from unittest.mock import patch

import pytest
from fastapi import BackgroundTasks, HTTPException

from app.schemas.auth import LoginRequest, RegisterRequest, VerifyRequest
from app.schemas.contacto import ContactoRequest
from app.schemas.cuadrilla import CuadrillaCreate
from app.schemas.reporte import CompletarRequest, ReporteCreate
from app.services import (
    auth_service,
    contacto_service,
    cuadrillas_service,
    estadisticas_service,
    reportes_service,
    usuarios_service,
)


def test_usuarios_listar_sin_pagina():
    with patch(
        "app.services.usuarios_service.usuarios_repo.listar",
        return_value=[[{"id": 1, "nombre": "Admin"}]],
    ):
        resultado = usuarios_service.listar(6)

    assert resultado == [{"id": 1, "nombre": "Admin"}]


def test_usuarios_listar_paginado():
    with patch(
        "app.services.usuarios_service.usuarios_repo.listar",
        return_value=[[{"total": 1}], [{"id": 1, "nombre": "Admin"}]],
    ):
        resultado = usuarios_service.listar(6, page=1, page_size=10)

    assert resultado["items"] == [{"id": 1, "nombre": "Admin"}]
    assert resultado["total"] == 1
    assert resultado["total_pages"] == 1


def test_reportes_crear_serializa_json():
    req = ReporteCreate(
        titulo="Título",
        descripcion="Descripción",
        distrito="Huancayo",
        direccion="Calle 1",
        imagenes=["imagen.png"],
        criterios_prioridad=["Basura"],
        puntaje_prioridad=20,
    )

    with patch(
        "app.services.reportes_service.reportes_repo.crear",
        return_value=42,
    ) as crear:
        resultado = reportes_service.crear(1, req)

    assert resultado == {"mensaje": "Reporte creado exitosamente", "id": 42}
    argumentos = crear.call_args.args
    assert argumentos[6] == 1
    assert argumentos[7] == 20
    assert argumentos[9] == '["imagen.png"]'
    assert argumentos[10] == '["Basura"]'


def test_reportes_completar_usa_observacion_por_defecto():
    req = CompletarRequest(evidencias=["evidencia.png"], observacion="")

    with patch("app.services.reportes_service.reportes_repo.completar") as completar:
        reportes_service.completar(7, 42, req)

    completar.assert_called_once_with(
        42,
        7,
        "Trabajo completado",
        '["evidencia.png"]',
    )


def test_cuadrillas_crear_resuelve_responsable():
    req = CuadrillaCreate(
        nombre="Cuadrilla E",
        responsable="Rosa Huamán",
        distrito="El Tambo",
    )

    with patch(
        "app.services.cuadrillas_service.usuarios_service.resolver_responsable",
        return_value=8,
    ) as resolver, patch(
        "app.services.cuadrillas_service.cuadrillas_repo.crear",
    ) as crear:
        resultado = cuadrillas_service.crear(6, req)

    resolver.assert_called_once_with(6, None, "Rosa Huamán")
    crear.assert_called_once_with(6, "Cuadrilla E", 8, "El Tambo", "")
    assert resultado == {"mensaje": "Cuadrilla creada exitosamente"}


def test_estadisticas_resumen():
    result_sets = [
        [{"total": 10}],
        [{"estado": "Pendiente", "cantidad": 5}],
        [{"distrito": "Huancayo", "cantidad": 10}],
        [{"prioridad": "Media", "cantidad": 10}],
    ]

    with patch(
        "app.services.estadisticas_service.estadisticas_repo.resumen",
        return_value=result_sets,
    ):
        resultado = estadisticas_service.resumen()

    assert resultado["total_reportes"] == 10
    assert resultado["por_estado"] == [{"estado": "Pendiente", "cantidad": 5}]
    assert resultado["por_distrito"] == [{"distrito": "Huancayo", "cantidad": 10}]
    assert resultado["por_prioridad"] == [{"prioridad": "Media", "cantidad": 10}]


def test_auth_login():
    user = {
        "id": 1,
        "nombre": "Admin",
        "email": "admin@ecoreport.pe",
        "password": "hash",
        "rol": "Administrador",
        "activo": True,
        "esta_verificado": True,
    }

    with patch("app.services.auth_service.auth_repo.login", return_value=user), patch(
        "app.services.auth_service.verify_password",
        return_value=True,
    ), patch(
        "app.services.auth_service.create_access_token",
        return_value="token",
    ):
        respuesta = auth_service.login(
            LoginRequest(email="admin@ecoreport.pe", password="123456")
        )

    assert respuesta.token == "token"
    assert respuesta.rol == "Administrador"


def test_auth_login_credenciales_invalidas():
    user = {
        "id": 1,
        "nombre": "Admin",
        "email": "admin@ecoreport.pe",
        "password": "hash",
        "rol": "Administrador",
        "activo": True,
        "esta_verificado": True,
    }

    with patch("app.services.auth_service.auth_repo.login", return_value=user), patch(
        "app.services.auth_service.verify_password",
        return_value=False,
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.login(
                LoginRequest(email="admin@ecoreport.pe", password="incorrecta")
            )

    assert error.value.status_code == 401


def test_contacto_crear_programa_correos():
    background_tasks = BackgroundTasks()
    req = ContactoRequest(
        nombre="  Ciudadano  ",
        email="  CIUDADANO@ECOREPORT.PE  ",
        asunto="Consulta",
        mensaje="  Mensaje  ",
    )

    with patch("app.services.contacto_service.contacto_repo.crear") as crear:
        resultado = contacto_service.crear(req, background_tasks)

    crear.assert_called_once()
    argumentos = crear.call_args.args
    assert argumentos[1] == "Ciudadano"
    assert argumentos[2] == "ciudadano@ecoreport.pe"
    assert argumentos[4] == "Mensaje"
    assert resultado["mensaje"] == "Mensaje registrado con éxito"
    assert len(background_tasks.tasks) == 2


def _usuario_verificacion(**overrides):
    usuario = {
        "id": 1,
        "nombre": "Ana",
        "email": "ana@example.com",
        "password": "hash",
        "codigo_verificacion": "hash",
        "codigo_expira": None,
        "intentos_verificacion": 0,
        "ultimo_envio_codigo": None,
        "codigo_expirado": 0,
        "segundos_desde_envio": 120,
        "esta_verificado": 0,
        "activo": 1,
        "rol": "Ciudadano",
    }
    usuario.update(overrides)
    return usuario


def test_auth_register_nuevo_usuario():
    background_tasks = BackgroundTasks()
    req = RegisterRequest(
        nombre="  Ana  ",
        email="  ANA@EXAMPLE.COM  ",
        password="secret123",
        dni="12345678",
    )

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=None,
    ), patch(
        "app.services.auth_service.generar_otp",
        return_value="123456",
    ), patch(
        "app.services.auth_service.hash_password",
        side_effect=lambda value: f"hash:{value}",
    ), patch(
        "app.services.auth_service.auth_repo.registrar",
        return_value=10,
    ) as registrar, patch(
        "app.services.auth_service.disparar_verificacion",
    ) as disparar:
        resultado = auth_service.register(req, background_tasks)

    registrar.assert_called_once_with(
        "Ana",
        "ana@example.com",
        "hash:secret123",
        "12345678",
        "hash:123456",
    )
    disparar.assert_called_once_with(
        background_tasks,
        "Ana",
        "ana@example.com",
        "123456",
    )
    assert resultado["id"] == 10


def test_auth_register_email_verificado():
    req = RegisterRequest(
        nombre="Ana",
        email="ana@example.com",
        password="secret123",
        dni="12345678",
    )

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value={"esta_verificado": 1},
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.register(req, BackgroundTasks())

    assert error.value.status_code == 400


def test_auth_register_cooldown():
    req = RegisterRequest(
        nombre="Ana",
        email="ana@example.com",
        password="secret123",
        dni="12345678",
    )

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value={
            "esta_verificado": 0,
            "segundos_desde_envio": 30,
        },
    ), patch(
        "app.services.auth_service.OTP_RESEND_COOLDOWN_SECONDS",
        60,
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.register(req, BackgroundTasks())

    assert error.value.status_code == 429
    assert "30 segundos" in error.value.detail


def test_auth_verify_exitoso():
    req = VerifyRequest(email="ana@example.com", codigo="123456")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(),
    ), patch(
        "app.services.auth_service.verify_password",
        return_value=True,
    ), patch(
        "app.services.auth_service.auth_repo.marcar_verificado",
    ) as marcar:
        resultado = auth_service.verify(req)

    marcar.assert_called_once_with(1)
    assert "verificada" in resultado["mensaje"]


def test_auth_verify_codigo_expirado():
    req = VerifyRequest(email="ana@example.com", codigo="123456")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(codigo_expirado=1),
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.verify(req)

    assert error.value.status_code == 400
    assert "expiró" in error.value.detail


def test_auth_verify_intentos_agotados():
    req = VerifyRequest(email="ana@example.com", codigo="123456")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(intentos_verificacion=5),
    ), patch(
        "app.services.auth_service.OTP_MAX_ATTEMPTS",
        5,
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.verify(req)

    assert error.value.status_code == 429


def test_auth_verify_codigo_incorrecto_incrementa_intentos():
    req = VerifyRequest(email="ana@example.com", codigo="000000")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(intentos_verificacion=1),
    ), patch(
        "app.services.auth_service.verify_password",
        return_value=False,
    ), patch(
        "app.services.auth_service.auth_repo.registrar_intento_fallido",
        return_value=2,
    ) as registrar_intento, patch(
        "app.services.auth_service.OTP_MAX_ATTEMPTS",
        5,
    ):
        with pytest.raises(HTTPException) as error:
            auth_service.verify(req)

    registrar_intento.assert_called_once_with(1)
    assert error.value.status_code == 400
    assert "3 intentos" in error.value.detail


def test_auth_reenviar_cooldown():
    req = VerifyRequest(email="ana@example.com", codigo="")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(segundos_desde_envio=20),
    ), patch(
        "app.services.auth_service.OTP_RESEND_COOLDOWN_SECONDS",
        60,
    ), patch(
        "app.services.auth_service.auth_repo.guardar_codigo",
    ) as guardar:
        with pytest.raises(HTTPException) as error:
            auth_service.reenviar_codigo(req, BackgroundTasks())

    guardar.assert_not_called()
    assert error.value.status_code == 429
    assert "40 segundos" in error.value.detail


def test_auth_reenviar_exitoso():
    background_tasks = BackgroundTasks()
    req = VerifyRequest(email="ana@example.com", codigo="")

    with patch(
        "app.services.auth_service.auth_repo.obtener_por_email",
        return_value=_usuario_verificacion(),
    ), patch(
        "app.services.auth_service.generar_otp",
        return_value="654321",
    ), patch(
        "app.services.auth_service.hash_password",
        return_value="hash:nuevo",
    ), patch(
        "app.services.auth_service.auth_repo.guardar_codigo",
    ) as guardar, patch(
        "app.services.auth_service.disparar_verificacion",
    ) as disparar:
        resultado = auth_service.reenviar_codigo(req, background_tasks)

    guardar.assert_called_once_with(1, "hash:nuevo")
    disparar.assert_called_once_with(
        background_tasks,
        "Ana",
        "ana@example.com",
        "654321",
    )
    assert "reenviado" in resultado["mensaje"]
