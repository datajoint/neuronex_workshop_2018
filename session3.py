import datajoint as dj
import numpy as np

username = dj.config['database.user']
schema = dj.schema('{}_pipeline_session3'.format(username))



# Table definitions

@schema
class Mouse(dj.Manual):
    definition = """
    # Experimental animals
    mouse_id             : int                          # Unique animal ID
    ---
    dob=null             : date                         # date of birth
    sex="unknown"        : enum('M','F','unknown')      # sex
    """
    
@schema
class Session(dj.Manual):
    definition = """
    # Experiment session
    -> Mouse
    session_date               : date                         # date
    ---
    experiment_setup           : int                          # experiment setup ID
    experimenter               : varchar(100)                 # experimenter name
    """
   
@schema
class Neuron(dj.Imported):
    definition = """
    -> Session
    ---
    activity: longblob    # electric activity of the neuron
    """
    def make(self, key):
        # use key dictionary to determine the data file path
        data_file = "data/data_{mouse_id}_{session_date}.npy".format(**key)

        # load the data
        data = np.load(data_file)

        # add the loaded data as the "activity" column
        key['activity'] = data

        # insert the key into self
        self.insert1(key)

        print('Populated a neuron for mouse_id={mouse_id} on session_date={session_date}'.format(**key))
        
        
@schema
class ActivityStatistics(dj.Computed):
    definition = """
    -> Neuron
    ---
    mean: float    # mean activity
    stdev: float   # standard deviation of activity
    max: float     # maximum activity
    """
    
    def make(self, key):
        activity = (Neuron() & key).fetch1('activity')    # fetch activity as NumPy array

        # compute various statistics on activity
        key['mean'] = activity.mean()   # compute mean
        key['stdev'] = activity.std()   # compute standard deviation
        key['max'] = activity.max()     # compute max
        self.insert1(key)
        print('Computed statistics for mouse_id {mouse_id} session_date {session_date}'.format(**key))

        
@schema
class SpikeDetectionParam(dj.Lookup):
    definition = """
    sdp_id: int      # unique id for spike detection parameter set
    ---
    threshold: float   # threshold for spike detection
    """
    contents = [(0, 0.5), (1, 0.9)]
    
    
@schema
class Spikes(dj.Computed):
    definition = """
    -> Neuron
    -> SpikeDetectionParam
    ---
    spikes: longblob     # detected spikes
    count: int           # total number of detected spikes
    """
    def make(self, key):
        print('Populating for: ', key)

        activity = (Neuron() & key).fetch1('activity')
        threshold = (SpikeDetectionParam() & key).fetch1('threshold')

        above_thrs = (activity > threshold).astype(np.int)   # find activity above threshold
        rising = (np.diff(above_thrs) > 0).astype(np.int)   # find rising edge of crossing threshold
        spikes = np.hstack((0, rising))    # prepend 0 to account for shortening due to np.diff

        count = spikes.sum()   # compute total spike counts
        print('Detected {} spikes!\n'.format(count))

        # save results and insert
        key['spikes'] = spikes
        key['count'] = count
        self.insert1(key)
        
    

# Insert the following data into the table
mouse_data = [
 {'dob': "2017-03-01", 'mouse_id': 0, 'sex': 'M'},
 {'dob': "2016-11-19", 'mouse_id': 1, 'sex': 'M'},
 {'dob': "2016-11-20", 'mouse_id': 2, 'sex': 'unknown'},
 {'dob': "2016-12-25", 'mouse_id': 5, 'sex': 'F'},
 {'dob': "2017-01-01", 'mouse_id': 10, 'sex': 'F'},
 {'dob': "2017-01-03", 'mouse_id': 11, 'sex': 'F'},
 {'dob': "2017-05-12", 'mouse_id': 100, 'sex': 'F'}
]

session_data = [
 {'experiment_setup': 0,
  'experimenter': 'Edgar Y. Walker',
  'mouse_id': 0,
  'session_date': "2017-05-15"},
 {'experiment_setup': 0,
  'experimenter': 'Edgar Y. Walker',
  'mouse_id': 0,
  'session_date': "2017-05-19"},
 {'experiment_setup': 1,
  'experimenter': 'Fabian Sinz',
  'mouse_id': 5,
  'session_date': "2017-01-05"},
 {'experiment_setup': 100,
  'experimenter': 'Jacob Reimer',
  'mouse_id': 100,
  'session_date': "2017-05-25"},
 {'mouse_id': 100,
    'session_date': "2017-06-01",
    "experiment_setup": 1,
    "experimenter": "Jacob Reimer"}
]


import sys
stdout = sys.stdout
# temporary suppress print
sys.stdout = None

Mouse.insert(mouse_data, skip_duplicates=True)
Session.insert(session_data, skip_duplicates=True)
Neuron.populate()
ActivityStatistics.populate()
Spikes.populate()

sys.stdout = stdout