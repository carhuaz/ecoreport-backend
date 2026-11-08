-- ============================================================
-- 05_otp_hardening.sql
-- Migración para bases existentes: columnas de control del OTP.
-- Ejecutar con un login sysadmin (sa) y luego re-ejecutar
-- 02_procedures.sql para actualizar los stored procedures.
-- ============================================================

USE EcoReportDB;
GO

IF COL_LENGTH('dbo.usuarios', 'codigo_expira') IS NULL
    ALTER TABLE dbo.usuarios ADD codigo_expira DATETIME2 NULL;
GO

IF COL_LENGTH('dbo.usuarios', 'intentos_verificacion') IS NULL
    ALTER TABLE dbo.usuarios
        ADD intentos_verificacion TINYINT NOT NULL
            CONSTRAINT DF_usuarios_intentos DEFAULT 0;
GO

IF COL_LENGTH('dbo.usuarios', 'ultimo_envio_codigo') IS NULL
    ALTER TABLE dbo.usuarios ADD ultimo_envio_codigo DATETIME2 NULL;
GO
