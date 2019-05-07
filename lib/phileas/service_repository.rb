# frozen_string_literal: true


module Phileas
  class ServiceRepository
    def initialize
      @services = []
    end

    def add(service)
      # need to insert a check. it this service already exist it should not be activated
      @services << service
    end

    def remove(service)
      raise "Service #{service} not found in repository!" unless @services.include?(service)
      @services.delete(service)
    end

    def find_interested_services(input_content_type:, input_message_type:)
      interested_services = @services.select do |s|
        s.input_content_type == input_content_type and
          s.input_message_type == input_message_type
      end
      interested_services.each do |s|
        yield s
      end
    end

    def find_active_services(cur_time)
      active_services = @services.select do |s|
        s.activation_time&.to_time&.to_f <= cur_time
      end
      active_services
    end

    def length
      @services.length
    end
  end
end
