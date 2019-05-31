require 'geo/coord'
require 'mm'
require_relative './location'

module Phileas

    class PropagationLoss

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
    end

    class LogDistancePropagationLoss
        attr_reader :exponent, :reference_distance, :path_loss_reference 
        # from ns3
        # the reference loss at reference distance (dB). (Default is Friis at 1m with 5.15 GHz)
        # default reference distance is 1.0 m
        # default exponent is 3.0
        # default path_loss_reference is 46.6777 dB
        def initialize(exponent =3.0, reference_distance = 1.0,
            path_loss_reference = 46.6777)
             @exponent = exponent
             @reference_distance = reference_distance
             @path_loss_reference = path_loss_reference
        end


        def calc_rx_power(txPowerDbm, location_a, location_b)
            distance = location_a.distance(location_b)
            if distance <= @reference_distance
                return txPowerDbm - m_referenceLoss
            end
            path_loss_db = 10 * @exponent * Math::log10(distance/@reference_distance)
            rxc = -(@path_loss_reference) - path_loss_db
            puts "Distance #{distance} m, reference-attenuation #{@path_loss_reference}dB, attenuation coefficient #{rxc}dB"
            return txPowerDbm + rxc
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

        def run
            locations = Mm::RandomWalk.latitude_longitude(10000, @location)
            ld_pl = LogDistancePropagationLoss.new
            (locations.length() -1).times do |i|
                rxp = ld_pl.calc_rx_power(@tx_power, @location, locations[i])
                if rxp < Energy_detenction_th
                    $stderr.puts "Trasmission is unfeasible rx_power is #{rxp}"
                    Mm::Helper.coords_to_kml("#{OUTPUT_SIM_FOLDER}/test_propagation_loss.kml", locations[0, i])
                    break
                end
            end
        end
    end
end