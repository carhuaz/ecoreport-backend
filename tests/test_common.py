from decimal import Decimal

from app.services.common import (
    normalizar_auditoria,
    normalizar_evidencia,
    normalizar_reporte,
    paginar_resultados,
)


def test_paginar_resultados():
    result_sets = [
        [{"total": 5}],
        [{"id": 3}, {"id": 4}],
    ]

    resultado = paginar_resultados(result_sets, page=2, page_size=2)

    assert resultado["items"] == [{"id": 3}, {"id": 4}]
    assert resultado["total"] == 5
    assert resultado["page"] == 2
    assert resultado["page_size"] == 2
    assert resultado["total_pages"] == 3


def test_paginar_resultados_vacio():
    resultado = paginar_resultados([], page=1, page_size=20)

    assert resultado["items"] == []
    assert resultado["total"] == 0
    assert resultado["total_pages"] == 1


def test_normalizar_reporte():
    reporte = normalizar_reporte(
        {
            "id": 1,
            "imagenes": '["a.png"]',
            "criterios_prioridad": '["Basura"]',
            "historial": '[{"id": 1, "accion": "Reporte creado"}]',
            "anonimo": True,
            "latitud": Decimal("-12.070400"),
            "longitud": Decimal("-75.212900"),
        }
    )

    assert reporte["imagenes"] == ["a.png"]
    assert reporte["criterios_prioridad"] == ["Basura"]
    assert reporte["historial"] == [{"id": 1, "accion": "Reporte creado"}]
    assert reporte["ciudadano_nombre"] == "Anónimo"
    assert reporte["latitud"] == -12.0704
    assert reporte["longitud"] == -75.2129


def test_normalizar_reporte_json_invalido():
    reporte = normalizar_reporte(
        {
            "id": 1,
            "imagenes": "no-json",
            "criterios_prioridad": None,
            "historial": None,
        }
    )

    assert reporte["imagenes"] == []
    assert reporte["criterios_prioridad"] == []
    assert reporte["historial"] == []


def test_normalizar_evidencia():
    evidencia = normalizar_evidencia(
        {
            "id": 1,
            "imagenes": '["evidencia.png"]',
            "observacion_completado": None,
        }
    )

    assert evidencia["imagenes"] == ["evidencia.png"]
    assert evidencia["observacion_completado"] == ""


def test_normalizar_auditoria():
    auditoria = normalizar_auditoria(
        {
            "id": 1,
            "imagenes": '["reporte.png"]',
        }
    )

    assert auditoria["imagenes"] == ["reporte.png"]
