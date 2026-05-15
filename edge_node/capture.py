from insightface.app import FaceAnalysis
import cv2
import numpy as np
import requests
import socket
from gpiozero import LED
from config import SERVER_URL, FRAMES_A_SALTAR, LED_GPIO_PIN
from detectar_camaras import detectar_camaras

_face_app = FaceAnalysis(name='buffalo_sc', providers=['CPUExecutionProvider'])
_face_app.prepare(ctx_id=0, det_size=(320, 320))


def get_faces(frame):
    faces = _face_app.get(frame)
    result = []
    for face in faces:
        x1, y1, x2, y2 = face.bbox.astype(int)
        result.append((y1, x2, y2, x1, face.embedding))
    return result


def _get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "desconocida"


try:
    requests.post(
        f"{SERVER_URL}/nodos/registrar",
        json={"hostname": socket.gethostname(), "ip": _get_local_ip()},
        timeout=5,
    )
    print(f"Nodo registrado en el servidor ({SERVER_URL}).")
except Exception:
    print("Advertencia: no se pudo registrar el nodo. El servidor puede no estar disponible.")


camaras = detectar_camaras()

if not camaras:
    print("Error: no se encontró ninguna cámara conectada.")
    exit(1)
elif len(camaras) == 1:
    indice = camaras[0]
    print(f"Usando cámara {indice}.")
else:
    print(f"Cámaras disponibles: {camaras}")
    seleccion = input(f"Elegí el índice de la cámara a usar {camaras}: ")
    try:
        indice = int(seleccion)
        if indice not in camaras:
            raise ValueError
    except ValueError:
        print(f"Índice inválido. Usando cámara {camaras[0]} por defecto.")
        indice = camaras[0]

camera = cv2.VideoCapture(indice)

modo = input("Elegí el modo (1 = registro / 2 = reconocimiento): ")

# ============================================================= MODO 1: REGISTRO =============================================================
if modo == "1":
    documento = input("Documento (DNI): ")
    nombre = input("Nombre de la persona: ")
    apellido = input("Apellido de la persona: ")
    print("Mostrando cámara... presioná 's' para capturar el rostro (podés tomar varias fotos!)")

    while True:
        success, frame = camera.read()
        if not success or frame is None:
            print("Error con la cámara")
            break

        cv2.imshow("Registro", frame)
        key = cv2.waitKey(1) & 0xFF

        if key == ord('s'):
            faces = get_faces(frame)
            if len(faces) == 0:
                print("No se detectó un rostro")
                continue

            _, _, _, _, encoding = faces[0]

            respuesta = requests.post(
                f"{SERVER_URL}/registrar",
                json={"documento": documento, "nombre": nombre, "apellido": apellido, "vector": encoding.tolist()},
            )

            if respuesta.status_code == 200:
                datos = respuesta.json()
                print(f"Rostro de {nombre} {apellido} guardado (id={datos['id_usuario']}).")
            else:
                print(f"Error al registrar: {respuesta.text}")

        elif key == 27:
            break

# ========================================================== MODO 2: RECONOCIMIENTO ==========================================================
elif modo == "2":
    print("Modo reconocimiento activo. ESC para salir.")

    led = LED(LED_GPIO_PIN)
    frame_count = 0
    ultimo_resultado = {}

    while True:
        success, frame = camera.read()
        if not success or frame is None:
            print("Error con la cámara")
            break

        frame_count += 1

        if frame_count % FRAMES_A_SALTAR == 0:
            faces = get_faces(frame)
            nuevo_resultado = {}

            for top, right, bottom, left, encoding in faces:
                try:
                    respuesta = requests.post(
                        f"{SERVER_URL}/reconocer",
                        json={"vector": encoding.tolist()},
                        timeout=5,
                    )
                    if respuesta.status_code == 200:
                        datos = respuesta.json()
                        nombre = datos["nombre"]
                        es_exitoso = datos["es_exitoso"]
                        distancia = datos.get("distancia")
                    else:
                        nombre, es_exitoso, distancia = "Error servidor", False, None
                except requests.exceptions.ConnectionError:
                    nombre, es_exitoso, distancia = "Sin conexion", False, None

                nuevo_resultado[(top, right, bottom, left)] = (nombre, es_exitoso, distancia)

            ultimo_resultado = nuevo_resultado if faces else {}

            if any(es_exitoso for _, es_exitoso, _ in ultimo_resultado.values()):
                led.on()
            else:
                led.off()

        for (top, right, bottom, left), (nombre, es_exitoso, distancia) in ultimo_resultado.items():
            color = (0, 255, 0) if es_exitoso else (0, 0, 255)
            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
            if es_exitoso:
                label = nombre
            elif nombre in ("Sin conexion", "Error servidor"):
                label = nombre
            elif distancia:
                label = f"Desconocido ({distancia:.2f})"
            else:
                label = "Desconocido"
            cv2.putText(frame, label, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)

        cv2.imshow("Reconocimiento", frame)

        if cv2.waitKey(1) & 0xFF == 27:
            break

    led.off()

camera.release()
cv2.destroyAllWindows()
