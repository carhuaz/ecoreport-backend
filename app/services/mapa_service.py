from ..repositories import mapa_repo
from .common import normalizar_mapa
from .errors import manejar_errores_bd


def reportes():
    with manejar_errores_bd():
        rows = mapa_repo.reportes()
    return [normalizar_mapa(r) for r in rows]
