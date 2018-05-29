# frozen_string_literal: true


module Phileas

  class Message

    attr_reader :size, :content_type, :type

    def initialize(size:, type:, content_type:, starting_voi:,
                   originating_time:, originating_location:, time_decay:,
                   space_decay: nil)
      @size                 = size
      @type                 = type
      @content_type         = content_type
      @starting_voi         = starting_voi
      @originating_time     = originating_time
      @originating_location = originating_location
      @time_decay_function  = VoIDecayCalculator.new(@originating_time, time_decay)

      @space_decay_function = if space_decay.nil?
        VoIDecayCalculator::NODECAY
      else
        VoIDecayCalculator.new(@originating_location, space_decay)
      end
    end

    def remaining_voi_at(time:, location:)
      if @originating_time > time
        raise ArgumentError, "Requested VoI evaluation time (#{time}) preceedes message originating time (#{@originating_time})!"
      end
      @starting_voi *
        @time_decay_function.remaining_value_at(time) *
        @space_decay_function.remaining_value_at(location)
    end

  end

end
