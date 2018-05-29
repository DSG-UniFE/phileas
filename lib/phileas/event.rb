# frozen_string_literal: true

module Phileas

  class Event

    ET_CRIO_MESSAGE_ARRIVAL        =   0
    ET_IO_MESSAGE_ARRIVAL          =   1
    ET_RAW_DATA_MESSAGE_ARRIVAL    =   2
    ET_RAW_DATA_MESSAGE_GENERATION =   3
    ET_SERVICE_ACTIVATION          =   4
    ET_SERVICE_SHUTDOWN            =   5
    ET_END_OF_SIMULATION           = 100

    # let the comparable mixin provide the < and > operators for us
    include Comparable

    attr_reader :type, :data, :time

    def initialize(type, data, time)
      @type        = type
      @data        = data
      @time        = time
    end

    def <=> (event)
      @time <=> event.time
    end

    def to_s
      "Event type: #{@type}, data: #{@data}, time: #{@time}"
    end

  end

end
