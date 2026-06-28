import json
import random
import time
from datetime import datetime
from paho.mqtt import client as mqtt_client

import config
import database as db
import motor_runner
from state import procesar_comando, clasificar_suelo, clasificar_gas, obtener_estado

_cliente        = None
_conectado      = False
_ultima_lectura = {}


def on_connect(client, userdata, flags, rc):
    global _conectado
    if rc == 0:
        print("[MQTT] Conectado al broker OK")
        _conectado = True
        client.subscribe(f"{config.MQTT_PREFIX}/#")
        print(f"[MQTT] Suscrito a {config.MQTT_PREFIX}/#")
    else:
        print(f"[MQTT] Fallo rc={rc}")
        _conectado = False


def on_disconnect(client, userdata, rc):
    global _conectado
    _conectado = False
    if rc != 0:
        print("[MQTT] Desconexion inesperada")


def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        topic   = msg.topic

        if topic in (config.TOPIC_CONTROL_REMOTO, config.TOPIC_CONTROL_MANUAL):
            if topic == config.TOPIC_CONTROL_REMOTO and payload.get("auto"):
                # Comando generado por la decision automatica de ARM64
                origen = "ARM64_AUTO"
            else:
                origen = "REMOTO" if topic == config.TOPIC_CONTROL_REMOTO else "MANUAL"
            procesar_comando(payload, origen)
            return

        _procesar_lectura_rasp(topic, payload)

    except Exception as e:
        print(f"[MQTT] Error en mensaje: {e}")


def _procesar_lectura_rasp(topic, payload):
    global _ultima_lectura
    ts = payload.get("timestamp", datetime.now().isoformat())

    if topic == config.TOPIC_TEMPERATURA:
        _ultima_lectura["temperatura"] = payload.get("valor", 0)
        _ultima_lectura["ts"] = ts
    elif topic == config.TOPIC_HUMEDAD_AMBIENTE:
        _ultima_lectura["hum_aire"] = payload.get("valor", 0)
    elif topic == config.TOPIC_HUMEDAD_SUELO_1:
        _ultima_lectura["hum_suelo1"]     = payload.get("estado", "NORMAL")
        _ultima_lectura["hum_suelo1_val"] = payload.get("valor", 0)
    elif topic == config.TOPIC_HUMEDAD_SUELO_2:
        _ultima_lectura["hum_suelo2"]     = payload.get("estado", "NORMAL")
        _ultima_lectura["hum_suelo2_val"] = payload.get("valor", 0)
    elif topic == config.TOPIC_LUZ:
        _ultima_lectura["luz"] = payload.get("valor", "NORMAL")
    elif topic == config.TOPIC_GAS:
        _ultima_lectura["gas"] = payload.get("valor", 0)

    campos = {"temperatura", "hum_aire", "hum_suelo1", "hum_suelo2", "luz", "gas"}
    if campos.issubset(_ultima_lectura.keys()):
        _guardar_lectura_completa(_ultima_lectura.copy())
        _ultima_lectura = {}

def _valor_a_porcentaje_humedad(valor_crudo):
    seco, humedo = config.SUELO_VALOR_SECO, config.SUELO_VALOR_HUMEDO
    rango = seco - humedo
    if rango == 0:
        return 0.0
    pct = (seco - valor_crudo) / rango * 100
    return round(max(0.0, min(100.0, pct)), 1)


def _publicar_accion_fisica(accion, riesgo):
    comandos = {
        "RIEGO_1_ON":  [("RIEGO_AREA1", "ON")],
        "RIEGO_2_ON":  [("RIEGO_AREA2", "ON")],
        "FAN_ON":      [("VENTILADOR", "ON")],
        "LIGHT_ON":    [("LUCES", "ON")],
        "ALARM_ON":    [("ALARMA", "ON"), ("VENTILADOR", "ON")],
        "LED_GREEN":   [("VENTILADOR", "OFF"), ("LUCES", "OFF"), ("ALARMA", "OFF")],
        "LED_YELLOW":  [],
        "LED_RED":     [("ALARMA", "ON")],
        "NO_ACTION":   [],
    }

    # Estos comandos vienen de la decision de ARM64
    for accion_gpio, valor in comandos.get(accion, []):
        publicar_comando_remoto(accion_gpio, valor, auto=True)

    if riesgo:
        publicar_comando_remoto("LED_ESTADO", riesgo, auto=True)


def _accion_arm64_a_estado(resultado_motor, modo_actual):
    if resultado_motor.get("status") != "OK":
        return None

    accion = resultado_motor.get("accion", "NO_ACTION")
    if not resultado_motor.get("accion_valida", False):
        return None

    estado = {
        "riego":      "RIEGO_OFF",
        "ventilador": "VENTILACION_OFF",
        "luces":      "OFF",
        "alarma":     "OFF",
        "modo":       modo_actual,
        "global":     "NORMAL",
    }

    if accion == "RIEGO_1_ON":
        estado["riego"] = "RIEGO_AREA1_ON"
    elif accion == "RIEGO_2_ON":
        estado["riego"] = "RIEGO_AREA2_ON"
    elif accion == "FAN_ON":
        estado["ventilador"] = "VENTILACION_ON"
    elif accion == "LIGHT_ON":
        estado["luces"] = "ON"
    elif accion == "ALARM_ON":
        estado["alarma"] = "ON"
        estado["ventilador"] = "VENTILACION_EMERGENCIA"
        estado["global"] = "EMERGENCIA"
    elif accion == "LED_YELLOW":
        estado["global"] = "ADVERTENCIA"
    elif accion == "LED_RED":
        estado["global"] = "EMERGENCIA"

    return estado


def _guardar_lectura_completa(l):
    ts            = l.get("ts", datetime.now().isoformat())
    estado_suelo1 = clasificar_suelo(l["hum_suelo1"])
    estado_suelo2 = clasificar_suelo(l["hum_suelo2"])
    estado_gas    = clasificar_gas(l["gas"])
    suelo1_val    = l.get("hum_suelo1_val", 0)
    suelo2_val    = l.get("hum_suelo2_val", 0)
    suelo1_pct    = _valor_a_porcentaje_humedad(suelo1_val)
    suelo2_pct    = _valor_a_porcentaje_humedad(suelo2_val)

    lecturas = {
        "temperatura":    l["temperatura"],
        "hum_aire":       l["hum_aire"],
        "hum_suelo1":     l["hum_suelo1"],
        "hum_suelo2":     l["hum_suelo2"],
        "hum_suelo1_val": suelo1_val,
        "hum_suelo2_val": suelo2_val,
        "luz":            l["luz"],
        "gas":            l["gas"],
        "estado_suelo1":  estado_suelo1,
        "estado_suelo2":  estado_suelo2,
        "estado_gas":     estado_gas,
    }

    modo_actual = obtener_estado().get("modo", "AUTOMATICO")

    if modo_actual == "AUTOMATICO":
        resultado_motor = motor_runner.procesar_lectura_con_motor(lecturas, modo=0)
        nuevo_estado = _accion_arm64_a_estado(resultado_motor, modo_actual)
        if nuevo_estado is not None:
            from state import estado_sistema, _lock as _state_lock
            with _state_lock:
                estado_sistema.update(nuevo_estado)
            db.actualizar_estado_global(estado_sistema.copy())

            _publicar_accion_fisica(
                resultado_motor.get("accion", "NO_ACTION"),
                resultado_motor.get("riesgo", ""),
            )
        else:
            print("[MOTOR] Respuesta invalida o ERROR -- se mantiene el ultimo estado conocido")

    estado = obtener_estado()

    print(f"[RASP] Temp={l['temperatura']}C Suelo1={l['hum_suelo1']}({suelo1_val}) Gas={l['gas']}")
    print(f"       Estado={estado['global']} Riego={estado['riego']} (modo={modo_actual})")

    db.guardar(config.COL_SENSOR_READINGS, {
        "timestamp":   ts,
        "tipo":        "sensor_reading",
        "origen":      "RASPBERRY_PI",
        "temperatura": {"valor": l["temperatura"], "unidad": "C"},
        "hum_aire":    {"valor": l["hum_aire"],    "unidad": "%"},
        "hum_suelo_1": {"valor": l["hum_suelo1"], "valor_num": suelo1_val, "porcentaje": suelo1_pct, "estado": estado_suelo1},
        "hum_suelo_2": {"valor": l["hum_suelo2"], "valor_num": suelo2_val, "porcentaje": suelo2_pct, "estado": estado_suelo2},
        "luz":         {"valor": l["luz"]},
        "gas":         {"valor": l["gas"], "estado": estado_gas},
        "estado":      estado["global"],
    })

    db.guardar(config.COL_ACTUATOR_LOGS, {
        "timestamp":  ts,
        "tipo":       "actuator_state",
        "riego":      estado["riego"],
        "ventilador": estado["ventilador"],
        "luces":      estado["luces"],
        "alarma":     estado["alarma"],
        "modo":       estado["modo"],
    })

    if estado["global"] != "NORMAL":
        db.guardar(config.COL_EVENTS, {
            "timestamp": ts,
            "tipo":      "event",
            "estado":    estado["global"],
            "gas":       estado["gas"],
            "riego":     estado["riego"],
            "temp":      l["temperatura"],
            "origen":    "raspberry_pi",
        })


def publicar_comando_remoto(accion, valor, auto=False):
    _publicar(config.TOPIC_CONTROL_REMOTO, {
        "accion": accion, "valor": valor, "auto": auto,
        "timestamp": datetime.now().isoformat()
    })


def _publicar(topic, datos):
    if not _conectado or _cliente is None:
        return
    try:
        _cliente.publish(topic, json.dumps(datos), qos=0)
        print(f"[MQTT TX] {topic}")
    except Exception as e:
        print(f"[MQTT] Error al publicar: {e}")


def iniciar():
    global _cliente
    client_id = f"InvernaderoG2_backend-{random.randint(0, 9999)}"
    client = mqtt_client.Client(client_id=client_id)
    _cliente = client
    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect
    client.on_message    = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=30)
    client.connect(config.MQTT_BROKER, config.MQTT_PORT, keepalive=60)
    client.loop_start()

    timeout = time.time() + 8
    while not _conectado and time.time() < timeout:
        time.sleep(0.1)

    print("[MQTT] Listo" if _conectado else "[MQTT] Sin conexion al broker")


def detener():
    global _cliente
    if _cliente:
        _cliente.disconnect()
        _cliente.loop_stop()
