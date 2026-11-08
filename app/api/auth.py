from fastapi import APIRouter, BackgroundTasks, Depends

from ..middleware.auth import get_current_user_id
from ..schemas.auth import AuthResponse, LoginRequest, RegisterRequest, VerifyRequest
from ..services import auth_service

router = APIRouter(prefix="/api/auth", tags=["Auth"])


@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest):
    return auth_service.login(req)


@router.post("/register")
def register(req: RegisterRequest, background_tasks: BackgroundTasks):
    return auth_service.register(req, background_tasks)


@router.post("/verify")
def verify(req: VerifyRequest):
    return auth_service.verify(req)


@router.post("/reenviar-codigo")
def reenviar_codigo(req: VerifyRequest, background_tasks: BackgroundTasks):
    return auth_service.reenviar_codigo(req, background_tasks)


@router.get("/me")
def get_me(user_id: int = Depends(get_current_user_id)):
    return auth_service.me(user_id)
