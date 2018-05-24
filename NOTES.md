# Working assumptions

Resource measurement and allocation is unidimensional.


# Message Dissemination

Raw data messages and CRIO messages produced by a service instantiated in a Fog
device are disseminated _locally_: we define a maximum distance for the
dissemination of these messages. Instead, all IOs messages and CRIO messages
produced by a service instantiated in the Cloud do not have any dissemination
constraints.


# (Markov?) Decision Process

State:
- S: set of services currently allocated at time t
- D: set of devices available at time t
- A: allocations, i.e., associations Si-Dj

Actions:
- Association change <- this is something that an optimizer would do
- Service change <- this is something that a service provider would do
- Device change <- this is something that a platform provider would do

Assessment of an action:
- Total VoI at time t + tau, in which t is the time at which the action is
  taken and tau is the minumum time interval required to accurately evaluate
  the results of an action


# Optimization

Optimization objective:
- Total VoI maximization

Optimization search space:
- D x S: that is all devices available and all service types available
- Each cell is an integer representing the number of services of a given type instantiated on a device

Adaptive Quantum-based PSO?
- How to use the alpha knob?

