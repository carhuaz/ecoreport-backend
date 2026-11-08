import re
from contextlib import contextmanager

from fastapi import HTTPException

from ..database import DatabaseError

_SP_ERROR_STATUS = {
    "50001": 404,
    "50002": 400,
    "50003": 400,
    "50004": 403,
    "50005": 400,
    "50006": 400,
}


def _extraer_error(exc: Exception) -> tuple[str | None, str]:
    message = " ".join(str(arg) for arg in exc.args) if exc.args else ""
    match = re.search(r"[\[(](5\d{4})[\])]", message)
    codigo = match.group(1) if match else None
    sql_server = re.search(r"\[SQL Server\](.*)", message)
    if sql_server:
        limpio = sql_server.group(1).strip()
    else:
        limpio = message.split("] ")[-1].strip() if message else "Error de base de datos"
    limpio = re.sub(r"\s*\(\d+\)\s*\(SQLExecDirectW\)\s*$", "", limpio)
    limpio = re.sub(r"\s*\(\d+\)\s*$", "", limpio)
    return codigo, limpio.strip("'\"")


def traducir_error_bd(exc: Exception) -> HTTPException:
    codigo, mensaje = _extraer_error(exc)
    status = _SP_ERROR_STATUS.get(codigo, 500)
    if status == 500:
        mensaje = "Error interno de base de datos"
    return HTTPException(status_code=status, detail=mensaje)


@contextmanager
def manejar_errores_bd():
    try:
        yield
    except DatabaseError as exc:
        raise traducir_error_bd(exc) from exc
