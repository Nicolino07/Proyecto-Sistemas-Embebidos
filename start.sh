#!/bin/bash
# =============================================================================
# Instalador y script de inicio del sistema de reconocimiento facial.
# Uso: bash start.sh
# Compatible con Linux/Debian y Raspberry Pi OS.
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "================================================"
echo "  Sistema de Reconocimiento Facial - Instalador"
echo "================================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Verificar Python 3
# -----------------------------------------------------------------------------
echo "Verificando Python 3..."
if ! command -v python3 &>/dev/null; then
    fail "Python 3 no encontrado. Instalalo con: sudo apt install python3 python3-venv python3-pip"
fi
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
ok "Python $PYTHON_VERSION encontrado."

# -----------------------------------------------------------------------------
# 2. Verificar Docker
# -----------------------------------------------------------------------------
echo "Verificando Docker..."
if ! command -v docker &>/dev/null; then
    fail "Docker no encontrado. Instalalo desde https://docs.docker.com/engine/install/"
fi
if ! docker info &>/dev/null; then
    fail "Docker no está corriendo. Iniciá el servicio con: sudo systemctl start docker"
fi
ok "Docker disponible."

# -----------------------------------------------------------------------------
# 3. Verificar docker compose
# -----------------------------------------------------------------------------
echo "Verificando docker compose..."
if ! docker compose version &>/dev/null; then
    fail "docker compose no encontrado. Actualizá Docker a una versión reciente."
fi
ok "docker compose disponible."

# -----------------------------------------------------------------------------
# 4. Instalar dependencias del edge node (solo la primera vez)
# -----------------------------------------------------------------------------
if [ ! -d "venv" ]; then
    echo ""
    echo "Primera vez: instalando dependencias del edge node..."
    warn "Esto puede tardar varios minutos."

    python3 -m venv venv \
        || fail "No se pudo crear el entorno virtual. Instalá python3-venv con: sudo apt install python3-venv"

    venv/bin/pip install --upgrade pip -q \
        || fail "No se pudo actualizar pip."

    venv/bin/pip install "setuptools<70" -q \
        || fail "Error instalando setuptools."

    venv/bin/pip install -r edge_node/requirements.txt -q \
        || fail "Error instalando dependencias del edge node (requirements.txt)."

    venv/bin/pip install Pillow -q \
        || fail "Error instalando Pillow."

    venv/bin/pip install face-recognition --no-deps -q \
        || fail "Error instalando face-recognition."

    venv/bin/pip install git+https://github.com/ageitgey/face_recognition_models -q \
        || fail "Error descargando face_recognition_models. Verificá tu conexión a internet."

    ok "Dependencias del edge node instaladas."
else
    ok "Dependencias ya instaladas (venv existente)."
fi

# -----------------------------------------------------------------------------
# 5. Levantar base de datos y servidor via Docker
# -----------------------------------------------------------------------------
echo ""
echo "Iniciando base de datos y servidor API..."
docker compose up -d --build \
    || fail "Error al levantar los contenedores Docker. Revisá el docker-compose.yml."

# -----------------------------------------------------------------------------
# 6. Esperar a que la base de datos esté lista
# -----------------------------------------------------------------------------
echo "Esperando que la base de datos esté lista..."
RETRIES=15
until docker exec facial_db pg_isready -U admin -d facial_recognition &>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -le 0 ]; then
        fail "La base de datos no respondió a tiempo. Revisá los logs con: docker logs facial_db"
    fi
    sleep 2
done
ok "Base de datos lista."

# -----------------------------------------------------------------------------
# 7. Listo
# -----------------------------------------------------------------------------
echo ""
echo "================================================"
ok "Sistema listo."
echo ""
echo "  API / Swagger: http://localhost:8000/docs"
echo "  Cámara:        bash camara.sh"
echo "================================================"
