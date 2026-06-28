import time
import signal
import sys
from datetime import datetime

import config_rasp as cfg
import sensores
import actuadores
import lcd
import botones
import mqtt_rasp as mqtt

estado = {
    "modo":       "AUTOMATICO",
    "riego":      "RIEGO_OFF",
    "ventilador": False,
    "luces":      False,
    "alarma":     False,
}

_riego_activo        = False
_tiempo_ultimo_riego = 0
_procesando_reset    = False
_corriendo           = True
_lcd_pagina          = 0


def _activar_riego():
    global _riego_activo, _tiempo_ultimo_riego

    if _riego_activo:
        return

    def _ciclo():
        global _riego_activo, _tiempo_ultimo_riego
        _riego_activo = True
        estado["riego"] = "RIEGO_ACTIVO"
        print(f"[RIEGO] Iniciando por {cfg.DURACION_RIEGO}s")
        actuadores.bomba(True)
        time.sleep(cfg.DURACION_RIEGO)
        actuadores.apagar_bomba()
        _riego_activo = False
        _tiempo_ultimo_riego = time.time()
        estado["riego"] = "RIEGO_OFF"
        print("[RIEGO] Finalizado")

    import threading
    threading.Thread(target=_ciclo, daemon=True).start()


def procesar_comando(payload):
    accion = payload.get("accion", "").upper()
    valor  = payload.get("valor",  "").upper()
    print(f"\n[CMD] {accion} = {valor}")

    if accion in ("RIEGO_AREA1", "RIEGO_AREA2"):
        if valor == "ON":
            _activar_riego()
        elif valor == "OFF":
            actuadores.apagar_bomba()
            _riego_local_off()

    elif accion == "VENTILADOR":
        enc = valor == "ON"
        estado["ventilador"] = enc
        actuadores.ventilador(enc)

    elif accion == "LUCES":
        enc = valor == "ON"
        estado["luces"] = enc
        actuadores.luces(enc)

    elif accion == "ALARMA":
        enc = valor == "ON"
        estado["alarma"] = enc
        actuadores.buzzer(enc)

    elif accion == "MODO":
        if valor in ("AUTOMATICO", "MANUAL"):
            estado["modo"] = valor
            print(f"[MODO] -> {valor}")

    elif accion == "RESET":
        estado["alarma"] = False
        estado["modo"]   = "AUTOMATICO"
        actuadores.buzzer(False)
        actuadores.set_led_estado("NORMAL")
        lcd.escribir("Alarma silenciada", "Modo: AUTO")

    elif accion == "LED_ESTADO":
        mapa_riesgo = {
            "LOW":      "NORMAL",
            "MEDIUM":   "ADVERTENCIA",
            "HIGH":     "EMERGENCIA",
            "CRITICAL": "EMERGENCIA",
        }
        actuadores.set_led_estado(mapa_riesgo.get(valor, "NORMAL"))


def _riego_local_off():
    global _riego_activo
    _riego_activo = False
    estado["riego"] = "RIEGO_OFF"


def btn_modo():
    nuevo = "MANUAL" if estado["modo"] == "AUTOMATICO" else "AUTOMATICO"
    estado["modo"] = nuevo
    print(f"[BTN] Modo -> {nuevo}")
    lcd.escribir(f"Modo: {nuevo}", "")
    mqtt.publicar_comando_manual("MODO", nuevo)


def btn_riego():
    if estado["modo"] != "MANUAL":
        lcd.escribir("Cambia a MANUAL", "primero")
        return
    if not _riego_activo:
        print("[BTN] Riego manual")
        mqtt.publicar_comando_manual("RIEGO_AREA1", "ON")
        _activar_riego()


def btn_luces():
    nuevo = not estado["luces"]
    estado["luces"] = nuevo
    actuadores.luces(nuevo)
    print(f"[BTN] Luces -> {'ON' if nuevo else 'OFF'}")
    mqtt.publicar_comando_manual("LUCES", "ON" if nuevo else "OFF")


def btn_reset():
    global _procesando_reset
    if _procesando_reset:
        return
    _procesando_reset = True

    estado["alarma"] = False
    estado["modo"]   = "AUTOMATICO"
    actuadores.buzzer(False)
    actuadores.set_led_estado("NORMAL")
    print("[BTN] Reset — alarma silenciada")
    lcd.escribir("Alarma silenciada", "Modo: AUTO")
    mqtt.publicar_comando_manual("RESET", "")

    _procesando_reset = False


def ciclo():
    print(f"\n{'='*50}")
    print(f"[CICLO] {datetime.now().strftime('%H:%M:%S')}")

    temp, hum_aire = sensores.leer_temperatura_humedad()
    valor_suelo1   = sensores.leer_humedad_suelo_valor(1)
    valor_suelo2   = sensores.leer_humedad_suelo_valor(2)
    suelo1         = "SECO" if valor_suelo1 > 800 else "NORMAL"
    suelo2         = "SECO" if valor_suelo2 > 800 else "NORMAL"
    luz            = sensores.leer_luz()
    gas_valor      = sensores.leer_gas()
    gas_estado     = sensores.clasificar_gas(gas_valor)

    print(f"  Temp={temp}C  Hum={hum_aire}%")
    print(f"  Suelo1={suelo1}({valor_suelo1})  Suelo2={suelo2}({valor_suelo2})")
    print(f"  Luz={luz}  Gas={gas_valor} ({gas_estado})")

    mqtt.publicar_temperatura(temp)
    mqtt.publicar_humedad_ambiente(hum_aire)
    mqtt.publicar_humedad_suelo(1, valor_suelo1, suelo1)
    mqtt.publicar_humedad_suelo(2, valor_suelo2, suelo2)
    mqtt.publicar_luz(luz)
    mqtt.publicar_gas(gas_valor, gas_estado)

    actualizar_lcd(temp, hum_aire, suelo1, suelo2, luz, gas_valor, gas_estado)


def actualizar_lcd(temp, hum_aire, suelo1, suelo2, luz, gas_valor, gas_estado):
    global _lcd_pagina

    paginas = [
        (f"Temp: {temp}C",          f"Hum: {hum_aire}%"),
        (f"Suelo1: {suelo1}",       f"Suelo2: {suelo2}"),
        (f"Luz: {luz}",             f"Gas: {gas_valor}"),
        (f"Riego: {estado['riego'][:14]}", f"Vent: {'ON' if estado['ventilador'] else 'OFF'}"),
        (f"Luces: {'ON' if estado['luces'] else 'OFF'}", f"Modo: {estado['modo'][:10]}"),
    ]

    l1, l2 = paginas[_lcd_pagina % len(paginas)]
    lcd.escribir(l1, l2)
    _lcd_pagina += 1


def _loop():
    global _corriendo
    print(f"[RASP] Ciclos cada {cfg.INTERVALO_LECTURA}s")
    while _corriendo:
        try:
            ciclo()
        except Exception as e:
            print(f"[ERROR] {e}")
        time.sleep(cfg.INTERVALO_LECTURA)


def shutdown(sig, frame):
    global _corriendo
    print("\n[RASP] Apagando...")
    _corriendo = False
    actuadores.limpiar()
    mqtt.detener()
    sys.exit(0)


if __name__ == "__main__":
    print("=" * 50)
    print("  INVERNADERO — Raspberry Pi 4")
    print("  (la decision automatica la toma ARM64 en el backend)")
    print("=" * 50)

    signal.signal(signal.SIGINT,  shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    sensores.inicializar()
    sensores.inicializar_arduino()
    actuadores.inicializar()
    lcd.inicializar()
    botones.inicializar()
    botones.registrar_todos(btn_modo, btn_riego, btn_luces, btn_reset)
    mqtt.iniciar(cb_comando=procesar_comando)

    lcd.escribir("Invernadero IoT", "Iniciando...")
    time.sleep(1)

    _loop()