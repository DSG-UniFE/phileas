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

    def generate
      # ASSUMPTION: we assume that VoI of a raw data message does not change
      # significantly as it travels from the data source to the processing
      # device
      [ 
        @time_dist.sample,
        {
          content_type: @content_type,
          size: @size_dist.sample,
          originating_location: @location,
          originating_voi: @voi.sample,
        }
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
    def self.create(voi_dist:, location:, content_type:)
      dist = Distribution.new(voi_dist)
      DataSource.new(voi_dist: dist, location: location, 
                     content_type: content_type)
    end
  end

end
