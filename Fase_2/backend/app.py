import os
from flask import Flask, render_template, jsonify, request, redirect, url_for, session
from flask_cors import CORS
from datetime import datetime

import config
import database as db
import csv_manager
import mqtt_client as mqtt
import arm64_runner
from state import procesar_comando, obtener_estado

# LOGIN
USUARIO_PRUEBA = "user"
CONTRASENA_PRUEBA = "1234"

app = Flask(
    __name__,
    template_folder=os.path.join("..", "dashboard", "templates"),
    static_folder=os.path.join("..", "dashboard", "static")
)
app.secret_key = config.SECRET_KEY
CORS(app)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        usuario = request.form.get("usuario", "").strip()
        password = request.form.get("password", "").strip()

        if usuario == USUARIO_PRUEBA and password == CONTRASENA_PRUEBA:
            session["usuario"] = usuario
            session["logueado"] = True
            return redirect(url_for("inicio"))
        else:
            return redirect(url_for("login", error=1))

    return render_template("login.html")

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/api/verificar_sesion")
def verificar_sesion():
    return jsonify({
        "logueado": session.get("logueado", False),
        "usuario": session.get("usuario", "")
    })

@app.route("/")
def inicio():
    if not session.get("logueado", False):
        return redirect(url_for("login"))
    return render_template("index.html")

@app.route("/api/estado")
def api_estado():
    estado  = obtener_estado()
    ultimas = db.obtener_ultimos(config.COL_SENSOR_READINGS, 1)
    ultima  = ultimas[0] if ultimas else {}
    return jsonify({
        "timestamp":        datetime.now().isoformat(),
        "estado_global":    estado.get("global", "NORMAL"),
        "modo":             estado.get("modo", "AUTOMATICO"),
        "riego":            estado.get("riego", "RIEGO_OFF"),
        "ventilacion":      estado.get("ventilador", "VENTILACION_OFF"),
        "luces":            estado.get("luces", "OFF"),
        "alarma":           estado.get("alarma", "OFF"),
        "temperatura":      ultima.get("temperatura", {}).get("valor", "--"),
        "humedad_ambiente": ultima.get("hum_aire",    {}).get("valor", "--"),
        "suelo_area1":      ultima.get("hum_suelo_1", {}).get("porcentaje", "--"),
        "suelo_area2":      ultima.get("hum_suelo_2", {}).get("porcentaje", "--"),
        "nivel_luz":        ultima.get("luz",         {}).get("valor", "--"),
        "nivel_gas":        ultima.get("gas",         {}).get("valor", "--"),
        "estado_suelo1":    ultima.get("hum_suelo_1", {}).get("estado", "--"),
        "estado_suelo2":    ultima.get("hum_suelo_2", {}).get("estado", "--"),
        "estado_gas":       ultima.get("gas",         {}).get("estado", "--"),
    })


@app.route("/api/historial")
def api_historial():
    limite = request.args.get("limite", 30, type=int)
    datos  = db.obtener_historial_sensores(limite)
    h = {"labels":[],"temperatura":[],"humedad":[],"suelo1":[],"suelo2":[],"luz":[],"gas":[]}
    for d in datos:
        ts = d.get("timestamp", "")
        h["labels"].append(ts[11:19] if len(ts) >= 19 else ts)
        h["temperatura"].append(d.get("temperatura", {}).get("valor", 0))
        h["humedad"].append(d.get("hum_aire",    {}).get("valor", 0))
        h["suelo1"].append(d.get("hum_suelo_1", {}).get("valor_num", 0))
        h["suelo2"].append(d.get("hum_suelo_2", {}).get("valor_num", 0))
        luz_val = d.get("luz", {}).get("valor", "NORMAL")
        h["luz"].append(0 if luz_val == "BAJO" else 1)
        h["gas"].append(d.get("gas", {}).get("valor", 0))
    return jsonify(h)


@app.route("/api/eventos")
def api_eventos():
    n = request.args.get("n", 20, type=int)
    return jsonify(db.obtener_ultimos(config.COL_EVENTS, n))


@app.route("/api/comandos")
def api_comandos():
    n = request.args.get("n", 20, type=int)
    return jsonify(db.obtener_ultimos(config.COL_COMMANDS, n))


@app.route("/api/actuadores")
def api_actuadores():
    n = request.args.get("n", 20, type=int)
    return jsonify(db.obtener_ultimos(config.COL_ACTUATOR_LOGS, n))


@app.route("/api/arm64")
def api_arm64():
    return jsonify(db.obtener_resultados_arm64())


@app.route("/api/csv")
def api_csv():
    return jsonify({
        "completo":  csv_manager.esta_completo(),
        "filas":     csv_manager.obtener_filas(),
        "max_filas": config.CSV_MAX_ROWS,
        "datos":     csv_manager.leer_csv()
    })


@app.route("/api/sistema")
def api_sistema():
    return jsonify({
        "csv_completo": csv_manager.esta_completo(),
        "csv_filas":    csv_manager.obtener_filas(),
        "estado":       obtener_estado(),
        "timestamp":    datetime.now().isoformat()
    })


@app.route("/api/comando", methods=["POST"])
def api_comando():
    datos = request.get_json()
    if not datos:
        return jsonify({"error": "Body JSON requerido"}), 400
    accion = datos.get("accion", "").upper()
    valor  = datos.get("valor",  "").upper()
    if not accion:
        return jsonify({"error": "Campo accion requerido"}), 400

    procesar_comando({"accion": accion, "valor": valor}, "DASHBOARD")
    mqtt.publicar_comando_remoto(accion, valor)

    return jsonify({
        "status":    "ok",
        "accion":    accion,
        "valor":     valor,
        "timestamp": datetime.now().isoformat(),
        "estado":    obtener_estado()
    })


@app.route("/api/arm64/variables")
def api_arm64_variables():
    return jsonify(list(arm64_runner.VARIABLES.keys()))


@app.route("/api/arm64/ejecutar", methods=["POST"])
def api_arm64_ejecutar():
    import threading
    datos    = request.get_json() or {}
    variable = datos.get("variable", "TEMP").upper()
    threading.Thread(
        target=arm64_runner.correr_pipeline,
        args=(variable,),
        daemon=True
    ).start()
    return jsonify({
        "status":    "iniciado",
        "variable":  variable,
        "timestamp": datetime.now().isoformat()
    })


# ANALISIS HISTORIO ARM64 CON RANGO
# archivo, linea_inicial, linea_final, columna
@app.route("/api/analisis/historico", methods=["POST"])
def api_analisis_historico():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({
                "status": "ERROR",
                "error": "INVALID_REQUEST",
                "detail": "Se requiere body JSON"
            }), 400

        archivo = datos.get("archivo", "lecturas.csv")
        linea_inicial = datos.get("linea_inicial", 1)
        linea_final = datos.get("linea_final", 30)
        columna = datos.get("columna", "TEMP").upper()

        # Validaciones
        if linea_inicial < 1:
            return jsonify({
                "status": "ERROR",
                "error": "INVALID_RANGE",
                "detail": "La linea inicial debe ser mayor o igual a 1"
            }), 400

        if linea_final < linea_inicial:
            return jsonify({
                "status": "ERROR",
                "error": "INVALID_RANGE",
                "detail": "La linea final debe ser mayor o igual a la linea inicial"
            }), 400

        if columna not in arm64_runner.VARIABLES:
            return jsonify({
                "status": "ERROR",
                "error": "INVALID_COLUMN",
                "detail": f"Columna '{columna}' no valida. Opciones: {list(arm64_runner.VARIABLES.keys())}"
            }), 400

        # Verificar que el archivo existe
        import os
        ruta_archivo = os.path.join(os.path.dirname(__file__), archivo)
        if not os.path.exists(ruta_archivo):
            return jsonify({
                "status": "ERROR",
                "error": "FILE_NOT_FOUND",
                "detail": f"Archivo '{archivo}' no encontrado"
            }), 400
        
        # Validar que las lineas existan dentro del archivo
        import csv
        try:
            with open(ruta_archivo, 'r') as f:
                reader = csv.reader(f)
                total_filas = sum(1 for row in reader) - 1
                if linea_final > total_filas:
                    return jsonify({
                        "status": "ERROR",
                        "error": "INVALID_RANGE",
                        "detail": f"La linea final ({linea_final}) excede el total de filas del archivo ({total_filas})"
                    }), 400
                if linea_inicial > total_filas:
                    return jsonify({
                        "status": "ERROR",
                        "error": "INVALID_RANGE",
                        "detail": f"La linea inicial ({linea_inicial}) excede el total de filas del archivo ({total_filas})"
                    }), 400
        except Exception as e:
            return jsonify({
                "status": "ERROR",
                "error": "FILE_READ_ERROR",
                "detail": f"Error al leer el archivo: {str(e)}"
            }), 400

        # Validar que los valores de la columna sean numericos
        try:
            col_index = arm64_runner.VARIABLES.get(columna, 1)
            with open(ruta_archivo, 'r') as f:
                reader = csv.reader(f)
                header = next(reader, None)
                if not header:
                    return jsonify({
                        "status": "ERROR",
                        "error": "EMPTY_FILE",
                        "detail": "El archivo CSV esta vacio o no tiene cabecera"
                    }), 400
                if col_index - 1 >= len(header):
                    return jsonify({
                        "status": "ERROR",
                        "error": "INVALID_COLUMN",
                        "detail": f"La columna {columna} no existe en el archivo. Columnas disponibles: {', '.join(header)}"
                    }), 400
                filas_leidas = 0
                for row in reader:
                    if filas_leidas >= linea_final:
                        break
                    if filas_leidas >= linea_inicial - 1:
                        if len(row) > col_index - 1:
                            valor = row[col_index - 1].strip()
                            try:
                                float(valor)
                            except ValueError:
                                return jsonify({
                                    "status": "ERROR",
                                    "error": "NON_NUMERIC_DATA",
                                    "detail": f"El valor '{valor}' en la columna {columna} no es numerico (fila {filas_leidas + 2})"
                                }), 400
                    filas_leidas += 1
        except Exception as e:
            return jsonify({
                "status": "ERROR",
                "error": "VALIDATION_ERROR",
                "detail": str(e)
            }), 400

        # Ejecutar analisis historico con rango
        import threading
        resultado = {}

        def ejecutar_con_rango():
            nonlocal resultado
            # Copiar CSV y ejecutar modulos con rango
            import arm64_runner
            import csv_manager
            import time

            # Asegurar que el CSV este actualizado
            csv_manager.inicializar()

            # Obtener el indice de columna
            col_index = arm64_runner.VARIABLES.get(columna, 1)

            # Compilar modulos si es necesario
            arm64_runner.compilar_modulos()

            # Ejecutar modulos con el rango especificado
            arm64_runner.ejecutar_modulos_con_rango(col_index, linea_inicial, linea_final)

            # Leer resultados
            resultados = arm64_runner.leer_resultados(columna)
            resultado = {
                "status": "OK",
                "resultados": resultados,
                "columna": columna,
                "linea_inicial": linea_inicial,
                "linea_final": linea_final,
                "archivo": archivo
            }

        # Ejecutar en hilo separado para no bloquear
        import threading
        hilo = threading.Thread(target=ejecutar_con_rango, daemon=True)
        hilo.start()
        hilo.join(timeout=30)

        if resultado:
            return jsonify(resultado)
        else:
            return jsonify({
                "status": "ERROR",
                "error": "TIMEOUT",
                "detail": "El analisis tomo demasiado tiempo"
            }), 408

    except Exception as e:
        return jsonify({
            "status": "ERROR",
            "error": "INTERNAL_ERROR",
            "detail": str(e)
        }), 500


def iniciar_servicios():
    print("=" * 55)
    print("  INVERNADERO INTELIGENTE IoT — Backend")
    print("=" * 55)

    if not db.iniciar():
        print("[WARN] Sin MongoDB — datos no se guardaran")

    csv_manager.inicializar()
    mqtt.iniciar()

    print("[INFO] Esperando datos de la Raspberry Pi por MQTT...")
    print(f"\n[BACKEND] http://localhost:{config.FLASK_PORT}\n")


if __name__ == "__main__":
    iniciar_servicios()
    app.run(host=config.FLASK_HOST, port=config.FLASK_PORT,
            debug=False, use_reloader=False)
