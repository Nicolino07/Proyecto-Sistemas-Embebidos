# =============================================================================
# uninstall.ps1 - Limpieza al desinstalar
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppDir
)

$ErrorActionPreference = "SilentlyContinue"
$TASK_NAME = "SisRecFacial_API"

Write-Host "Deteniendo contenedores Docker..."
Set-Location $AppDir
& docker compose down 2>&1 | Out-Null

Write-Host "Eliminando tarea programada..."
Stop-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Limpieza completada."
