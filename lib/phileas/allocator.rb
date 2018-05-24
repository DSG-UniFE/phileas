# frozen_string_literal: true

require 'forwardable'


module Phileas
  class ClosestDevicePolicy
    # TODO: does strategy pattern use class or instance methods?
    def allocate(service:, devices:)
      data_source_location = service.data_source_location
      devices.sort_by {|d| distance(data_source_location, d.location) }.first
    end
  end

  class Allocator
    extend Forwardable

    # implements the allocate method
    def_delegator :@allocation_policy, :allocate

    def initialize(allocation_policy:)
      @allocation_policy = allocation_policy
    end
  end
end
