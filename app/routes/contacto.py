import random
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from ..database import execute_returning_id
from ..email_service import _enviar, _renderizar, SMTP_USER

router = APIRouter(prefix="/api/contacto", tags=["Contacto"])


class ContactoRequest(BaseModel):
    nombre: str
    email: str
    asunto: str
    mensaje: str


def _construir_acuse_html(nombre: str, codigo: str) -> str:
    return _renderizar("emails/acuse_contacto.html", nombre=nombre, codigo=codigo)


def _construir_notificacion_html(nombre: str, email: str, asunto: str, mensaje: str) -> str:
    return _renderizar("emails/notificacion_contacto.html", nombre=nombre, email=email, asunto=asunto, mensaje=mensaje)


def _enviar_acuse(nombre: str, destinatario: str, codigo: str) -> None:
    try:
        _enviar(destinatario, "EcoReport – Hemos recibido tu mensaje", _construir_acuse_html(nombre, codigo))
    except Exception as exc:
        print(f"[contacto] Error enviando acuse a {destinatario}: {exc}")


def _enviar_notificacion(nombre: str, email: str, asunto_contacto: str, mensaje: str) -> None:
    try:
        _enviar(SMTP_USER, f"Nuevo mensaje de contacto: {nombre} - {asunto_contacto}",
                _construir_notificacion_html(nombre, email, asunto_contacto, mensaje))
    except Exception as exc:
        print(f"[contacto] Error enviando notificación: {exc}")


@router.post("")
def enviar_contacto(req: ContactoRequest, background_tasks: BackgroundTasks):
    if not req.nombre.strip():
        raise HTTPException(status_code=400, detail="El nombre es obligatorio")
    if not req.email.strip() or "@" not in req.email:
        raise HTTPException(status_code=400, detail="Correo electrónico inválido")
    if not req.mensaje.strip():
        raise HTTPException(status_code=400, detail="El mensaje es obligatorio")

    codigo = f"ECO-{random.randint(100000, 999999)}"

    execute_returning_id(
        "INSERT INTO contactos (codigo, nombre, email, asunto, mensaje) OUTPUT INSERTED.id VALUES (?, ?, ?, ?, ?)",
        (codigo, req.nombre.strip(), req.email.strip().lower(), req.asunto, req.mensaje.strip())
    )

    background_tasks.add_task(_enviar_acuse, req.nombre.strip(), req.email.strip().lower(), codigo)
    background_tasks.add_task(_enviar_notificacion, req.nombre.strip(), req.email.strip().lower(), req.asunto, req.mensaje.strip())

    return {"codigo": codigo, "mensaje": "Mensaje registrado con éxito"}
