-- ============================================================
-- EcoReportDB - SCRIPT EJECUTABLE EN UNA SOLA VEZ
-- Borra la base de datos si existe, la vuelve a crear,
-- crea tablas y carga datos de prueba.
-- ============================================================

USE master;
GO

IF DB_ID(N'EcoReportDB') IS NOT NULL
BEGIN
    ALTER DATABASE EcoReportDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EcoReportDB;
END
GO

CREATE DATABASE EcoReportDB;
GO

USE EcoReportDB;
GO

-- ============================================================
-- EcoReport DB - Script TODO EN UNO (esquema + datos)
-- Ejecutar en: EcoReportDB (o la BD que uses)
-- ============================================================

-- ============================================================
-- 0. ELIMINAR TABLAS SI EXISTEN (orden inverso por FK)
-- ============================================================
DROP TABLE IF EXISTS historial_reportes;
DROP TABLE IF EXISTS reportes;
DROP TABLE IF EXISTS cuadrillas;
DROP TABLE IF EXISTS usuarios;

-- ============================================================
-- 1. TABLAS PRINCIPALES
-- ============================================================

CREATE TABLE usuarios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) NOT NULL UNIQUE,
    password NVARCHAR(255) NOT NULL,
    dni NVARCHAR(8) NOT NULL UNIQUE,
    rol NVARCHAR(25) NOT NULL CHECK (rol IN ('Ciudadano', 'Validador', 'Administrador', 'ResponsableCuadrilla')),
    activo BIT NOT NULL DEFAULT 1,
    codigo_verificacion NVARCHAR(60) NULL,
    esta_verificado BIT NOT NULL DEFAULT 0,
    fecha_registro DATE NOT NULL DEFAULT GETDATE()
);

CREATE TABLE cuadrillas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    responsable NVARCHAR(100) NOT NULL,
    responsable_id INT REFERENCES usuarios(id),
    estado NVARCHAR(20) NOT NULL DEFAULT 'Disponible' CHECK (estado IN ('Disponible', 'En ruta', 'Ocupada')),
    zona_asignada NVARCHAR(200),
    distrito NVARCHAR(50) NOT NULL
);

CREATE TABLE reportes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    titulo NVARCHAR(200) NOT NULL,
    descripcion NVARCHAR(MAX),
    distrito NVARCHAR(50) NOT NULL,
    direccion NVARCHAR(200),
    estado NVARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    prioridad NVARCHAR(20) NOT NULL DEFAULT 'Baja' CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Crítica')),
    puntaje_prioridad INT NOT NULL DEFAULT 0,
    criterios_prioridad NVARCHAR(MAX),
    prioridad_corregida BIT NOT NULL DEFAULT 0,
    observacion_prioridad NVARCHAR(MAX),
    fecha DATE NOT NULL DEFAULT GETDATE(),
    latitud FLOAT,
    longitud FLOAT,
    imagenes NVARCHAR(MAX),
    ciudadano_id INT REFERENCES usuarios(id),
    observacion_validacion NVARCHAR(MAX),
    cuadrilla_id INT REFERENCES cuadrillas(id),
    anonimo BIT NOT NULL DEFAULT 0
);

CREATE TABLE historial_reportes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    reporte_id INT NOT NULL REFERENCES reportes(id),
    fecha DATE NOT NULL DEFAULT GETDATE(),
    accion NVARCHAR(100) NOT NULL,
    usuario NVARCHAR(100) NOT NULL,
    observacion NVARCHAR(MAX)
);

CREATE TABLE contactos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    codigo NVARCHAR(20) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) NOT NULL,
    asunto NVARCHAR(100) NOT NULL,
    mensaje NVARCHAR(500) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT GETDATE(),
    leido BIT NOT NULL DEFAULT 0
);

-- ============================================================
-- 2. DATOS DE PRUEBA (SEED)
-- ============================================================

-- USUARIOS (contraseña de todos: 123456)
SET IDENTITY_INSERT usuarios ON;

INSERT INTO usuarios (id, nombre, email, password, dni, rol, activo, esta_verificado)
VALUES
(1, 'Juan Pérez',       'ciudadano@ecoreport.pe',  '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000001', 'Ciudadano',     1, 1),
(2, 'Ciudadano 2',      'ciudadano2@ecoreport.pe', '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000002', 'Ciudadano',     1, 1),
(3, 'María Gómez',      'ciudadano3@ecoreport.pe', '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000003', 'Ciudadano',     1, 1),
(4, 'Validador 1',      'validador1@ecoreport.pe', '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000004', 'Validador',     1, 1),
(5, 'Validador 2',      'validador2@ecoreport.pe', '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000005', 'Validador',     1, 1),
(6, 'Admin Municipal',  'admin@ecoreport.pe',      '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000006', 'Administrador', 1, 1),
(7, 'Carlos López',     'carlos@ecoreport.pe',    '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000007', 'ResponsableCuadrilla', 1, 1),
(8, 'Rosa Huamán',      'rosa@ecoreport.pe',      '$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy', '00000008', 'ResponsableCuadrilla', 1, 1);

SET IDENTITY_INSERT usuarios OFF;

-- CUADRILLAS
SET IDENTITY_INSERT cuadrillas ON;

INSERT INTO cuadrillas (id, nombre, responsable, responsable_id, estado, zona_asignada, distrito)
VALUES
(1, 'Cuadrilla A', 'Carlos López',   7, 'Disponible', 'Norte - Av. Principal',       'Huancayo'),
(2, 'Cuadrilla B', 'Rosa Huamán',    8, 'En ruta',    'Sur - Jr. Cusco',             'Huancayo'),
(3, 'Cuadrilla C', 'Carlos López',  7, 'Disponible', 'Centro - Mercado Modelo',     'El Tambo'),
(4, 'Cuadrilla D', 'Rosa Huamán',   8, 'Disponible', 'Este - Parque Infantil',      'Chilca');

SET IDENTITY_INSERT cuadrillas OFF;

-- REPORTES (40 registros)
SET IDENTITY_INSERT reportes ON;

INSERT INTO reportes (id, titulo, descripcion, distrito, direccion, estado, prioridad, puntaje_prioridad, fecha, latitud, longitud, ciudadano_id, cuadrilla_id)
VALUES
(1,  'Acumulación de basura en Av. Francisca de la Calle', 'Gran cantidad de residuos acumulados en la avenida principal.', 'Huancayo', 'Av. Francisca de la Calle cdra. 4', 'Pendiente', 'Alta', 9,  '2026-05-01', -12.0704, -75.2129, 1, NULL),
(2,  'Desmonte en riberas del río Shullcas', 'Escombros y desmonte en la ribera del río.', 'Huancayo', 'Ribera del río Shullcas, frente al puente', 'Programado', 'Crítica', 13, '2026-05-02', -12.0671, -75.2154, 2, 1),
(3,  'Basura frente a restaurante Sabores Huancas', 'Bolsas de basura acumuladas frente al restaurante.', 'El Tambo', 'Jr. Puno cdra. 2', 'Atendido', 'Media', 6, '2026-05-03', -12.0687, -75.2104, 1, 3),
(4,  'Residuos cerca de la Universidad Continental', 'Residuos orgánicos en la entrada de la universidad.', 'Huancayo', 'Av. San Carlos cdra. 1', 'Aprobado', 'Alta', 9, '2026-05-04', -12.0596, -75.2269, 3, NULL),
(5,  'Botadero informal en mercado central', 'Botadero informal con malos olores en el mercado.', 'Huancayo', 'Mercado Central, Jr. Cusco', 'Aprobado', 'Crítica', 12, '2026-05-05', -12.0723, -75.2149, 2, NULL),
(6,  'Bolsas acumuladas en Jr. Puno con Jr. Lima', 'Varias bolsas de basura acumuladas en la esquina.', 'El Tambo', 'Jr. Puno cdra. 5', 'Pendiente', 'Baja', 2, '2026-05-06', -12.0714, -75.2120, 1, NULL),
(7,  'Desmonte cerca de parque Constitución', 'Desmonte y maleza acumulada en el parque.', 'Huancayo', 'Parque Constitución', 'Programado', 'Media', 5, '2026-05-07', -12.0671, -75.2154, 3, 1),
(8,  'Residuos orgánicos en zona comercial de Chilca', 'Residuos orgánicos en la zona comercial de Chilca.', 'Chilca', 'Av. Centenario cdra. 10', 'Atendido', 'Media', 5, '2026-05-08', -12.0542, -75.1945, 1, 4),
(9,  'Botadero en El Tambo', 'Botadero informal cerca del parque principal.', 'El Tambo', 'Parque Principal El Tambo', 'Verificado', 'Crítica', 14, '2026-05-09', -12.0580, -75.2280, 2, 2),
(10, 'Maleza y basura en Chilca centro', 'Maleza crecida y basura en la plaza de Chilca.', 'Chilca', 'Plaza de Chilca', 'Aprobado', 'Baja', 2, '2026-05-10', -12.0510, -75.1980, 3, NULL),

(11, 'Basura esparcida en el parque Huaytapallana - Reporte #11',  'Descripción del reporte #11.',  'Chilca',   'Pasaje Las Flores 11',   'Pendiente',  'Media', 7,  '2026-05-11', -12.0424, -75.1961, 1, NULL),
(12, 'Desmonte en la Av. Ferrocarril - Reporte #12',               'Descripción del reporte #12.',  'Huancayo', 'Jr. Los Olivos 12',      'Pendiente',  'Baja',   2, '2026-05-12', -12.0629, -75.2070, 2, NULL),
(13, 'Residuos orgánicos en Jr. Cusco - Reporte #13',              'Descripción del reporte #13.',  'El Tambo', 'Calle Real 13',          'Aprobado',   'Alta',  10, '2026-05-13', -12.0503, -75.2269, 3, NULL),
(14, 'Plásticos y envases en la ribera del río Mantaro - #14',     'Descripción del reporte #14.',  'Chilca',   'Av. Independencia 14',   'Pendiente',  'Media',  5, '2026-05-14', -12.0465, -75.1903, 1, NULL),
(15, 'Esmozón de maleza y basura en la Av. Centenario - #15',      'Descripción del reporte #15.',  'Huancayo', 'Av. Principal 15',       'Aprobado',   'Alta',   9, '2026-05-15', -12.0571, -75.2161, 2, NULL),
(16, 'Acumulación de ramas y residuos verdes en parque - #16',     'Descripción del reporte #16.',  'El Tambo', 'Av. Principal 16',       'Programado', 'Media',  6, '2026-05-16', -12.0478, -75.2272, 3, NULL),
(17, 'Colchones y muebles viejos en la vía pública - #17',         'Descripción del reporte #17.',  'Chilca',   'Jr. Los Olivos 17',      'Pendiente',  'Baja',   1, '2026-05-17', -12.0391, -75.1995, 1, NULL),
(18, 'Acumulación de residuos en Av. Mariscal Castilla - #18',     'Descripción del reporte #18.',  'Huancayo', 'Pasaje Las Flores 18',   'Aprobado',   'Media',  8, '2026-05-18', -12.0544, -75.2103, 2, NULL),
(19, 'Botadero informal cerca del mercado Modelo - #19',           'Descripción del reporte #19.',  'El Tambo', 'Calle Real 19',          'Rechazado',  'Crítica',12, '2026-05-19', -12.0512, -75.2256, 3, NULL),
(20, 'Basura esparcida en el parque Huaytapallana - #20',          'Descripción del reporte #20.',  'Chilca',   'Av. Independencia 20',   'Pendiente',  'Media',  4, '2026-05-20', -12.0402, -75.1990, 1, NULL),
(21, 'Desmonte en la Av. Ferrocarril - Reporte #21',               'Descripción del reporte #21.',  'Huancayo', 'Av. Principal 21',       'Pendiente',  'Baja',   3, '2026-05-21', -12.0648, -75.2182, 2, NULL),
(22, 'Residuos orgánicos en Jr. Cusco - Reporte #22',              'Descripción del reporte #22.',  'El Tambo', 'Jr. Los Olivos 22',      'Aprobado',   'Alta',  11, '2026-05-22', -12.0524, -75.2289, 3, NULL),
(23, 'Plásticos y envases en la ribera del río Mantaro - #23',     'Descripción del reporte #23.',  'Chilca',   'Pasaje Las Flores 23',   'Pendiente',  'Media',  7, '2026-05-23', -12.0435, -75.1939, 1, NULL),
(24, 'Esmozón de maleza y basura en la Av. Centenario - #24',      'Descripción del reporte #24.',  'Huancayo', 'Calle Real 24',          'Aprobado',   'Alta',   9, '2026-05-24', -12.0561, -75.2112, 2, NULL),
(25, 'Acumulación de ramas y residuos verdes en parque - #25',     'Descripción del reporte #25.',  'El Tambo', 'Av. Independencia 25',   'Programado', 'Media',  5, '2026-05-25', -12.0482, -75.2294, 3, NULL),
(26, 'Colchones y muebles viejos en la vía pública - #26',         'Descripción del reporte #26.',  'Chilca',   'Av. Principal 26',       'Pendiente',  'Baja',   2, '2026-05-26', -12.0382, -75.2014, 1, NULL),
(27, 'Acumulación de residuos en Av. Mariscal Castilla - #27',     'Descripción del reporte #27.',  'Huancayo', 'Jr. Los Olivos 27',      'Aprobado',   'Crítica',13, '2026-05-27', -12.0573, -75.2072, 2, NULL),
(28, 'Botadero informal cerca del mercado Modelo - #28',           'Descripción del reporte #28.',  'El Tambo', 'Calle Real 28',          'Rechazado',  'Alta',   9, '2026-05-28', -12.0511, -75.2260, 3, NULL),
(29, 'Basura esparcida en el parque Huaytapallana - #29',          'Descripción del reporte #29.',  'Chilca',   'Pasaje Las Flores 29',   'Pendiente',  'Media',  6, '2026-05-29', -12.0391, -75.1905, 1, NULL),
(30, 'Desmonte en la Av. Ferrocarril - Reporte #30',               'Descripción del reporte #30.',  'Huancayo', 'Av. Principal 30',       'Aprobado',   'Baja',   4, '2026-05-30', -12.0648, -75.2193, 2, NULL),
(31, 'Residuos orgánicos en Jr. Cusco - Reporte #31',              'Descripción del reporte #31.',  'El Tambo', 'Av. Independencia 31',   'Programado', 'Media',  7, '2026-05-31', -12.0489, -75.2236, 3, NULL),
(32, 'Plásticos y envases en la ribera del río Mantaro - #32',     'Descripción del reporte #32.',  'Chilca',   'Jr. Los Olivos 32',      'Pendiente',  'Baja',   1, '2026-06-01', -12.0409, -75.1910, 1, NULL),
(33, 'Esmozón de maleza y basura en la Av. Centenario - #33',      'Descripción del reporte #33.',  'Huancayo', 'Calle Real 33',          'Aprobado',   'Alta',  10, '2026-06-02', -12.0535, -75.2165, 2, NULL),
(34, 'Acumulación de ramas y residuos verdes en parque - #34',     'Descripción del reporte #34.',  'El Tambo', 'Pasaje Las Flores 34',   'Atendido',   'Crítica',12, '2026-06-03', -12.0504, -75.2305, 3, NULL),
(35, 'Colchones y muebles viejos en la vía pública - #35',         'Descripción del reporte #35.',  'Chilca',   'Av. Principal 35',       'Pendiente',  'Media',  5, '2026-06-04', -12.0390, -75.1950, 1, NULL),
(36, 'Acumulación de residuos en Av. Mariscal Castilla - #36',     'Descripción del reporte #36.',  'Huancayo', 'Jr. Los Olivos 36',      'Pendiente',  'Baja',   2, '2026-06-05', -12.0561, -75.2145, 2, NULL),
(37, 'Botadero informal cerca del mercado Modelo - #37',           'Descripción del reporte #37.',  'El Tambo', 'Calle Real 37',          'Rechazado',  'Alta',   9, '2026-06-06', -12.0482, -75.2245, 3, NULL),
(38, 'Basura esparcida en el parque Huaytapallana - #38',          'Descripción del reporte #38.',  'Chilca',   'Pasaje Las Flores 38',   'Pendiente',  'Media',  6, '2026-06-07', -12.0384, -75.1991, 1, NULL),
(39, 'Desmonte en la Av. Ferrocarril - Reporte #39',               'Descripción del reporte #39.',  'Huancayo', 'Av. Principal 39',       'Aprobado',   'Media',  8, '2026-06-08', -12.0576, -75.2102, 2, NULL),
(40, 'Residuos orgánicos en Jr. Cusco - Reporte #40',              'Descripción del reporte #40.',  'El Tambo', 'Jr. Los Olivos 40',      'Programado', 'Alta',  11, '2026-06-09', -12.0479, -75.2281, 3, NULL);

SET IDENTITY_INSERT reportes OFF;

-- HISTORIAL (1 entrada por reporte)
INSERT INTO historial_reportes (reporte_id, accion, usuario)
SELECT id, 'Reporte creado', 'Ciudadano' FROM reportes;


-- ============================================================
-- 3. VERIFICACIÓN RÁPIDA
-- ============================================================
SELECT 'usuarios' AS tabla, COUNT(*) AS total FROM usuarios
UNION ALL
SELECT 'cuadrillas', COUNT(*) FROM cuadrillas
UNION ALL
SELECT 'reportes', COUNT(*) FROM reportes
UNION ALL
SELECT 'historial_reportes', COUNT(*) FROM historial_reportes;
GO

SELECT * FROM usuarios