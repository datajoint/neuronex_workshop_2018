# Using datajoint with Julia

This directory is a completed draft of taking the tutorial material from [Edgar Walker's Neuronexus 2018](../../..) tutorial workshop on [DataJoint](https://datajoint.io/) and translating it into something that can run within [Julia](https://julialang.org/). The first three tutorial notebooks [00-ConnectingToDatabase.ipynb](./00-ConnectingToDatabase.ipynb), [01-Getting started with DataJoint.ipynb](01-Getting%20started%20with%20DataJoint.ipynb), and [02-Imported and Computed Tables.ipynb](02-Imported%20and%20Computed%20Tables.ipynb) are enough to get you going. They roughly cover the same material as found in [DataJoint's main tutorial web pages ](https://tutorials.datajoint.io/beginner/building-first-pipeline/python/first-table.html), but now all within Julia.

The goal here is to be able to set up and work with DataJoint from Julia as quickly as possible. No attempts at elegance or efficiency are made. The main approach is to use Julia's [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) package, which allows interoperability between Python and Julia, so as to make all the necessary Python function calls from within Julia. This has the advantage that the extra code is extremely slight-- the vast majority of the codebase to run in Julia is the Python datajoint codebase.

While the elegance could be greater, [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) is powerful enough that it works pretty well. People who want to live in Julia but interoperate with others using DataJoint with Matlab or Python will be able to do so.  

For example, **this datajoint Python code**

```
((Mouse() and 'dob = "2017-05-15"') * Session).fetch()
```

is this functionally identical, and almost syntatically identical, **datajoint ulia code**

```
((Mouse() and "dob = '2017-05-15'") * Session).fetch()
```

And **this datajoint Python code**
```
@schema
class Neuron(dj.Imported):
    definition = """
    -> Session
    ---
    activity: longblob    # electric activity of the neuron
    """
    def make(self, key):
        data_file = "data/data_{mouse_id}_{session_date}.npy".format(**key)
        data = np.load(data_file)
        key['activity'] = data
        self.insert1(key)
        print('Populated a neuron for mouse_id={mouse_id} on session_date={session_date}'.format(**key))
```

becomes this pretty similar **datajoint Julia code**

```
@pydef mutable struct Neuron <: dj.Imported
    definition = """
    -> Session
    ---
    activity: longblob    # electric activity of the neuron
    """
    
    function make(self, key)
        filename = "../data/data_$(key["mouse_id"])_$(key["session_date"]).npy"
        key["activity"] = npzread(filename)
        self.insert1(key)
        println("Populated a neuron for mouse_id=$(key["mouse_id"]) on session_date=$(key["session_date"])")
    end
end
py"""
Neuron = schema($Neuron)
"""
Neuron = py"Neuron"
```





# Known Issues

* While Python function calls that use dialog boxes work fine within a Julia REPL in the terminal or in Atom, they cause an error in Julia Jupyter notebooks.  This means that in a Julia Jupyter notebook, `delete()` and `drop()` cannot be called without setting `config`'s `safemode` to false, and `conn()` also cannot be called without setting the username and password into the local config file first, and `set_password()` cannot be called at all (you need to do it from a REPL).
* displaying the ERD works in Julia Jupyter notebooks, but does not work in Julia REPL at terminal or Atom. (Currently it's not working for me in Python from the terminal either.)

## Improvements TO-DO
* `d2j()` should be in a Module, not as a bare function for `include()`.
* We should decorate each table class in Julia (in addition and on top of decorating with `schema` in Python), so as to 
  * (1) automatically wrap `fetch()` calls in `d2j()` to return Julia types; 
  * (2) overload the Python function calls that need dialog boxes with Julia functions, so that they not only play nice in REPLs but also in Jupyter notebooks.  These functions include `dj.conn()`, `dj.set_password`, `dj.delete()`, and `dj.drop()`.  One idea would be to start a pull request to modify datajoint's code for those Python functions so that optional parameters can supply what the dialog boxes would have ask for, and thus avoid the use of Python dialog boxes. 
