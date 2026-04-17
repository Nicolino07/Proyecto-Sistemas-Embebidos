-- Habilitar la extensión de vectores (pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

-- Tabla de usuarios: datos personales, sin vectores
-- Un usuario puede tener múltiples fotos registradas (ver tabla rostro_vector)
CREATE TABLE usuario (
    id_usuario SERIAL PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    apellido   VARCHAR(100) NOT NULL,
    email      VARCHAR(255) UNIQUE,           -- Opcional, puede ser NULL en registros por cámara
    creado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de vectores faciales: cada fila es una foto registrada de un usuario
-- Separada de usuario para permitir múltiples fotos por persona y mejorar el reconocimiento
CREATE TABLE rostro_vector (
    id_vector  SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    vector     vector(128) NOT NULL,
    creado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de accesos: log de cada intento de reconocimiento facial
CREATE TABLE accesos (
    id_acceso           SERIAL PRIMARY KEY,
    id_usuario          INTEGER REFERENCES usuario(id_usuario) ON DELETE SET NULL,
    fecha_hora          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    captura_path        TEXT,
    distancia_calculada FLOAT,
    es_exitoso          BOOLEAN DEFAULT FALSE
);

-- Índice HNSW para búsquedas vectoriales rápidas usando distancia coseno
-- Actúa sobre la tabla rostro_vector, no sobre usuario
CREATE INDEX ON rostro_vector USING hnsw (vector vector_cosine_ops);
