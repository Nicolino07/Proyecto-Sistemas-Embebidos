import { useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../api/client";
import styles from "./Login.module.css";
import modalStyles from "./Administradores.module.css";

type Modo = "login" | "recover" | "recover-ok";

export default function Login() {
  const [modo, setModo] = useState<Modo>("login");

  // Login
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState("");
  const [loginLoading, setLoginLoading] = useState(false);

  // Recuperación
  const [rUsername, setRUsername] = useState("");
  const [rCode, setRCode] = useState("");
  const [rPassword, setRPassword] = useState("");
  const [rPassword2, setRPassword2] = useState("");
  const [rError, setRError] = useState("");
  const [rLoading, setRLoading] = useState(false);
  const [nuevoCode, setNuevoCode] = useState("");

  const navigate = useNavigate();

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoginError("");
    setLoginLoading(true);
    try {
      const form = new URLSearchParams();
      form.append("username", username);
      form.append("password", password);
      const res = await api.post("/admin/login", form);
      localStorage.setItem("token", res.data.access_token);
      navigate("/accesos");
    } catch {
      setLoginError("Usuario o contraseña incorrectos");
    } finally {
      setLoginLoading(false);
    }
  }

  async function handleRecover(e: React.FormEvent) {
    e.preventDefault();
    setRError("");

    if (rPassword !== rPassword2) {
      setRError("Las contraseñas no coinciden.");
      return;
    }
    if (rPassword.length < 8) {
      setRError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }

    setRLoading(true);
    try {
      const res = await api.post("/admin/recover", {
        username: rUsername,
        recovery_code: rCode.toUpperCase().trim(),
        nueva_password: rPassword,
      });
      setNuevoCode(res.data.recovery_code);
      setModo("recover-ok");
    } catch {
      setRError("Código de recuperación incorrecto o usuario inválido.");
    } finally {
      setRLoading(false);
    }
  }

  async function copiarNuevoCodigo() {
    await navigator.clipboard.writeText(nuevoCode);
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  if (modo === "login") {
    return (
      <div className={styles.wrapper}>
        <form className={styles.card} onSubmit={handleLogin}>
          <h1 className={styles.title}>Panel Admin</h1>
          <p className={styles.subtitle}>Sistema de Reconocimiento Facial</p>
          <div className={styles.field}>
            <label>Usuario</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              required
            />
          </div>
          <div className={styles.field}>
            <label>Contraseña</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </div>
          {loginError && <p className={styles.error}>{loginError}</p>}
          <button type="submit" className={styles.btn} disabled={loginLoading}>
            {loginLoading ? "Ingresando..." : "Ingresar"}
          </button>
          <button
            type="button"
            onClick={() => setModo("recover")}
            style={{ background: "none", border: "none", color: "#6c7086", fontSize: "0.82rem", cursor: "pointer", textAlign: "center" }}
          >
            ¿Olvidaste tu contraseña?
          </button>
        </form>
      </div>
    );
  }

  // ── Formulario de recuperación ─────────────────────────────────────────────
  if (modo === "recover") {
    return (
      <div className={styles.wrapper}>
        <form className={styles.card} onSubmit={handleRecover}>
          <h1 className={styles.title}>Recuperar acceso</h1>
          <p className={styles.subtitle}>Ingresá tu código de recuperación para establecer una nueva contraseña.</p>
          <div className={styles.field}>
            <label>Usuario</label>
            <input
              type="text"
              value={rUsername}
              onChange={(e) => setRUsername(e.target.value)}
              autoComplete="username"
              required
            />
          </div>
          <div className={styles.field}>
            <label>Código de recuperación</label>
            <input
              type="text"
              value={rCode}
              onChange={(e) => setRCode(e.target.value)}
              placeholder="XXXX-XXXX-XXXX-XXXX"
              autoComplete="off"
              required
              style={{ fontFamily: "monospace", letterSpacing: "0.08em" }}
            />
          </div>
          <div className={styles.field}>
            <label>Nueva contraseña</label>
            <input
              type="password"
              value={rPassword}
              onChange={(e) => setRPassword(e.target.value)}
              autoComplete="new-password"
              required
            />
          </div>
          <div className={styles.field}>
            <label>Repetir nueva contraseña</label>
            <input
              type="password"
              value={rPassword2}
              onChange={(e) => setRPassword2(e.target.value)}
              autoComplete="new-password"
              required
            />
          </div>
          {rError && <p className={styles.error}>{rError}</p>}
          <button type="submit" className={styles.btn} disabled={rLoading}>
            {rLoading ? "Verificando..." : "Cambiar contraseña"}
          </button>
          <button
            type="button"
            onClick={() => setModo("login")}
            style={{ background: "none", border: "none", color: "#6c7086", fontSize: "0.82rem", cursor: "pointer", textAlign: "center" }}
          >
            Volver al login
          </button>
        </form>
      </div>
    );
  }

  // ── Éxito: mostrar nuevo código ────────────────────────────────────────────
  return (
    <div className={styles.wrapper}>
      <div className={modalStyles.overlay}>
        <div className={modalStyles.modal} style={{ maxWidth: 460, gap: 18 }}>
          <h3 className={modalStyles.modalTitle}>Contraseña actualizada</h3>
          <p style={{ color: "#a6adc8", fontSize: "0.88rem", margin: 0 }}>
            Tu contraseña fue cambiada correctamente. Se generó un nuevo código de recuperación.
            <strong style={{ color: "#f38ba8" }}> Guardalo ahora, no se volverá a mostrar.</strong>
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
            {nuevoCode}
          </div>
          <div className={modalStyles.modalFooter}>
            <button type="button" className={modalStyles.btnSecondary} onClick={copiarNuevoCodigo}>
              Copiar
            </button>
            <button type="button" className={modalStyles.btnPrimary} onClick={() => navigate("/login")}>
              Ya lo guardé, ir al login
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
