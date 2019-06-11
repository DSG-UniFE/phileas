# frozen_string_literal: true
require 'erv'

require_relative './random_walk'

module Phileas

  class UserGroup
    # to find user_group interest in a service in a certain location
    PROXIMITY_THRESHOLD = 500.0 # meters
    CHANGE_OF_POSITION = 100 # change of position for the user group during the simulation

    attr_reader :interests, :location, :trajectory
    attr_accessor :multiply_factor

    def initialize(location:, user_dist:, interests:)
      @interests = interests
      @location  = location
      @user_dist = ERV::RandomVariable.new(user_dist)
      #@trajectory = RandomWalk.latitude_longitude(CHANGE_OF_POSITION, location.coords)
      @trajectory = RandomWalk.lat_lon_direction(CHANGE_OF_POSITION, location.coords, 1000.0, 100.0, 35.0)
      @trajectory_count = 1
    end

    def users_at(time)
      # ASSUMPTION: we assume that user_dist is stationary, i.e., it doesn't
      # change over time - so (at least) for now we can just ignore the time
      # parameter.
      @user_dist.sample.to_i
    end

    def move_users()
      unless trajectory[@trajectory_count].nil?
        lat = trajectory[@trajectory_count].lat
        lon = trajectory[@trajectory_count].lon
        @location = LocationFactory.create(latitude: lat, longitude: lon)
        @trajectory_count += 1
      end
      nil
    end

    def users_interested(content_type)
      users = 0.to_f
      @interests.each do |interest|
        if interest[:content_type] == content_type[:content_type]
          users +=  interest[:share] * users_at(nil) 
        end
      end
      users
    end

    def users_interested(content_type, location)
      users = 0.to_f
      @interests.each do |interest|
        if interest[:content_type] == content_type && nearby?(location)
          users +=  interest[:share] * users_at(nil) 
        end
      end
      users
    end

    # add a monkey path to update user share
    def update_interest(content_type, multiply_factor)
      @interests.each do |interest|
        if interest[:content_type] == content_type
          # normalize the multuply_factor to the current interest
          min, max = [interest[:share], multiply_factor].minmax
          puts "*** Before share was #{interest[:share]} ***"
          normalized_factor =  (multiply_factor - min) / (max)
          interest[:share] += normalized_factor
          puts "*** Now share is #{interest[:share]} factor: #{normalized_factor}***"
        end
      end
    end

    def nearby?(location)
      @location.distance(location) <= PROXIMITY_THRESHOLD ? true : false
    end

  end

  class UserGroupFactory
    def self.create(location:, user_dist:, interests:)
      UserGroup.new(location: location, user_dist: user_dist, interests: interests)
    end
  end

end
