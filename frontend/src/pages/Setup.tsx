import { useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../api/client";
import styles from "./Login.module.css";
import extraStyles from "./Setup.module.css";
import modalStyles from "./Administradores.module.css";

interface Campo {
  id: string;
  label: string;
  type: string;
  required: boolean;
  placeholder?: string;
}

const CAMPOS: Campo[] = [
  { id: "username",  label: "Nombre de usuario",   type: "text",     required: true  },
  { id: "nombre",    label: "Nombre",               type: "text",     required: true  },
  { id: "apellido",  label: "Apellido",             type: "text",     required: true  },
  { id: "email",     label: "Email (opcional)",     type: "email",    required: false },
  { id: "password",  label: "Contraseña",           type: "password", required: true  },
  { id: "password2", label: "Repetir contraseña",   type: "password", required: true  },
];

export default function Setup() {
  const [form, setForm] = useState<Record<string, string>>({});
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [recoveryCode, setRecoveryCode] = useState<string | null>(null);
  const navigate = useNavigate();

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setForm((prev) => ({ ...prev, [e.target.id]: e.target.value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    if (form.password !== form.password2) {
      setError("Las contraseñas no coinciden.");
      return;
    }
    if (form.password.length < 8) {
      setError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }

    setLoading(true);
    try {
      const res = await api.post("/admin/setup", {
        username: form.username,
        password: form.password,
        nombre: form.nombre,
        apellido: form.apellido,
        email: form.email || undefined,
      });
      setRecoveryCode(res.data.recovery_code);
    } catch (err: any) {
      if (err.response?.status === 409) {
        navigate("/login");
      } else {
        setError("Error al crear el administrador. Intentá de nuevo.");
      }
    } finally {
      setLoading(false);
    }
  }

  async function copiar() {
    if (recoveryCode) await navigator.clipboard.writeText(recoveryCode);
  }

  return (
    <div className={styles.wrapper}>
      <form className={styles.card} onSubmit={handleSubmit}>
        <h1 className={styles.title}>Configuración inicial</h1>
        <p className={styles.subtitle}>
          Creá el administrador master para comenzar a usar el sistema.
        </p>

        <div className={extraStyles.divider} />

        {CAMPOS.map((campo) => (
          <div className={styles.field} key={campo.id}>
            <label htmlFor={campo.id}>{campo.label}</label>
            <input
              id={campo.id}
              type={campo.type}
              value={form[campo.id] ?? ""}
              onChange={handleChange}
              required={campo.required}
              autoComplete={campo.type === "password" ? "new-password" : campo.id}
            />
          </div>
        ))}

        {error && <p className={styles.error}>{error}</p>}

        <button type="submit" className={styles.btn} disabled={loading}>
          {loading ? "Creando administrador..." : "Crear administrador y continuar"}
        </button>
      </form>

      {recoveryCode && (
        <div className={modalStyles.overlay}>
          <div className={modalStyles.modal} style={{ maxWidth: 460, gap: 18 }}>
            <h3 className={modalStyles.modalTitle}>Guardá tu código de recuperación</h3>
            <p style={{ color: "#a6adc8", fontSize: "0.88rem", margin: 0 }}>
              Si olvidás tu contraseña, este código te permite recuperar el acceso.
              <strong style={{ color: "#f38ba8" }}> Solo se muestra una vez.</strong>{" "}
              Guardalo en un lugar seguro.
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
              <button type="button" className={modalStyles.btnSecondary} onClick={copiar}>
                Copiar
              </button>
              <button
                type="button"
                className={modalStyles.btnPrimary}
                onClick={() => navigate("/login")}
              >
                Ya lo guardé, continuar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
