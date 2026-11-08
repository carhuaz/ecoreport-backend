from typing import Optional

from fastapi import APIRouter, Depends, Query

from ..middleware.auth import (
    get_current_user_id,
    get_current_user_role,
    require_roles,
)
from ..schemas.reporte import CompletarRequest, ReporteCreate, ValidacionRequest
from ..services import reportes_service

router = APIRouter(prefix="/api/reportes", tags=["Reportes"])


@router.get("")
def listar_reportes(
    estado: Optional[str] = None,
    distrito: Optional[str] = None,
    prioridad: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    user=Depends(get_current_user_role),
):
    return reportes_service.listar(estado, distrito, prioridad, page, page_size)


@router.get("/publicos")
def listar_reportes_publicos(
    distrito: Optional[str] = None,
    estado: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
):
    return reportes_service.publicos(distrito, estado, page, page_size)


@router.get("/mis-reportes")
def mis_reportes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: int = Depends(get_current_user_id),
):
    return reportes_service.mis_reportes(user_id, page, page_size)


@router.get("/cuadrilla/{cuadrilla_id}")
def reportes_por_cuadrilla(
    cuadrilla_id: int,
    estado: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user=Depends(get_current_user_role),
):
    return reportes_service.por_cuadrilla(
        user["id"],
        cuadrilla_id,
        estado,
        page,
        page_size,
    )


@router.get("/auditoria-evidencias")
def auditoria_evidencias(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    cuadrilla_id: Optional[int] = None,
    estado: Optional[str] = None,
    user=Depends(require_roles("Administrador")),
):
    return reportes_service.auditoria_evidencias(
        user["id"],
        page,
        page_size,
        cuadrilla_id,
        estado,
    )


@router.get("/auditoria")
def auditoria_validaciones(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user=Depends(require_roles("Administrador")),
):
    return reportes_service.auditoria_validaciones(user["id"], page, page_size)


@router.post("")
def crear_reporte(
    req: ReporteCreate,
    user_id: int = Depends(get_current_user_id),
):
    return reportes_service.crear(user_id, req)


@router.post("/{reporte_id}/aprobar")
def aprobar_reporte(
    reporte_id: int,
    req: ValidacionRequest,
    user=Depends(require_roles("Validador")),
):
    return reportes_service.aprobar(user["id"], reporte_id, req)


@router.post("/{reporte_id}/rechazar")
def rechazar_reporte(
    reporte_id: int,
    req: ValidacionRequest,
    user=Depends(require_roles("Validador")),
):
    return reportes_service.rechazar(user["id"], reporte_id, req)


@router.post("/{reporte_id}/atender")
def marcar_en_atencion(
    reporte_id: int,
    user=Depends(get_current_user_role),
):
    return reportes_service.marcar_en_atencion(user["id"], reporte_id)


@router.post("/{reporte_id}/completar-con-evidencias")
def completar_con_evidencias(
    reporte_id: int,
    req: CompletarRequest,
    user=Depends(require_roles("ResponsableCuadrilla")),
):
    return reportes_service.completar(user["id"], reporte_id, req)
