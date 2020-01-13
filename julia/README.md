# Using datajoint with Julia

This directory is an attempt to take the tutorial material from [Edgar Walker's Neuronexus 2018](../../..) tutorial workshop on [DataJoint](https://datajoint.io/) and translate it into something that can run within [Julia](https://julialang.org/). The first three tutorial notebooks [00-ConnectingToDatabase.ipynb](./00-ConnectingToDatabase.ipynb), [01-Getting started with DataJoint.ipynb](01-Getting%20started%20with%20DataJoint.ipynb), and [02-Imported and Computed Tables.ipynb](02-Imported%20and%20Computed%20Tables.ipynb) are enough to get you going. They roughly cover the same material as found in [DataJoint's main tutorial web pages ](https://tutorials.datajoint.io/beginner/building-first-pipeline/python/first-table.html), but now all within Julia.

The goal here is to be able to set up and work with DataJoint from Julia as quickly as possible. No attempts at elegance or efficiency are made. The main approach is to use Julia's [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) package, which allows interoperability between Python and Julia, so as to make all the necessary Python function calls from within Julia.

While the elegance is low, the approach seems to work. People who want to live in Julia but interoperate with others using DataJoint with Matlab or Python will be able to do so.

The tutorials are a work in progress right now; when done, you should be able to simply start from scratch, in Julia, with tutorial 0, and go on from there. We do assume that there is already set up a DataJoint server that you have access to.





# Known Issues

* While Python function calls that use dialog boxes work fine within a Julia REPL in the terminal or in Atom, they cause an error in Julia Jupyter notebooks.  This means that in a Julia Jupyter notebook, `delete()` cannot be called without setting `config`'s `safemode` to false, and `conn()` also cannot be called without setting the username and password into the local config file first.
* displaying the ERD works in Julia Jupyter notebooks, but does not work in Julia REPL at terminal or Atom
