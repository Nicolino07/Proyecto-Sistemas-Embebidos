#!/bin/bash
# =============================================================================
# Inicia el edge node (cámara + reconocimiento facial).
# Uso: bash camara.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Primero ejecutá bash start.sh para instalar las dependencias."
    exit 1
fi

# En el server la API corre localmente, el .env apunta siempre a localhost
if [ ! -f "$SCRIPT_DIR/edge_node/.env" ]; then
    echo "SERVER_URL=http://localhost:8001" > "$SCRIPT_DIR/edge_node/.env"
fi

cd "$SCRIPT_DIR/edge_node"
"$SCRIPT_DIR/venv/bin/python" capture.py
