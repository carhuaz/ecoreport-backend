from pydantic import BaseModel


class ContactoRequest(BaseModel):
    nombre: str
    email: str
    asunto: str
    mensaje: str
