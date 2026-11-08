from fastapi import APIRouter, Depends

from ..middleware.auth import require_roles
from ..schemas.cuadrilla import CuadrillaCreate, CuadrillaUpdate
from ..services import cuadrillas_service

router = APIRouter(prefix="/api/cuadrillas", tags=["Cuadrillas"])


@router.get("")
def listar_cuadrillas(user=Depends(require_roles("Administrador"))):
    return cuadrillas_service.listar()


@router.get("/disponibles")
def cuadrillas_disponibles(user=Depends(require_roles("Administrador"))):
    return cuadrillas_service.disponibles()


@router.get("/mis-cuadrillas")
def mis_cuadrillas(user=Depends(require_roles("ResponsableCuadrilla"))):
    return cuadrillas_service.mis_cuadrillas(user["id"])


@router.post("")
def crear_cuadrilla(
    req: CuadrillaCreate,
    user=Depends(require_roles("Administrador")),
):
    return cuadrillas_service.crear(user["id"], req)


@router.put("/{cuadrilla_id}")
def actualizar_cuadrilla(
    cuadrilla_id: int,
    req: CuadrillaUpdate,
    user=Depends(require_roles("Administrador")),
):
    return cuadrillas_service.actualizar(user["id"], cuadrilla_id, req)


@router.delete("/{cuadrilla_id}")
def eliminar_cuadrilla(
    cuadrilla_id: int,
    user=Depends(require_roles("Administrador")),
):
    return cuadrillas_service.eliminar(user["id"], cuadrilla_id)


@router.post("/{cuadrilla_id}/asignar-revision")
def asignar_a_cuadrilla(
    cuadrilla_id: int,
    reporte_id: int,
    user=Depends(require_roles("Administrador")),
):
    return cuadrillas_service.asignar(user["id"], cuadrilla_id, reporte_id)
