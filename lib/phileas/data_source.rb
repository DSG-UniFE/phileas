# frozen_string_literal: true

require_relative './voi_tracker'
require_relative './message'

require 'erv'


module Phileas

  class DataSource
    def initialize(location:, output_content_type:, voi_dist:,
                   message_size_dist:, time_between_message_generation_dist:,
                   time_decay:, space_decay:)
      @location = location
      @output_content_type = output_content_type
      @voi_dist  = ERV::RandomVariable.new(voi_dist)
      @size_dist = ERV::RandomVariable.new(message_size_dist)
      @time_dist = ERV::RandomVariable.new(time_between_message_generation_dist)
      @time_decay = time_decay
      @space_decay = space_decay
    end

    def generate(time)
      [
        @time_dist.next,
        Message.new(
          size: @size_dist.next,
          type: :raw_data,
          content_type: @output_content_type,
          starting_voi: @voi_dist.next,
          originating_time: time,
          originating_location: @location,
          time_decay: @time_decay,
          space_decay: @space_decay,
        )
      ]
    end
  end

  # TODO: finish implementing this
  class MultistateDataSource
    def initialize(weighted_states)
      @states = weighted_states
      # normalize weigths
      weight_sum = @states.inject(0.0) {|s,x| s += x[:weight] }
      @states.each {|x| x[:weight] /= weight_sum }
    end

    def generate
      @next_state = sample_next_state
      @states[@next_state].generate
    end

    private
      def sample_next_state
        x = rand
        # find index of the state we are supposed to transition to
        i = 0
        while x > @states[i][:weight]
          x -= @states[i][:weight]
          i += 1
        end
        i
      end
  end

  class DataSourceFactory
    def self.create(location:, output_content_type:, voi_dist:,
                    message_size_dist:, time_between_message_generation_dist:,
                    time_decay:, space_decay:)
      DataSource.new(
        location: location,
        output_content_type: output_content_type,
        voi_dist: voi_dist,
        message_size_dist: message_size_dist,
        time_between_message_generation_dist: time_between_message_generation_dist,
        time_decay: time_decay,
        space_decay: space_decay,
      )
    end
  end

end
