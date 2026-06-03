import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";

interface Acceso {
  id_acceso: number;
  nombre_usuario: string | null;
  fecha_hora: string;
  resultado: "exitoso" | "sin_permiso" | "no_reconocido";
  distancia_calculada: number | null;
  punto_acceso: string | null;
}

const RESULTADO_LABEL: Record<Acceso["resultado"], string> = {
  exitoso: "Exitoso",
  sin_permiso: "Sin permiso",
  no_reconocido: "No reconocido",
};

const RESULTADO_COLOR: Record<Acceso["resultado"], string> = {
  exitoso: "#a6e3a1",
  sin_permiso: "#fab387",
  no_reconocido: "#f38ba8",
};

export default function Accesos() {
  const [accesos, setAccesos] = useState<Acceso[]>([]);
  const [filtro, setFiltro] = useState<string>("todos");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get<Acceso[]>("/accesos")
      .then((res) => setAccesos(res.data))
      .catch(() => setError("No se pudo cargar el historial de accesos"))
      .finally(() => setLoading(false));
  }, []);

  const filtrados = filtro === "todos"
    ? accesos
    : accesos.filter((a) => a.resultado === filtro);

  return (
    <div>
      <div className={styles.pageHeader}>
        <h2 className={styles.pageTitle}>Accesos</h2>
        <select
          className={styles.select}
          value={filtro}
          onChange={(e) => setFiltro(e.target.value)}
        >
          <option value="todos">Todos</option>
          <option value="exitoso">Exitosos</option>
          <option value="sin_permiso">Sin permiso</option>
          <option value="no_reconocido">No reconocidos</option>
        </select>
      </div>
      {loading && <p className={styles.muted}>Cargando...</p>}
      {error && <p className={styles.error}>{error}</p>}
      {!loading && !error && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>#</th>
              <th>Usuario</th>
              <th>Punto de acceso</th>
              <th>Resultado</th>
              <th>Distancia</th>
              <th>Fecha y hora</th>
            </tr>
          </thead>
          <tbody>
            {filtrados.map((a) => (
              <tr key={a.id_acceso}>
                <td className={styles.muted}>{a.id_acceso}</td>
                <td>{a.nombre_usuario ?? <span className={styles.muted}>Desconocido</span>}</td>
                <td className={styles.muted}>{a.punto_acceso ?? "—"}</td>
                <td>
                  <span
                    className={styles.badge}
                    style={{ color: RESULTADO_COLOR[a.resultado] }}
                  >
                    {RESULTADO_LABEL[a.resultado]}
                  </span>
                </td>
                <td className={styles.muted}>
                  {a.distancia_calculada != null
                    ? a.distancia_calculada.toFixed(3)
                    : "—"}
                </td>
                <td className={styles.muted}>
                  {new Date(a.fecha_hora).toLocaleString("es-AR")}
                </td>
              </tr>
            ))}
            {filtrados.length === 0 && (
              <tr>
                <td colSpan={6} className={styles.muted} style={{ textAlign: "center" }}>
                  No hay registros
                </td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
