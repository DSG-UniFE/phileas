# frozen_string_literal: true


module Phileas

  class AggregationProcessingPolicy
    def initialize(aggregation_window_size_dist:, aggregated_message_size_dist:, voi_multiplier:, resource_requirements:)
      @aggregation_window_size_dist = ERV::RandomVariable.new(aggregation_window_size_dist)
      @aggregated_message_size_dist = ERV::RandomVariable.new(aggregated_message_size_dist)
      # ASSUMPTION: for the moment we adopt the simple policy of generating the
      # VoI of the CRIO message by multiplying the average VoI of the received
      # messages by a constant factor, called VoI multiplier.
      @voi_multiplier = voi_multiplier
      @recorded_vois = []
      @messages_to_next_aggregation = @aggregation_window_size_dist.next
      @resources_required = resource_requirements
      @resources_assigned = resource_requirements
    end

    def assign_resources(quantity)
      @resources_assigned = quantity
    end

    def process_message_with_voi(value)
      # reject messages if resources are not sufficient
      # for the moment we implement a linear message drop policy
      threshold = @resources_assigned / @resources_required
      if (threshold < 1.0)
        return if rand > threshold
      end

      #do not use negative values
      #unless @messages_to_next_aggregation == 0
      #  @messages_to_next_aggregation -= 1
      #end
      # check whether to trigger aggregation
      if @messages_to_next_aggregation == 0
        #skip if no records
        if @recorded_vois == []
          return nil
        end
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

    attr_reader :device, :resource_requirements, :input_message_type, :input_content_type

    def initialize(device:, input_message_type:, input_content_type:, output_message_type:,
                   output_content_type:, resource_requirements:, time_decay:,
                   space_decay:, processing_policy:)
      @device                = device
      @input_content_type    = input_content_type
      @input_message_type    = input_message_type
      @output_message_type   = output_message_type
      @output_content_type   = output_content_type
      @resource_requirements = resource_requirements
      @time_decay            = time_decay
      @space_decay           = space_decay

      # prepare processing policy configuration
      processing_policy_configuration = processing_policy.dup

      # get class name that corresponds to the requested distribution
      processing_policy_type = processing_policy_configuration.delete(:type)&.to_s
      klass_name = processing_policy_type.split('_').map(&:capitalize).join + 'ProcessingPolicy'

      # add resource requirements
      processing_policy_configuration.merge!(resource_requirements: resource_requirements)

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
