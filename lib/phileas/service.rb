# frozen_string_literal: true


module Phileas

  class AggregationProcessingPolicy
    #read the dropping_rate for service
    def initialize(aggregation_window_size_dist:, aggregated_message_size_dist:, voi_multiplier:,
       resource_requirements:, device:)
      @aggregation_window_size_dist = ERV::RandomVariable.new(aggregation_window_size_dist)
      @aggregated_message_size_dist = ERV::RandomVariable.new(aggregated_message_size_dist)
      # ASSUMPTION: for the moment we adopt the simple policy of generating the
      # VoI of the CRIO message by multiplying the average VoI of the received
      # messages by a constant factor, called VoI multiplier.
      @voi_multiplier = voi_multiplier
      @recorded_vois = []
      @messages_to_next_aggregation = @aggregation_window_size_dist.next
      @resources_required = resource_requirements
      #is this a bug?
      @resources_assigned = resource_requirements
      @device = device
      # need to keep historical data
      # a percentage of dropped packets in the last
      # time window
      @processed_messages = 0
      @dropped_messages = 0
    end

    def assign_resources(quantity)
      @resources_assigned = quantity
    end

    def dropping_rate
      dropping_rate = @dropped_messages / (@processed_messages + @dropped_messages).to_f
      #puts "Dropping rate #{dropping_rate}"
      dropping_rate
    end

    def process_message_with_voi(value)
      # reject messages if resources are not sufficient
      # for the moment we implement a linear message drop policy
      # if the device has no available resources,the message will be dropped
      # resources assigined to this service
      threshold = @resources_assigned * value
      if (threshold < 1.0)
        if rand > threshold
          @dropped_messages += 1
          return
        end
      end
      # check whether to trigger aggregation
      if @messages_to_next_aggregation == 0
        #skip if no records
        raise "No VoI information recorded!" if @recorded_vois.empty?
        @processed_messages += 1
        # calculate average voi
        total_voi = @recorded_vois.inject(0.0) {|acc,el| acc += el }
        average_voi = total_voi / @recorded_vois.size.to_f

        # reset messages array and messages_to_next_aggregation counter
        @recorded_vois = []
        @messages_to_next_aggregation = @aggregation_window_size_dist.next

        # return size and voi message attributes
        {
          size: @aggregated_message_size_dist.next,
          starting_voi: average_voi * @voi_multiplier
        }
      else
        @messages_to_next_aggregation -= 1
        @recorded_vois << value
        return nil
      end
    end

  end

  class Service
    extend Forwardable

    # implements the device_location method
    def_delegator :@device, :location, :device_location
    # called by device
    def_delegator :@processing_policy, :assign_resources
    # called by device when reallocating
    def_delegator :@processing_policy, :dropping_rate

    # Use resource_requirement to scale up or down the allocated cores on the device
    attr_accessor :resource_requirements, :required_scale, :resources_assigned, :numerical_speed_up

    attr_reader :device, :input_message_type, :input_content_type,
                         :activation_time, :speed_up, :output_content_type

    def initialize(device:, input_message_type:, input_content_type:, output_message_type:,
                   output_content_type:, resource_requirements:, time_decay:,
                   space_decay:, processing_policy:, activation_time:, speed_up:)
      @device                = device
      @input_content_type    = input_content_type
      @input_message_type    = input_message_type
      @output_message_type   = output_message_type
      @output_content_type   = output_content_type
      @resource_requirements = resource_requirements
      @time_decay            = time_decay
      @space_decay           = space_decay
      @activation_time       = activation_time
      @speed_up              = speed_up
      @required_scale        = 0.0 #this value can be either positive or negative
      @resources_assigned    = resource_requirements
      @numerical_speed_up    = 0.0

      # prepare processing policy configuration
      processing_policy_configuration = processing_policy.dup

      # get class name that corresponds to the requested distribution
      processing_policy_type = processing_policy_configuration.delete(:type)&.to_s
      klass_name = processing_policy_type.split('_').map(&:capitalize).join + 'ProcessingPolicy'

      # add resource requirements
      processing_policy_configuration.merge!(resource_requirements: resource_requirements, device: @device)

      # create processing_policy object
      @processing_policy = Phileas.const_get(klass_name).new(processing_policy_configuration)
    end


    def incoming_message(msg, time)
      voi_left = msg.remaining_voi_at(time: time, location: @device.location)
      size_and_voi_attrs = @processing_policy.process_message_with_voi(voi_left)
      unless size_and_voi_attrs.nil?
        attrs = {
          type:                 @output_message_type,
          content_type:         @output_content_type,
          originating_time:     time,
          originating_location: @device.location,
          time_decay:           @time_decay,
          space_decay:          @space_decay,
          device:               @device,
        }
        return Message.new(attrs.merge!(size_and_voi_attrs))
      end
      return nil
    end
  end

  class ServiceFactory
    # create and activate service
    def self.create(args={})
      serv = Service.new(*args)
      dev = serv.device
      dev.add_service(serv)
      serv
    end
  end
end
