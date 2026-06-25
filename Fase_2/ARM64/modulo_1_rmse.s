// modulo_1_rmse.s

// archivo linea_inicial linea_final columna_sensor

// Formulas:
//   ERROR_i  = Y_i - IDEAL
//   ERROR2_i = ERROR_i * ERROR_i
//   MSE      = suma(ERROR2_i) / N
//   RMSE     = sqrt_entera(MSE)

.data

IDEAL:
    .quad 55

nombre_archivo_salida:
    .asciz "resultado_rmse.txt"

texto_calc:
    .ascii "CALC=RMSE\n"
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

texto_ideal:
    .ascii "IDEAL="
    len_texto_ideal = . - texto_ideal

texto_rmse:
    .ascii "RMSE="
    len_texto_rmse = . - texto_rmse

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
    .ascii "EXPECTED_4_ARGS\n"
    len_detalle_args = . - detalle_args

error_datos_insuficientes:
    .ascii "INSUFFICIENT_DATA\n"
    len_error_datos_insuficientes = . - error_datos_insuficientes

detalle_datos_insuficientes:
    .ascii "RMSE_REQUIRES_AT_LEAST_2_VALUES\n"
    len_detalle_datos_insuficientes = . - detalle_datos_insuficientes

salto_linea:
    .ascii "\n"

.bss

buffer_ascii:
    .skip 32

// almacenamiento temporal de los argumentos de entrada, guardados
guardado_linea_inicial:
    .skip 8
guardado_linea_final:
    .skip 8
guardado_columna:
    .skip 8
guardado_fd_salida:
    .skip 8

.text

.global _start
.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

_start:

    mov x0, #-100
    ldr x1, =nombre_archivo_salida
    mov x2, #577
    mov x3, #0644
    mov x8, #56
    svc #0

    ldr x4, =guardado_fd_salida
    str x0, [x4]              // guardar fd del archivo de salida

    ldr x0, [sp]

    cmp x0, #5
    bne rmse_error_args

    ldr x9, [sp, #16]         // Puntero a nombre de archivo

    ldr x0, [sp, #24]         // linea_inicial (string)
    bl ascii_a_int
    mov x12, x0               // Guarda linea_inicial

    ldr x0, [sp, #32]         // linea_final (string)
    bl ascii_a_int
    mov x13, x0               // Guarda linea_final

    ldr x0, [sp, #40]         // columna (string)
    bl ascii_a_int
    mov x11, x0               // Guarda columna_sensor

    ldr x4, =guardado_linea_inicial
    str x12, [x4]
    ldr x4, =guardado_linea_final
    str x13, [x4]
    ldr x4, =guardado_columna
    str x11, [x4]

    bl read_column_to_stack

    mov x24, x0               // Puntero inicio datos en stack
    mov x25, x2               // x25 = N
    mov x26, x3               // Posicion para restaurar stack

    cmp x25, #2
    blt rmse_error_datos_insuficientes

    ldr x4, =guardado_linea_inicial
    ldr x27, [x4]

    // ---- calcular suma de ERROR2_i ----
    ldr x4, =IDEAL
    ldr x29, [x4]              // x29 = IDEAL

    mov x4, #0                 // Acumulador suma(ERROR2_i)
    mov x5, x24                // Puntero recorrido
    mov x6, #0                 // Contador de elementos recorridos

rmse_ciclo_suma:
    cmp x6, x25
    bge rmse_ciclo_suma_fin

    ldr x7, [x5]              // Y_i
    sub x7, x7, x29           // ERROR_i = Y_i - IDEAL
    mul x7, x7, x7            // ERROR2_i
    add x4, x4, x7            // acumular

    add x5, x5, #16           // siguiente dato
    add x6, x6, #1
    b rmse_ciclo_suma

rmse_ciclo_suma_fin:
    // MSE = suma / N 
    udiv x10, x4, x25          // MSE (valores no negativos, division simple)

    mov sp, x26

    // RMSE = raiz_entera(MSE)
    mov x0, x10
    bl raiz_entera
    mov x28, x0                // x28 = RMSE

    // ---- escribir salida OK a resultado_rmse.txt ----
    ldr x0, =texto_calc
    mov x1, len_texto_calc
    bl rmse_escribir

    ldr x0, =texto_columna
    mov x1, len_texto_columna
    bl rmse_escribir

    ldr x4, =guardado_columna
    ldr x4, [x4]
    mov x0, x4
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_inicio_ventana
    mov x1, len_texto_inicio_ventana
    bl rmse_escribir

    mov x0, x27
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_fin_ventana
    mov x1, len_texto_fin_ventana
    bl rmse_escribir

    ldr x4, =guardado_linea_final
    ldr x4, [x4]
    mov x0, x4
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_cantidad
    mov x1, len_texto_cantidad
    bl rmse_escribir

    mov x0, x25
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_ideal
    mov x1, len_texto_ideal
    bl rmse_escribir

    mov x0, x29
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_rmse
    mov x1, len_texto_rmse
    bl rmse_escribir

    mov x0, x28
    ldr x1, =buffer_ascii
    bl int_a_ascii
    bl rmse_escribir_ascii_nl

    ldr x0, =texto_estado_ok
    mov x1, len_texto_estado_ok
    bl rmse_escribir

    // cerrar el archivo de salida antes de terminar
    ldr x4, =guardado_fd_salida
    ldr x0, [x4]
    mov x8, #57
    svc #0

    mov x0, #0
    mov x8, #93
    svc #0

rmse_escribir:
    mov x2, x1
    mov x1, x0
    ldr x4, =guardado_fd_salida
    ldr x0, [x4]
    mov x8, #64
    svc #0
    ret

rmse_escribir_ascii_nl:
    str x30, [sp, #-16]!
    ldr x11, =buffer_ascii

rmse_calcular_longitud:
    ldrb w12, [x11], #1
    cmp w12, #0
    bne rmse_calcular_longitud

    sub x11, x11, #1
    ldr x12, =buffer_ascii
    sub x1, x11, x12           // longitud de la cadena

    ldr x0, =buffer_ascii
    bl rmse_escribir

    ldr x0, =salto_linea
    mov x1, #1
    bl rmse_escribir

    ldr x30, [sp], #16
    ret

raiz_entera:
    mov x1, x0        // Numero del que se busca raiz (se preserva)
    mov x4, #1        // Iterador (candidato a raiz)

raiz_entera_ciclo:
    mul x2, x4, x4
    cmp x2, x1        // x2 > x1 ?
    bgt raiz_entera_fin
    add x4, x4, #1
    b raiz_entera_ciclo

raiz_entera_fin:
    sub x0, x4, #1
    ret

// ---- manejo de errores ----

rmse_error_args:
    ldr x0, =texto_calc
    mov x1, len_texto_calc
    bl rmse_escribir

    ldr x0, =texto_estado_error
    mov x1, len_texto_estado_error
    bl rmse_escribir

    ldr x0, =texto_etiqueta_error
    mov x1, len_texto_etiqueta_error
    bl rmse_escribir

    ldr x0, =error_args
    mov x1, len_error_args
    bl rmse_escribir

    ldr x0, =texto_etiqueta_detalle
    mov x1, len_texto_etiqueta_detalle
    bl rmse_escribir

    ldr x0, =detalle_args
    mov x1, len_detalle_args
    bl rmse_escribir

    // cerrar el archivo de salida antes de terminar
    ldr x4, =guardado_fd_salida
    ldr x0, [x4]
    mov x8, #57
    svc #0

    mov x0, #1
    mov x8, #93
    svc #0

rmse_error_datos_insuficientes:
    mov sp, x26

    ldr x0, =texto_calc
    mov x1, len_texto_calc
    bl rmse_escribir

    ldr x0, =texto_estado_error
    mov x1, len_texto_estado_error
    bl rmse_escribir

    ldr x0, =texto_etiqueta_error
    mov x1, len_texto_etiqueta_error
    bl rmse_escribir

    ldr x0, =error_datos_insuficientes
    mov x1, len_error_datos_insuficientes
    bl rmse_escribir

    ldr x0, =texto_etiqueta_detalle
    mov x1, len_texto_etiqueta_detalle
    bl rmse_escribir

    ldr x0, =detalle_datos_insuficientes
    mov x1, len_detalle_datos_insuficientes
    bl rmse_escribir

    // cerrar el archivo de salida antes de terminar
    ldr x4, =guardado_fd_salida
    ldr x0, [x4]
    mov x8, #57
    svc #0

    mov x0, #1
    mov x8, #93
    svc #0