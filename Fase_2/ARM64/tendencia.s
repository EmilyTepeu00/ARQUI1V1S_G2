// tendencia.s

.text

.global calcular_tendencia

calcular_tendencia:
    cmp x1, #2
    blt tendencia_vacia

    mov x2, #0               // x2 = acumulador DIF_ACUM
    mov x3, #1               // x3 = indice i, empieza en 1 (necesita X_(i-1))

tendencia_loop:
    cmp x3, x1
    bge fin_tendencia

    // X_i
    lsl x4, x3, #3
    add x5, x0, x4
    ldr x6, [x5]               // x6 = X_i

    // X_(i-1)
    sub x7, x3, #1
    lsl x7, x7, #3
    add x8, x0, x7
    ldr x9, [x8]               // x9 = X_(i-1)

    sub x10, x6, x9             // x10 = DIF_i = X_i - X_(i-1)
    add x2, x2, x10

    add x3, x3, #1
    b tendencia_loop

fin_tendencia:
    mov x0, x2
    ret

tendencia_vacia:
    mov x0, #0
    ret