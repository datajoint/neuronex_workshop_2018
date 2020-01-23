module DataJoint2Julia

using PyCall
import Dates

export dj, d2j, julia_user_choice, d2jDecorate, my_input, decorateMethod

const dj             = PyNULL()
const origERD        = PyNULL()

decorateMethod       = PyNULL()
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

   py"""
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


function declarePythonEnvironmentFunctions()
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
def __decorateMethod(origMethod, *, newMethod=None, preMethod=None, postMethod=None):
   '''decorateMethod(origMethod, *, newMethod=None, preMethod=None, postMethod=None):

   Python function:
   Decorates a class method, adding possible preprocessing and postprocessing.
   If there is no postprocessing, the output of the decorated method will be
   the original method's output. If there IS post-processing then the output
   of the decorated method will be the post-processing function's output

   :param     origMethod     The original class method to be decorated

   :kw_param  newMethod      If other than None, should be a function that can
                             take self, followed by whatever arguments origMethod
                             takes.  When this is not None, preMethod and postMethod
                             are ignored, and the final output of the decoratedMethod
                             is the output of newMethod

   :kw_param  preMethod      If other than None, should be a function that can
                             take self, followed by whatever arguments origMethod
                             takes. Any outputs from this function are ignored.

   :kw_param  postMethod     If other than None, should be a function that can
                             take self, followed by whatever output the origMethod
                             produced, followed by whatever further arguments
                             origMethod took. The output from this postMethod
                             function will become the decorated method's final
                             output

   :return                   the decorated Method

   EXAMPLE CALL (within Python environment):

      Example.method = __decorateMethod(Example.method_,  \
      preMethod =lambda self,      *args, **kwargs: print("I'm pre-decorated with self = ", self) \
      postMethod=lambda self, out, *args, **kwargs: print("I'm post-ddecorated with out = ", out))

   '''
   def decorated(self, *args, **kwargs):
      if newMethod != None:
          return newMethod(self, *args, **kwargs)

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

end





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
function julia_user_choice(prompt::String, choices=("yes", "no"); default=nothing)

Prompts the user for confirmation.  The default value, if any, is capitalized.
:param prompt: Information to display to the user.
:param choices: an iterable of possible choices.
:param default: default choice. If nothing, user MUST answer with an explicit choice.
:return: the user's choice, guaranteed to be in lower case.

"""
function julia_user_choice(prompt::String, choices=("yes", "no"); default=nothing)
    @assert default==nothing || any(default .== choices) "default must be one of the choices"
    prompt = prompt * " Z["
    for ch in choices
        prompt = prompt * (ch==default ? titlecase(ch) : ch) * ", "
    end
    prompt = prompt[1:end-2] * "] "

    str = ""
    while !any(str .== choices)
        print(prompt)
        str = lowercase(chomp(readline()))
        if isempty(str)
            str = default
        end
    end
    return str
end


function my_input(prompt::String="")
    print(prompt)
    return chomp(readline())
end


"""
preSchemaDrop(self, force=false, vars... ; kwargs...)

self should be a schema object. Returns true if ok to drop the schema
from the MySQL server; returns false if not.
"""
function preSchemaDrop(self, force=false, vars... ; kwargs...)
    # if the schema doesn't even exist on the server, do nothing, return:
    if !self.exists
        # from schema.py:
        py"""
        import logging
        logger = logging.getLogger('datajoint.schema')
        logger.info("Schema named `{database}` does not exist. Doing nothing.".format(database=$self.database))
        """
        return false
    end
    # If we're in safemode and not forced, prompt the user whether this is ok:
    if !force && dj.config.__getitem__("safemode")
        if julia_user_choice("Proceed to delete entire schema `$(self.database)` ?", default="no") == "no"
            return false
        end
    end
    # ok, all is good, go ahead and drop:
    return true
end



"""
When evaluating the ERD, it should be done in the same Python namespace
(this module) where the schemas and tables were defined.
"""
function myERD(source)
    return py"$origERD($source)"
end




function __init__()
    declarePythonEnvironmentFunctions()
    copy!(decorateMethod, py"__decorateMethod")

    # When experimenting, we use our local datajoint. Remove the next
    # line to use the system datajoint.
    pushfirst!(PyVector(pyimport("sys")."path"), "../../datajoint-python")
    # Next line is PyCall,jl trick for persistent variables in precompiled modules
    copy!(dj, pyimport("datajoint"))
    copy!(origERD, dj.ERD)

    # Put datajointJulia Python package into the path
    pushfirst!(PyVector(pyimport("sys")."path"), "./DataJoint2Julia/src/")
    Jdj = pyimport("datajointJulia")

    py"""
    def newTableDrop(self, *args, **kwargs):
         $Jdj.table.drop(self, *args, user_choice_fn = $julia_user_choice, **kwargs)

    def newTableDelete(self, *args, **kwargs):
        $Jdj.table.delete(self, *args, user_choice_fn = $julia_user_choice, **kwargs)

    """
    dj.table.Table.drop   = py"newTableDrop"
    dj.table.Table.delete = py"newTableDelete"

    # Do dj.conn user dialogs in Julia:
    dj.conn = decorateFunction(dj.conn, preFunction = connCheckUserDialogItems)

    # Replace Python user_choice() with equivalent Julia user_choice(),
    # to avoid issues in Jupyter notebooks:
    # dj.utils.user_choice = user_choice
    # And reload dj modules that use user_choice(), so they now point to the
    # new version of the function:
    # pyimport("importlib")."reload"(dj.admin)
    # pyimport("importlib")."reload"(dj.table)
    # pyimport("importlib")."reload"(dj.migrate)

    # datajoint imports submodule schema.py, but then from there imports
    # class Schema as schema; this hides the submodule name and we cannot
    # reload it. So, do schema.drop() user dialogs in Julia:
    py"""
    def __newSchemaDrop(origSchemaDrop):
        def decorated(self, force=False, *args, **kwargs):
            flag = $preSchemaDrop(self, force, *args, **kwargs)
            if not flag:
                return
            origSchemaDrop(self, True, *args, **kwargs)
        return decorated
    """
    dj.schema.drop = py"__newSchemaDrop"(dj.schema.drop)

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

    # same for jfetch1() and fetch1()
    def __jfetch1(self, *args, **kwargs):
       return $d2j(($dj.fetch.Fetch1(self))(*args, **kwargs))
    setattr($dj.expression.QueryExpression, 'jfetch1', __jfetch1)

    """

end

end  # MODULE END
