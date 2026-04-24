import cv2

def detectar_camaras():
    disponibles = []
    for i in range(10):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, _ = cap.read()
            if ret:
                disponibles.append(i)
        cap.release()
    return disponibles

if __name__ == "__main__":
    print("Detectando cámaras disponibles...")
    camaras = detectar_camaras()

    if not camaras:
        print("No se encontró ninguna cámara.")
        exit(1)

    if len(camaras) == 1:
        print(f"Cámara encontrada: índice {camaras[0]}")
    else:
        print(f"Cámaras encontradas: {camaras}")
