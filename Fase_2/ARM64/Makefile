# ============================================================
# 				Ejecución para los Módulos
# ============================================================

# En Raspberry Pi (nativo):
# AS = as
# LD = ld

# En PC:
AS = aarch64-linux-gnu-as
LD = aarch64-linux-gnu-ld

UTILS_OBJ = utils.o

MODULOS = modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendecia

MODULOS_NUEVOS = modulo_1_rmse modulo_2_regresion modulo_3_prediccion modulo_4_integral_error  modulo_5_derivada_local

.PHONY: all run clean

all: $(UTILS_OBJ) $(MODULOS)
	@echo "--- Compilando modulos nuevos de Fase 2 ---"
	-$(MAKE) modulo_1_rmse
	-$(MAKE) modulo_2_regresion
	-$(MAKE) modulo_3_prediccion
	-$(MAKE) modulo_4_integral_error
	-$(MAKE) modulo_5_derivada_local

$(UTILS_OBJ): utils.s
	$(AS) utils.s -o utils.o

# Fase 1

modulo_1_media: modulo_1_media.s $(UTILS_OBJ)
	$(AS) modulo_1_media.s -o modulo_1_media.o
	$(LD) utils.o modulo_1_media.o -o modulo_1_media

modulo_2_varianza: modulo_2_varianza.s $(UTILS_OBJ)
	$(AS) modulo_2_varianza.s -o modulo_2_varianza.o
	$(LD) utils.o modulo_2_varianza.o -o modulo_2_varianza

modulo_3_anomalias: modulo_3_anomalias.s $(UTILS_OBJ)
	$(AS) modulo_3_anomalias.s -o modulo_3_anomalias.o
	$(LD) utils.o modulo_3_anomalias.o -o modulo_3_anomalias

modulo_4_prediccion: modulo_4_prediccion.s $(UTILS_OBJ)
	$(AS) modulo_4_prediccion.s -o modulo_4_prediccion.o
	$(LD) utils.o modulo_4_prediccion.o -o modulo_4_prediccion

modulo_5_tendecia: modulo_5_tendecia.s $(UTILS_OBJ)
	$(AS) modulo_5_tendecia.s -o modulo_5_tendecia.o
	$(LD) utils.o modulo_5_tendecia.o -o modulo_5_tendecia

# Fase 2

modulo_1_rmse: modulo_1_rmse.s $(UTILS_OBJ)
	$(AS) modulo_1_rmse.s -o modulo_1_rmse.o
	$(LD) utils.o modulo_1_rmse.o -o modulo_1_rmse

modulo_2_regresion: modulo_2_regresion.s $(UTILS_OBJ)
	$(AS) modulo_2_regresion.s -o modulo_2_regresion.o
	$(LD) utils.o modulo_2_regresion.o -o modulo_2_regresion

modulo_3_prediccion: modulo_3_prediccion.s $(UTILS_OBJ)
	$(AS) modulo_3_prediccion.s -o modulo_3_prediccion.o
	$(LD) utils.o modulo_3_prediccion.o -o modulo_3_prediccion

modulo_4_integral_error: modulo_4_integral_error.s $(UTILS_OBJ)
	$(AS) modulo_4_integral_error.s -o modulo_4_integral_error.o
	$(LD) utils.o modulo_4_integral_error.o -o modulo_4_integral_error

modulo_5_derivada_local: modulo_5_derivada_local.s $(UTILS_OBJ)
	$(AS) modulo_5_derivada_local.s -o modulo_5_derivada_local.o
	$(LD) utils.o modulo_5_derivada_local.o -o modulo_5_derivada_local

run: all
	@echo "--- Ejecutando modulos ARM64 ---"
	@echo "Uso: archivo=lecturas.csv linea_inicial=1 linea_final=30 columna=2 (TEMP)"
	-./modulo_1_media     lecturas.csv 1 30 2; cat resultado_media.txt 2>/dev/null
	-./modulo_2_varianza  lecturas.csv 1 30 2; cat resultado_varianza.txt 2>/dev/null
	-./modulo_3_anomalias lecturas.csv 1 30 2; cat resultado_anomalias.txt 2>/dev/null
	-./modulo_4_prediccion lecturas.csv 1 30 2; cat resultado_prediccion.txt 2>/dev/null
	-./modulo_5_tendecia  lecturas.csv 1 30 2; cat resultado_tendencia.txt 2>/dev/null
	@echo "--- Ejecutando modulos NUEVOS de Fase 2 ---"
	-./modulo_1_rmse          lecturas.csv 1 30 2; cat resultado_rmse.txt 2>/dev/null
	-./modulo_2_regresion     lecturas.csv 1 30 2; cat resultado_regresion.txt 2>/dev/null
	-./modulo_3_prediccion    lecturas.csv 1 30 2 5; cat resultado_2_prediccion.txt 2>/dev/null
	-./modulo_4_integral_error lecturas.csv 1 30 2; cat resultado_integral.txt 2>/dev/null
	-./modulo_5_derivada_local lecturas.csv 1 30 2; cat resultado_derivada.txt 2>/dev/null

clean:
	rm -f $(UTILS_OBJ)
	rm -f modulo_1_media.o modulo_2_varianza.o modulo_3_anomalias.o modulo_4_prediccion.o modulo_5_tendecia.o
	rm -f modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendecia
	rm -f modulo_1_rmse.o modulo_2_regresion.o modulo_3_prediccion.o modulo_4_integral_error.o modulo_5_derivada_local.o
	rm -f modulo_1_rmse modulo_2_regresion modulo_3_prediccion modulo_4_integral_error modulo_5_derivada_local
	rm -f resultado_media.txt resultado_varianza.txt resultado_anomalias.txt resultado_prediccion.txt resultado_tendencia.txt
	rm -f resultado_rmse.txt resultado_regresion.txt resultado_2_prediccion.txt resultado_integral.txt resultado_derivada.txt