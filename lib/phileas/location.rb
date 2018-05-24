# frozen_string_literal: true

require 'forwardable'
require 'geo/coord'


module Phileas

  class Location
    extend Forwardable

    def_delegator :@coords, :distance

    def initialize(latitude:, longitude:)
      @coords = Geo::Coord.new(latitude, longitude)
    end
  end

  class LocationFactory
    def self.create(latitude:, longitude:)
      Location.new(latitude: latitude, longitude: longitude)
    end
  end

end
