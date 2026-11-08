-- ============================================================
-- 03_seed.sql
-- Datos de prueba para EcoReportDB (normalizado a 3FN).
-- Contraseña de todos los usuarios: 123456
-- ============================================================

USE EcoReportDB;
GO

-- ============================================================
-- Catálogos
-- ============================================================

INSERT INTO dbo.roles (nombre) VALUES
    (N'Ciudadano'),
    (N'Validador'),
    (N'Administrador'),
    (N'ResponsableCuadrilla');
GO

INSERT INTO dbo.estados_reporte (nombre) VALUES
    (N'Pendiente'),
    (N'Aprobado'),
    (N'Rechazado'),
    (N'Programado'),
    (N'En atención'),
    (N'Atendido'),
    (N'Verificado');
GO

INSERT INTO dbo.distritos (nombre) VALUES
    (N'Huancayo'),
    (N'El Tambo'),
    (N'Chilca');
GO

INSERT INTO dbo.prioridades (nombre, puntaje_min, puntaje_max) VALUES
    (N'Baja',    0,   4),
    (N'Media',   5,   7),
    (N'Alta',    8,  11),
    (N'Crítica', 12, 100);
GO

INSERT INTO dbo.acciones_historial (nombre) VALUES
    (N'Reporte creado'),
    (N'Aprobado'),
    (N'Rechazado'),
    (N'Asignado a cuadrilla'),
    (N'En atención'),
    (N'Atendido con evidencias');
GO

INSERT INTO dbo.configuracion (clave, valor) VALUES
    (N'MAX_ASIGNACIONES_POR_CUADRILLA', N'3');
GO

-- ============================================================
-- Usuarios
-- ============================================================

SET IDENTITY_INSERT dbo.usuarios ON;

INSERT INTO dbo.usuarios
    (id, nombre, email, password, dni, rol_id, activo, esta_verificado)
SELECT
    v.id, v.nombre, v.email,
    N'$2b$12$D/dWiCqdcDrJ.rX6aeOSIOXW0ZFYYI3EZ2rsH8EDpO8Zs4OreXrpy',
    v.dni, r.id, 1, 1
FROM (VALUES
    (1, N'Juan Pérez',      N'ciudadano@ecoreport.pe',  N'00000001', N'Ciudadano'),
    (2, N'Ciudadano 2',     N'ciudadano2@ecoreport.pe', N'00000002', N'Ciudadano'),
    (3, N'María Gómez',     N'ciudadano3@ecoreport.pe', N'00000003', N'Ciudadano'),
    (4, N'Validador 1',     N'validador1@ecoreport.pe', N'00000004', N'Validador'),
    (5, N'Validador 2',     N'validador2@ecoreport.pe', N'00000005', N'Validador'),
    (6, N'Admin Municipal', N'admin@ecoreport.pe',      N'00000006', N'Administrador'),
    (7, N'Carlos López',    N'carlos@ecoreport.pe',     N'00000007', N'ResponsableCuadrilla'),
    (8, N'Rosa Huamán',     N'rosa@ecoreport.pe',       N'00000008', N'ResponsableCuadrilla')
) v(id, nombre, email, dni, rol)
JOIN dbo.roles r ON r.nombre = v.rol;

SET IDENTITY_INSERT dbo.usuarios OFF;
GO

-- ============================================================
-- Cuadrillas
-- ============================================================

SET IDENTITY_INSERT dbo.cuadrillas ON;

INSERT INTO dbo.cuadrillas (id, nombre, responsable_id, distrito_id, zona_asignada, activo)
SELECT v.id, v.nombre, v.responsable_id, d.id, v.zona, 1
FROM (VALUES
    (1, N'Cuadrilla A', 7, N'Huancayo', N'Norte - Av. Principal'),
    (2, N'Cuadrilla B', 8, N'Huancayo', N'Sur - Jr. Cusco'),
    (3, N'Cuadrilla C', 7, N'El Tambo', N'Centro - Mercado Modelo'),
    (4, N'Cuadrilla D', 8, N'Chilca',   N'Este - Parque Infantil')
) v(id, nombre, responsable_id, distrito, zona)
JOIN dbo.distritos d ON d.nombre = v.distrito;

SET IDENTITY_INSERT dbo.cuadrillas OFF;
GO

-- ============================================================
-- Reportes
-- ============================================================

SET IDENTITY_INSERT dbo.reportes ON;

INSERT INTO dbo.reportes
    (id, titulo, descripcion, distrito_id, direccion, estado_id,
     puntaje_prioridad, fecha, latitud, longitud, ciudadano_id, anonimo)
SELECT
    v.id, v.titulo, v.descripcion, d.id, v.direccion, e.id,
    v.puntaje, v.fecha, v.lat, v.lon, v.ciudadano_id,
    CASE WHEN v.id % 9 = 0 THEN 1 ELSE 0 END
FROM (VALUES
    (1,  N'Acumulación de basura en Av. Francisca de la Calle', N'Gran cantidad de residuos acumulados en la avenida principal.', N'Huancayo', N'Av. Francisca de la Calle cdra. 4', N'Pendiente',   9,  CAST('2026-05-01' AS DATETIME2), -12.0704, -75.2129, 1),
    (2,  N'Desmonte en riberas del río Shullcas', N'Escombros y desmonte en la ribera del río.', N'Huancayo', N'Ribera del río Shullcas, frente al puente', N'Programado',  13, CAST('2026-05-02' AS DATETIME2), -12.0671, -75.2154, 2),
    (3,  N'Basura frente a restaurante Sabores Huancas', N'Bolsas de basura acumuladas frente al restaurante.', N'El Tambo', N'Jr. Puno cdra. 2', N'Atendido',    6,  CAST('2026-05-03' AS DATETIME2), -12.0687, -75.2104, 1),
    (4,  N'Residuos cerca de la Universidad Continental', N'Residuos orgánicos en la entrada de la universidad.', N'Huancayo', N'Av. San Carlos cdra. 1', N'Aprobado',    9,  CAST('2026-05-04' AS DATETIME2), -12.0596, -75.2269, 3),
    (5,  N'Botadero informal en mercado central', N'Botadero informal con malos olores en el mercado.', N'Huancayo', N'Mercado Central, Jr. Cusco', N'Aprobado',    12, CAST('2026-05-05' AS DATETIME2), -12.0723, -75.2149, 2),
    (6,  N'Bolsas acumuladas en Jr. Puno con Jr. Lima', N'Varias bolsas de basura acumuladas en la esquina.', N'El Tambo', N'Jr. Puno cdra. 5', N'Pendiente',   2,  CAST('2026-05-06' AS DATETIME2), -12.0714, -75.2120, 1),
    (7,  N'Desmonte cerca de parque Constitución', N'Desmonte y maleza acumulada en el parque.', N'Huancayo', N'Parque Constitución', N'En atención', 5,  CAST('2026-05-07' AS DATETIME2), -12.0671, -75.2154, 3),
    (8,  N'Residuos orgánicos en zona comercial de Chilca', N'Residuos orgánicos en la zona comercial de Chilca.', N'Chilca', N'Av. Centenario cdra. 10', N'Atendido',    5,  CAST('2026-05-08' AS DATETIME2), -12.0542, -75.1945, 1),
    (9,  N'Botadero en El Tambo', N'Botadero informal cerca del parque principal.', N'El Tambo', N'Parque Principal El Tambo', N'Verificado',  14, CAST('2026-05-09' AS DATETIME2), -12.0580, -75.2280, 2),
    (10, N'Maleza y basura en Chilca centro', N'Maleza crecida y basura en la plaza de Chilca.', N'Chilca', N'Plaza de Chilca', N'Aprobado',    2,  CAST('2026-05-10' AS DATETIME2), -12.0510, -75.1980, 3),
    (11, N'Basura esparcida en el parque Huaytapallana - Reporte #11', N'Descripción del reporte #11.', N'Chilca', N'Pasaje Las Flores 11', N'Pendiente',  7,  CAST('2026-05-11' AS DATETIME2), -12.0424, -75.1961, 1),
    (12, N'Desmonte en la Av. Ferrocarril - Reporte #12', N'Descripción del reporte #12.', N'Huancayo', N'Jr. Los Olivos 12', N'Pendiente',   2,  CAST('2026-05-12' AS DATETIME2), -12.0629, -75.2070, 2),
    (13, N'Residuos orgánicos en Jr. Cusco - Reporte #13', N'Descripción del reporte #13.', N'El Tambo', N'Calle Real 13', N'Aprobado',    10, CAST('2026-05-13' AS DATETIME2), -12.0503, -75.2269, 3),
    (14, N'Plásticos y envases en la ribera del río Mantaro - #14', N'Descripción del reporte #14.', N'Chilca', N'Av. Independencia 14', N'Pendiente',  5,  CAST('2026-05-14' AS DATETIME2), -12.0465, -75.1903, 1),
    (15, N'Esmozón de maleza y basura en la Av. Centenario - #15', N'Descripción del reporte #15.', N'Huancayo', N'Av. Principal 15', N'Aprobado',    9,  CAST('2026-05-15' AS DATETIME2), -12.0571, -75.2161, 2),
    (16, N'Acumulación de ramas y residuos verdes en parque - #16', N'Descripción del reporte #16.', N'El Tambo', N'Av. Principal 16', N'Programado',  6,  CAST('2026-05-16' AS DATETIME2), -12.0478, -75.2272, 3),
    (17, N'Colchones y muebles viejos en la vía pública - #17', N'Descripción del reporte #17.', N'Chilca', N'Jr. Los Olivos 17', N'Pendiente',   1,  CAST('2026-05-17' AS DATETIME2), -12.0391, -75.1995, 1),
    (18, N'Acumulación de residuos en Av. Mariscal Castilla - #18', N'Descripción del reporte #18.', N'Huancayo', N'Pasaje Las Flores 18', N'Aprobado',    8,  CAST('2026-05-18' AS DATETIME2), -12.0544, -75.2103, 2),
    (19, N'Botadero informal cerca del mercado Modelo - #19', N'Descripción del reporte #19.', N'El Tambo', N'Calle Real 19', N'Rechazado',  12, CAST('2026-05-19' AS DATETIME2), -12.0512, -75.2256, 3),
    (20, N'Basura esparcida en el parque Huaytapallana - #20', N'Descripción del reporte #20.', N'Chilca', N'Av. Independencia 20', N'Pendiente',   4,  CAST('2026-05-20' AS DATETIME2), -12.0402, -75.1990, 1),
    (21, N'Desmonte en la Av. Ferrocarril - Reporte #21', N'Descripción del reporte #21.', N'Huancayo', N'Av. Principal 21', N'Pendiente',   3,  CAST('2026-05-21' AS DATETIME2), -12.0648, -75.2182, 2),
    (22, N'Residuos orgánicos en Jr. Cusco - Reporte #22', N'Descripción del reporte #22.', N'El Tambo', N'Jr. Los Olivos 22', N'Aprobado',    11, CAST('2026-05-22' AS DATETIME2), -12.0524, -75.2289, 3),
    (23, N'Plásticos y envases en la ribera del río Mantaro - #23', N'Descripción del reporte #23.', N'Chilca', N'Pasaje Las Flores 23', N'Pendiente',  7,  CAST('2026-05-23' AS DATETIME2), -12.0435, -75.1939, 1),
    (24, N'Esmozón de maleza y basura en la Av. Centenario - #24', N'Descripción del reporte #24.', N'Huancayo', N'Calle Real 24', N'Aprobado',    9,  CAST('2026-05-24' AS DATETIME2), -12.0561, -75.2112, 2),
    (25, N'Acumulación de ramas y residuos verdes en parque - #25', N'Descripción del reporte #25.', N'El Tambo', N'Av. Independencia 25', N'Programado',  5,  CAST('2026-05-25' AS DATETIME2), -12.0482, -75.2294, 3),
    (26, N'Colchones y muebles viejos en la vía pública - #26', N'Descripción del reporte #26.', N'Chilca', N'Av. Principal 26', N'Pendiente',   2,  CAST('2026-05-26' AS DATETIME2), -12.0382, -75.2014, 1),
    (27, N'Acumulación de residuos en Av. Mariscal Castilla - #27', N'Descripción del reporte #27.', N'Huancayo', N'Jr. Los Olivos 27', N'Aprobado',    13, CAST('2026-05-27' AS DATETIME2), -12.0573, -75.2072, 2),
    (28, N'Botadero informal cerca del mercado Modelo - #28', N'Descripción del reporte #28.', N'El Tambo', N'Calle Real 28', N'Rechazado',   9,  CAST('2026-05-28' AS DATETIME2), -12.0511, -75.2260, 3),
    (29, N'Basura esparcida en el parque Huaytapallana - #29', N'Descripción del reporte #29.', N'Chilca', N'Pasaje Las Flores 29', N'Pendiente',  6,  CAST('2026-05-29' AS DATETIME2), -12.0391, -75.1905, 1),
    (30, N'Desmonte en la Av. Ferrocarril - Reporte #30', N'Descripción del reporte #30.', N'Huancayo', N'Av. Principal 30', N'Aprobado',    4,  CAST('2026-05-30' AS DATETIME2), -12.0648, -75.2193, 2),
    (31, N'Residuos orgánicos en Jr. Cusco - Reporte #31', N'Descripción del reporte #31.', N'El Tambo', N'Av. Independencia 31', N'Programado',  7,  CAST('2026-05-31' AS DATETIME2), -12.0489, -75.2236, 3),
    (32, N'Plásticos y envases en la ribera del río Mantaro - #32', N'Descripción del reporte #32.', N'Chilca', N'Jr. Los Olivos 32', N'Pendiente',   1,  CAST('2026-06-01' AS DATETIME2), -12.0409, -75.1910, 1),
    (33, N'Esmozón de maleza y basura en la Av. Centenario - #33', N'Descripción del reporte #33.', N'Huancayo', N'Calle Real 33', N'Aprobado',    10, CAST('2026-06-02' AS DATETIME2), -12.0535, -75.2165, 2),
    (34, N'Acumulación de ramas y residuos verdes en parque - #34', N'Descripción del reporte #34.', N'El Tambo', N'Pasaje Las Flores 34', N'Atendido',   12, CAST('2026-06-03' AS DATETIME2), -12.0504, -75.2305, 3),
    (35, N'Colchones y muebles viejos en la vía pública - #35', N'Descripción del reporte #35.', N'Chilca', N'Av. Principal 35', N'Pendiente',   5,  CAST('2026-06-04' AS DATETIME2), -12.0390, -75.1950, 1),
    (36, N'Acumulación de residuos en Av. Mariscal Castilla - #36', N'Descripción del reporte #36.', N'Huancayo', N'Jr. Los Olivos 36', N'Pendiente',   2,  CAST('2026-06-05' AS DATETIME2), -12.0561, -75.2145, 2),
    (37, N'Botadero informal cerca del mercado Modelo - #37', N'Descripción del reporte #37.', N'El Tambo', N'Calle Real 37', N'Rechazado',   9,  CAST('2026-06-06' AS DATETIME2), -12.0482, -75.2245, 3),
    (38, N'Basura esparcida en el parque Huaytapallana - #38', N'Descripción del reporte #38.', N'Chilca', N'Pasaje Las Flores 38', N'Pendiente',  6,  CAST('2026-06-07' AS DATETIME2), -12.0384, -75.1991, 1),
    (39, N'Desmonte en la Av. Ferrocarril - Reporte #39', N'Descripción del reporte #39.', N'Huancayo', N'Av. Principal 39', N'Aprobado',    8,  CAST('2026-06-08' AS DATETIME2), -12.0576, -75.2102, 2),
    (40, N'Residuos orgánicos en Jr. Cusco - Reporte #40', N'Descripción del reporte #40.', N'El Tambo', N'Jr. Los Olivos 40', N'Programado',  11, CAST('2026-06-09' AS DATETIME2), -12.0479, -75.2281, 3)
) v(id, titulo, descripcion, distrito, direccion, estado, puntaje, fecha, lat, lon, ciudadano_id)
JOIN dbo.distritos d ON d.nombre = v.distrito
JOIN dbo.estados_reporte e ON e.nombre = v.estado;

SET IDENTITY_INSERT dbo.reportes OFF;
GO

-- ============================================================
-- Imágenes (una de reporte por cada reporte)
-- ============================================================

INSERT INTO dbo.reporte_imagenes (reporte_id, url, tipo, orden)
SELECT
    r.id,
    CASE r.id % 3
        WHEN 0 THEN N'/images/reporte-basura-calle.jpg'
        WHEN 1 THEN N'/images/reporte-rio-shullcas.jpg'
        ELSE N'/images/reporte-limpieza-atendida.jpg'
    END,
    N'Reporte',
    1
FROM dbo.reportes r;
GO

-- Evidencias de cierre (evita repetir la imagen principal del reporte)
INSERT INTO dbo.reporte_imagenes (reporte_id, url, tipo, orden)
SELECT
    r.id,
    CASE
        WHEN r.id % 3 = 2 THEN N'/images/reporte-basura-calle.jpg'
        ELSE N'/images/reporte-limpieza-atendida.jpg'
    END,
    N'Evidencia',
    1
FROM dbo.reportes r
JOIN dbo.estados_reporte e ON e.id = r.estado_id
WHERE e.nombre IN (N'Atendido', N'Verificado');
GO

-- ============================================================
-- Criterios de prioridad (1 a 4 según el puntaje)
-- ============================================================

INSERT INTO dbo.reporte_criterios (reporte_id, descripcion, orden)
SELECT r.id, c.descripcion, c.orden
FROM dbo.reportes r
CROSS APPLY (
    SELECT
        v.orden,
        CASE
            WHEN v.orden = 1 THEN
                CASE r.id % 4
                    WHEN 0 THEN N'Acumulación de residuos sólidos'
                    WHEN 1 THEN N'Desmonte y escombros'
                    WHEN 2 THEN N'Residuos orgánicos'
                    ELSE N'Plásticos y envases'
                END
            ELSE v.descripcion
        END AS descripcion
    FROM (VALUES
        (1, N'Acumulación de residuos sólidos'),
        (2, N'Malos olores'),
        (3, N'Riesgo para la salud'),
        (4, N'Cercanía a zonas sensibles')
    ) v(orden, descripcion)
    WHERE v.orden <= CASE
        WHEN r.puntaje_prioridad >= 12 THEN 4
        WHEN r.puntaje_prioridad >= 8  THEN 3
        WHEN r.puntaje_prioridad >= 5  THEN 2
        ELSE 1
    END
) c;
GO

-- ============================================================
-- Asignaciones
-- Activas (fecha_fin NULL): Programado / En atención.
-- Cerradas (fecha_fin): Atendido / Verificado.
-- ============================================================

DECLARE @asignaciones TABLE (
    reporte_id   INT NOT NULL,
    cuadrilla_id INT NOT NULL,
    cerrada      BIT NOT NULL
);

INSERT INTO @asignaciones (reporte_id, cuadrilla_id, cerrada) VALUES
    (2,  1, 0),
    (7,  3, 0),
    (3,  3, 1),
    (8,  4, 1),
    (9,  2, 1),
    (16, 4, 0),
    (25, 3, 0),
    (31, 4, 0),
    (34, 3, 1),
    (40, 4, 0);

INSERT INTO dbo.asignaciones_reporte (reporte_id, cuadrilla_id, fecha_asignacion, fecha_fin)
SELECT
    a.reporte_id,
    a.cuadrilla_id,
    DATEADD(HOUR, 12, r.fecha),
    CASE WHEN a.cerrada = 1 THEN DATEADD(DAY, 3, r.fecha) ELSE NULL END
FROM @asignaciones a
JOIN dbo.reportes r ON r.id = a.reporte_id;
GO

-- ============================================================
-- Historial coherente con el estado de cada reporte
-- ============================================================

-- 1. Reporte creado
INSERT INTO dbo.historial_reportes
    (reporte_id, fecha, accion_id, usuario_id, usuario_snapshot, observacion)
SELECT
    r.id,
    r.fecha,
    ac.id,
    CASE WHEN r.anonimo = 1 THEN NULL ELSE r.ciudadano_id END,
    CASE WHEN r.anonimo = 1 THEN N'Anónimo' ELSE NULL END,
    NULL
FROM dbo.reportes r
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Reporte creado') ac;
GO

-- 2. Validación (Aprobado / Rechazado)
INSERT INTO dbo.historial_reportes
    (reporte_id, fecha, accion_id, usuario_id, observacion)
SELECT
    r.id,
    DATEADD(HOUR, 6, r.fecha),
    CASE WHEN e.nombre = N'Rechazado' THEN ar.id ELSE aa.id END,
    CASE WHEN r.id % 2 = 0 THEN 4 ELSE 5 END,
    CASE
        WHEN e.nombre = N'Rechazado'
            THEN N'El reporte no cumple con los criterios de evidencia suficiente.'
        ELSE N'Reporte validado correctamente.'
    END
FROM dbo.reportes r
JOIN dbo.estados_reporte e ON e.id = r.estado_id
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Aprobado') aa
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Rechazado') ar
WHERE e.nombre IN
    (N'Aprobado', N'Rechazado', N'Programado', N'En atención', N'Atendido', N'Verificado');
GO

-- 3. Asignado a cuadrilla
INSERT INTO dbo.historial_reportes
    (reporte_id, fecha, accion_id, usuario_id, observacion)
SELECT
    a.reporte_id,
    DATEADD(HOUR, 12, r.fecha),
    ac.id,
    6,
    N'Asignado a ' + c.nombre
FROM dbo.asignaciones_reporte a
JOIN dbo.reportes r ON r.id = a.reporte_id
JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Asignado a cuadrilla') ac;
GO

-- 4. En atención
INSERT INTO dbo.historial_reportes
    (reporte_id, fecha, accion_id, usuario_id, observacion)
SELECT
    r.id,
    DATEADD(HOUR, 18, r.fecha),
    ac.id,
    c.responsable_id,
    NULL
FROM dbo.reportes r
JOIN dbo.estados_reporte e ON e.id = r.estado_id
JOIN dbo.asignaciones_reporte a ON a.reporte_id = r.id
JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'En atención') ac
WHERE e.nombre IN (N'En atención', N'Atendido', N'Verificado');
GO

-- 5. Atendido con evidencias
INSERT INTO dbo.historial_reportes
    (reporte_id, fecha, accion_id, usuario_id, observacion)
SELECT
    r.id,
    DATEADD(HOUR, 30, r.fecha),
    ac.id,
    c.responsable_id,
    N'Trabajo completado y evidencias cargadas.'
FROM dbo.reportes r
JOIN dbo.estados_reporte e ON e.id = r.estado_id
JOIN dbo.asignaciones_reporte a ON a.reporte_id = r.id
JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id
CROSS JOIN (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Atendido con evidencias') ac
WHERE e.nombre IN (N'Atendido', N'Verificado');
GO

-- ============================================================
-- Verificación rápida
-- ============================================================

SELECT 'usuarios' AS tabla, COUNT(*) AS total FROM dbo.usuarios
UNION ALL SELECT 'cuadrillas', COUNT(*) FROM dbo.cuadrillas
UNION ALL SELECT 'reportes', COUNT(*) FROM dbo.reportes
UNION ALL SELECT 'asignaciones', COUNT(*) FROM dbo.asignaciones_reporte
UNION ALL SELECT 'historial', COUNT(*) FROM dbo.historial_reportes
UNION ALL SELECT 'imagenes', COUNT(*) FROM dbo.reporte_imagenes
UNION ALL SELECT 'criterios', COUNT(*) FROM dbo.reporte_criterios;
GO

SELECT id, nombre, estado, zonaAsignada, distrito FROM dbo.vw_cuadrillas ORDER BY id;
GO
