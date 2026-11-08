import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import auth, contacto, cuadrillas, estadisticas, reportes, usuarios

app = FastAPI(
    title="EcoReport API",
    description="API REST para el sistema de reportes ambientales",
    version="1.0.0"
)

cors_origins = [
    origen.strip()
    for origen in os.getenv("CORS_ORIGINS", "http://localhost:4200").split(",")
    if origen.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(reportes.router)
app.include_router(usuarios.router)
app.include_router(cuadrillas.router)
app.include_router(estadisticas.router)
app.include_router(contacto.router)


@app.get("/api/health")
def health():
    return {"status": "ok", "app": "EcoReport API"}
