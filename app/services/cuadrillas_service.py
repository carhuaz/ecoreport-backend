from fastapi import HTTPException

from ..repositories import cuadrillas_repo
from ..schemas.cuadrilla import CuadrillaCreate, CuadrillaUpdate
from . import usuarios_service
from .errors import manejar_errores_bd


def listar():
    with manejar_errores_bd():
        return cuadrillas_repo.listar()


def disponibles():
    with manejar_errores_bd():
        return cuadrillas_repo.disponibles()


def mis_cuadrillas(usuario_id):
    with manejar_errores_bd():
        return cuadrillas_repo.por_responsable(usuario_id, usuario_id)


def crear(usuario_id, req: CuadrillaCreate):
    responsable_id = usuarios_service.resolver_responsable(
        usuario_id,
        req.responsable_id,
        req.responsable,
    )
    with manejar_errores_bd():
        cuadrillas_repo.crear(
            usuario_id,
            req.nombre,
            responsable_id,
            req.distrito,
            req.zona_asignada or "",
        )
    return {"mensaje": "Cuadrilla creada exitosamente"}


def actualizar(usuario_id, cuadrilla_id, req: CuadrillaUpdate):
    responsable_id = req.responsable_id
    if responsable_id is None and req.responsable:
        responsable_id = usuarios_service.resolver_responsable(
            usuario_id,
            None,
            req.responsable,
        )

    with manejar_errores_bd():
        cuadrillas_repo.actualizar(
            usuario_id,
            cuadrilla_id,
            req.nombre,
            responsable_id,
            req.distrito,
            req.zona_asignada,
        )
    return {"mensaje": "Cuadrilla actualizada"}


def eliminar(usuario_id, cuadrilla_id):
    with manejar_errores_bd():
        cuadrillas_repo.eliminar(usuario_id, cuadrilla_id)
    return {"mensaje": "Cuadrilla eliminada"}


def asignar(usuario_id, cuadrilla_id, reporte_id):
    with manejar_errores_bd():
        cuadrillas = cuadrillas_repo.listar()
        cuadrilla = next((c for c in cuadrillas if c["id"] == cuadrilla_id), None)
        if not cuadrilla:
            raise HTTPException(status_code=404, detail="Cuadrilla no encontrada")
        cuadrillas_repo.asignar(usuario_id, cuadrilla_id, reporte_id)

    return {"mensaje": f"Reporte asignado a {cuadrilla['nombre']}"}
