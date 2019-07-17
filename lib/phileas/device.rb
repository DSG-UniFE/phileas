# frozen_string_literal: true

require 'forwardable'


module Phileas

  class WeightedFairResourceAssignmentPolicy

    NO_RESOURCES = 0.0

    def initialize(resources:, location:)
      @resource_pool = resources
      @total_resources_required = NO_RESOURCES
      @services = []
      # need to keep historical data
      # a percentage of dropped packets in the last
      # time window
      @dropping_rate = 0.0
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

    #private

    # below is the original reallocate_resources method
    # we should maybe use this one other here
    # but it does not fit will with cores. We need to know the real number of core
    #def reallocate_resources
    #  # scales resources based on the device' resource pool
    #  # instead of using a 0..1 scale
    #  @services.each {|x| x.assign_resources((x.resource_requirements / @total_resources_required) * @resource_pool)  }
    #end
    # here we need to redefine the basic reallocate_resources method

    def reallocate_resources
        # scales resources based on the device' resource pool
        # instead of using a 0..1 scale
        allocable_resources = @resource_pool
        #puts "Device with #{@resource_pool} cores"
        @services.each do |x|
          unless allocable_resources === 0
            #puts "Resource requirements: #{x.resource_requirements}"
            service_resources_tmp = ((x.resource_requirements / @total_resources_required) * @resource_pool)
            #puts "Assigned tmp #{service_resources_tmp} allocable: #{allocable_resources}"
            unless service_resources_tmp == allocable_resources
              #puts "Service is allocable"
              service_resources = service_resources_tmp.round % allocable_resources
            else
              service_resources = allocable_resources
            end
            allocable_resources -= service_resources
            #puts "Resources assigned: #{service_resources} "
            x.assign_resources(service_resources)
          else
            x.assign_resources(0.0)
            x.resources_assigned = 0.0
          end
        end
      end

      def reallocate_resources_with_speedup
        # scales resources based on the device's resource pool also assigning
        allocable_resources = @resource_pool
        #puts "**** Device #{self} with #{@resource_pool} cores - Running #{@services.length} services ****"
        # update total_resources_required before performing the allocation algorithm
        rr = 0.0
        #@total_resources_required = rr
        @total_resources_required = @services.inject(0) {|sum, x| sum += x.resource_requirements}
        allocated_cores = 0.0
        @services.each do |x|
          log_base = x.speed_up[:base]
          log_exp = x.speed_up[:exp]
          unless allocable_resources === 0
            #puts "Resource assigned: #{x.resources_assigned}\t required_requirements: #{x.resource_requirements}\t total_required: #{@total_resources_required}"
            # x.required_scale = 0 if ( x.resources_assigned + x.required_scale ) <= 0
            # zero check
            unless @total_resources_required == 0.0
               service_resources_tmp = ( (x.resource_requirements.to_f / @total_resources_required.to_f) * @resource_pool)
            else
              service_resources_tmp = 0.0
            end

            #puts "Assigned tmp #{service_resources_tmp} allocable: #{allocable_resources}"
            if service_resources_tmp == 0.0
              service_resources = 0.0
            else
              if service_resources_tmp > allocable_resources && allocable_resources > 1.0
                service_resources = (service_resources_tmp - (service_resources_tmp % allocable_resources)).round.to_f
              elsif allocable_resources == 1.0
                service_resources = 1.0
              else
                service_resources = service_resources_tmp.round.to_f
              end
            end
            allocable_resources -= service_resources.to_f
            #puts "Resources assigned: #{service_resources}"
            x.numerical_speed_up = service_resources ** Math::log(log_exp, log_base) - x.resources_assigned ** Math::log(log_exp, log_base)
            x.assign_resources(service_resources)
            allocated_cores +=  service_resources
            x.resources_assigned = service_resources.to_f
          else
            x.assign_resources(0.0)
            x.resources_assigned = 0.0
            x.numerical_speed_up = 0.0 ** Math::log(log_exp, log_base) - x.resources_assigned ** Math::log(log_exp, log_base)
          end
          #puts "**** Desired speedup #{x.numerical_speed_up} for service #{x}"
        end
        # calculate resource requirements
        #resource_requirements = 0.0
        #puts "**** Allocated cores #{allocated_cores}/#{@resource_pool} for #{@services.length} services ***"
        raise "Error, there is an error in the allocation algorithm. Allocated #{allocated_cores} " if allocated_cores.to_f > @resource_pool.to_f
        # we probably do not need to update total_resoureces_required here
        resources_check = 0.0
        @services.each do |x|
          resources_check += x.resources_assigned
          puts "#{x.output_content_type} is using #{x.resources_assigned}/#{@resource_pool}"
        end
        puts "**** End Allocated cores ***"
    end

  def reallocate_res_greedy
    allocable_resources = @resource_pool
    allocated_cores = 0.0
    allocation_map = []
    @services.each do |x|
      unless allocable_resources === 0
        #puts "Requirements #{x.resource_requirements.to_f } for Service: #{x.output_content_type}"
        service_resources_tmp = ( (x.resource_requirements.to_f / @total_resources_required.to_f) * @resource_pool).round
        if service_resources_tmp > allocable_resources 
          service_resources = allocable_resources.round
        else
          service_resources = service_resources_tmp.round
        end
        #puts "About to assign #{service_resources} for Service: #{x.output_content_type}"
        allocable_resources -= service_resources.round
        x.assign_resources(service_resources)
        allocated_cores +=  service_resources
        x.resources_assigned = service_resources.to_f
        allocation_map << service_resources
      end
    end
    # increment randomly resource assigned to the minimum services
    min_index = allocation_map.each_with_index.min 
    #puts "Allocation_map #{allocation_map} Still to allocate #{allocable_resources} min_index: #{min_index}"
    while allocable_resources.round > 0.0 do 
      service_index = min_index.sample
      s_assigned = @services[service_index].resources_assigned + 1.0
      @services[service_index].assign_resources(s_assigned)
      @services[service_index].resources_assigned = s_assigned 
      allocable_resources -= 1
      allocated_cores += 1
    end
    puts "**** Allocated cores #{allocated_cores}/#{@resource_pool} for #{@services.length} services ***"
    raise "Error! Allocated #{allocated_cores}" if allocated_cores.to_f > @resource_pool.to_f
    resources_check = 0.0
    @services.each do |x|
      resources_check += x.resources_assigned
      puts "#{x.output_content_type} is using #{x.resources_assigned}/#{@resource_pool}"
    end
    @total_resources_required = @services.inject(0) {|sum, x| sum += x.resources_assigned}
    puts "**** End Allocated cores total_resource_required is #{@total_resources_required} ***"
  end
  end

  class EdgeDevice
    extend Forwardable
    def_delegators :@resource_assignment_policy, :add_service, :remove_service, :available_resources

    attr_reader :location, :resources, :resource_assignment_policy

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
