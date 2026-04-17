#!/bin/bash
# =============================================================================
# Script de inicio del sistema de reconocimiento facial.
# Uso: bash start.sh
# =============================================================================

# Instalar dependencias si el venv no existe todavía
if [ ! -d "venv" ]; then
    echo "Primera vez: instalando dependencias..."
    python3 -m venv venv
    venv/bin/pip install "setuptools<70" -q
    venv/bin/pip install -r server/requirements.txt -q
    venv/bin/pip install -r edge_node/requirements.txt -q
    venv/bin/pip install face-recognition --no-deps -q
    venv/bin/pip install git+https://github.com/ageitgey/face_recognition_models -q
    venv/bin/pip install "numpy<2" -q  # opencv y dlib requieren numpy<2
    echo "Dependencias instaladas."
fi

echo "Iniciando base de datos..."
docker compose up -d

echo "Esperando que la base de datos esté lista..."
sleep 3

echo "Iniciando servidor..."
venv/bin/python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
