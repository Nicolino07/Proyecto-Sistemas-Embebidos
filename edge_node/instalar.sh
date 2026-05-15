#!/bin/bash
set -e

echo "=== Instalando dependencias del sistema ==="
sudo apt update
sudo apt install -y \
    python3-dev \
    python3-pip \
    python3-venv \
    libgl1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libgtk2.0-0

echo ""
echo "=== Limpiando entorno si existe ==="
rm -rf venv

echo ""
echo "=== Creando entorno virtual ==="
python3 -m venv venv
source venv/bin/activate

echo ""
echo "=== Actualizando pip ==="
pip install --upgrade pip setuptools wheel

echo ""
echo "=== Instalando dependencias ==="
pip install --no-cache-dir "numpy<2" requests Pillow

echo ""
echo "=== Instalando onnxruntime ==="
pip install --no-cache-dir onnxruntime

echo ""
echo "=== Instalando insightface ==="
pip install --no-cache-dir insightface

echo ""
echo "=== Instalando opencv con soporte de display (piwheels) ==="
pip install --force-reinstall --no-cache-dir opencv-python --extra-index-url https://www.piwheels.org/simple

echo ""
echo "=== Instalando gpiozero (control de GPIO / LED) ==="
pip install --no-cache-dir gpiozero

echo ""
echo "=== Descargando modelo de reconocimiento facial (buffalo_sc) ==="
venv/bin/python -c "
from insightface.app import FaceAnalysis
app = FaceAnalysis(name='buffalo_sc', providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(320, 320))
print('Modelo descargado correctamente.')
"

echo ""
echo "=== Verificando instalacion ==="
venv/bin/python <<EQF
import insightface
import cv2
import requests
import numpy as np
print('insightface version:', insightface.__version__)
print('Todo instalado correctamente!')
EQF

echo ""
echo "=== Configurando IP del servidor ==="
read -rp "IP del servidor (ej: 192.168.1.100): " SERVER_IP
if [ -z "$SERVER_IP" ]; then
    echo "Advertencia: no se ingresó IP. Editá .env manualmente antes de iniciar."
else
    echo "SERVER_URL=http://${SERVER_IP}:8001" > "$(dirname "$0")/.env"
    echo "IP guardada en .env"
fi

echo ""
echo "=== Listo! Para correr el sistema: ==="
echo "    source venv/bin/activate && python capture.py"
