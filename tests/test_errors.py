from app.services.errors import traducir_error_bd


def test_mapea_error_50001():
    exc = Exception(
        "42000",
        "[42000] [Microsoft][ODBC Driver 17 for SQL Server]"
        "[SQL Server]Reporte no encontrado. (50001) (SQLExecDirectW)",
    )

    error = traducir_error_bd(exc)

    assert error.status_code == 404
    assert error.detail == "Reporte no encontrado."


def test_mapea_error_50004():
    exc = Exception(
        "42000",
        "[42000] [Microsoft][ODBC Driver 17 for SQL Server]"
        "[SQL Server]No tienes acceso a esta cuadrilla. (50004) (SQLExecDirectW)",
    )

    error = traducir_error_bd(exc)

    assert error.status_code == 403
    assert error.detail == "No tienes acceso a esta cuadrilla."


def test_mapea_error_50006_con_corchetes():
    exc = Exception("[50006] El DNI debe tener 8 dígitos numéricos.")

    error = traducir_error_bd(exc)

    assert error.status_code == 400
    assert error.detail == "El DNI debe tener 8 dígitos numéricos."


def test_mapea_conflicto_de_unicidad():
    exc = Exception(
        "23000",
        "[23000] [Microsoft][ODBC Driver 17 for SQL Server]"
        "[SQL Server]Cannot insert duplicate key row in object 'dbo.cuadrillas' "
        "with unique index 'UQ_cuadrillas_nombre_distrito'. (2601) (SQLExecDirectW)",
    )

    error = traducir_error_bd(exc)

    assert error.status_code == 409
    assert "conflicto" in error.detail


def test_error_desconocido():
    error = traducir_error_bd(Exception("fallo inesperado"))

    assert error.status_code == 500
    assert error.detail == "Error interno de base de datos"
