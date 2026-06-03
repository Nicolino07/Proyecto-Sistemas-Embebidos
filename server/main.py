from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
import bcrypt
from server.database import guardar_usuario, buscar_usuario_por_encoding, registrar_acceso, registrar_nodo, listar_nodos, get_connection
import numpy as np
import cv2
import os
import pathlib
import secrets

# ==============================================================================
# MODELO DE RECONOCIMIENTO FACIAL (insightface)
#
# Se inicializa una sola vez al arrancar el servidor para no recargar el modelo
# en cada petición. buffalo_sc es el modelo liviano (single-camera) optimizado
# para CPU, el mismo que usa la Raspberry Pi.
# ==============================================================================
from insightface.app import FaceAnalysis as _FaceAnalysis

_face_app = _FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
_face_app.prepare(ctx_id=0, det_size=(320, 320))

JWT_SECRET = os.getenv("JWT_SECRET", "cambia-esto-en-produccion")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 480  # 8 horas

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/admin/login")


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


_RECOVERY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sin 0/O ni 1/I

def generar_recovery_code() -> str:
    return "-".join(
        "".join(secrets.choice(_RECOVERY_ALPHABET) for _ in range(4))
        for _ in range(4)
    )

app = FastAPI(
    title="Sistema de Reconocimiento Facial",
    description="API REST para registro y reconocimiento facial usando pgvector",
)


# ==============================================================================
# MODELOS DE DATOS
# ==============================================================================

class VectorReconocimiento(BaseModel):
    vector: List[float]
    # La Raspberry envía su id_nodo (obtenido al registrarse en /nodos/registrar).
    # El servidor resuelve el punto de acceso asociado a ese nodo y verifica permisos.
    id_nodo: Optional[int] = None

class DatosRegistro(BaseModel):
    documento: str
    nombre: str
    apellido: str
    vector: List[float]

class ResultadoReconocimiento(BaseModel):
    nombre: str
    es_exitoso: bool
    distancia: Optional[float]

class ResultadoRegistro(BaseModel):
    id_usuario: int
    mensaje: str

class RegistroNodo(BaseModel):
    hostname: str
    ip: str


# ==============================================================================
# AUTENTICACIÓN JWT
# ==============================================================================

def crear_token(username: str) -> str:
    expira = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRE_MINUTES)
    return jwt.encode({"sub": username, "exp": expira}, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_admin_actual(token: str = Depends(oauth2_scheme)) -> str:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        username: str = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Token inválido")
        return username
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")


# ==============================================================================
# SETUP INICIAL
#
# Estos dos endpoints solo están activos cuando no existe ningún administrador
# en la base de datos. Permiten crear el usuario master desde la interfaz
# gráfica la primera vez que se levanta el sistema, sin necesidad de usar
# la terminal. Una vez creado el primer admin, ambos endpoints quedan
# efectivamente bloqueados (devuelven 409 Conflict).
# ==============================================================================

class DatosSetup(BaseModel):
    username: str
    password: str
    nombre: str
    apellido: str
    email: Optional[str] = None


def hay_admins() -> bool:
    """Retorna True si ya existe al menos un administrador en la base de datos."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM administrador LIMIT 1")
            return cur.fetchone() is not None


@app.get("/admin/setup/status")
def setup_status():
    """
    Indica si el sistema necesita configuración inicial.
    El frontend lo consulta al arrancar para decidir si mostrar /setup o /login.
    Respuesta: { "necesita_setup": true | false }
    """
    return {"necesita_setup": not hay_admins()}


@app.post("/admin/setup", status_code=201)
def setup_inicial(datos: DatosSetup):
    """
    Crea el administrador master la primera vez que se configura el sistema.
    Si ya existe algún admin, devuelve 409 para impedir la sobreescritura.
    """
    if hay_admins():
        raise HTTPException(
            status_code=409,
            detail="El sistema ya fue configurado. Usá el login normal.",
        )

    password_hash = hash_password(datos.password)
    recovery_code = generar_recovery_code()
    recovery_hash = hash_password(recovery_code)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO administrador (username, password_hash, recovery_code_hash, nombre, apellido, email)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id_admin
                """,
                (datos.username, password_hash, recovery_hash, datos.nombre, datos.apellido, datos.email or None),
            )
            id_admin = cur.fetchone()[0]
        conn.commit()

    return {
        "id_admin": id_admin,
        "mensaje": f"Administrador '{datos.username}' creado correctamente.",
        "recovery_code": recovery_code,
    }


@app.post("/admin/login")
def login(form: OAuth2PasswordRequestForm = Depends()):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT password_hash, habilitado FROM administrador WHERE username = %s",
                (form.username,),
            )
            row = cur.fetchone()

    if row is None or not row[1]:
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    password_hash, _ = row
    if not verify_password(form.password, password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE administrador SET ultimo_acceso = NOW() WHERE username = %s",
                (form.username,),
            )
        conn.commit()

    return {"access_token": crear_token(form.username), "token_type": "bearer"}


# ==============================================================================
# RECUPERACIÓN DE CONTRASEÑA
# ==============================================================================

class RecuperarPassword(BaseModel):
    username: str
    recovery_code: str
    nueva_password: str


@app.post("/admin/recover")
def recuperar_password(datos: RecuperarPassword):
    """
    Resetea la contraseña usando el código de recuperación.
    El código se invalida y se genera uno nuevo tras el uso exitoso.
    Endpoint público (no requiere token).
    """
    if len(datos.nueva_password) < 8:
        raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 8 caracteres.")

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id_admin, recovery_code_hash, habilitado FROM administrador WHERE username = %s",
                (datos.username,),
            )
            row = cur.fetchone()

    if row is None or not row[2]:
        raise HTTPException(status_code=401, detail="Credenciales incorrectas.")

    id_admin, recovery_hash, _ = row

    if recovery_hash is None or not verify_password(datos.recovery_code, recovery_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas.")

    nuevo_code = generar_recovery_code()
    nuevo_hash_password = hash_password(datos.nueva_password)
    nuevo_hash_code = hash_password(nuevo_code)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE administrador SET password_hash = %s, recovery_code_hash = %s WHERE id_admin = %s",
                (nuevo_hash_password, nuevo_hash_code, id_admin),
            )
        conn.commit()

    return {"mensaje": "Contraseña actualizada.", "recovery_code": nuevo_code}


@app.post("/admin/admins/{id_admin}/recovery-code")
def regenerar_recovery_code(id_admin: int, _: str = Depends(get_admin_actual)):
    """Genera un nuevo código de recuperación para el administrador indicado."""
    nuevo_code = generar_recovery_code()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE administrador SET recovery_code_hash = %s WHERE id_admin = %s RETURNING id_admin",
                (hash_password(nuevo_code), id_admin),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Administrador no encontrado.")
        conn.commit()
    return {"recovery_code": nuevo_code}


# ==============================================================================
# ENDPOINTS — ACCESOS
# ==============================================================================

@app.get("/accesos")
def listar_accesos(_: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT a.id_acceso,
                       CASE WHEN u.id_usuario IS NOT NULL
                            THEN u.nombre || ' ' || u.apellido
                            ELSE NULL END AS nombre_usuario,
                       a.fecha_hora,
                       a.resultado,
                       a.distancia_calculada,
                       pa.nombre AS punto_acceso
                FROM accesos a
                LEFT JOIN usuario u ON a.id_usuario = u.id_usuario
                LEFT JOIN punto_acceso pa ON a.id_punto_acceso = pa.id_punto
                ORDER BY a.fecha_hora DESC
                LIMIT 500
            """)
            rows = cur.fetchall()

    return [
        {
            "id_acceso": r[0],
            "nombre_usuario": r[1],
            "fecha_hora": r[2],
            "resultado": r[3],
            "distancia_calculada": r[4],
            "punto_acceso": r[5],
        }
        for r in rows
    ]


# ==============================================================================
# ENDPOINTS — RECONOCIMIENTO Y REGISTRO (usados por la Raspberry)
# ==============================================================================

@app.post("/reconocer", response_model=ResultadoReconocimiento)
def reconocer(datos: VectorReconocimiento):
    encoding = np.array(datos.vector)
    if len(encoding) != 512:
        raise HTTPException(status_code=400, detail="El vector debe tener exactamente 512 valores")

    id_usuario, nombre, distancia = buscar_usuario_por_encoding(encoding)

    # Resolver el punto de acceso a partir del id_nodo de la Raspberry
    id_punto_acceso = None
    if datos.id_nodo is not None:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id_punto FROM punto_acceso WHERE id_nodo = %s AND habilitado = TRUE LIMIT 1",
                    (datos.id_nodo,),
                )
                row = cur.fetchone()
                if row:
                    id_punto_acceso = row[0]

    if nombre == "Desconocido":
        registrar_acceso(None, distancia, "no_reconocido", id_punto_acceso=id_punto_acceso)
        return ResultadoReconocimiento(nombre=nombre, es_exitoso=False, distancia=distancia)

    # Verificar permisos si se conoce el punto de acceso.
    # Sin punto configurado se considera acceso libre (modo sin control de permisos).
    tiene_permiso = True
    if id_punto_acceso is not None:
        with get_connection() as conn:
            with conn.cursor() as cur:
                # 1. Acceso directo al punto
                cur.execute(
                    "SELECT 1 FROM usuario_punto WHERE id_usuario = %s AND id_punto_acceso = %s",
                    (id_usuario, id_punto_acceso),
                )
                if cur.fetchone():
                    tiene_permiso = True
                else:
                    # 2. Acceso por zona, verificando que no haya exclusión para este punto
                    cur.execute(
                        """
                        SELECT 1 FROM usuario_zona uz
                        JOIN punto_acceso pa ON pa.id_zona = uz.id_zona
                        WHERE uz.id_usuario = %s AND pa.id_punto = %s
                          AND NOT EXISTS (
                              SELECT 1 FROM usuario_zona_exclusion
                              WHERE id_usuario = %s AND id_punto_acceso = %s
                          )
                        """,
                        (id_usuario, id_punto_acceso, id_usuario, id_punto_acceso),
                    )
                    tiene_permiso = cur.fetchone() is not None

    resultado = "exitoso" if tiene_permiso else "sin_permiso"
    registrar_acceso(id_usuario, distancia, resultado, id_punto_acceso=id_punto_acceso)

    return ResultadoReconocimiento(nombre=nombre, es_exitoso=tiene_permiso, distancia=distancia)


@app.post("/registrar", response_model=ResultadoRegistro)
def registrar(datos: DatosRegistro):
    encoding = np.array(datos.vector)
    if len(encoding) != 512:
        raise HTTPException(status_code=400, detail="El vector debe tener exactamente 512 valores")

    id_usuario = guardar_usuario(datos.documento, datos.nombre, datos.apellido, encoding)
    return ResultadoRegistro(
        id_usuario=id_usuario,
        mensaje=f"{datos.nombre} {datos.apellido} registrado correctamente",
    )


@app.post("/registrar/imagen", response_model=ResultadoRegistro)
async def registrar_desde_imagen(
    documento: str = Form(...),
    nombre: str = Form(...),
    apellido: str = Form(...),
    imagen: UploadFile = File(...),
    _: str = Depends(get_admin_actual),
):
    """
    Registra un usuario a partir de una imagen JPEG capturada desde el navegador.
    El servidor extrae el embedding facial usando insightface (mismo modelo que
    la Raspberry) y lo guarda en la base de datos.

    Devuelve 400 si no se detecta ningún rostro en la imagen.
    Devuelve 409 si se detectan múltiples rostros (ambigüedad).
    """
    contenido = await imagen.read()
    img_array = np.frombuffer(contenido, dtype=np.uint8)
    frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

    if frame is None:
        raise HTTPException(status_code=400, detail="No se pudo decodificar la imagen.")

    rostros = _face_app.get(frame)

    if len(rostros) == 0:
        raise HTTPException(status_code=400, detail="No se detectó ningún rostro en la imagen.")
    if len(rostros) > 1:
        raise HTTPException(status_code=409, detail="Se detectaron múltiples rostros. Asegurate de que solo aparezca una persona.")

    embedding = rostros[0].embedding  # vector de 512 floats

    id_usuario = guardar_usuario(documento, nombre, apellido, embedding)
    return ResultadoRegistro(
        id_usuario=id_usuario,
        mensaje=f"{nombre} {apellido} registrado correctamente",
    )


# ==============================================================================
# ENDPOINTS — USUARIOS (protegidos)
# ==============================================================================

@app.get("/usuarios")
def listar_usuarios(_: str = Depends(get_admin_actual)):
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
def eliminar_usuario(id_usuario: int, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM usuario WHERE id_usuario = %s RETURNING id_usuario", (id_usuario,))
            eliminado = cur.fetchone()
        conn.commit()

    if eliminado is None:
        raise HTTPException(status_code=404, detail=f"Usuario {id_usuario} no encontrado")

    return {"mensaje": f"Usuario {id_usuario} eliminado correctamente"}


# ==============================================================================
# ENDPOINTS — ADMINISTRADORES (protegidos)
#
# Permiten gestionar los administradores del panel desde la propia interfaz.
# Solo un admin autenticado puede crear, editar o deshabilitar otros admins.
# No se puede eliminar ni deshabilitar el último admin activo para evitar
# quedarse sin acceso al sistema.
# ==============================================================================

class DatosAdmin(BaseModel):
    username: str
    password: Optional[str] = None   # None = no cambiar la contraseña
    nombre: str
    apellido: str
    email: Optional[str] = None


@app.get("/admin/admins")
def listar_admins(_: str = Depends(get_admin_actual)):
    """Devuelve todos los administradores. No incluye el hash de contraseña."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id_admin, username, nombre, apellido, email,
                       habilitado, creado_en, ultimo_acceso
                FROM administrador
                ORDER BY id_admin
            """)
            rows = cur.fetchall()
    return [
        {
            "id_admin": r[0],
            "username": r[1],
            "nombre": r[2],
            "apellido": r[3],
            "email": r[4],
            "habilitado": r[5],
            "creado_en": r[6],
            "ultimo_acceso": r[7],
        }
        for r in rows
    ]


@app.post("/admin/admins", status_code=201)
def crear_admin(datos: DatosAdmin, _: str = Depends(get_admin_actual)):
    """Crea un nuevo administrador. La contraseña es obligatoria en la creación."""
    if not datos.password:
        raise HTTPException(status_code=400, detail="La contraseña es obligatoria al crear un administrador.")

    password_hash = hash_password(datos.password)
    recovery_code = generar_recovery_code()
    recovery_hash = hash_password(recovery_code)
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    """
                    INSERT INTO administrador (username, password_hash, recovery_code_hash, nombre, apellido, email)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id_admin
                    """,
                    (datos.username, password_hash, recovery_hash, datos.nombre, datos.apellido, datos.email or None),
                )
                id_admin = cur.fetchone()[0]
            except Exception:
                raise HTTPException(status_code=409, detail=f"El usuario '{datos.username}' ya existe.")
        conn.commit()
    return {
        "id_admin": id_admin,
        "mensaje": f"Administrador '{datos.username}' creado.",
        "recovery_code": recovery_code,
    }


@app.put("/admin/admins/{id_admin}")
def editar_admin(id_admin: int, datos: DatosAdmin, admin_actual: str = Depends(get_admin_actual)):
    """
    Actualiza datos de un administrador. Si se envía password, se cambia el hash.
    Si password es None o vacío, la contraseña actual no se modifica.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            if datos.password:
                cur.execute(
                    """
                    UPDATE administrador
                    SET username = %s, password_hash = %s, nombre = %s, apellido = %s, email = %s
                    WHERE id_admin = %s
                    RETURNING id_admin
                    """,
                    (datos.username, hash_password(datos.password),
                     datos.nombre, datos.apellido, datos.email or None, id_admin),
                )
            else:
                cur.execute(
                    """
                    UPDATE administrador
                    SET username = %s, nombre = %s, apellido = %s, email = %s
                    WHERE id_admin = %s
                    RETURNING id_admin
                    """,
                    (datos.username, datos.nombre, datos.apellido, datos.email or None, id_admin),
                )
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Administrador no encontrado.")
        conn.commit()
    return {"mensaje": "Administrador actualizado."}


@app.patch("/admin/admins/{id_admin}/habilitado")
def cambiar_habilitado(id_admin: int, _: str = Depends(get_admin_actual)):
    """
    Alterna el estado habilitado/deshabilitado de un administrador.
    Impide deshabilitar al último admin activo para no perder el acceso al sistema.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT habilitado FROM administrador WHERE id_admin = %s", (id_admin,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Administrador no encontrado.")

            habilitado_actual = row[0]

            # Si se va a deshabilitar, verificar que quede al menos uno activo
            if habilitado_actual:
                cur.execute("SELECT COUNT(*) FROM administrador WHERE habilitado = TRUE")
                if cur.fetchone()[0] <= 1:
                    raise HTTPException(
                        status_code=400,
                        detail="No se puede deshabilitar el único administrador activo.",
                    )

            cur.execute(
                "UPDATE administrador SET habilitado = NOT habilitado WHERE id_admin = %s RETURNING habilitado",
                (id_admin,),
            )
            nuevo_estado = cur.fetchone()[0]
        conn.commit()
    return {"habilitado": nuevo_estado}


# ==============================================================================
# ENDPOINTS — ZONAS
#
# Una zona agrupa uno o más puntos de acceso (puertas, torniquetes, etc.).
# Los usuarios pueden tener acceso a una zona completa o a puntos individuales.
# ==============================================================================

class DatosZona(BaseModel):
    nombre: str
    descripcion: Optional[str] = None


@app.get("/zonas")
def listar_zonas(_: str = Depends(get_admin_actual)):
    """Devuelve todas las zonas con la cantidad de puntos de acceso que contienen."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT z.id_zona, z.nombre, z.descripcion, z.creado_en,
                       COUNT(pa.id_punto) AS puntos
                FROM zona z
                LEFT JOIN punto_acceso pa ON pa.id_zona = z.id_zona
                GROUP BY z.id_zona
                ORDER BY z.id_zona
            """)
            rows = cur.fetchall()
    return [{"id_zona": r[0], "nombre": r[1], "descripcion": r[2], "creado_en": r[3], "puntos": r[4]} for r in rows]


@app.post("/zonas", status_code=201)
def crear_zona(datos: DatosZona, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO zona (nombre, descripcion) VALUES (%s, %s) RETURNING id_zona",
                (datos.nombre, datos.descripcion),
            )
            id_zona = cur.fetchone()[0]
        conn.commit()
    return {"id_zona": id_zona, "mensaje": f"Zona '{datos.nombre}' creada."}


@app.put("/zonas/{id_zona}")
def editar_zona(id_zona: int, datos: DatosZona, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE zona SET nombre = %s, descripcion = %s WHERE id_zona = %s RETURNING id_zona",
                (datos.nombre, datos.descripcion, id_zona),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Zona no encontrada.")
        conn.commit()
    return {"mensaje": "Zona actualizada."}


@app.delete("/zonas/{id_zona}")
def eliminar_zona(id_zona: int, _: str = Depends(get_admin_actual)):
    """
    Elimina una zona. Falla con 409 si tiene puntos de acceso asociados,
    para evitar dejar puntos huérfanos. Hay que eliminar los puntos primero.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM punto_acceso WHERE id_zona = %s", (id_zona,))
            if cur.fetchone()[0] > 0:
                raise HTTPException(
                    status_code=409,
                    detail="La zona tiene puntos de acceso asociados. Eliminá los puntos primero.",
                )
            cur.execute("DELETE FROM zona WHERE id_zona = %s RETURNING id_zona", (id_zona,))
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Zona no encontrada.")
        conn.commit()
    return {"mensaje": "Zona eliminada."}


# ==============================================================================
# ENDPOINTS — PUNTOS DE ACCESO
#
# Un punto de acceso es una puerta o dispositivo físico dentro de una zona.
# Cada punto puede tener asignado un nodo edge (Raspberry Pi).
# ==============================================================================

class DatosPunto(BaseModel):
    nombre: str
    ubicacion: Optional[str] = None
    id_zona: int
    id_nodo: Optional[int] = None   # Raspberry Pi asignada a este punto


@app.get("/puntos")
def listar_puntos(_: str = Depends(get_admin_actual)):
    """Devuelve todos los puntos con su zona y nodo asignado."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT pa.id_punto, pa.nombre, pa.ubicacion, pa.habilitado,
                       z.id_zona, z.nombre AS zona_nombre,
                       ne.id_nodo, ne.hostname, ne.ip
                FROM punto_acceso pa
                JOIN zona z ON pa.id_zona = z.id_zona
                LEFT JOIN nodo_edge ne ON ne.id_nodo = pa.id_nodo
                ORDER BY z.nombre, pa.nombre
            """)
            rows = cur.fetchall()
    return [
        {
            "id_punto": r[0], "nombre": r[1], "ubicacion": r[2], "habilitado": r[3],
            "id_zona": r[4], "zona_nombre": r[5],
            "id_nodo": r[6], "nodo_hostname": r[7], "nodo_ip": r[8],
        }
        for r in rows
    ]


@app.post("/puntos", status_code=201)
def crear_punto(datos: DatosPunto, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO punto_acceso (nombre, ubicacion, id_zona, id_nodo)
                VALUES (%s, %s, %s, %s) RETURNING id_punto
                """,
                (datos.nombre, datos.ubicacion, datos.id_zona, datos.id_nodo),
            )
            id_punto = cur.fetchone()[0]
        conn.commit()
    return {"id_punto": id_punto, "mensaje": f"Punto '{datos.nombre}' creado."}


@app.put("/puntos/{id_punto}")
def editar_punto(id_punto: int, datos: DatosPunto, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE punto_acceso
                SET nombre = %s, ubicacion = %s, id_zona = %s, id_nodo = %s
                WHERE id_punto = %s RETURNING id_punto
                """,
                (datos.nombre, datos.ubicacion, datos.id_zona, datos.id_nodo, id_punto),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Punto de acceso no encontrado.")
        conn.commit()
    return {"mensaje": "Punto de acceso actualizado."}


@app.patch("/puntos/{id_punto}/habilitado")
def toggle_punto(id_punto: int, _: str = Depends(get_admin_actual)):
    """Habilita o deshabilita un punto de acceso."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE punto_acceso SET habilitado = NOT habilitado WHERE id_punto = %s RETURNING habilitado",
                (id_punto,),
            )
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Punto de acceso no encontrado.")
        conn.commit()
    return {"habilitado": row[0]}


@app.delete("/puntos/{id_punto}")
def eliminar_punto(id_punto: int, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM punto_acceso WHERE id_punto = %s RETURNING id_punto", (id_punto,))
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Punto de acceso no encontrado.")
        conn.commit()
    return {"mensaje": "Punto de acceso eliminado."}


# ==============================================================================
# ENDPOINTS — PERMISOS DE USUARIO
#
# Modelo de permisos:
#   1. usuario_zona:          acceso a todos los puntos de una zona
#   2. usuario_zona_exclusion: excepción puntual dentro de una zona asignada
#   3. usuario_punto:         acceso a un punto específico sin necesitar zona
#
# La verificación en /reconocer sigue este orden:
#   - ¿El usuario tiene acceso al punto directamente? → exitoso
#   - ¿El usuario tiene acceso a la zona del punto?
#       - ¿Tiene exclusión para este punto específico? → sin_permiso
#       - Si no → exitoso
#   - Si ninguna condición se cumple → sin_permiso
# ==============================================================================

@app.get("/usuarios/{id_usuario}/permisos")
def listar_permisos(id_usuario: int, _: str = Depends(get_admin_actual)):
    """
    Devuelve los permisos completos de un usuario:
    zonas asignadas, exclusiones dentro de esas zonas y puntos directos.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT z.id_zona, z.nombre FROM usuario_zona uz
                JOIN zona z ON z.id_zona = uz.id_zona
                WHERE uz.id_usuario = %s ORDER BY z.nombre
            """, (id_usuario,))
            zonas = [{"id_zona": r[0], "nombre": r[1]} for r in cur.fetchall()]

            cur.execute("""
                SELECT pa.id_punto, pa.nombre, z.nombre AS zona_nombre
                FROM usuario_zona_exclusion uze
                JOIN punto_acceso pa ON pa.id_punto = uze.id_punto_acceso
                JOIN zona z ON z.id_zona = pa.id_zona
                WHERE uze.id_usuario = %s ORDER BY pa.nombre
            """, (id_usuario,))
            exclusiones = [{"id_punto": r[0], "nombre": r[1], "zona_nombre": r[2]} for r in cur.fetchall()]

            cur.execute("""
                SELECT pa.id_punto, pa.nombre, z.nombre AS zona_nombre
                FROM usuario_punto up
                JOIN punto_acceso pa ON pa.id_punto = up.id_punto_acceso
                JOIN zona z ON z.id_zona = pa.id_zona
                WHERE up.id_usuario = %s ORDER BY pa.nombre
            """, (id_usuario,))
            puntos_directos = [{"id_punto": r[0], "nombre": r[1], "zona_nombre": r[2]} for r in cur.fetchall()]

    return {"zonas": zonas, "exclusiones": exclusiones, "puntos_directos": puntos_directos}


@app.post("/usuarios/{id_usuario}/zonas/{id_zona}", status_code=201)
def asignar_zona(id_usuario: int, id_zona: int, _: str = Depends(get_admin_actual)):
    """Otorga acceso a un usuario a todos los puntos de una zona."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO usuario_zona (id_usuario, id_zona) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (id_usuario, id_zona),
            )
        conn.commit()
    return {"mensaje": "Zona asignada."}


@app.delete("/usuarios/{id_usuario}/zonas/{id_zona}")
def quitar_zona(id_usuario: int, id_zona: int, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM usuario_zona WHERE id_usuario = %s AND id_zona = %s",
                (id_usuario, id_zona),
            )
        conn.commit()
    return {"mensaje": "Zona removida."}


@app.post("/usuarios/{id_usuario}/exclusiones/{id_punto}", status_code=201)
def agregar_exclusion(id_usuario: int, id_punto: int, _: str = Depends(get_admin_actual)):
    """Agrega una excepción: el usuario tiene acceso a la zona pero NO a este punto."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO usuario_zona_exclusion (id_usuario, id_punto_acceso) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (id_usuario, id_punto),
            )
        conn.commit()
    return {"mensaje": "Exclusión agregada."}


@app.delete("/usuarios/{id_usuario}/exclusiones/{id_punto}")
def quitar_exclusion(id_usuario: int, id_punto: int, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM usuario_zona_exclusion WHERE id_usuario = %s AND id_punto_acceso = %s",
                (id_usuario, id_punto),
            )
        conn.commit()
    return {"mensaje": "Exclusión removida."}


@app.post("/usuarios/{id_usuario}/puntos/{id_punto}", status_code=201)
def asignar_punto_directo(id_usuario: int, id_punto: int, _: str = Depends(get_admin_actual)):
    """Otorga acceso a un punto específico sin necesidad de asignar la zona completa."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO usuario_punto (id_usuario, id_punto_acceso) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (id_usuario, id_punto),
            )
        conn.commit()
    return {"mensaje": "Punto asignado."}


@app.delete("/usuarios/{id_usuario}/puntos/{id_punto}")
def quitar_punto_directo(id_usuario: int, id_punto: int, _: str = Depends(get_admin_actual)):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM usuario_punto WHERE id_usuario = %s AND id_punto_acceso = %s",
                (id_usuario, id_punto),
            )
        conn.commit()
    return {"mensaje": "Punto removido."}


# ==============================================================================
# ENDPOINTS — NODOS (protegidos)
# ==============================================================================

@app.post("/nodos/registrar")
def registrar_nodo_endpoint(datos: RegistroNodo):
    id_nodo = registrar_nodo(datos.hostname, datos.ip)
    return {"id_nodo": id_nodo, "mensaje": f"Nodo '{datos.hostname}' registrado con IP {datos.ip}"}


@app.get("/nodos")
def listar_nodos_endpoint(_: str = Depends(get_admin_actual)):
    return listar_nodos()


# ==============================================================================
# FRONTEND ESTÁTICO
# Sirve el build de React desde /frontend/dist
# ==============================================================================

_FRONTEND_DIST = pathlib.Path(__file__).parent.parent / "frontend" / "dist"

if _FRONTEND_DIST.exists():
    app.mount("/assets", StaticFiles(directory=_FRONTEND_DIST / "assets"), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    def serve_frontend(full_path: str):
        file = _FRONTEND_DIST / full_path
        if file.is_file():
            return FileResponse(file)
        return FileResponse(_FRONTEND_DIST / "index.html")
