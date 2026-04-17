# ==============================================================================
# LIBRERIA psycopg2
# Es el "conector" entre Python y PostgreSQL. Funciona como un intermediario:
# vos escribís código Python, y psycopg2 lo traduce a comandos que entiende
# la base de datos. Sin esta librería, Python no sabe cómo hablarle a Postgres.
# ==============================================================================
import psycopg2
import numpy as np

# ==============================================================================
# CONFIGURACION DE LA BASE DE DATOS
# Estos datos tienen que coincidir con lo que pusiste en docker-compose.yml.
# En un proyecto real esto iría en un archivo .env para no hardcodear contraseñas.
# ==============================================================================
DB_CONFIG = {
    "dbname": "facial_recognition",
    "user": "admin",
    "password": "admin123",
    "host": "localhost",
    "port": 5434,
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


def guardar_usuario(nombre, apellido, encoding_vector):
    """
    Busca si el usuario ya existe por nombre+apellido.
    Si existe, agrega un nuevo vector a su registro.
    Si no existe, crea el usuario y agrega el vector.
    Devuelve el id_usuario.
    """
    vector_lista = encoding_vector.tolist()
    with get_connection() as conn:
        with conn.cursor() as cur:
            # Buscar si el usuario ya existe
            cur.execute(
                "SELECT id_usuario FROM usuario WHERE nombre = %s AND apellido = %s",
                (nombre, apellido),
            )
            row = cur.fetchone()

            if row:
                # Ya existe — solo agregamos el nuevo vector
                id_usuario = row[0]
            else:
                # No existe — creamos el usuario primero
                cur.execute(
                    "INSERT INTO usuario (nombre, apellido) VALUES (%s, %s) RETURNING id_usuario",
                    (nombre, apellido),
                )
                id_usuario = cur.fetchone()[0]

            # Insertamos el vector en la tabla rostro_vector
            # El ::vector convierte el string al tipo vector de pgvector
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


def registrar_acceso(id_usuario, distancia, es_exitoso, captura_path=None):
    """Inserta un registro en la tabla accesos."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO accesos (id_usuario, distancia_calculada, es_exitoso, captura_path)
                VALUES (%s, %s, %s, %s)
                """,
                (id_usuario, distancia, es_exitoso, captura_path),
            )
        conn.commit()
