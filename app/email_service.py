import logging
import secrets
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr, formatdate, make_msgid
from pathlib import Path

from fastapi import BackgroundTasks
from jinja2 import Environment, FileSystemLoader

from .config import (
    OTP_EXPIRE_MINUTES,
    SMTP_FROM_NAME,
    SMTP_HOST,
    SMTP_PASSWORD,
    SMTP_PORT,
    SMTP_REPLY_TO,
    SMTP_TIMEOUT,
    SMTP_USER,
)

logger = logging.getLogger(__name__)

TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
_jinja_env = Environment(loader=FileSystemLoader(str(TEMPLATES_DIR)), autoescape=True)


def _renderizar(nombre_template: str, **kwargs) -> str:
    return _jinja_env.get_template(nombre_template).render(**kwargs)


def generar_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _enviar(destinatario: str, asunto: str, html: str, texto: str | None = None) -> None:
    if not SMTP_USER or not SMTP_PASSWORD:
        raise RuntimeError("SMTP no configurado")

    msg = MIMEMultipart("alternative")
    msg["From"] = formataddr((SMTP_FROM_NAME, SMTP_USER))
    msg["To"] = destinatario
    msg["Subject"] = asunto
    msg["Date"] = formatdate(localtime=True)
    msg["Reply-To"] = SMTP_REPLY_TO or SMTP_USER
    msg["Content-Language"] = "es"
    msg["X-Mailer"] = "EcoReport Backend"
    domain = SMTP_USER.split("@")[-1] if "@" in SMTP_USER else None
    msg["Message-ID"] = make_msgid(domain=domain)

    if texto:
        msg.attach(MIMEText(texto, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=SMTP_TIMEOUT) as server:
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)


def enviar_otp_background(nombre: str, destinatario: str, codigo: str) -> None:
    try:
        html = _renderizar(
            "emails/verificacion.html",
            nombre=nombre,
            codigo=codigo,
            minutos=OTP_EXPIRE_MINUTES,
        )
        texto = _renderizar(
            "emails/verificacion.txt",
            nombre=nombre,
            codigo=codigo,
            minutos=OTP_EXPIRE_MINUTES,
        )
        _enviar(destinatario, "EcoReport - Tu codigo de verificacion", html, texto)
    except Exception:
        logger.exception("Error enviando OTP a %s", destinatario)


def disparar_verificacion(
    background_tasks: BackgroundTasks,
    nombre: str,
    email: str,
    codigo: str,
) -> None:
    background_tasks.add_task(enviar_otp_background, nombre, email, codigo)
