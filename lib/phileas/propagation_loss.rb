module Phileas
    class PropagationLoss

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
        def initiliaze(exponent =3.0, reference_distance = 1.0,
             path_loss_renfence = 46.6777)
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
            rxc = -@path_loss_reference - path_loss_db{distance}
            puts "Distance #{distance}, reference-attenuation #{@path_loss_reference}dB, attenuation coefficient #{rxc}dB"
            return txPowerDbm + rxc
        end
    end
end