import os
import subprocess
import threading
from datetime import datetime

import config
import database as db

ARM64_DIR     = os.path.join(os.path.dirname(__file__), "..", "ARM64")
MOTOR_FUENTE  = os.path.join(ARM64_DIR, "motor.s")
MOTOR_BINARIO = os.path.join(ARM64_DIR, "motor")

# Acciones validas que puede devolver ARM64 
ACCIONES_VALIDAS = {
    "RIEGO_1_ON", "RIEGO_2_ON", "FAN_ON", "LIGHT_ON",
    "ALARM_ON", "LED_GREEN", "LED_YELLOW", "LED_RED", "NO_ACTION",
}

_proceso = None
_lock = threading.RLock()


def compilar_motor():
    print("[MOTOR] Compilando motor.s...")
    obj = os.path.join(ARM64_DIR, "motor.o")
    try:
        r = subprocess.run(
            ["as", "-I", ARM64_DIR, MOTOR_FUENTE, "-o", obj],
            capture_output=True, text=True, cwd=ARM64_DIR
        )
        if r.returncode != 0:
            print(f"[MOTOR] Error compilando motor.s: {r.stderr}")
            return False

        r = subprocess.run(
            ["ld", obj, "-o", MOTOR_BINARIO],
            capture_output=True, text=True, cwd=ARM64_DIR
        )
        if r.returncode != 0:
            print(f"[MOTOR] Error linkando motor: {r.stderr}")
            return False

        print("[MOTOR] motor compilado OK")
        return True
    except FileNotFoundError:
        print("[MOTOR] Error: 'as'/'ld' no encontrados en el PATH")
        return False


def iniciar_motor():
    global _proceso
    with _lock:
        if _proceso is not None and _proceso.poll() is None:
            print("[MOTOR] Ya estaba corriendo, no se relanza")
            return True

        if not os.path.exists(MOTOR_BINARIO):
            print("[MOTOR] Binario no existe, compilando primero...")
            if not compilar_motor():
                return False

        try:
            _proceso = subprocess.Popen(
                [MOTOR_BINARIO],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,  
                cwd=ARM64_DIR,
            )
            print("[MOTOR] Proceso ARM64 en vivo iniciado")
            return True
        except FileNotFoundError:
            print(f"[MOTOR] No se pudo iniciar el binario {MOTOR_BINARIO}")
            return False


def detener_motor():
    global _proceso
    with _lock:
        if _proceso is None:
            return
        try:
            _proceso.stdin.close()
            _proceso.wait(timeout=5)
            print("[MOTOR] Proceso ARM64 detenido limpiamente")
        except Exception as e:
            print(f"[MOTOR] Error al detener, forzando kill: {e}")
            _proceso.kill()
        _proceso = None