# AGENTS.md — EcoReport Backend

Guía para futuras sesiones de OpenCode. Léela antes de modificar el backend.

## Descripción

API REST para el sistema de reportes ambientales **EcoReport**. Backend en **Python 3.12 + FastAPI**, base de datos **SQL Server**, autenticación JWT y envío de correos por SMTP. Este repositorio contiene **solo el backend**; el frontend Angular vive en el repo `ecoreport-frontend` (https://github.com/carhuaz/ecoreportt-frontend).

## Comandos reales

Ejecutar desde la raíz del repo:

```powershell
# Instalar/actualizar dependencias según uv.lock (crea .venv)
uv sync

# Actualizar el lockfile tras editar pyproject.toml
uv lock

# Servidor de desarrollo
uv run uvicorn app.main:app --reload --port 8000

# Verificar imports
uv run python -c "import fastapi, pyodbc, passlib, jose"

# Setup del backend (uv sync + .env)
.\setup.ps1
```

Frontend: vive en un repositorio aparte (`ecoreport-frontend`). No forma parte de este repo.

Base de datos: ejecutar `sql/BDConDatosDePrueba.sql` en SQL Server Management Studio (SSMS). Borra y recrea `EcoReportDB` con datos de prueba.

Healthcheck: `GET http://localhost:8000/api/health`. Swagger: `http://localhost:8000/docs`.

## Arquitectura actual (implementada)

```
app/main.py  ->  app/routes/*  ->  app/database.py  ->  SQL Server
                     |
                     +-> app/schemas/*      (Pydantic)
                     +-> app/middleware/*   (JWT / roles)
                     +-> app/utils.py       (paginación, reglas)
                     +-> app/email_service.py + app/templates/
```

- `app/main.py`: crea la app FastAPI, CORS y registra routers.
- `app/routes/`: controladores HTTP. **Contienen la lógica de negocio y el SQL directamente.**
- `app/schemas/`: modelos Pydantic de entrada/salida.
- `app/middleware/auth.py`: hash bcrypt, JWT (`python-jose`), dependencias de roles.
- `app/database.py`: conexión y helpers de SQL crudo (`fetch_all`, `fetch_one`, `execute`, `execute_returning_id`).
- `app/utils.py`: `paginar()` y reglas de estado de cuadrillas.
- `app/email_service.py`: SMTP + Jinja2 para OTP y contactos.

## Arquitectura objetivo (pendiente, NO implementada)

```
main.py -> api -> services -> repositories
                 \-> schemas
```

No existe aún la capa `services/` ni `repositories/`. Si se refactoriza, mover la lógica de negocio a `services` y el SQL a `repositories`, dejando los routers como capa `api` delgada. **No romper los contratos HTTP actuales.**

## Base de datos — SQL Server sin ORM

- Motor: **Microsoft SQL Server**, base `EcoReportDB`.
- **Prohibido usar ORM** (SQLAlchemy, Django ORM, etc.). Todo es SQL crudo parametrizado (`?`).
- Driver según plataforma (`app/database.py`):
  - Windows: `pyodbc` (ODBC Driver 17 for SQL Server).
  - Linux/macOS: `pymssql`.
- Tablas: `usuarios`, `cuadrillas`, `reportes`, `historial_reportes`, `contactos`.
- Paginación: `utils.paginar()` añade `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY`. **Requiere `ORDER BY`** en el `data_sql`.
- La app abre/cierra conexión por request con `get_db()` (context manager, commit/rollback automático).

## Configuración y secretos

- `app/config.py` carga `.env` (raíz del repo) con `python-dotenv`.
- Variables: `DB_SERVER`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_DRIVER`, `SECRET_KEY`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `CORS_ORIGINS`.
- `.env` **no debe versionarse** (ya está en `.gitignore` y destrackeado). Usar `.env.example` como plantilla (solo nombres/valores de ejemplo).
- Dependencias: `pyproject.toml` + `uv.lock`. `requirements.txt` fue eliminado; no recrearlo salvo que se pida.

## Dominio

**Roles** (`CHECK` en BD): `Ciudadano`, `Validador`, `Administrador`, `ResponsableCuadrilla`.

**Estados de reporte:** `Pendiente` (default BD) → `Aprobado` (Validador) / `Rechazado` (Validador) → `Programado` (Admin asigna cuadrilla) → `En atención` → `Atendido` (con evidencias). `Verificado` se consulta pero **ningún endpoint lo asigna**.

**Estados de cuadrilla:** `Disponible`, `En ruta`, `Ocupada`. Se recalculan con `calcular_estado_cuadrilla()` según asignaciones activas (`Programado` / `En atención`).

**Reglas:**
- Máximo `MAX_ASIGNACIONES_POR_CUADRILLA = 3` reportes activos por cuadrilla.
- Registro: DNI de 8 dígitos, email único, verificación por OTP hasheado en BD.
- Login bloqueado si `activo = 0` o `esta_verificado = 0`.
- Historial de auditoría en `historial_reportes` (`usuario` guarda nombre o id según el flujo).
- Un `ResponsableCuadrilla` solo accede a reportes de sus cuadrillas (`responsable_id`).

## Trampas del repo

- **`app/routes/mapa.py` no está registrado en `app/main.py`**: `/api/mapa/*` no está activo. Registrarlo si se necesita.
- Lógica y SQL mezclados en los routers: no asumir capas `services`/`repositories`.
- `passlib==1.7.4` es incompatible con bcrypt moderno; está fijado `bcrypt<4.1` en `pyproject.toml`. No subir bcrypt sin probar auth.
- `pymssql` no está instalado en Windows por el marcador de plataforma; no importarlo directamente, usar `app.database`.
- No debe existir `package-lock.json` en este repo: es un archivo del frontend, no del backend.
- Los scripts SQL del README antiguo (`001_schema.sql`, `todo_en_uno.sql`) no existen; el real es `sql/BDConDatosDePrueba.sql`.
- No hay tests ni linter configurados todavía.

## Validación antes de terminar

1. `uv sync`
2. `uv run python -c "import fastapi, pyodbc, passlib, jose"`
3. `uv run uvicorn app.main:app --reload --port 8000` y probar `/api/health`.
4. Si se tocó SQL: ejecutar el script contra una BD de prueba y validar los endpoints afectados.
