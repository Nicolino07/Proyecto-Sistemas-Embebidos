# ==============================================================================
# Configuración del edge node (Raspberry Pi)
# Cambiar SERVER_URL por la IP real del servidor cuando estén en red local.
# Ejemplo: SERVER_URL = "http://192.168.1.100:8000"
# ==============================================================================

# URL del servidor FastAPI que corre en la PC
SERVER_URL = "http://localhost:8000"

# Índice de la cámara (0 = primera webcam disponible)
CAMARA_INDEX = 2

# Procesar 1 de cada N frames para no sobrecargar la Raspberry.
# Con 5, si la cámara corre a 15fps, se analiza ~3 rostros por segundo.
FRAMES_A_SALTAR = 5
