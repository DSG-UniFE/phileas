# frozen_string_literal: true
require 'progress_bar'

require_relative './support/sorted_array'
require_relative './data_source'
require_relative './device'
require_relative './event'
require_relative './latency_manager'
require_relative './propagation_loss'
require_relative './location'
require_relative './service'
require_relative './service_repository'
require_relative './user_group'


module Phileas
  class Simulator
    OUTPUT_SIM_FOLDER = "simulation_results"
    def initialize(configuration:)
      @state = :not_running
      @progress_bar = ProgressBar.new(100, :bar, :percentage, :elapsed, :eta)
      @event_queue = nil
      @active_service_repository = []
      @configuration = configuration

      # prepare location repository
      @location_repository = Hash[
        @configuration.locations.map do |loc_id,loc_conf|
          [ loc_id, LocationFactory.create(loc_conf) ]
        end
      ]

      # prepare data source repository
      @data_source_repository = Hash[
        @configuration.data_sources.map do |ds_id,ds_conf|
          dsc = ds_conf.dup
          loc_id = dsc.delete(:location_id)
          [ ds_id, DataSourceFactory.create(dsc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare device repository
      @device_repository = Hash[
        @configuration.devices.map do |dev_id,dev_conf|
          dvc = dev_conf.dup
          loc_id = dvc.delete(:location_id)
          [ dev_id, DeviceFactory.create(dvc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare user group repository
      @user_group_repository = Hash[
        @configuration.user_groups.map do |ug_id,ug_conf|
          ugc = ug_conf.dup
          loc_id = ugc.delete(:location_id)
          [ ug_id, UserGroupFactory.create(ugc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare service type repository
      @service_type_repository = @configuration.service_types

      # setup latency manager
      @latency_manager = LatencyManager.new

      # setup propagation_loss manager with default parameters
      if @configuration.propagation_loss_enabled
        @propagation_loss = LogDistancePropagationLoss.new
      else
        @propagation_loss = nil
      end

      @tx_power_dbm = 32.0
      @energy_det_th = -96.0 #dbm of wifi_channgel

      # Prototyping speed_up simulation
      # not used at this time
      # random variable for scale generation
      # adjust this parameter
      @serv_speedup_rv = ERV::RandomVariable.new(distribution: :gaussian, args: { mean: 0.02, sd: 0.001 })

      #voi benchmark  file
      time = Time.now.strftime('%Y%m%d%H%M%S')

      # benchmarking file, create simulation directory
      Dir.mkdir(OUTPUT_SIM_FOLDER) unless Dir.exist?(OUTPUT_SIM_FOLDER)

      @voi_benchmark = File.open("#{OUTPUT_SIM_FOLDER}/sim_voi_data#{time}.csv", 'w')
      @voi_benchmark  << "CurrentTime,InputVoI,OriginatingTime,Users,OutputVoI,ContentType,ActiveServices,Device,Distance\n"
      #services benchmakr file (aggregated/dropped/ messages) resources' status
      @services_benchmark = File.open("#{OUTPUT_SIM_FOLDER}/sim_services_data#{time}.csv", 'w')
      @services_benchmark << "CurrentTime,MsgType,MsgContentType,Dropped,ResourcesRequirements,AvailableResources,ActiveServices,EdgeResourcesUsed,Device\n"
      @resources_allocation = File.open("#{OUTPUT_SIM_FOLDER}/resources_allocation_data#{time}.csv", 'w')
      @resources_allocation << "CurrentTime,Service,Device,CoreNumber,Scale,DeviceResources,DesiredSpeedUp\n"
      @device_utilization = File.open("#{OUTPUT_SIM_FOLDER}/device_utilization#{time}.csv", 'w')
      @device_utilization << "CurrentTime,Device,Utilization,DeviceResources\n"
      @speed_up_event_benchmark = File.open("#{OUTPUT_SIM_FOLDER}/speed_up_event_benchmark#{time}.csv", 'w')
      @speed_up_event_benchmark << "CurrentTime\n"
    end

    def new_event(type, data, time)
      raise "Simulation not running" unless @state == :running
      @event_queue << Event.new(type, data, time)
    end

    def run
      # change state to running
      @state = :running

      # create event queue
      @event_queue = SortedArray.new

      # setup initial time
      @current_time = @configuration.start_time

      # create active service repository
      @active_service_repository = ServiceRepository.new

      # schedule service_activations
      @configuration.service_activations.each do |sa_id,service_activation_conf|
        service_type = @service_type_repository[service_activation_conf[:type_id]]
        time = service_activation_conf.dig(:at, :time)
        device_id = service_activation_conf.dig(:at, :device_id)
        service_conf = service_type.dup
        service_conf.merge!(device: @device_repository[device_id], activation_time: time)
        new_event(Event::ET_SERVICE_ACTIVATION, [ service_conf ], time&.to_time&.to_f)
      end

      # schedule initial generation of raw message
      @data_source_repository.each_value do |ds|
        schedule_next_raw_data_message_generation(ds)
      end

      # schedule the generation of the first speed_up event
      schedule_speed_up_event_generation if @configuration.scaling_event
      # schedule users' mobility event generation
      schedule_next_change_position_event_generation if @configuration.mobility_enabled

      current_event = 0

      # launch simulation
      until @event_queue.empty?
        e = @event_queue.shift

        current_event += 1

        # sanity check on simulation time flow
        if @current_time > e.time
          raise "Error! Simulation time inconsistency when processing event ###{current_event} " +
                "(#{e}) at time #{@current_time}!"
        end

        @current_time = e.time

        case e.type

        when Event::ET_RAW_DATA_MESSAGE_GENERATION
          raw_data_msg, data_source = e.data

          # dispatch raw data message
          dispatch_message(raw_data_msg)

          # schedule next raw data message generation
          schedule_next_raw_data_message_generation(data_source)

        when Event::ET_RAW_DATA_MESSAGE_ARRIVAL, Event::ET_IO_MESSAGE_ARRIVAL
          msg, service = e.data
          new_msg = service.incoming_message(msg, @current_time)

          # service might 1) return nothing; 2) return io; 3) return crio
          # perform message dispatching accordingly
          unless new_msg.nil?
            dispatch_message(new_msg)
            @services_benchmark << "#{@current_time},#{msg.type},#{msg.content_type},false,#{service.resource_requirements},#{service.device.available_resources},#{@active_service_repository.find_active_services(@current_time).length},#{resources_in_use_at_the_edge(@device_repository)},#{service.device}\n"
          else
            #log if message has been dropped
            @services_benchmark << "#{@current_time},#{msg.type},#{msg.content_type},true,#{service.resource_requirements},#{service.device.available_resources},#{@active_service_repository.find_active_services(@current_time).length},#{resources_in_use_at_the_edge(@device_repository)},#{service.device}\n"
          end


        when Event::ET_CRIO_MESSAGE_ARRIVAL
          # calculate voi at user group
          msg, user_group = e.data
          msg_voi = msg.remaining_voi_at(time: @current_time,
                                         location: user_group.location, debug: false)
          #num_users = user_group.users_interested(content_type: msg.content_type,
          #                                        time: @current_time)
          # here we should count only the users nearby
          #num_users = user_group.users_interested(content_type: msg.content_type)
          num_users = user_group.users_interested(msg.content_type, user_group.location)

          total_voi = msg_voi * num_users
          #puts "CRIO message starting_voi: #{msg.starting_voi} remaing_voi: #{msg_voi}"
          distance = msg.originating_location.distance(user_group.location)
          # NOTE: for now the output is a list of VoI values measured at the
          # corresponding time - the idea is to facilitate post-processing via
          # CSV parsing
          #puts "#@current_time,#{msg.originating_time},#{msg.starting_voi},#{num_users},#{total_voi},#{msg.content_type},#{@active_service_repository.find_active_services(@current_time).length}"
          @voi_benchmark << "#@current_time,#{msg.starting_voi},#{msg.originating_time},#{num_users},#{total_voi},#{msg.content_type},#{@active_service_repository.find_active_services(@current_time).length},#{msg.device},#{distance}\n"


        when Event::ET_SERVICE_ACTIVATION
          serv = ServiceFactory.create(e.data)
          @active_service_repository.add(serv)
          # add this missing benchmark. 
          # check the csv file
          # @resources_allocation << "#{@current_time},#{serv.output_content_type},#{serv.device},#{serv.resources_assigned},#{serv.required_scale},#{serv.device.resources},#{serv.numerical_speed_up}\n"


        when Event::ET_SERVICE_SHUTDOWN
          raise "Unimplemented yet!"


        when Event::ET_SERVICE_SPEEDUP
          puts "ET_SERVICE_SPEEDUP event generated at time: #{@current_time}"
          @speed_up_event_benchmark << "#{@current_time}\n"
          # for each ET_SERVICE_SPEEDUP event select a service randomly
          selected_service = rand(@active_service_repository.find_active_services(@current_time).length)
          service = @active_service_repository.find_active_services(@current_time)[selected_service]
          dev_cores = service.device.resources
          used_cores = dev_cores - service.device.available_resources
          puts "Reallocating resources for service #{service.output_content_type}, now using: #{service.resources_assigned} Device Status: #{used_cores} / #{dev_cores}"
          avg_cores = (dev_cores + service.device.available_resources) / 2.0
          #puts "Available cores on device: #{service.device.available_resources} / #{dev_cores}\n "
          #puts "Service is using #{service.resources_assigned} cores"
          log_base = service.speed_up[:base]
          log_exp = service.speed_up[:exp]
          # simulate step by step speed_up or scale_down
          # otherwise, we can use the gaussian random variable e.data
          # calculate the possible speed_up based on the device's capabilities
          # before was dev_cores, here we are trying to use the average between available and total instead
          speed_up = rand(avg_cores) ** Math::log(log_exp, log_base)
          # need to reallocate the resource requirements only for that service
          # here we simulate an increased or a decreas interest in the service
          #calculate the numerical speed_up
          if rand > 0.5
            # simulate a peak of interest
            scale = speed_up.round
          else
            scale = -speed_up.round
          end
          # the scaling should be reflected on the number of processed messages 
          # (as effect of the linear dropping policy)
          # we should also change the VoI multiplier?

          # Simulate an increase or a decrease of required resources
          puts "Scale: #{scale} for #{service.output_content_type} on device #{service.device}"
          service.resource_requirements += scale
          service.resource_requirements = 0.0 if service.resource_requirements < 0.0
          service.required_scale = scale
          # reallocate reources here
          service.device.resource_assignment_policy.reallocate_resources_with_speedup
          # update user interest according to speed_up (only for user_group nearby)
          @user_group_repository.each do |_, ug|
            if ug.nearby?(service.device.location)
               ug.update_interest(service.output_content_type, scale)
            end
          end
          # collect the data regarding device_utilization
          @device_repository.each do |dev|
            unless dev[1].type == :cloud
              @device_utilization << "#{@current_time},#{dev[1]},#{(dev[1].resources - dev[1].available_resources).round},#{dev[1].resources}\n"
            end
          end
          @active_service_repository.find_active_services(@current_time).each do |s|
            #puts "Benchmarking reallocation data for service #{s.output_content_type} on device: #{s.device} at time #{@current_time}"
            @resources_allocation << "#{@current_time},#{s.output_content_type},#{s.device},#{s.resources_assigned},#{s.required_scale},#{s.device.resources},#{s.numerical_speed_up}\n "
          end
          schedule_speed_up_event_generation

        when Event::ET_USER_GROUP_MOVED
          @user_group_repository.each do |_,ug|
            ug.move_users
          end
          schedule_next_change_position_event_generation

        when Event::ET_END_OF_SIMULATION
          $stderr.puts "#{e.time}: end simulation"
          break
        end
      end

      @voi_benchmark.close
      @services_benchmark.close
      @resources_allocation.close
      @device_utilization.close
      @speed_up_event_benchmark.close
      @state = :not_running
      @event_queue = nil
      #save also position data
      @user_group_repository.each do |id,ug|
        Helper.coords_to_kml("#{OUTPUT_SIM_FOLDER}/user_group_#{id}.kml", ug.trajectory)
      end
      # sleep before drawing the graphs
      puts "*** #{self.class.name} About to generate plots.... ***"
      puts "Rscript --vanilla bin/generate_plots.r #{@voi_benchmark.path} #{@services_benchmark.path} #{@resources_allocation.path} #{@device_utilization.path}"
      `sleep 2; Rscript --vanilla bin/generate_plots.r #{@voi_benchmark.path} #{@services_benchmark.path} #{@resources_allocation.path} #{@device_utilization.path}`
    end

    # TODO: consider refactoring the following methods and moving them out of the Simulator class
    private
      def schedule_next_raw_data_message_generation(data_source)
        update_progress_bar
        if @current_time <= (@configuration.start_time + @configuration.duration)
          time_to_next_generation, raw_msg = data_source.generate(@current_time)
          new_event(Event::ET_RAW_DATA_MESSAGE_GENERATION, [ raw_msg, data_source ], @current_time + time_to_next_generation)
        end
      end

      # TODO: consider joining dispatch and management of raw data and IO messages
      # (perhaps in a dispatch_low_maturity_message method?)
      def dispatch_raw_data_message(msg)
        @active_service_repository.find_interested_services(input_content_type: msg.content_type,
                                                            input_message_type: :raw_data) do |serv|
          loc1 = msg.originating_location
          loc2 = serv.device_location
          transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
          rx_power = @configuration.propagation_loss_enabled ? @propagation_loss.calc_rx_power(@tx_power_dbm, loc1.coords, loc2.coords)
             : Float::INFINITY  
          unless transmission_time.nil? || rx_power < @energy_det_th
            new_event(Event::ET_RAW_DATA_MESSAGE_ARRIVAL, [ msg, serv ], @current_time + transmission_time)
          else
            #$stderr.puts "transmission is unfeasible"
          end
        end
      end

      def dispatch_io_message(msg)
        @active_service_repository.find_interested_services(input_content_type: msg.content_type,
                                                            input_message_type: :io) do |serv|
          loc1 = msg.originating_location
          loc2 = serv.device_location
          transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
          rx_power = @configuration.propagation_loss_enabled ? @propagation_loss.calc_rx_power(@tx_power_dbm, loc1.coords, loc2.coords)
             : Float::INFINITY  
          unless transmission_time.nil? || rx_power < @energy_det_th
            new_event(Event::ET_IO_MESSAGE_ARRIVAL, [ msg, serv ], @current_time + transmission_time)
          else
            #$stderr.puts "transmission is unfeasible"
          end
        end
      end

      def schedule_speed_up_event_generation()
        if @current_time <= (@configuration.start_time + @configuration.duration)
          scale = @serv_speedup_rv.next
          # time_to_next_generation = scale * 100000
          # schedule a reallocation event each 1800 seconds
          # an improvements here, it is select also a location and the reallocate
          # the resource only for the devices nearby
          time_to_next_generation = 1800.to_f
          puts "Current time: #{@current_time} \t Time to next generation  #{time_to_next_generation}"
          new_event(Event::ET_SERVICE_SPEEDUP, [scale], @current_time + time_to_next_generation)
        end
      end

      def schedule_next_change_position_event_generation()
        if @current_time <= (@configuration.start_time + @configuration.duration)
          time_to_next_generation = @configuration.duration / 100.0
          puts "ChangePosition: Current time: #{@current_time} \t Time to next generation  #{time_to_next_generation}"
          new_event(Event::ET_USER_GROUP_MOVED, [], @current_time + time_to_next_generation)
        end
      end

      def dispatch_crio_message(msg)
        @user_group_repository.each do |ug_id,ug|
          ug.interests.each do |interest|
            if interest[:content_type] == msg.content_type
              loc1 = msg.originating_location
              # loc2 should be the location of the user so the transmission time
              # is the difference between
              loc2 = ug.location
              transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
              rx_power = @configuration.propagation_loss_enabled ? @propagation_loss.calc_rx_power(@tx_power_dbm, loc1.coords, loc2.coords)
              : Float::INFINITY  
              unless transmission_time.nil? || rx_power < @energy_det_th
                new_event(Event::ET_CRIO_MESSAGE_ARRIVAL, [ msg, ug ], @current_time + transmission_time)
                #$stdout.puts "CRIO transmission is feasible, power at rx #{rx_power}, tx-rx distance: #{loc1.distance(loc2)}"
              else
               #$stderr.puts "CRIO transmission is unfeasible, device at, #{loc1.coords.lat} #{loc1.coords.lon}, power at rx #{rx_power}, tx-rx distance: #{loc1.distance(loc2)}"
              end
            end
          end
        end
      end

      def dispatch_message(msg)
        case msg.type
        when :raw_data
          dispatch_raw_data_message(msg)
        when :io
          dispatch_io_message(msg)
        when :crio
          dispatch_crio_message(msg)
        else
          raise "Inconsistent message type found (#{msg.type})!"
        end
      end

      # monitor the available resource at the edge during the simulation
      def resources_in_use_at_the_edge(device_repository)
        resources_in_use = 0
        device_repository.each do |dev|
          unless dev[1].type == :cloud
              resources_in_use += (dev[1].resources - dev[1].available_resources)
          end
        end
        resources_in_use / (device_repository.length.to_f * 100.0)
      end


      def update_progress_bar
        @progress_bar.count = ((@current_time - @configuration.start_time) / (@configuration.duration)) * 100
        @progress_bar.increment! 0
      end

  end
end
