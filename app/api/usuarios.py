from typing import Optional

from fastapi import APIRouter, Depends, Query

from ..middleware.auth import require_roles
from ..schemas.usuario import CambiarRolRequest
from ..services import usuarios_service

router = APIRouter(prefix="/api/usuarios", tags=["Usuarios"])


@router.get("")
def listar_usuarios(
    termino: Optional[str] = None,
    rol: Optional[str] = None,
    page: Optional[int] = Query(None, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    user=Depends(require_roles("Administrador")),
):
    return usuarios_service.listar(user["id"], termino, rol, page, page_size)


@router.put("/{usuario_id}/rol")
def cambiar_rol(
    usuario_id: int,
    req: CambiarRolRequest,
    user=Depends(require_roles("Administrador")),
):
    return usuarios_service.cambiar_rol(user["id"], usuario_id, req.rol)


@router.put("/{usuario_id}/activar")
def activar_usuario(
    usuario_id: int,
    user=Depends(require_roles("Administrador")),
):
    return usuarios_service.activar(user["id"], usuario_id)


@router.put("/{usuario_id}/desactivar")
def desactivar_usuario(
    usuario_id: int,
    user=Depends(require_roles("Administrador")),
):
    return usuarios_service.desactivar(user["id"], usuario_id)
