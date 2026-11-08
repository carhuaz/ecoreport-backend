-- ============================================================
-- 01_schema.sql
-- Esquema normalizado a 3FN para EcoReportDB.
-- Catálogos, tablas, índices, función de roles y vistas.
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

USE master;
GO

IF DB_ID(N'EcoReportDB') IS NULL
    CREATE DATABASE EcoReportDB;
GO

USE EcoReportDB;
GO

-- ============================================================
-- Limpieza (permite re-ejecutar el script)
-- ============================================================

DROP VIEW IF EXISTS dbo.vw_historial;
DROP VIEW IF EXISTS dbo.vw_cuadrillas;
DROP VIEW IF EXISTS dbo.vw_reportes;
GO

DROP FUNCTION IF EXISTS dbo.fn_usuario_tiene_rol;
GO

DROP TABLE IF EXISTS dbo.historial_reportes;
DROP TABLE IF EXISTS dbo.asignaciones_reporte;
DROP TABLE IF EXISTS dbo.reporte_criterios;
DROP TABLE IF EXISTS dbo.reporte_imagenes;
DROP TABLE IF EXISTS dbo.contactos;
DROP TABLE IF EXISTS dbo.reportes;
DROP TABLE IF EXISTS dbo.cuadrillas;
DROP TABLE IF EXISTS dbo.usuarios;
DROP TABLE IF EXISTS dbo.configuracion;
DROP TABLE IF EXISTS dbo.acciones_historial;
DROP TABLE IF EXISTS dbo.prioridades;
DROP TABLE IF EXISTS dbo.distritos;
DROP TABLE IF EXISTS dbo.estados_reporte;
DROP TABLE IF EXISTS dbo.roles;
GO

-- ============================================================
-- Catálogos
-- ============================================================

CREATE TABLE dbo.roles (
    id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_roles PRIMARY KEY,
    nombre NVARCHAR(25)      NOT NULL,
    CONSTRAINT UQ_roles_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.estados_reporte (
    id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_estados_reporte PRIMARY KEY,
    nombre NVARCHAR(20)      NOT NULL,
    CONSTRAINT UQ_estados_reporte_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.distritos (
    id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_distritos PRIMARY KEY,
    nombre NVARCHAR(50)      NOT NULL,
    CONSTRAINT UQ_distritos_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.prioridades (
    id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_prioridades PRIMARY KEY,
    nombre       NVARCHAR(20)      NOT NULL,
    puntaje_min  INT               NOT NULL,
    puntaje_max  INT               NOT NULL,
    CONSTRAINT UQ_prioridades_nombre UNIQUE (nombre),
    CONSTRAINT CK_prioridades_rango CHECK (puntaje_min >= 0 AND puntaje_max >= puntaje_min)
);
GO

CREATE TABLE dbo.acciones_historial (
    id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_acciones_historial PRIMARY KEY,
    nombre NVARCHAR(100)     NOT NULL,
    CONSTRAINT UQ_acciones_historial_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.configuracion (
    clave NVARCHAR(50)  NOT NULL CONSTRAINT PK_configuracion PRIMARY KEY,
    valor NVARCHAR(200) NOT NULL
);
GO

-- ============================================================
-- Entidades
-- ============================================================

CREATE TABLE dbo.usuarios (
    id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_usuarios PRIMARY KEY,
    nombre              NVARCHAR(100)     NOT NULL,
    email               NVARCHAR(150)     NOT NULL,
    password            NVARCHAR(255)     NOT NULL,
    dni                 NVARCHAR(8)       NOT NULL,
    rol_id              INT               NOT NULL,
    activo              BIT               NOT NULL CONSTRAINT DF_usuarios_activo DEFAULT 1,
    codigo_verificacion NVARCHAR(60)      NULL,
    codigo_expira       DATETIME2         NULL,
    intentos_verificacion TINYINT         NOT NULL CONSTRAINT DF_usuarios_intentos DEFAULT 0,
    ultimo_envio_codigo DATETIME2         NULL,
    esta_verificado     BIT               NOT NULL CONSTRAINT DF_usuarios_verificado DEFAULT 0,
    fecha_registro      DATETIME2         NOT NULL CONSTRAINT DF_usuarios_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_usuarios_email UNIQUE (email),
    CONSTRAINT UQ_usuarios_dni UNIQUE (dni),
    CONSTRAINT FK_usuarios_roles FOREIGN KEY (rol_id) REFERENCES dbo.roles (id),
    CONSTRAINT CK_usuarios_dni CHECK (LEN(dni) = 8 AND dni NOT LIKE N'%[^0-9]%'),
    CONSTRAINT CK_usuarios_email CHECK (email LIKE N'%_@_%._%')
);
GO

CREATE TABLE dbo.cuadrillas (
    id             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_cuadrillas PRIMARY KEY,
    nombre         NVARCHAR(100)     NOT NULL,
    responsable_id INT               NOT NULL,
    distrito_id    INT               NOT NULL,
    zona_asignada  NVARCHAR(200)     NULL,
    activo         BIT               NOT NULL CONSTRAINT DF_cuadrillas_activo DEFAULT 1,
    CONSTRAINT FK_cuadrillas_usuarios FOREIGN KEY (responsable_id) REFERENCES dbo.usuarios (id),
    CONSTRAINT FK_cuadrillas_distritos FOREIGN KEY (distrito_id) REFERENCES dbo.distritos (id)
);
GO

CREATE TABLE dbo.reportes (
    id                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_reportes PRIMARY KEY,
    titulo            NVARCHAR(200)     NOT NULL,
    descripcion       NVARCHAR(MAX)     NULL,
    distrito_id       INT               NOT NULL,
    direccion         NVARCHAR(200)     NULL,
    estado_id         INT               NOT NULL,
    puntaje_prioridad INT               NOT NULL CONSTRAINT DF_reportes_puntaje DEFAULT 0,
    fecha             DATETIME2         NOT NULL CONSTRAINT DF_reportes_fecha DEFAULT SYSDATETIME(),
    latitud           DECIMAL(9,6)      NULL,
    longitud          DECIMAL(10,6)     NULL,
    ciudadano_id      INT               NULL,
    anonimo           BIT               NOT NULL CONSTRAINT DF_reportes_anonimo DEFAULT 0,
    CONSTRAINT FK_reportes_distritos FOREIGN KEY (distrito_id) REFERENCES dbo.distritos (id),
    CONSTRAINT FK_reportes_estados FOREIGN KEY (estado_id) REFERENCES dbo.estados_reporte (id),
    CONSTRAINT FK_reportes_usuarios FOREIGN KEY (ciudadano_id) REFERENCES dbo.usuarios (id),
    CONSTRAINT CK_reportes_puntaje CHECK (puntaje_prioridad BETWEEN 0 AND 100),
    CONSTRAINT CK_reportes_latitud CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT CK_reportes_longitud CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);
GO

CREATE TABLE dbo.reporte_imagenes (
    id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_reporte_imagenes PRIMARY KEY,
    reporte_id INT               NOT NULL,
    url        NVARCHAR(MAX)     NOT NULL,
    tipo       NVARCHAR(20)      NOT NULL CONSTRAINT DF_reporte_imagenes_tipo DEFAULT N'Reporte',
    orden      INT               NOT NULL CONSTRAINT DF_reporte_imagenes_orden DEFAULT 1,
    CONSTRAINT FK_reporte_imagenes_reportes FOREIGN KEY (reporte_id) REFERENCES dbo.reportes (id) ON DELETE CASCADE,
    CONSTRAINT CK_reporte_imagenes_tipo CHECK (tipo IN (N'Reporte', N'Evidencia')),
    CONSTRAINT UQ_reporte_imagenes_orden UNIQUE (reporte_id, tipo, orden)
);
GO

CREATE TABLE dbo.reporte_criterios (
    id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_reporte_criterios PRIMARY KEY,
    reporte_id  INT               NOT NULL,
    descripcion NVARCHAR(300)     NOT NULL,
    orden       INT               NOT NULL CONSTRAINT DF_reporte_criterios_orden DEFAULT 1,
    CONSTRAINT FK_reporte_criterios_reportes FOREIGN KEY (reporte_id) REFERENCES dbo.reportes (id) ON DELETE CASCADE,
    CONSTRAINT UQ_reporte_criterios_orden UNIQUE (reporte_id, orden)
);
GO

CREATE TABLE dbo.asignaciones_reporte (
    id               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_asignaciones_reporte PRIMARY KEY,
    reporte_id       INT               NOT NULL,
    cuadrilla_id     INT               NOT NULL,
    fecha_asignacion DATETIME2         NOT NULL CONSTRAINT DF_asignaciones_fecha DEFAULT SYSDATETIME(),
    fecha_fin        DATETIME2         NULL,
    CONSTRAINT FK_asignaciones_reportes FOREIGN KEY (reporte_id) REFERENCES dbo.reportes (id) ON DELETE CASCADE,
    CONSTRAINT FK_asignaciones_cuadrillas FOREIGN KEY (cuadrilla_id) REFERENCES dbo.cuadrillas (id),
    CONSTRAINT CK_asignaciones_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_asignacion)
);
GO

CREATE TABLE dbo.historial_reportes (
    id               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_historial_reportes PRIMARY KEY,
    reporte_id       INT               NOT NULL,
    fecha            DATETIME2         NOT NULL CONSTRAINT DF_historial_fecha DEFAULT SYSDATETIME(),
    accion_id        INT               NOT NULL,
    usuario_id       INT               NULL,
    usuario_snapshot NVARCHAR(100)     NULL,
    observacion      NVARCHAR(MAX)     NULL,
    CONSTRAINT FK_historial_reportes FOREIGN KEY (reporte_id) REFERENCES dbo.reportes (id) ON DELETE CASCADE,
    CONSTRAINT FK_historial_acciones FOREIGN KEY (accion_id) REFERENCES dbo.acciones_historial (id),
    CONSTRAINT FK_historial_usuarios FOREIGN KEY (usuario_id) REFERENCES dbo.usuarios (id)
);
GO

CREATE TABLE dbo.contactos (
    id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_contactos PRIMARY KEY,
    codigo  NVARCHAR(20)      NOT NULL,
    nombre  NVARCHAR(100)     NOT NULL,
    email   NVARCHAR(150)     NOT NULL,
    asunto  NVARCHAR(100)     NOT NULL,
    mensaje NVARCHAR(500)     NOT NULL,
    fecha   DATETIME2         NOT NULL CONSTRAINT DF_contactos_fecha DEFAULT SYSDATETIME(),
    leido   BIT               NOT NULL CONSTRAINT DF_contactos_leido DEFAULT 0,
    CONSTRAINT UQ_contactos_codigo UNIQUE (codigo)
);
GO

-- ============================================================
-- Índices
-- ============================================================

CREATE INDEX IX_reportes_estado_fecha ON dbo.reportes (estado_id, fecha);
CREATE INDEX IX_reportes_distrito ON dbo.reportes (distrito_id);
CREATE INDEX IX_reportes_ciudadano ON dbo.reportes (ciudadano_id);
CREATE INDEX IX_reportes_fecha ON dbo.reportes (fecha);
CREATE INDEX IX_asignaciones_cuadrilla ON dbo.asignaciones_reporte (cuadrilla_id) INCLUDE (reporte_id, fecha_fin);
CREATE INDEX IX_historial_reporte_fecha ON dbo.historial_reportes (reporte_id, fecha);
CREATE INDEX IX_cuadrillas_responsable ON dbo.cuadrillas (responsable_id);
CREATE INDEX IX_cuadrillas_distrito ON dbo.cuadrillas (distrito_id);
CREATE INDEX IX_reporte_imagenes_reporte ON dbo.reporte_imagenes (reporte_id);
CREATE INDEX IX_reporte_criterios_reporte ON dbo.reporte_criterios (reporte_id);
GO

-- Una sola asignación activa por reporte (activa = fecha_fin IS NULL)
CREATE UNIQUE INDEX UX_asignaciones_activa
ON dbo.asignaciones_reporte (reporte_id)
WHERE fecha_fin IS NULL;
GO

-- ============================================================
-- Función auxiliar de permisos
-- ============================================================

CREATE FUNCTION dbo.fn_usuario_tiene_rol
(
    @usuario_id INT,
    @rol NVARCHAR(25)
)
RETURNS BIT
AS
BEGIN
    RETURN CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.usuarios u
            JOIN dbo.roles r ON r.id = u.rol_id
            WHERE u.id = @usuario_id
              AND r.nombre = @rol
              AND u.activo = 1
        ) THEN 1
        ELSE 0
    END;
END;
GO

-- ============================================================
-- Vistas
-- ============================================================

CREATE VIEW dbo.vw_reportes
AS
SELECT
    r.id,
    r.titulo,
    r.descripcion,
    d.nombre AS distrito,
    r.direccion,
    e.nombre AS estado,
    COALESCE(p.nombre, N'Crítica') AS prioridad,
    r.puntaje_prioridad,
    CONVERT(VARCHAR(10), r.fecha, 23) AS fecha,
    r.latitud,
    r.longitud,
    COALESCE(
        '[' + STUFF((
            SELECT ',' + '"' + STRING_ESCAPE(i.url, 'json') + '"'
            FROM dbo.reporte_imagenes i
            WHERE i.reporte_id = r.id
            ORDER BY CASE WHEN i.tipo = N'Reporte' THEN 0 ELSE 1 END, i.orden
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') + ']',
        '[]'
    ) AS imagenes,
    COALESCE(
        '[' + STUFF((
            SELECT ',' + '"' + STRING_ESCAPE(cr.descripcion, 'json') + '"'
            FROM dbo.reporte_criterios cr
            WHERE cr.reporte_id = r.id
            ORDER BY cr.orden
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') + ']',
        '[]'
    ) AS criterios_prioridad,
    r.ciudadano_id,
    CASE WHEN r.anonimo = 1 THEN N'Anónimo' ELSE COALESCE(u.nombre, N'Ciudadano') END AS ciudadano_nombre,
    r.anonimo,
    (
        SELECT TOP (1) h.observacion
        FROM dbo.historial_reportes h
        JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
        WHERE h.reporte_id = r.id
          AND ac.nombre IN (N'Aprobado', N'Rechazado')
        ORDER BY h.fecha DESC, h.id DESC
    ) AS observacion_validacion,
    a.cuadrilla_id,
    c.nombre AS cuadrilla_nombre
FROM dbo.reportes r
JOIN dbo.distritos d ON d.id = r.distrito_id
JOIN dbo.estados_reporte e ON e.id = r.estado_id
LEFT JOIN dbo.prioridades p
    ON r.puntaje_prioridad BETWEEN p.puntaje_min AND p.puntaje_max
LEFT JOIN dbo.usuarios u ON u.id = r.ciudadano_id
OUTER APPLY (
    SELECT TOP (1) ar.cuadrilla_id
    FROM dbo.asignaciones_reporte ar
    WHERE ar.reporte_id = r.id
    ORDER BY CASE WHEN ar.fecha_fin IS NULL THEN 0 ELSE 1 END,
             ar.fecha_asignacion DESC,
             ar.id DESC
) a
LEFT JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id;
GO

CREATE VIEW dbo.vw_cuadrillas
AS
SELECT
    c.id,
    c.nombre,
    u.nombre AS responsable,
    c.responsable_id AS responsableId,
    CASE
        WHEN x.activos = 0 THEN N'Disponible'
        WHEN x.activos >= COALESCE(
            CAST((SELECT valor FROM dbo.configuracion WHERE clave = N'MAX_ASIGNACIONES_POR_CUADRILLA') AS INT),
            3
        ) THEN N'Ocupada'
        ELSE N'En ruta'
    END AS estado,
    c.zona_asignada AS zonaAsignada,
    d.nombre AS distrito
FROM dbo.cuadrillas c
JOIN dbo.usuarios u ON u.id = c.responsable_id
JOIN dbo.distritos d ON d.id = c.distrito_id
CROSS APPLY (
    SELECT COUNT(*) AS activos
    FROM dbo.asignaciones_reporte a
    WHERE a.cuadrilla_id = c.id
      AND a.fecha_fin IS NULL
) x
WHERE c.activo = 1;
GO

CREATE VIEW dbo.vw_historial
AS
SELECT
    h.id,
    h.reporte_id,
    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
    ac.nombre AS accion,
    COALESCE(h.usuario_snapshot, u.nombre, N'Sistema') AS usuario,
    h.observacion
FROM dbo.historial_reportes h
JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
LEFT JOIN dbo.usuarios u ON u.id = h.usuario_id;
GO
