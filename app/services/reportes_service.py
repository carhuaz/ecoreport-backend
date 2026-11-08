import json

from fastapi import HTTPException

from ..repositories import reportes_repo
from ..schemas.reporte import CompletarRequest, ReporteCreate, ValidacionRequest
from .common import (
    normalizar_auditoria,
    normalizar_evidencia,
    normalizar_reporte,
    paginar_resultados,
)
from .errors import manejar_errores_bd


def _paginar_reportes(result_sets, page, page_size):
    resultado = paginar_resultados(result_sets, page, page_size)
    resultado["items"] = [normalizar_reporte(r) for r in resultado["items"]]
    return resultado


def listar(estado, distrito, prioridad, page, page_size):
    with manejar_errores_bd():
        result_sets = reportes_repo.listar(
            estado,
            distrito,
            prioridad,
            page,
            page_size,
        )
    return _paginar_reportes(result_sets, page, page_size)


def publicos(distrito, estado, page, page_size):
    with manejar_errores_bd():
        result_sets = reportes_repo.publicos(distrito, estado, page, page_size)
    return _paginar_reportes(result_sets, page, page_size)


def mis_reportes(ciudadano_id, page, page_size):
    with manejar_errores_bd():
        result_sets = reportes_repo.por_ciudadano(ciudadano_id, page, page_size)
    return _paginar_reportes(result_sets, page, page_size)


def por_cuadrilla(usuario_id, cuadrilla_id, estado, page, page_size):
    with manejar_errores_bd():
        result_sets = reportes_repo.por_cuadrilla(
            usuario_id,
            cuadrilla_id,
            estado,
            page,
            page_size,
        )
    return _paginar_reportes(result_sets, page, page_size)


def auditoria_evidencias(usuario_id, page, page_size, cuadrilla_id, estado):
    with manejar_errores_bd():
        result_sets = reportes_repo.auditoria_evidencias(
            usuario_id,
            page,
            page_size,
            cuadrilla_id,
            estado,
        )
    resultado = paginar_resultados(result_sets, page, page_size)
    resultado["items"] = [normalizar_evidencia(r) for r in resultado["items"]]
    return resultado


def auditoria_validaciones(usuario_id, page, page_size):
    with manejar_errores_bd():
        result_sets = reportes_repo.auditoria_validaciones(
            usuario_id,
            page,
            page_size,
        )
    resultado = paginar_resultados(result_sets, page, page_size)
    resultado["items"] = [normalizar_auditoria(r) for r in resultado["items"]]
    return resultado


def crear(ciudadano_id, req: ReporteCreate):
    imagenes_json = json.dumps(req.imagenes or [], ensure_ascii=False)
    criterios_json = json.dumps(req.criterios_prioridad or [], ensure_ascii=False)

    with manejar_errores_bd():
        reporte_id = reportes_repo.crear(
            req.titulo,
            req.descripcion,
            req.distrito,
            req.direccion,
            req.latitud,
            req.longitud,
            ciudadano_id,
            req.puntaje_prioridad or 0,
            req.anonimo,
            imagenes_json,
            criterios_json,
        )

    return {"mensaje": "Reporte creado exitosamente", "id": reporte_id}


def aprobar(usuario_id, reporte_id, req: ValidacionRequest):
    with manejar_errores_bd():
        reportes_repo.aprobar(reporte_id, usuario_id, req.observacion)
    return {"mensaje": "Reporte aprobado"}


def rechazar(usuario_id, reporte_id, req: ValidacionRequest):
    with manejar_errores_bd():
        reportes_repo.rechazar(reporte_id, usuario_id, req.observacion)
    return {"mensaje": "Reporte rechazado"}


def marcar_en_atencion(usuario_id, reporte_id):
    with manejar_errores_bd():
        reportes_repo.en_atencion(reporte_id, usuario_id)
    return {"mensaje": "Reporte en atención"}


def completar(usuario_id, reporte_id, req: CompletarRequest):
    evidencias_json = json.dumps(req.evidencias or [], ensure_ascii=False)
    observacion = req.observacion or "Trabajo completado"

    with manejar_errores_bd():
        reportes_repo.completar(
            reporte_id,
            usuario_id,
            observacion,
            evidencias_json,
        )
    return {"mensaje": "Reporte completado con evidencias"}


def obtener(reporte_id):
    with manejar_errores_bd():
        reporte = reportes_repo.obtener(reporte_id)
    if not reporte:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    return normalizar_reporte(reporte)


def historial(reporte_id):
    with manejar_errores_bd():
        return reportes_repo.historial(reporte_id)
