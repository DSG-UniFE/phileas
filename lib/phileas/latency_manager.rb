# frozen_string_literal: true

require 'erv'


module Phileas
  # TODO: check how the 'geo/coord' gem calculates distances
  PROXIMITY_THRESHOLD = 500.meters

  class LatencyManager
    def initialize
      # TODO: use truncated gaussian to model Cloud-to-Cloud communication latency
      @c2c_latency_rv = ERV::RandomVariable.new(distribution: :gaussian, args: { mean: 0.02, sd: 0.001 })
      # TODO: use gaussian mixture to model Cloud-to-edge communication latency
      @c2e_latency_rv = ERV::RandomVariable.new(distribution: :gaussian, args: { mean: 0.02, sd: 0.001 })
      # TODO: use long tail distribution to model edge-to-edge communication latency
      @e2e_latency_rv = ERV::RandomVariable.new(distribution: :gaussian, args: { mean: 0.02, sd: 0.001 })
    end

    def calculate_trasmission_time_between(loc1, loc2)
      res = nil
      if cloud_to_edge_communication(loc1, loc2)
        # sample with truncation for non-positive values
        until (res = @c2e_latency_rv.next) > 0.0; end
      elsif cloud_to_cloud_communication(msg, serv)
        # sample with truncation for non-positive values
        until (res = @c2c_latency_rv.next) > 0.0; end
      else # edge to edge communication
        if distance <= PROXIMITY_THRESHOLD
          # sample with truncation for non-positive values
          until (res = @e2e_latency_rv.next) > 0.0; end
        end
      end
      return res
    end

    private
      def cloud_to_edge_communication(loc1, loc2)
        (loc1 == :cloud and loc2 != :cloud) or
        (loc1 != :cloud and loc2 == :cloud)
      end

      def cloud_to_cloud_communication(loc1, loc2)
        loc1 == :cloud and loc2 == :cloud
      end

      def edge_to_edge_communication(loc1, loc2)
        loc1 != :cloud and loc2 != :cloud
      end

  end
end
