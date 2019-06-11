require 'erv'
require 'geo/coord'
require 'ruby_kml'


module Phileas
  class RandomWalk
    # one dimesional RandomWalk implementation 
    # inspired by https://github.com/egtann/random-walk
    def self.one_dimension(limits, array_length, step = 1)
      starting_point = Random.rand(limits)
      output_array = [starting_point]
      (array_length - 1).times do
        add_or_subtract = Random.rand(-step..step)
        end_point = output_array.last + add_or_subtract
        if end_point <= limits.max && end_point >= limits.min
          output_array << end_point
        else
          output_array << output_array.last
        end
      end
      return output_array
    end

    # two dimensional RandomWalk implmentation
    # x,y plot similar to other simulator (NS3)
    def self.two_dimension(array_length, step = 1, starting_x = 0, starting_y = 0)
      x = Array.new(array_length, 0)
      y = Array.new(array_length, 0)
      x[0] = starting_x
      y[0] = starting_y
      (array_length - 1).times do |i|
        val = Random.rand(1..4)
        case val
        when 1
          x[i] = x[i -1] + 1
          y[i] = y[i - 1] 
        when 2 
          x[i] = x[i - 1] - 1
          y[i] = y[i - 1] 
        when 3 
          x[i] = x[i - 1] 
          y[i] = y[i - 1] + 1
        else 
          x[i] = x[i - 1] 
          y[i] = y[i - 1] - 1
        end
      end
      return [x,y]
    end

    # latitude and longitude RandomWalk implmentation (missing altitude)
    # x,y plot similar to other simulator (NS3)
    def self.latitude_longitude(array_length, starting_location)
      starting_location = starting_location
      gaussian_erv = ERV::RandomVariable.new(distribution: :gaussian ,args: { mean: 0.00005, sd: 0.00005 })
      lats = [starting_location.lat]
      lons = [starting_location.lon]
      positions = []
      (array_length - 1).times do |i|
        m1 = rand >= 0.5 ? 1 : -1
        m2 = rand >= 0.5 ? 1 : -1
        r = gaussian_erv.sample
        val = Random.rand(0..2)
        case val
        when 0
          lats[i] = (lats[i -1] + r * m1)
          lons[i] = lons[i-1]
        when 1
          lats[i] = lats[i -1]
          lons[i] = (lons[i-1] + r * m2)
        else
          lats[i] = lats[i -1]
          lons[i] = (lons[i-1] + r * m2)
        end
        positions << Geo::Coord.new(lats[i], lons[i])
        end
      return positions
    end


  # azimuth is expressed in degrees
  def self.lat_lon_direction(array_length, starting_location, mean_distance = 50.0, sd_distance = 12.5)
    starting_location = starting_location
    erv_distance = ERV::RandomVariable.new(distribution: :gaussian, 
      args: { mean: mean_distance, sd: sd_distance })
    lats = [starting_location.lat]
    lons = [starting_location.lon]
    positions = []
    current_location = starting_location
    # select a different angle at each iteration. Do not conside
    (array_length - 1).times do |i|
      direction = Random.rand(0..2*Math::PI)
      distance = erv_distance.sample
      next_position = current_location.endpoint(distance, Helper::to_degree(direction))
      positions << next_position
      current_location = next_position
      end
    return positions
  end



  # azimuth is expressed in degrees
  def self.lat_lon_bound(array_length, starting_location, max_distance = nil, mean_distance = 50.0, sd_distance = 12.5)
    starting_location = starting_location
    erv_distance = ERV::RandomVariable.new(distribution: :gaussian, 
      args: { mean: mean_distance, sd: sd_distance })
    lats = [starting_location.lat]
    lons = [starting_location.lon]
    positions = []
    current_location = starting_location
    # select a different angle at each iteration. Do not conside
    puts "Max distance: #{max_distance}"
    (array_length - 1).times do |i|
      while true do
        direction = Random.rand(0..2*Math::PI)
        distance = erv_distance.sample
        next_position = current_location.endpoint(distance, Helper::to_degree(direction))
        if max_distance.nil? || next_position.distance(starting_location) <= max_distance
          positions << next_position
          current_location = next_position
          break
        end
        $stderr.puts "RandomWalk: Out of bound"
      end
      end
    return positions
  end
  
end

  
  class Helper
    # This method takes as input a filename and an Array of coordinates
    # and it translates the coordinates into a kml file
    def self.coords_to_kml(filename, coords)
      kml = KMLFile.new()
      # select a different color randomly
      style = KML::Style.new(:id => "mmStyle")
      is = KML::IconStyle.new
      hex_color = "ff%06x" % (rand * 0xffffff)
      is.color= hex_color
      is.color_mode = "normal"
      style.icon_style=is
      folder = KML::Folder.new(:name => "#{filename}")
      folder.features << style
      # create the placemarkers
      coords.length.times do |i|
        folder.features << KML::Placemark.new(
          :name => i,
          :style_url => "#mmStyle",
          :geometry => KML::Point.new(:coordinates => {:lat => coords[i].lat, :lng => coords[i].lon})
        )
      end
      kml.objects << folder
      #puts kml.render
      kml.save(filename)
    end

    def self.to_rad(degree)
      rads = degrees * Math::PI / 180.0 
    end

    def self.to_degree(rads)
      degrees = rads / Math::PI * 180.0
    end

  end


  class Test
    def self.test_helper()
      g = Geo::Coord.new(50.004444, 36.231389)
      coords = RandomWalk.latitude_longitude(1000, g)
      Helper.coords_to_kml("test_rw.kml", coords)
    end

    def self.test_helper_2()
      g = Geo::Coord.new(50.004444, 36.231389)
      coords = RandomWalk.lat_lon_direction(1000, g)
      Helper.coords_to_kml("test_rw_d.kml", coords)
    end


    def self.test_helper_3()
      g = Geo::Coord.new(50.004444, 36.231389)
      coords = RandomWalk.lat_lon_bound(10000, g, 250.0)
      Helper.coords_to_kml("test_rw_bound.kml", coords)
    end

  end
end
