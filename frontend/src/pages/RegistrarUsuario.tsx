import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../api/client";
import styles from "./Page.module.css";
import camStyles from "./RegistrarUsuario.module.css";

const FOTOS_REQUERIDAS = 10;

type Etapa = "formulario" | "camara" | "listo";

export default function RegistrarUsuario() {
  const navigate = useNavigate();

  const [documento, setDocumento] = useState("");
  const [nombre, setNombre] = useState("");
  const [apellido, setApellido] = useState("");

  const [etapa, setEtapa] = useState<Etapa>("formulario");
  const [fotosCapturadas, setFotosCapturadas] = useState(0);
  const [error, setError] = useState("");
  const [enviando, setEnviando] = useState(false);

  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  // Asigna el stream al <video> una vez que el elemento existe en el DOM.
  // setEtapa("camara") hace re-render y monta el <video>; este efecto se
  // dispara justo después, cuando videoRef.current ya no es null.
  useEffect(() => {
    if (etapa === "camara" && videoRef.current && streamRef.current) {
      videoRef.current.srcObject = streamRef.current;
    }
  }, [etapa]);

  async function abrirCamara(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: "user" },
      });
      streamRef.current = stream;
      setEtapa("camara"); // el useEffect de arriba conecta el stream al <video>
    } catch {
      setError("No se pudo acceder a la cámara. Verificá los permisos del navegador.");
    }
  }

  function cerrarCamara() {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }

  async function capturarFoto() {
    if (!videoRef.current || !canvasRef.current || enviando) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d")!.drawImage(video, 0, 0);

    canvas.toBlob(async (blob) => {
      if (!blob) return;
      setEnviando(true);
      setError("");

      const formData = new FormData();
      formData.append("documento", documento);
      formData.append("nombre", nombre);
      formData.append("apellido", apellido);
      formData.append("imagen", blob, "foto.jpg");

      try {
        await api.post("/registrar/imagen", formData);
        setFotosCapturadas((prev) => {
          const nuevas = prev + 1;
          if (nuevas >= FOTOS_REQUERIDAS) {
            cerrarCamara();
            setEtapa("listo");
          }
          return nuevas;
        });
      } catch (err: any) {
        setError(err.response?.data?.detail ?? "Error al procesar la imagen.");
      } finally {
        setEnviando(false);
      }
    }, "image/jpeg", 0.9);
  }

  function cancelar() {
    cerrarCamara();
    setEtapa("formulario");
    setFotosCapturadas(0);
    setError("");
  }

  return (
    <div>
      <h2 className={styles.pageTitle}>Registrar usuario</h2>

      {/* ETAPA 1 — Datos del usuario */}
      {etapa === "formulario" && (
        <form className={camStyles.form} onSubmit={abrirCamara}>
          <div className={camStyles.field}>
            <label>Documento (DNI)</label>
            <input value={documento} onChange={(e) => setDocumento(e.target.value)} required />
          </div>
          <div className={camStyles.field}>
            <label>Nombre</label>
            <input value={nombre} onChange={(e) => setNombre(e.target.value)} required />
          </div>
          <div className={camStyles.field}>
            <label>Apellido</label>
            <input value={apellido} onChange={(e) => setApellido(e.target.value)} required />
          </div>
          {error && <p className={styles.error}>{error}</p>}
          <button type="submit" className={camStyles.btnPrimary}>
            Continuar y abrir cámara
          </button>
        </form>
      )}

      {/* ETAPA 2 — Captura de fotos */}
      {etapa === "camara" && (
        <div className={camStyles.camaraWrapper}>
          <p className={camStyles.instruccion}>
            Mirá a la cámara y presioná <strong>Tomar foto</strong>.
            Necesitamos <strong>{FOTOS_REQUERIDAS} fotos</strong> desde distintos ángulos.
          </p>

          <div className={camStyles.videoContainer}>
            {/* autoPlay necesario para que el stream se reproduzca sin interacción del usuario */}
            <video ref={videoRef} className={camStyles.video} autoPlay muted playsInline />
            <canvas ref={canvasRef} style={{ display: "none" }} />

            <div className={camStyles.progreso}>
              {Array.from({ length: FOTOS_REQUERIDAS }).map((_, i) => (
                <div
                  key={i}
                  className={`${camStyles.punto} ${i < fotosCapturadas ? camStyles.puntoOk : ""}`}
                />
              ))}
            </div>
          </div>

          <p className={camStyles.contador}>
            {fotosCapturadas} / {FOTOS_REQUERIDAS} fotos
          </p>

          {error && <p className={styles.error}>{error}</p>}

          <div className={camStyles.acciones}>
            <button className={camStyles.btnSecondary} onClick={cancelar}>
              Cancelar
            </button>
            <button className={camStyles.btnPrimary} onClick={capturarFoto} disabled={enviando}>
              {enviando ? "Procesando..." : "Tomar foto"}
            </button>
          </div>
        </div>
      )}

      {/* ETAPA 3 — Registro completado */}
      {etapa === "listo" && (
        <div className={camStyles.listo}>
          <div className={camStyles.checkmark}>✓</div>
          <h3>Registro completado</h3>
          <p>
            <strong>{nombre} {apellido}</strong> fue registrado correctamente
            con {FOTOS_REQUERIDAS} fotos.
          </p>
          <div className={camStyles.acciones}>
            <button
              className={camStyles.btnSecondary}
              onClick={() => {
                setEtapa("formulario");
                setDocumento(""); setNombre(""); setApellido("");
                setFotosCapturadas(0);
              }}
            >
              Registrar otro
            </button>
            <button className={camStyles.btnPrimary} onClick={() => navigate("/usuarios")}>
              Ver usuarios
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
