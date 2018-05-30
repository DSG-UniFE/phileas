# frozen_string_literal: true

require 'date'
require 'as-duration'

require_relative './support/dsl_helper'


module Phileas

  # CHECK: do we actually need to consider a simulation warmup?
  module Configurable
    dsl_accessor :locations,
                 :data_sources,
                 :devices,
                 :user_groups,
                 :service_types,
                 :service_activations,
                 :start_time,
                 :duration,
                 :warmup_duration
  end

  class Configuration
    include Configurable

    attr_accessor :filename

    def initialize(filename)
      @filename = filename
    end

    def end_time
      @start_time + @duration
    end

    def validate
      @start_time = @start_time&.to_time&.to_f
      raise "Invalid simulation start time!" unless @start_time

      @duration = @duration&.to_f
      raise "Invalid simulation duration!" unless @duration

      @warmup_duration = @warmup_duration&.to_f
      raise "Invalid simulation warmup duration!" unless @warmup_duration
    end

    def self.load_from_file(filename)
      # allow filename, string, and IO objects as input
      raise ArgumentError, "File #{filename} does not exist!" unless File.exists?(filename)

      # create configuration object
      conf = Configuration.new(filename)

      # take the file content and pass it to instance_eval
      conf.instance_eval(File.new(filename, 'r').read)

      # validate and finalize configuration
      conf.validate

      # return new object
      conf
    end
  end
end
