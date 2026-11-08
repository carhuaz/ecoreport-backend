from fastapi import APIRouter, Depends

from ..middleware.auth import get_current_user_role
from ..services import estadisticas_service

router = APIRouter(prefix="/api/estadisticas", tags=["Estadísticas"])


@router.get("/resumen")
def resumen(user=Depends(get_current_user_role)):
    return estadisticas_service.resumen()
