using PyCall
dj = pyimport("datajoint")

# RUN THE FOLLOWING ONLY ONCE:  Next time tou start up tou won't need it, the info will be saved in the local file
#
# dj.config.__setitem__("database.host", "datajoint00.pni.princeton.edu")
# dj.config.__setitem__("database.user", "YOUR PU ID")
# dj.config.__setitem__("database.password", "YOUR PU PASSWORD")
# dj.config.save_local()

dj.conn(reset=true)

schema = dj.schema("brody_tutorial2", py"locals()")


py"""
@$schema
class Mouse($dj.Manual):
      definition = '''
      mouse_id: int                  # unique mouse id
      ---
      dob: date                      # mouse date of birth
      sex: enum('M', 'F', 'U')       # sex of mouse - Male, Female, or Unknown/Unclassified
      '''
"""

mouse = py"Mouse()"


mouse.insert([
        Dict("mouse_id"=>1, "dob"=>"2020-01-01", "sex"=>"M"),
        Dict("mouse_id"=>2, "dob"=>"2020-01-02", "sex"=>"F"),
        Dict("mouse_id"=>3, "dob"=>"2020-01-03", "sex"=>"U"),
        Dict("mouse_id"=>5, "dob"=>"2020-01-05", "sex"=>"M"),
        Dict("mouse_id"=>6, "dob"=>"2020-01-05", "sex"=>"F"),
        Dict("mouse_id"=>7, "dob"=>"2020-01-05", "sex"=>"F")
        ], skip_duplicates=true)


py"""
schema = $dj.schema('brody_tutorial2', locals())

@schema
class Session($dj.Manual):
    definition = '''
    # Experiment session
    -> Mouse
    session_date               : date                         # date
    ---
    experiment_setup           : int                          # experiment setup ID
    experimenter               : varchar(100)                 # experimenter name
    '''

"""

session = py"Session"()

data = Dict(
  "mouse_id" => 1,
  "session_date" => "2017-05-15",
  "experiment_setup" => 0,
  "experimenter" => "Edgar Y. Walker"
)

session.insert1(data, skip_duplicates=true)


data = [
    Dict(
  "mouse_id" => 1,
  "session_date" => "2020-05-15",
  "experiment_setup" => 0,
  "experimenter" => "Boaty McBoatFace"
    ),
    Dict(
  "mouse_id" => 3,
  "session_date" => "2020-05-15",
  "experiment_setup" => 0,
  "experimenter" => "Boaty McBoatFace"
    )
    ]

session.insert(data, skip_duplicates=true)


py"""
schema = $dj.schema('brody_tutorial2', locals())

@schema
class Doodle($dj.Manual):
    definition = '''
    id :       int
    ---
    activity: longblob    # electric activity of the neuron
    '''
"""

doodle = py"Doodle"()
