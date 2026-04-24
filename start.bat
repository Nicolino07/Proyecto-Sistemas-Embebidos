@echo off
REM =============================================================================
REM Instalador y script de inicio del sistema de reconocimiento facial (Windows)
REM Uso: doble clic en start.bat, o ejecutar desde la terminal
REM Compatible con Windows 10/11 de 64 bits con Docker Desktop.
REM =============================================================================

echo ================================================
echo   Sistema de Reconocimiento Facial - Instalador
echo ================================================
echo.

REM -----------------------------------------------------------------------------
REM 1. Verificar Python
REM -----------------------------------------------------------------------------
echo Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no encontrado. Instalalo desde https://www.python.org/downloads/
    echo         Asegurate de tildar "Add Python to PATH" durante la instalacion.
    pause
    exit /b 1
)
echo [OK] Python encontrado.

REM -----------------------------------------------------------------------------
REM 2. Verificar Docker
REM -----------------------------------------------------------------------------
echo Verificando Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker no esta corriendo o no esta instalado.
    echo         Abre Docker Desktop y esperá a que termine de iniciar.
    echo         Si no lo tenes, descargalo desde https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo [OK] Docker disponible.

REM -----------------------------------------------------------------------------
REM 3. Verificar docker compose
REM -----------------------------------------------------------------------------
echo Verificando docker compose...
docker compose version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] docker compose no encontrado. Actualizá Docker Desktop a una version reciente.
    pause
    exit /b 1
)
echo [OK] docker compose disponible.

REM -----------------------------------------------------------------------------
REM 4. Instalar dependencias del edge node (solo la primera vez)
REM -----------------------------------------------------------------------------
if not exist "venv\" (
    echo.
    echo Primera vez: instalando dependencias del edge node...
    echo [AVISO] Esto puede tardar varios minutos.

    python -m venv venv
    if errorlevel 1 (
        echo [ERROR] No se pudo crear el entorno virtual.
        pause
        exit /b 1
    )

    venv\Scripts\pip install --upgrade pip -q
    if errorlevel 1 ( echo [ERROR] No se pudo actualizar pip. & pause & exit /b 1 )

    venv\Scripts\pip install "setuptools<70" -q
    if errorlevel 1 ( echo [ERROR] Error instalando setuptools. & pause & exit /b 1 )

    venv\Scripts\pip install cmake -q
    if errorlevel 1 ( echo [ERROR] Error instalando cmake. & pause & exit /b 1 )

    venv\Scripts\pip install "numpy<2" -q
    if errorlevel 1 ( echo [ERROR] Error instalando numpy. & pause & exit /b 1 )

    venv\Scripts\pip install dlib-bin -q
    if errorlevel 1 ( echo [ERROR] Error instalando dlib-bin. & pause & exit /b 1 )

    venv\Scripts\pip install "opencv-python<4.10" -q
    if errorlevel 1 ( echo [ERROR] Error instalando opencv-python. & pause & exit /b 1 )

    venv\Scripts\pip install Pillow -q
    if errorlevel 1 ( echo [ERROR] Error instalando Pillow. & pause & exit /b 1 )

    venv\Scripts\pip install face-recognition --no-deps -q
    if errorlevel 1 ( echo [ERROR] Error instalando face-recognition. & pause & exit /b 1 )

    venv\Scripts\pip install git+https://github.com/ageitgey/face_recognition_models -q
    if errorlevel 1 ( echo [ERROR] Error descargando face_recognition_models. Verificá tu conexion a internet. & pause & exit /b 1 )

    venv\Scripts\pip install requests psycopg2-binary -q
    if errorlevel 1 ( echo [ERROR] Error instalando requests/psycopg2. & pause & exit /b 1 )

    echo [OK] Dependencias del edge node instaladas.
) else (
    echo [OK] Dependencias ya instaladas ^(venv existente^).
)

REM -----------------------------------------------------------------------------
REM 5. Levantar base de datos y servidor via Docker
REM -----------------------------------------------------------------------------
echo.
echo Iniciando base de datos y servidor API...
docker compose up -d --build
if errorlevel 1 (
    echo [ERROR] Error al levantar los contenedores Docker. Revisá el docker-compose.yml.
    pause
    exit /b 1
)

REM -----------------------------------------------------------------------------
REM 6. Esperar a que la base de datos esté lista
REM -----------------------------------------------------------------------------
echo Esperando que la base de datos este lista...
set RETRIES=15
:wait_db
docker exec facial_db pg_isready -U admin -d facial_recognition >nul 2>&1
if errorlevel 1 (
    set /a RETRIES-=1
    if %RETRIES% leq 0 (
        echo [ERROR] La base de datos no respondio a tiempo. Revisa los logs con: docker logs facial_db
        pause
        exit /b 1
    )
    timeout /t 2 /nobreak >nul
    goto wait_db
)
echo [OK] Base de datos lista.

REM -----------------------------------------------------------------------------
REM 7. Listo
REM -----------------------------------------------------------------------------
echo.
echo ================================================
echo [OK] Sistema listo.
echo.
echo   API / Swagger: http://localhost:8000/docs
echo   Camara:        ejecuta camara.bat
echo ================================================
pause
