import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";
import m from "./Administradores.module.css";

interface Usuario { id_usuario: number; nombre: string; apellido: string; }
interface Zona    { id_zona: number; nombre: string; }
interface Punto   { id_punto: number; nombre: string; zona_nombre: string; id_zona: number; }
interface Permisos {
  zonas: { id_zona: number; nombre: string }[];
  exclusiones: { id_punto: number; nombre: string; zona_nombre: string }[];
  puntos_directos: { id_punto: number; nombre: string; zona_nombre: string }[];
}

export default function Permisos() {
  const [usuarios, setUsuarios] = useState<Usuario[]>([]);
  const [zonas, setZonas] = useState<Zona[]>([]);
  const [puntos, setPuntos] = useState<Punto[]>([]);
  const [usuarioSel, setUsuarioSel] = useState<Usuario | null>(null);
  const [permisos, setPermisos] = useState<Permisos | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    Promise.all([
      api.get<Usuario[]>("/usuarios"),
      api.get<Zona[]>("/zonas"),
      api.get<Punto[]>("/puntos"),
    ]).then(([u, z, p]) => {
      setUsuarios(u.data);
      setZonas(z.data);
      setPuntos(p.data);
    }).catch(() => setError("Error al cargar datos."))
      .finally(() => setLoading(false));
  }, []);

  async function seleccionarUsuario(u: Usuario) {
    setUsuarioSel(u);
    setPermisos(null);
    const res = await api.get<Permisos>(`/usuarios/${u.id_usuario}/permisos`);
    setPermisos(res.data);
  }

  async function asignarZona(id_zona: number) {
    if (!usuarioSel) return;
    await api.post(`/usuarios/${usuarioSel.id_usuario}/zonas/${id_zona}`);
    seleccionarUsuario(usuarioSel);
  }
  async function quitarZona(id_zona: number) {
    if (!usuarioSel) return;
    await api.delete(`/usuarios/${usuarioSel.id_usuario}/zonas/${id_zona}`);
    seleccionarUsuario(usuarioSel);
  }
  async function agregarExclusion(id_punto: number) {
    if (!usuarioSel) return;
    await api.post(`/usuarios/${usuarioSel.id_usuario}/exclusiones/${id_punto}`);
    seleccionarUsuario(usuarioSel);
  }
  async function quitarExclusion(id_punto: number) {
    if (!usuarioSel) return;
    await api.delete(`/usuarios/${usuarioSel.id_usuario}/exclusiones/${id_punto}`);
    seleccionarUsuario(usuarioSel);
  }
  async function asignarPunto(id_punto: number) {
    if (!usuarioSel) return;
    await api.post(`/usuarios/${usuarioSel.id_usuario}/puntos/${id_punto}`);
    seleccionarUsuario(usuarioSel);
  }
  async function quitarPunto(id_punto: number) {
    if (!usuarioSel) return;
    await api.delete(`/usuarios/${usuarioSel.id_usuario}/puntos/${id_punto}`);
    seleccionarUsuario(usuarioSel);
  }

  if (loading) return <p className={styles.muted}>Cargando...</p>;
  if (error)   return <p className={styles.error}>{error}</p>;

  const zonasAsignadasIds = new Set(permisos?.zonas.map(z => z.id_zona));
  const exclusionesIds    = new Set(permisos?.exclusiones.map(p => p.id_punto));
  const puntosDirectosIds = new Set(permisos?.puntos_directos.map(p => p.id_punto));

  // Puntos de las zonas asignadas (candidatos a exclusión)
  const puntosDeZonasAsignadas = puntos.filter(p => zonasAsignadasIds.has(p.id_zona));

  return (
    <div style={{ display: "flex", gap: 32, alignItems: "flex-start" }}>

      {/* ── Columna izquierda: lista de usuarios ── */}
      <div style={{ width: 240, flexShrink: 0 }}>
        <h2 className={styles.pageTitle}>Permisos</h2>
        <p className={styles.muted} style={{ fontSize: "0.82rem", marginBottom: 12 }}>
          Seleccioná un usuario para gestionar sus permisos.
        </p>
        <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
          {usuarios.map((u) => (
            <button
              key={u.id_usuario}
              onClick={() => seleccionarUsuario(u)}
              style={{
                background: usuarioSel?.id_usuario === u.id_usuario ? "#45475a" : "none",
                border: "1px solid #45475a",
                borderRadius: 8,
                color: "#cdd6f4",
                padding: "8px 12px",
                textAlign: "left",
                cursor: "pointer",
                fontSize: "0.9rem",
              }}
            >
              {u.nombre} {u.apellido}
            </button>
          ))}
          {usuarios.length === 0 && <p className={styles.muted}>No hay usuarios registrados.</p>}
        </div>
      </div>

      {/* ── Columna derecha: permisos del usuario seleccionado ── */}
      <div style={{ flex: 1 }}>
        {!usuarioSel && (
          <p className={styles.muted} style={{ marginTop: 48 }}>← Seleccioná un usuario</p>
        )}

        {usuarioSel && !permisos && <p className={styles.muted}>Cargando permisos...</p>}

        {usuarioSel && permisos && (
          <div style={{ display: "flex", flexDirection: "column", gap: 32 }}>
            <h3 style={{ color: "#cba6f7", margin: 0 }}>
              {usuarioSel.nombre} {usuarioSel.apellido}
            </h3>

            {/* Zonas */}
            <Section titulo="Acceso por zona" descripcion="El usuario puede entrar a todos los puntos de estas zonas (salvo exclusiones).">
              <table className={styles.table}>
                <thead><tr><th>Zona</th><th></th></tr></thead>
                <tbody>
                  {zonas.map((z) => {
                    const asignada = zonasAsignadasIds.has(z.id_zona);
                    return (
                      <tr key={z.id_zona}>
                        <td>{z.nombre}</td>
                        <td>
                          {asignada
                            ? <button className={styles.btnDanger} onClick={() => quitarZona(z.id_zona)}>Quitar</button>
                            : <button className={m.btnPrimary} style={{ padding: "5px 12px", fontSize: "0.82rem" }} onClick={() => asignarZona(z.id_zona)}>Asignar</button>
                          }
                        </td>
                      </tr>
                    );
                  })}
                  {zonas.length === 0 && <tr><td colSpan={2} className={styles.muted}>No hay zonas creadas.</td></tr>}
                </tbody>
              </table>
            </Section>

            {/* Exclusiones */}
            {puntosDeZonasAsignadas.length > 0 && (
              <Section titulo="Exclusiones" descripcion="Puntos dentro de las zonas asignadas a los que este usuario NO puede acceder.">
                <table className={styles.table}>
                  <thead><tr><th>Punto</th><th>Zona</th><th></th></tr></thead>
                  <tbody>
                    {puntosDeZonasAsignadas.map((p) => {
                      const excluido = exclusionesIds.has(p.id_punto);
                      return (
                        <tr key={p.id_punto}>
                          <td>{p.nombre}</td>
                          <td className={styles.muted}>{p.zona_nombre}</td>
                          <td>
                            {excluido
                              ? <button className={m.btnPrimary} style={{ padding: "5px 12px", fontSize: "0.82rem" }} onClick={() => quitarExclusion(p.id_punto)}>Quitar exclusión</button>
                              : <button className={styles.btnDanger} onClick={() => agregarExclusion(p.id_punto)}>Excluir</button>
                            }
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </Section>
            )}

            {/* Puntos directos */}
            <Section titulo="Acceso a puntos específicos" descripcion="Acceso a puntos individuales sin necesidad de asignar la zona completa.">
              <table className={styles.table}>
                <thead><tr><th>Punto</th><th>Zona</th><th></th></tr></thead>
                <tbody>
                  {puntos.map((p) => {
                    const asignado = puntosDirectosIds.has(p.id_punto);
                    return (
                      <tr key={p.id_punto}>
                        <td>{p.nombre}</td>
                        <td className={styles.muted}>{p.zona_nombre}</td>
                        <td>
                          {asignado
                            ? <button className={styles.btnDanger} onClick={() => quitarPunto(p.id_punto)}>Quitar</button>
                            : <button className={m.btnPrimary} style={{ padding: "5px 12px", fontSize: "0.82rem" }} onClick={() => asignarPunto(p.id_punto)}>Asignar</button>
                          }
                        </td>
                      </tr>
                    );
                  })}
                  {puntos.length === 0 && <tr><td colSpan={3} className={styles.muted}>No hay puntos de acceso creados.</td></tr>}
                </tbody>
              </table>
            </Section>
          </div>
        )}
      </div>
    </div>
  );
}

function Section({ titulo, descripcion, children }: { titulo: string; descripcion: string; children: React.ReactNode }) {
  return (
    <div>
      <h4 style={{ color: "#cdd6f4", margin: "0 0 4px" }}>{titulo}</h4>
      <p style={{ color: "#6c7086", fontSize: "0.82rem", margin: "0 0 12px" }}>{descripcion}</p>
      {children}
    </div>
  );
}
