from unittest.mock import patch

import pytest
from fastapi import BackgroundTasks, HTTPException

from app.schemas.auth import LoginRequest
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
