import sys
from contextlib import contextmanager

if sys.platform.startswith('win'):
    import pyodbc
    from .config import CONNECTION_STRING

    def get_connection():
        return pyodbc.connect(CONNECTION_STRING)
else:
    import pymssql
    from .config import DB_SERVER, DB_NAME, DB_USER, DB_PASSWORD

    def get_connection():
        return pymssql.connect(
            server=DB_SERVER,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )


@contextmanager
def get_db():
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fetch_all(query: str, params: tuple = ()):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        columns = [col[0] for col in cursor.description]
        rows = cursor.fetchall()
        return [dict(zip(columns, row)) for row in rows]


def fetch_one(query: str, params: tuple = ()):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        columns = [col[0] for col in cursor.description] if cursor.description else None
        row = cursor.fetchone()
        if row and columns:
            return dict(zip(columns, row))
        return None


def execute(query: str, params: tuple = ()):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        return cursor.rowcount


def execute_returning_id(query: str, params: tuple = ()):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        row = cursor.fetchone()
        return int(row[0]) if row else None
