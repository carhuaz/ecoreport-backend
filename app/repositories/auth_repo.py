from ..database import call_proc, call_proc_scalar


def login(email: str):
    rows = call_proc("usp_auth_login", (email,))
    return rows[0] if rows else None


def registrar(
    nombre: str,
    email: str,
    password_hash: str,
    dni: str,
    codigo_hash: str,
):
    return call_proc_scalar(
        "usp_auth_registrar",
        (nombre, email, password_hash, dni, codigo_hash),
    )


def obtener_por_email(email: str):
    rows = call_proc("usp_auth_obtener_por_email", (email,))
    return rows[0] if rows else None


def marcar_verificado(usuario_id: int) -> None:
    call_proc("usp_auth_marcar_verificado", (usuario_id,))


def guardar_codigo(usuario_id: int, codigo_hash: str) -> None:
    call_proc("usp_auth_guardar_codigo", (usuario_id, codigo_hash))


def me(usuario_id: int):
    rows = call_proc("usp_auth_me", (usuario_id,))
    return rows[0] if rows else None
