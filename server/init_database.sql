-- Habilitar la extensión de vectores (pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TYPE resultado_acceso AS ENUM (
    'exitoso',           -- reconocido y con permiso
    'sin_permiso',       -- reconocido pero sin permiso
    'no_reconocido'      -- rostro desconocido (SF05)
);

-- Tabla de usuarios: datos personales, sin vectores
-- Un usuario puede tener múltiples fotos registradas (ver tabla rostro_vector)
CREATE TABLE usuario (
    id_usuario SERIAL PRIMARY KEY,
    documento  VARCHAR(50) UNIQUE NOT NULL,            -- DNI o número de identificación único  
    nombre     VARCHAR(100) NOT NULL,
    apellido   VARCHAR(100) NOT NULL,
    email      VARCHAR(255) UNIQUE,           -- Opcional, puede ser NULL en registros por cámara
    legajo     VARCHAR(50) UNIQUE,            -- Opcional UNICO, puede ser NULL en registros por cámara
    creado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de administradores: acceso solo al panel de administración
-- Entidad independiente de usuario, sin rostro registrado
CREATE TABLE administrador (
    id_admin    SERIAL PRIMARY KEY,
    username    VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,        -- hash bcrypt o argon2, nunca texto plano
    nombre      VARCHAR(100),
    apellido    VARCHAR(100),
    email       VARCHAR(255) UNIQUE,
    habilitado  BOOLEAN DEFAULT TRUE,
    creado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP             -- para auditoría de sesiones
);

-- Tabla de vectores faciales: cada fila es una foto registrada de un usuario
-- Separada de usuario para permitir múltiples fotos por persona y mejorar el reconocimiento
CREATE TABLE rostro_vector (
    id_vector  SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    vector     vector(128) NOT NULL,
    creado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Zona agrupa puntos de acceso
CREATE TABLE zona (
    id_zona     SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    descripcion TEXT,
    creado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Punto de acceso pertenece a una zona
CREATE TABLE punto_acceso (
    id_punto    SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    ubicacion   VARCHAR(255),
    id_zona     INTEGER NOT NULL REFERENCES zona(id_zona) ON DELETE RESTRICT,
    habilitado  BOOLEAN DEFAULT TRUE,
    creado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Acceso por zona completa
CREATE TABLE usuario_zona (
    id_usuario  INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_zona     INTEGER NOT NULL REFERENCES zona(id_zona) ON DELETE CASCADE,
    creado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_zona)
);

-- Exclusiones puntuales dentro de una zona asignada
CREATE TABLE usuario_zona_exclusion (
    id_usuario      INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_punto_acceso INTEGER NOT NULL REFERENCES punto_acceso(id_punto) ON DELETE CASCADE,
    creado_en       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_punto_acceso)
);

-- Acceso a punto específico sin zona
CREATE TABLE usuario_punto (
    id_usuario      INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_punto_acceso INTEGER NOT NULL REFERENCES punto_acceso(id_punto) ON DELETE CASCADE,
    creado_en       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_punto_acceso)
);

-- Tabla de accesos: log de cada intento de reconocimiento facial
-- Registra tanto accesos exitosos como fallidos (SF05)
-- Enum: exitoso, sin_permiso, no_reconocido
CREATE TABLE accesos (
    id_acceso           SERIAL PRIMARY KEY,
    id_usuario          INTEGER REFERENCES usuario(id_usuario) ON DELETE SET NULL,
    id_punto_acceso     INTEGER REFERENCES punto_acceso(id_punto) ON DELETE SET NULL,
    fecha_hora          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    distancia_calculada FLOAT,
    resultado           resultado_acceso NOT NULL  
);

-- Índice HNSW para búsquedas vectoriales rápidas usando distancia coseno
-- Actúa sobre la tabla rostro_vector, no sobre usuario
CREATE INDEX ON rostro_vector USING hnsw (vector vector_cosine_ops);
