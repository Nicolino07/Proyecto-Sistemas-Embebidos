import { NavLink, Outlet, useNavigate } from "react-router-dom";
import styles from "./Layout.module.css";

const NAV_ITEMS = [
  { to: "/accesos",           label: "Accesos" },
  { to: "/usuarios",          label: "Usuarios" },
  { to: "/registrar-usuario", label: "Registrar usuario" },
  { to: "/permisos",          label: "Permisos" },
  { to: "/zonas",             label: "Zonas y puntos" },
  { to: "/nodos",             label: "Nodos" },
  { to: "/administradores",   label: "Administradores" },
];

export default function Layout() {
  const navigate = useNavigate();

  function cerrarSesion() {
    localStorage.removeItem("token");
    navigate("/login");
  }

  return (
    <div className={styles.shell}>
      <aside className={styles.sidebar}>
        <div className={styles.logo}>Panel Admin</div>
        <nav className={styles.nav}>
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `${styles.link} ${isActive ? styles.active : ""}`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <button className={styles.logout} onClick={cerrarSesion}>
          Cerrar sesión
        </button>
      </aside>
      <main className={styles.main}>
        <Outlet />
      </main>
    </div>
  );
}
