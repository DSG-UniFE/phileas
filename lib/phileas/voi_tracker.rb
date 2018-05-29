# frozen_string_literal: true


module Phileas

  class ValueDecayCalculator
    NO_DECAY = Object.new.tap {|x| def x.remaining_value_at(coord); 1.0; end }

    def initialize(initial_value:, decay_logic:)
      raise "To implement!"
    end

    def remaining_value_at(coord)
      raise "To implement!"
    end
  end

end
