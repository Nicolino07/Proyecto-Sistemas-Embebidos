#!/bin/bash
set -e

echo "=== Instalando dependencias del sistema ==="
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    python3-dev \
    python3-pip \
    python3-venv \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    libboost-python-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libatlas-base-dev \
    gfortran

echo ""
echo "=== Limpiando entorno si existe ==="
rm -rf venv

echo ""
echo "=== Creando entorno virtual ==="
python3 -m venv venv
source venv/bin/activate

echo ""
echo "=== Actualizando pip y herramientas de compilacion ==="
pip install --upgrade pip setuptools wheel

echo ""
echo "=== Instalando dependencias base ==="
pip install "numpy<2" requests

echo ""
echo "=== Instalando Pillow ==="
pip install --no-cache-dir Pillow

echo ""
echo "=== Instalando dlib desde piwheels (wheel ARM precompilado) ==="
pip install --no-cache-dir dlib --extra-index-url https://www.piwheels.org/simple --only-binary=dlib

echo ""
echo "=== Instalando face_recognition y opencv ==="
pip install --no-cache-dir face_recognition "opencv-python<4.10" --extra-index-url https://www.piwheels.org/simple

echo ""
echo "=== Verificando instalacion ==="
venv/bin/python <<EQF
import dlib
import face_recognition
import cv2
import requests
print('dlib version:', dlib.__version__)
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
