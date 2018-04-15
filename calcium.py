import datajoint as dj

schema = dj.schema('workshop_2pdemo')


@schema
class Session(dj.Manual):
    definition = """
    -> Mouse
    session              : smallint                     # session number
    ---
    session_date         : date                         # date
    person               : varchar(100)                 # researcher name
    scan_path            : varchar(255)                 # file path for TIFF stacks
    """
   
schema.spawn_missing_classes()
