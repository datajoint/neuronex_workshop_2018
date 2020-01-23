"""
Python package doing some minimal adaptations of datajoint functions,
adding optional parameters to use alternative user dialog box functions.
Introduced so that Julia users can call datajoint Python methods while
avoiding Python dialog boxes, which appear to crash in Juia Jupyter notebooks

Will put in a pull request to make these part of datajoint-python repo itself
"""

__all__ = ['table']

from .table import drop as tableDrop


# __author__ = "DataJoint Contributors"
# __date__ = "February 7, 2019"
# __all__ = ['conn', 'Connection',
#            'schema', 'create_virtual_module', 'list_schemas',
#            'Table', 'FreeTable',
#            'Manual', 'Lookup', 'Imported', 'Computed', 'Part',
#            'Not', 'AndList', 'U', 'Diagram', 'Di', 'ERD',
#            'set_password', 'kill',
#            'MatCell', 'MatStruct', 'AttributeAdapter',
#            'errors', 'DataJointError', 'key']
#
# from .version import __version__
# from .settings import config
# from .connection import conn, Connection
# from .schema import Schema as schema
# from .schema import create_virtual_module, list_schemas
# from .table import Table, FreeTable
# from .user_tables import Manual, Lookup, Imported, Computed, Part
# from .expression import Not, AndList, U
# from .diagram import Diagram
# from .admin import set_password, kill
# from .blob import MatCell, MatStruct
# from .fetch import key
# from .attribute_adapter import AttributeAdapter
# from . import errors
# from .errors import DataJointError
# from .migrate import migrate_dj011_external_blob_storage_to_dj012
#
# ERD = Di = Diagram   # Aliases for Diagram
