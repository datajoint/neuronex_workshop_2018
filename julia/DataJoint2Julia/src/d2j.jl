#################################################
#
#  THE d2j() FUNCTION
#
#  Formatting the results of fetch() for Julia
#
#################################################



import Dates

# List of data types that are not automatically converted, defining how to convert
# First column is Python name for the data type class, second column is corresponding Julia type
conversion_list = Dict{String, Any}(
      "str"     =>   String,
      "date"    =>   Dates.Date,
)

"""
function d2j(x)

Takes x, the output of a datajoint fetch() call, and converts it from PyObject formal to Julia format

= PARAMETERS:

- x      Must be a PyObject that is the output of a datajoint fetch() call

= RETURNS:

- out    The same data that was in x, but now in Julia format. In general this will
         be an Array of type Any, but if x was a single column of unique type, or a list
         of single columns, each of unique type, then those may come back as the corresponding
         type (e.g., Array of Int or Array of String).

= EXAMPLE CALL:

```jldoctest
d2j(mouse.fetch())

7×3 Array{Any,2}:
 1  2019-12-19  "M"
 2  2019-12-20  "U"
 3  2019-12-21  "M"
 4  2020-01-03  "F"
 5  2020-01-05  "M"
 6  2020-01-05  "F"
 7  2020-01-05  "F"

d2j(mouse.fetch("mouse_id"))

7-element Array{Int64,1}:
 1
 2
 3
 4
 5
 6
 7


```
"""
function d2j(x::PyObject)
      out = x
      if x.__class__.__name__ == "ndarray" &&  !isempty(x)
            shape = x.shape
            # if this is a vector, try to flatten to see if that
            # converts it from PyObject.
            if length(shape)==1 && py"hasattr"(x, "flatten")
                  # Let'see if this does it for us:
                  out = x.flatten()
                  if !(typeof(x) <: PyObject)
                        # No longer a PyObject, we might be done!
                        # we'll go through d2j() again just in case
                        # the elements of out need conversion, but otherwise
                        # we're set.
                        return d2j(out)
                  end
                  # Flattening didn't solve it, proceed to go element by element
            end
            out = Array{Any}(undef, shape)
            my_type_list = Array{Type}(undef, 1, 0)
            for i=1:length(out)
                  # These get statements do autoconvert to Julia data types
                  out[i] = d2j(get(x, i-1))
                  # Except for integers it seems, which stay as PyObjects but can be
                  # converted as follows:
                  if typeof(out[i]) <: PyObject && py"hasattr($(out[i]), 'flatten')"
                        out[i] = d2j(out[i].flatten())
                  end
                  if findfirst(typeof(out[i]) .== my_type_list)==nothing
                      my_type_list = hcat(my_type_list, typeof(out[i]))
                  end
            end
            if length(my_type_list)==1
                out = convert(Array{my_type_list[1]}, out)
            end
            return out
      elseif x.__class__.__name__ == "ndarray" &&  isempty(x)
            return []
      elseif (x.__class__.__name__ == "list" || x.__class__.__name__ == "void" ) && !isempty(x)
            out = Array{Any}(undef, length(x))
            for i=1:length(x)
                out[i] = d2j(get(x, i-1))
            end
            return out
      elseif x.__class__.__name__ == "int64"  && py"hasattr"(x, "flatten")
            out = x.flatten()[1]
      end
      return out
end

function d2j(x::Array{PyObject,1})
      # We have a single column requested: most likely only a single data type
      out = x
      if !isempty(x)
            classname = x[1].__class__.__name__
            # Do we know how to convert this data type?
            if haskey(conversion_list, classname)
                  # We do know!
                  # first a special case: a data type where each
                  # element should go back in through function d2j()
                  if conversion_list[classname] == d2j
                        my_type_list = Array{Type}(undef, 1, 0)  # list of types found inside converted x
                        out = Array{Any}(undef, length(x))
                        for i=1:length(x)
                              out[i] = d2j(x[i])
                              if findfirst(typeof(out[i]) .== my_type_list)==nothing
                                    # add to list of found types
                                    my_type_list = hcat(my_type_list, typeof(out[i]))
                              end
                        end
                        if length(my_type_list)==1
                            out = convert(Array{my_type_list[1]}, out)
                        end
                  else # Default is to try to convert the whole column
                        try
                              out = convert(Array{conversion_list[classname]}, x)
                        catch
                        end
                  end
            end
      end
      return out
end

function d2j(x::Array{Dict{Any,Any}})
      # User probably set as_dict=true
      # We'll go through each Dict, and each of its values, applying d2j() to it
      for i=1:length(x)
            for k in keys(x[i])
                  x[i][k] = d2j(x[i][k])
            end
      end
      return x
end


function d2j(x::Array)
      out = x
      if eltype(x) <: Array || eltype(x) == Any
            # We have multiple columns requested as multiple outputs
            # We'll convert each one separately
            out = Array{Any}(undef, size(x))
            for i=1:length(x)
                  out[i] = d2j(x[i])
            end
      end
      return out
end

# If we don't know what to do with it, just return it
function d2j(x)
      return x
end

conversion_list["ndarray"] = d2j
conversion_list["list"]    = d2j
conversion_list["void"]    = d2j
