import { useEffect, useState } from "react";
import api from "../api/client";
import styles from "./Page.module.css";
import modalStyles from "./Administradores.module.css";

interface Admin {
  id_admin: number;
  username: string;
  nombre: string;
  apellido: string;
  email: string | null;
  habilitado: boolean;
  creado_en: string;
  ultimo_acceso: string | null;
}

const FORM_VACIO = { username: "", nombre: "", apellido: "", email: "", password: "", password2: "" };

export default function Administradores() {
  const [admins, setAdmins] = useState<Admin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Modal crear/editar
  const [modalAbierto, setModalAbierto] = useState(false);
  const [editando, setEditando] = useState<Admin | null>(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [formError, setFormError] = useState("");
  const [guardando, setGuardando] = useState(false);

  // Modal código de recuperación
  const [recoveryCode, setRecoveryCode] = useState<string | null>(null);
  const [recoveryUsername, setRecoveryUsername] = useState("");

  async function cargar() {
    try {
      const res = await api.get<Admin[]>("/admin/admins");
      setAdmins(res.data);
    } catch {
      setError("No se pudo cargar la lista de administradores.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { cargar(); }, []);

  function abrirCrear() {
    setEditando(null);
    setForm(FORM_VACIO);
    setFormError("");
    setModalAbierto(true);
  }

  function abrirEditar(admin: Admin) {
    setEditando(admin);
    setForm({ username: admin.username, nombre: admin.nombre, apellido: admin.apellido, email: admin.email ?? "", password: "", password2: "" });
    setFormError("");
    setModalAbierto(true);
  }

  function cerrarModal() {
    setModalAbierto(false);
    setEditando(null);
    setFormError("");
  }

  async function guardar(e: React.FormEvent) {
    e.preventDefault();
    setFormError("");

    if (!editando && !form.password) {
      setFormError("La contraseña es obligatoria.");
      return;
    }
    if (form.password && form.password !== form.password2) {
      setFormError("Las contraseñas no coinciden.");
      return;
    }
    if (form.password && form.password.length < 8) {
      setFormError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }

    const payload = {
      username: form.username,
      nombre: form.nombre,
      apellido: form.apellido,
      email: form.email || undefined,
      password: form.password || undefined,
    };

    setGuardando(true);
    try {
      if (editando) {
        await api.put(`/admin/admins/${editando.id_admin}`, payload);
        cerrarModal();
        cargar();
      } else {
        const res = await api.post("/admin/admins", payload);
        cerrarModal();
        cargar();
        setRecoveryUsername(form.username);
        setRecoveryCode(res.data.recovery_code);
      }
    } catch (err: any) {
      setFormError(err.response?.data?.detail ?? "Error al guardar.");
    } finally {
      setGuardando(false);
    }
  }

  async function toggleHabilitado(admin: Admin) {
    const accion = admin.habilitado ? "deshabilitar" : "habilitar";
    if (!confirm(`¿${accion.charAt(0).toUpperCase() + accion.slice(1)} a ${admin.username}?`)) return;
    try {
      await api.patch(`/admin/admins/${admin.id_admin}/habilitado`);
      cargar();
    } catch (err: any) {
      alert(err.response?.data?.detail ?? `Error al ${accion}.`);
    }
  }

  async function regenerarCodigo(admin: Admin) {
    if (!confirm(`¿Generar un nuevo código de recuperación para ${admin.username}? El código anterior quedará inválido.`)) return;
    try {
      const res = await api.post(`/admin/admins/${admin.id_admin}/recovery-code`);
      setRecoveryUsername(admin.username);
      setRecoveryCode(res.data.recovery_code);
    } catch (err: any) {
      alert(err.response?.data?.detail ?? "Error al regenerar el código.");
    }
  }

  async function copiarCodigo() {
    if (recoveryCode) await navigator.clipboard.writeText(recoveryCode);
  }

  return (
    <div>
      <div className={styles.pageHeader}>
        <h2 className={styles.pageTitle}>Administradores</h2>
        <button className={modalStyles.btnPrimary} onClick={abrirCrear}>
          + Nuevo administrador
        </button>
      </div>

      {loading && <p className={styles.muted}>Cargando...</p>}
      {error && <p className={styles.error}>{error}</p>}

      {!loading && !error && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>#</th>
              <th>Usuario</th>
              <th>Nombre</th>
              <th>Email</th>
              <th>Estado</th>
              <th>Último acceso</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {admins.map((a) => (
              <tr key={a.id_admin}>
                <td className={styles.muted}>{a.id_admin}</td>
                <td>{a.username}</td>
                <td>{a.nombre} {a.apellido}</td>
                <td className={styles.muted}>{a.email ?? "—"}</td>
                <td>
                  <span className={styles.badge} style={{ color: a.habilitado ? "#a6e3a1" : "#f38ba8" }}>
                    {a.habilitado ? "Activo" : "Deshabilitado"}
                  </span>
                </td>
                <td className={styles.muted}>
                  {a.ultimo_acceso ? new Date(a.ultimo_acceso).toLocaleString("es-AR") : "—"}
                </td>
                <td className={modalStyles.acciones}>
                  <button className={styles.btnDanger} style={{ borderColor: "#cba6f7", color: "#cba6f7" }} onClick={() => abrirEditar(a)}>
                    Editar
                  </button>
                  <button className={styles.btnDanger} onClick={() => toggleHabilitado(a)}>
                    {a.habilitado ? "Deshabilitar" : "Habilitar"}
                  </button>
                  <button className={styles.btnDanger} style={{ borderColor: "#89b4fa", color: "#89b4fa" }} onClick={() => regenerarCodigo(a)}>
                    Cód. recuperación
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {/* Modal crear / editar */}
      {modalAbierto && (
        <div className={modalStyles.overlay} onClick={cerrarModal}>
          <form className={modalStyles.modal} onSubmit={guardar} onClick={(e) => e.stopPropagation()}>
            <h3 className={modalStyles.modalTitle}>
              {editando ? "Editar administrador" : "Nuevo administrador"}
            </h3>

            {(["username", "nombre", "apellido", "email"] as const).map((campo) => (
              <div className={modalStyles.field} key={campo}>
                <label>{campo.charAt(0).toUpperCase() + campo.slice(1)}{campo === "email" ? " (opcional)" : ""}</label>
                <input
                  type={campo === "email" ? "email" : "text"}
                  value={form[campo]}
                  onChange={(e) => setForm((p) => ({ ...p, [campo]: e.target.value }))}
                  required={campo !== "email"}
                />
              </div>
            ))}

            <div className={modalStyles.field}>
              <label>{editando ? "Nueva contraseña (dejar vacío para no cambiar)" : "Contraseña"}</label>
              <input
                type="password"
                value={form.password}
                onChange={(e) => setForm((p) => ({ ...p, password: e.target.value }))}
                required={!editando}
                autoComplete="new-password"
              />
            </div>

            {form.password && (
              <div className={modalStyles.field}>
                <label>Repetir contraseña</label>
                <input
                  type="password"
                  value={form.password2}
                  onChange={(e) => setForm((p) => ({ ...p, password2: e.target.value }))}
                  required
                  autoComplete="new-password"
                />
              </div>
            )}

            {formError && <p className={styles.error}>{formError}</p>}

            <div className={modalStyles.modalFooter}>
              <button type="button" className={modalStyles.btnSecondary} onClick={cerrarModal}>
                Cancelar
              </button>
              <button type="submit" className={modalStyles.btnPrimary} disabled={guardando}>
                {guardando ? "Guardando..." : "Guardar"}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal código de recuperación */}
      {recoveryCode && (
        <div className={modalStyles.overlay}>
          <div className={modalStyles.modal} style={{ maxWidth: 460, gap: 18 }}>
            <h3 className={modalStyles.modalTitle}>Código de recuperación — {recoveryUsername}</h3>
            <p style={{ color: "#a6adc8", fontSize: "0.88rem", margin: 0 }}>
              El administrador debe guardar este código en un lugar seguro.
              <strong style={{ color: "#f38ba8" }}> Solo se muestra una vez.</strong>{" "}
              Si lo pierde, se puede regenerar desde este panel.
            </p>
            <div style={{
              background: "#1e1e2e",
              border: "1px solid #45475a",
              borderRadius: 8,
              padding: "14px 16px",
              textAlign: "center",
              fontFamily: "monospace",
              fontSize: "1.25rem",
              letterSpacing: "0.12em",
              color: "#cba6f7",
              userSelect: "all",
            }}>
              {recoveryCode}
            </div>
            <div className={modalStyles.modalFooter}>
              <button type="button" className={modalStyles.btnSecondary} onClick={copiarCodigo}>
                Copiar
              </button>
              <button type="button" className={modalStyles.btnPrimary} onClick={() => setRecoveryCode(null)}>
                Ya lo guardé
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
