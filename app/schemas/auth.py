from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RegisterRequest(BaseModel):
    nombre: str
    email: EmailStr
    password: str
    dni: str


class AuthResponse(BaseModel):
    id: int
    nombre: str
    email: str
    rol: str
    activo: bool
    token: str


class VerifyRequest(BaseModel):
    email: EmailStr
    codigo: str
