/* ====================================================================================
                            Módulo 2: Regresión Lineal Simple
   ====================================================================================
    modulo_2_regresion.s
    Módulo 2: Regresión Lineal Simple
    Proyecto: Invernadero Inteligente IoT - ACYE1
    Responsable: Diana Myriam Priscila Santizo Cáceres

    Entrada            : lecturas.csv (pasado por parámetro)
    Salida             : resultado_prediccion.txt

    Funcionamiento:
    - Calcula la tendencia de la variable en una ventana usando regresión lineal.
    - Numerador = (N * suma(X_i * Y_i)) - (suma(X_i) * suma(Y_i))
    - Denominador = (N * suma(X_i * X_i)) - (suma(X_i) * suma(X_i))
    - M_X100 = (Numerador * 100) / Denominador

   ==================================================================================== 
   */

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.section .data
nombre_csv:     .asciz "lecturas.csv"
nombre_salida:  .asciz "resultado_regresion.txt"

// Textos estructurados dinámicos
lbl_calc:      .asciz "CALC=LINEAR_REGRESSION\nCOLUMN="
lbl_win_start: .asciz "\nWINDOW_START="
lbl_win_end:   .asciz "\nWINDOW_END="
lbl_count:     .asciz "\nCOUNT="
lbl_slope:     .asciz "\nSLOPE_X100="
lbl_trend:     .asciz "\nTREND="
lbl_status:    .asciz "\nSTATUS=OK\n"

// Diccionario de variables
col_1_nom: .asciz "TEMP"
col_2_nom: .asciz "HUM_AIRE"
col_3_nom: .asciz "HUM_SUELO_1"
col_4_nom: .asciz "HUM_SUELO_2"
col_5_nom: .asciz "LUZ"
col_6_nom: .asciz "GAS"
col_7_nom: .asciz "RIEGO_1"
col_8_nom: .asciz "RIEGO_2"
col_unk:   .asciz "UNKNOWN"

// Resultados de la tendencia
trend_asc:     .asciz "ASCENDING"
trend_desc:    .asciz "DESCENDING"
trend_stab:    .asciz "STABLE"

// Mensaje de error estructurado usando .ascii y .equ
err_insuficiente: 
    .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=REQUIRES_AT_LEAST_2_VALUES\n"
.equ len_err_insuficiente, . - err_insuficiente

.section .bss
buffer_salida:  .skip 1024  // Buffer donde se armara el archivo completo
buf_conv:       .skip 32    // Buffer temporal para conversiones numéricas

.section .text
.global _start

_start:
    // --------------------------------------------------------
    // 1. LEER ARGUMENTOS DE LA TERMINAL
    // ./modulo_2_regresion archivo inicio fin columna
    // --------------------------------------------------------
    ldr x0, [sp]            // x0 = argc
    cmp x0, #5              // Se debe de ingresar programa, archivo, inicio, fin, columna
    blt usar_defaults       // Si no, usar valores por defecto

    ldr x9, [sp, #16]       // Dato 1: nombre del archivo 

    ldr x0, [sp, #24]       // Dato 2: linea inicial (WINDOW_START) 
    bl  ascii_a_int         
    mov x12, x0             

    ldr x0, [sp, #32]       // Dato 3: linea final (WINDOW_END)
    bl  ascii_a_int         
    mov x13, x0             

    ldr x0, [sp, #40]       // Dato 4: columna
    bl  ascii_a_int         
    mov x11, x0             
    b   llamar_utils

// Valores por defecto
usar_defaults:
    adr x9, nombre_csv      // Cargar archivo por defecto para utils.s
    mov x12, #1000        // WINDOW_START por defecto
    mov x13, #1050        // WINDOW_END por defecto
    mov x11, #5             // Columna = 2 (LUZ)

llamar_utils:
    // --------------------------------------------------------
    // 2. EXTRAER DATOS CON UTILS.S
    // --------------------------------------------------------
    bl  read_column_to_stack

    mov x27, x2             // Guardamos COUNT en x27 porque x2 se perderá

    cmp x27, #2
    blt error_datos         // Requiere al menos 2 datos para una regresión

    // --------------------------------------------------------
    // 3. CÁLCULO DE SUMATORIAS PARA REGRESIÓN
    // --------------------------------------------------------
    // x19 = sum(X_i)
    // x20 = sum(Y_i)
    // x21 = sum(X_i * Y_i)
    // x22 = sum(X_i * X_i)
    // x23 = X_i (contador de 1 a N)
    // x24 = Puntero al stack (inicia en x1 - 16, el primer elemento leído)
    
    mov x19, #0
    mov x20, #0
    mov x21, #0
    mov x22, #0
    mov x23, #1             // X_i inicia en 1
    sub x24, x1, #16        // Apuntar al primer dato real

loop_sumatorias:
    cmp x23, x27
    bgt fin_sumatorias      // Si X_i > N, terminar ciclo

    ldr x25, [x24]          // x25 = Y_i

    add x20, x20, x25       // sum(Y_i) += Y_i
    add x19, x19, x23       // sum(X_i) += X_i

    mul x26, x23, x25       // tmp = X_i * Y_i
    add x21, x21, x26       // sum(X_i * Y_i) += tmp

    mul x26, x23, x23       // tmp = X_i * X_i
    add x22, x22, x26       // sum(X_i * X_i) += tmp

    add x23, x23, #1        // X_i++
    sub x24, x24, #16       // Retroceder puntero al siguiente elemento en orden de tiempo
    b loop_sumatorias

fin_sumatorias:
    // --------------------------------------------------------
    // 4. FÓRMULA DE REGRESIÓN
    // --------------------------------------------------------
    // Numerador
    mul x4, x27, x21        // N * sum(X_i * Y_i)
    mul x5, x19, x20        // sum(X_i) * sum(Y_i)
    sub x6, x4, x5          // x6 = Numerador

    // Denominador
    mul x4, x27, x22        // N * sum(X_i * X_i)
    mul x5, x19, x19        // sum(X_i) * sum(X_i)
    sub x7, x4, x5          // x7 = Denominador

    cbz x7, es_estable      // Si denominador es 0, la pendiente es 0 

    // M_X100 = (Numerador * 100) / Denominador
    mov x4, #100
    mul x6, x6, x4          // Numerador * 100
    sdiv x23, x6, x7        // x23 = SLOPE_X100
    b evaluar_tendencia

// ============================================================
// FUNCIONES AUXILIARES INTERNAS
// ============================================================

// --- Función: copiar_a_buffer ---
copiar_a_buffer:
    ldrb w21, [x0], #1      // leer byte y avanzar x0
    cbz  w21, fin_copiar    // si es \0 terminamos
    strb w21, [x20], #1     // guardar byte y avanzar x20
    b    copiar_a_buffer
fin_copiar:
    ret

// --- Función: formatear_numero ---
formatear_numero:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    cmp  x0, #0
    bge  conv_positivo      // Si es mayor o igual a 0, saltar 

    // Si es negativo: colocar '-' en el buffer de conversión
    mov  w9, #45            // Código ASCII para '-'
    strb w9, [x1], #1       // Guardar el '-' y avanzar el puntero del buffer
    neg  x0, x0             // Volver el número positivo para int_a_ascii

// --- Función: conv_positivo ---
conv_positivo:
    bl   int_a_ascii        // convierte x0 al texto en x1
    ldp  x29, x30, [sp], #16
    ret
    
/*  Ejecutar para pruebas:
    make modulo_2_regresion
    qemu-aarch64 ./modulo_2_regresion lecturas.csv 1 25 3
    cat resultado_regresion.txt
*/
