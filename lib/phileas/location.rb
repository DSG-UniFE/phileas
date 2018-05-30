# frozen_string_literal: true

require 'geo/coord'


module Phileas

  class Location

    attr_reader :coords

    def initialize(latitude:, longitude:)
      @coords = Geo::Coord.new(latitude, longitude)
    end

    def distance(loc)
      @coords.distance(loc.coords)
    end
  end

  class LocationFactory
    def self.create(latitude:, longitude:)
      Location.new(latitude: latitude, longitude: longitude)
    end
  end

end
