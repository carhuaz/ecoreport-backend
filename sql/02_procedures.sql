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
    @nombre              NVARCHAR(100),
    @email               NVARCHAR(150),
    @password_hash       NVARCHAR(255),
    @dni                 NVARCHAR(8),
    @codigo_hash         NVARCHAR(60),
    @codigo_expira_minutos INT = 10
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
                codigo_expira = DATEADD(MINUTE, @codigo_expira_minutos, SYSDATETIME()),
                intentos_verificacion = 0,
                ultimo_envio_codigo = SYSDATETIME(),
                esta_verificado = 0
            WHERE id = @id;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.usuarios
                (nombre, email, password, dni, rol_id, activo, codigo_verificacion,
                 codigo_expira, intentos_verificacion, ultimo_envio_codigo, esta_verificado)
            VALUES
                (@nombre, @email, @password_hash, @dni, @rol_ciudadano, 1, @codigo_hash,
                 DATEADD(MINUTE, @codigo_expira_minutos, SYSDATETIME()), 0, SYSDATETIME(), 0);

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
        u.codigo_expira,
        u.intentos_verificacion,
        u.ultimo_envio_codigo,
        CASE
            WHEN u.codigo_expira IS NULL OR u.codigo_expira < SYSDATETIME() THEN 1
            ELSE 0
        END AS codigo_expirado,
        DATEDIFF(SECOND, u.ultimo_envio_codigo, SYSDATETIME()) AS segundos_desde_envio,
        u.esta_verificado,
        u.activo,
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
        codigo_verificacion = NULL,
        codigo_expira = NULL,
        intentos_verificacion = 0
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_guardar_codigo;
GO
CREATE PROCEDURE dbo.usp_auth_guardar_codigo
    @id                    INT,
    @codigo_hash           NVARCHAR(60),
    @codigo_expira_minutos INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.usuarios
    SET codigo_verificacion = @codigo_hash,
        codigo_expira = DATEADD(MINUTE, @codigo_expira_minutos, SYSDATETIME()),
        intentos_verificacion = 0,
        ultimo_envio_codigo = SYSDATETIME()
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT 1 AS ok;
END;
GO

DROP PROCEDURE IF EXISTS dbo.usp_auth_registrar_intento_fallido;
GO
CREATE PROCEDURE dbo.usp_auth_registrar_intento_fallido
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.usuarios
    SET intentos_verificacion = intentos_verificacion + 1
    WHERE id = @id;

    IF @@ROWCOUNT = 0
        THROW 50001, N'Usuario no encontrado.', 1;

    SELECT intentos_verificacion
    FROM dbo.usuarios
    WHERE id = @id;
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

    IF @page < 1 OR @page_size < 1 OR @page_size > 200
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

    IF @page < 1 OR @page_size < 1 OR @page_size > 200
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
