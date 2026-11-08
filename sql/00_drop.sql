-- ============================================================
-- 00_drop.sql
-- Elimina la base de datos EcoReportDB si existe.
-- Ejecutar con un login con permisos (sa o sysadmin).
-- ============================================================

USE master;
GO

IF DB_ID(N'EcoReportDB') IS NOT NULL
BEGIN
    ALTER DATABASE EcoReportDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EcoReportDB;
END
GO
