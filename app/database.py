import sys
from contextlib import contextmanager

if sys.platform.startswith('win'):
    import pyodbc

    from .config import CONNECTION_STRING

    DatabaseError = pyodbc.Error

    def get_connection():
        return pyodbc.connect(CONNECTION_STRING)
else:
    import pymssql

    from .config import DB_NAME, DB_PASSWORD, DB_SERVER, DB_USER

    DatabaseError = pymssql.Error

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
        return [dict(zip(columns, row, strict=False)) for row in rows]


def fetch_one(query: str, params: tuple = ()):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        columns = [col[0] for col in cursor.description] if cursor.description else None
        row = cursor.fetchone()
        if row and columns:
            return dict(zip(columns, row, strict=False))
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


def _result_set(cursor) -> list[dict]:
    if cursor.description is None:
        return []
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row, strict=False)) for row in cursor.fetchall()]


def _query_proc(nombre: str, params: tuple) -> tuple[str, tuple]:
    placeholders = ", ".join("?" for _ in params)
    query = f"EXEC dbo.{nombre}" + (f" {placeholders}" if placeholders else "")
    return query, params


def call_proc(nombre: str, params: tuple = ()) -> list[dict]:
    query, values = _query_proc(nombre, params)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, values)
        return _result_set(cursor)


def call_proc_multi(nombre: str, params: tuple = ()) -> list[list[dict]]:
    query, values = _query_proc(nombre, params)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(query, values)
        resultados = []
        while True:
            resultados.append(_result_set(cursor))
            if not cursor.nextset():
                break
        return resultados


def call_proc_scalar(nombre: str, params: tuple = ()):
    rows = call_proc(nombre, params)
    if not rows:
        return None
    return next(iter(rows[0].values()))
