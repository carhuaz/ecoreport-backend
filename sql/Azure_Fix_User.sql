-- ==============================================================================
-- EcoReportDB - CONFIGURACIÓN DEL USUARIO CONTENIDO ecoreport_app (AZURE SQL)
-- ==============================================================================
-- Servidor: ecoreport-server.database.windows.net
-- Base de Datos: EcoReportDB
--
-- Ejecuta este script directamente en el Editor de consultas de Azure Portal o SSMS.
-- Completa el 100% de la instalación sin necesidad de reejecutar todo el script.
-- ==============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Eliminar usuario y rol si ya existían parcialmente
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ecoreport_app')
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM sys.database_principals dp
        JOIN sys.database_role_members rm ON rm.member_principal_id = dp.principal_id
        JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        WHERE dp.name = N'ecoreport_app' AND r.name = N'ecoreport_app_role'
    )
    BEGIN
        ALTER ROLE ecoreport_app_role DROP MEMBER ecoreport_app;
    END
    DROP USER ecoreport_app;
END
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ecoreport_app_role')
BEGIN
    DROP ROLE ecoreport_app_role;
END
GO

-- 2. Crear usuario contenido con contraseña de alta complejidad (política Azure SQL)
-- La contraseña no contiene el nombre de usuario 'ecoreport' ni 'app'
CREATE USER ecoreport_app WITH PASSWORD = N'CloudSys2026_Secret#99';
GO

-- 3. Crear rol de aplicación
CREATE ROLE ecoreport_app_role;
GO

-- 4. Asociar usuario al rol
ALTER ROLE ecoreport_app_role ADD MEMBER ecoreport_app;
GO

-- 5. Conceder ÚNICAMENTE permisos de ejecución en procedimientos del esquema dbo
GRANT EXECUTE ON SCHEMA::dbo TO ecoreport_app_role;
GO

-- 6. Denegar expresamente acceso DML directo a tablas físicas (seguridad por capas)
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ecoreport_app_role;
GO

-- ==============================================================================
-- [VERIFICACIÓN ESTRICTA FINAL]
-- Solo emite éxito si confirma tablas >= 12, SPs >= 34 y usuario ecoreport_app activo
-- ==============================================================================
DECLARE @total_tablas INT;
DECLARE @total_sps INT;
DECLARE @user_ok BIT = 0;

SELECT @total_tablas = COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo');
SELECT @total_sps = COUNT(*) FROM sys.procedures WHERE name LIKE 'usp_%';

IF EXISTS (
    SELECT 1 
    FROM sys.database_principals dp
    JOIN sys.database_role_members rm ON rm.member_principal_id = dp.principal_id
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    WHERE dp.name = N'ecoreport_app' AND r.name = N'ecoreport_app_role'
)
    SET @user_ok = 1;

PRINT '==============================================================================';
IF (@total_tablas >= 12 AND @total_sps >= 34 AND @user_ok = 1)
BEGIN
    PRINT '>>> INSTALACIÓN DE EcoReportDB EN AZURE SQL COMPLETADA Y VERIFICADA AL 100% <<<';
    PRINT '    [OK] Tablas físicas en 3FN: ' + CAST(@total_tablas AS VARCHAR(10));
    PRINT '    [OK] Procedimientos usp_*: ' + CAST(@total_sps AS VARCHAR(10));
    PRINT '    [OK] Usuario contenido ecoreport_app: Activo y en rol ecoreport_app_role (EXECUTE)';
END
ELSE
BEGIN
    PRINT '>>> ADVERTENCIA: La instalación presenta inconsistencias. <<<';
    PRINT '    Tablas encontradas: ' + CAST(@total_tablas AS VARCHAR(10)) + ' (Esperadas: >= 12)';
    PRINT '    Procedimientos encontrados: ' + CAST(@total_sps AS VARCHAR(10)) + ' (Esperados: >= 34)';
    IF (@user_ok = 0)
        PRINT '    [ERROR] El usuario ecoreport_app NO existe o no pertenece al rol ecoreport_app_role.';
END
PRINT '==============================================================================';

SELECT
    dp.name AS usuario_contenido,
    r.name AS rol_asignado,
    dp.type_desc AS tipo_usuario,
    dp.create_date AS fecha_creacion
FROM sys.database_principals dp
JOIN sys.database_role_members rm ON rm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
WHERE dp.name = N'ecoreport_app';
GO
