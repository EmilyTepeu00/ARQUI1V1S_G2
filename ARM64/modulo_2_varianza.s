// ===========================================================
// modulo_2_varianza.s
// Jackeline Stephany Rivera Argueta - 202401685
// Modulo 2: Varianza y Desviacion Estandar
// Curso: ACYE1 - Segundo Semestre 2026
//
// Lo que hace este modulo:
//   Lee la columna que Python le mande como argumento,
//   si no le mandan nada usa columna 3 (HUM_SUELO_1) por defecto.
//   Calcula que tan dispersos estan los 30 datos respecto
//   al promedio y escribe los resultados en un archivo.
//
// Las formulas que use:
//   Primero saco el promedio: MEDIA = suma de todo / 30
//   Luego la varianza: VAR = suma de (dato-media)^2 / 30
//   Y por ultimo la desviacion: DESV = raiz(VAR)
//
// Archivo de entrada:  lecturas.csv
// Archivo de salida:   resultado_varianza.txt
// ===========================================================

// estas funciones viven en utils.s, las llamo desde aca
.extern leer_datos
.extern int_a_ascii
.extern ascii_a_int
.extern datos

// ===========================================================
// textos fijos que van en el archivo de salida
// ===========================================================
.section .data

nombre_salida:
    .asciz "resultado_varianza.txt"

linea_module:
    .asciz "MODULE=VARIANCE\n"
linea_module_len = . - linea_module

linea_total:
    .asciz "TOTAL_VALUES=30\n"
linea_total_len = . - linea_total

label_mean:     .asciz "MEAN="
label_mean_len = . - label_mean

label_var:      .asciz "VARIANCE="
label_var_len = . - label_var

label_desv:     .asciz "STD_DEV="
label_desv_len = . - label_desv

newline:        .asciz "\n"
newline_len = . - newline

// ===========================================================
// memoria sin inicializar para los buffers
// ===========================================================
.section .bss
buffer_salida: .skip 512    // aqui armo todo el texto antes de guardarlo
buf_media:     .skip 32     // espacio temporal para convertir la media a texto
buf_var:       .skip 32     // espacio temporal para convertir la varianza a texto
buf_desv:      .skip 32     // espacio temporal para convertir la desviacion a texto

// ===========================================================
// aca empieza el codigo
// ===========================================================
.section .text
.global _start

_start:
    // ---------------------------------------------------------
    // leo el argumento que manda Python con el numero de columna
    // si no viene ningun argumento uso columna 3 (HUM_SUELO_1) por defecto
    // [sp] = argc, [sp+16] = puntero al string del argumento
    // ---------------------------------------------------------
    ldr x0, [sp]            // cuantos argumentos llegaron?
    cmp x0, #2              // hay al menos 1 argumento?
    blt usar_default_2      // no -> ir al default

    ldr x0, [sp, #16]       // si -> agarro el puntero al argumento
    bl  ascii_a_int         // lo convierto de texto a numero
    b   llamar_leer_2

usar_default_2:
    mov x0, #3              // nadie mando argumento, uso HUM_SUELO_1 por defecto

llamar_leer_2:
    bl leer_datos           // utils lee la columna x0 y llena datos[]

    // ---------------------------------------------------------
    // Paso 1: calculo la media sumando todos y dividiendo entre 30
    // x19 = puntero al arreglo datos
    // x20 = voy acumulando la suma aqui
    // x21 = contador, va de 0 a 29
    // ---------------------------------------------------------
    adr x19, datos
    mov x20, #0
    mov x21, #0

loop_suma:
    cmp x21, #30            // ya llegue a 30?
    beq fin_suma            // si ya, salgo

    ldr x22, [x19, x21, lsl #3]    // agarro datos[x21], lsl#3 multiplica por 8 porque cada numero ocupa 8 bytes
    add x20, x20, x22       // sumo al acumulador
    add x21, x21, #1        // siguiente
    b loop_suma

fin_suma:
    mov x23, #30
    udiv x24, x20, x23      // x24 = MEDIA = suma / 30

    // ---------------------------------------------------------
    // Paso 2: calculo la varianza
    // para cada dato: lo resto de la media, elevo al cuadrado y sumo
    // uso valor absoluto para evitar negativos antes de elevar
    // x25 = voy acumulando la suma de cuadrados
    // ---------------------------------------------------------
    mov x25, #0
    mov x21, #0

loop_varianza:
    cmp x21, #30
    beq fin_varianza

    ldr x22, [x19, x21, lsl #3]    // agarro datos[x21]

    // reviso cual es mayor para restar siempre positivo
    cmp x22, x24
    bge dato_mayor

    sub x26, x24, x22       // dato < media: diferencia = media - dato
    b elevar_cuadrado

dato_mayor:
    sub x26, x22, x24       // dato >= media: diferencia = dato - media

elevar_cuadrado:
    mul x27, x26, x26       // cuadrado = diferencia * diferencia
    add x25, x25, x27       // sumo al acumulador

    add x21, x21, #1
    b loop_varianza

fin_varianza:
    udiv x28, x25, x23      // x28 = VARIANZA = suma_cuadrados / 30

    // ---------------------------------------------------------
    // Paso 3: calculo la desviacion estandar = raiz(varianza)
    // ARM64 no tiene instruccion directa para raiz de enteros
    // asi que use Newton-Raphson que va mejorando un estimado
    // hasta que ya no cambia mas
    // ---------------------------------------------------------
    mov x0, x28
    bl raiz_cuadrada        // resultado regresa en x0
    mov x29, x0             // x29 = STD_DEV

    // ---------------------------------------------------------
    // armo el texto del resultado en el buffer
    // x9 es la posicion actual donde voy escribiendo
    // ---------------------------------------------------------
    adr x0, buffer_salida
    mov x9, #0

    bl copiar_module        // "MODULE=VARIANCE\n"
    bl copiar_total         // "TOTAL_VALUES=30\n"

    // "MEAN=" + valor + salto de linea
    bl copiar_label_mean
    mov x0, x24
    adr x1, buf_media
    bl int_a_ascii          // convierto el numero a texto
    adr x0, buf_media
    bl copiar_cadena
    bl copiar_newline

    // "VARIANCE=" + valor + salto de linea
    bl copiar_label_var
    mov x0, x28
    adr x1, buf_var
    bl int_a_ascii
    adr x0, buf_var
    bl copiar_cadena
    bl copiar_newline

    // "STD_DEV=" + valor + salto de linea
    bl copiar_label_desv
    mov x0, x29
    adr x1, buf_desv
    bl int_a_ascii
    adr x0, buf_desv
    bl copiar_cadena
    bl copiar_newline

    // ---------------------------------------------------------
    // guardo el buffer en resultado_varianza.txt
    // uso syscalls para pedirle al sistema que abra y escriba
    // ---------------------------------------------------------
    mov x8, #56             // syscall 56 = openat (abrir/crear archivo)
    mov x0, #-100           // AT_FDCWD = buscar en directorio actual
    adr x1, nombre_salida
    mov x2, #577            // crear si no existe y limpiar lo anterior
    mov x3, #0644           // permisos del archivo
    svc #0
    mov x10, x0             // guardo el descriptor del archivo

    mov x8, #64             // syscall 64 = write (escribir)
    mov x0, x10
    adr x1, buffer_salida
    mov x2, x9              // x9 tiene cuantos bytes escribi
    svc #0

    mov x8, #57             // syscall 57 = close (cerrar)
    mov x0, x10
    svc #0

    // tambien muestro en pantalla para verificar
    mov x8, #64
    mov x0, #1              // 1 = stdout = pantalla
    adr x1, buffer_salida
    mov x2, x9
    svc #0

    // fin del programa, 0 = todo bien
    mov x8, #93             // syscall 93 = exit
    mov x0, #0
    svc #0


// ===========================================================
// raiz_cuadrada
// calcula la raiz cuadrada entera usando Newton-Raphson
// le paso el numero en x0 y me devuelve la raiz en x0
//
// como funciona:
//   arranco con estimado = numero / 2
//   cada vuelta: nuevo = (estimado + numero/estimado) / 2
//   cuando el nuevo ya no mejora al anterior, ese es el resultado
// ===========================================================
raiz_cuadrada:
    stp x29, x30, [sp, #-32]!  // guardo registros en la pila
    mov x29, sp
    str x19, [sp, #16]
    str x20, [sp, #24]

    mov x19, x0                 // guardo el numero original

    cmp x19, #0
    beq raiz_es_cero            // caso especial: raiz de 0 es 0

    lsr x20, x19, #1            // estimado inicial = numero / 2

    cmp x20, #0
    beq raiz_es_uno             // si el estimado quedo en 0, la raiz es 1

loop_newton:
    udiv x0, x19, x20           // numero / estimado_actual
    add x0, x0, x20             // + estimado_actual
    lsr x0, x0, #1              // / 2 = nuevo estimado

    cmp x0, x20
    bge raiz_lista              // si no mejora, ya convergio

    mov x20, x0                 // actualizo y repito
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
    ldr x19, [sp, #16]          // recupero los registros
    ldr x20, [sp, #24]
    ldp x29, x30, [sp], #32
    ret


// ===========================================================
// funciones para copiar texto al buffer de salida
// todas usan x9 como posicion actual
// x9 va creciendo conforme escribo mas cosas
// ===========================================================

copiar_module:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, linea_module
loop_cm:
    ldrb w2, [x1]           // leo un byte del texto
    cmp w2, #0              // es el fin?
    beq fin_cm
    strb w2, [x0, x9]       // lo copio al buffer
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
    mov w2, #10             // 10 = codigo ASCII del salto de linea
    strb w2, [x0, x9]
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret
