import csv
import os
import threading
import config
import database as db

_lock      = threading.Lock()
_num_filas = 0


class DatosInsuficientesError(Exception):
    """Se lanza cuando Mongo no tiene suficientes lecturas para cubrir
    la cantidad de filas solicitada (linea_final)."""
    def __init__(self, solicitadas, disponibles):
        self.solicitadas  = solicitadas
        self.disponibles  = disponibles
        super().__init__(
            f"Se solicitaron {solicitadas} fila(s) pero Mongo solo tiene "
            f"{disponibles} lectura(s) disponible(s)"
        )


def generar_csv_para_rango(linea_final):
    """
    El CSV resultante queda en disco tal cual hasta la siguiente
    solicitud (no hay regeneracion automatica por MQTT).
    """
    global _num_filas

    with _lock:
        total_disponible = db.contar_lecturas_sensores()
        if total_disponible is None:
            total_disponible = 0

        if total_disponible < linea_final:
            raise DatosInsuficientesError(linea_final, total_disponible)

        historial = db.obtener_historial_sensores(limite=linea_final)
        filas_escritas = _escribir_csv(historial)
        _copiar_a_arm64()
        _num_filas = filas_escritas

    print(f"[CSV] Generado para solicitud — {filas_escritas} fila(s) (linea_final={linea_final})")
    return filas_escritas


def _escribir_csv(historial):
    with open(config.CSV_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(config.CSV_HEADERS)
        filas_escritas = 0
        for i, doc in enumerate(historial, start=1):
            try:
                temp_val   = doc.get("temperatura", {}).get("valor", 0)
                hum_aire   = doc.get("hum_aire", {}).get("valor", 0)
                suelo1_val = doc.get("hum_suelo_1", {}).get("valor_num", 0)
                suelo2_val = doc.get("hum_suelo_2", {}).get("valor_num", 0)
                luz_val    = doc.get("luz", {}).get("valor", "BAJO")
                gas_val    = doc.get("gas", {}).get("valor", 0)

                luz_num    = 0 if luz_val == "BAJO" else 1

                fila = [
                    i,
                    int(round(float(temp_val) * 10)),
                    int(hum_aire),
                    int(suelo1_val),
                    int(suelo2_val),
                    luz_num,
                    int(gas_val),
                    0,
                    0,
                ]
                writer.writerow(fila)
                filas_escritas += 1
            except Exception as e:
                print(f"[CSV] Fila Mongo descartada por error: {e}")
                continue

        f.write("$\n")

    return filas_escritas


def _copiar_a_arm64():
    try:
        with open(config.CSV_FILE, "r", newline="") as src:
            contenido = src.read()
        os.makedirs(os.path.dirname(config.CSV_FILE_ARM64), exist_ok=True)
        with open(config.CSV_FILE_ARM64, "w", newline="") as dst:
            dst.write(contenido)
    except Exception as e:
        print(f"[CSV] No se pudo copiar a ARM64/: {e}")


def esta_completo():
    return _num_filas > 0


def obtener_filas():
    return _num_filas


def leer_csv():
    if not os.path.exists(config.CSV_FILE):
        return []
    try:
        rows = []
        with open(config.CSV_FILE, "r", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if None in row or None in row.values():
                    continue
                if "TEMP" in row:
                    try:
                        row["TEMP"] = round(int(row["TEMP"]) / 10, 1)
                    except Exception:
                        pass
                rows.append(row)
        return rows
    except Exception as e:
        print(f"[CSV] Error al leer: {e}")
        return []
