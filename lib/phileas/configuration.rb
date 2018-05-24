# frozen_string_literal: true

require_relative './support/dsl_helper'


module Phileas

  # CHECK: do we actually need to consider a simulation warmup?
  module Configurable
    dsl_accessor :locations,
                 :data_sources,
                 :devices,
                 :user_groups,
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
      # convert datetimes and integers into floats
      @start_time      = @start_time.to_f
      @duration        = @duration.to_f
      @warmup_duration = @warmup_duration.to_f
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
