#!/bin/bash
set -e

echo "=== Instalando dependencias del sistema ==="
sudo apt update
sudo apt install -y \
    cmake \
    python3-pip \
    python3-venv \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    libboost-python-dev \
    python3-opencv

echo ""
echo "=== Creando entorno virtual ==="
python3 -m venv venv
source venv/bin/activate

echo ""
echo "=== Instalando numpy y requests ==="
pip install "numpy<2" requests

echo ""
echo "=== Compilando dlib (tarda ~20 minutos, no interrumpir) ==="
pip install dlib

echo ""
echo "=== Instalando face_recognition y opencv ==="
pip install face_recognition "opencv-python<4.10"

echo ""
echo "=== Verificando instalacion ==="
python -c "import face_recognition; import cv2; import requests; print('Todo instalado correctamente!')"

echo ""
echo "=== Listo! Para correr el sistema: ==="
echo "    source venv/bin/activate"
echo "    python capture.py"
