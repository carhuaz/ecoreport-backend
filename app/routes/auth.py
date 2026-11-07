import re
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from ..database import fetch_one, execute, execute_returning_id
from ..schemas.auth import LoginRequest, RegisterRequest, AuthResponse, VerifyRequest
from ..middleware.auth import hash_password, verify_password, create_access_token, get_current_user_id
from ..email_service import generar_otp, disparar_verificacion

router = APIRouter(prefix="/api/auth", tags=["Auth"])


@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest):
    user = fetch_one(
        "SELECT id, nombre, email, password, rol, activo, esta_verificado FROM usuarios WHERE email = ?",
        (req.email.strip().lower(),)
    )
    if not user or not verify_password(req.password, user["password"]):
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    if not user["activo"]:
        raise HTTPException(status_code=403, detail="Usuario desactivado")
    if not user["esta_verificado"]:
        raise HTTPException(status_code=403, detail="Cuenta no verificada. Revisa tu correo para el código OTP.")

    token = create_access_token({"id": user["id"], "rol": user["rol"]})
    return AuthResponse(
        id=user["id"],
        nombre=user["nombre"],
        email=user["email"],
        rol=user["rol"],
        activo=user["activo"],
        token=token
    )


@router.post("/register")
def register(req: RegisterRequest, background_tasks: BackgroundTasks):
    email = req.email.strip().lower()

    if not re.match(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', email):
        raise HTTPException(status_code=400, detail="Formato de correo electrónico inválido")

    existente = fetch_one("SELECT id, esta_verificado FROM usuarios WHERE email = ?", (email,))
    if existente:
        if existente["esta_verificado"]:
            raise HTTPException(status_code=400, detail="El email ya está registrado y verificado")
        # Si nunca verificó, permitimos re-registrar (eliminamos cuenta vieja)
        execute("DELETE FROM usuarios WHERE id = ?", (existente["id"],))

    if not req.dni or len(req.dni) != 8 or not req.dni.isdigit():
        raise HTTPException(status_code=400, detail="El DNI debe tener 8 dígitos numéricos")

    if fetch_one("SELECT id FROM usuarios WHERE dni = ?", (req.dni,)):
        raise HTTPException(status_code=400, detail="El DNI ya está registrado")

    hashed = hash_password(req.password)
    codigo = generar_otp()

    user_id = execute_returning_id(
        "INSERT INTO usuarios (nombre, email, password, dni, rol, activo, codigo_verificacion, esta_verificado) OUTPUT INSERTED.id VALUES (?, ?, ?, ?, 'Ciudadano', 1, ?, 0)",
        (req.nombre.strip(), email, hashed, req.dni, hash_password(codigo))
    )

    disparar_verificacion(background_tasks, req.nombre.strip(), email, codigo)

    return {"mensaje": "Usuario registrado. Revisa tu correo para verificar tu cuenta con el código enviado.", "id": user_id}


@router.post("/verify")
def verify(req: VerifyRequest):
    email = req.email.strip().lower()

    user = fetch_one(
        "SELECT id, codigo_verificacion, esta_verificado FROM usuarios WHERE email = ?",
        (email,)
    )
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if user["esta_verificado"]:
        raise HTTPException(status_code=400, detail="La cuenta ya está verificada")
    if not user["codigo_verificacion"]:
        raise HTTPException(status_code=400, detail="No hay código pendiente. Solicita uno nuevo.")

    if not verify_password(req.codigo.strip(), user["codigo_verificacion"]):
        raise HTTPException(status_code=400, detail="Código incorrecto")

    execute(
        "UPDATE usuarios SET esta_verificado = 1, codigo_verificacion = NULL WHERE id = ?",
        (user["id"],)
    )

    return {"mensaje": "Cuenta verificada exitosamente. Ya puedes iniciar sesión."}


@router.post("/reenviar-codigo")
def reenviar_codigo(req: VerifyRequest, background_tasks: BackgroundTasks):
    """Reenvía el código OTP al email si la cuenta no está verificada."""
    email = req.email.strip().lower()
    user = fetch_one(
        "SELECT id, nombre, esta_verificado FROM usuarios WHERE email = ?",
        (email,)
    )
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if user["esta_verificado"]:
        raise HTTPException(status_code=400, detail="La cuenta ya está verificada")

    codigo = generar_otp()
    execute(
        "UPDATE usuarios SET codigo_verificacion = ? WHERE id = ?",
        (hash_password(codigo), user["id"])
    )
    disparar_verificacion(background_tasks, user["nombre"], email, codigo)
    return {"mensaje": "Código reenviado. Revisa tu correo."}


@router.get("/me")
def get_me(user_id: int = Depends(get_current_user_id)):
    user = fetch_one(
        "SELECT id, nombre, email, dni, rol, activo, FORMAT(fecha_registro, 'yyyy-MM-dd') as fecha_registro FROM usuarios WHERE id = ?",
        (user_id,)
    )
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user
