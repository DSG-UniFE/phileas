# frozen_string_literal: true

require 'forwardable'


module Phileas

  class WeightedFairResourceAssignmentPolicy
    NO_RESOURCES = 0.0

    def initialize(resources:, location:)
      @resource_pool = resources
      @total_resources_required = NO_RESOURCES
      @services = []
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def add_service(s)
      raise "Service already existing" if @services.include?(s)
      @services << s
      @total_resources_required += s.required_resources
      reallocate_resources
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    # TODO: IMPLEMENT THIS
    def remove_service(s)
      raise "No such service" if @services.delete(s).nil?
      @total_resources_required -= s.required_resources
      reallocate_resources
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def available_resources
      [ NO_RESOURCES, @resource_pool - @total_resources_required ].max
    end

    private
      def reallocate_resources
        @services.each {|x| x.assign_resources(x.required_resources) / @total_resources_required }
      end
  end

  class Device
    extend Forwardable
    def_delegators :@resource_assignment_policy, :add_service, :remove_service, :available_resources

    def initialize(resource_pool:)
      # NOTE: for the moment, we use only a weighted resource assignment policy
      @resource_assignment_policy = WeightedFairResourceAssignmentPolicy.new(resource_pool)
      # TODO: CHECK IF WE NEED TO KEEP TRACK OF RESOURCE POOL DIRECTLY ON DEVICE
      # @resource_pool = resource_pool
    end
  end

end
