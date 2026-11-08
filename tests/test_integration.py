import pytest
from fastapi.testclient import TestClient

from app.config import DB_PASSWORD, DB_USER
from app.database import call_proc
from app.main import app


def _db_disponible() -> bool:
    if not DB_USER or not DB_PASSWORD:
        return False
    try:
        call_proc("usp_cuadrillas_listar")
        return True
    except Exception:
        return False


pytestmark = pytest.mark.skipif(
    not _db_disponible(),
    reason="SQL Server no disponible o credenciales no configuradas",
)


def _login(client: TestClient, email: str) -> dict:
    response = client.post(
        "/api/auth/login",
        json={"email": email, "password": "123456"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['token']}"}


def test_login_y_consultas_admin():
    client = TestClient(app)
    headers = _login(client, "admin@ecoreport.pe")

    assert client.get("/api/auth/me", headers=headers).status_code == 200
    assert client.get("/api/cuadrillas", headers=headers).status_code == 200
    assert (
        client.get("/api/cuadrillas/disponibles", headers=headers).status_code == 200
    )

    usuarios = client.get("/api/usuarios?page=1&page_size=2", headers=headers)
    assert usuarios.status_code == 200
    assert usuarios.json()["total"] == 8

    reportes = client.get("/api/reportes?page=1&page_size=2", headers=headers)
    assert reportes.status_code == 200
    assert reportes.json()["total"] == 40

    auditoria = client.get(
        "/api/reportes/auditoria-evidencias?page=1&page_size=2",
        headers=headers,
    )
    assert auditoria.status_code == 200
    assert auditoria.json()["total"] == 4


def test_reportes_publicos_sin_token():
    client = TestClient(app)
    response = client.get("/api/reportes/publicos?page=1&page_size=2")

    assert response.status_code == 200
    assert response.json()["total"] > 0
    assert len(response.json()["items"]) == 2


def test_estadisticas_resumen():
    client = TestClient(app)
    headers = _login(client, "admin@ecoreport.pe")

    response = client.get("/api/estadisticas/resumen", headers=headers)

    assert response.status_code == 200
    assert response.json()["total_reportes"] == 40
    assert response.json()["por_estado"]
    assert response.json()["por_distrito"]
    assert response.json()["por_prioridad"]


def test_responsable_solo_accede_a_sus_cuadrillas():
    client = TestClient(app)
    headers = _login(client, "carlos@ecoreport.pe")

    propias = client.get("/api/cuadrillas/mis-cuadrillas", headers=headers)
    assert propias.status_code == 200
    assert all(c["responsableId"] == 7 for c in propias.json())

    ajenas = client.get(
        "/api/reportes/cuadrilla/2?page=1&page_size=2",
        headers=headers,
    )
    assert ajenas.status_code == 403


def test_ciudadano_no_puede_listar_usuarios():
    client = TestClient(app)
    headers = _login(client, "ciudadano@ecoreport.pe")

    response = client.get("/api/usuarios", headers=headers)

    assert response.status_code == 403


def test_errores_de_negocio_se_traducen():
    client = TestClient(app)
    validador = _login(client, "validador1@ecoreport.pe")
    ciudadano = _login(client, "ciudadano@ecoreport.pe")

    inexistente = client.post(
        "/api/reportes/99999/aprobar",
        headers=validador,
        json={"observacion": "x"},
    )
    assert inexistente.status_code == 404

    dni_invalido = client.post(
        "/api/auth/register",
        json={
            "nombre": "Prueba",
            "email": "prueba.integracion@ecoreport.pe",
            "password": "123456",
            "dni": "123",
        },
    )
    assert dni_invalido.status_code == 400

    contacto_invalido = client.post(
        "/api/contacto",
        json={
            "nombre": "Prueba",
            "email": "correo-invalido",
            "asunto": "Asunto",
            "mensaje": "Mensaje",
        },
    )
    assert contacto_invalido.status_code == 400

    login_invalido = client.post(
        "/api/auth/login",
        json={"email": "ciudadano@ecoreport.pe", "password": "incorrecta"},
    )
    assert login_invalido.status_code == 401

    assert client.get("/api/reportes/mis-reportes", headers=ciudadano).status_code == 200


def test_mapa_no_registrado():
    client = TestClient(app)
    headers = _login(client, "admin@ecoreport.pe")

    assert client.get("/api/mapa/reportes", headers=headers).status_code == 404
