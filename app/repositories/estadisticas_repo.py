from ..database import call_proc_multi


def resumen():
    return call_proc_multi("usp_estadisticas_resumen")
