from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional
from ..database import fetch_all, fetch_one, execute
from ..schemas.usuario import CambiarRolRequest
from ..middleware.auth import require_roles
from ..utils import paginar

router = APIRouter(prefix="/api/usuarios", tags=["Usuarios"])


@router.get("")
def listar_usuarios(
    termino: Optional[str] = None,
    rol: Optional[str] = None,
    page: Optional[int] = Query(None, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    user=Depends(require_roles("Administrador"))
):
    where = "WHERE 1=1"
    params = []

    if termino:
        where += " AND (LOWER(nombre) LIKE ? OR LOWER(email) LIKE ?)"
        params.extend([f"%{termino.lower()}%", f"%{termino.lower()}%"])
    if rol:
        where += " AND rol = ?"
        params.append(rol)

    columns = """
        id, nombre, email, dni, rol, activo,
        FORMAT(fecha_registro, 'yyyy-MM-dd') as fecha_registro
    """
    data_sql = f"SELECT {columns} FROM usuarios {where} ORDER BY id"

    if page:
        count_sql = f"SELECT COUNT(*) as total FROM usuarios {where}"
        return paginar(count_sql, data_sql, params, page, page_size)

    return fetch_all(data_sql, tuple(params))


@router.put("/{usuario_id}/rol")
def cambiar_rol(usuario_id: int, req: CambiarRolRequest, user=Depends(require_roles("Administrador"))):
    if req.rol not in ("Ciudadano", "Validador", "Administrador", "ResponsableCuadrilla"):
        raise HTTPException(status_code=400, detail="Rol inválido")
    usuario = fetch_one("SELECT id FROM usuarios WHERE id = ?", (usuario_id,))
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    execute("UPDATE usuarios SET rol = ? WHERE id = ?", (req.rol, usuario_id))
    return {"mensaje": "Rol actualizado"}


@router.put("/{usuario_id}/activar")
def activar_usuario(usuario_id: int, user=Depends(require_roles("Administrador"))):
    usuario = fetch_one("SELECT id FROM usuarios WHERE id = ?", (usuario_id,))
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    execute("UPDATE usuarios SET activo = 1 WHERE id = ?", (usuario_id,))
    return {"mensaje": "Usuario activado"}


@router.put("/{usuario_id}/desactivar")
def desactivar_usuario(usuario_id: int, user=Depends(require_roles("Administrador"))):
    usuario = fetch_one("SELECT id FROM usuarios WHERE id = ?", (usuario_id,))
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if usuario_id == user["id"]:
        raise HTTPException(status_code=400, detail="No puedes desactivarte a ti mismo")
    execute("UPDATE usuarios SET activo = 0 WHERE id = ?", (usuario_id,))
    return {"mensaje": "Usuario desactivado"}
