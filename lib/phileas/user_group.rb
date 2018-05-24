# frozen_string_literal: true


module Phileas

  class UserGroup
    def initialize(location:, user_dist:)
      @location = location
      @user_dist = user_dist
    end

    def users_at(time)
      # ASSUMPTION: we assume that user_dist is stationary, i.e., it doesn't
      # change over time - so (at least) for now we can just ignore the time
      # parameter.
      @user_dist.sample.to_i
    end
  end

end
