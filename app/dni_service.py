import logging
import re

import httpx

from .config import APISPERU_TOKEN

logger = logging.getLogger(__name__)

_DNI_REGEX = re.compile(r"^\d{8}$")
_APISPERU_URL = "https://dniruc.apisperu.com/api/v1/dni/{dni}"


class DniLookupError(Exception):
    """Error al consultar o validar un DNI en APISPERU."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def consultar_dni(dni: str) -> dict:
    """Consulta un DNI de 8 dígitos en APISPERU y devuelve los datos normalizados."""
    dni_limpio = dni.strip()
    if not _DNI_REGEX.match(dni_limpio):
        raise DniLookupError("El DNI debe tener exactamente 8 dígitos numéricos.", 400)

    if not APISPERU_TOKEN:
        raise DniLookupError("Servicio de validación de DNI no configurado.", 503)

    url = _APISPERU_URL.format(dni=dni_limpio)
    try:
        with httpx.Client(timeout=8.0) as client:
            response = client.get(url, params={"token": APISPERU_TOKEN})
    except httpx.HTTPError as exc:
        logger.exception("Error de red consultando APISPERU para DNI %s", dni_limpio)
        raise DniLookupError(
            "No se pudo conectar con RENIEC/APISPERU. Intenta nuevamente.", 503
        ) from exc

    if response.status_code == 404:
        raise DniLookupError("El DNI ingresado no fue encontrado en RENIEC.", 404)

    if response.status_code in (401, 403):
        logger.error("Token de APISPERU inválido o sin permisos (status %s)", response.status_code)
        raise DniLookupError("Token de APISPERU inválido o expirado.", 503)

    if response.status_code >= 400:
        raise DniLookupError("Error consultando el DNI en APISPERU.", 502)

    data = response.json()
    if not data.get("success") or not data.get("nombres"):
        raise DniLookupError("El DNI ingresado no existe en RENIEC.", 404)

    nombres = str(data.get("nombres", "")).strip()
    paterno = str(data.get("apellidoPaterno", "")).strip()
    materno = str(data.get("apellidoMaterno", "")).strip()
    nombre_completo = " ".join(part for part in (nombres, paterno, materno) if part).title()

    return {
        "dni": dni_limpio,
        "nombres": nombres.title(),
        "apellido_paterno": paterno.title(),
        "apellido_materno": materno.title(),
        "nombre_completo": nombre_completo,
    }
