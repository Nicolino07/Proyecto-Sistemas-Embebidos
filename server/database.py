# ==============================================================================
# LIBRERIA psycopg2
# Es el "conector" entre Python y PostgreSQL. Funciona como un intermediario:
# vos escribís código Python, y psycopg2 lo traduce a comandos que entiende
# la base de datos. Sin esta librería, Python no sabe cómo hablarle a Postgres.
# ==============================================================================
import psycopg2
import numpy as np
import os
from dotenv import load_dotenv

# Carga las variables del archivo .env (DB_HOST, DB_PORT, etc.)
# Cuando corre dentro de Docker, las variables vienen del docker-compose.yml
# Cuando corre localmente, las lee del archivo .env
load_dotenv()

DB_CONFIG = {
    "dbname": "facial_recognition",
    "user": "admin",
    "password": "admin123",
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5435")),
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


def guardar_usuario(documento, nombre, apellido, encoding_vector):
    """
    Busca si el usuario ya existe por documento.
    Si existe, agrega un nuevo vector a su registro.
    Si no existe, crea el usuario y agrega el vector.
    Devuelve el id_usuario.
    """
    vector_lista = encoding_vector.tolist()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id_usuario FROM usuario WHERE documento = %s",
                (documento,),
            )
            row = cur.fetchone()

            if row:
                id_usuario = row[0]
            else:
                cur.execute(
                    "INSERT INTO usuario (documento, nombre, apellido) VALUES (%s, %s, %s) RETURNING id_usuario",
                    (documento, nombre, apellido),
                )
                id_usuario = cur.fetchone()[0]

            cur.execute(
                "INSERT INTO rostro_vector (id_usuario, vector) VALUES (%s, %s::vector)",
                (id_usuario, str(vector_lista)),
            )
        conn.commit()
    return id_usuario


def cargar_encodings():
    """
    Devuelve (lista de arrays numpy, lista de nombres, lista de ids de usuario)
    leyendo de la tabla rostro_vector con JOIN a usuario.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT u.id_usuario, u.nombre, u.apellido, rv.vector
                FROM rostro_vector rv
                JOIN usuario u ON rv.id_usuario = u.id_usuario
            """)
            rows = cur.fetchall()

    ids, nombres, encodings = [], [], []
    for id_usuario, nombre, apellido, vector_str in rows:
        vector = np.array([float(x) for x in vector_str.strip("[]").split(",")])
        ids.append(id_usuario)
        nombres.append(f"{nombre} {apellido}")
        encodings.append(vector)

    return encodings, nombres, ids


def buscar_usuario_por_encoding(encoding_vector, umbral=0.4):
    """
    Busca el usuario más parecido usando distancia coseno (pgvector <=>).
    Busca en rostro_vector y hace JOIN con usuario para obtener el nombre.

    Distancia coseno: 0.0 = idénticos, 0.4 = parecidos, 1.0+ = desconocido
    """
    vector_lista = encoding_vector.tolist()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT u.id_usuario, u.nombre, u.apellido,
                       rv.vector <=> %s::vector AS distancia
                FROM rostro_vector rv
                JOIN usuario u ON rv.id_usuario = u.id_usuario
                ORDER BY distancia ASC
                LIMIT 1
                """,
                (str(vector_lista),),
            )
            row = cur.fetchone()

    if row is None:
        return None, "Desconocido", None

    id_usuario, nombre, apellido, distancia = row
    if distancia > umbral:
        return None, "Desconocido", distancia

    return id_usuario, f"{nombre} {apellido}", distancia


def registrar_nodo(hostname, ip):
    """
    Registra o actualiza un nodo edge por su hostname.
    Se llama cada vez que la Raspberry arranca capture.py.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO nodo_edge (hostname, ip, ultimo_inicio)
                VALUES (%s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (hostname) DO UPDATE
                    SET ip = EXCLUDED.ip,
                        ultimo_inicio = CURRENT_TIMESTAMP
                RETURNING id_nodo
                """,
                (hostname, ip),
            )
            id_nodo = cur.fetchone()[0]
        conn.commit()
    return id_nodo


def listar_nodos():
    """
    Devuelve todos los nodos edge registrados con su última IP conocida.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id_nodo, hostname, ip, ultimo_inicio, creado_en FROM nodo_edge ORDER BY ultimo_inicio DESC"
            )
            rows = cur.fetchall()
    return [
        {
            "id_nodo": r[0],
            "hostname": r[1],
            "ip": r[2],
            "ultimo_inicio": r[3],
            "creado_en": r[4],
        }
        for r in rows
    ]


def registrar_acceso(id_usuario, distancia, resultado):
    """
    Inserta un registro en la tabla accesos.
    resultado: 'exitoso' | 'sin_permiso' | 'no_reconocido'
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO accesos (id_usuario, distancia_calculada, resultado)
                VALUES (%s, %s, %s)
                """,
                (id_usuario, distancia, resultado),
            )
        conn.commit()
