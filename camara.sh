#!/bin/bash
# =============================================================================
# Inicia el edge node (cámara + reconocimiento facial).
# Uso: bash camara.sh
# =============================================================================

cd "$(dirname "$0")"

if [ ! -d "venv" ]; then
    echo "Primero ejecutá bash start.sh para instalar las dependencias."
    exit 1
fi

cd edge_node
../venv/bin/python capture.py
