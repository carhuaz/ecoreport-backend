from ..database import call_proc


def reportes():
    return call_proc("usp_mapa_reportes")
