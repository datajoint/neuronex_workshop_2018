import pymysql
from getpass import getpass
from datajoint.connection import conn
from datajoint.settings import config
from datajoint.utils import user_choice


def set_password(new_password=None, connection=None, update_config=None, *, \
getpass_fn=getpass, user_choice_fn=user_choice, print_fn=print):   # pragma: no cover
    """
    NEEDS DOCUMENTATION

    :kwparam getpass_fn  function object for function that asks for a hidden
                       user string through a dialog box. Introduced so that Julia
                       users can call the method while avoiding Python dialog boxes,
                       which appear to crash in Juia Jupyter notebooks
    :kwparam user_choice_fn  function object for function that interacts with user
                             through dialog boxes. Introduced so that Julia users
                             can call the method while avoiding Python dialog boxes,
                             which appear to crash in Juia Jupyter notebooks
    :kwparam print_fn  function object for printing to stdout. Introduced so that
                       Julia users can call the method and still see print output
                       in Juia Jupyter notebooks

    """
    connection = conn() if connection is None else connection
    if new_password is None:
        new_password = getpass_fn('New password: ')
        confirm_password = getpass_fn('Confirm password: ')
        if new_password != confirm_password:
            print_fn('Failed to confirm the password! Aborting password change.')
            return
    connection.query("SET PASSWORD = PASSWORD('%s')" % new_password)
    print_fn('Password updated.')

    if update_config or (update_config is None and user_choice_fn('Update local setting?') == 'yes'):
        config['database.password'] = new_password
        config.save_local(verbose=True)


def kill(restriction=None, connection=None, *, input_fn=input, print_fn=print):  # pragma: no cover
    """
    view and kill database connections.
    :param restriction: restriction to be applied to processlist
    :param connection: a datajoint.Connection object. Default calls datajoint.conn()
    :kwparam input_fn  function object for function that asks for a user string
                       through a dialog box. Introduced so that Julia users
                       can call the method while avoiding Python dialog boxes,
                       which appear to crash in Juia Jupyter notebooks
    :kwparam print_fn  function object for printing to stdout. Introduced so that
                       Julia users can call the method and still see print output
                       in Juia Jupyter notebooks

    Restrictions are specified as strings and can involve any of the attributes of
    information_schema.processlist: ID, USER, HOST, DB, COMMAND, TIME, STATE, INFO.

    Examples:
        dj.kill('HOST LIKE "%compute%"') lists only connections from hosts containing "compute".
        dj.kill('TIME > 600') lists only connections older than 10 minutes.
    """

    if connection is None:
        connection = conn()

    query = 'SELECT * FROM information_schema.processlist WHERE id <> CONNECTION_ID()' + (
        "" if restriction is None else ' AND (%s)' % restriction)

    while True:
        print_fn('  ID USER         STATE         TIME  INFO')
        print_fn('+--+ +----------+ +-----------+ +--+')
        cur = connection.query(query, as_dict=True)
        for process in cur:
            try:
                print_fn('{ID:>4d} {USER:<12s} {STATE:<12s} {TIME:>5d}  {INFO}'.format(**process))
            except TypeError:
                print_fn(process)
        response = input_fn('process to kill or "q" to quit > ')
        if response == 'q':
            break
        if response:
            try:
                pid = int(response)
            except ValueError:
                pass  # ignore non-numeric input
            else:
                try:
                    connection.query('kill %d' % pid)
                except pymysql.err.InternalError:
                    print_fn('Process not found')
