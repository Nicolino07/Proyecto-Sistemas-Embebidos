#!/bin/bash
# =============================================================================
# Script de inicio del servidor (API + base de datos + cámara local).
# Uso: bash start.sh
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
echo "  Sistema de Reconocimiento Facial - Servidor"
echo "================================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Seleccionar Python
# Preferimos 3.11 o 3.12 porque tienen wheels precompilados para dlib
# (sin necesidad de compilar). Con versiones más nuevas se compila desde cero.
# -----------------------------------------------------------------------------
echo "Buscando Python compatible..."
PYTHON_BIN=""
for ver in 3.11 3.12 3.10 3.13 3.9; do
    if command -v "python${ver}" &>/dev/null; then
        PYTHON_BIN="python${ver}"
        PYTHON_VERSION="$ver"
        break
    fi
done
if [ -z "$PYTHON_BIN" ]; then
    PYTHON_BIN="python3"
    PYTHON_VERSION=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
fi
ok "Usando Python $PYTHON_VERSION ($PYTHON_BIN)."

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
# 4. Instalar dependencias de cámara (solo la primera vez)
# -----------------------------------------------------------------------------
if [ ! -d "venv" ]; then
    echo ""
    echo "Instalando dependencias de cámara (primera vez, puede tardar ~10 min)..."

    # python-venv
    if ! "$PYTHON_BIN" -c "import ensurepip" &>/dev/null; then
        warn "Instalando python${PYTHON_VERSION}-venv..."
        sudo apt install -y "python${PYTHON_VERSION}-venv" \
            || fail "No se pudo instalar python${PYTHON_VERSION}-venv."
    fi

    # headers de Python (necesarios para compilar dlib si no hay wheel)
    if ! "$PYTHON_BIN" -c "import sysconfig; open(sysconfig.get_path('include') + '/Python.h')" &>/dev/null; then
        warn "Instalando python${PYTHON_VERSION}-dev y cmake..."
        sudo apt install -y "python${PYTHON_VERSION}-dev" cmake build-essential \
            || fail "No se pudieron instalar las herramientas de compilación."
    fi

    "$PYTHON_BIN" -m venv venv \
        || fail "No se pudo crear el entorno virtual."

    venv/bin/pip install --upgrade pip \
        || fail "No se pudo actualizar pip."

    venv/bin/pip install "setuptools<71" \
        || fail "No se pudo instalar setuptools."

    echo "Instalando dependencias (esto puede tardar si dlib se compila)..."
    venv/bin/pip install --no-cache-dir -r edge_node/requirements.txt \
        || fail "Error instalando dependencias."

    # Verificar que todo quedó instalado
    venv/bin/python -c "import face_recognition, cv2, numpy, requests" \
        || fail "La instalación no quedó completa. Revisá los errores de arriba."

    ok "Dependencias instaladas correctamente."
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
echo "  Nodos activos: http://localhost:8000/nodos"
echo "  Cámara local:  bash camara.sh"
echo "================================================"
