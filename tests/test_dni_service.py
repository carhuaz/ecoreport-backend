from unittest.mock import MagicMock, patch

import pytest

from app import dni_service


def _limpiar_estado():
    with dni_service._lock:
        dni_service._dni_cache.clear()
        dni_service._ip_attempts.clear()


def test_consultar_dni_usa_cache_y_evita_doble_llamada():
    _limpiar_estado()
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "success": True,
        "nombres": "ABEL",
        "apellidoPaterno": "CARHUAZ",
        "apellidoMaterno": "PEREZ",
    }
    mock_client = MagicMock()
    mock_client.__enter__.return_value.get.return_value = mock_resp

    with (
        patch.object(dni_service, "APISPERU_TOKEN", "token-demo"),
        patch("app.dni_service.httpx.Client", return_value=mock_client) as client_cls,
    ):
        r1 = dni_service.consultar_dni("70472274", client_ip="1.2.3.4")
        r2 = dni_service.consultar_dni("70472274", client_ip="1.2.3.4")

    assert r1["nombre_completo"] == "Abel Carhuaz Perez"
    assert r2 == r1
    assert client_cls.call_count == 1


def test_consultar_dni_aplica_rate_limit_por_ip():
    _limpiar_estado()
    mock_resp = MagicMock()
    mock_resp.status_code = 404
    mock_client = MagicMock()
    mock_client.__enter__.return_value.get.return_value = mock_resp

    with (
        patch.object(dni_service, "APISPERU_TOKEN", "token-demo"),
        patch("app.dni_service.httpx.Client", return_value=mock_client),
    ):
        for i in range(dni_service._RATE_LIMIT_MAX_CALLS):
            with pytest.raises(dni_service.DniLookupError) as exc:
                dni_service.consultar_dni(f"1000000{i}", client_ip="9.9.9.9")
            assert exc.value.status_code == 404

        with pytest.raises(dni_service.DniLookupError) as exc_limit:
            dni_service.consultar_dni("10000099", client_ip="9.9.9.9")
        assert exc_limit.value.status_code == 429
