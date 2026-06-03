import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import ProtectedRoute from "./components/ProtectedRoute";
import SetupGuard from "./components/SetupGuard";
import Accesos from "./pages/Accesos";
import Administradores from "./pages/Administradores";
import Login from "./pages/Login";
import Nodos from "./pages/Nodos";
import Permisos from "./pages/Permisos";
import RegistrarUsuario from "./pages/RegistrarUsuario";
import Setup from "./pages/Setup";
import Usuarios from "./pages/Usuarios";
import Zonas from "./pages/Zonas";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* SetupGuard verifica si existe algún admin antes de mostrar el login.
            Si no hay ninguno, redirige automáticamente a /setup. */}
        <Route
          path="/login"
          element={
            <SetupGuard>
              <Login />
            </SetupGuard>
          }
        />

        {/* Configuración inicial: solo accesible si no hay admins registrados.
            El endpoint POST /admin/setup devuelve 409 si ya existe uno. */}
        <Route path="/setup" element={<Setup />} />

        <Route
          element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to="/accesos" replace />} />
          <Route path="/accesos" element={<Accesos />} />
          <Route path="/usuarios" element={<Usuarios />} />
          <Route path="/registrar-usuario" element={<RegistrarUsuario />} />
          <Route path="/permisos" element={<Permisos />} />
          <Route path="/zonas" element={<Zonas />} />
          <Route path="/nodos" element={<Nodos />} />
          <Route path="/administradores" element={<Administradores />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
