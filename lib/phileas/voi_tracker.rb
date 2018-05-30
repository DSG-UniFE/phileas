# frozen_string_literal: true


module Phileas

  class ValueDecayCalculator

    # special calculator that applies no decay
    NO_DECAY = Object.new.tap {|x| def x.remaining_value_at(coord); 1.0; end }

    # list of supported decay types (to facilitate input validation)
    SUPPORTED_DECAY_TYPES = [ :linear, :exponential ]
    private_constant :SUPPORTED_DECAY_TYPES

    # to speed up calculations
    LN_2 = Math.log(2.0)
    private_constant :LN_2

    def initialize(initial_value:, decay_logic:)
      @initial_value = initial_value

      @decay_type = decay_logic[:type]
      raise "Unsupported decay type!" unless SUPPORTED_DECAY_TYPES.include?(@decay_type)

      @halflife = Float(decay_logic[:halflife])
      raise "Parameter :halflife in :decay_logic argument must be a valid real number!" unless @halflife
      raise "Parameter :halflife in :decay_logic argument must be > 1.0 for exponential decay!" if @decay_type == :exponential and @halflife <= 1.0
    end

    def remaining_value_at(coord)
      case @decay_type
      when :linear
        [ 1.0 - (coord - @initial_value) / (2 * @halflife), 0.0 ].max
      when :exponential
        @alpha ||= LN_2 / (@halflife - 1.0) # memoize to speed up following calculations
        x = @initial_value - coord + 1.0
        Math.exp(@alpha * (1.0 - x))
      else
      end
    end
  end

end
