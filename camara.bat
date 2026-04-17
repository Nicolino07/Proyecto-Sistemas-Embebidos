@echo off
REM =============================================================================
REM Inicia el edge node (camara + reconocimiento facial) en Windows
REM Uso: doble clic en camara.bat, o ejecutar desde la terminal
REM =============================================================================

if not exist "venv\" (
    echo Primero ejecuta start.bat para instalar las dependencias.
    pause
    exit /b 1
)

cd edge_node
..\venv\Scripts\python capture.py
pause
