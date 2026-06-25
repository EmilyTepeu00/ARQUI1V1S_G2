// modulo_3_prediccion.s
// Jackeline Stephany Rivera Argueta - 202401685
// Rutina 3: Prediccion futura por regresion lineal
//
// Modo de uso: ./modulo_3_prediccion archivo.csv linea_inicial linea_final columna [K]
// Si no se manda K, se usa K=5 por defecto
//
// Formulas:
//   M_X100 = ((N*suma(X*Y)) - (suma(X)*suma(Y))) * 100 / ((N*suma(X^2)) - suma(X)^2)
//   B_X100 = ((suma(Y)*100) - (M_X100*suma(X))) / N
//   X_FUTURE = N + K
//   Y_PRED = ((M_X100 * X_FUTURE) + B_X100) / 100

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.data

nombre_salida:
    .asciz "resultado_prediccion.txt"

linea_module:
    .asciz "MODULE=PREDICTION\n"
label_column:       .asciz "COLUMN="
label_wstart:       .asciz "WINDOW_START="
label_wend:         .asciz "WINDOW_END="
label_count:        .asciz "COUNT="
label_k:            .asciz "K="
label_slope:        .asciz "SLOPE_X100="
label_intercept:    .asciz "INTERCEPT_X100="
label_predicted:    .asciz "PREDICTED_"
label_status:       .asciz "STATUS=OK\n"

err_insuf:
    .ascii "MODULE=PREDICTION\nSTATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n"
    len_err_insuf = . - err_insuf

err_div0:
    .ascii "MODULE=PREDICTION\nSTATUS=ERROR\nERROR=DIVISION_BY_ZERO\nDETAIL=REGRESSION_DENOMINATOR_IS_ZERO\n"
    len_err_div0 = . - err_div0

.bss

buffer_salida: .skip 2048
buf_num1:      .skip 64

.text
.global _start

_start:
    // === Leer argumentos ===
    ldr x9,  [sp, #16]      // cargo el nombre del archivo
    ldr x0,  [sp, #24]      // cargo '1' como texto
    bl ascii_a_int          // convierto texto a numero
    mov x12, x0             // guardo linea inicial en x12

    ldr x0,  [sp, #32]
    bl ascii_a_int
    mov x13, x0

    ldr x0,  [sp, #40]
    bl ascii_a_int
    mov x11, x0

    // leo K (como ultimo argumento, que es opcional)
    mov x14, #5
    ldr x0,  [sp, #48]
    cbz x0, guardar_args        // si no existe (es 0), salto con K=5
    bl ascii_a_int              // si existe, lo convierto en número
    mov x14, x0                 // uso ese K en lugar del default

guardar_args:
    sub sp, sp, #80             // hago espacio en el stack
    str x11, [sp, #0]           // guardo columna
    str x12, [sp, #8]           // linea inicial
    str x13, [sp, #16]          // linea final
    str x9,  [sp, #24]          // nombre del archivo
    str x14, [sp, #32]          // guardo K
    
    bl read_column_to_stack

    cmp x2, #2
    blt error_insuficientes_datos

    mov x24, x0          // inicio datos
    mov x25, x1          // fin datos
    mov x26, x3          // sp original de utils
    mov x27, x2          // N = cantidad

    // inicializar acumuladores para la sumas
    mov x5, #0           // sum(X)
    mov x6, #0           // sum(Y)
    mov x7, #0           // sum(X*Y)
    mov x8, #0           // sum(X^2)
    mov x10, #0          // indice i

// === Recorre desde el final hacia el inicio ===
loop_acum:
    cmp x24, x25
    beq fin_acum

    sub x25, x25, #16    // Retrocede desde el final
    ldr x9, [x25]        // Carga el dato en orden correcto

    //Ahora actualizo todas las sumas
    add x5, x5, x10         // sum(X) += i
    add x6, x6, x9          // sum(Y) += Y_i
    mul x11, x10, x9        // x11 = i * Y_i
    add x7, x7, x11         // sum(X*Y) += i*Y_i
    mul x11, x10, x10       // x11 = i * i
    add x8, x8, x11         // sum(X^2) += i^2

    add x10, x10, #1        // i++
    b loop_acum
