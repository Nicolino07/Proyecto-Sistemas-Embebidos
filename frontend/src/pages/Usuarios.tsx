import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";

interface Usuario {
  id_usuario: number;
  nombre: string;
  apellido: string;
  creado_en: string;
  fotos_registradas: number;
}

export default function Usuarios() {
  const [usuarios, setUsuarios] = useState<Usuario[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function cargar() {
    try {
      const res = await api.get<Usuario[]>("/usuarios");
      setUsuarios(res.data);
    } catch {
      setError("No se pudo cargar la lista de usuarios");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { cargar(); }, []);

  async function eliminar(id: number, nombre: string) {
    if (!confirm(`¿Eliminar a ${nombre}? Esta acción no se puede deshacer.`)) return;
    try {
      await api.delete(`/usuarios/${id}`);
      setUsuarios((prev) => prev.filter((u) => u.id_usuario !== id));
    } catch {
      alert("Error al eliminar el usuario");
    }
  }

  return (
    <div>
      <h2 className={styles.pageTitle}>Usuarios</h2>
      {loading && <p className={styles.muted}>Cargando...</p>}
      {error && <p className={styles.error}>{error}</p>}
      {!loading && !error && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>#</th>
              <th>Nombre</th>
              <th>Apellido</th>
              <th>Fotos</th>
              <th>Registrado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {usuarios.map((u) => (
              <tr key={u.id_usuario}>
                <td className={styles.muted}>{u.id_usuario}</td>
                <td>{u.nombre}</td>
                <td>{u.apellido}</td>
                <td>{u.fotos_registradas}</td>
                <td className={styles.muted}>
                  {new Date(u.creado_en).toLocaleDateString("es-AR")}
                </td>
                <td>
                  <button
                    className={styles.btnDanger}
                    onClick={() => eliminar(u.id_usuario, `${u.nombre} ${u.apellido}`)}
                  >
                    Eliminar
                  </button>
                </td>
              </tr>
            ))}
            {usuarios.length === 0 && (
              <tr>
                <td colSpan={6} className={styles.muted} style={{ textAlign: "center" }}>
                  No hay usuarios registrados
                </td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
