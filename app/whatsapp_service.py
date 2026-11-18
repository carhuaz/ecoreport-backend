import logging
import os

import httpx

logger = logging.getLogger(__name__)

TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "").strip()
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "").strip()
TWILIO_WHATSAPP_NUMBER = os.getenv("TWILIO_WHATSAPP_NUMBER", "+14155238886").strip()


def enviar_otp_whatsapp(telefono: str, nombre: str, codigo: str) -> bool:
    """
    Envía el código OTP a través de la API de WhatsApp de Twilio.
    Usa HTTP Basic Auth con el Account SID y Auth Token de Twilio.
    """
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN:
        logger.warning("Twilio no configurado. Se omite el envío por WhatsApp.")
        return False

    # Normalizar número de teléfono (por defecto +51 para Perú si no incluye prefijo)
    numero_limpio = "".join(filter(str.isdigit, telefono))
    if not telefono.startswith("+"):
        if len(numero_limpio) == 9:
            numero_limpio = f"+51{numero_limpio}"
        else:
            numero_limpio = f"+{numero_limpio}"
    else:
        numero_limpio = f"+{numero_limpio}"

    from_number = (
        TWILIO_WHATSAPP_NUMBER
        if TWILIO_WHATSAPP_NUMBER.startswith("whatsapp:")
        else f"whatsapp:{TWILIO_WHATSAPP_NUMBER}"
    )
    to_number = f"whatsapp:{numero_limpio}"

    cuerpo = (
        f"🌿 *EcoReport Huancayo*\n\n"
        f"Hola {nombre},\n"
        f"Tu código de verificación es:\n\n"
        f"👉 *{codigo}*\n\n"
        f"Este código expirará en 10 minutos. Por favor no lo compartas con nadie."
    )

    url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"

    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.post(
                url,
                data={
                    "From": from_number,
                    "To": to_number,
                    "Body": cuerpo,
                },
                auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
            )
            response.raise_for_status()
            logger.info("Mensaje de WhatsApp enviado exitosamente a %s", to_number)
            return True
    except Exception as e:
        logger.exception("Error enviando WhatsApp OTP vía Twilio a %s: %s", to_number, e)
        return False
