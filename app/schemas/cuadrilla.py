from typing import Optional

from pydantic import BaseModel, Field


class CuadrillaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    responsable: Optional[str] = Field(default=None, max_length=100)
    distrito: str = Field(min_length=1, max_length=50)
    zona_asignada: Optional[str] = Field(default=None, max_length=200)
    responsable_id: Optional[int] = None


class CuadrillaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    responsable: Optional[str] = Field(default=None, max_length=100)
    distrito: Optional[str] = Field(default=None, max_length=50)
    zona_asignada: Optional[str] = Field(default=None, max_length=200)
    responsable_id: Optional[int] = None
