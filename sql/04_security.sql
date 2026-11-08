-- ============================================================
-- 04_security.sql
-- Login de aplicación con permisos mínimos:
--   * Puede ejecutar los stored procedures del esquema dbo.
--   * No puede hacer SELECT/INSERT/UPDATE/DELETE directo.
--
-- La contraseña es SOLO para desarrollo local.
-- Cámbiala en producción y actualiza backend/.env.
-- ============================================================

USE EcoReportDB;
GO

-- Quitar usuario y rol si ya existen (permite re-ejecutar)
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ecoreport_app' AND type = 'S')
    DROP USER ecoreport_app;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ecoreport_app_role' AND type = 'R')
    DROP ROLE ecoreport_app_role;
GO

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'ecoreport_app')
    DROP LOGIN ecoreport_app;
GO

CREATE LOGIN ecoreport_app
    WITH PASSWORD = N'EcoReport_App_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF,
         DEFAULT_DATABASE = EcoReportDB;
GO

USE EcoReportDB;
GO

CREATE USER ecoreport_app FOR LOGIN ecoreport_app;
GO

CREATE ROLE ecoreport_app_role;
GO

ALTER ROLE ecoreport_app_role ADD MEMBER ecoreport_app;
GO

-- Solo ejecución de SPs/funciones del esquema dbo
GRANT EXECUTE ON SCHEMA::dbo TO ecoreport_app_role;
GO

-- Sin acceso directo a tablas/vistas
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ecoreport_app_role;
GO

-- Verificación: el login debe existir y el usuario debe estar en el rol
SELECT
    sp.name AS login_name,
    dp.name AS user_name,
    r.name  AS role_name
FROM sys.server_principals sp
JOIN sys.database_principals dp ON dp.name = sp.name
JOIN sys.database_role_members rm ON rm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
WHERE sp.name = N'ecoreport_app';
GO
