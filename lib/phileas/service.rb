# frozen_string_literal: true


module Phileas

  class ProcessingPolicy
    def initialize(aggregation_window_size_dist:, aggregated_message_size_dist:, voi_multiplier:)
      @aggregation_window_size_dist = aggregation_window_size_dist
      @aggregated_message_size_dist = aggregated_message_size_dist
      # ASSUMPTION: for the moment we adopt the simple policy of generating the
      # VoI of the CRIO message by multiplying the hignest VoI of the received
      # messages by a constant factor.
      @voi_multiplier = voi_multiplier
      @messages = []
      @messages_to_next_aggregation = @aggregation_window_size_dist.sample
    end

    def process_message(m, tstamp)
      @messages_to_next_aggregation -= 1
      # check whether to trigger aggregation
      if @messages_to_next_aggregation == 0 
        # reset messages array and messages_to_next_aggregation counter
        @messages = []
        @messages_to_next_aggregation = @aggregation_window_size_dist.sample
        # return message
        {
          message: Message.new(),
          # TODO: we need to consider processing times to add to tstamp
          tracker: VoITracker.new(
            start_voi: @voi.sample,
            start_time: tstamp,
            time_decay: { type: :exponential, half_life: 10.seconds },
            start_location: @location,
            space_decay: { type: :exponential, half_life: 10.seconds }
          ),
        }
      else
        @messages_to_next_aggregation -= 1
        @messages << m # do we actually need the timestamp?
        nil
      end
    end
  end

  class Service
    extend Forwardable

    # implements the incoming_message method
    def_delegator :@processing_policy, :process, :incoming_message
    # implements the device_location method
    def_delegator :@device, :location, :device_location

    def initialize(device:, requirements:, processing_policy:)
      @data_source = data_source
      @requirements = requirements
      @processing_policy = processing_policy
    end
  end

end
