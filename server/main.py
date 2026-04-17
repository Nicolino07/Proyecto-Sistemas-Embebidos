# ==============================================================================
# LIBRERIA FastAPI
# Framework para construir APIs REST en Python. Es moderno, rápido y genera
# documentación interactiva automáticamente en http://localhost:8000/docs
# (Swagger UI) — podés probar los endpoints desde el navegador sin escribir código.
#
# LIBRERIA pydantic (BaseModel)
# Define la "forma" de los datos que recibe y devuelve cada endpoint.
# FastAPI la usa para validar automáticamente: si mandás un string donde se espera
# un número, FastAPI devuelve un error 422 antes de que el código se ejecute.
# ==============================================================================
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from server.database import guardar_usuario, buscar_usuario_por_encoding, registrar_acceso, get_connection
import numpy as np

app = FastAPI(
    title="Sistema de Reconocimiento Facial",
    description="API REST para registro y reconocimiento facial usando pgvector",
)

# ==============================================================================
# MODELOS DE DATOS (Pydantic)
# Cada clase define qué campos espera recibir o devolver un endpoint.
# El tipo List[float] con 128 elementos es el vector de embedding facial.
# ==============================================================================

class VectorReconocimiento(BaseModel):
    vector: List[float]  # Array de 128 números generado por face_recognition en la Raspberry

class DatosRegistro(BaseModel):
    nombre: str
    apellido: str
    vector: List[float]  # Array de 128 números del rostro a registrar

class ResultadoReconocimiento(BaseModel):
    nombre: str
    es_exitoso: bool
    distancia: Optional[float]  # None si no hay nadie registrado aún

class ResultadoRegistro(BaseModel):
    id_usuario: int
    mensaje: str


# ==============================================================================
# ENDPOINTS
# Cada función decorada con @app.post o @app.get es un endpoint de la API.
# FastAPI convierte automáticamente los objetos Python a JSON en la respuesta.
# ==============================================================================

@app.post("/reconocer", response_model=ResultadoReconocimiento)
def reconocer(datos: VectorReconocimiento):
    """
    Recibe un vector de 128 floats (embedding facial generado en la Raspberry),
    busca el usuario más parecido en la DB y registra el intento en la tabla accesos.
    """
    encoding = np.array(datos.vector)

    if len(encoding) != 128:
        raise HTTPException(status_code=400, detail="El vector debe tener exactamente 128 valores")

    id_usuario, nombre, distancia = buscar_usuario_por_encoding(encoding)
    es_exitoso = nombre != "Desconocido"

    # Guardamos el intento en la tabla accesos (sea exitoso o no)
    registrar_acceso(id_usuario, distancia, es_exitoso)

    return ResultadoReconocimiento(
        nombre=nombre,
        es_exitoso=es_exitoso,
        distancia=distancia,
    )


@app.post("/registrar", response_model=ResultadoRegistro)
def registrar(datos: DatosRegistro):
    """
    Registra un nuevo usuario con su embedding facial en la base de datos.
    Se llama desde la Raspberry en el modo 1 (registro).
    """
    encoding = np.array(datos.vector)

    if len(encoding) != 128:
        raise HTTPException(status_code=400, detail="El vector debe tener exactamente 128 valores")

    id_usuario = guardar_usuario(datos.nombre, datos.apellido, encoding)

    return ResultadoRegistro(
        id_usuario=id_usuario,
        mensaje=f"{datos.nombre} {datos.apellido} registrado correctamente",
    )


@app.get("/usuarios")
def listar_usuarios():
    """
    Devuelve la lista de todos los usuarios registrados.
    No incluye los vectores (son datos biométricos internos, no se exponen).
    Útil para el frontend React.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT u.id_usuario, u.nombre, u.apellido, u.creado_en,
                       COUNT(rv.id_vector) AS fotos_registradas
                FROM usuario u
                LEFT JOIN rostro_vector rv ON u.id_usuario = rv.id_usuario
                GROUP BY u.id_usuario
                ORDER BY u.id_usuario
            """)
            rows = cur.fetchall()

    return [
        {
            "id_usuario": row[0],
            "nombre": row[1],
            "apellido": row[2],
            "creado_en": row[3],
            "fotos_registradas": row[4],
        }
        for row in rows
    ]


@app.delete("/usuarios/{id_usuario}")
def eliminar_usuario(id_usuario: int):
    """
    Da de baja un usuario por su ID.
    Los accesos previos quedan en la tabla accesos con id_usuario=NULL (ON DELETE SET NULL).
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM usuario WHERE id_usuario = %s RETURNING id_usuario", (id_usuario,))
            eliminado = cur.fetchone()
        conn.commit()

    if eliminado is None:
        raise HTTPException(status_code=404, detail=f"Usuario {id_usuario} no encontrado")

    return {"mensaje": f"Usuario {id_usuario} eliminado correctamente"}
