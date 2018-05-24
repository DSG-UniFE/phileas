# frozen_string_literal: true


module Phileas
  class ServiceRepository
    def initialize
      @services = {}
    end

    def add(service:, content_type:)
      @services[content_type] ||= []
      @services[content_type] << service
    end

    def remove(service:, content_type:)
      raise "Unexisting content_type #{content_type}!" unless @services.has_key?(content_type)
      @services[content_type].delete(service)
    end

    # TODO: refactor this method into a sequence of 2 enumerators
    def with_interested_services_and_distance_from(content_type:, location:)
      raise "Unexisting content_type #{content_type}!" unless @services.has_key?(content_type)
      @services[content_type].each do |s|
        yield s, s.device_location.distance(location)
      end
    end
  end
end
