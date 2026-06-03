# Cómo compilar el instalador .exe (desde Linux)

## Requisitos

```bash
sudo apt install nsis        # compilador de instaladores Windows
npm install                  # (ya instalado en el proyecto)
```

## Pasos

### 1. Buildear el frontend

```bash
cd frontend
npm run build
cd ..
```

Genera `frontend/dist/` que el instalador incluye.

### 2. Compilar el instalador

```bash
makensis installer/installer.nsi
```

Genera: **`installer/Output/SistemaReconocimientoFacial_Instalador.exe`**

Copiás ese `.exe` a cualquier PC con Windows 10/11 y hacés doble clic.

---

## Qué hace el instalador al ejecutarse en Windows

| Paso | Qué hace | Tiempo aprox. |
|------|----------|--------------|
| 1 | Instala Python 3.11 | 2-3 min |
| 2 | Descarga PostgreSQL 16 portable (~130 MB) | 5-10 min |
| 3 | Descarga pgvector | 1 min |
| 4 | Inicializa la base de datos | 1 min |
| 5 | Registra PostgreSQL como servicio Windows | 30 seg |
| 6 | Crea la DB y las tablas | 30 seg |
| 7 | Instala dependencias Python (~500 MB) | 10-20 min |
| 8 | Descarga modelo de IA buffalo_sc (~120 MB) | 5 min |
| 9 | Registra el servidor como tarea de inicio | 30 seg |

**Total: 25-45 minutos** — solo se hace una vez.

## Resultado en la PC Windows

- **PostgreSQL** → servicio Windows (arranca automáticamente con el sistema)  
- **Servidor API** → tarea programada del sistema (arranca 20 s después de Windows)  
- **Panel admin** → http://localhost:8000  
- **Acceso directo** en el Escritorio y en el Menú Inicio  

El servidor corre aunque no haya ningún usuario logueado en Windows.

## Actualizar la versión de PostgreSQL

Si la descarga de PostgreSQL falla, actualizar `PG_FULL_VERSION` en `install.ps1`:

```powershell
$PG_FULL_VERSION = "16.4-1"   # ← cambiar por la versión más reciente
```

Ver versiones disponibles en: https://www.enterprisedb.com/download-postgresql-binaries

## Agregar ícono (opcional)

Colocar `installer/assets/icon.ico` y descomentarlo en `installer.nsi`.  
Sin ícono el instalador funciona igual pero usa el ícono por defecto de NSIS.
