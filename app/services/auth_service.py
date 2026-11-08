from fastapi import BackgroundTasks, HTTPException

from ..config import OTP_MAX_ATTEMPTS, OTP_RESEND_COOLDOWN_SECONDS
from ..email_service import disparar_verificacion, generar_otp
from ..middleware.auth import create_access_token, hash_password, verify_password
from ..repositories import auth_repo
from ..schemas.auth import AuthResponse, LoginRequest, RegisterRequest, VerifyRequest
from .errors import manejar_errores_bd


def login(req: LoginRequest) -> AuthResponse:
    email = req.email.strip().lower()
    with manejar_errores_bd():
        user = auth_repo.login(email)

    if not user or not verify_password(req.password, user["password"]):
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    if not user["activo"]:
        raise HTTPException(status_code=403, detail="Usuario desactivado")
    if not user["esta_verificado"]:
        raise HTTPException(
            status_code=403,
            detail="Cuenta no verificada. Revisa tu correo para el código OTP.",
        )

    token = create_access_token({"id": user["id"], "rol": user["rol"]})
    return AuthResponse(
        id=user["id"],
        nombre=user["nombre"],
        email=user["email"],
        rol=user["rol"],
        activo=user["activo"],
        token=token,
    )


def register(req: RegisterRequest, background_tasks: BackgroundTasks) -> dict:
    email = req.email.strip().lower()
    nombre = req.nombre.strip()

    with manejar_errores_bd():
        existente = auth_repo.obtener_por_email(email)

    if existente:
        if existente["esta_verificado"]:
            raise HTTPException(
                status_code=400,
                detail="El email ya está registrado y verificado",
            )
        segundos = existente.get("segundos_desde_envio")
        if segundos is not None and segundos < OTP_RESEND_COOLDOWN_SECONDS:
            restantes = OTP_RESEND_COOLDOWN_SECONDS - int(segundos)
            raise HTTPException(
                status_code=429,
                detail=f"Espera {restantes} segundos antes de solicitar otro código.",
            )

    codigo = generar_otp()

    with manejar_errores_bd():
        user_id = auth_repo.registrar(
            nombre,
            email,
            hash_password(req.password),
            req.dni.strip(),
            hash_password(codigo),
        )

    disparar_verificacion(background_tasks, nombre, email, codigo)
    return {
        "mensaje": (
            "Usuario registrado. Revisa tu correo para verificar tu cuenta "
            "con el código enviado."
        ),
        "id": user_id,
    }


def verify(req: VerifyRequest) -> dict:
    email = req.email.strip().lower()
    with manejar_errores_bd():
        user = auth_repo.obtener_por_email(email)

    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if not user["activo"]:
        raise HTTPException(status_code=403, detail="Usuario desactivado")
    if user["esta_verificado"]:
        raise HTTPException(status_code=400, detail="La cuenta ya está verificada")
    if user["intentos_verificacion"] >= OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail="Demasiados intentos fallidos. Solicita un nuevo código.",
        )
    if not user["codigo_verificacion"]:
        raise HTTPException(
            status_code=400,
            detail="No hay código pendiente. Solicita uno nuevo.",
        )
    if user["codigo_expirado"]:
        raise HTTPException(
            status_code=400,
            detail="El código expiró. Solicita uno nuevo.",
        )
    if not verify_password(req.codigo.strip(), user["codigo_verificacion"]):
        with manejar_errores_bd():
            intentos = auth_repo.registrar_intento_fallido(user["id"])
        if intentos >= OTP_MAX_ATTEMPTS:
            raise HTTPException(
                status_code=429,
                detail="Demasiados intentos fallidos. Solicita un nuevo código.",
            )
        restantes = OTP_MAX_ATTEMPTS - intentos
        raise HTTPException(
            status_code=400,
            detail=f"Código incorrecto. Te quedan {restantes} intentos.",
        )

    with manejar_errores_bd():
        auth_repo.marcar_verificado(user["id"])

    return {"mensaje": "Cuenta verificada exitosamente. Ya puedes iniciar sesión."}


def reenviar_codigo(req: VerifyRequest, background_tasks: BackgroundTasks) -> dict:
    email = req.email.strip().lower()
    with manejar_errores_bd():
        user = auth_repo.obtener_por_email(email)

    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if not user["activo"]:
        raise HTTPException(status_code=403, detail="Usuario desactivado")
    if user["esta_verificado"]:
        raise HTTPException(status_code=400, detail="La cuenta ya está verificada")

    segundos = user.get("segundos_desde_envio")
    if segundos is not None and segundos < OTP_RESEND_COOLDOWN_SECONDS:
        restantes = OTP_RESEND_COOLDOWN_SECONDS - int(segundos)
        raise HTTPException(
            status_code=429,
            detail=f"Espera {restantes} segundos antes de solicitar otro código.",
        )

    codigo = generar_otp()
    with manejar_errores_bd():
        auth_repo.guardar_codigo(user["id"], hash_password(codigo))

    disparar_verificacion(background_tasks, user["nombre"], email, codigo)
    return {"mensaje": "Código reenviado. Revisa tu correo."}


def me(user_id: int) -> dict:
    with manejar_errores_bd():
        user = auth_repo.me(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if not user.get("activo"):
        raise HTTPException(status_code=403, detail="Usuario desactivado")
    return user
