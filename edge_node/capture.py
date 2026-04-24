# ==============================================================================
# LIBRERIA requests
# Permite hacer llamadas HTTP desde Python. Es el equivalente a abrir el navegador
# y escribir una URL, pero desde código. Acá lo usamos para comunicar la Raspberry
# con el servidor FastAPI que corre en la PC.
#
# requests.post(url, json=datos) → envía datos en formato JSON al servidor
# respuesta.json()               → convierte la respuesta del servidor a diccionario Python
# ==============================================================================
import face_recognition
import cv2
import numpy as np
import requests
from config import SERVER_URL, FRAMES_A_SALTAR
from detectar_camaras import detectar_camaras

# Detectar cámaras disponibles y dejar al usuario elegir
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

# ========================== MODO ==========================
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

        # OpenCV usa BGR, face_recognition necesita RGB
        rgb_frame = np.ascontiguousarray(frame[:, :, ::-1], dtype=np.uint8)
        cv2.imshow("Registro", frame)
        key = cv2.waitKey(1) & 0xFF

        if key == ord('s'):
            face_locations = face_recognition.face_locations(rgb_frame)
            if len(face_locations) == 0:
                print("No se detectó un rostro")
                continue

            face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)
            if len(face_encodings) == 0:
                print("No se pudo generar encoding")
                continue

            encoding = face_encodings[0]

            # Enviamos el vector al servidor por HTTP en lugar de escribir en la DB directamente.
            # .tolist() convierte el numpy array a lista de Python, que es serializable a JSON.
            respuesta = requests.post(
                f"{SERVER_URL}/registrar",
                json={"documento": documento, "nombre": nombre, "apellido": apellido, "vector": encoding.tolist()},
            )

            if respuesta.status_code == 200:
                datos = respuesta.json()
                print(f"Rostro de {nombre} {apellido} guardado (id={datos['id_usuario']}).")
            else:
                print(f"Error al registrar: {respuesta.text}")

        elif key == 27:  # ESC para salir
            break

# ========================================================== MODO 2: RECONOCIMIENTO ==========================================================
elif modo == "2":
    print("Modo reconocimiento activo. ESC para salir.")

    # Contador de frames para implementar el salto de frames
    frame_count = 0
    # Guardamos el último resultado para mostrarlo en los frames que salteamos
    ultimo_resultado = {}

    while True:
        success, frame = camera.read()
        if not success or frame is None:
            print("Error con la cámara")
            break

        frame_count += 1

        # Solo procesamos 1 de cada FRAMES_A_SALTAR frames.
        # En los frames que salteamos, mostramos el último resultado conocido.
        # Esto hace que el video sea fluido aunque el reconocimiento sea lento.
        if frame_count % FRAMES_A_SALTAR == 0:
            rgb_frame = np.ascontiguousarray(frame[:, :, ::-1], dtype=np.uint8)
            face_locations = face_recognition.face_locations(rgb_frame)

            if len(face_locations) > 0:
                face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)
                nuevo_resultado = {}

                for (top, right, bottom, left), encoding in zip(face_locations, face_encodings):
                    # Enviamos el vector al servidor y recibimos el nombre
                    try:
                        respuesta = requests.post(
                            f"{SERVER_URL}/reconocer",
                            json={"vector": encoding.tolist()},
                            timeout=5,  # si el servidor no responde en 5 segs, seguimos
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

                ultimo_resultado = nuevo_resultado
            else:
                ultimo_resultado = {}

        # Dibujamos el último resultado conocido sobre el frame actual
        for (top, right, bottom, left), (nombre, es_exitoso, distancia) in ultimo_resultado.items():
            color = (0, 255, 0) if es_exitoso else (0, 0, 255)
            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
            label = nombre if es_exitoso else f"Desconocido ({distancia:.2f})" if distancia else "Desconocido"
            cv2.putText(frame, label, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)

        cv2.imshow("Reconocimiento", frame)

        if cv2.waitKey(1) & 0xFF == 27:
            break

camera.release()
cv2.destroyAllWindows()
