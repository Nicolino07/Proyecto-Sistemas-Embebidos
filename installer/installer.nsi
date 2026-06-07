; =============================================================================
; Sistema de Reconocimiento Facial - Instalador Windows
; Compilar en Linux: makensis installer/installer.nsi
; Requiere: sudo apt install nsis
; =============================================================================

Unicode True
!include "MUI2.nsh"
!include "LogicLib.nsh"

; ─── Metadatos ────────────────────────────────────────────────────────────────
!define APP_NAME    "Sistema de Reconocimiento Facial"
!define APP_VERSION "1.0"
!define APP_PUBLISHER "UADE"
!define TASK_NAME   "SisRecFacial_API"

Name "${APP_NAME}"
OutFile "Output\SistemaReconocimientoFacial_Instalador_v3.exe"
InstallDir "$PROGRAMFILES64\SistemaReconocimientoFacial"
InstallDirRegKey HKLM "Software\${APP_NAME}" "InstallDir"
RequestExecutionLevel admin

; ─── Aspecto moderno ──────────────────────────────────────────────────────────
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE  "Bienvenido al instalador"
!define MUI_WELCOMEPAGE_TEXT   "Este asistente instalará el ${APP_NAME} en tu computadora.$\r$\n$\r$\nRequiere Docker Desktop y conexión a internet. Si Docker no está instalado, se descargará e instalará automáticamente (requiere reinicio).$\r$\n$\r$\nCerrá todas las aplicaciones antes de continuar."
!define MUI_FINISHPAGE_TITLE   "Instalación completada"
!define MUI_FINISHPAGE_TEXT    "El sistema está listo.$\r$\n$\r$\nEl servidor arranca automáticamente con Windows.$\r$\nEl panel de administración estará disponible en:$\r$\nhttp://localhost:8001"
!define MUI_FINISHPAGE_RUN     "$INSTDIR\abrir_panel.bat"
!define MUI_FINISHPAGE_RUN_TEXT "Abrir el Panel de Administración"

; ─── Páginas del wizard ───────────────────────────────────────────────────────
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Spanish"

; =============================================================================
; INSTALACIÓN
; =============================================================================
Section "Principal" SecMain

  SetOutPath "$INSTDIR"

  ; ── Código del servidor (File /r con nombre de carpeta crea $INSTDIR\server\) ──
  File /r "..\server"

  ; ── Frontend ya compilado ──────────────────────────────────────────────────
  SetOutPath "$INSTDIR\frontend"
  File /r "..\frontend\dist"

  ; ── Archivos raíz ─────────────────────────────────────────────────────────
  SetOutPath "$INSTDIR"
  File "..\server\init_database.sql"
  File "..\docker-compose.yml"
  File "scripts\install.ps1"
  File "scripts\uninstall.ps1"

  ; ── Script principal de instalación ───────────────────────────────────────
  DetailPrint "Instalando dependencias del sistema..."
  DetailPrint "(Docker Desktop, imagen del servidor, modelo de IA)"
  DetailPrint "Esto puede tardar entre 10 y 20 minutos segun tu conexion a internet."
  DetailPrint "No cierres esta ventana."

  nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -NonInteractive \
    -File "$INSTDIR\install.ps1" -AppDir "$INSTDIR"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "La instalacion fallo (codigo $0).$\r$\nRevisa el log en:$\r$\n$INSTDIR\install.log"
    Abort
  ${EndIf}

  ; ── Registro de Windows ───────────────────────────────────────────────────
  WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"

  ; ── Desinstalador ─────────────────────────────────────────────────────────
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "Publisher" "${APP_PUBLISHER}"

  ; ── Accesos directos ──────────────────────────────────────────────────────
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Panel de Administracion.lnk" \
    "$INSTDIR\abrir_panel.bat" "" "$INSTDIR\abrir_panel.bat"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Iniciar Servidor (manual).lnk" \
    "$INSTDIR\start_server.bat" "" "$INSTDIR\start_server.bat"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Detener Servidor.lnk" \
    "$INSTDIR\stop_server.bat" "" "$INSTDIR\stop_server.bat"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk" \
    "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\Panel Reconocimiento Facial.lnk" \
    "$INSTDIR\abrir_panel.bat"

SectionEnd

; =============================================================================
; DESINSTALACIÓN
; =============================================================================
Section "Uninstall"

  DetailPrint "Deteniendo servicios..."
  nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -NonInteractive \
    -File "$INSTDIR\uninstall.ps1" -AppDir "$INSTDIR"'

  RMDir /r "$INSTDIR\server"
  RMDir /r "$INSTDIR\frontend"
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"

  ; Accesos directos
  Delete "$DESKTOP\Panel Reconocimiento Facial.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; Registro
  DeleteRegKey HKLM "Software\${APP_NAME}"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

SectionEnd
