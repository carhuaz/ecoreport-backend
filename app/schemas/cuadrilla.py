from typing import Optional

from pydantic import BaseModel


class CuadrillaCreate(BaseModel):
    nombre: str
    responsable: str
    distrito: str
    zona_asignada: Optional[str] = None
    responsable_id: Optional[int] = None


class CuadrillaUpdate(BaseModel):
    nombre: Optional[str] = None
    responsable: Optional[str] = None
    distrito: Optional[str] = None
    zona_asignada: Optional[str] = None
    estado: Optional[str] = None
    responsable_id: Optional[int] = None
