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


def _parsear_respuesta(linea):
    resultado = {}
    for par in linea.strip().split(";"):
        if "=" in par:
            clave, valor = par.split("=", 1)
            resultado[clave.strip()] = valor.strip()
    return resultado


def enviar_lectura(temp, hum_aire, soil1, soil2, luz, gas, modo=0):
    global _proceso
    with _lock:
        if _proceso is None or _proceso.poll() is not None:
            print("[MOTOR] Proceso no esta vivo, reintentando iniciar...")
            if not iniciar_motor():
                return {
                    "STATUS": "ERROR",
                    "ERROR": "MOTOR_NOT_RUNNING",
                    "DETAIL": "No se pudo iniciar o reiniciar el proceso ARM64",
                }

        linea = f"{int(temp)},{int(hum_aire)},{int(soil1)},{int(soil2)},{int(luz)},{int(gas)},{int(modo)}"
        try:
            _proceso.stdin.write(linea + "\n")
            _proceso.stdin.flush()
            respuesta_raw = _proceso.stdout.readline()
          
            if respuesta_raw.strip() == "STATUS=ERROR":
                linea_error  = _proceso.stdout.readline()
                linea_detail = _proceso.stdout.readline()
                respuesta_raw = (
                    respuesta_raw.strip() + ";" +
                    linea_error.strip() + ";" +
                    linea_detail.strip()
                )
        except (BrokenPipeError, ValueError) as e:
            print(f"[MOTOR] Error de comunicacion: {e}")
            return {
                "STATUS": "ERROR",
                "ERROR": "BROKEN_PIPE",
                "DETAIL": str(e),
            }

        if not respuesta_raw:
            return {
                "STATUS": "ERROR",
                "ERROR": "EMPTY_RESPONSE",
                "DETAIL": "El proceso ARM64 no devolvio nada (pudo haber terminado)",
            }

        print(f"[MOTOR] Python envia: {linea}")
        print(f"[MOTOR] ARM64 responde: {respuesta_raw.strip()}")

        return _parsear_respuesta(respuesta_raw)


def _luz_a_entero(valor_luz):
    if isinstance(valor_luz, str):
        return 0 if valor_luz.upper() == "BAJO" else 1
    return int(valor_luz)


def procesar_lectura_con_motor(lecturas, modo=0):
    respuesta = enviar_lectura(
        temp=lecturas.get("temperatura", 0),
        hum_aire=lecturas.get("hum_aire", 0),
        soil1=lecturas.get("hum_suelo1_val", 0),
        soil2=lecturas.get("hum_suelo2_val", 0),
        luz=_luz_a_entero(lecturas.get("luz", "NORMAL")),
        gas=lecturas.get("gas", 0),
        modo=modo,
    )

    ts = datetime.now().isoformat()

    if respuesta.get("STATUS") == "OK":
        accion = respuesta.get("ACTION", "NO_ACTION")
        accion_valida = accion in ACCIONES_VALIDAS
        if not accion_valida:
            print(f"[MOTOR] Accion '{accion}' NO esta en la lista de acciones validas -- se ignora")
            accion = "NO_ACTION"

        target      = respuesta.get("TARGET", "")
        riesgo      = respuesta.get("RISK", "")
        razon       = respuesta.get("REASON", "")
        valor       = respuesta.get("VALUE", "")
        indicador   = respuesta.get("INDICATOR", "")

        documento = {
            "timestamp": ts,
            "source":    "live_engine",
            "module":    "motor",
            "input":     lecturas,
            "range":     None,    # no aplica al motor en vivo, si al historico
            "column":    None,  
            "result":    {"value": valor, "indicator": indicador},
            "decision":  accion,
            "risk":      riesgo,
            "status":    "OK",
            "error_detail": None,
            "accion":        accion,
            "target":        target,
            "riesgo":        riesgo,
            "razon":         razon,
            "valor":         valor,
            "indicador":     indicador,
            "accion_valida": accion_valida,
        }
    else:
        error_detail = f"{respuesta.get('ERROR','?')}: {respuesta.get('DETAIL','')}"
        documento = {
            "timestamp": ts,
            "source":    "live_engine",
            "module":    "motor",
            "input":     lecturas,
            "range":     None,
            "column":    None,
            "result":    {},
            "decision":  "NO_ACTION",
            "risk":      "LOW",
            "status":    "ERROR",
            "error_detail": error_detail,
            "accion":        "NO_ACTION",
            "target":        "GENERAL",
            "riesgo":        "LOW",
            "razon":         error_detail,   
            "valor":         "",
        }

    print(f"[MOTOR][DEBUG] Antes de guardar en {config.COL_ARM64_RESULTS}")
    resultado_id = db.guardar(config.COL_ARM64_RESULTS, documento)
    print(f"[MOTOR][DEBUG] Resultado guardar: {resultado_id}")
    return documento