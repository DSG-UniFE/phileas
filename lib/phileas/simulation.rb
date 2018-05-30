# frozen_string_literal: true

require_relative './support/sorted_array'
require_relative './data_source'
require_relative './device'
require_relative './event'
require_relative './latency_manager'
require_relative './location'
require_relative './service'
require_relative './service_repository'
require_relative './user_group'


module Phileas
  class Simulator
    def initialize(configuration:)
      @state = :not_running
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
      # @service_type_repository = Hash[
      #   @configuration.service_types.map do |st_id,st_conf|
      #     stc = st_conf.dup
      #     ds_id = stc.delete(:data_source_id)
      #     [ st_id, stc.merge!(data_source: @data_source_repository[ds_id]) ]
      #   end
      # ]

      @latency_manager = LatencyManager.new
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
        service_conf.merge!(device: @device_repository[device_id])
        new_event(Event::ET_SERVICE_ACTIVATION, [ service_conf ], time&.to_time&.to_f)
      end

      # schedule initial generation of raw message
      @data_source_repository.each_value do |ds|
        schedule_next_raw_data_message_generation(ds)
      end

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

        when Event::ET_RAW_DATA_MESSAGE_ARRIVAL
        when Event::ET_IO_MESSAGE_ARRIVAL
          msg, service = e.data
          new_msg = service.incoming_message(msg, @current_time)

          # service might 1) return nothing; 2) return io; 3) return crio
          # perform message dispatching accordingly
          unless new_msg.nil?
            dispatch_message(new_msg)
          end

        when Event::ET_CRIO_MESSAGE_ARRIVAL
          # calculate voi at user group
          msg, user_group = e.data
          msg_voi = msg.remaining_voi_at(time: @current_time,
                                         location: user_group.location)
          num_users = user_group.users_interested(content_type: msg.content_type, 
                                                  time: @current_time)
          total_voi = msg_voi * num_users

          # NOTE: for now the output is a list of VoI values measured at the
          # corresponding time - the idea is to facilitate post-processing via
          # CSV parsing
          puts "#@current_time,#{total_voi}"


        when Event::ET_SERVICE_ACTIVATION
          serv = ServiceFactory.create(e.data)
          @active_service_repository.add(serv)


        when Event::ET_SERVICE_SHUTDOWN
          raise "Unimplemented yet!"


        when Event::ET_END_OF_SIMULATION
          $stderr.puts "#{e.time}: end simulation"
          break
        end
      end

      @state = :not_running
      @event_queue = nil
    end

    # TODO: consider refactoring the following methods and moving them out of the Simulator class
    private
      def schedule_next_raw_data_message_generation(data_source)
        time_to_next_generation, raw_msg = data_source.generate(@current_time)
        new_event(Event::ET_RAW_DATA_MESSAGE_GENERATION, [ raw_msg, data_source ], @current_time + time_to_next_generation)
      end

      # TODO: consider joining dispatch and management of raw data and IO messages
      # (perhaps in a dispatch_low_maturity_message method?)
      def dispatch_raw_data_message(msg)
        @active_service_repository.find_interested_services(input_content_type: msg.content_type,
                                                            input_message_type: :raw_data) do |serv|
          loc1 = msg.originating_location
          loc2 = serv.device_location
          transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
          unless transmission_time.nil?
            new_event(Event::ET_RAW_DATA_MESSAGE_ARRIVAL, [ msg, serv ], @current_time + transmission_time)
          else
            $stderr.puts "transmission is unfeasible"
          end
        end
      end

      def dispatch_io_message(msg)
        @active_service_repository.find_interested_services(input_content_type: msg.content_type,
                                                            input_message_type: :io) do |serv|
          loc1 = msg.originating_location
          loc2 = serv.device_location
          transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
          unless transmission_time.nil?
            new_event(Event::ET_IO_MESSAGE_ARRIVAL, [ msg, serv ], @current_time + transmission_time)
          else
            $stderr.puts "transmission is unfeasible"
          end
        end
      end

      def dispatch_crio_message(msg)
        @user_group_repository.find_interested_user_groups(msg.content_type) do |ug|
          loc1 = msg.originating_location
          loc2 = serv.device_location
          transmission_time = @latency_manager.calculate_trasmission_time_between(loc1, loc2)
          unless transmission_time.nil?
            new_event(Event::ET_CRIO_MESSAGE_ARRIVAL, [ msg, ug ], @current_time + transmission_time)
          else
            $stderr.puts "transmission is unfeasible"
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

  end
end
