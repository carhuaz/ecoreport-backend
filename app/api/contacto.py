from fastapi import APIRouter, BackgroundTasks

from ..schemas.contacto import ContactoRequest
from ..services import contacto_service

router = APIRouter(prefix="/api/contacto", tags=["Contacto"])


@router.post("")
def enviar_contacto(req: ContactoRequest, background_tasks: BackgroundTasks):
    return contacto_service.crear(req, background_tasks)
