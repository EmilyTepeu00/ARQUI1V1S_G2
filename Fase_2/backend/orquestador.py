import os
import sys
import time
import subprocess
import argparse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
import database as db        
import config                  

RUTA_MOTOR = os.path.join(os.path.dirname(__file__), "motor")


def _lectura_a_linea(doc):
    """Convierte un documento de sensor_readings (el formato real
    que guarda mqtt_client.py) a la linea de 7 campos que espera el
    motor (seccion 4.4): TEMP,HUM_AIRE,SOIL1,SOIL2,LUZ,GAS,MODO."""
    temp     = doc.get("temperatura", {}).get("valor", 0)
    hum_aire = doc.get("hum_aire",    {}).get("valor", 0)
    soil1    = doc.get("hum_suelo_1", {}).get("valor_num", 0)
    soil2    = doc.get("hum_suelo_2", {}).get("valor_num", 0)
    luz_raw  = doc.get("luz", {}).get("valor", "NORMAL")
    luz      = 0 if str(luz_raw).upper() == "BAJO" else 1
    gas      = doc.get("gas", {}).get("valor", 0)
    return f"{int(temp)},{int(hum_aire)},{int(soil1)},{int(soil2)},{luz},{int(gas)},0"


def _leer_respuesta(proceso):
    primera = proceso.stdout.readline().strip()
    if primera == "STATUS=ERROR":
        error  = proceso.stdout.readline().strip()
        detail = proceso.stdout.readline().strip()
        return f"{primera} | {error} | {detail}"
    return primera


def modo_replay(cantidad):
    if not db.iniciar():
        print("No se pudo conectar a MongoDB. Revisa config.py / la VPN / el cluster Atlas.")
        return

    lecturas = db.obtener_historial_sensores(cantidad)
    if not lecturas:
        print("No hay lecturas reales en Mongo todavia. Encendé la Raspberry Pi primero,")
        print("o usá --live para esperar a que lleguen.")
        return

    print(f"Reproduciendo {len(lecturas)} lecturas reales desde MongoDB...\n")

    proceso = subprocess.Popen(
        [RUTA_MOTOR],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1
    )

    try:
        for doc in lecturas:
            linea = _lectura_a_linea(doc)
            ts = doc.get("timestamp", "")[:19]
            print(f"[{ts}] Python envia: {linea}")

            proceso.stdin.write(linea + "\n")
            proceso.stdin.flush()
            respuesta = _leer_respuesta(proceso)
            print(f"           ARM64 responde: {respuesta}\n")

            time.sleep(1)
    except KeyboardInterrupt:
        print("\nInterrupcion del usuario.")
    finally:
        proceso.stdin.close()
        proceso.wait()
        print("Motor detenido limpiamente.")


def modo_live():
    if not db.iniciar():
        print("No se pudo conectar a MongoDB. Revisa config.py / la VPN / el cluster Atlas.")
        return

    print("Modo LIVE: esperando lecturas nuevas de la Raspberry Pi (Ctrl+C para salir)...\n")

    proceso = subprocess.Popen(
        [RUTA_MOTOR],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1
    )

    ultimo_ts_visto = None
    try:
        while True:
            recientes = db.obtener_historial_sensores(1)
            if recientes:
                doc = recientes[-1]
                ts = doc.get("timestamp", "")
                if ts != ultimo_ts_visto:
                    ultimo_ts_visto = ts
                    linea = _lectura_a_linea(doc)
                    print(f"[{ts[:19]}] Python envia: {linea}")

                    proceso.stdin.write(linea + "\n")
                    proceso.stdin.flush()
                    respuesta = _leer_respuesta(proceso)
                    print(f"           ARM64 responde: {respuesta}\n")

            time.sleep(2)
    except KeyboardInterrupt:
        print("\nInterrupcion del usuario.")
    finally:
        proceso.stdin.close()
        proceso.wait()
        print("Motor detenido limpiamente.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=10,
                         help="Cantidad de lecturas reales a reproducir (modo replay)")
    parser.add_argument("--live", action="store_true",
                         help="Seguir lecturas nuevas en tiempo real, en vez de reproducir historico")
    args = parser.parse_args()

    if not os.path.exists(RUTA_MOTOR):
        print(f"No se encontro el binario compilado en {RUTA_MOTOR}")
        print("Compilalo primero con: make motor   (desde la carpeta ARM64/)")
        return

    if args.live:
        modo_live()
    else:
        modo_replay(args.n)


if __name__ == "__main__":
    main()
