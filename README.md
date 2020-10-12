# Phileas

Phileas is a discrete event simulator for Fog Computing scenario. It allows the realistic modelling of Internet of Things (IoT) sensors, devices, and users to allow the reproducible evaluation of Fog applications in a realistic environment.

Phileas is based on 6 main concepts: locations, data sources, devices, service types, service activations, and user groups. Phileas models locations in a realistic fashion, associating geographical latitude and longitude coordinates to them. All entities modeled by Phileas, such as data sources, devices, and users are placed in a specific location. Geodesic distance between locations is calculated according to Vincenty’s formula, which leverages an accurate ellipsoidal model of the Earth and is significantly more accurate than the simpler and more popular Haversine formula.

## Installation

For starting clone this repository:
    $ git clone https://github.com/DSG-UniFE/phileas.git

And then execute to install required gems:

    $ bundle

Or you can install them inside the phileas directory:

    $ bundle install --path vendor/bundle

## Getting started

Before running a simulation, you need to define a configuration file containing the description of the scenario to simulate. The scenario is a Ruby configuration file that contains the description of locations, data sources, devices, user groups, and services.

Take a look at the `example` folder to familiarize yourself with a configuration file.

To run the example scenario `example/example_scenario.conf`
	$ bundle exec exe/phileas example/example_scenario.conf

## Development

Phileas is currenlty under development.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[DSG-UniFE]/phileas.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# References

1. Filippo  Poltronieri,  Cesare  Stefanelli,  Niranjan  Suri,  and  Mauro  Tortonesi.Phileas:  Asimulation-based approach for the evaluation of value-based fog services.  In 2018 IEEE23rd International Workshop on Computer Aided Modeling and Design of CommunicationLinks and Networks (CAMAD), pages 1–6. IEEE, 2018.