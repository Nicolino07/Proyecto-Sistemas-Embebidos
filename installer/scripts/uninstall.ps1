# =============================================================================
# uninstall.ps1 - Limpieza al desinstalar
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppDir
)

$ErrorActionPreference = "SilentlyContinue"

$PG_SVC   = "SisRecFacial_DB"
$API_SVC  = "SisRecFacial_API"
$PGBIN    = "$AppDir\pgsql\bin"

Write-Host "Deteniendo servidor API..."
Stop-ScheduledTask -TaskName $API_SVC -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $API_SVC -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Deteniendo base de datos..."
Stop-Service -Name $PG_SVC -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (Test-Path "$PGBIN\pg_ctl.exe") {
    & "$PGBIN\pg_ctl.exe" unregister -N $PG_SVC 2>&1 | Out-Null
}

Write-Host "Limpieza completada."
