@echo off
REM =============================================================================
REM Script de inicio del sistema de reconocimiento facial (Windows)
REM Uso: doble clic en start.bat, o ejecutar desde la terminal
REM =============================================================================

REM Verificar que Docker esté corriendo
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker no esta corriendo. Abre Docker Desktop y volvé a intentar.
    pause
    exit /b 1
)

REM Instalar dependencias si el venv no existe todavía
if not exist "venv\" (
    echo Primera vez: instalando dependencias, esto puede tardar varios minutos...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Python no encontrado. Instala Python 3.11 desde https://www.python.org/downloads/
        pause
        exit /b 1
    )
    venv\Scripts\pip install cmake -q
    venv\Scripts\pip install "setuptools<70" -q
    venv\Scripts\pip install "numpy<2" -q
    venv\Scripts\pip install dlib-bin -q
    venv\Scripts\pip install "opencv-python<4.10" -q
    venv\Scripts\pip install face-recognition --no-deps -q
    venv\Scripts\pip install git+https://github.com/ageitgey/face_recognition_models -q
    venv\Scripts\pip install -r server\requirements.txt -q
    echo Dependencias instaladas.
)

echo Iniciando base de datos...
docker compose up -d

echo Esperando que la base de datos este lista...
timeout /t 4 /nobreak >nul

echo Iniciando servidor...
venv\Scripts\python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
