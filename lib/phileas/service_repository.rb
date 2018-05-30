# frozen_string_literal: true


module Phileas
  class ServiceRepository
    def initialize
      @services = []
    end

    def add(service)
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
  end
end
