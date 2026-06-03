import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";
import m from "./Administradores.module.css";

interface Zona {
  id_zona: number;
  nombre: string;
  descripcion: string | null;
  puntos: number;
}

interface Punto {
  id_punto: number;
  nombre: string;
  ubicacion: string | null;
  habilitado: boolean;
  id_zona: number;
  zona_nombre: string;
  id_nodo: number | null;
  nodo_hostname: string | null;
  nodo_ip: string | null;
}

interface Nodo {
  id_nodo: number;
  hostname: string;
  ip: string;
}

export default function Zonas() {
  const [zonas, setZonas] = useState<Zona[]>([]);
  const [puntos, setPuntos] = useState<Punto[]>([]);
  const [nodos, setNodos] = useState<Nodo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Modal zona
  const [modalZona, setModalZona] = useState(false);
  const [editZona, setEditZona] = useState<Zona | null>(null);
  const [formZona, setFormZona] = useState({ nombre: "", descripcion: "" });

  // Modal punto
  const [modalPunto, setModalPunto] = useState(false);
  const [editPunto, setEditPunto] = useState<Punto | null>(null);
  const [formPunto, setFormPunto] = useState({ nombre: "", ubicacion: "", id_zona: "", id_nodo: "" });

  const [guardando, setGuardando] = useState(false);
  const [formError, setFormError] = useState("");

  async function cargar() {
    try {
      const [rZonas, rPuntos, rNodos] = await Promise.all([
        api.get<Zona[]>("/zonas"),
        api.get<Punto[]>("/puntos"),
        api.get<Nodo[]>("/nodos"),
      ]);
      setZonas(rZonas.data);
      setPuntos(rPuntos.data);
      setNodos(rNodos.data);
    } catch {
      setError("No se pudieron cargar los datos.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { cargar(); }, []);

  // ── Zonas ──────────────────────────────────────────────────────────────────
  function abrirCrearZona() {
    setEditZona(null); setFormZona({ nombre: "", descripcion: "" });
    setFormError(""); setModalZona(true);
  }
  function abrirEditarZona(z: Zona) {
    setEditZona(z); setFormZona({ nombre: z.nombre, descripcion: z.descripcion ?? "" });
    setFormError(""); setModalZona(true);
  }
  async function guardarZona(e: React.FormEvent) {
    e.preventDefault(); setGuardando(true); setFormError("");
    try {
      if (editZona) await api.put(`/zonas/${editZona.id_zona}`, formZona);
      else await api.post("/zonas", formZona);
      setModalZona(false); cargar();
    } catch (err: any) { setFormError(err.response?.data?.detail ?? "Error al guardar."); }
    finally { setGuardando(false); }
  }
  async function eliminarZona(z: Zona) {
    if (!confirm(`¿Eliminar la zona "${z.nombre}"? Primero eliminá sus puntos de acceso.`)) return;
    try { await api.delete(`/zonas/${z.id_zona}`); cargar(); }
    catch (err: any) { alert(err.response?.data?.detail ?? "Error al eliminar."); }
  }

  // ── Puntos ─────────────────────────────────────────────────────────────────
  function abrirCrearPunto() {
    setEditPunto(null);
    setFormPunto({ nombre: "", ubicacion: "", id_zona: zonas[0]?.id_zona.toString() ?? "", id_nodo: "" });
    setFormError(""); setModalPunto(true);
  }
  function abrirEditarPunto(p: Punto) {
    setEditPunto(p);
    setFormPunto({ nombre: p.nombre, ubicacion: p.ubicacion ?? "", id_zona: p.id_zona.toString(), id_nodo: p.id_nodo?.toString() ?? "" });
    setFormError(""); setModalPunto(true);
  }
  async function guardarPunto(e: React.FormEvent) {
    e.preventDefault(); setGuardando(true); setFormError("");
    const payload = {
      nombre: formPunto.nombre,
      ubicacion: formPunto.ubicacion || undefined,
      id_zona: parseInt(formPunto.id_zona),
      id_nodo: formPunto.id_nodo ? parseInt(formPunto.id_nodo) : null,
    };
    try {
      if (editPunto) await api.put(`/puntos/${editPunto.id_punto}`, payload);
      else await api.post("/puntos", payload);
      setModalPunto(false); cargar();
    } catch (err: any) { setFormError(err.response?.data?.detail ?? "Error al guardar."); }
    finally { setGuardando(false); }
  }
  async function togglePunto(p: Punto) {
    try { await api.patch(`/puntos/${p.id_punto}/habilitado`); cargar(); }
    catch { alert("Error al cambiar estado."); }
  }
  async function eliminarPunto(p: Punto) {
    if (!confirm(`¿Eliminar el punto "${p.nombre}"?`)) return;
    try { await api.delete(`/puntos/${p.id_punto}`); cargar(); }
    catch (err: any) { alert(err.response?.data?.detail ?? "Error al eliminar."); }
  }

  if (loading) return <p className={styles.muted}>Cargando...</p>;
  if (error) return <p className={styles.error}>{error}</p>;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 40 }}>

      {/* ── ZONAS ── */}
      <div>
        <div className={styles.pageHeader}>
          <h2 className={styles.pageTitle}>Zonas</h2>
          <button className={m.btnPrimary} onClick={abrirCrearZona}>+ Nueva zona</button>
        </div>
        <table className={styles.table}>
          <thead><tr><th>#</th><th>Nombre</th><th>Descripción</th><th>Puntos</th><th></th></tr></thead>
          <tbody>
            {zonas.map((z) => (
              <tr key={z.id_zona}>
                <td className={styles.muted}>{z.id_zona}</td>
                <td>{z.nombre}</td>
                <td className={styles.muted}>{z.descripcion ?? "—"}</td>
                <td>{z.puntos}</td>
                <td className={m.acciones}>
                  <button className={styles.btnDanger} style={{ borderColor: "#cba6f7", color: "#cba6f7" }} onClick={() => abrirEditarZona(z)}>Editar</button>
                  <button className={styles.btnDanger} onClick={() => eliminarZona(z)}>Eliminar</button>
                </td>
              </tr>
            ))}
            {zonas.length === 0 && <tr><td colSpan={5} className={styles.muted} style={{ textAlign: "center" }}>No hay zonas</td></tr>}
          </tbody>
        </table>
      </div>

      {/* ── PUNTOS DE ACCESO ── */}
      <div>
        <div className={styles.pageHeader}>
          <h2 className={styles.pageTitle}>Puntos de acceso</h2>
          <button className={m.btnPrimary} onClick={abrirCrearPunto} disabled={zonas.length === 0}>+ Nuevo punto</button>
        </div>
        {zonas.length === 0 && <p className={styles.muted}>Creá una zona primero para poder agregar puntos.</p>}
        <table className={styles.table}>
          <thead><tr><th>#</th><th>Nombre</th><th>Zona</th><th>Nodo asignado</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {puntos.map((p) => (
              <tr key={p.id_punto}>
                <td className={styles.muted}>{p.id_punto}</td>
                <td>{p.nombre}{p.ubicacion && <span className={styles.muted}> · {p.ubicacion}</span>}</td>
                <td className={styles.muted}>{p.zona_nombre}</td>
                <td className={styles.mono}>{p.nodo_hostname ?? <span className={styles.muted}>Sin asignar</span>}</td>
                <td>
                  <span className={styles.badge} style={{ color: p.habilitado ? "#a6e3a1" : "#f38ba8" }}>
                    {p.habilitado ? "Habilitado" : "Deshabilitado"}
                  </span>
                </td>
                <td className={m.acciones}>
                  <button className={styles.btnDanger} style={{ borderColor: "#cba6f7", color: "#cba6f7" }} onClick={() => abrirEditarPunto(p)}>Editar</button>
                  <button className={styles.btnDanger} onClick={() => togglePunto(p)}>{p.habilitado ? "Deshabilitar" : "Habilitar"}</button>
                  <button className={styles.btnDanger} onClick={() => eliminarPunto(p)}>Eliminar</button>
                </td>
              </tr>
            ))}
            {puntos.length === 0 && <tr><td colSpan={6} className={styles.muted} style={{ textAlign: "center" }}>No hay puntos de acceso</td></tr>}
          </tbody>
        </table>
      </div>

      {/* Modal Zona */}
      {modalZona && (
        <div className={m.overlay} onClick={() => setModalZona(false)}>
          <form className={m.modal} onSubmit={guardarZona} onClick={(e) => e.stopPropagation()}>
            <h3 className={m.modalTitle}>{editZona ? "Editar zona" : "Nueva zona"}</h3>
            <div className={m.field}><label>Nombre</label>
              <input value={formZona.nombre} onChange={(e) => setFormZona(p => ({ ...p, nombre: e.target.value }))} required />
            </div>
            <div className={m.field}><label>Descripción (opcional)</label>
              <input value={formZona.descripcion} onChange={(e) => setFormZona(p => ({ ...p, descripcion: e.target.value }))} />
            </div>
            {formError && <p className={styles.error}>{formError}</p>}
            <div className={m.modalFooter}>
              <button type="button" className={m.btnSecondary} onClick={() => setModalZona(false)}>Cancelar</button>
              <button type="submit" className={m.btnPrimary} disabled={guardando}>{guardando ? "Guardando..." : "Guardar"}</button>
            </div>
          </form>
        </div>
      )}

      {/* Modal Punto */}
      {modalPunto && (
        <div className={m.overlay} onClick={() => setModalPunto(false)}>
          <form className={m.modal} onSubmit={guardarPunto} onClick={(e) => e.stopPropagation()}>
            <h3 className={m.modalTitle}>{editPunto ? "Editar punto de acceso" : "Nuevo punto de acceso"}</h3>
            <div className={m.field}><label>Nombre</label>
              <input value={formPunto.nombre} onChange={(e) => setFormPunto(p => ({ ...p, nombre: e.target.value }))} required />
            </div>
            <div className={m.field}><label>Ubicación (opcional)</label>
              <input value={formPunto.ubicacion} onChange={(e) => setFormPunto(p => ({ ...p, ubicacion: e.target.value }))} />
            </div>
            <div className={m.field}><label>Zona</label>
              <select className={styles.select} value={formPunto.id_zona} onChange={(e) => setFormPunto(p => ({ ...p, id_zona: e.target.value }))} required>
                {zonas.map((z) => <option key={z.id_zona} value={z.id_zona}>{z.nombre}</option>)}
              </select>
            </div>
            <div className={m.field}><label>Nodo (Raspberry Pi) — opcional</label>
              <select className={styles.select} value={formPunto.id_nodo} onChange={(e) => setFormPunto(p => ({ ...p, id_nodo: e.target.value }))}>
                <option value="">Sin asignar</option>
                {nodos.map((n) => <option key={n.id_nodo} value={n.id_nodo}>{n.hostname} ({n.ip})</option>)}
              </select>
            </div>
            {formError && <p className={styles.error}>{formError}</p>}
            <div className={m.modalFooter}>
              <button type="button" className={m.btnSecondary} onClick={() => setModalPunto(false)}>Cancelar</button>
              <button type="submit" className={m.btnPrimary} disabled={guardando}>{guardando ? "Guardando..." : "Guardar"}</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
