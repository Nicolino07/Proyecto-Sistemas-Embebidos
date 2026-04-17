import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

from server.database import get_connection

# get_connection() abre una conexión con PostgreSQL (ver server/database.py).
# El bloque "with" la cierra automáticamente al terminar.
with get_connection() as conn:
    # El cursor es el objeto que ejecuta las consultas SQL y guarda los resultados.
    with conn.cursor() as cur:

        # ── TABLA USUARIO ──────────────────────────────────────────────────────
        # Traemos todos los usuarios registrados, ordenados por id.
        # No pedimos el rostro_vector porque son 128 números y no sirve mostrarlo.
        print("--- Personas registradas (tabla usuario) ---")
        cur.execute("SELECT id_usuario, nombre, apellido, email, creado_en FROM usuario ORDER BY id_usuario")
        usuarios = cur.fetchall()  # fetchall() trae todas las filas como lista de tuplas
        if not usuarios:
            print("No hay usuarios registrados.")
        for id_u, nombre, apellido, email, creado_en in usuarios:
            print(f"ID: {id_u} | Nombre: {nombre} {apellido} | Email: {email} | Registrado: {creado_en}")

        # ── TABLA ACCESOS ──────────────────────────────────────────────────────
        # Hacemos un JOIN entre accesos y usuario para mostrar el nombre en lugar del id.
        # LEFT JOIN significa: traé todos los accesos, y si tiene usuario asociado mostrá
        # su nombre; si el usuario es NULL (desconocido) igual mostrá el acceso.
        print("\n--- Últimos 20 accesos (tabla accesos) ---")
        cur.execute("""
            SELECT a.id_acceso, u.nombre, u.apellido, a.fecha_hora, a.distancia_calculada, a.es_exitoso
            FROM accesos a
            LEFT JOIN usuario u ON a.id_usuario = u.id_usuario
            ORDER BY a.fecha_hora DESC
            LIMIT 20
        """)
        accesos = cur.fetchall()
        if not accesos:
            print("No hay accesos registrados.")
        for id_a, nombre, apellido, fecha, distancia, exitoso in accesos:
            persona = f"{nombre} {apellido}" if nombre else "Desconocido"
            estado = "OK" if exitoso else "FALLO"
            # distancia puede ser None si no había nadie en la DB al momento del acceso
            dist_str = f"{distancia:.4f}" if distancia is not None else "N/A"
            print(f"ID: {id_a} | {persona} | {fecha} | Distancia: {dist_str} | {estado}")
