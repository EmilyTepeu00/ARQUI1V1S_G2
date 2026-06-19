import csv
import os
import threading
import config
import database as db

_lock      = threading.Lock()
_num_filas = 0


def inicializar():
    global _num_filas
    with _lock:
        _num_filas = _reescribir_desde_mongo()
    print(f"[CSV] Inicializado desde Mongo — {_num_filas} fila(s)")


def agregar_fila(temp, hum_aire, hum_suelo1, hum_suelo2, luz, gas, riego1, riego2):
    global _num_filas
    with _lock:
        _num_filas = _reescribir_desde_mongo()
    print(f"[CSV] Regenerado — {_num_filas}/{config.CSV_MAX_ROWS} (FIFO desde Mongo)")
    return True


def _reescribir_desde_mongo():
    historial = db.obtener_historial_sensores(limite=config.CSV_MAX_ROWS)

    with open(config.CSV_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(config.CSV_HEADERS)
        for i, doc in enumerate(historial, start=1):
            try:
                temp_val   = doc.get("temperatura", {}).get("valor", 0)
                hum_aire   = doc.get("hum_aire", {}).get("valor", 0)
                suelo1_est = doc.get("hum_suelo_1", {}).get("estado", "SECO")
                suelo2_est = doc.get("hum_suelo_2", {}).get("estado", "SECO")
                luz_val    = doc.get("luz", {}).get("valor", "BAJO")
                gas_val    = doc.get("gas", {}).get("valor", 0)

                suelo1_num = 0 if suelo1_est == "SECO" else 1
                suelo2_num = 0 if suelo2_est == "SECO" else 1
                luz_num    = 0 if luz_val == "BAJO" else 1

                fila = [
                    i,
                    int(round(float(temp_val) * 10)),
                    int(hum_aire),
                    suelo1_num,
                    suelo2_num,
                    luz_num,
                    int(gas_val),
                    0,
                    0,
                ]
                writer.writerow(fila)
            except Exception as e:
                print(f"[CSV] Fila Mongo descartada por error: {e}")
                continue

    return len(historial)


def esta_completo():
    return _num_filas >= config.CSV_MAX_ROWS


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