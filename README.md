# EcoReport Huancayo — Backend API

API REST para la plataforma web de gestión y reporte ambiental **EcoReport Huancayo** (impacto social ciudadano).

- **URL en Producción (Render):** https://ecoreport-backend-e0nk.onrender.com
- **Documentación Interactiva (Swagger):** https://ecoreport-backend-e0nk.onrender.com/docs

---

## Arquitectura y Stack

- **Framework:** FastAPI (Python 3.12 + Uvicorn) con arquitectura en 4 capas:
  `main.py` → `app/api/*` → `app/services/*` → `app/repositories/*` → `app/database.py`
- **Base de Datos:** Microsoft Azure SQL Database (`EcoReportDB`) normalizada en **3ra Forma Normal (3FN)**, con **34 Stored Procedures (`usp_*`)**, función escalar `fn_usuario_tiene_rol`, 3 vistas (`vw_reportes`, `vw_cuadrillas`, `vw_historial`) y usuario contenido `ecoreport_app` (`GRANT EXECUTE`, `DENY` DML).
- **Scripts SQL oficiales:**
  - `sql/EcoReportDB_Azure.sql` (Azure SQL Database)
  - `sql/EcoReportDB_Local.sql` (SQL Server / SSMS local)
- **Integraciones Externas (HTTPS):**
  - **Brevo API:** Envío de códigos OTP de verificación y correos de contacto.
  - **APISPERU:** Validación de DNI en RENIEC con caché de 24h y límite de consultas por IP.
  - **Mapbox:** Entrega dinámica de configuración al frontend (`/api/config`).

---

## Pruebas y CI/CD

- **Linter:** `uv run ruff check app tests main.py`
- **Pruebas automatizadas:** `uv run pytest -q`
- **GitHub Actions:** `.github/workflows/ci-cd.yml` ejecuta Ruff + Pytest en cada push/Pull Request y dispara el Deploy Hook de Render al fusionarse en `main`.
