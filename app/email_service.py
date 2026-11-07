import smtplib
import random
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from jinja2 import Environment, FileSystemLoader
from fastapi import BackgroundTasks
from .config import SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD


TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
_jinja_env = Environment(loader=FileSystemLoader(str(TEMPLATES_DIR)), autoescape=True)


def _renderizar(nombre_template: str, **kwargs) -> str:
    return _jinja_env.get_template(nombre_template).render(**kwargs)


def generar_otp() -> str:
    return f"{random.randint(0, 999999):06d}"


def _enviar(destinatario: str, asunto: str, html: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["From"] = SMTP_USER
    msg["To"] = destinatario
    msg["Subject"] = asunto
    
    # 3. Se añaden encabezados explícitos de idioma y codificación al correo
    msg["Content-Language"] = "es"
    
    # 4. Aseguramos que el MIMEText use codificación utf-8 explícita
    html_part = MIMEText(html, "html", "utf-8")
    msg.attach(html_part)

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)


def enviar_otp_background(nombre: str, destinatario: str, codigo: str) -> None:
    """Wrapper para BackgroundTasks – recibe solo args serializables."""
    try:
        html = _renderizar("emails/verificacion.html", nombre=nombre, codigo=codigo)
        _enviar(destinatario, "EcoReport – Verifica tu cuenta", html)
    except Exception as exc:
        print(f"[email_service] Error enviando OTP a {destinatario}: {exc}")


def disparar_verificacion(background_tasks: BackgroundTasks, nombre: str, email: str, codigo: str) -> None:
    background_tasks.add_task(enviar_otp_background, nombre, email, codigo)
