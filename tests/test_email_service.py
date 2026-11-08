from unittest.mock import MagicMock, patch

import pytest

from app import email_service


def test_generar_otp_formato():
    with patch("app.email_service.secrets.randbelow", return_value=42):
        assert email_service.generar_otp() == "000042"


def test_enviar_incluye_texto_html_y_headers():
    smtp = MagicMock()
    smtp.__enter__.return_value = smtp

    with patch.multiple(
        "app.email_service",
        SMTP_USER="smtp@example.com",
        SMTP_PASSWORD="secret",
        SMTP_FROM_NAME="EcoReport Huancayo",
        SMTP_REPLY_TO="reply@example.com",
        SMTP_TIMEOUT=5,
    ), patch("app.email_service.smtplib.SMTP", return_value=smtp):
        email_service._enviar(
            "destino@example.com",
            "Asunto",
            "<p>Hola</p>",
            "Hola",
        )

    mensaje = smtp.send_message.call_args.args[0]
    assert "EcoReport Huancayo" in mensaje["From"]
    assert mensaje["To"] == "destino@example.com"
    assert mensaje["Reply-To"] == "reply@example.com"
    assert mensaje["Content-Language"] == "es"
    assert "example.com" in mensaje["Message-ID"]
    assert mensaje["Date"]

    partes = mensaje.get_payload()
    assert [parte.get_content_type() for parte in partes] == [
        "text/plain",
        "text/html",
    ]
    assert partes[0].get_payload(decode=True).decode() == "Hola"
    assert partes[1].get_payload(decode=True).decode() == "<p>Hola</p>"

    smtp.starttls.assert_called_once()
    smtp.login.assert_called_once_with("smtp@example.com", "secret")
    smtp.send_message.assert_called_once_with(mensaje)


def test_enviar_sin_smtp_configurado():
    with patch.multiple(
        "app.email_service",
        SMTP_USER="",
        SMTP_PASSWORD="",
    ):
        with pytest.raises(RuntimeError):
            email_service._enviar("destino@example.com", "Asunto", "<p>Hola</p>")


def test_enviar_otp_background_renderiza_html_y_texto():
    with patch(
        "app.email_service._enviar",
    ) as enviar, patch(
        "app.email_service.OTP_EXPIRE_MINUTES",
        10,
    ):
        email_service.enviar_otp_background("Ana", "ana@example.com", "123456")

    destinatario, asunto, html, texto = enviar.call_args.args
    assert destinatario == "ana@example.com"
    assert "verificacion" in asunto
    assert "123456" in html
    assert "10 minutos" in html
    assert "123456" in texto
    assert "10 minutos" in texto


def test_enviar_otp_background_registra_error():
    with patch(
        "app.email_service._renderizar",
        side_effect=RuntimeError("fallo"),
    ), patch(
        "app.email_service.logger.exception",
    ) as logger_exception:
        email_service.enviar_otp_background("Ana", "ana@example.com", "123456")

    logger_exception.assert_called_once()
