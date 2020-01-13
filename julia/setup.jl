###########################
#
# This code starts from scratch to connect to the database and set up and populate some tables,
# to be used in the Julia tutorial Jupyter notebook "02-Imported and Computed Tables.ipynb"
#
# We assume that you have an appropriately configures dj_local_conf.json file in your working directory
#
###########################


cd("/Users/carlos/Github/datajoint/neuronex_workshop_2018/julia")  # Insert your own working directory here!
# Your directory should have the file "d2j.jl" in it.

using PyCall
dj = pyimport("datajoint")
include("d2j.jl")  # this is the code that converts datajoint fetch() results into Julia types

# RUN THE FOLLOWING ONLY ONCE:  Next time tou start up tou won't need it, the info will be saved in the local file
#
# dj.config.__setitem__("database.host", "datajoint00.pni.princeton.edu")
# dj.config.__setitem__("database.user", "YOUR PU ID")
# dj.config.__setitem__("database.password", "YOUR PU PASSWORD")
# dj.config.save_local()

dj.conn(reset=true)

schema_name = "brody_tutorial3"

schema = dj.schema(schema_name, py"locals()")


py"""
schema = $dj.schema($schema_name, locals())
"""

@pydef mutable struct Mouse <: dj.Manual
    definition = """
      mouse_id: int                  # unique mouse id
      ---
      dob: date                      # mouse date of birth
      sex: enum('M', 'F', 'U')       # sex of mouse - Male, Female, or Unknown/Unclassified
      """
end

# Julia doesn't have decorators, so we do the @schema decoration by hand in Python:
py"""
Mouse = schema($Mouse)
"""
# And then make sure the Julia variable is the new Python Mouse
Mouse = py"Mouse"


mouse = Mouse()


mouse.insert([
        Dict("mouse_id"=>0,   "dob"=>"2010-01-01", "sex"=>"M"),
        Dict("mouse_id"=>1,   "dob"=>"2020-01-01", "sex"=>"M"),
        Dict("mouse_id"=>2,   "dob"=>"2020-01-02", "sex"=>"F"),
        Dict("mouse_id"=>3,   "dob"=>"2020-01-03", "sex"=>"U"),
        Dict("mouse_id"=>5,   "dob"=>"2020-01-05", "sex"=>"M"),
        Dict("mouse_id"=>6,   "dob"=>"2020-01-05", "sex"=>"F"),
        Dict("mouse_id"=>7,   "dob"=>"2020-01-05", "sex"=>"F"),
        Dict("mouse_id"=>8,   "dob"=>"2018-01-05", "sex"=>"U"),
        Dict("mouse_id"=>100, "dob"=>"2017-01-05", "sex"=>"F")
        ], skip_duplicates=true)


@pydef mutable struct Session <: dj.Manual
    definition = """
    # Experiment session
    -> Mouse
    session_date               : date                         # date
    ---
    experiment_setup           : int                          # experiment setup ID
    experimenter               : varchar(100)                 # experimenter name
    """
end

py"""
Session = schema($Session)
"""
Session = py"Session"

session = Session()

data = Dict(
  "mouse_id" => 0,
  "session_date" => "2017-05-15",
  "experiment_setup" => 0,
  "experimenter" => "Edgar Y. Walker"
)

session.insert1(data, skip_duplicates=true)


data = [
    Dict(
  "mouse_id" => 0,
  "session_date" => "2017-05-19",
  "experiment_setup" => 0,
  "experimenter" => "Boaty McBoatFace"
    ),
    Dict(
  "mouse_id" => 100,
  "session_date" => "2017-05-25",
  "experiment_setup" => 0,
  "experimenter" => "Boaty McBoatFace"
    ),
    Dict(
  "mouse_id" => 5,
  "session_date" => "2017-01-05",
  "experiment_setup" => 0,
  "experimenter" => "Boaty McBoatFace"
    )

    ]

session.insert(data, skip_duplicates=true)

session
