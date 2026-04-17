# Detección Facial
**Laboratorio de Sistemas Embebidos — UNRN 2026**

Sistema de reconocimiento facial para control de acceso y registro de asistencia.
La Raspberry Pi captura el video, genera el embedding facial y lo envía al servidor central por HTTP. El servidor compara contra la base de datos y registra el resultado.

## Integrantes
- Damián Pérez
- Elías Nicolás Vargas
- Matías Palleres

## Arquitectura

```
Webcam → Raspberry Pi (face_recognition) → HTTP POST vector[128] → PC Servidor (FastAPI) → PostgreSQL
```

## Hardware
- Raspberry Pi 400 — captura y preprocesamiento (genera embeddings)
- Webcam USB — sensor de video
- PC — servidor central, base de datos, interfaz web
- Display — indicador de acceso permitido/denegado

## Software
- Python 3, OpenCV, face_recognition, dlib
- FastAPI + uvicorn (servidor REST)
- PostgreSQL + pgvector (base de datos vectorial)
- React (interfaz gráfica — pendiente)

---

## Instalación

### 1. Instalar dependencias del servidor (en la PC)
```bash
pip3 install -r server/requirements.txt
```

### 2. Instalar dependencias del edge node (en la Raspberry o PC para desarrollo)
```bash
pip3 install -r edge_node/requirements.txt
```

### 3. Levantar la base de datos

```bash
docker compose up -d
```

Docker crea la base de datos, el usuario y las tablas automáticamente la primera vez.
Las siguientes veces que lo corras, solo levanta el contenedor sin re-crear nada.

---

## Correr el sistema

### Terminal 1 — Servidor (PC)
```bash
bash start.sh
```
La primera vez instala las dependencias automáticamente. La API queda en http://localhost:8000/docs

### Terminal 2 — Cámara (Raspberry o PC para desarrollo)
```bash
bash camara.sh
```

---

## Estructura del proyecto

```
├── docker-compose.yml          # Levanta PostgreSQL con pgvector
├── server/
│   ├── main.py                 # API REST (FastAPI) — endpoints /reconocer, /registrar, /usuarios
│   ├── database.py             # Conexión a PostgreSQL y operaciones con pgvector
│   ├── init_database.sql       # Script de creación de tablas
│   └── requirements.txt        # fastapi, uvicorn, psycopg2-binary, pgvector
└── edge_node/
    ├── capture.py              # Captura de cámara, genera embeddings, llama al servidor
    ├── config.py               # URL del servidor, índice de cámara, frames a saltar
    ├── ver_base_datos.py       # Script para inspeccionar la DB (debugging)
    └── requirements.txt        # opencv-python, face-recognition, numpy, requests
```
