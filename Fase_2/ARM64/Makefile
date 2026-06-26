# ============================================================
# 			Ejecución Automàtica para de los Módulos
# ============================================================

# En Raspberry Pi (nativo):
# AS = as
# LD = ld

# En PC:
AS = aarch64-linux-gnu-as
LD = aarch64-linux-gnu-ld

UTILS_OBJ = utils.o

MODULOS_F1 = modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendecia


.PHONY: all run clean

# Compila todo de una vez
all: $(UTILS_OBJ) $(MODULOS_F1) 

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


# Ejecución de Pruebas
run: all
	@echo "Ejecutando módulos ARM64 Fase 1:"
	-./modulo_1_media     lecturas.csv 1 30 2; cat resultado_media.txt 2>/dev/null
	-./modulo_2_varianza  lecturas.csv 1 30 2; cat resultado_varianza.txt 2>/dev/null
	-./modulo_3_anomalias lecturas.csv 1 30 2; cat resultado_anomalias.txt 2>/dev/null
	-./modulo_4_prediccion lecturas.csv 1 30 2; cat resultado_prediccion.txt 2>/dev/null
	-./modulo_5_tendecia  lecturas.csv 1 30 2; cat resultado_tendencia.txt 2>/dev/null


# Elimina los archivos temporales
clean:
	rm -f $(UTILS_OBJ)
	rm -f modulo_1_media.o modulo_2_varianza.o modulo_3_anomalias.o modulo_4_prediccion.o modulo_5_tendecia.o
	rm -f modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendecia
	rm -f resultado_media.txt resultado_varianza.txt resultado_anomalias.txt resultado_prediccion.txt resultado_tendencia.txt
	