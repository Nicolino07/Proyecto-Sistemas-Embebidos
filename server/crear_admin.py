"""
Crea o actualiza un administrador en la base de datos.
Uso: python -m server.crear_admin
"""
import getpass
import bcrypt
from server.database import get_connection


def main():
    print("=== Crear administrador ===")
    username = input("Username: ").strip()
    nombre = input("Nombre: ").strip()
    apellido = input("Apellido: ").strip()
    email = input("Email (opcional): ").strip() or None
    password = getpass.getpass("Contraseña: ")
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO administrador (username, password_hash, nombre, apellido, email)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (username) DO UPDATE
                    SET password_hash = EXCLUDED.password_hash,
                        nombre = EXCLUDED.nombre,
                        apellido = EXCLUDED.apellido,
                        email = EXCLUDED.email,
                        habilitado = TRUE
                RETURNING id_admin
                """,
                (username, password_hash, nombre, apellido, email),
            )
            id_admin = cur.fetchone()[0]
        conn.commit()

    print(f"Admin '{username}' guardado con id={id_admin}.")


if __name__ == "__main__":
    main()
