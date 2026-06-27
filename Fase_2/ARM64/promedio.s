// promedio.s

.text

//   Entrada:
//     x0 = puntero al arreglo (buffer) del sensor
//     x1 = N (cantidad de datos validos, count actual)
//   Salida:
//     x0 = PROMEDIO = suma(X_i) / N   
.global calcular_promedio
calcular_promedio:
    cbz x1, promedio_vacio

    mov x2, #0               // x2 = acumulador de suma
    mov x3, #0               // x3 = indice i

suma_promedio_loop:
    cmp x3, x1
    bge fin_suma_promedio

    lsl x4, x3, #3            // x4 = i * 8 (offset en bytes)
    add x5, x0, x4
    ldr x6, [x5]               // x6 = X_i
    add x2, x2, x6

    add x3, x3, #1
    b suma_promedio_loop

fin_suma_promedio:
    sdiv x0, x2, x1            // division entera truncada
    ret

promedio_vacio:
    mov x0, #0
    ret
