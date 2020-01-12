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
function d2j(x)
      out = x
      if typeof(x) <: PyObject && x.__class__.__name__ == "ndarray" &&  !isempty(x)
            # We are getting each row of the table as a row of x.
            # This means different columns will have different data types
            nrows = length(x)
            ncols = length(get(x, 0))
            out = Array{Any}(undef, nrows, ncols)
            my_type_list = Array{Type}(undef, 1, 0)
            for i=1:nrows
                  for j=1:ncols
                        # These get statements do autoconvert to Julia data types
                        out[i,j] = get(get(x, i-1), j-1)
                        # Except for integers it seems, which stay as PyObjects but can be
                        # converted as follows:
                        if typeof(out[i,j]) <: PyObject && py"hasattr($(out[i,j]), 'flatten')"
                              out[i,j] = out[i,j].flatten()[1]
                        end
                        if findfirst(typeof(out[i,j]) .== my_type_list)==nothing
                            my_type_list = hcat(my_type_list, typeof(out[i,j]))
                        end
                  end
            end
            if length(my_type_list)==1
                out = convert(Array{my_type_list[1]}, out)
            end
            return out
      elseif typeof(x) <: PyObject && x.__class__.__name__ == "list" && !isempty(x)
            out = Array{Any}(undef, length(x))
            for i=1:length(x)
                out[i] = d2j(x[i])
            end
            return out
      elseif typeof(x) <: PyObject && x.__class__.__name__ == "int64" && py"hasattr($x, 'flatten')"
            out = x.flatten()[1]
      elseif typeof(x) <: Array{PyObject,1}
            # We have a single column requested: most likely only a single data type
            if !isempty(x)
                  classname = x[1].__class__.__name__
                  # Do we know how to convert this data type?
                  if haskey(conversion_list, classname)
                        # We do know!
                        # first a special case: a data type where each
                        # element should go back in through function d2j()
                    if conversion_list[classname] == d2j
                            out = Array{Any}(undef, length(x))
                            for i=1:length(x)
                                out[i] = d2j(x[i])
                            end
                    else # Default is to try to convert the whole column
                            out = convert(Array{conversion_list[classname]}, x)
                        end
                  end
            end
      elseif typeof(x) <: Array && eltype(x) <: Array
            # We have multiple columns requested as multiple outputs
            # We'll convert each one separately
            out = Array{Any}(undef, length(x))
            for i=1:length(x)
                  out[i] = d2j(x[i])
            end
      end
      return out
end


conversion_list["ndarray"] = d2j
conversion_list["list"]    = d2j
conversion_list["void"]    = d2j
