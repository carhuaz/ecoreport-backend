from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional
from ..database import fetch_all, fetch_one, execute
from ..schemas.reporte import ReporteCreate, ValidacionRequest, CompletarRequest
from ..middleware.auth import get_current_user_id, get_current_user_role, require_roles
from ..utils import paginar, MAX_ASIGNACIONES_POR_CUADRILLA, calcular_estado_cuadrilla
import json

router = APIRouter(prefix="/api/reportes", tags=["Reportes"])


def _serializar_reporte(row: dict) -> dict:
    if row.get("criterios_prioridad") and isinstance(row["criterios_prioridad"], str):
        row["criterios_prioridad"] = json.loads(row["criterios_prioridad"])
    if row.get("imagenes") and isinstance(row["imagenes"], str):
        row["imagenes"] = json.loads(row["imagenes"])
    if row.get("fecha") and hasattr(row["fecha"], 'strftime'):
        row["fecha"] = row["fecha"].strftime("%Y-%m-%d")
    if row.get("anonimo"):
        row["ciudadano_nombre"] = "Anónimo"
    return row


def _adjuntar_historial(reportes: list[dict]) -> list[dict]:
    for r in reportes:
        historial = fetch_all(
            "SELECT id, FORMAT(fecha, 'yyyy-MM-dd') as fecha, accion, usuario, observacion FROM historial_reportes WHERE reporte_id = ? ORDER BY fecha ASC",
            (r["id"],)
        )
        r["historial"] = historial
    return reportes


def _actualizar_estado_cuadrilla(reporte_id: int):
    reporte = fetch_one("SELECT cuadrilla_id FROM reportes WHERE id = ?", (reporte_id,))
    if not reporte or not reporte["cuadrilla_id"]:
        return
    cuadrilla_id = reporte["cuadrilla_id"]
    activos = fetch_one(
        "SELECT COUNT(*) as total FROM reportes WHERE cuadrilla_id = ? AND estado IN ('Programado', 'En atención')",
        (cuadrilla_id,)
    )
    nuevo_estado = calcular_estado_cuadrilla(activos["total"] if activos else 0)
    execute("UPDATE cuadrillas SET estado = ? WHERE id = ?", (nuevo_estado, cuadrilla_id))


@router.get("")
def listar_reportes(
    estado: Optional[str] = None,
    distrito: Optional[str] = None,
    prioridad: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(get_current_user_role)
):
    where = "WHERE 1=1"
    params: list = []
    if estado:
        where += " AND r.estado = ?"
        params.append(estado)
    if distrito:
        where += " AND r.distrito = ?"
        params.append(distrito)
    if prioridad:
        where += " AND r.prioridad = ?"
        params.append(prioridad)

    count_sql = f"SELECT COUNT(*) as total FROM reportes r {where}"
    data_sql = f"""
        SELECT r.*, u.nombre as ciudadano_nombre,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha
        FROM reportes r
        LEFT JOIN usuarios u ON r.ciudadano_id = u.id
        {where}
        ORDER BY r.fecha DESC
    """

    result = paginar(count_sql, data_sql, params, page, page_size)
    result["items"] = _adjuntar_historial([_serializar_reporte(r) for r in result["items"]])
    return result


@router.get("/publicos")
def listar_reportes_publicos(
    distrito: Optional[str] = None,
    estado: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100)
):
    where = "WHERE r.estado NOT IN ('Pendiente', 'Rechazado')"
    params: list = []
    if distrito:
        where += " AND r.distrito = ?"
        params.append(distrito)
    if estado:
        where += " AND r.estado = ?"
        params.append(estado)

    count_sql = f"SELECT COUNT(*) as total FROM reportes r {where}"
    data_sql = f"""
        SELECT r.*, u.nombre as ciudadano_nombre,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha
        FROM reportes r
        LEFT JOIN usuarios u ON r.ciudadano_id = u.id
        {where}
        ORDER BY r.fecha DESC
    """

    result = paginar(count_sql, data_sql, params, page, page_size)
    result["items"] = _adjuntar_historial([_serializar_reporte(r) for r in result["items"]])
    return result


@router.get("/mis-reportes")
def mis_reportes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: int = Depends(get_current_user_id)
):
    where = "WHERE r.ciudadano_id = ?"
    params = [user_id]

    count_sql = f"SELECT COUNT(*) as total FROM reportes r {where}"
    data_sql = f"""
        SELECT r.*, u.nombre as ciudadano_nombre,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha
        FROM reportes r
        LEFT JOIN usuarios u ON r.ciudadano_id = u.id
        {where}
        ORDER BY r.fecha DESC
    """

    result = paginar(count_sql, data_sql, params, page, page_size)
    result["items"] = _adjuntar_historial([_serializar_reporte(r) for r in result["items"]])
    return result


@router.get("/cuadrilla/{cuadrilla_id}")
def reportes_por_cuadrilla(
    cuadrilla_id: int,
    estado: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user=Depends(get_current_user_role)
):
    where = "WHERE r.cuadrilla_id = ?"
    params: list = [cuadrilla_id]

    if user["rol"] == "ResponsableCuadrilla":
        cuadrilla = fetch_one("SELECT id FROM cuadrillas WHERE id = ? AND responsable_id = ?", (cuadrilla_id, user["id"]))
        if not cuadrilla:
            raise HTTPException(status_code=403, detail="No tienes acceso a esta cuadrilla")

    if estado:
        where += " AND r.estado = ?"
        params.append(estado)

    count_sql = f"SELECT COUNT(*) as total FROM reportes r {where}"
    data_sql = f"""
        SELECT r.*, u.nombre as ciudadano_nombre,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha
        FROM reportes r
        LEFT JOIN usuarios u ON r.ciudadano_id = u.id
        {where}
        ORDER BY r.fecha DESC
    """

    result = paginar(count_sql, data_sql, params, page, page_size)
    result["items"] = _adjuntar_historial([_serializar_reporte(r) for r in result["items"]])
    return result


@router.get("/auditoria-evidencias")
def auditoria_evidencias(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    cuadrilla_id: Optional[int] = None,
    estado: Optional[str] = None,
    user=Depends(require_roles("Administrador"))
):
    where = "WHERE r.estado IN ('Atendido', 'Verificado')"
    params: list = []

    if cuadrilla_id:
        where += " AND r.cuadrilla_id = ?"
        params.append(cuadrilla_id)
    if estado:
        where += " AND r.estado = ?"
        params.append(estado)

    count_sql = f"""
        SELECT COUNT(*) as total
        FROM reportes r
        {where}
    """
    data_sql = f"""
        SELECT r.id, r.titulo, r.descripcion, r.distrito, r.estado, r.imagenes, r.fecha,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha_str,
               c.id as cuadrilla_id, c.nombre as cuadrilla_nombre,
               (SELECT TOP 1 observacion FROM historial_reportes
                WHERE reporte_id = r.id AND accion = 'Atendido con evidencias'
                ORDER BY fecha DESC) as observacion_completado
        FROM reportes r
        LEFT JOIN cuadrillas c ON r.cuadrilla_id = c.id
        {where}
        ORDER BY r.fecha DESC
    """

    result = paginar(count_sql, data_sql, params, page, page_size)

    for item in result["items"]:
        item["fecha"] = item.pop("fecha_str")
        if item.get("imagenes") and isinstance(item["imagenes"], str):
            item["imagenes"] = json.loads(item["imagenes"])
        if item.get("observacion_completado") is None:
            item["observacion_completado"] = ""

    return result


@router.get("/auditoria")
def auditoria_validaciones(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user=Depends(require_roles("Administrador"))
):
    count_sql = """
        SELECT COUNT(*) as total
        FROM historial_reportes h
        WHERE h.accion IN ('Aprobado', 'Rechazado')
    """
    data_sql = f"""
        SELECT h.id, h.reporte_id, h.fecha, h.accion, h.usuario as usuario_id, h.observacion,
               r.titulo, r.distrito, r.prioridad, r.estado as estado_reporte, r.imagenes,
               FORMAT(h.fecha, 'yyyy-MM-dd') as fecha_str,
               u.nombre as validador_nombre
        FROM historial_reportes h
        JOIN reportes r ON h.reporte_id = r.id
        LEFT JOIN usuarios u ON TRY_CAST(h.usuario AS INT) = u.id
        WHERE h.accion IN ('Aprobado', 'Rechazado')
        ORDER BY h.fecha DESC
    """

    result = paginar(count_sql, data_sql, [], page, page_size)

    for item in result["items"]:
        item["fecha"] = item.pop("fecha_str")
        if item.get("imagenes") and isinstance(item["imagenes"], str):
            item["imagenes"] = json.loads(item["imagenes"])

    return result


@router.post("")
def crear_reporte(req: ReporteCreate, user_id: int = Depends(get_current_user_id)):
    imagenes_json = json.dumps(req.imagenes or [], ensure_ascii=False)
    criterios_json = json.dumps(req.criterios_prioridad or [], ensure_ascii=False) if hasattr(req, 'criterios_prioridad') else '[]'

    ciudadano_id_val = user_id
    nombre_usuario = "Anónimo" if req.anonimo else (fetch_one("SELECT nombre FROM usuarios WHERE id = ?", (user_id,)) or {}).get("nombre", "Ciudadano")

    reporte_id = execute(
        """INSERT INTO reportes (titulo, descripcion, distrito, direccion, latitud, longitud, imagenes, ciudadano_id, prioridad, puntaje_prioridad, criterios_prioridad, anonimo)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (req.titulo, req.descripcion, req.distrito, req.direccion, req.latitud, req.longitud, imagenes_json, ciudadano_id_val,
         req.prioridad or 'Media', req.puntaje_prioridad or 0, criterios_json, 1 if req.anonimo else 0)
    )

    execute(
        "INSERT INTO historial_reportes (reporte_id, accion, usuario) VALUES (?, 'Reporte creado', ?)",
        (reporte_id, nombre_usuario)
    )

    return {"mensaje": "Reporte creado exitosamente", "id": reporte_id}


# --- Transiciones de estado ---

@router.post("/{reporte_id}/aprobar")
def aprobar_reporte(reporte_id: int, req: ValidacionRequest, user=Depends(require_roles("Validador"))):
    reporte = fetch_one("SELECT id, estado FROM reportes WHERE id = ?", (reporte_id,))
    if not reporte:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    execute("UPDATE reportes SET estado = 'Aprobado' WHERE id = ?", (reporte_id,))
    execute(
        "INSERT INTO historial_reportes (reporte_id, accion, usuario, observacion) VALUES (?, 'Aprobado', ?, ?)",
        (reporte_id, user["id"], req.observacion)
    )
    return {"mensaje": "Reporte aprobado"}


@router.post("/{reporte_id}/rechazar")
def rechazar_reporte(reporte_id: int, req: ValidacionRequest, user=Depends(require_roles("Validador"))):
    reporte = fetch_one("SELECT id FROM reportes WHERE id = ?", (reporte_id,))
    if not reporte:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    execute("UPDATE reportes SET estado = 'Rechazado', observacion_validacion = ? WHERE id = ?",
            (req.observacion, reporte_id))
    execute(
        "INSERT INTO historial_reportes (reporte_id, accion, usuario, observacion) VALUES (?, 'Rechazado', ?, ?)",
        (reporte_id, user["id"], req.observacion)
    )
    return {"mensaje": "Reporte rechazado"}


@router.post("/{reporte_id}/atender")
def marcar_en_atencion(reporte_id: int, user=Depends(get_current_user_role)):
    reporte = fetch_one("SELECT id, cuadrilla_id FROM reportes WHERE id = ?", (reporte_id,))
    if not reporte:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")

    if user["rol"] == "ResponsableCuadrilla":
        if not reporte["cuadrilla_id"]:
            raise HTTPException(status_code=403, detail="El reporte no está asignado a ninguna cuadrilla")
        cuadrilla = fetch_one("SELECT id FROM cuadrillas WHERE id = ? AND responsable_id = ?", (reporte["cuadrilla_id"], user["id"]))
        if not cuadrilla:
            raise HTTPException(status_code=403, detail="No tienes acceso a este reporte")

    execute("UPDATE reportes SET estado = 'En atención' WHERE id = ?", (reporte_id,))
    execute(
        "INSERT INTO historial_reportes (reporte_id, accion, usuario) VALUES (?, 'En atención', ?)",
        (reporte_id, f"User {user['id']}")
    )
    _actualizar_estado_cuadrilla(reporte_id)
    return {"mensaje": "Reporte en atención"}


@router.post("/{reporte_id}/completar-con-evidencias")
def completar_con_evidencias(reporte_id: int, req: CompletarRequest, user=Depends(require_roles("ResponsableCuadrilla"))):
    reporte = fetch_one("SELECT id, imagenes, cuadrilla_id FROM reportes WHERE id = ?", (reporte_id,))
    if not reporte:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")

    if user["rol"] == "ResponsableCuadrilla":
        cuadrilla = fetch_one("SELECT id FROM cuadrillas WHERE id = ? AND responsable_id = ?", (reporte["cuadrilla_id"], user["id"]))
        if not cuadrilla:
            raise HTTPException(status_code=403, detail="No tienes acceso a este reporte")

    imagenes_actuales = []
    if reporte["imagenes"]:
        try:
            imagenes_actuales = json.loads(reporte["imagenes"])
        except (json.JSONDecodeError, TypeError):
            imagenes_actuales = []

    if req.evidencias:
        imagenes_actuales.extend(req.evidencias)

    execute("UPDATE reportes SET estado = 'Atendido', imagenes = ? WHERE id = ?",
            (json.dumps(imagenes_actuales, ensure_ascii=False), reporte_id))
    execute(
        "INSERT INTO historial_reportes (reporte_id, accion, usuario, observacion) VALUES (?, 'Atendido con evidencias', ?, ?)",
        (reporte_id, f"User {user['id']}", req.observacion or 'Trabajo completado')
    )
    _actualizar_estado_cuadrilla(reporte_id)
    return {"mensaje": "Reporte completado con evidencias"}
