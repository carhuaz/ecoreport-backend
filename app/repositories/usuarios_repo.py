from ..database import call_proc, call_proc_multi


def listar(usuario_id, termino=None, rol=None, page=None, page_size=50):
    return call_proc_multi(
        "usp_usuarios_listar",
        (usuario_id, termino, rol, page, page_size),
    )


def cambiar_rol(usuario_id, objetivo_id, rol):
    call_proc("usp_usuario_cambiar_rol", (usuario_id, objetivo_id, rol))


def activar(usuario_id, objetivo_id):
    call_proc("usp_usuario_activar", (usuario_id, objetivo_id))


def desactivar(usuario_id, objetivo_id):
    call_proc("usp_usuario_desactivar", (usuario_id, objetivo_id))
