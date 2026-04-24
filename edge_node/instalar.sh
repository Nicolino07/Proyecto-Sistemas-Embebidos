#!/bin/bash
set -e

echo "=== Instalando dependencias del sistema ==="
sudo apt update
sudo apt install -y \
    cmake \
    python3-pip \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    python3-opencv

echo ""
echo "=== Instalando dependencias Python ==="
echo "Esto puede tardar ~20 minutos porque compila dlib desde el codigo fuente..."
pip3 install --break-system-packages -r requirements.txt

echo ""
echo "=== Verificando instalacion ==="
python3 -c "import face_recognition; import cv2; import requests; print('Todo instalado correctamente!')"

echo ""
echo "=== Listo! Para correr el sistema: ==="
echo "    python3 capture.py"
