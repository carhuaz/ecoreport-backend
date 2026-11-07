from .database import fetch_all, fetch_one


MAX_ASIGNACIONES_POR_CUADRILLA = 3


def calcular_estado_cuadrilla(activos: int) -> str:
    if activos == 0:
        return "Disponible"
    if activos >= MAX_ASIGNACIONES_POR_CUADRILLA:
        return "Ocupada"
    return "En ruta"


def paginar(sql_count: str, sql_data: str, params: list, page: int, page_size: int) -> dict:
    total = fetch_one(sql_count, tuple(params))["total"]
    offset = (page - 1) * page_size
    sql_paginado = f"{sql_data} OFFSET {offset} ROWS FETCH NEXT {page_size} ROWS ONLY"
    rows = fetch_all(sql_paginado, tuple(params))
    return {
        "items": rows,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": max(1, (total + page_size - 1) // page_size)
    }
