import collections
import itertools
import inspect
import platform
import numpy as np
import pandas
import logging
import uuid
from pathlib import Path
from datajoint.settings import config
from datajoint.declare import declare, alter
from datajoint.expression import QueryExpression
from datajoint import blob
from datajoint.utils import user_choice
from datajoint.heading import Heading
from datajoint.errors import DuplicateError, AccessError, DataJointError, UnknownAttributeError
from datajoint.version import __version__ as version

from datajoint.table import FreeTable

logger = logging.getLogger(__name__)



def delete(self, verbose=True, *, user_choice_fn=user_choice):
    """
    Deletes the contents of the table and its dependent tables, recursively.
    User is prompted for confirmation if config['safemode'] is set to True.

    :param   verbose         Boolean that controls how much info is printed to user
    :kwparam user_choice_fn  function object for function that interacts with user
                             through dialog boxes. Introduced so that Julia users
                             can call the method while avoiding Python dialog boxes,
                             which appear to crash in Juia Jupyter notebooks
    """
    conn = self.connection
    already_in_transaction = conn.in_transaction
    safe = config['safemode']
    if already_in_transaction and safe:
        raise DataJointError('Cannot delete within a transaction in safemode. '
                             'Set dj.config["safemode"] = False or complete the ongoing transaction first.')
    graph = conn.dependencies
    graph.load()
    delete_list = collections.OrderedDict(
        (name, _RenameMap(next(iter(graph.parents(name).items()))) if name.isdigit() else FreeTable(conn, name))
        for name in graph.descendants(self.full_table_name))

    # construct restrictions for each relation
    restrict_by_me = set()
    # restrictions: Or-Lists of restriction conditions for each table.
    # Uncharacteristically of Or-Lists, an empty entry denotes "delete everything".
    restrictions = collections.defaultdict(list)
    # restrict by self
    if self.restriction:
        restrict_by_me.add(self.full_table_name)
        restrictions[self.full_table_name].append(self.restriction)  # copy own restrictions
    # restrict by renamed nodes
    restrict_by_me.update(table for table in delete_list if table.isdigit())  # restrict by all renamed nodes
    # restrict by secondary dependencies
    for table in delete_list:
        restrict_by_me.update(graph.children(table, primary=False))   # restrict by any non-primary dependents

    # compile restriction lists
    for name, table in delete_list.items():
        for dep in graph.children(name):
            # if restrict by me, then restrict by the entire relation otherwise copy restrictions
            restrictions[dep].extend([table] if name in restrict_by_me else restrictions[name])

    # apply restrictions
    for name, table in delete_list.items():
        if not name.isdigit() and restrictions[name]:  # do not restrict by an empty list
            table.restrict([
                r.proj() if isinstance(r, FreeTable) else (
                    delete_list[r[0]].proj(**{a: b for a, b in r[1]['attr_map'].items()})
                    if isinstance(r, _RenameMap) else r)
                for r in restrictions[name]])
    if safe:
        print('About to delete:')

    if not already_in_transaction:
        conn.start_transaction()
    total = 0
    try:
        for name, table in reversed(list(delete_list.items())):
            if not name.isdigit():
                count = table.delete_quick(get_count=True)
                total += count
                if (verbose or safe) and count:
                    print('{table}: {count} items'.format(table=name, count=count))
    except:
        # Delete failed, perhaps due to insufficient privileges. Cancel transaction.
        if not already_in_transaction:
            conn.cancel_transaction()
        raise
    else:
        assert not (already_in_transaction and safe)
        if not total:
            print('Nothing to delete')
            if not already_in_transaction:
                conn.cancel_transaction()
        else:
            if already_in_transaction:
                if verbose:
                    print('The delete is pending within the ongoing transaction.')
            else:
                if not safe or user_choice_fn("Proceed?", default='no') == 'yes':
                    conn.commit_transaction()
                    if verbose or safe:
                        print('Committed.')
                else:
                    conn.cancel_transaction()
                    if verbose or safe:
                        print('Cancelled deletes.')


def drop(self, *, user_choice_fn = user_choice):
    """
    Drop the table and all tables that reference it, recursively.
    User is prompted for confirmation if config['safemode'] is set to True.

    :kwparam user_choice_fn  function object for function that interacts with user
                             through dialog boxes. Introduced so that Julia users
                             can call the method while avoiding Python dialog boxes,
                             which appear to crash in Juia Jupyter notebooks
    """
    if self.restriction:
        raise DataJointError('A relation with an applied restriction condition cannot be dropped.'
                             ' Call drop() on the unrestricted Table.')
    self.connection.dependencies.load()
    do_drop = True
    tables = [table for table in self.connection.dependencies.descendants(self.full_table_name)
              if not table.isdigit()]
    if config['safemode']:
        for table in tables:
            print(table, '(%d tuples)' % len(FreeTable(self.connection, table)))
        do_drop = user_choice_fn("Proceed?", default='no') == 'yes'
    if do_drop:
        for table in reversed(tables):
            FreeTable(self.connection, table).drop_quick()
        print('Tables dropped.  Restart kernel.')
