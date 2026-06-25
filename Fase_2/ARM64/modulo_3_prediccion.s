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
    ldr x0,  [sp, #16]      // cargo el nombre del archivo
    ldr x9,  [sp, #24]      // cargo '1' como texto
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

fin_acum:
    // === Calcular pendiente M_X100 ===
    // primero calculamos el numerador
    mul x11, x27, x7        // x11 = N * sum(X*Y)
    mul x12, x5, x6         // x12 = sum(X) * sum(Y)
    sub x13, x11, x12       // x13 = numerador

    // ahora calculamos el denominador
    mul x11, x27, x8        // x11 = N * sum(X^2)
    mul x12, x5, x5         // x12 = (sum(X))^2
    sub x14, x11, x12       // x14 = denominador

    // validar que no sea división por cero
    cmp x14, #0
    beq error_division_cero

    mov x15, #100
    mul x13, x13, x15           // x13 = numerador * 100
    sdiv x15, x13, x14          // x15 = M_X100 (pendiente * 100)

    // === Calcular el intercepto B_X100 ===
    mov x16, #100
    mul x16, x6, x16            // x16 = sum(Y) * 100
    mul x17, x15, x5            // x17 = M_X100 * sum(X)
    sub x16, x16, x17           // x16 = (sum(Y)*100) - (M_X100*sum(X))
    sdiv x16, x16, x27          // x16 = B_X100 (intercepto * 100)

    // === Calcular predicción ===
    ldr x23, [sp, #32]          
    add x17, x27, x23           // x17 = X_FUTURE = N + K
    mul x11, x15, x17           // x11 = M_X100 * X_FUTURE
    add x11, x11, x16           // x11 = (M_X100 * X_FUTURE) + B_X100
    mov x12, #100             // x12 = 100
    sdiv x17, x11, x12          // x17 = Y_PRED (valor predicho)

    // Guardar resultados
    str x15, [sp, #40]
    str x16, [sp, #48]
    str x17, [sp, #56]
    str x27, [sp, #64]

    mov sp, x26

    // === Generar salida ===
    adr x0, buffer_salida           // apunta al buffer de salida
    mov x9, #0                      // posición actual del buffer

    adr x1, linea_module
    bl copiar_etiqueta

    adr x1, label_column
    bl copiar_etiqueta
    ldr x0, [sp, #0]                // cargo la columna desde el stack
    bl escribir_numero
    bl agregar_newline

    adr x1, label_wstart
    bl copiar_etiqueta
    ldr x0, [sp, #8]                // cargo linea inicial
    bl escribir_numero
    bl agregar_newline

    adr x1, label_wend
    bl copiar_etiqueta
    ldr x0, [sp, #16]               // cargo linea final
    bl escribir_numero
    bl agregar_newline

    adr x1, label_count
    bl copiar_etiqueta
    ldr x0, [sp, #64]               // cargo N
    bl escribir_numero
    bl agregar_newline

    adr x1, label_k
    bl copiar_etiqueta
    ldr x0, [sp, #32]               // cargo K
    bl escribir_numero
    bl agregar_newline

    adr x1, label_slope
    bl copiar_etiqueta
    ldr x0, [sp, #40]               // cargo M_X100
    bl escribir_numero
    bl agregar_newline

    adr x1, label_intercept
    bl copiar_etiqueta
    ldr x0, [sp, #48]               // cargo B_X100
    bl escribir_numero
    bl agregar_newline

    adr x1, label_predicted
    bl copiar_etiqueta
    ldr x0, [sp, #32]       // Cargo K
    bl escribir_numero
    adr x0, buffer_salida
    mov w2, #'='            // w2 = caracter '='
    strb w2, [x0, x9]       // se escribe en buffer
    add x9, x9, #1          // avanzo la posición
    ldr x0, [sp, #56]       // cargo Y_PRED
    bl escribir_numero
    bl agregar_newline

    adr x1, label_status
    bl copiar_etiqueta

    // Escribir archivo
    mov x8, #56
    mov x0, #-100
    adr x1, nombre_salida
    mov x2, #577
    mov x3, #0644
    svc #0
    mov x10, x0

    mov x8, #64
    mov x0, x10
    adr x1, buffer_salida
    mov x2, x9
    svc #0

    mov x8, #57
    mov x0, x10
    svc #0

    // Imprimir a stdout
    mov x8, #64
    mov x0, #1
    adr x1, buffer_salida
    mov x2, x9
    svc #0

    mov x8, #93
    mov x0, #0
    svc #0

// === Manejo de Errores === 
error_insuficientes_datos:
    mov x0, #1
    adr x1, err_insuf
    mov x2, len_err_insuf
    mov x8, #64
    svc #0
    mov x8, #93
    mov x0, #1
    svc #0

error_division_cero:
    mov x0, #1
    adr x1, err_div0
    mov x2, len_err_div0
    mov x8, #64
    svc #0
    mov x8, #93
    mov x0, #1
    svc #0

// === Funcines Auxiliares ===
copiar_etiqueta:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
loop_et:
    ldrb w2, [x1], #1
    cmp w2, #0
    beq fin_et
    strb w2, [x0, x9]
    add x9, x9, #1
    b loop_et
fin_et:
    ldp x29, x30, [sp], #16
    ret

escribir_numero:
    stp x29, x30, [sp, #-32]!
    str x19, [sp, #16]
    mov x19, x0
    sub sp, sp, #16
    str x9, [sp]
    adr x1, buf_num1
    bl int_a_ascii
    ldr x9, [sp]
    add sp, sp, #16
    adr x1, buf_num1
    bl copiar_etiqueta
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

agregar_newline:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10
    strb w2, [x0, x9]
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret
