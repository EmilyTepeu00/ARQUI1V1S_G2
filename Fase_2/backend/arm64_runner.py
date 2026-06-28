import os
import subprocess
import threading
from datetime import datetime
import database as db
import config

ARM64_DIR      = os.path.join(os.path.dirname(__file__), "..", "ARM64")
RESULTADOS_DIR = ARM64_DIR
CSV_BACKEND    = os.path.join(os.path.dirname(__file__), "lecturas.csv")
CSV_ARM64      = os.path.join(ARM64_DIR, "lecturas.csv")

# Cabecera: TEMP, HUM_AIRE, HUM_SUELO_1, HUM_SUELO_2, LUZ, GAS, RIEGO_1, RIEGO_2
#            1       2          3            4         5    6      7        8
VARIABLES = {
    "TEMP":        1,
    "HUM_AIRE":    2,
    "HUM_SUELO_1": 3,
    "HUM_SUELO_2": 4,
    "LUZ":         5,
    "GAS":         6,

    "SOIL1":       3,
    "SOIL2":       4,
}

MODULOS = [
    {
        "nombre":  "modulo_1_media",
        "fuente":  "modulo_1_media.s",
        "binario": "modulo_1_media",
        "salida":  "resultado_media.txt",
        "tipo":    "WEIGHTED_MEAN",
    },
    {
        "nombre":  "modulo_2_varianza",
        "fuente":  "modulo_2_varianza.s",
        "binario": "modulo_2_varianza",
        "salida":  "resultado_varianza.txt",
        "tipo":    "VARIANCE",
    },
    {
        "nombre":  "modulo_3_anomalias",
        "fuente":  "modulo_3_anomalias.s",
        "binario": "modulo_3_anomalias",
        "salida":  "resultado_anomalias.txt",
        "tipo":    "ANOMALY_DETECTION",
    },
    {
        "nombre":  "modulo_4_prediccion",
        "fuente":  "modulo_4_prediccion.s",
        "binario": "modulo_4_prediccion",
        "salida":  "resultado_prediccion.txt",
        "tipo":    "PREDICTION",
    },
    {
        "nombre":  "modulo_5_tendecia",
        "fuente":  "modulo_5_tendecia.s",
        "binario": "modulo_5_tendecia",
        "salida":  "resultado_tendencia.txt",
        "tipo":    "ADVANCED_TREND",
    },
    {
        "nombre":  "modulo_1_rmse",
        "fuente":  "modulo_1_rmse.s",
        "binario": "modulo_1_rmse",
        "salida":  "resultado_rmse.txt",
        "tipo":    "RMSE",
    },
    {
        "nombre":  "modulo_2_regresion",
        "fuente":  "modulo_2_regresion.s",
        "binario": "modulo_2_regresion",
        "salida":  "resultado_regresion.txt",
        "tipo":    "LINEAR_REGRESSION",
    },
    {
        "nombre":  "modulo_3_prediccion",
        "fuente":  "modulo_3_prediccion.s",
        "binario": "modulo_3_prediccion",
        "salida":  "resultado_2_prediccion.txt",
        "tipo":    "PREDICTION_FUTURE",
    },
    {
        "nombre":  "modulo_4_integral_error",
        "fuente":  "modulo_4_integral_error.s",
        "binario": "modulo_4_integral_error",
        "salida":  "resultado_integral.txt",
        "tipo":    "INTEGRAL_ERROR",
    },
    {
        "nombre":  "modulo_5_derivada_local",
        "fuente":  "modulo_5_derivada_local.s",
        "binario": "modulo_5_derivada_local",
        "salida":  "resultado_derivada.txt",
        "tipo":    "LOCAL_DERIVATIVE",
    },
]

_ejecutado = False
_lock      = threading.Lock()


def compilar_modulos():
    print("[ARM64] Compilando modulos...")
    utils_o = os.path.join(ARM64_DIR, "utils.o")
    utils_s = os.path.join(ARM64_DIR, "utils.s")

    try:
        r = subprocess.run(
            ["as", utils_s, "-o", utils_o],
            capture_output=True, text=True, cwd=ARM64_DIR
        )
        if r.returncode != 0:
            print(f"[ARM64] Error compilando utils.s: {r.stderr}")
            return False
        print("[ARM64] utils.o OK")
    except FileNotFoundError:
        print("[ARM64] Error: 'as' no encontrado")
        return False

    for m in MODULOS:
        fuente_s = os.path.join(ARM64_DIR, m["fuente"])
        if not os.path.exists(fuente_s):
            print(f"[ARM64] No existe {m['fuente']} — saltando")
            continue

        obj  = os.path.join(ARM64_DIR, m["nombre"] + ".o")
        bin_ = os.path.join(ARM64_DIR, m["binario"])

        r = subprocess.run(
            ["as", fuente_s, "-o", obj],
            capture_output=True, text=True, cwd=ARM64_DIR
        )
        if r.returncode != 0:
            print(f"[ARM64] Error compilando {m['fuente']}: {r.stderr}")
            continue

        r = subprocess.run(
            ["ld", utils_o, obj, "-o", bin_],
            capture_output=True, text=True, cwd=ARM64_DIR
        )
        if r.returncode != 0:
            print(f"[ARM64] Error linkando {m['nombre']}: {r.stderr}")
        else:
            print(f"[ARM64] {m['binario']} compilado OK")

    return True


def ejecutar_modulos(col_index):
    print(f"[ARM64] Ejecutando modulos con columna index={col_index}...")
    col_str = str(col_index)
    archivo_str = "lecturas.csv"
    inicio_str = "1"
    fin_str = str(config.CSV_MAX_ROWS)
    for m in MODULOS:
        bin_ = os.path.join(ARM64_DIR, m["binario"])
        if not os.path.exists(bin_):
            print(f"[ARM64] Binario {m['binario']} no existe — saltando")
            continue
        try:
            # binario archivo inicio fin columna 
            r = subprocess.run(
                [bin_, archivo_str, inicio_str, fin_str, col_str],
                capture_output=True, text=True, cwd=ARM64_DIR, timeout=15
            )
            if r.returncode == 0:
                print(f"[ARM64] {m['nombre']} ejecutado OK")
                if r.stdout:
                    print(r.stdout)
            else:
                print(f"[ARM64] {m['nombre']} error (rc={r.returncode}): stderr={r.stderr!r} stdout={r.stdout!r}")
        except FileNotFoundError:
            print(f"[ARM64] Binario no encontrado: {bin_}")
            break
        except subprocess.TimeoutExpired:
            print(f"[ARM64] Timeout en {m['nombre']}")


# Ejecutar los modulos con rango especifico
def ejecutar_modulos_con_rango(col_index, linea_inicial, linea_final):
    print(f"[ARM64] Ejecutando modulos con columna={col_index}, rango={linea_inicial}-{linea_final}...")

    col_str = str(col_index)
    inicio_str = str(linea_inicial)
    fin_str = str(linea_final)
    archivo_str = "lecturas.csv"

    errores = []

    for m in MODULOS:
        bin_ = os.path.join(ARM64_DIR, m["binario"])
        if not os.path.exists(bin_):
            print(f"[ARM64] Binario {m['binario']} no existe — saltando")
            continue
        try:
            # binario archivo inicio fin columna 
            r = subprocess.run(
                [bin_, archivo_str, inicio_str, fin_str, col_str],
                capture_output=True, text=True, cwd=ARM64_DIR, timeout=15
            )
            if r.returncode == 0:
                print(f"[ARM64] {m['nombre']} ejecutado OK (rango {linea_inicial}-{linea_final})")
                if r.stdout:
                    print(r.stdout)
            else:
                salida = r.stdout or r.stderr or ""
                detalle_error = _parsear_error_estructurado(salida)
                detalle_error["modulo"] = m["nombre"]
                errores.append(detalle_error)
                print(f"[ARM64] {m['nombre']} error (rc={r.returncode}): {detalle_error}")
        except FileNotFoundError:
            print(f"[ARM64] Binario no encontrado: {bin_}")
            errores.append({"modulo": m["nombre"], "error": "BINARY_NOT_FOUND", "detail": bin_})
            break
        except subprocess.TimeoutExpired:
            print(f"[ARM64] Timeout en {m['nombre']}")
            errores.append({"modulo": m["nombre"], "error": "TIMEOUT", "detail": "El modulo no respondio a tiempo"})

    return errores

# Ejecutar solo el modulo seleccionado
def ejecutar_modulo_unico(tipo_modulo, col_index, linea_inicial, linea_final):
    print(f"[ARM64] Ejecutando modulo unico tipo={tipo_modulo}, columna={col_index}, rango={linea_inicial}-{linea_final}...")

    modulo = next((m for m in MODULOS if m["tipo"] == tipo_modulo), None)
    if modulo is None:
        return [{"modulo": "?", "error": "INVALID_MODULE", "detail": f"Modulo '{tipo_modulo}' no reconocido"}]

    col_str = str(col_index)
    inicio_str = str(linea_inicial)
    fin_str = str(linea_final)
    archivo_str = "lecturas.csv"

    bin_ = os.path.join(ARM64_DIR, modulo["binario"])
    if not os.path.exists(bin_):
        print(f"[ARM64] Binario {modulo['binario']} no existe")
        return [{"modulo": modulo["nombre"], "error": "BINARY_NOT_FOUND", "detail": bin_}]

    try:
        # binario archivo inicio fin columna
        r = subprocess.run(
            [bin_, archivo_str, inicio_str, fin_str, col_str],
            capture_output=True, text=True, cwd=ARM64_DIR, timeout=15
        )
        if r.returncode == 0:
            print(f"[ARM64] {modulo['nombre']} ejecutado OK (rango {linea_inicial}-{linea_final})")
            if r.stdout:
                print(r.stdout)
            return []
        else:
            salida = r.stdout or r.stderr or ""
            detalle_error = _parsear_error_estructurado(salida)
            detalle_error["modulo"] = modulo["nombre"]
            print(f"[ARM64] {modulo['nombre']} error (rc={r.returncode}): {detalle_error}")
            return [detalle_error]
    except FileNotFoundError:
        print(f"[ARM64] Binario no encontrado: {bin_}")
        return [{"modulo": modulo["nombre"], "error": "BINARY_NOT_FOUND", "detail": bin_}]
    except subprocess.TimeoutExpired:
        print(f"[ARM64] Timeout en {modulo['nombre']}")
        return [{"modulo": modulo["nombre"], "error": "TIMEOUT", "detail": "El modulo no respondio a tiempo"}]


# Lee el resultado .txt del modulo seleccionado
def leer_resultado_unico(tipo_modulo, variable):
    modulo = next((m for m in MODULOS if m["tipo"] == tipo_modulo), None)
    if modulo is None:
        return []

    ruta = os.path.join(ARM64_DIR, modulo["salida"])
    datos = parsear_txt(ruta)
    if not datos:
        return []

    datos["modulo"]    = modulo["nombre"]
    datos["tipo"]      = modulo["tipo"]
    datos["variable"]  = variable
    datos["timestamp"] = datetime.now().isoformat()
    print(f"[ARM64] Resultado {modulo['nombre']}: {datos}")
    return [datos]


def _parsear_error_estructurado(salida):
    """Convierte el bloque STATUS=ERROR/ERROR=.../DETAIL=... (seccion
    4.16) que un modulo imprime por stdout/stderr en un dict simple
    {"error": ..., "detail": ...} para devolverlo al dashboard."""
    resultado = {"error": "UNKNOWN_ERROR", "detail": salida.strip()[:200] or "Sin detalle"}
    for linea in salida.splitlines():
        linea = linea.strip()
        if linea.startswith("ERROR="):
            resultado["error"] = linea.split("=", 1)[1].strip()
        elif linea.startswith("DETAIL="):
            resultado["detail"] = linea.split("=", 1)[1].strip()
    return resultado


def parsear_txt(ruta):
    resultado = {}
    if not os.path.exists(ruta):
        return resultado
    with open(ruta, "r") as f:
        contenido = f.read()
    secciones = contenido.split("---")
    seccion = secciones[0]
    for linea in seccion.strip().splitlines():
        linea = linea.strip()
        if "=" in linea:
            k, v = linea.split("=", 1)
            resultado[k.strip()] = v.strip()
    return resultado


def leer_resultados(variable):
    resultados = []
    for m in MODULOS:
        ruta  = os.path.join(ARM64_DIR, m["salida"])
        datos = parsear_txt(ruta)
        if datos:
            datos["modulo"]    = m["nombre"]
            datos["tipo"]      = m["tipo"]
            datos["variable"]  = variable
            datos["timestamp"] = datetime.now().isoformat()
            resultados.append(datos)
            print(f"[ARM64] Resultado {m['nombre']}: {datos}")
    return resultados


def guardar_en_mongo(resultados):
    for r in resultados:
        db.guardar(config.COL_ARM64_RESULTS, r)
    if resultados:
        print(f"[ARM64] {len(resultados)} resultados guardados en MongoDB")


def guardar_resultados_historicos(resultados, errores, columna, linea_inicial, linea_final):
    ts = datetime.now().isoformat()
    rango = {"linea_inicial": linea_inicial, "linea_final": linea_final}

    for r in resultados:
        modulo_nombre = r.get("modulo", "?")
        crudo = {k: v for k, v in r.items()
                 if k not in ("modulo", "tipo", "variable", "timestamp")}

        documento = {
            "timestamp":    ts,
            "source":       "historical_analyzer",
            "module":       modulo_nombre,
            "input":        {"archivo": "lecturas.csv", "columna": columna},
            "range":        rango,
            "column":       columna,
            "result":       crudo,
            "decision":     None,
            "risk":         None,
            "status":       crudo.get("STATUS", "OK"),
            "error_detail": None,
        }
        db.guardar(config.COL_ARM64_RESULTS, documento)

    for e in errores:
        documento = {
            "timestamp":    ts,
            "source":       "historical_analyzer",
            "module":       e.get("modulo", "?"),
            "input":        {"archivo": "lecturas.csv", "columna": columna},
            "range":        rango,
            "column":       columna,
            "result":       {},
            "decision":     None,
            "risk":         None,
            "status":       "ERROR",
            "error_detail": f"{e.get('error','?')}: {e.get('detail','')}",
        }
        db.guardar(config.COL_ARM64_RESULTS, documento)

    total = len(resultados) + len(errores)
    if total:
        print(f"[ARM64] {total} documento(s) del analisis con rango guardados en MongoDB "
              f"({len(resultados)} OK, {len(errores)} con error)")


def _copiar_csv():
    try:
        with open(CSV_BACKEND, "r") as src:
            contenido = src.read()
        if os.path.exists(CSV_ARM64):
            try:
                os.remove(CSV_ARM64)
            except PermissionError:
                pass
        with open(CSV_ARM64, "w") as dst:
            dst.write(contenido)
        print("[ARM64] CSV copiado a ARM64/")
        return CSV_ARM64
    except PermissionError:
        print("[ARM64] Sin permisos para escribir en ARM64/ — los modulos leeran desde backend/")
        return CSV_BACKEND


def correr_pipeline(variable="TEMP"):
    global _ejecutado
    with _lock:
        _ejecutado = True

    import csv_manager
    if not csv_manager.esta_completo():
        print(f"[ARM64] Aviso: solo hay {csv_manager.obtener_filas()}/{config.CSV_MAX_ROWS} lecturas, se analiza con los datos disponibles")

    variable_upper = variable.upper()
    
    col_index = VARIABLES.get(variable_upper, 1)
    print(f"[ARM64] Variable seleccionada: {variable_upper} -> columna {col_index}")

    _copiar_csv()

    ok = compilar_modulos()
    if ok:
        ejecutar_modulos(col_index)

    resultados = leer_resultados(variable_upper)
    if resultados:
        guardar_en_mongo(resultados)
    else:
        print("[ARM64] Sin resultados de archivos .txt")