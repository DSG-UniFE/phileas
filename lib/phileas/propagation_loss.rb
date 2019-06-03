require 'geo/coord'

require_relative './location'
require_relative './random_walk'

module Phileas

    class PropagationLoss
        C = 299792458.0 # speedl of light in vacuum

        # energy_detenction threshold is measured in dbm
        # the energy of a received signal should be higher than the threshold

        # the rx_power is measured in dbm
        def calc_rx_power(txPowerDbm, location_a, location_b)
        end

        def self.dbm_to_watt(p_dbm)
            p_watt = 10.0 ** ((p_dbm-30) / 10.0)
        end

        def self.watt_to_dbm(p_watt)
            p_dbm = 10.0 * Math::log10(p_watt) + 30.0
        end

        def self.watt_to_db(p_watt)
            p_db = watt_to_dbm(p_watt) -30
        end

        def self.db_to_dbm(p_db)
            p_dbm = p_db + 30
        end

        def self.dbm_to_db(p_dbm)
            p_db = p_dbm - 30
        end

        # distance is the distance between the antennas
        # frequency
        # gtx gain of transmitting antenna db
        # grx gain of receiving antenna db
        # c speed_light in vacuum m/s
        def self.freespace_path_loss(distance, frequency = 5.150e9, gtx = 1.0, grx = 1.0)
            20 * Math::log10(distance) + 20 * Math::log10(frequency) + 20 * 
                Math::log10((4 * Math::PI) / C) - gtx - grx
        end
    end


    class LogDistancePropagationLoss < PropagationLoss
        attr_reader :exponent, :reference_distance, :path_loss_reference 
        # from ns3
        # the reference loss at reference distance (dB). (Default is Friis at 1m with 5.15 GHz)
        # default reference distance is 1.0 m
        # default exponent is 3.0
        # default path_loss_reference is 46.6777 dB calculated according to free space path loss formulae

        # for more details
        # https://en.wikipedia.org/wiki/Log-distance_path_loss_model
        def initialize(exponent =3.0, reference_distance = 1.0,
            path_loss_reference = 46.6777)
             @exponent = exponent
             @reference_distance = reference_distance
             @path_loss_reference = path_loss_reference
        end


        def calc_rx_power(txPowerDbm, location_a, location_b)
            distance = location_a.distance(location_b)
            if distance <= @reference_distance
                return txPowerDbm - @path_loss_reference
            end
            path_loss_db = 10 * @exponent * Math::log10(distance/@reference_distance)
            rxc = -(@path_loss_reference) - path_loss_db
            #puts "Distance #{distance} m, reference-attenuation #{@path_loss_reference}dB, attenuation coefficient #{rxc}dB"
            return txPowerDbm + rxc
        end

    end

    class FriisPropagationLossModel < PropagationLoss
        C = 299792458.0
        attr_reader :frequency, :system_loss, :min_loss, :lambda
        # The minimum value (dB) of the total loss, used at short ranges.

        def initialize(frequency = 5.150e9, system_loss = 1.0, min_loss = 0.0)
            @frequency = frequency
            @system_loss = system_loss
            @min_loss = min_loss
            @lambda = C / frequency
        end

        #value in hertz
        def frequency(frequency)
            @frequency = frequency
            @lambda = C / frequency
        end

        # from ns3

        # Friis free space equation:
        # where Pt, Gr, Gr and P are in Watt units
        # L is in meter units.
        #
        #    P     Gt * Gr * (lambda^2)
        #   --- = ---------------------
        #    Pt     (4 * pi * d)^2 * L
        #
        # Gt: tx gain (unit-less)
        # Gr: rx gain (unit-less)
        # Pt: tx power (W)
        # d: distance (m)
        # L: system loss
        # lambda: wavelength (m)
        #

        def calc_rx_power(txPowerDbm, location_a, location_b)
            distance = location_a.distance(location_b)
            if distance <= (3 * @lambda)
                $stderr.puts("distance not within the far field region => inaccurate propagation loss value")
            end
            
            if distance <= 0.0
                return txPowerDbm - @min_loss
            end

            numerator = @lambda ** 2
            denominator = 16 * Math::PI * Math::PI * distance * distance * @system_loss
            path_loss_db = -10 * Math::log10(numerator / denominator)
            puts "Distance: #{distance}m loss: #{path_loss_db} dB"
            return txPowerDbm - [path_loss_db, @min_loss].max
        end


    end

  class TestHelper
    Energy_detenction_th = -96.0 #dbm of wifi_channgel
    OUTPUT_SIM_FOLDER = "simulation_results"
    attr_reader :location
    # tx_power in dbm
    def initialize(location = nil, tx_power = 20.0)
      @location = Geo::Coord.new(44.833416, 11.598771)
      @tx_power = tx_power
    end

    def test_log_model
      locations = RandomWalk.latitude_longitude(10000, @location)
      ld_pl = LogDistancePropagationLoss.new
      (locations.length() -1).times do |i|
        rxp = ld_pl.calc_rx_power(@tx_power, @location, locations[i])
        if rxp < Energy_detenction_th
          $stderr.puts "Trasmission is unfeasible rx_power is #{rxp}"
          Mm::Helper.coords_to_kml("#{OUTPUT_SIM_FOLDER}/test_log_propagation_loss.kml", locations[0, i])
          break
        end
      end
    end

      def test_friis_model
        locations = RandomWalk.latitude_longitude(10000, @location)
        f_pl = FriisPropagationLossModel.new
        (locations.length() -1).times do |i|
          rxp = f_pl.calc_rx_power(@tx_power, @location, locations[i])
          if rxp < Energy_detenction_th
            $stderr.puts "Trasmission is unfeasible rx_power is #{rxp}"
            Mm::Helper.coords_to_kml("#{OUTPUT_SIM_FOLDER}/test_friss_propagation_loss.kml", locations[0, i])
            break
          end
        end
    end
  end
end