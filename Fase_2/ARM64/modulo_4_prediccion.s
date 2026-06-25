/* ====================================================================================
                        Módulo 4: Prediccion de Proximo Valor
   ====================================================================================
    modulo_4_prediccion.s
    Módulo 4: Predicción de Próximo Valor
    Proyecto: Invernadero Inteligente IoT - ACYE1
    Responsable: Diana Myriam Priscila Santizo Cáceres

    Entrada            : lecturas.csv (pasado por parámetro)
    Salida             : resultado_prediccion.txt

    Funcionamiento:
    - Recibe 4 argumentos desde Python: archivo, inicio, fin, columna.
    - Usa utils.s para extraer datos dinámicos.
    - Genera una predicción basándose en el promedio de cambio.

    Cálculos Realizados: 
    1. Valor inicial 
    2. Valor final  
    3. Diferencia total = Final - Inicial
    4. Promedio de cambio = Diferencia / N - 1
    5. Predicción = Final + Promedio_cambio

   ====================================================================================
*/

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.section .data
nombre_csv:     .asciz "lecturas.csv"
nombre_salida:  .asciz "resultado_prediccion.txt"

// Textos fijos en formato .asciz
lbl_calc:      .asciz "CALC=SIMPLE-PREDICTION\nCOLUMN="
lbl_win_start: .asciz "\nWINDOW_START="
lbl_win_end:   .asciz "\nWINDOW_END="
lbl_count:     .asciz "\nCOUNT="
lbl_init:      .asciz "\nINITIAL_VALUE="
lbl_final:     .asciz "\nFINAL_VALUE="
lbl_diff:      .asciz "\nTOTAL_DIFF="
lbl_avg:       .asciz "\nAVG_CHANGE="
lbl_next:      .asciz "\nPREDICTED_NEXT="
lbl_status:    .asciz "\nSTATUS=OK\n"

// Variables para del encabezado dinámico
col_2_nom: .asciz "TEMP"
col_3_nom: .asciz "HUM_AIRE"
col_4_nom: .asciz "HUM_SUELO_1"
col_5_nom: .asciz "HUM_SUELO_2"
col_6_nom: .asciz "LUZ"
col_7_nom: .asciz "GAS"
col_8_nom: .asciz "RIEGO_1"
col_9_nom: .asciz "RIEGO_2"
col_unk:   .asciz "UNKNOWN"

// Mensaje de error estructurado usando .ascii y .equ
err_insuficiente: 
    .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=REQUIRES_AT_LEAST_2_VALUES\n"
.equ len_err_insuficiente, . - err_insuficiente


.section .bss
buffer_salida:  .skip 1024   // Buffer donde se armara el archivo completo
buf_conv:       .skip 32     // Buffer temporal para conversiones numéricas

.section .text
.global _start

_start:
    // --------------------------------------------------------
    // 1. LEER PARÀMETROS DE LA TERMINAL
    // ./modulo_4_prediccion archivo inicio fin columna
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
    mov x11, #2             // Columna = 2 (TEMP)


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
    make modulo_4_prediccion
    qemu-aarch64 ./modulo_4_prediccion 
    cat resultado_prediccion.txt
*/

