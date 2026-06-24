// modulo_2_varianza.s
// Jackeline Stephany Rivera Argueta - 202401685
// Modulo 2: Varianza y Desviacion Estandar
//
// MEDIA = suma / cantidad
// VAR   = suma((dato-media)^2) / cantidad
// DESV  = raiz(VAR)

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.data

nombre_salida:
    .asciz "resultado_varianza.txt"

linea_module:
    .asciz "MODULE=VARIANCE\n"

label_column:    .asciz "COLUMN="
label_wstart:    .asciz "WINDOW_START="
label_wend:      .asciz "WINDOW_END="
label_count:     .asciz "COUNT="
label_mean:      .asciz "MEAN="
label_var:       .asciz "VARIANCE="
label_desv:      .asciz "STD_DEV="
label_status:    .asciz "STATUS=OK\n"

.bss

buffer_salida: .skip 512
buf_num1:      .skip 32
buf_num2:      .skip 32
buf_num3:      .skip 32

.text
.global _start

_start:
    // leer los 4 argumento de columna
    ldr x9, [sp, #16]              // x9 = puntero al nombre del archivo argv[1]

    ldr x0, [sp, #24]               // argv[2] = linea inicial
    bl ascii_a_int
    mov x12, x0                    

    ldr x0, [sp, #32]               // argv[3] = linea final
    bl ascii_a_int
    mov x13, x0                   

    ldr x0, [sp, #40]               // argv[4] = columna
    bl ascii_a_int
    mov x11, x0                   

    //guardamos copias
    sub sp, sp, #32
    str x11, [sp]        // columna
    str x12, [sp, #8]    // linea inicial
    str x13, [sp, #16]   // linea final
    str x9,  [sp, #24]   // puntero al nombre del archivo
    bl read_column_to_stack

    //recuperamos las copias despues de la llamada
    ldr x18, [sp]         // x18 = columna
    ldr x17, [sp, #8]     // x17 = linea inicial 
    ldr x16, [sp, #16]    // x16 = linea final 
    add sp, sp, #32


    // x0 = inicio datos
    // x1 = limite superior
    // x2 = cantidad
    // x3 = restaurar stack
    mov x24, x0
    mov x25, x1
    mov x26, x3
    mov x27, x2              // x27 = cantidad real de datos leidos


//calcular media
    mov x6, x24
    mov x7, #0

suma_loop:
    cmp x6, x25
    beq suma_fin

    ldr x9, [x6], #16         // cada dato ocupa 16 bytes en la pila
    add x7, x7, x9
    b suma_loop

suma_fin:
    udiv x12, x7, x27          // x12 = MEDIA


//Calcular Varianza
    mov x6, x24
    mov x13, #0                 // acumulador de cuadrados

var_loop:
    cmp x6, x25
    beq var_fin

    ldr x9, [x6], #16

    sub x14, x9, x12
    mul x15, x14, x14
    add x13, x13, x15

    b var_loop

var_fin:
    udiv x28, x13, x27          // x28 = VARIANZA


//Calcular desviacion estandar
    mov x0, x28
    bl raiz_cuadrada
    mov x29, x0                  // x29 = STD_DEV

    // restaurar el stack 
    mov sp, x26

    // generar salida
    adr x0, buffer_salida
    mov x9, #0

    bl copiar_module

    // COLUMN= numero
    bl copiar_label_column
    mov x23, x9
    mov x0, x18
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_START= linea inicial
    bl copiar_label_wstart
    mov x23, x9
    mov x0, x17
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_END= linea final
    bl copiar_label_wend
    mov x23, x9
    mov x0, x16
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // COUNT=<cantidad>
    bl copiar_label_count
    mov x23, x9
    mov x0, x27
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // MEAN= media
    bl copiar_label_mean
    mov x23, x9
    mov x0, x12
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // VARIANCE= varianza
    bl copiar_label_var
    mov x23, x9
    mov x0, x28
    adr x1, buf_num2
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num2
    bl copiar_cadena
    bl copiar_newline

    // STD_DEV= desviacion
    bl copiar_label_desv
    mov x23, x9
    mov x0, x29
    adr x1, buf_num3
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num3
    bl copiar_cadena
    bl copiar_newline

    // STATUS= ok
    bl copiar_status

    // escribir archivo
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

    mov x8, #64
    mov x0, #1
    adr x1, buffer_salida
    mov x2, x9
    svc #0

    mov x8, #93
    mov x0, #0
    svc #0

// metodo de Newton Raphson
raiz_cuadrada:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    str x20, [sp, #24]

    mov x19, x0

    cmp x19, #0
    beq raiz_es_cero

    lsr x20, x19, #1

    cmp x20, #0
    beq raiz_es_uno

loop_newton:
    udiv x0, x19, x20
    add x0, x0, x20
    lsr x0, x0, #1

    cmp x0, x20
    bge raiz_lista

    mov x20, x0
    b loop_newton

raiz_lista:
    mov x0, x20
    b fin_raiz

raiz_es_cero:
    mov x0, #0
    b fin_raiz

raiz_es_uno:
    mov x0, #1

fin_raiz:
    ldr x19, [sp, #16]
    ldr x20, [sp, #24]
    ldp x29, x30, [sp], #32
    ret


//funciones auxiliares
copiar_module:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, linea_module
loop_cm:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cm
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_cm
fin_cm:
    ldp x29, x30, [sp], #16
    ret

copiar_label_column:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_column
loop_clc:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clc
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clc
fin_clc:
    ldp x29, x30, [sp], #16
    ret

copiar_label_wstart:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wstart
loop_clws:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clws
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clws
fin_clws:
    ldp x29, x30, [sp], #16
    ret

copiar_label_wend:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wend
loop_clwe:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clwe
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clwe
fin_clwe:
    ldp x29, x30, [sp], #16
    ret

copiar_label_count:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_count
loop_clcnt:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clcnt
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clcnt
fin_clcnt:
    ldp x29, x30, [sp], #16
    ret

copiar_label_mean:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_mean
loop_clm:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clm
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clm
fin_clm:
    ldp x29, x30, [sp], #16
    ret

copiar_label_var:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_var
loop_clv:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_clv
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_clv
fin_clv:
    ldp x29, x30, [sp], #16
    ret

copiar_label_desv:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_desv
loop_cld:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cld
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_cld
fin_cld:
    ldp x29, x30, [sp], #16
    ret

copiar_status:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_status
loop_cst:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cst
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_cst
fin_cst:
    ldp x29, x30, [sp], #16
    ret

copiar_cadena:
    stp x29, x30, [sp, #-16]!
    mov x1, x0
    adr x0, buffer_salida
loop_cc:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cc
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_cc
fin_cc:
    ldp x29, x30, [sp], #16
    ret

copiar_newline:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10
    strb w2, [x0, x9]
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret
