# frozen_string_literal: true

require_relative './support/sorted_array'


module Phileas
  class Simulator
    def initialize(configuration:)
      @state = :not_running
      @event_queue = nil
      @active_service_repository = []
      @configuration = configuration

      # prepare location repository
      @location_repository = Hash [
        @configuration.locations.map do |loc_id,loc_conf|
          [ loc_id, LocationFactory.create(loc_conf) ]
        end
      ]

      # prepare data source repository
      @data_source_repository = Hash [
        @configuration.data_sources.map do |ds_id,ds_conf|
          dsc = ds_conf.dup
          loc_id = dsc.delete(:location_id)
          [ ds_id, DataSourceFactory.create(dsc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare device repository
      @device_repository = Hash [
        @configuration.devices.map do |dev_id,dev_conf|
          dvc = dev_conf.dup
          loc_id = dvc.delete(:location_id)
          [ dev_id, DeviceFactory.create(dvc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare user group repository
      @user_group_repository = Hash [
        @configuration.user_groups.map do |ug_id,ug_conf|
          ugc = ug_conf.dup
          loc_id = ugc.delete(:location_id)
          [ ug_id, UserGroupFactory.create(ugc.merge!(location: @location_repository[loc_id])) ]
        end
      ]

      # prepare service type repository
      @service_type_repository = Hash [
        @configuration.service_types.map do |st_id,st_conf|
          stc = st_conf.dup
          ds_id = stc.delete(:data_source_id)
          [ st_id, ServiceTypeFactory.create(stc.merge!(data_source: @data_source_repository[ds_id])) ]
        end
      ]
    end

    def new_event(type, data, time) #, destination)
      raise "Simulation not running" unless @state == :running
      @event_queue << Event.new(type, data, time) #, destination)
    end

    def run
      @state = :running
      @event_queue = SortedArray.new
      @current_time = @start_time
      @active_service_repository = ServiceRepository.new

      # schedule service_activations
      @configuration.activate_services.each do |service_conf|
        s = service_conf.dup
        at = s.delete(:at)
        time, location = [:time, :location].map(&at)
        serv = ServiceFactory.create(s)
        new_event(Event::ET_SERVICE_ACTIVATION, [ serv ], time)
      end

      # schedule initial generation of raw message
      @data_source_repository.each_value do |ds|
        schedule_next_message_generation(ds)
      end

      # launch simulation
      until @event_queue.empty?
        e = @event_queue.shift
        case e.type
        when Event::ET_RAW_DATA_MESSAGE_GENERATION
          raw_msg, data_source = e.data

          # need to schedule raw data message arrival
          ct = raw_msg[:content_type]

          # NOTE: the dispatching of raw data messages to services (instead of,
          # e.g., to devices that would later do internal redispatching) might end
          # up generating more events but it also simplifies the message management
          # code at the device level
          @active_service_repository.find_interested_services_with_distance_from(ct, ds.location).each do |serv, distance|
            new_event(Event::ET_RAW_DATA_MESSAGE_ARRIVAL, [ raw_msg, serv ], @current_time + distance / PROPAGATION_VELOCITY)
          end

          # schedule next raw data message generation
          schedule_next_message_generation(data_source)

        when Event::ET_RAW_DATA_MESSAGE_ARRIVAL
          raw_msg, service = e.data
          res = service.incoming_message(raw_msg, e.time)
          unless res.nil?
            # need to schedule CRIO message arrival
            ct = raw_msg[:content_type]
            # NOTE: the dispatching of raw data messages to services (instead of,
            # e.g., to devices that would later do internal redispatching) might end
            # up generating more events but it also simplifies the message management
            # code at the device level
            @active_service_repository.find_interested_services_with_distance_from(ct, ds.location).each do |serv, distance|
              new_event(Event::ET_RAW_DATA_MESSAGE_ARRIVAL, [ raw_msg, serv ], @current_time + distance / PROPAGATION_VELOCITY)
            end
          end

        when Event::ET_IO_MESSAGE_ARRIVAL
          raise "Unimplemented yet!"

        when Event::ET_CRIO_MESSAGE_ARRIVAL

        when Event::ET_SERVICE_ACTIVATION
          @active_service_repository.add_service(e.data.first)

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

    # TODO: consider getting rid of @current_time in the following methods
    private
      def schedule_next_message_generation(data_source)
        time_to_next_generation, raw_msg = data_source.generate
        new_event(Event::ET_RAW_DATA_MESSAGE_GENERATION, [ raw_msg, data_source ], @current_time + time_to_next_generation)
      end

  end
end
