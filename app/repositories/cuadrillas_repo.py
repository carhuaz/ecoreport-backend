from ..database import call_proc, call_proc_scalar


def listar():
    return call_proc("usp_cuadrillas_listar")


def disponibles():
    return call_proc("usp_cuadrillas_disponibles")


def por_responsable(responsable_id, usuario_id):
    return call_proc("usp_cuadrillas_por_responsable", (responsable_id, usuario_id))


def crear(usuario_id, nombre, responsable_id, distrito, zona_asignada):
    return call_proc_scalar(
        "usp_cuadrilla_crear",
        (usuario_id, nombre, responsable_id, distrito, zona_asignada),
    )


def actualizar(
    usuario_id,
    cuadrilla_id,
    nombre,
    responsable_id,
    distrito,
    zona_asignada,
):
    call_proc(
        "usp_cuadrilla_actualizar",
        (usuario_id, cuadrilla_id, nombre, responsable_id, distrito, zona_asignada),
    )


def eliminar(usuario_id, cuadrilla_id):
    call_proc("usp_cuadrilla_eliminar", (usuario_id, cuadrilla_id))


def asignar(usuario_id, cuadrilla_id, reporte_id):
    call_proc("usp_cuadrilla_asignar", (usuario_id, cuadrilla_id, reporte_id))
