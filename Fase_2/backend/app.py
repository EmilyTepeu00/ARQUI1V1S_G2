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
        "generado":  csv_manager.esta_completo(),
        "filas":     csv_manager.obtener_filas(),
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


# ANALISIS HISTORICO ARM64 CON RANGO
# linea_inicial, linea_final, columna
# El CSV se genera en este momento con las 'linea_final' lecturas
# mas recientes de Mongo (no existe un CSV previo que validar).
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

        linea_inicial = datos.get("linea_inicial", 1)
        linea_final = datos.get("linea_final", 30)
        columna = datos.get("columna", "TEMP").upper()

        # Validaciones de rango
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

        # Generar el CSV con las 'linea_final' lecturas mas recientes de Mongo.
        # Si Mongo no tiene suficientes, esto lanza DatosInsuficientesError.
        try:
            csv_manager.generar_csv_para_rango(linea_final)
        except csv_manager.DatosInsuficientesError as e:
            return jsonify({
                "status": "ERROR",
                "error": "INSUFFICIENT_DATA",
                "detail": str(e),
                "solicitadas": e.solicitadas,
                "disponibles": e.disponibles
            }), 400

        # Ejecutar analisis historico con rango
        resultado = {}

        def ejecutar_con_rango():
            nonlocal resultado

            col_index = arm64_runner.VARIABLES.get(columna, 1)

            arm64_runner.compilar_modulos()
            arm64_runner.ejecutar_modulos_con_rango(col_index, linea_inicial, linea_final)

            resultados = arm64_runner.leer_resultados(columna)
            resultado = {
                "status": "OK",
                "resultados": resultados,
                "columna": columna,
                "linea_inicial": linea_inicial,
                "linea_final": linea_final
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

    mqtt.iniciar()

    print("[INFO] Esperando datos de la Raspberry Pi por MQTT...")
    print("[INFO] El CSV se genera bajo demanda desde /api/analisis/historico")
    print(f"\n[BACKEND] http://localhost:{config.FLASK_PORT}\n")


if __name__ == "__main__":
    iniciar_servicios()
    app.run(host=config.FLASK_HOST, port=config.FLASK_PORT,
            debug=False, use_reloader=False)
