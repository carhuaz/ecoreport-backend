from ..database import call_proc, call_proc_multi, call_proc_scalar


def listar(estado, distrito, prioridad, page, page_size):
    return call_proc_multi(
        "usp_reportes_listar",
        (estado, distrito, prioridad, page, page_size),
    )


def publicos(distrito, estado, page, page_size):
    return call_proc_multi(
        "usp_reportes_publicos",
        (distrito, estado, page, page_size),
    )


def por_ciudadano(ciudadano_id, page, page_size):
    return call_proc_multi(
        "usp_reportes_por_ciudadano",
        (ciudadano_id, page, page_size),
    )


def por_cuadrilla(usuario_id, cuadrilla_id, estado, page, page_size):
    return call_proc_multi(
        "usp_reportes_por_cuadrilla",
        (usuario_id, cuadrilla_id, estado, page, page_size),
    )


def auditoria_evidencias(usuario_id, page, page_size, cuadrilla_id, estado):
    return call_proc_multi(
        "usp_reportes_auditoria_evidencias",
        (usuario_id, page, page_size, cuadrilla_id, estado),
    )


def auditoria_validaciones(usuario_id, page, page_size):
    return call_proc_multi(
        "usp_reportes_auditoria_validaciones",
        (usuario_id, page, page_size),
    )


def crear(
    titulo,
    descripcion,
    distrito,
    direccion,
    latitud,
    longitud,
    ciudadano_id,
    puntaje_prioridad,
    anonimo,
    imagenes_json,
    criterios_json,
):
    return call_proc_scalar(
        "usp_reporte_crear",
        (
            titulo,
            descripcion,
            distrito,
            direccion,
            latitud,
            longitud,
            ciudadano_id,
            puntaje_prioridad,
            anonimo,
            imagenes_json,
            criterios_json,
        ),
    )


def aprobar(reporte_id, usuario_id, observacion):
    call_proc("usp_reporte_aprobar", (reporte_id, usuario_id, observacion))


def rechazar(reporte_id, usuario_id, observacion):
    call_proc("usp_reporte_rechazar", (reporte_id, usuario_id, observacion))


def en_atencion(reporte_id, usuario_id):
    call_proc("usp_reporte_en_atencion", (reporte_id, usuario_id))


def completar(reporte_id, usuario_id, observacion, evidencias_json):
    call_proc(
        "usp_reporte_completar",
        (reporte_id, usuario_id, observacion, evidencias_json),
    )


def obtener(reporte_id):
    rows = call_proc("usp_reporte_obtener", (reporte_id,))
    return rows[0] if rows else None


def historial(reporte_id):
    return call_proc("usp_reporte_historial", (reporte_id,))
