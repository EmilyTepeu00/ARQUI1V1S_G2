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
linea_module_len = . - linea_module

linea_total:
    .asciz "TOTAL_VALUES=30\n"
linea_total_len = . - linea_total

label_mean:     .asciz "MEAN="
label_var:      .asciz "VARIANCE="
label_desv:     .asciz "STD_DEV="

.bss

buffer_salida: .skip 512
buf_media:     .skip 32
buf_var:       .skip 32
buf_desv:      .skip 32

.text
.global _start

_start:
    // leer argumento de columna
    ldr x0, [sp, #16]
    bl ascii_a_int

    mov x11, x0
    bl read_column_to_stack

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
    udiv x16, x13, x27          // x16 = VARIANZA


//Calcular desviacion estandar
    mov x0, x16
    bl raiz_cuadrada
    mov x17, x0                  // x17 = STD_DEV

    // restaurar el stack 
    mov sp, x26

    // generar salida
    adr x0, buffer_salida
    mov x9, #0

    bl copiar_module
    bl copiar_total

    bl copiar_label_mean
    mov x23, x9
    mov x0, x12
    adr x1, buf_media
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_media
    bl copiar_cadena
    bl copiar_newline

    bl copiar_label_var
    mov x23, x9
    mov x0, x16
    adr x1, buf_var
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_var
    bl copiar_cadena
    bl copiar_newline

    bl copiar_label_desv
    mov x23, x9
    mov x0, x17
    adr x1, buf_desv
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_desv
    bl copiar_cadena
    bl copiar_newline

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

// Newton-Raphson
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

copiar_total:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, linea_total
loop_ct:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_ct
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b loop_ct
fin_ct:
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
