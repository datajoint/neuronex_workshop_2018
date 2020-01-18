module DataJoint2Julia

using PyCall
import Dates

export dj, d2j, d2jDecorate, user_choice

const dj = PyNULL()

include("d2j.jl")

orig_config = Dict(
    "database.host"=>"",
    "database.user"=>"",
    "database.password"=>""
)


pushfirst!(PyVector(pyimport("sys")."path"), "../../datajoint-python")
if PyVector(pyimport("sys")."path")[1] != ""
    # Then the following line is PyCall-ese for "add the current directory to the Python path"
    pushfirst!(PyVector(pyimport("sys")."path"), "")
end




############################################################
#
#  Decorating various DataJoint functions for Julia purposes
#
############################################################


## =========  decorating table definitions  ==========

"""
   Decorates a passed function such that its output will be put through d2j()
   before being returned to the user.  This is intended specifically for
   decorating DataJoint's fetch() function: d2j() reformats the output of
   fetch from PyObjects to Julia types.
"""
function fetchDecorate(origFetch)
   function decorated(vars... ; kwargs...)
      out = d2j(origFetch(vars...; kwargs...))
      return out
   end
   return decorated
end

##

"""
function d2jDecorate(dj_class_ex, schema)

Immediately after defining a table, put it through this function

"""
function d2jDecorate(dj_class_ex, schema)
   if typeof(dj_class_ex) != PyObject || dj_class_ex.__class__.__name__ != "OrderedClass"
      error("I only know how to deal with datajoint's PyObject OrderedClass members")
   end
   name = dj_class_ex.__name__
   py"""
   $$name = $schema($dj_class_ex)
   """

   out = py"$$name"
   out.fetch = fetchDecorate(out.fetch)
   return out
end


## =========  decorating dj.conn()  ==========

"""
function connCheckUserDialogItems()

Checks to see whether "database.host", "database.user", "database.password" are
set in dj.config, if not, prompts user for them and sets them.

Python dialog boxes seem to work fine in REPL but not un Julia Jupyter notebooks;
this function is used, before running dj.conn(), to first run through Julia dialog
boxes so no error occurs

SIDE EFFECTS:

After running this function, each of "database.host", "database.user",
"database.password" in dj.config will be guaranteed to be a non-empty string.

"""
function connCheckUserDialogItems()
    for k in ["database.host", "database.user", "database.password"]
        if dj.config.__getitem__(k) == nothing || isempty(dj.config.__getitem__(k))
            ans = ""
            while isempty(ans)
                print("Please enter ", k, ": ")
                if k == "database.password"  # special case, hiding typed text
                    sb = Base.getpass("")      # put user text into secret buffer
                    ans = chomp(read(sb, String))  # turn that into a string
                    Base.shred!(sb)    # thus losing all security, then shred secret buffer to rpevent warning message
                else   # don't need to hide typed text
                    ans = chomp(readline())
                end
            end
            dj.config.__setitem__(k, ans)
        end
    end
end
##

"""
Used to decorate dj.conn() to first make sure
user dialog boxes occur in Julia
"""
function connDecorate(origconn)
    function decorated(vars... ; kwargs...)
        connCheckUserDialogItems()
        out = origconn(vars...; kwargs...)
        return out
    end
    return decorated
end

"""
function user_choice(prompt::String; default="no")

Prints prompt on the REPL and then waits for the user to type in either "yes"
or "no" (case insensitive). An empty response returns the default.
Any other response repeats the prompt.

Optional parameter default MUST be either "yes" or "no" (case sensitive).

RETURNS: either "yes" or "no"

"""
function user_choice(prompt::String; default="no")
   if default == "yes"
      print(prompt, " [Yes, no]: ")
   elseif default == "no"
      print(prompt, " [yes, No]: ")
   else
      error("default should be either \"yes\" or \"no\".")
   end

   str = lowercase(chomp(readline()))
   if isempty(str)
      str = default
   end

   if str != "yes" && str != "no"
      str = user_choice(prompt, default=default)
   end
   return str
end

function schemaDecorate(origSchema)
    function decoratedSchema(vars... ; kwargs...)
        out = origSchema(vars... ; kwargs...)
        out.drop = schemaDecorateDrop(out, out.drop)
        return out
    end
    return decoratedSchema
end

function schemaDecorateDrop(self, origDrop)
    function decoratedDrop(force=false, vars... ; kwargs...)
        # if the schema doesn't even exist on the server, do nothing, return:
        if !self.exists
            # from schema.py:
            py"""
            import logging

            logger = logging.getLogger('datajoint.schema')
            logger.info("Schema named `{database}` does not exist. Doing nothing.".format(database=$self.database))
            """
            return
        end
        # If we're in safemode, prompt the user whether this is ok:
        if !force && dj.config.__getitem__("safemode")
            if user_choice("Proceed to delete entire schema `$(self.database)` ?", default="no") == "no"
                return
            end
        end
        origDrop(true, vars...; kwargs...)
    end
    return decoratedDrop
end




function __init__()
    copy!(dj, pyimport("datajoint"))

    dj.conn = connDecorate(dj.conn)
    dj.schema = schemaDecorate(dj.schema)
end

end
