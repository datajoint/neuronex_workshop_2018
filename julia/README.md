# Using datajoint with Julia

This directory is an attempt to take the tutorial material from [Edgar Walker's Neuronexus 2018](../../..) tutorial workshop on [DataJoint](https://datajoint.io/) and translate it into something that can run within [Julia](https://julialang.org/).

This is an initial attempt: the goal is to be able to set up and work with DataJoint from Julia as quickly as possible. No attempts at elegance or efficiency are made. The main approach is to use Julia's [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) package, which allows interoperability between Python and Julia, so as to make all the necessary Python function calls from within Julia.

While the elegance is low, the approach seems to work. People who want to live in Julia but interoperate with others using DataJoint with Matlab or Python will be able to do so.

The tutorials are a work in progress right now; when done, you should be able to simply start from scratch, in Julia, with tutorial 0, and go on from there. We do assume that there is already set up a DataJoint server that you have access to.





