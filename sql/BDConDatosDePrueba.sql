-- ============================================================
-- EcoReportDB - SCRIPT MAESTRO (esquema + SPs + seed + seguridad)
-- Ejecutar en SSMS con un login sysadmin (sa).
-- Generado a partir de 00_drop.sql, 01_schema.sql, 02_procedures.sql,
-- 03_seed.sql y 04_security.sql. No editar a mano: editar los parciales.
-- ============================================================
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


-- ============================================================
-- 02_procedures.sql
-- Stored procedures de EcoReportDB.
-- Todas las operaciones de la aplicación pasan por aquí.
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE EcoReportDB;
GO

-- ============================================================
-- AUTH
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_auth_login;
GO
CREATE PROCEDURE dbo.usp_auth_login
    @email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET @email = LOWER(LTRIM(RTRIM(@email)));

    SELECT
        u.id,
        u.nombre,
        u.email,
        u.password,
        r.nombre AS rol,
        u.activo,
        u.esta_verificado
    FROM dbo.usuarios u
    JOIN dbo.roles r ON r.id = u.rol_id
    WHERE u.email = @email;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_registrar;
GO
CREATE PROCEDURE dbo.usp_auth_registrar
    @nombre        NVARCHAR(100),
    @email         NVARCHAR(150),
    @password_hash NVARCHAR(255),
    @dni           NVARCHAR(8),
    @codigo_hash   NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @nombre = LTRIM(RTRIM(@nombre));
    SET @email  = LOWER(LTRIM(RTRIM(@email)));
    SET @dni    = LTRIM(RTRIM(@dni));

    IF @nombre IS NULL OR LEN(@nombre) = 0
        THROW 50006, N'El nombre es obligatorio.', 1;
    IF @email IS NULL OR @email NOT LIKE N'%_@_%._%'
        THROW 50006, N'El correo electrónico no es válido.', 1;
    IF @dni IS NULL OR LEN(@dni) <> 8 OR @dni LIKE N'%[^0-9]%'
        THROW 50006, N'El DNI debe tener 8 dígitos numéricos.', 1;
    IF @password_hash IS NULL OR LEN(@password_hash) = 0
        THROW 50006, N'La contraseña es obligatoria.', 1;
    IF @codigo_hash IS NULL OR LEN(@codigo_hash) = 0
        THROW 50006, N'El código de verificación es obligatorio.', 1;

    DECLARE @rol_ciudadano INT = (SELECT id FROM dbo.roles WHERE nombre = N'Ciudadano');
    IF @rol_ciudadano IS NULL
        THROW 50006, N'El rol Ciudadano no está configurado.', 1;

    IF EXISTS (SELECT 1 FROM dbo.usuarios WHERE email = @email AND esta_verificado = 1)
        THROW 50005, N'El email ya está registrado y verificado.', 1;

    IF EXISTS (SELECT 1 FROM dbo.usuarios WHERE dni = @dni AND email <> @email)
        THROW 50005, N'El DNI ya está registrado.', 1;

    DECLARE @id INT = (SELECT id FROM dbo.usuarios WHERE email = @email);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @id IS NOT NULL
        BEGIN
            UPDATE dbo.usuarios
            SET nombre = @nombre,
                password = @password_hash,
                dni = @dni,
                rol_id = @rol_ciudadano,
                activo = 1,
                codigo_verificacion = @codigo_hash,
                esta_verificado = 0
            WHERE id = @id;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.usuarios
                (nombre, email, password, dni, rol_id, activo, codigo_verificacion, esta_verificado)
            VALUES
                (@nombre, @email, @password_hash, @dni, @rol_ciudadano, 1, @codigo_hash, 0);

            SET @id = SCOPE_IDENTITY();
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT @id AS id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_obtener_por_email;
GO
CREATE PROCEDURE dbo.usp_auth_obtener_por_email
    @email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET @email = LOWER(LTRIM(RTRIM(@email)));

    SELECT
        u.id,
        u.nombre,
        u.email,
        u.password,
        u.codigo_verificacion,
        u.esta_verificado,
        r.nombre AS rol
    FROM dbo.usuarios u
    JOIN dbo.roles r ON r.id = u.rol_id
    WHERE u.email = @email;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_marcar_verificado;
GO
CREATE PROCEDURE dbo.usp_auth_marcar_verificado
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.usuarios
    SET esta_verificado = 1,
        codigo_verificacion = NULL
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_guardar_codigo;
GO
CREATE PROCEDURE dbo.usp_auth_guardar_codigo
    @id INT,
    @codigo_hash NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.usuarios
    SET codigo_verificacion = @codigo_hash
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_me;
GO
CREATE PROCEDURE dbo.usp_auth_me
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.id,
        u.nombre,
        u.email,
        u.dni,
        r.nombre AS rol,
        u.activo,
        CONVERT(VARCHAR(10), u.fecha_registro, 23) AS fecha_registro
    FROM dbo.usuarios u
    JOIN dbo.roles r ON r.id = u.rol_id
    WHERE u.id = @id;
END;
GO

-- ============================================================
-- USUARIOS
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_usuarios_listar;
GO
CREATE PROCEDURE dbo.usp_usuarios_listar
    @usuario_id INT,
    @termino    NVARCHAR(100) = NULL,
    @rol        NVARCHAR(25)  = NULL,
    @page       INT           = NULL,
    @page_size  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para listar usuarios.', 1;

    SET @termino = NULLIF(LTRIM(RTRIM(@termino)), N'');
    SET @rol     = NULLIF(LTRIM(RTRIM(@rol)), N'');

    IF @page IS NULL
    BEGIN
        SELECT
            u.id,
            u.nombre,
            u.email,
            u.dni,
            r.nombre AS rol,
            u.activo,
            CONVERT(VARCHAR(10), u.fecha_registro, 23) AS fecha_registro
        FROM dbo.usuarios u
        JOIN dbo.roles r ON r.id = u.rol_id
        WHERE (@termino IS NULL OR LOWER(u.nombre) LIKE N'%' + LOWER(@termino) + N'%'
                               OR LOWER(u.email)  LIKE N'%' + LOWER(@termino) + N'%')
          AND (@rol IS NULL OR r.nombre = @rol)
        ORDER BY u.id;
        RETURN;
    END

    IF @page < 1 OR @page_size < 1 OR @page_size > 200
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.usuarios u
    JOIN dbo.roles r ON r.id = u.rol_id
    WHERE (@termino IS NULL OR LOWER(u.nombre) LIKE N'%' + LOWER(@termino) + N'%'
                           OR LOWER(u.email)  LIKE N'%' + LOWER(@termino) + N'%')
      AND (@rol IS NULL OR r.nombre = @rol);

    SELECT
        u.id,
        u.nombre,
        u.email,
        u.dni,
        r.nombre AS rol,
        u.activo,
        CONVERT(VARCHAR(10), u.fecha_registro, 23) AS fecha_registro
    FROM dbo.usuarios u
    JOIN dbo.roles r ON r.id = u.rol_id
    WHERE (@termino IS NULL OR LOWER(u.nombre) LIKE N'%' + LOWER(@termino) + N'%'
                           OR LOWER(u.email)  LIKE N'%' + LOWER(@termino) + N'%')
      AND (@rol IS NULL OR r.nombre = @rol)
    ORDER BY u.id
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_usuario_cambiar_rol;
GO
CREATE PROCEDURE dbo.usp_usuario_cambiar_rol
    @usuario_id INT,
    @id         INT,
    @rol        NVARCHAR(25)
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para cambiar roles.', 1;

    DECLARE @rol_id INT = (SELECT id FROM dbo.roles WHERE nombre = @rol);
    IF @rol_id IS NULL
        THROW 50006, N'Rol inválido.', 1;

    UPDATE dbo.usuarios
    SET rol_id = @rol_id
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_usuario_activar;
GO
CREATE PROCEDURE dbo.usp_usuario_activar
    @usuario_id INT,
    @id         INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para activar usuarios.', 1;

    UPDATE dbo.usuarios
    SET activo = 1
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_usuario_desactivar;
GO
CREATE PROCEDURE dbo.usp_usuario_desactivar
    @usuario_id INT,
    @id         INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para desactivar usuarios.', 1;

    IF @id = @usuario_id
        THROW 50006, N'No puedes desactivarte a ti mismo.', 1;

    UPDATE dbo.usuarios
    SET activo = 0
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

-- ============================================================
-- CUADRILLAS
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_cuadrillas_listar;
GO
CREATE PROCEDURE dbo.usp_cuadrillas_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_cuadrillas ORDER BY id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrillas_disponibles;
GO
CREATE PROCEDURE dbo.usp_cuadrillas_disponibles
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_cuadrillas WHERE estado = N'Disponible' ORDER BY id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrillas_por_responsable;
GO
CREATE PROCEDURE dbo.usp_cuadrillas_por_responsable
    @responsable_id INT,
    @usuario_id     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
    BEGIN
        IF dbo.fn_usuario_tiene_rol(@usuario_id, N'ResponsableCuadrilla') = 0
            THROW 50004, N'No tienes permiso para consultar cuadrillas.', 1;
        IF @responsable_id <> @usuario_id
            THROW 50004, N'No tienes acceso a las cuadrillas de otro responsable.', 1;
    END

    SELECT * FROM dbo.vw_cuadrillas WHERE responsableId = @responsable_id ORDER BY id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrilla_crear;
GO
CREATE PROCEDURE dbo.usp_cuadrilla_crear
    @usuario_id      INT,
    @nombre          NVARCHAR(100),
    @responsable_id  INT,
    @distrito        NVARCHAR(50),
    @zona_asignada   NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para crear cuadrillas.', 1;

    SET @nombre = LTRIM(RTRIM(@nombre));
    IF @nombre IS NULL OR LEN(@nombre) = 0
        THROW 50006, N'El nombre es obligatorio.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.usuarios u
        JOIN dbo.roles r ON r.id = u.rol_id
        WHERE u.id = @responsable_id
          AND r.nombre = N'ResponsableCuadrilla'
          AND u.activo = 1
    )
        THROW 50006, N'El responsable no existe o no tiene el rol ResponsableCuadrilla.', 1;

    DECLARE @distrito_id INT = (SELECT id FROM dbo.distritos WHERE nombre = @distrito);
    IF @distrito_id IS NULL
        THROW 50006, N'Distrito inválido.', 1;

    INSERT INTO dbo.cuadrillas (nombre, responsable_id, distrito_id, zona_asignada, activo)
    VALUES (@nombre, @responsable_id, @distrito_id, NULLIF(LTRIM(RTRIM(@zona_asignada)), N''), 1);

    SELECT SCOPE_IDENTITY() AS id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrilla_actualizar;
GO
CREATE PROCEDURE dbo.usp_cuadrilla_actualizar
    @usuario_id      INT,
    @id              INT,
    @nombre          NVARCHAR(100) = NULL,
    @responsable_id  INT           = NULL,
    @distrito        NVARCHAR(50)  = NULL,
    @zona_asignada   NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para actualizar cuadrillas.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.cuadrillas WHERE id = @id AND activo = 1)
        THROW 50001, N'Cuadrilla no encontrada.', 1;

    IF @nombre IS NOT NULL
    BEGIN
        SET @nombre = LTRIM(RTRIM(@nombre));
        IF LEN(@nombre) = 0
            THROW 50006, N'El nombre no puede estar vacío.', 1;
    END

    IF @responsable_id IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.usuarios u
            JOIN dbo.roles r ON r.id = u.rol_id
            WHERE u.id = @responsable_id
              AND r.nombre = N'ResponsableCuadrilla'
              AND u.activo = 1
        )
            THROW 50006, N'El responsable no existe o no tiene el rol ResponsableCuadrilla.', 1;
    END

    DECLARE @distrito_id INT = NULL;
    IF @distrito IS NOT NULL
    BEGIN
        SET @distrito_id = (SELECT id FROM dbo.distritos WHERE nombre = @distrito);
        IF @distrito_id IS NULL
            THROW 50006, N'Distrito inválido.', 1;
    END

    UPDATE dbo.cuadrillas
    SET nombre         = COALESCE(@nombre, nombre),
        responsable_id = COALESCE(@responsable_id, responsable_id),
        distrito_id    = COALESCE(@distrito_id, distrito_id),
        zona_asignada  = CASE
            WHEN @zona_asignada IS NULL THEN zona_asignada
            ELSE NULLIF(LTRIM(RTRIM(@zona_asignada)), N'')
        END
    WHERE id = @id;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrilla_eliminar;
GO
CREATE PROCEDURE dbo.usp_cuadrilla_eliminar
    @usuario_id INT,
    @id         INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para eliminar cuadrillas.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.cuadrillas WHERE id = @id AND activo = 1)
        THROW 50001, N'Cuadrilla no encontrada.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.asignaciones_reporte
        WHERE cuadrilla_id = @id
          AND fecha_fin IS NULL
    )
        THROW 50003, N'No se puede eliminar: la cuadrilla tiene reportes activos asignados.', 1;

    UPDATE dbo.cuadrillas
    SET activo = 0
    WHERE id = @id;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cuadrilla_asignar;
GO
CREATE PROCEDURE dbo.usp_cuadrilla_asignar
    @usuario_id   INT,
    @cuadrilla_id INT,
    @reporte_id   INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para asignar reportes.', 1;

    DECLARE @cuadrilla_nombre NVARCHAR(100) =
        (SELECT nombre FROM dbo.cuadrillas WHERE id = @cuadrilla_id AND activo = 1);
    IF @cuadrilla_nombre IS NULL
        THROW 50001, N'Cuadrilla no encontrada.', 1;

    DECLARE @estado NVARCHAR(20) = (
        SELECT e.nombre
        FROM dbo.reportes r
        JOIN dbo.estados_reporte e ON e.id = r.estado_id
        WHERE r.id = @reporte_id
    );
    IF @estado IS NULL
        THROW 50001, N'Reporte no encontrado.', 1;
    IF @estado NOT IN (N'Aprobado', N'Programado')
        THROW 50002, N'Solo se pueden asignar reportes en estado Aprobado o Programado.', 1;

    DECLARE @max INT = COALESCE(
        CAST((SELECT valor FROM dbo.configuracion WHERE clave = N'MAX_ASIGNACIONES_POR_CUADRILLA') AS INT),
        3
    );
    DECLARE @activos INT = (
        SELECT COUNT(*)
        FROM dbo.asignaciones_reporte
        WHERE cuadrilla_id = @cuadrilla_id
          AND fecha_fin IS NULL
    );
    IF @activos >= @max
        THROW 50003, N'La cuadrilla ya tiene el máximo de asignaciones activas.', 1;

    DECLARE @estado_programado INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'Programado');
    DECLARE @accion_asignado INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Asignado a cuadrilla');

    IF @estado_programado IS NULL OR @accion_asignado IS NULL
        THROW 50006, N'Catálogos de estado o acción no configurados.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.asignaciones_reporte
        SET fecha_fin = SYSDATETIME()
        WHERE reporte_id = @reporte_id
          AND fecha_fin IS NULL;

        INSERT INTO dbo.asignaciones_reporte (reporte_id, cuadrilla_id, fecha_asignacion, fecha_fin)
        VALUES (@reporte_id, @cuadrilla_id, SYSDATETIME(), NULL);

        UPDATE dbo.reportes
        SET estado_id = @estado_programado
        WHERE id = @reporte_id;

        INSERT INTO dbo.historial_reportes (reporte_id, accion_id, usuario_id, observacion)
        VALUES (@reporte_id, @accion_asignado, @usuario_id, N'Asignado a ' + @cuadrilla_nombre);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS ok;
END;
GO

-- ============================================================
-- REPORTES
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_reportes_listar;
GO
CREATE PROCEDURE dbo.usp_reportes_listar
    @estado    NVARCHAR(20) = NULL,
    @distrito  NVARCHAR(50) = NULL,
    @prioridad NVARCHAR(20) = NULL,
    @page      INT          = 1,
    @page_size INT          = 20
AS
BEGIN
    SET NOCOUNT ON;

    SET @estado    = NULLIF(LTRIM(RTRIM(@estado)), N'');
    SET @distrito  = NULLIF(LTRIM(RTRIM(@distrito)), N'');
    SET @prioridad = NULLIF(LTRIM(RTRIM(@prioridad)), N'');

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.vw_reportes v
    WHERE (@estado IS NULL OR v.estado = @estado)
      AND (@distrito IS NULL OR v.distrito = @distrito)
      AND (@prioridad IS NULL OR v.prioridad = @prioridad);

    SELECT
        v.*,
        COALESCE(
            (
                SELECT TOP (2147483647)
                    h.id,
                    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
                    ac.nombre AS accion,
                    COALESCE(h.usuario_snapshot, hu.nombre, N'Sistema') AS usuario,
                    h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                LEFT JOIN dbo.usuarios hu ON hu.id = h.usuario_id
                WHERE h.reporte_id = v.id
                ORDER BY h.fecha ASC, h.id ASC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ),
            '[]'
        ) AS historial
    FROM dbo.vw_reportes v
    WHERE (@estado IS NULL OR v.estado = @estado)
      AND (@distrito IS NULL OR v.distrito = @distrito)
      AND (@prioridad IS NULL OR v.prioridad = @prioridad)
    ORDER BY v.fecha DESC, v.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reportes_publicos;
GO
CREATE PROCEDURE dbo.usp_reportes_publicos
    @distrito  NVARCHAR(50) = NULL,
    @estado    NVARCHAR(20) = NULL,
    @page      INT          = 1,
    @page_size INT          = 20
AS
BEGIN
    SET NOCOUNT ON;

    SET @distrito = NULLIF(LTRIM(RTRIM(@distrito)), N'');
    SET @estado   = NULLIF(LTRIM(RTRIM(@estado)), N'');

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.vw_reportes v
    WHERE v.estado NOT IN (N'Pendiente', N'Rechazado')
      AND (@distrito IS NULL OR v.distrito = @distrito)
      AND (@estado IS NULL OR v.estado = @estado);

    SELECT
        v.*,
        COALESCE(
            (
                SELECT TOP (2147483647)
                    h.id,
                    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
                    ac.nombre AS accion,
                    COALESCE(h.usuario_snapshot, hu.nombre, N'Sistema') AS usuario,
                    h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                LEFT JOIN dbo.usuarios hu ON hu.id = h.usuario_id
                WHERE h.reporte_id = v.id
                ORDER BY h.fecha ASC, h.id ASC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ),
            '[]'
        ) AS historial
    FROM dbo.vw_reportes v
    WHERE v.estado NOT IN (N'Pendiente', N'Rechazado')
      AND (@distrito IS NULL OR v.distrito = @distrito)
      AND (@estado IS NULL OR v.estado = @estado)
    ORDER BY v.fecha DESC, v.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reportes_por_ciudadano;
GO
CREATE PROCEDURE dbo.usp_reportes_por_ciudadano
    @ciudadano_id INT,
    @page         INT = 1,
    @page_size    INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.vw_reportes v
    WHERE v.ciudadano_id = @ciudadano_id;

    SELECT
        v.*,
        COALESCE(
            (
                SELECT TOP (2147483647)
                    h.id,
                    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
                    ac.nombre AS accion,
                    COALESCE(h.usuario_snapshot, hu.nombre, N'Sistema') AS usuario,
                    h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                LEFT JOIN dbo.usuarios hu ON hu.id = h.usuario_id
                WHERE h.reporte_id = v.id
                ORDER BY h.fecha ASC, h.id ASC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ),
            '[]'
        ) AS historial
    FROM dbo.vw_reportes v
    WHERE v.ciudadano_id = @ciudadano_id
    ORDER BY v.fecha DESC, v.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reportes_por_cuadrilla;
GO
CREATE PROCEDURE dbo.usp_reportes_por_cuadrilla
    @usuario_id   INT,
    @cuadrilla_id INT,
    @estado       NVARCHAR(20) = NULL,
    @page         INT          = 1,
    @page_size    INT          = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.cuadrillas
            WHERE id = @cuadrilla_id
              AND responsable_id = @usuario_id
              AND activo = 1
        )
            THROW 50004, N'No tienes acceso a esta cuadrilla.', 1;
    END

    SET @estado = NULLIF(LTRIM(RTRIM(@estado)), N'');

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.vw_reportes v
    WHERE v.cuadrilla_id = @cuadrilla_id
      AND (@estado IS NULL OR v.estado = @estado);

    SELECT
        v.*,
        COALESCE(
            (
                SELECT TOP (2147483647)
                    h.id,
                    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
                    ac.nombre AS accion,
                    COALESCE(h.usuario_snapshot, hu.nombre, N'Sistema') AS usuario,
                    h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                LEFT JOIN dbo.usuarios hu ON hu.id = h.usuario_id
                WHERE h.reporte_id = v.id
                ORDER BY h.fecha ASC, h.id ASC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ),
            '[]'
        ) AS historial
    FROM dbo.vw_reportes v
    WHERE v.cuadrilla_id = @cuadrilla_id
      AND (@estado IS NULL OR v.estado = @estado)
    ORDER BY v.fecha DESC, v.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reportes_auditoria_evidencias;
GO
CREATE PROCEDURE dbo.usp_reportes_auditoria_evidencias
    @usuario_id   INT,
    @page         INT = 1,
    @page_size    INT = 20,
    @cuadrilla_id INT = NULL,
    @estado       NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para consultar la auditoría de evidencias.', 1;

    SET @estado = NULLIF(LTRIM(RTRIM(@estado)), N'');

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.vw_reportes v
    WHERE v.estado IN (N'Atendido', N'Verificado')
      AND (@cuadrilla_id IS NULL OR v.cuadrilla_id = @cuadrilla_id)
      AND (@estado IS NULL OR v.estado = @estado);

    SELECT
        v.id,
        v.titulo,
        v.descripcion,
        v.distrito,
        v.estado,
        v.imagenes,
        v.fecha,
        v.cuadrilla_id,
        v.cuadrilla_nombre,
        COALESCE(
            (
                SELECT TOP (1) h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                WHERE h.reporte_id = v.id
                  AND ac.nombre = N'Atendido con evidencias'
                ORDER BY h.fecha DESC, h.id DESC
            ),
            N''
        ) AS observacion_completado
    FROM dbo.vw_reportes v
    WHERE v.estado IN (N'Atendido', N'Verificado')
      AND (@cuadrilla_id IS NULL OR v.cuadrilla_id = @cuadrilla_id)
      AND (@estado IS NULL OR v.estado = @estado)
    ORDER BY v.fecha DESC, v.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reportes_auditoria_validaciones;
GO
CREATE PROCEDURE dbo.usp_reportes_auditoria_validaciones
    @usuario_id INT,
    @page       INT = 1,
    @page_size  INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador') = 0
        THROW 50004, N'No tienes permiso para consultar la auditoría de validaciones.', 1;

    IF @page < 1 OR @page_size < 1 OR @page_size > 100
        THROW 50006, N'Parámetros de paginación inválidos.', 1;

    DECLARE @offset INT = (@page - 1) * @page_size;

    SELECT COUNT(*) AS total
    FROM dbo.historial_reportes h
    JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
    WHERE ac.nombre IN (N'Aprobado', N'Rechazado');

    SELECT
        h.id,
        h.reporte_id,
        CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
        ac.nombre AS accion,
        h.usuario_id,
        h.observacion,
        v.titulo,
        v.distrito,
        v.prioridad,
        v.estado AS estado_reporte,
        v.imagenes,
        COALESCE(h.usuario_snapshot, u.nombre, N'Sistema') AS validador_nombre
    FROM dbo.historial_reportes h
    JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
    JOIN dbo.vw_reportes v ON v.id = h.reporte_id
    LEFT JOIN dbo.usuarios u ON u.id = h.usuario_id
    WHERE ac.nombre IN (N'Aprobado', N'Rechazado')
    ORDER BY h.fecha DESC, h.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_crear;
GO
CREATE PROCEDURE dbo.usp_reporte_crear
    @titulo            NVARCHAR(200),
    @descripcion       NVARCHAR(MAX),
    @distrito          NVARCHAR(50),
    @direccion         NVARCHAR(200),
    @latitud           DECIMAL(9,6),
    @longitud          DECIMAL(10,6),
    @ciudadano_id      INT,
    @puntaje_prioridad INT,
    @anonimo           BIT,
    @imagenes_json     NVARCHAR(MAX),
    @criterios_json    NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @titulo = LTRIM(RTRIM(@titulo));
    IF @titulo IS NULL OR LEN(@titulo) = 0
        THROW 50006, N'El título es obligatorio.', 1;

    IF @puntaje_prioridad IS NULL OR @puntaje_prioridad < 0 OR @puntaje_prioridad > 100
        THROW 50006, N'El puntaje de prioridad debe estar entre 0 y 100.', 1;

    DECLARE @distrito_id INT = (SELECT id FROM dbo.distritos WHERE nombre = @distrito);
    IF @distrito_id IS NULL
        THROW 50006, N'Distrito inválido.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.usuarios WHERE id = @ciudadano_id AND activo = 1)
        THROW 50001, N'Ciudadano no encontrado o inactivo.', 1;

    IF @imagenes_json IS NOT NULL AND ISJSON(@imagenes_json) = 0
        THROW 50006, N'El JSON de imágenes no es válido.', 1;
    IF @criterios_json IS NOT NULL AND ISJSON(@criterios_json) = 0
        THROW 50006, N'El JSON de criterios no es válido.', 1;

    DECLARE @estado_pendiente INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'Pendiente');
    DECLARE @accion_creado INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Reporte creado');

    IF @estado_pendiente IS NULL OR @accion_creado IS NULL
        THROW 50006, N'Catálogos de estado o acción no configurados.', 1;

    DECLARE @reporte_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.reportes
            (titulo, descripcion, distrito_id, direccion, estado_id, puntaje_prioridad,
             fecha, latitud, longitud, ciudadano_id, anonimo)
        VALUES
            (@titulo, @descripcion, @distrito_id, @direccion, @estado_pendiente, @puntaje_prioridad,
             SYSDATETIME(), @latitud, @longitud, @ciudadano_id, @anonimo);

        SET @reporte_id = SCOPE_IDENTITY();

        IF @imagenes_json IS NOT NULL AND ISJSON(@imagenes_json) = 1
        BEGIN
            INSERT INTO dbo.reporte_imagenes (reporte_id, url, tipo, orden)
            SELECT
                @reporte_id,
                j.[value],
                N'Reporte',
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            FROM OPENJSON(@imagenes_json) WITH ([value] NVARCHAR(MAX) '$') j
            WHERE j.[value] IS NOT NULL
              AND LEN(j.[value]) > 0;
        END

        IF @criterios_json IS NOT NULL AND ISJSON(@criterios_json) = 1
        BEGIN
            INSERT INTO dbo.reporte_criterios (reporte_id, descripcion, orden)
            SELECT
                @reporte_id,
                j.[value],
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            FROM OPENJSON(@criterios_json) WITH ([value] NVARCHAR(MAX) '$') j
            WHERE j.[value] IS NOT NULL
              AND LEN(j.[value]) > 0;
        END

        INSERT INTO dbo.historial_reportes
            (reporte_id, accion_id, usuario_id, usuario_snapshot, observacion)
        VALUES
            (@reporte_id, @accion_creado,
             CASE WHEN @anonimo = 1 THEN NULL ELSE @ciudadano_id END,
             CASE WHEN @anonimo = 1 THEN N'Anónimo' ELSE NULL END,
             NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT @reporte_id AS id;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_aprobar;
GO
CREATE PROCEDURE dbo.usp_reporte_aprobar
    @reporte_id  INT,
    @usuario_id  INT,
    @observacion NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Validador') = 0
        THROW 50004, N'No tienes permiso para aprobar reportes.', 1;

    DECLARE @estado NVARCHAR(20) = (
        SELECT e.nombre
        FROM dbo.reportes r
        JOIN dbo.estados_reporte e ON e.id = r.estado_id
        WHERE r.id = @reporte_id
    );
    IF @estado IS NULL
        THROW 50001, N'Reporte no encontrado.', 1;
    IF @estado <> N'Pendiente'
        THROW 50002, N'Solo se puede aprobar un reporte en estado Pendiente.', 1;

    DECLARE @estado_aprobado INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'Aprobado');
    DECLARE @accion_aprobado INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Aprobado');

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.reportes
        SET estado_id = @estado_aprobado
        WHERE id = @reporte_id;

        INSERT INTO dbo.historial_reportes (reporte_id, accion_id, usuario_id, observacion)
        VALUES (@reporte_id, @accion_aprobado, @usuario_id, @observacion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_rechazar;
GO
CREATE PROCEDURE dbo.usp_reporte_rechazar
    @reporte_id  INT,
    @usuario_id  INT,
    @observacion NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'Validador') = 0
        THROW 50004, N'No tienes permiso para rechazar reportes.', 1;

    DECLARE @estado NVARCHAR(20) = (
        SELECT e.nombre
        FROM dbo.reportes r
        JOIN dbo.estados_reporte e ON e.id = r.estado_id
        WHERE r.id = @reporte_id
    );
    IF @estado IS NULL
        THROW 50001, N'Reporte no encontrado.', 1;
    IF @estado <> N'Pendiente'
        THROW 50002, N'Solo se puede rechazar un reporte en estado Pendiente.', 1;

    DECLARE @estado_rechazado INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'Rechazado');
    DECLARE @accion_rechazado INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Rechazado');

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.reportes
        SET estado_id = @estado_rechazado
        WHERE id = @reporte_id;

        INSERT INTO dbo.historial_reportes (reporte_id, accion_id, usuario_id, observacion)
        VALUES (@reporte_id, @accion_rechazado, @usuario_id, @observacion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_en_atencion;
GO
CREATE PROCEDURE dbo.usp_reporte_en_atencion
    @reporte_id INT,
    @usuario_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @es_admin BIT = dbo.fn_usuario_tiene_rol(@usuario_id, N'Administrador');
    DECLARE @es_responsable BIT = dbo.fn_usuario_tiene_rol(@usuario_id, N'ResponsableCuadrilla');

    IF @es_admin = 0 AND @es_responsable = 0
        THROW 50004, N'No tienes permiso para marcar reportes en atención.', 1;

    DECLARE @estado NVARCHAR(20) = (
        SELECT e.nombre
        FROM dbo.reportes r
        JOIN dbo.estados_reporte e ON e.id = r.estado_id
        WHERE r.id = @reporte_id
    );
    IF @estado IS NULL
        THROW 50001, N'Reporte no encontrado.', 1;
    IF @estado <> N'Programado'
        THROW 50002, N'Solo se puede marcar en atención un reporte Programado.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.asignaciones_reporte
        WHERE reporte_id = @reporte_id
          AND fecha_fin IS NULL
    )
        THROW 50006, N'El reporte no tiene una asignación activa.', 1;

    IF @es_admin = 0 AND NOT EXISTS (
        SELECT 1
        FROM dbo.asignaciones_reporte a
        JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id
        WHERE a.reporte_id = @reporte_id
          AND a.fecha_fin IS NULL
          AND c.responsable_id = @usuario_id
    )
        THROW 50004, N'No tienes acceso a este reporte.', 1;

    DECLARE @estado_en_atencion INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'En atención');
    DECLARE @accion_en_atencion INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'En atención');

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.reportes
        SET estado_id = @estado_en_atencion
        WHERE id = @reporte_id;

        INSERT INTO dbo.historial_reportes (reporte_id, accion_id, usuario_id, observacion)
        VALUES (@reporte_id, @accion_en_atencion, @usuario_id, NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_completar;
GO
CREATE PROCEDURE dbo.usp_reporte_completar
    @reporte_id     INT,
    @usuario_id     INT,
    @observacion    NVARCHAR(MAX),
    @evidencias_json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_usuario_tiene_rol(@usuario_id, N'ResponsableCuadrilla') = 0
        THROW 50004, N'No tienes permiso para completar reportes.', 1;

    DECLARE @estado NVARCHAR(20) = (
        SELECT e.nombre
        FROM dbo.reportes r
        JOIN dbo.estados_reporte e ON e.id = r.estado_id
        WHERE r.id = @reporte_id
    );
    IF @estado IS NULL
        THROW 50001, N'Reporte no encontrado.', 1;
    IF @estado <> N'En atención'
        THROW 50002, N'Solo se puede completar un reporte En atención.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.asignaciones_reporte a
        JOIN dbo.cuadrillas c ON c.id = a.cuadrilla_id
        WHERE a.reporte_id = @reporte_id
          AND a.fecha_fin IS NULL
          AND c.responsable_id = @usuario_id
    )
        THROW 50004, N'No tienes acceso a este reporte.', 1;

    IF @evidencias_json IS NOT NULL AND ISJSON(@evidencias_json) = 0
        THROW 50006, N'El JSON de evidencias no es válido.', 1;

    DECLARE @estado_atendido INT = (SELECT id FROM dbo.estados_reporte WHERE nombre = N'Atendido');
    DECLARE @accion_atendido INT = (SELECT id FROM dbo.acciones_historial WHERE nombre = N'Atendido con evidencias');
    DECLARE @orden_base INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @evidencias_json IS NOT NULL AND ISJSON(@evidencias_json) = 1
        BEGIN
            SET @orden_base = ISNULL((
                SELECT MAX(orden)
                FROM dbo.reporte_imagenes
                WHERE reporte_id = @reporte_id
                  AND tipo = N'Evidencia'
            ), 0);

            INSERT INTO dbo.reporte_imagenes (reporte_id, url, tipo, orden)
            SELECT
                @reporte_id,
                j.[value],
                N'Evidencia',
                @orden_base + ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            FROM OPENJSON(@evidencias_json) WITH ([value] NVARCHAR(MAX) '$') j
            WHERE j.[value] IS NOT NULL
              AND LEN(j.[value]) > 0;
        END

        UPDATE dbo.reportes
        SET estado_id = @estado_atendido
        WHERE id = @reporte_id;

        UPDATE dbo.asignaciones_reporte
        SET fecha_fin = SYSDATETIME()
        WHERE reporte_id = @reporte_id
          AND fecha_fin IS NULL;

        INSERT INTO dbo.historial_reportes (reporte_id, accion_id, usuario_id, observacion)
        VALUES (@reporte_id, @accion_atendido, @usuario_id, COALESCE(@observacion, N'Trabajo completado'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_historial;
GO
CREATE PROCEDURE dbo.usp_reporte_historial
    @reporte_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_historial WHERE reporte_id = @reporte_id ORDER BY fecha ASC, id ASC;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_reporte_obtener;
GO
CREATE PROCEDURE dbo.usp_reporte_obtener
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.*,
        COALESCE(
            (
                SELECT TOP (2147483647)
                    h.id,
                    CONVERT(VARCHAR(10), h.fecha, 23) AS fecha,
                    ac.nombre AS accion,
                    COALESCE(h.usuario_snapshot, hu.nombre, N'Sistema') AS usuario,
                    h.observacion
                FROM dbo.historial_reportes h
                JOIN dbo.acciones_historial ac ON ac.id = h.accion_id
                LEFT JOIN dbo.usuarios hu ON hu.id = h.usuario_id
                WHERE h.reporte_id = v.id
                ORDER BY h.fecha ASC, h.id ASC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ),
            '[]'
        ) AS historial
    FROM dbo.vw_reportes v
    WHERE v.id = @id;
END;
GO

-- ============================================================
-- ESTADÍSTICAS
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_estadisticas_resumen;
GO
CREATE PROCEDURE dbo.usp_estadisticas_resumen
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS total FROM dbo.reportes;

    SELECT e.nombre AS estado, COUNT(*) AS cantidad
    FROM dbo.reportes r
    JOIN dbo.estados_reporte e ON e.id = r.estado_id
    GROUP BY e.nombre
    ORDER BY e.nombre;

    SELECT d.nombre AS distrito, COUNT(*) AS cantidad
    FROM dbo.reportes r
    JOIN dbo.distritos d ON d.id = r.distrito_id
    GROUP BY d.nombre
    ORDER BY d.nombre;

    SELECT p.nombre AS prioridad, COUNT(*) AS cantidad
    FROM dbo.reportes r
    JOIN dbo.prioridades p
        ON r.puntaje_prioridad BETWEEN p.puntaje_min AND p.puntaje_max
    GROUP BY p.nombre
    ORDER BY p.nombre;
END;
GO

-- ============================================================
-- CONTACTO
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_contacto_crear;
GO
CREATE PROCEDURE dbo.usp_contacto_crear
    @codigo  NVARCHAR(20),
    @nombre  NVARCHAR(100),
    @email   NVARCHAR(150),
    @asunto  NVARCHAR(100),
    @mensaje NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigo  = LTRIM(RTRIM(@codigo));
    SET @nombre  = LTRIM(RTRIM(@nombre));
    SET @email   = LOWER(LTRIM(RTRIM(@email)));
    SET @asunto  = LTRIM(RTRIM(@asunto));
    SET @mensaje = LTRIM(RTRIM(@mensaje));

    IF @codigo IS NULL OR LEN(@codigo) = 0
        THROW 50006, N'El código es obligatorio.', 1;
    IF @nombre IS NULL OR LEN(@nombre) = 0
        THROW 50006, N'El nombre es obligatorio.', 1;
    IF @email IS NULL OR @email NOT LIKE N'%_@_%._%'
        THROW 50006, N'El correo electrónico no es válido.', 1;
    IF @asunto IS NULL OR LEN(@asunto) = 0
        THROW 50006, N'El asunto es obligatorio.', 1;
    IF @mensaje IS NULL OR LEN(@mensaje) = 0
        THROW 50006, N'El mensaje es obligatorio.', 1;

    INSERT INTO dbo.contactos (codigo, nombre, email, asunto, mensaje, fecha, leido)
    VALUES (@codigo, @nombre, @email, @asunto, @mensaje, SYSDATETIME(), 0);

    SELECT SCOPE_IDENTITY() AS id;
END;
GO

-- ============================================================
-- MAPA
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.usp_mapa_reportes;
GO
CREATE PROCEDURE dbo.usp_mapa_reportes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.id,
        v.titulo,
        v.descripcion,
        v.distrito,
        v.direccion,
        v.estado,
        v.prioridad,
        v.latitud,
        v.longitud,
        v.fecha,
        v.ciudadano_nombre AS ciudadano
    FROM dbo.vw_reportes v
    WHERE v.latitud IS NOT NULL
      AND v.longitud IS NOT NULL
      AND v.estado <> N'Rechazado'
    ORDER BY v.fecha DESC, v.id DESC;
END;
GO


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
