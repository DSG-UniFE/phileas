# frozen_string_literal: true


module Phileas

  class Message

    attr_reader :size, :content_type, :type, :originating_location, :starting_voi, :originating_time

    def initialize(size:, type:, content_type:, starting_voi:,
                   originating_time:, originating_location:, time_decay:,
                   space_decay: nil)
      @size                 = size
      @type                 = type
      @content_type         = content_type
      @starting_voi         = starting_voi
      @originating_time     = originating_time
      @originating_location = originating_location
      @time_decay_function  = ValueDecayCalculator.new(initial_value: @originating_time,
                                                       decay_logic: time_decay)

      @space_decay_function = if space_decay.nil?
        ValueDecayCalculator::NODECAY
      else
        ValueDecayCalculator.new(initial_value: @originating_location,
                                 decay_logic: space_decay)
      end
    end

    def remaining_voi_at(time:, location:, debug: false)
      if @originating_time > time
        raise ArgumentError, "Requested VoI evaluation time (#{time}) preceedes message originating time (#{@originating_time})!"
      end

      spatial_decay = if @originating_location == :cloud or location == :cloud
        # no spatial decay if cloud is involved
        1.0
      else
        @space_decay_function.remaining_value_at(@originating_location.distance(location))
      end
      puts "distance: #{@originating_location.distance(location)} spatial decay: #{spatial_decay} delta_time: #{time-@originating_time} time_decay: #{@time_decay_function.remaining_value_at(time-@originating_time)}" unless debug == false
      #puts "spatial_decay: #{spatial_decay} time_decay: #{@time_decay_function.remaining_value_at(time-@originating_time)}"
      @starting_voi * spatial_decay *
        @time_decay_function.remaining_value_at(time-@originating_time)
    end

  end

end
