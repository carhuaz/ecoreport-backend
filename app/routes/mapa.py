from fastapi import APIRouter, Depends
from ..database import fetch_all
from ..middleware.auth import get_current_user_role

router = APIRouter(prefix="/api/mapa", tags=["Mapa"])


@router.get("/reportes")
def reportes_mapa(user=Depends(get_current_user_role)):
    rows = fetch_all("""
        SELECT r.id, r.titulo, r.descripcion, r.distrito, r.direccion,
               r.estado, r.prioridad, r.latitud, r.longitud,
               FORMAT(r.fecha, 'yyyy-MM-dd') as fecha,
               u.nombre as ciudadano
        FROM reportes r
        LEFT JOIN usuarios u ON r.ciudadano_id = u.id
        WHERE r.latitud IS NOT NULL AND r.longitud IS NOT NULL
          AND r.estado NOT IN ('Rechazado')
        ORDER BY r.fecha DESC
    """)
    return rows
