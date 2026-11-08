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

# Recrear la BD desde cero (requiere un login sysadmin, p. ej. sa)
sqlcmd -S "localhost\SQLEXPRESS" -U sa -P "<password>" -C -b -i "sql\BDConDatosDePrueba.sql"
```

Frontend: vive en un repositorio aparte (`ecoreport-frontend`). No forma parte de este repo.

Base de datos: ejecutar `sql/BDConDatosDePrueba.sql` en SQL Server Management Studio (SSMS) o con `sqlcmd`. Borra y recrea `EcoReportDB` con esquema normalizado, stored procedures, seed y seguridad. Los scripts parciales son `00_drop.sql`, `01_schema.sql`, `02_procedures.sql`, `03_seed.sql` y `04_security.sql`; el maestro se genera concatenándolos. Si usas `sqlcmd` para consultar las vistas, agrega `-I` (ver trampas).

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

- Motor: **Microsoft SQL Server 2016+**, base `EcoReportDB`.
- **Prohibido usar ORM** (SQLAlchemy, Django ORM, etc.). Esquema normalizado a **3FN**.
- Scripts en `sql/`:
  - `00_drop.sql`: elimina la BD.
  - `01_schema.sql`: catálogos, tablas, índices, `fn_usuario_tiene_rol` y vistas `vw_reportes`, `vw_cuadrillas`, `vw_historial`.
  - `02_procedures.sql`: todos los `usp_*` (auth, usuarios, cuadrillas, reportes, estadísticas, contacto, mapa).
  - `03_seed.sql`: catálogos + 8 usuarios + 4 cuadrillas + 40 reportes + asignaciones + historial + imágenes/criterios.
  - `04_security.sql`: login `ecoreport_app` con solo `EXECUTE` en `dbo` y `DENY` de DML directo.
  - `BDConDatosDePrueba.sql`: maestro autosuficiente (concatenación de 00–04).
- Catálogos: `roles`, `estados_reporte`, `distritos`, `prioridades`, `acciones_historial`, `configuracion`.
- Tablas: `usuarios`, `cuadrillas`, `reportes`, `reporte_imagenes`, `reporte_criterios`, `asignaciones_reporte`, `historial_reportes`, `contactos`.
- **Asignación activa = `fecha_fin IS NULL`**. El índice único filtrado `UX_asignaciones_activa` garantiza una sola activa por reporte.
- La prioridad se deriva de `puntaje_prioridad` con la tabla `prioridades` (Baja 0–4, Media 5–7, Alta 8–11, Crítica 12–100). **No existe columna `prioridad` en `reportes`.**
- `MAX_ASIGNACIONES_POR_CUADRILLA` se lee de `configuracion` (valor `3`).
- Las vistas usan `STRING_ESCAPE` + `FOR XML PATH` para devolver `imagenes` y `criterios_prioridad` como JSON. Requieren `QUOTED_IDENTIFIER ON` en la sesión (ODBC lo activa; `sqlcmd` necesita `-I`).
- Driver según plataforma (`app/database.py`):
  - Windows: `pyodbc` (ODBC Driver 17 for SQL Server).
  - Linux/macOS: `pymssql`.
- Paginación: `utils.paginar()` añade `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY`. **Requiere `ORDER BY`** en el `data_sql`.
- La app abre/cierra conexión por request con `get_db()` (context manager, commit/rollback automático).
- **El backend actual todavía hace SQL directo en los routers.** Con `ecoreport_app` fallará por el `DENY`; usa `sa` mientras no se refactorice a SPs.

## Configuración y secretos

- `app/config.py` carga `.env` (raíz del repo) con `python-dotenv`.
- Variables: `DB_SERVER`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_DRIVER`, `SECRET_KEY`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `CORS_ORIGINS`.
- `DB_USER` y `DB_PASSWORD` ya **no tienen valores por defecto** en `config.py`; si faltan en `.env`, la conexión falla (evita credenciales hardcodeadas).
- `.env` **no debe versionarse** (ya está en `.gitignore` y destrackeado). Usar `.env.example` como plantilla (solo nombres/valores de ejemplo).
- Dependencias: `pyproject.toml` + `uv.lock`. `requirements.txt` fue eliminado; no recrearlo salvo que se pida.

## Dominio

**Roles** (catálogo `roles`): `Ciudadano`, `Validador`, `Administrador`, `ResponsableCuadrilla`.

**Estados de reporte** (catálogo `estados_reporte`): `Pendiente` (default BD) → `Aprobado` (Validador) / `Rechazado` (Validador) → `Programado` (Admin asigna cuadrilla) → `En atención` → `Atendido` (con evidencias). `Verificado` se consulta pero **ningún SP lo asigna** (solo existe en el seed).

**Estados de cuadrilla:** `Disponible`, `En ruta`, `Ocupada`. Se derivan en `vw_cuadrillas` contando asignaciones activas (`fecha_fin IS NULL`); no se almacenan. `utils.calcular_estado_cuadrilla()` sigue existiendo para el código legado, pero la fuente de verdad es la vista.

**Reglas:**
- Máximo `MAX_ASIGNACIONES_POR_CUADRILLA` (en `configuracion`, valor `3`) reportes activos por cuadrilla.
- Registro: DNI de 8 dígitos, email único, verificación por OTP hasheado en BD.
- Login bloqueado si `activo = 0` o `esta_verificado = 0`.
- Historial de auditoría en `historial_reportes` con `usuario_id` + `usuario_snapshot`; los reportes anónimos guardan `usuario_snapshot = 'Anónimo'`.
- Un `ResponsableCuadrilla` solo accede a reportes de sus cuadrillas (`responsable_id`).
- `usp_cuadrilla_asignar` acepta reportes `Aprobado` o `Programado`; al reasignar cierra la asignación activa anterior (`fecha_fin`) e inserta la nueva.
- El seed deja: Cuadrilla A `En ruta`, B `Disponible`, C `En ruta`, D `Ocupada` (estados derivados, no columnas).

## Trampas del repo

- **`app/routes/mapa.py` no está registrado en `app/main.py`**: `/api/mapa/*` no está activo. Registrarlo si se necesita.
- Lógica y SQL mezclados en los routers: no asumir capas `services`/`repositories`.
- **El backend actual hace SQL directo y no llama a los `usp_*`.** Si `.env` usa `ecoreport_app`, las consultas fallarán por `DENY`; usa `sa` hasta completar el refactor a SPs.
- Las vistas con `FOR XML PATH ... .value(...)` requieren `QUOTED_IDENTIFIER ON` en la sesión. `sqlcmd` lo desactiva por defecto: usa `-I`. SSMS y el driver ODBC lo activan.
- `STRING_ESCAPE(url, 'json')` escapa `/` como `\/`; es JSON válido y `JSON.parse` lo resuelve.
- `04_security.sql` crea `ecoreport_app` con contraseña de desarrollo `EcoReport_App_2026!`. **Cámbiala en producción** y actualiza `.env`.
- `passlib==1.7.4` es incompatible con bcrypt moderno; está fijado `bcrypt<4.1` en `pyproject.toml`. No subir bcrypt sin probar auth.
- `pymssql` no está instalado en Windows por el marcador de plataforma; no importarlo directamente, usar `app.database`.
- No debe existir `package-lock.json` en este repo: es un archivo del frontend, no del backend.
- Los scripts SQL del README antiguo (`001_schema.sql`, `todo_en_uno.sql`) no existen; los reales son los de `sql/` (maestro: `BDConDatosDePrueba.sql`).
- No hay tests ni linter configurados todavía.

## Validación antes de terminar

1. `uv sync`
2. `uv run python -c "import fastapi, pyodbc, passlib, jose"`
3. `uv run uvicorn app.main:app --reload --port 8000` y probar `/api/health`.
4. Si se tocó SQL, recrear y validar:
   ```powershell
   sqlcmd -S "localhost\SQLEXPRESS" -U sa -P "<password>" -C -b -i "sql\BDConDatosDePrueba.sql"
   sqlcmd -S "localhost\SQLEXPRESS" -U sa -P "<password>" -C -I -d EcoReportDB -Q "SELECT * FROM dbo.vw_cuadrillas"
   sqlcmd -S "localhost\SQLEXPRESS" -U ecoreport_app -P "EcoReport_App_2026!" -C -d EcoReportDB -Q "SELECT * FROM dbo.reportes"   # debe fallar 229
   sqlcmd -S "localhost\SQLEXPRESS" -U ecoreport_app -P "EcoReport_App_2026!" -C -I -d EcoReportDB -Q "EXEC dbo.usp_reportes_publicos"
   ```
5. Si se refactoriza el backend, mover el SQL a `repositories` y llamar solo a `usp_*`; no romper los contratos HTTP actuales.
