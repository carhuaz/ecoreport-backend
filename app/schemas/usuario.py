from pydantic import BaseModel


class CambiarRolRequest(BaseModel):
    rol: str
