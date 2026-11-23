import logging
import re
import threading
import time

import httpx

from .config import APISPERU_TOKEN

logger = logging.getLogger(__name__)

_DNI_REGEX = re.compile(r"^\d{8}$")
_APISPERU_URL = "https://dniruc.apisperu.com/api/v1/dni/{dni}"

_CACHE_TTL_SECONDS = 86_400  # 24 horas
_CACHE_MAX_ITEMS = 2_000
_RATE_LIMIT_MAX_CALLS = 5
_RATE_LIMIT_WINDOW_SECONDS = 600  # 10 minutos

_lock = threading.Lock()
_dni_cache: dict[str, tuple[float, dict]] = {}
_ip_attempts: dict[str, list[float]] = {}


class DniLookupError(Exception):
    """Error al consultar o validar un DNI en APISPERU."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _obtener_de_cache(dni: str) -> dict | None:
    ahora = time.monotonic()
    with _lock:
        entrada = _dni_cache.get(dni)
        if not entrada:
            return None
        expira, datos = entrada
        if ahora >= expira:
            del _dni_cache[dni]
            return None
        return dict(datos)


def _guardar_en_cache(dni: str, datos: dict) -> None:
    ahora = time.monotonic()
    with _lock:
        if len(_dni_cache) >= _CACHE_MAX_ITEMS:
            expirados = [k for k, (exp, _) in _dni_cache.items() if ahora >= exp]
            for k in expirados:
                del _dni_cache[k]
            if len(_dni_cache) >= _CACHE_MAX_ITEMS:
                primer_key = next(iter(_dni_cache))
                del _dni_cache[primer_key]
        _dni_cache[dni] = (ahora + _CACHE_TTL_SECONDS, dict(datos))


def _verificar_rate_limit(client_ip: str | None) -> None:
    if not client_ip:
        return
    ahora = time.monotonic()
    limite_inicio = ahora - _RATE_LIMIT_WINDOW_SECONDS
    with _lock:
        recientes = [ts for ts in _ip_attempts.get(client_ip, []) if ts > limite_inicio]
        if len(recientes) >= _RATE_LIMIT_MAX_CALLS:
            _ip_attempts[client_ip] = recientes
            restantes = max(1, int((recientes[0] + _RATE_LIMIT_WINDOW_SECONDS - ahora) / 60) + 1)
            raise DniLookupError(
                f"Has alcanzado el límite de validaciones de DNI. Intenta en {restantes} min.",
                429,
            )
        recientes.append(ahora)
        _ip_attempts[client_ip] = recientes


def consultar_dni(dni: str, client_ip: str | None = None) -> dict:
    """Consulta un DNI de 8 dígitos en APISPERU con caché (24h) y límite por IP."""
    dni_limpio = dni.strip()
    if not _DNI_REGEX.match(dni_limpio):
        raise DniLookupError("El DNI debe tener exactamente 8 dígitos numéricos.", 400)

    en_cache = _obtener_de_cache(dni_limpio)
    if en_cache is not None:
        return en_cache

    if not APISPERU_TOKEN:
        raise DniLookupError("Servicio de validación de DNI no configurado.", 503)

    _verificar_rate_limit(client_ip)

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

    resultado = {
        "dni": dni_limpio,
        "nombres": nombres.title(),
        "apellido_paterno": paterno.title(),
        "apellido_materno": materno.title(),
        "nombre_completo": nombre_completo,
    }
    _guardar_en_cache(dni_limpio, resultado)
    return resultado
