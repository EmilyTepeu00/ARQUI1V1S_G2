import csv
import os
import threading
import config

_lock       = threading.Lock()
_id_counter = 1
_completo   = False


def inicializar():
    global _id_counter, _completo
    if not os.path.exists(config.CSV_FILE):
        with open(config.CSV_FILE, "w", newline="") as f:
            csv.writer(f).writerow(config.CSV_HEADERS)
        _id_counter = 1
        _completo   = False
        print(f"[CSV] Creado '{config.CSV_FILE}'")
    else:
        with open(config.CSV_FILE, "r") as f:
            lineas = f.readlines()
        filas = [l for l in lineas if l.strip() and not l.startswith("ID") and not l.startswith("$")]
        _id_counter = len(filas) + 1
        _completo   = _id_counter > config.CSV_MAX_ROWS
        print(f"[CSV] Existente — {len(filas)} registros, continuando desde ID {_id_counter}")


def agregar_fila(temp, hum_aire, hum_suelo1, hum_suelo2, luz, gas, riego1, riego2):
    global _id_counter, _completo
    with _lock:
        suelo1_num = 0 if hum_suelo1 == "SECO" else 1
        suelo2_num = 0 if hum_suelo2 == "SECO" else 1
        luz_num    = 0 if luz == "BAJO" else 1

        nueva_fila = [int(round(float(temp) * 10)), int(hum_aire),
                      suelo1_num, suelo2_num, luz_num, int(gas),
                      int(riego1), int(riego2)]

        # Leer filas actuales (sin contar header)
        filas = []
        if os.path.exists(config.CSV_FILE):
            with open(config.CSV_FILE, "r", newline="") as f:
                reader = csv.reader(f)
                next(reader, None)  # saltar header
                filas = [row for row in reader if row]

        # Agregar la nueva fila (sin ID todavía)
        filas.append(nueva_fila)

        # FIFO: si supera el máximo, tirar la más vieja
        if len(filas) > config.CSV_MAX_ROWS:
            filas = filas[-config.CSV_MAX_ROWS:]

        # Reescribir el archivo completo con IDs renumerados 1..N
        with open(config.CSV_FILE, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(config.CSV_HEADERS)
            for i, fila in enumerate(filas, start=1):
                writer.writerow([i] + fila)

        _id_counter = len(filas) + 1
        _completo   = len(filas) >= config.CSV_MAX_ROWS

        print(f"[CSV] Fila agregada — {len(filas)}/{config.CSV_MAX_ROWS} (FIFO) — TEMP={nueva_fila[0]} HUM={nueva_fila[1]} GAS={nueva_fila[5]}")
        return True


def esta_completo():
    return _completo


def obtener_filas():
    return max(0, _id_counter - 1)


def leer_csv():
    if not os.path.exists(config.CSV_FILE):
        return []
    try:
        rows = []
        with open(config.CSV_FILE, "r") as f:
            for row in csv.DictReader(f):
                if "$" not in str(row):
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
