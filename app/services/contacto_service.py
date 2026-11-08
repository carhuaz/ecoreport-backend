import logging
import secrets

from fastapi import BackgroundTasks

from ..email_service import SMTP_USER, _enviar, _renderizar
from ..repositories import contacto_repo
from ..schemas.contacto import ContactoRequest
from .errors import manejar_errores_bd

logger = logging.getLogger(__name__)


def _construir_acuse_html(nombre: str, codigo: str) -> str:
    return _renderizar("emails/acuse_contacto.html", nombre=nombre, codigo=codigo)


def _construir_notificacion_html(
    nombre: str,
    email: str,
    asunto: str,
    mensaje: str,
) -> str:
    return _renderizar(
        "emails/notificacion_contacto.html",
        nombre=nombre,
        email=email,
        asunto=asunto,
        mensaje=mensaje,
    )


def _enviar_acuse(nombre: str, destinatario: str, codigo: str) -> None:
    try:
        _enviar(
            destinatario,
            "EcoReport – Hemos recibido tu mensaje",
            _construir_acuse_html(nombre, codigo),
        )
    except Exception:
        logger.exception("Error enviando acuse a %s", destinatario)


def _enviar_notificacion(
    nombre: str,
    email: str,
    asunto_contacto: str,
    mensaje: str,
) -> None:
    try:
        _enviar(
            SMTP_USER,
            f"Nuevo mensaje de contacto: {nombre} - {asunto_contacto}",
            _construir_notificacion_html(nombre, email, asunto_contacto, mensaje),
        )
    except Exception:
        logger.exception("Error enviando notificación")


def crear(req: ContactoRequest, background_tasks: BackgroundTasks) -> dict:
    codigo = f"ECO-{secrets.randbelow(900000) + 100000}"
    nombre = req.nombre.strip()
    email = req.email.strip().lower()
    mensaje = req.mensaje.strip()

    with manejar_errores_bd():
        contacto_repo.crear(codigo, nombre, email, req.asunto, mensaje)

    background_tasks.add_task(_enviar_acuse, nombre, email, codigo)
    background_tasks.add_task(
        _enviar_notificacion,
        nombre,
        email,
        req.asunto,
        mensaje,
    )

    return {"codigo": codigo, "mensaje": "Mensaje registrado con éxito"}
