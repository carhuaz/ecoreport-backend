FROM python:3.12-slim

# Evitar generación de archivos .pyc y habilitar salida de logs en tiempo real
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Instalar paquetes básicos de compilación
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gcc \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copiar archivos de dependencias
COPY pyproject.toml uv.lock ./

# Instalar uv e instalar las dependencias en .venv
RUN pip install --no-cache-dir uv && \
    uv sync --frozen --no-dev

# Activar el entorno virtual en el PATH
ENV PATH="/app/.venv/bin:$PATH"

# Copiar el código fuente de la aplicación
COPY main.py ./
COPY app/ ./app/
COPY sql/ ./sql/

# Render asigna dinámicamente la variable PORT
ENV PORT=8000
EXPOSE ${PORT}

# Ejecutar la aplicación con Uvicorn en el host 0.0.0.0 y el puerto dinámico
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
