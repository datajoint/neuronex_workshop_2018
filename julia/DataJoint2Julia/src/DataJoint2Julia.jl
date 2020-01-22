module DataJoint2Julia

using PyCall
import Dates

export dj, d2j, user_choice, open_schemas
export d2jDecorate

const dj           = PyNULL()
const origERD      = PyNULL()
const open_schemas = PyNULL()

include("d2j.jl")


# pushfirst!(PyVector(pyimport("sys")."path"), "../../datajoint-python")
# if PyVector(pyimport("sys")."path")[1] != ""
#    # Then the following line is PyCall-ese for "add the current directory to the Python path"
#    pushfirst!(PyVector(pyimport("sys")."path"), "")
# end


"""
function d2jDecorate(dj_class_ex, schema)

Immediately after defining a table, put it through this function

"""
function d2jDecorate(dj_class_ex, schema)
   if typeof(dj_class_ex) != PyObject || dj_class_ex.__class__.__name__ != "OrderedClass"
      error("I only know how to deal with datajoint's PyObject OrderedClass members")
   end
   name = dj_class_ex.__name__

   if !schema.exists
       error("Schema $(schema.database) does not exist on the server")
   end
   # os = convert(Dict{String,Any}, open_schemas)
   # if !haskey(os, schema.database)
   #     error("Internal DataJoint2Julia error: can't find a record in open_schemas of schema `$schema.database`")
   # end

   py"""
   # $$name = $open_schemas[$(schema.database)]($dj_class_ex, context=locals())
   # print(locals())
   $$name = $schema($dj_class_ex, context=locals())
   """

   out = py"$$name"
   return out
end


############################################################
#
#  Decorating various DataJoint functions for Julia purposes
#
############################################################


# =========== decorating Python Class methods ===============

"""
Decoration of Python class Methods should happen within the Python
environment, because it is Python that knows that class Methods, when
called from an object, need to have self inserted as the first argument.

Since Julia doesn't have objects, it is much more complicated in Julia. Even in
Python, trying decorate bound methods upon instance creation sometimes works but
sometimes not: for example, it does not work for __call__() (upon decoration, of
an instance obj's __call__ method, obj() calls the UNdecorated method while
obj.__call__() calls the decorated method -- weird!)

Thus we use the following Python function to decorate Python class Methods
within Python.
"""

py"""
def __decorateMethod(origMethod, *, preMethod=None, postMethod=None):
   '''decorateMethod(origMethod, *, preMethod=None, postMethod=None):

   Python function:
   Decorates a class method, adding possible preprocessing and postprocessing.
   If there is no postprocessing, the output of the decorated method will be
   the original method's output. If there IS post-processing then the output
   of the decorated method will be the post-processing function's output

   :param     origMethod     The original class method to be decorated
   :kw_param  preMethod      If other than None, should be a function that can
                             take self, followed by whatever arguments origMethod
                             Any outputs from this function are ignored.
   :kw_param  postMethod     If other than None, should be a function that can
                             take self, followed by whatever output the origMethod
                             produced, followed by whatever further arguments
                             origMethod took. The output from this postMethod
                             function will become the decorated method's final
                             output

   :return                   the decorated Method

   EXAMPLE CALL (within Python environment):

      Example.method = decorateMethod(Example.method_,  \
      preMethod =lambda self,      *args, **kwargs: print("I'm pre-decorated with self = ", self) \
      postMethod=lambda self, out, *args, **kwargs: print("I'm post-ddecorated with out = ", out))

   '''
   def decorated(self, *args, **kwargs):
      if preMethod != None:
         preMethod(self, *args, **kwargs)
      out = origMethod(self, *args, **kwargs)
      if postMethod == None:
         return out
      else:
         newout = postMethod(self, out, *args, **kwargs)
         return newout
   return decorated

"""

decorateMethod = py"__decorateMethod"


# =========== decorating functions ===============

"""
decorateFunction(origFunction; preFunction=None, postFunction=None):

Decorates a Julia function method, adding possible preprocessing and postprocessing.
If there is no postprocessing, the output of the decorated function will be
the original function's output. If there IS post-processing then the output
of the decorated function will be the post-processing function's output

:param     origFunction   The original function to be decorated

:kwparam   preFunction    If other than nothing, should be a function that can
                          take whatever arguments origFunction took.
                          Any outputs from this function are ignored.

:kwparam   postFunction   If other than nothing, should be a function that can
                          take whatever output the origFunction
                          produced, followed by whatever further arguments
                          origFunction took. The output from this postFunction
                          function will become the decorated function's final
                          output

:return                   the decorated function

EXAMPLE CALL:

   myfun = decorateFunction(myfun; preFunction = (vars... ; kwargs...) -> print("I'm pre-decorated"),
        postFunction=(out, vars... ; kwargs...) -> print("I'm post-decorated with out = ", out))

"""
function decorateFunction(originalFunction; preFunction=nothing, postFunction=nothing)
    function decorated(vars... ; kwargs...)
        if preFunction != nothing
            preFunction(vars... ; kwargs...)
        end
        out = originalFunction(vars... ; kwargs...)
        if postFunction==nothing
            return out
        else
            newout = postFunction(out, vars... ; kwargs...)
            return newout
        end
        return decorated
    end
end



## =========  decorating table definitions  ==========




## =========  decorating dj.conn()  ==========

"""
function connCheckUserDialogItems()

Checks to see whether "database.host", "database.user", "database.password" are
set in dj.config, if not, prompts user for them and sets them.

Python dialog boxes seem to work fine in REPL but not un Julia Jupyter notebooks;
this function is used, before running dj.conn(), to first run through Julia dialog
boxes so no error occurs

= PARAMETERS:

- Ignores all passed parameters

= SIDE EFFECTS:

After running this function, each of "database.host", "database.user",
"database.password" in dj.config will be guaranteed to be a non-empty string.

"""
function connCheckUserDialogItems(vars... ; kwargs...)
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

RETURNS: either "yes" or "no", guaranteed to be in lower case.

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
        # py"""
        # $open_schemas[$out.database] = $origSchema($out.database, locals())
        # """
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

"""
When evaluating the ERD, it should be done in the same Python namespace
(this module) where the schemas and tables were defined.
"""
function myERD(source)
    return py"$origERD($source)"
end




function __init__()
    # When experimenting, we use our local datajoint. Remove the next
    # line to use the system datajoint.
    pushfirst!(PyVector(pyimport("sys")."path"), "../../datajoint-python")
    # Next line is PyCall,jl trick for persistent variables in precompiled modules
    copy!(dj, pyimport("datajoint"))
    copy!(origERD, dj.ERD)

    # Do dj.conn user dialogs in Julia:
    dj.conn = decorateFunction(dj.conn, preFunction = connCheckUserDialogItems)

    # Do schema.drop() user dialogs in Julia:
    dj.schema = schemaDecorate(dj.schema)

    # Evaluate ERD in Python namespace local to this module:
    dj.ERD = myERD

    # Have jfetch() be the same as fetch() but wrapped with d2j()
    # We don't decorate the Fetch object's __call__ function directly
    # because fetch() is called internally a bunch of times, and those
    # internal calls should not go through d2j()
    py"""
    def __jfetch(self, *args, **kwargs):
       return $d2j(($dj.fetch.Fetch(self))(*args, **kwargs))

    setattr($dj.expression.QueryExpression, 'jfetch', __jfetch)

    def __jfetch1(self, *args, **kwargs):
       return $d2j(($dj.fetch.Fetch1(self))(*args, **kwargs))

    setattr($dj.expression.QueryExpression, 'jfetch1', __jfetch1)

    """

end

end
