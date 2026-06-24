// modulo_3_prediccion.s
// Jackeline Stephany Rivera Argueta - 202401685
// Rutina 3: Prediccion futura por regresion
//
// archivo linea_inicial linea_final columna_sensor [K]
// Si no se recibe K, se usa K=5 
//
// Formulas:
//   B_X100 = ((suma(Yi)*100) - (M_X100*suma(Xi))) / N
//   X_FUTURE = N + K
//   Y_PRED = ((M_X100 * X_FUTURE) + B_X100) / 100

.data

nombre_archivo_salida:
    .asciz "resultado_prediccion.txt"

texto_calc:
    .ascii "CALC=PREDICTION\n"
    len_texto_calc = . - texto_calc

texto_columna:
    .ascii "COLUMN="
    len_texto_columna = . - texto_columna

texto_inicio_ventana:
    .ascii "WINDOW_START="
    len_texto_inicio_ventana = . - texto_inicio_ventana

texto_fin_ventana:
    .ascii "WINDOW_END="
    len_texto_fin_ventana = . - texto_fin_ventana

texto_cantidad:
    .ascii "COUNT="
    len_texto_cantidad = . - texto_cantidad

texto_k:
    .ascii "K="
    len_texto_k = . - texto_k

texto_slope:
    .ascii "SLOPE_X100="
    len_texto_slope = . - texto_slope

texto_intercept:
    .ascii "INTERCEPT_X100="
    len_texto_intercept = . - texto_intercept

texto_predicted:
    .ascii "PREDICTED_"
    len_texto_predicted = . - texto_predicted

texto_igual:
    .ascii "="
    len_texto_igual = . - texto_igual

texto_estado_ok:
    .ascii "STATUS=OK\n"
    len_texto_estado_ok = . - texto_estado_ok

texto_estado_error:
    .ascii "STATUS=ERROR\n"
    len_texto_estado_error = . - texto_estado_error

texto_etiqueta_error:
    .ascii "ERROR="
    len_texto_etiqueta_error = . - texto_etiqueta_error

texto_etiqueta_detalle:
    .ascii "DETAIL="
    len_texto_etiqueta_detalle = . - texto_etiqueta_detalle

error_args:
    .ascii "INVALID_ARGS\n"
    len_error_args = . - error_args

detalle_args:
    .ascii "EXPECTED_4_OR_5_ARGS\n"
    len_detalle_args = . - detalle_args

error_datos_insuficientes:
    .ascii "INSUFFICIENT_DATA\n"
    len_error_datos_insuficientes = . - error_datos_insuficientes

detalle_datos_insuficientes:
    .ascii "PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n"
    len_detalle_datos_insuficientes = . - detalle_datos_insuficientes

salto_linea:
    .ascii "\n"

.bss
