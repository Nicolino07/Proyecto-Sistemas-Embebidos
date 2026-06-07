FROM python:3.11-slim

# Dependencias del sistema requeridas por OpenCV e insightface
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-descarga el modelo de reconocimiento facial para que el primer
# arranque no tarde. El modelo queda cacheado en la imagen Docker.
RUN python -c "\
from insightface.app import FaceAnalysis; \
app = FaceAnalysis(name='buffalo_sc', providers=['CPUExecutionProvider']); \
app.prepare(ctx_id=0, det_size=(320, 320))"

COPY server/ ./server
COPY frontend/dist/ ./frontend/dist/

CMD ["uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
