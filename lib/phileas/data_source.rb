# frozen_string_literal: true

require_relative './voi_tracker'

require 'erv'


module Phileas

  class DataSource
    def initialize(location:, content_type:, voi_dist:, message_size_dist:, time_between_message_generation_dist:)
      @location = location
      @content_type = content_type
      @voi_dist  = ERV::Distribution.new(voi_dist)
      @size_dist = ERV::Distribution.new(message_size_dist)
      @time_dist = ERV::Distribution.new(time_between_message_generation_dist)
    end

    def generate(time)
      [
        @time_dist.sample,
        Message.new(
          size: @size_dist.sample,
          content_type: @content_type,
          starting_voi: @voi_dist.sample,
          originating_time: time,
          originating_location: @location,
          starting_voi: @voi.sample,
          time_decay: nil,
          location_decay: nil
        )
      ]
    end
  end

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
    def self.create(location:, content_type:, voi_dist:, message_size_dist:, time_between_message_generation_dist:)
      DataSource.new(
        location: location,
        content_type: content_type,
        voi_dist: voi_dist,
        message_size_dist: message_size_dist,
        time_between_message_generation_dist: time_between_message_generation_dist,
      )
    end
  end

end
