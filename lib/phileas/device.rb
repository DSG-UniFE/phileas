# frozen_string_literal: true

require 'forwardable'


module Phileas

  class WeightedFairResourceAssignmentPolicy

    NO_RESOURCES = 0.0

    # each service component should have a total 
    # number of resources equals to one of following element
    # check if 0 should be here
    FEASIBILE_PARTITION = [0,1, 2, 3, 4, 6, 8, 9, 12, 16]
    INFEASIBLE_ALLOCATION = [9, 6, 1]
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
        @services.sort_by {|el| -(el[:resource_requirements])}.each do |x|
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
            # here service_resources is the total number of assigned resource
            raise "#{service_resources} is not a feasible partition" unless FEASIBILE_PARTITION.include? service_resources
            allocable_resources -= service_resources.to_f
            # puts "Resources assigned: #{service_resources}"
            # just calculate the speedup here
            x.numerical_speed_up = service_resources ** Math::log(log_exp, log_base) - x.resources_assigned ** Math::log(log_exp, log_base)
            x.assign_resources(service_resources)
            allocated_cores +=  service_resources
            x.resources_assigned = service_resources.to_f
          else
            # 0.0 value should be feasible here --- it means the application is not running
            # or scheduled on this device
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
    allocated_cores = 0
    allocation_map = []
    # this one sort by resource_requirements, which is fair
    #@services.sort_by! {|el| -(el.resource_requirements)}.each do |x|
    # trying sorting for required_scale instead of resource requirements
    @services.sort_by! {|el| -(el.required_scale)}.each do |x|
    #@services.each do |x|
    puts "Dropping rate for #{x.output_content_type} is #{x.dropping_rate}"
      unless allocable_resources === 0
        #puts "Requirements #{x.resource_requirements.to_f } for Service: #{x.output_content_type}"
        service_resources_tmp = ( (x.resource_requirements.to_f / @total_resources_required.to_f) * @resource_pool).round
        if service_resources_tmp >= allocable_resources 
          service_resources = allocable_resources.round
        else
          service_resources = service_resources_tmp.round
        end
            # here service_resources is the total number of assigned resource
        unless FEASIBILE_PARTITION.include? service_resources
          puts "Infeasible partition generated"
          # please refactor the code here
          closest_partition = FEASIBILE_PARTITION.min_by{|x| (service_resources - x).abs}
          puts "Checking if #{closest_partition} is feasible with resources #{allocable_resources}"
          if closest_partition > allocable_resources
            # get the closet allocable partition
            closest_partition = FEASIBILE_PARTITION.
              select{|x| x <= allocable_resources }.min_by{|x| (service_resources - x).abs}
            puts "partition generated #{closest_partition} on #{allocable_resources}"
          end
          service_resources = closest_partition
        end
        
        raise "#{service_resources} is not a feasible partition" unless FEASIBILE_PARTITION.include? service_resources

        #puts "About to assign #{service_resources} for Service: #{x.output_content_type}"
        allocable_resources -= service_resources.to_f
        # fix this bug
        x.assign_resources(service_resources.to_f)
        x.resources_assigned = service_resources.to_f
        allocated_cores +=  service_resources.to_f
        allocation_map << service_resources
      else
        x.assign_resources(0.0)
        x.resources_assigned = 0.0
      end
    end
    # increment randomly resource assigned to the minimum services
    min_index = allocation_map.each_with_index.min 
    puts "Allocation_map #{allocation_map} Still to allocate #{allocable_resources} min_index: #{min_index}"
    if allocable_resources > 0
      s_assigned = @services[min_index[1]].resources_assigned
      @services[min_index[1]].assign_resources(s_assigned + 1.0)
      @services[min_index[1]].resources_assigned = s_assigned + 1.0
      allocation_map[min_index[1]] += 1.0
      allocable_resources -= 1.0
      allocated_cores += 1.0
    end

    puts "Before g_check allocated_cores #{allocated_cores}"
    #geometrical constraint check here
    while (allocation_map & INFEASIBLE_ALLOCATION).size == INFEASIBLE_ALLOCATION.size do
      puts "Allocation not respecting geometrical constraints"
      # get max index and then decrement
      max_index = allocation_map.each_with_index.max
      if max_index[0] > 0.0 
        s_assigned = @services[max_index[1]].resources_assigned
        prior = s_assigned
        while ! (FEASIBILE_PARTITION.include? (s_assigned -1.0)) do
          s_assigned -= 1.0
        end
        if s_assigned > 0.0
          to_assign = s_assigned - 1.0
          puts "Prior was #{prior} now is #{to_assign}"
          @services[max_index[1]].assign_resources(to_assign)
          @services[max_index[1]].resources_assigned = to_assign
          allocation_map[max_index[1]] -= (prior - to_assign) 
          allocable_resources += (prior - to_assign)
          allocated_cores -= (prior - to_assign)
        end
      end
    end

=begin
    max_iteration = @services.length * 2
    iter = 0
    while (allocable_resources > 0 && iter < max_iteration) do 
      puts "Allocable cores #{allocable_resources}"
      service_index = min_index.sample
      s_assigned = @services[service_index].resources_assigned + 1.0
      if FEASIBILE_PARTITION.include? s_assigned
        @services[service_index].assign_resources(s_assigned)
        #@services[service_index].resources_assigned = s_assigned 
        allocable_resources -= 1
        allocated_cores += 1
        puts "Updated partition for service index: #{service_index}"
      end
      iter +=1
    end
=end

    puts "**** Allocated cores #{allocated_cores}/#{@resource_pool} for #{@services.length} services ***"
    raise "Error! Allocated #{allocated_cores}" if allocated_cores.to_f > @resource_pool.to_f
    resources_check = 0.0
    @services.each do |x|
      # reset also the required scale
      x.required_scale = 0.0
      resources_check += x.resources_assigned
      puts "#{x.output_content_type} is using #{x.resources_assigned}/#{@resource_pool}"
    end
    @total_resources_required = @services.inject(0) {|sum, x| sum += x.resources_assigned}
    puts "**** End Allocated cores, allocated: #{resources_check} ****" #total_resource_required is #{@total_resources_required} ***"
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
