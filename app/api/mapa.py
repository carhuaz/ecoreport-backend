from fastapi import APIRouter, Depends

from ..middleware.auth import get_current_user_role
from ..services import mapa_service

router = APIRouter(prefix="/api/mapa", tags=["Mapa"])


@router.get("/reportes")
def reportes_mapa(user=Depends(get_current_user_role)):
    return mapa_service.reportes()
