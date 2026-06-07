# =============================================================================
# install.ps1 - Script de instalacion del Sistema de Reconocimiento Facial
# Requiere: Windows 10/11 x64, conexion a internet, permisos de administrador.
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppDir
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$LOG          = "$AppDir\install.log"
$TASK_NAME    = "SisRecFacial_API"
$DOCKER_URL   = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"

function Log {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg"
    Add-Content -Path $LOG -Value $line -Encoding UTF8
    Write-Host $line
}

function Die {
    param([string]$Msg)
    Log $Msg "ERROR"
    Add-Type -AssemblyName System.Windows.Forms
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
        Die "No se pudo descargar $Desc.`nVerifica tu conexion a internet."
    }
    Log "OK: $Desc descargado."
}

Add-Type -AssemblyName System.Windows.Forms | Out-Null

# Limpiar log de instalaciones anteriores para evitar confusion
if (Test-Path $LOG) { Remove-Item $LOG -Force -ErrorAction SilentlyContinue }
if (Test-Path "$AppDir\docker_build.log") { Remove-Item "$AppDir\docker_build.log" -Force -ErrorAction SilentlyContinue }

Log "=== INICIO DE INSTALACION (script v3 - Start-Process) ==="
Log "Directorio de instalacion: $AppDir"

# -----------------------------------------------------------------------------
# 1. VERIFICAR / INSTALAR DOCKER DESKTOP
# -----------------------------------------------------------------------------
Log "--- PASO 1: Docker Desktop ---"

$dockerOk = $false
try {
    & docker --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {}

if (-not $dockerOk) {
    Log "Docker no encontrado. Descargando Docker Desktop (~600 MB)..."
    $installer = "$env:TEMP\DockerDesktopInstaller.exe"
    Download $DOCKER_URL $installer "Docker Desktop"

    Log "Instalando Docker Desktop..."
    $proc = Start-Process $installer -ArgumentList "install --quiet --accept-license" -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 1) {
        Die "Error al instalar Docker Desktop (codigo $($proc.ExitCode))."
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Docker Desktop fue instalado correctamente.`n`nEs necesario REINICIAR la computadora para continuar.`n`nDespues del reinicio, ejecuta el instalador nuevamente.",
        "Reinicio requerido",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 0
}

Log "Docker encontrado."

# Asegurar que Docker esté en el PATH (puede faltar en contexto SYSTEM)
$dockerPaths = @(
    "C:\Program Files\Docker\Docker\resources\bin",
    "C:\Program Files\Docker\cli-plugins"
)
foreach ($p in $dockerPaths) {
    if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) {
        $env:Path += ";$p"
    }
}

# -----------------------------------------------------------------------------
# 2. VERIFICAR QUE DOCKER ENGINE ESTE CORRIENDO
# -----------------------------------------------------------------------------
Log "--- PASO 2: Iniciar Docker Engine ---"

$retries = 60
$engineOk = $false
while ($retries -gt 0) {
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $engineOk = $true; break }
    } catch {}

    if ($retries -eq 60) {
        Log "Docker Engine no esta corriendo. Iniciando Docker Desktop..."
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 5
    $retries--
}

if (-not $engineOk) {
    Die "Docker Desktop no respondio despues de 5 minutos.`nAbrilo manualmente y volvé a ejecutar el instalador."
}
Log "Docker Engine listo."

# -----------------------------------------------------------------------------
# 3. GENERAR ARCHIVO .env CON JWT_SECRET
# -----------------------------------------------------------------------------
Log "--- PASO 3: Configuracion (.env) ---"

$jwtBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($jwtBytes)
$jwtSecret = [System.Convert]::ToBase64String($jwtBytes)

@"
JWT_SECRET=$jwtSecret
"@ | Set-Content -Path "$AppDir\.env" -Encoding UTF8
Log ".env creado."

# -----------------------------------------------------------------------------
# 4. CONSTRUIR Y LEVANTAR CONTENEDORES
# -----------------------------------------------------------------------------
Log "--- PASO 4: Levantar contenedores Docker ---"
Log "Esto puede tardar 10-20 minutos la primera vez (descarga imagen base + modelo de IA)."

Set-Location $AppDir

Log "Construyendo imagen Docker (usando cmd.exe)..."
# Usar cmd.exe para evitar el problema de PowerShell que trata stderr de Docker como excepcion
$proc = Start-Process "cmd.exe" `
    -ArgumentList "/c", "docker compose build --progress plain > `"$AppDir\docker_build.log`" 2>&1" `
    -WorkingDirectory $AppDir `
    -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Log "ExitCode build: $($proc.ExitCode)" "ERROR"
    Die "Error al construir la imagen Docker (exit $($proc.ExitCode)). Revisa docker_build.log"
}
Log "Imagen construida."

Log "Iniciando contenedores..."
$proc = Start-Process "cmd.exe" `
    -ArgumentList "/c", "docker compose up -d >> `"$AppDir\docker_build.log`" 2>&1" `
    -WorkingDirectory $AppDir `
    -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Log "ExitCode up: $($proc.ExitCode)" "ERROR"
    Die "Error al iniciar los contenedores Docker (exit $($proc.ExitCode)). Revisa docker_build.log"
}

Log "Esperando que la base de datos este lista..."
$retries = 30
while ($retries -gt 0) {
    & docker exec facial_db pg_isready -U admin -d facial_recognition 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
    $retries--
}
if ($retries -eq 0) { Die "La base de datos no respondio a tiempo. Revisa: docker logs facial_db" }
Log "Contenedores corriendo correctamente."

# -----------------------------------------------------------------------------
# 5. INICIO AUTOMATICO CON WINDOWS (Tarea Programada)
# -----------------------------------------------------------------------------
Log "--- PASO 5: Inicio automatico con Windows ---"

Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute "docker" `
    -Argument "compose up -d" `
    -WorkingDirectory $AppDir

$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT30S"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([System.TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable $true `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TASK_NAME `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Log "Tarea de inicio automatico registrada."

# -----------------------------------------------------------------------------
# 6. SCRIPTS AUXILIARES
# -----------------------------------------------------------------------------
Log "--- PASO 6: Scripts auxiliares ---"

@"
@echo off
start "" http://localhost:8001
"@ | Set-Content -Path "$AppDir\abrir_panel.bat" -Encoding ASCII

@"
@echo off
title Servidor de Reconocimiento Facial
cd /d "%~dp0"
echo Iniciando contenedores...
docker compose up -d
echo Listo. Panel disponible en http://localhost:8001
pause
"@ | Set-Content -Path "$AppDir\start_server.bat" -Encoding ASCII

@"
@echo off
title Detener Servidor
cd /d "%~dp0"
echo Deteniendo contenedores...
docker compose down
echo Servidor detenido.
pause
"@ | Set-Content -Path "$AppDir\stop_server.bat" -Encoding ASCII

Log "Scripts auxiliares creados."

Log "=== INSTALACION COMPLETADA EXITOSAMENTE ==="
Log "Panel admin disponible en: http://localhost:8001"
Log "Log completo en: $LOG"
