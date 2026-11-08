from ..repositories import estadisticas_repo
from .errors import manejar_errores_bd


def resumen():
    with manejar_errores_bd():
        result_sets = estadisticas_repo.resumen()

    total = result_sets[0][0]["total"] if result_sets and result_sets[0] else 0
    return {
        "total_reportes": total,
        "por_estado": result_sets[1] if len(result_sets) > 1 else [],
        "por_distrito": result_sets[2] if len(result_sets) > 2 else [],
        "por_prioridad": result_sets[3] if len(result_sets) > 3 else [],
    }
