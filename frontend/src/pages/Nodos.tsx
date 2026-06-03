import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";

interface Nodo {
  id_nodo: number;
  hostname: string;
  ip: string;
  ultimo_inicio: string;
  creado_en: string;
}

export default function Nodos() {
  const [nodos, setNodos] = useState<Nodo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get<Nodo[]>("/nodos")
      .then((res) => setNodos(res.data))
      .catch(() => setError("No se pudo cargar la lista de nodos"))
      .finally(() => setLoading(false));
  }, []);

  function minutosDesde(fecha: string) {
    const diff = (Date.now() - new Date(fecha).getTime()) / 1000 / 60;
    if (diff < 60) return `hace ${Math.round(diff)} min`;
    if (diff < 1440) return `hace ${Math.round(diff / 60)} h`;
    return `hace ${Math.round(diff / 1440)} días`;
  }

  function estaActivo(fecha: string) {
    const diff = (Date.now() - new Date(fecha).getTime()) / 1000 / 60;
    return diff < 5;
  }

  return (
    <div>
      <h2 className={styles.pageTitle}>Nodos</h2>
      {loading && <p className={styles.muted}>Cargando...</p>}
      {error && <p className={styles.error}>{error}</p>}
      {!loading && !error && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>#</th>
              <th>Hostname</th>
              <th>IP</th>
              <th>Estado</th>
              <th>Último inicio</th>
              <th>Registrado</th>
            </tr>
          </thead>
          <tbody>
            {nodos.map((n) => (
              <tr key={n.id_nodo}>
                <td className={styles.muted}>{n.id_nodo}</td>
                <td>{n.hostname}</td>
                <td className={styles.mono}>{n.ip}</td>
                <td>
                  <span
                    className={styles.badge}
                    style={{ color: estaActivo(n.ultimo_inicio) ? "#a6e3a1" : "#6c7086" }}
                  >
                    {estaActivo(n.ultimo_inicio) ? "En línea" : minutosDesde(n.ultimo_inicio)}
                  </span>
                </td>
                <td className={styles.muted}>
                  {new Date(n.ultimo_inicio).toLocaleString("es-AR")}
                </td>
                <td className={styles.muted}>
                  {new Date(n.creado_en).toLocaleDateString("es-AR")}
                </td>
              </tr>
            ))}
            {nodos.length === 0 && (
              <tr>
                <td colSpan={6} className={styles.muted} style={{ textAlign: "center" }}>
                  No hay nodos registrados
                </td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
