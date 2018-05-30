require 'test_helper'
require 'phileas/voi_tracker'

describe Phileas::ValueDecayCalculator do
  it "should allow" do
    Phileas::ValueDecayCalculator.new(initial_value: 100,
                                      decay_logic: { type: :exponential, halflife: 1000.0 })
  end
end
