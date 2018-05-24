# frozen_string_literal: true


module Phileas

  class VoIDecayCalculator
    NODECAY = Object.new.tap {|x| def x.remaining_voi_at(coord); 1.0; end }

    def initialize
    end

    def remaining_voi_at(coord)
    end
  end

  class VoITracker
    NODECAY = VoIDecayCalculator
    def initialize(start_voi:, start_time:, time_decay:, start_location:, location_decay: nil)
      @start_voi = start_voi
      @time_decay_function = VoIDecayCalculator.new(start_time, time_decay)
      @location_decay_function = if location_decay.nil? or start_location.nil?
        VoIDecayCalculator::NODECAY
      else
        VoIDecayCalculator.new(location_decay)
      end
    end

    def remaining_voi_at(time, location)
      @time_decay_function.remaining_voi_at(time) *
        @location_decay_function.remaining_voi_at(location)
    end
  end

end
