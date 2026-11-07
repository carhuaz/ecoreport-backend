from fastapi import APIRouter, Depends
from ..database import fetch_all
from ..middleware.auth import get_current_user_role

router = APIRouter(prefix="/api/estadisticas", tags=["Estadísticas"])


@router.get("/resumen")
def resumen(user=Depends(get_current_user_role)):
    total = fetch_all("SELECT COUNT(*) as total FROM reportes")[0]["total"]
    por_estado = fetch_all("SELECT estado, COUNT(*) as cantidad FROM reportes GROUP BY estado")
    por_distrito = fetch_all("SELECT distrito, COUNT(*) as cantidad FROM reportes GROUP BY distrito")
    por_prioridad = fetch_all("SELECT prioridad, COUNT(*) as cantidad FROM reportes GROUP BY prioridad")

    return {
        "total_reportes": total,
        "por_estado": por_estado,
        "por_distrito": por_distrito,
        "por_prioridad": por_prioridad
    }
