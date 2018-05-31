# frozen_string_literal: true


module Phileas

  class UserGroup

    attr_reader :interests, :location

    def initialize(location:, user_dist:, interests:)
      @interests = interests
      @location  = location
      @user_dist = user_dist
    end

    def users_at(time)
      # ASSUMPTION: we assume that user_dist is stationary, i.e., it doesn't
      # change over time - so (at least) for now we can just ignore the time
      # parameter.
      @user_dist.sample.to_i
    end

    def users_interested(content_type)
      @interests.each do |interest|
        if interest[:content_type] == content_type[:content_type]
          return interest[:share]
        end
      end
    end
  end

  class UserGroupFactory
    def self.create(location:, user_dist:, interests:)
      UserGroup.new(location: location, user_dist: user_dist, interests: interests)
    end
  end

end
