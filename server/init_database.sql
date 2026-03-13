-- Habilitar la extensión de vectores
CREATE EXTENSION IF NOT EXISTS vector;

-- Tabla de usuarios
CREATE TABLE usuario (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    rostro_vector vector(128), 
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de accesos (intentos de reconocimiento facial)
CREATE TABLE accesos (
    id_acceso SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuario(id_usuario) ON DELETE SET NULL, -- NULL si es desconocido
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    captura_path TEXT, 
    distancia_calculada FLOAT,
    es_exitoso BOOLEAN DEFAULT FALSE -- Para filtrar rápido entradas vs intentos fallidos
);

-- esto no se bien que es pero lo dejo por si acaso

-- Índice para búsquedas vectoriales ultra rápidas
-- El parámetro 'cosine' es muy común en reconocimiento facial, 
-- pero si usas 'l2' (distancia euclidiana) cámbialo a vector_l2_ops
CREATE INDEX ON usuario USING hnsw (rostro_vector vector_cosine_ops);