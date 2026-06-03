import { useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import api from "../api/client";

interface Props {
  /** Página que se muestra solo si el setup YA fue completado (ej: Login). */
  children: React.ReactNode;
}

/**
 * Guarda de configuración inicial.
 *
 * Consulta GET /admin/setup/status al montar el componente:
 *   - Si necesita_setup = true  → redirige a /setup
 *   - Si necesita_setup = false → renderiza children (Login)
 *
 * Mientras resuelve la consulta muestra una pantalla en blanco para evitar
 * parpadeos. Si la API no responde (servidor caído) deja pasar al login
 * para no bloquear indefinidamente la interfaz.
 */
export default function SetupGuard({ children }: Props) {
  const [estado, setEstado] = useState<"cargando" | "setup" | "ok">("cargando");

  useEffect(() => {
    api
      .get<{ necesita_setup: boolean }>("/admin/setup/status")
      .then((res) => setEstado(res.data.necesita_setup ? "setup" : "ok"))
      .catch(() => setEstado("ok")); // Si falla la API, dejamos pasar al login
  }, []);

  if (estado === "cargando") return (
    <div style={{ minHeight: "100vh", background: "#1e1e2e", display: "flex", alignItems: "center", justifyContent: "center", color: "#6c7086", fontFamily: "system-ui" }}>
      Cargando...
    </div>
  );
  if (estado === "setup") return <Navigate to="/setup" replace />;
  return <>{children}</>;
}
