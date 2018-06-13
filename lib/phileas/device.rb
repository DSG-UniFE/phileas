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
      @total_resources_required += s.resource_requirements
      reallocate_resources
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def remove_service(s)
      raise "No such service" if @services.delete(s).nil?
      @total_resources_required -= s.resource_requirements
      reallocate_resources
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def available_resources
      [ NO_RESOURCES, @resource_pool - @total_resources_required ].max
    end

    private
      def reallocate_resources
        @services.each {|x| x.assign_resources(x.resource_requirements / @total_resources_required) }
      end
  end

  class EdgeDevice
    extend Forwardable
    def_delegators :@resource_assignment_policy, :add_service, :remove_service, :available_resources

    attr_reader :location

    def initialize(resources:, location:)
      @resources = resources
      @location = location
      # NOTE: for the moment, we use only a weighted resource assignment policy
      @resource_assignment_policy = WeightedFairResourceAssignmentPolicy.new(resources: @resources, location: @location)
    end

    def type
      :edge
    end
  end

  class CloudPlatform
    attr_reader :location

    def initialize
      @services = []
      @location = :cloud
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def add_service(s)
      raise "Service already existing" if @services.include?(s)
      @services << s
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def remove_service(s)
      raise "No such service" if @services.delete(s).nil?
    end

    # TODO: CHECK IF WE NEED TO KEEP TRACK OF CURRENT TIME HERE
    def available_resources
      Float::INFINITY
    end

    def type
      :cloud
    end
  end

  class DeviceFactory
    def self.create(type:, resources:, location:)
      case type
      when :edge
        EdgeDevice.new(resources: resources, location: location)
      when :cloud
        CloudPlatform.new
      else
        raise ArgumentError, "Unsupported device type #{type}!"
      end
    end
  end

end
