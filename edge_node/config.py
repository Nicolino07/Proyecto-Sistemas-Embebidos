import os
from pathlib import Path

_env_file = Path(__file__).parent / ".env"
if _env_file.exists():
    for _line in _env_file.read_text().splitlines():
        if "=" in _line and not _line.startswith("#"):
            _k, _v = _line.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

_url = os.environ.get("SERVER_URL", "").strip()
if not _url:
    raise RuntimeError("SERVER_URL no configurada. Corré instalar.sh nuevamente.")

SERVER_URL = _url

# Procesar 1 de cada N frames para no sobrecargar la Raspberry.
FRAMES_A_SALTAR = 5

# Pin BCM del LED que se enciende al reconocer una cara (ej: GPIO 17 = pin físico 11).
LED_GPIO_PIN = 17
