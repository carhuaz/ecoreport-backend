from fastapi import HTTPException

from ..repositories import usuarios_repo
from .common import paginar_resultados
from .errors import manejar_errores_bd


def listar(usuario_id, termino=None, rol=None, page=None, page_size=50):
    with manejar_errores_bd():
        result_sets = usuarios_repo.listar(
            usuario_id,
            termino=termino,
            rol=rol,
            page=page,
            page_size=page_size,
        )

    if page is None:
        return result_sets[0] if result_sets else []
    return paginar_resultados(result_sets, page, page_size)


def cambiar_rol(usuario_id, objetivo_id, rol):
    with manejar_errores_bd():
        usuarios_repo.cambiar_rol(usuario_id, objetivo_id, rol)
    return {"mensaje": "Rol actualizado"}


def activar(usuario_id, objetivo_id):
    with manejar_errores_bd():
        usuarios_repo.activar(usuario_id, objetivo_id)
    return {"mensaje": "Usuario activado"}


def desactivar(usuario_id, objetivo_id):
    with manejar_errores_bd():
        usuarios_repo.desactivar(usuario_id, objetivo_id)
    return {"mensaje": "Usuario desactivado"}


def resolver_responsable(usuario_id, responsable_id, nombre):
    if responsable_id is not None:
        return responsable_id
    if not nombre:
        raise HTTPException(status_code=400, detail="Responsable no encontrado")

    with manejar_errores_bd():
        result_sets = usuarios_repo.listar(
            usuario_id,
            termino=nombre,
            rol="ResponsableCuadrilla",
            page=None,
        )

    usuarios = result_sets[0] if result_sets else []
    buscado = nombre.strip().lower()
    for usuario in usuarios:
        if usuario["nombre"].strip().lower() == buscado:
            return usuario["id"]

    raise HTTPException(status_code=400, detail="Responsable no encontrado")
