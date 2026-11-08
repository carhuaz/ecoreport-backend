import json


def _cargar_json(valor, default):
    if isinstance(valor, str):
        try:
            return json.loads(valor)
        except (json.JSONDecodeError, TypeError):
            return default
    if valor is None:
        return default
    return valor


def paginar_resultados(result_sets, page, page_size):
    total = result_sets[0][0]["total"] if result_sets and result_sets[0] else 0
    items = result_sets[1] if len(result_sets) > 1 else []
    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": max(1, (total + page_size - 1) // page_size),
    }


def normalizar_reporte(row):
    row = dict(row)
    row["imagenes"] = _cargar_json(row.get("imagenes"), [])
    row["criterios_prioridad"] = _cargar_json(row.get("criterios_prioridad"), [])
    row["historial"] = _cargar_json(row.get("historial"), [])
    if row.get("anonimo"):
        row["ciudadano_nombre"] = "Anónimo"
    if row.get("latitud") is not None:
        row["latitud"] = float(row["latitud"])
    if row.get("longitud") is not None:
        row["longitud"] = float(row["longitud"])
    return row


def normalizar_evidencia(row):
    row = dict(row)
    row["imagenes"] = _cargar_json(row.get("imagenes"), [])
    if row.get("observacion_completado") is None:
        row["observacion_completado"] = ""
    return row


def normalizar_auditoria(row):
    row = dict(row)
    row["imagenes"] = _cargar_json(row.get("imagenes"), [])
    return row


def normalizar_mapa(row):
    row = dict(row)
    if row.get("latitud") is not None:
        row["latitud"] = float(row["latitud"])
    if row.get("longitud") is not None:
        row["longitud"] = float(row["longitud"])
    return row
