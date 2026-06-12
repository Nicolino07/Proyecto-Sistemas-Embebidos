# =============================================================================
# install.ps1 - Script de instalacion del Sistema de Reconocimiento Facial
# Llamado por Inno Setup durante la instalacion.
# Requiere: Windows 10/11 x64, conexion a internet, permisos de administrador.
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppDir
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # acelera Invoke-WebRequest

$LOG = "$AppDir\install.log"

function Log {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg"
    Add-Content -Path $LOG -Value $line -Encoding UTF8
    Write-Host $line
}

function Die {
    param([string]$Msg)
    Log $Msg "ERROR"
    [System.Windows.Forms.MessageBox]::Show(
        "Error durante la instalacion:`n`n$Msg`n`nRevisa el log en:`n$LOG",
        "Error de Instalacion",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

function Download {
    param([string]$Url, [string]$Dest, [string]$Desc)
    Log "Descargando $Desc..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
    } catch {
        Die "No se pudo descargar $Desc desde:`n$Url`n`nVerifica tu conexion a internet."
    }
    Log "OK: $Desc descargado."
}

Add-Type -AssemblyName System.Windows.Forms | Out-Null

Log "=== INICIO DE INSTALACION ==="
Log "Directorio de instalacion: $AppDir"

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────────────────────────────────────────
$PYTHON_VERSION  = "3.11.9"
$PG_VERSION      = "16"
$PG_FULL_VERSION = "16.4-1"
$PGVECTOR_VER    = "0.8.0"

$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION-amd64.exe"
# PostgreSQL portable binaries — URL estable de EnterpriseDB
# Si falla, actualizá PG_FULL_VERSION con la version mas reciente de:
# https://www.enterprisedb.com/download-postgresql-binaries
$PG_URL     = "https://get.enterprisedb.com/postgresql/postgresql-$PG_FULL_VERSION-windows-x64-binaries.zip"
$PGVEC_URL  = "https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/$PGVECTOR_VER`_$PG_VERSION/vector.v$PGVECTOR_VER-pg$PG_VERSION.zip"

$PG_DIR     = "$AppDir\pgsql"          # binarios de PostgreSQL
$PG_DATA    = "$AppDir\pgsql_data"     # cluster de datos
$PG_PORT    = 5432
$PG_SVC     = "SisRecFacial_DB"        # nombre del servicio Windows para Postgres
$API_SVC    = "SisRecFacial_API"       # nombre del servicio Windows para FastAPI

$DB_NAME    = "facial_recognition"
$DB_USER    = "admin"
$DB_PASS    = "admin123"

$PGBIN      = "$PG_DIR\bin"
$env:PGPASSWORD = $DB_PASS

# ─────────────────────────────────────────────────────────────────────────────
# 1. PYTHON
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 1: Python ---"

$pythonExe = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"
$pythonOk  = $false

# Buscar Python 3.11 ya instalado
foreach ($path in @($pythonExe, "python", "python3", "python3.11")) {
    try {
        $v = & $path --version 2>&1
        if ($v -match "Python 3\.11") { $pythonOk = $true; $pythonExe = $path; Log "Python 3.11 ya instalado: $v"; break }
    } catch {}
}

if (-not $pythonOk) {
    $pyInstaller = "$env:TEMP\python-$PYTHON_VERSION-amd64.exe"
    Download $PYTHON_URL $pyInstaller "Python $PYTHON_VERSION"

    Log "Instalando Python $PYTHON_VERSION..."
    $proc = Start-Process $pyInstaller -ArgumentList @(
        "/quiet", "InstallAllUsers=0", "PrependPath=1",
        "Include_test=0", "Include_doc=0", "Include_launcher=1"
    ) -Wait -PassThru
    if ($proc.ExitCode -ne 0) { Die "Error al instalar Python (codigo $($proc.ExitCode))." }

    # Actualizar PATH en sesion actual
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $pythonExe = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"
    Log "Python $PYTHON_VERSION instalado correctamente."
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. POSTGRESQL PORTABLE
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 2: PostgreSQL $PG_VERSION (portable) ---"

if (-not (Test-Path "$PGBIN\postgres.exe")) {
    $pgZip = "$env:TEMP\postgresql-binaries.zip"
    Download $PG_URL $pgZip "PostgreSQL $PG_FULL_VERSION (binarios portables)"

    Log "Extrayendo PostgreSQL..."
    Expand-Archive -Path $pgZip -DestinationPath "$AppDir\_pg_tmp" -Force

    # El zip contiene una carpeta "pgsql" dentro
    $extracted = Get-ChildItem "$AppDir\_pg_tmp" | Select-Object -First 1
    Move-Item $extracted.FullName $PG_DIR -Force
    Remove-Item "$AppDir\_pg_tmp" -Recurse -Force
    Log "PostgreSQL extraido en $PG_DIR"
} else {
    Log "PostgreSQL portable ya presente en $PG_DIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. PGVECTOR
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 3: pgvector $PGVECTOR_VER ---"

if (-not (Test-Path "$PGBIN\..\lib\vector.dll")) {
    $vecZip = "$env:TEMP\pgvector.zip"
    $vecTmp = "$env:TEMP\pgvector_tmp"
    Download $PGVEC_URL $vecZip "pgvector $PGVECTOR_VER"

    Expand-Archive -Path $vecZip -DestinationPath $vecTmp -Force

    # Copiar DLLs y archivos de extension
    $libDir = "$PG_DIR\lib"
    $extDir = "$PG_DIR\share\extension"
    New-Item -ItemType Directory -Force -Path $libDir | Out-Null
    New-Item -ItemType Directory -Force -Path $extDir | Out-Null

    Get-ChildItem "$vecTmp" -Filter "*.dll" | Copy-Item -Destination $libDir -Force
    Get-ChildItem "$vecTmp" -Filter "*.control" | Copy-Item -Destination $extDir -Force
    Get-ChildItem "$vecTmp" -Filter "*.sql" | Copy-Item -Destination $extDir -Force

    Remove-Item $vecTmp -Recurse -Force
    Log "pgvector instalado en $PG_DIR"
} else {
    Log "pgvector ya presente."
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. INICIALIZAR CLUSTER DE POSTGRESQL
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 4: Inicializar base de datos ---"

if (-not (Test-Path "$PG_DATA\PG_VERSION")) {
    # Archivo temporal con la contrasena del superusuario
    $pwFile = "$env:TEMP\pg_pwfile.txt"
    Set-Content -Path $pwFile -Value $DB_PASS -Encoding ASCII

    Log "Inicializando cluster PostgreSQL en $PG_DATA..."
    $initProc = Start-Process "$PGBIN\initdb.exe" -ArgumentList @(
        "-D", $PG_DATA,
        "-U", $DB_USER,
        "--pwfile=$pwFile",
        "--encoding=UTF8",
        "--locale=es_AR"
    ) -Wait -PassThru -RedirectStandardOutput "$AppDir\initdb.log" -RedirectStandardError "$AppDir\initdb_err.log"

    Remove-Item $pwFile -Force -ErrorAction SilentlyContinue

    if ($initProc.ExitCode -ne 0) {
        $errDetail = Get-Content "$AppDir\initdb_err.log" -Raw
        Die "Error al inicializar PostgreSQL:`n$errDetail"
    }

    # Configurar puerto y conexiones en postgresql.conf
    $pgConf = "$PG_DATA\postgresql.conf"
    (Get-Content $pgConf) `
        -replace "#?port\s*=\s*\d+", "port = $PG_PORT" `
        -replace "#?listen_addresses\s*=\s*'[^']*'", "listen_addresses = 'localhost'" |
    Set-Content $pgConf

    Log "Cluster inicializado correctamente."
} else {
    Log "Cluster PostgreSQL ya inicializado en $PG_DATA."
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. REGISTRAR POSTGRESQL COMO SERVICIO WINDOWS
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 5: Servicio Windows para PostgreSQL ---"

$pgSvc = Get-Service -Name $PG_SVC -ErrorAction SilentlyContinue
if (-not $pgSvc) {
    Log "Registrando servicio '$PG_SVC'..."
    $regProc = Start-Process "$PGBIN\pg_ctl.exe" -ArgumentList @(
        "register",
        "-N", $PG_SVC,
        "-D", $PG_DATA,
        "-S", "auto",           # inicio automatico
        "-w"
    ) -Wait -PassThru
    if ($regProc.ExitCode -ne 0) { Die "Error al registrar el servicio de PostgreSQL." }
    Log "Servicio '$PG_SVC' registrado."
} else {
    Log "Servicio '$PG_SVC' ya existe."
}

# Iniciar el servicio
Log "Iniciando servicio de PostgreSQL..."
Start-Service -Name $PG_SVC -ErrorAction SilentlyContinue

# Esperar a que PostgreSQL acepte conexiones (hasta 30 segundos)
$retries = 30
while ($retries -gt 0) {
    $ready = & "$PGBIN\pg_isready.exe" -U $DB_USER -p $PG_PORT 2>&1
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 1
    $retries--
}
if ($retries -eq 0) { Die "PostgreSQL no respondio despues de 30 segundos." }
Log "PostgreSQL listo en puerto $PG_PORT."

# ─────────────────────────────────────────────────────────────────────────────
# 6. CREAR BASE DE DATOS Y ESTRUCTURA
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 6: Crear base de datos y tablas ---"

$env:PGPASSWORD = $DB_PASS

# Verificar si la DB ya existe
$dbExists = & "$PGBIN\psql.exe" -U $DB_USER -p $PG_PORT -d postgres `
    -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>&1
if ($dbExists -notmatch "1") {
    Log "Creando base de datos '$DB_NAME'..."
    & "$PGBIN\createdb.exe" -U $DB_USER -p $PG_PORT $DB_NAME
    if ($LASTEXITCODE -ne 0) { Die "Error al crear la base de datos." }
}

Log "Habilitando extension pgvector..."
& "$PGBIN\psql.exe" -U $DB_USER -p $PG_PORT -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 | Out-Null

Log "Ejecutando esquema inicial..."
& "$PGBIN\psql.exe" -U $DB_USER -p $PG_PORT -d $DB_NAME -f "$AppDir\init_database.sql" 2>&1 | Out-Null

Log "Base de datos lista."

# ─────────────────────────────────────────────────────────────────────────────
# 7. ENTORNO PYTHON (venv + dependencias)
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 7: Entorno Python y dependencias (esto tarda mas) ---"

$venvDir = "$AppDir\venv"
if (-not (Test-Path "$venvDir\Scripts\python.exe")) {
    Log "Creando entorno virtual..."
    & $pythonExe -m venv $venvDir
    if ($LASTEXITCODE -ne 0) { Die "Error al crear el entorno virtual Python." }
}

$pip = "$venvDir\Scripts\pip.exe"
Log "Actualizando pip..."
& $pip install --upgrade pip --quiet

Log "Instalando dependencias (insightface, fastapi, etc.)..."
Log "Esto puede tardar 10-20 minutos segun la velocidad de internet."
& $pip install -r "$AppDir\server\requirements.txt" --quiet
if ($LASTEXITCODE -ne 0) { Die "Error al instalar las dependencias de Python." }

Log "Dependencias instaladas correctamente."

# Pre-descargar el modelo de insightface (buffalo_sc ~120MB)
Log "Descargando modelo de reconocimiento facial (buffalo_sc, ~120 MB)..."
& "$venvDir\Scripts\python.exe" -c @"
from insightface.app import FaceAnalysis
app = FaceAnalysis(name='buffalo_sc', providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(320,320))
print('Modelo descargado.')
"@
Log "Modelo listo."

# ─────────────────────────────────────────────────────────────────────────────
# 8. ARCHIVO .env
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 8: Configuracion (.env) ---"

# Generar JWT_SECRET aleatorio
$jwtBytes  = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($jwtBytes)
$jwtSecret = [System.Convert]::ToBase64String($jwtBytes)

@"
DB_HOST=localhost
DB_PORT=$PG_PORT
JWT_SECRET=$jwtSecret
"@ | Set-Content -Path "$AppDir\.env" -Encoding UTF8

Log ".env creado."

# ─────────────────────────────────────────────────────────────────────────────
# 9. SERVICIO WINDOWS PARA EL SERVIDOR FASTAPI
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 9: Servicio Windows para el servidor API ---"

# Usar Task Scheduler con perfil SYSTEM para que arranque antes del login
$uvicorn  = "$venvDir\Scripts\uvicorn.exe"
$taskName = $API_SVC

# Eliminar tarea previa si existe
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute $uvicorn `
    -Argument "server.main:app --host 0.0.0.0 --port 8000 --log-level warning" `
    -WorkingDirectory $AppDir

# Disparador: al iniciar el sistema (con 20 s de delay para que Postgres levante primero)
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT20S"   # 20 segundos

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([System.TimeSpan]::Zero) `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable $true `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Log "Tarea programada '$taskName' registrada (inicio automatico con el sistema)."

# Iniciar el servidor ahora mismo
Log "Iniciando servidor API..."
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5
Log "Servidor iniciado."

# ─────────────────────────────────────────────────────────────────────────────
# 10. SCRIPTS AUXILIARES
# ─────────────────────────────────────────────────────────────────────────────
Log "--- PASO 10: Creando scripts auxiliares ---"

# abrir_panel.bat - abre el navegador en el panel admin
@"
@echo off
start "" http://localhost:8000
"@ | Set-Content -Path "$AppDir\abrir_panel.bat" -Encoding ASCII

# start_server.bat - inicio manual si la tarea falla
@"
@echo off
title Servidor de Reconocimiento Facial
cd /d "%~dp0"
echo Iniciando base de datos...
net start $PG_SVC >nul 2>&1
timeout /t 5 /nobreak >nul
echo Iniciando servidor API...
venv\Scripts\uvicorn.exe server.main:app --host 0.0.0.0 --port 8000 --log-level warning
pause
"@ | Set-Content -Path "$AppDir\start_server.bat" -Encoding ASCII

# stop_server.bat - detener manualmente
@"
@echo off
title Detener Servidor
echo Deteniendo servidor...
schtasks /End /TN "$taskName" >nul 2>&1
taskkill /IM uvicorn.exe /F >nul 2>&1
echo Servidor detenido.
pause
"@ | Set-Content -Path "$AppDir\stop_server.bat" -Encoding ASCII

Log "Scripts auxiliares creados."

# ─────────────────────────────────────────────────────────────────────────────
# FIN
# ─────────────────────────────────────────────────────────────────────────────
Log "=== INSTALACION COMPLETADA EXITOSAMENTE ==="
Log "Panel admin disponible en: http://localhost:8000"
Log "Log completo en: $LOG"
