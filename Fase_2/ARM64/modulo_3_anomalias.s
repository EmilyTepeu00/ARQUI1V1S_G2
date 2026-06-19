// modulo_3_anomalias.s
// Deteccion Estadistica de Anomalias
// Emily Maritza Tepeu Guacamaya - 202402955
//
// Detecta anomalias usando z-score: |Z| >= 2 = ANOMALIA
// Z = (X - MEDIA) * 10 / DESV  (x10 para evitar decimales)


// FUNCIONES EXTERNAS
.extern read_column_to_stack   // Lee columna del CSV y guarda datos en stack
.extern int_a_ascii            // Convierte entero a texto ASCII
.extern ascii_a_int            // Convierte texto ASCII a entero

// Constantes .equ se usa para definir constantes, parecido al #define en C
// Syscalls son llamadas al SO
.equ SYS_OPENAT,  56    // abrir archivo
.equ SYS_CLOSE,   57    // cerrar archivo
.equ SYS_WRITE,   64    // escribir en ela rchivo
.equ SYS_EXIT,    93    // trminar el programa
.equ AT_FDCWD,   -100   // le dice al sistema que use el directorio actual
.equ O_WRONLY,    1     // modo escribir solo
.equ O_CREAT,     64    // crear archivo si no existe
.equ O_TRUNC,     512   // borrar contenido si ya existe
.equ PERM_644,    0644  // permisos del archivo (rw-r--r--)
.equ N_DATOS,     30    // cantidad de datos a procesar

.section .data

// NOMBRE DEL ARCHIVO DE SALIDA
archivo_salida:   .asciz "resultado_anomalias.txt"

// ETIQUETAS PARA EL ARCHIVO DE SALIDA
str_module:       .asciz "MODULE=ANOMALY_DETECTION\n"
str_total:        .asciz "TOTAL_VALUES=30\n"
str_mean_label:   .asciz "MEAN="
str_std_label:    .asciz "STD_DEV="
str_anom_label:   .asciz "ANOMALIES="
str_risk_label:   .asciz "SYSTEM_RISK="

// CLASIFICACION DE RIESGO
str_risk_normal:  .asciz "NORMAL\n"
str_risk_medium:  .asciz "MEDIUM\n"
str_risk_high:    .asciz "HIGH\n"

.section .bss

// BUFFER CONVERSION NUMERO A TEXTO
buf_conv:      .skip 32      // Buffer temp para convertir num a texto
buffer_salida: .skip 512     // Buffer para armar el archivo de salida

// VARIABLES PARA ALMACENAR RESULTADOS
res_mean:      .skip 8       // Media aritmetica
res_std:       .skip 8       // Desviacion estandar
res_anomalias: .skip 8       // Cantidad de anomalias

.section .text
.global _start

// ----- PROGRAMA PRINCIPAL -----
_start:
    // LECTURA DEL ARG DE COLUMNA
    // [sp] contiene argc
    // [sp+16] puntero a argv[1] (el string de la columna)
    ldr x0, [sp]            // x0 = argc (cantidad de arg)
    cmp x0, #2              // hay al menos 1 argumento?
    blt usar_default_3      // Si no, columna 7 por default

    // Si hay argumento, leerlo
    ldr x0, [sp, #16]       // x0 = puntero a argv[1]
    bl  ascii_a_int         // convierte el string a numero entero en x0
    b   llamar_leer_3

usar_default_3:
    mov x0, #7              // default: columna 7 = GAS

llamar_leer_3:
    // Llamar a read_column_to_stack
    //  Se lee la columna del CSV y guarda los datos en el stack
    // La columna a leer debe estar en x11
    mov x11, x0
    bl  read_column_to_stack

    // VALORES DE RETORNO DE read_column_to_stack
    mov x24, x0     // x0 = primer dato leido
    mov x25, x1     // x1 = limite superior
    mov x26, x3     // x2 = cantidad real de datos leidos (N)
    mov x27, x2     // x3 = posicion original del st ya no se usen los datos

    // CALCULAR MEDIA
    // Se usa x6 como puntero y x7 como acumulador de suma
    mov x6, x24
    mov x7, #0

suma_loop:
    cmp x6, x25
    beq suma_fin

    ldr x9, [x6], #16   // Cada dato ocupa 16 bytes en la pila
    add x7, x7, x9
    b suma_loop

suma_fin:
    udiv x12, x7, x27   // x12 = MEDIA

    // CALCULAR VARIANZA
    // Se usa x6 como puntero y x13 como acumulador de cuadrados
    mov x6, x24
    mov x13, #0     // Acumulador de cuadrados

var_loop:
    cmp x6, x25
    beq var_fin

    ldr x9, [x6], #16

    sub x14, x9, x12
    mul x15, x14, x14
    add x13, x13, x15

    b var_loop

var_fin:
    udiv x16, x13, x27  // x16 = VARIANZA

    // CALCULAR DESVIACION ESTANDAR
    // Se usa raiz_cuadrada para calcular la raiz de la varianza
    mov x0, x16
    bl raiz_cuadrada
    mov x17, x0     // x17 = STD_DEV

    // CONTAR ANOMALIAS
    // Se usa x6 como puntero y x18 como contador de anomalias
    mov x6, x24
    mov x18, #0     // Contador anomalias

anom_loop:
    cmp x6, x25
    beq anom_fin

    ldr x9, [x6], #16       // x9 = dato actual

    // Calcular |dato - media|
    sub x19, x9, x12
    cmp x19, #0
    bge anom_pos
    neg x19, x19        // valor absoluto

anom_pos:
    // Z = |dato - media| / desv
    // Se multiplica por 10 para evitar decimales
    // |Z| >= 2 equivale a |Z|*10 >= 20
    mov x20, #10
    mul x19, x19, x20
    udiv x19, x19, x17

    cmp x19, #20
    blt anom_siguiente

    // Si |Z| >= 2, es una anomalia
    add x18, x18, #1

anom_siguiente:
    b anom_loop

anom_fin:
    // GUARDAR RESULTADOS EN MEMORIA
    adr x9, res_mean
    str x12, [x9]

    adr x9, res_std
    str x17, [x9]

    adr x9, res_anomalias
    str x18, [x9]

    // RESTAURAR EL STACK
    mov sp, x26

    // GENERAR SALIDA
    adr x0, buffer_salida
    mov x9, #0      // x9 = contador de bytes escritos

    // MODULE=ANOMALY_DETECTION
    adr x1, str_module
    bl copiar_cadena

    // TOTAL_VALUES=30
    adr x1, str_total
    bl copiar_cadena

    // MEAN=
    adr x1, str_mean_label
    bl copiar_cadena
    mov x23, x9
    mov x0, x12
    adr x1, buf_conv
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_conv
    bl copiar_cadena
    bl copiar_newline

    // STD_DEV=
    adr x1, str_std_label
    bl copiar_cadena
    mov x23, x9
    mov x0, x17
    adr x1, buf_conv
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_conv
    bl copiar_cadena
    bl copiar_newline

    // ANOMALIES=
    adr x1, str_anom_label
    bl copiar_cadena
    mov x23, x9
    mov x0, x18
    adr x1, buf_conv
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_conv
    bl copiar_cadena
    bl copiar_newline

    // SYSTEM_RISK=
    adr x1, str_risk_label
    bl copiar_cadena

    // Clasificar segun la cantidad de anomalias
    cmp x18, #0
    beq risk_normal
    cmp x18, #4
    blt risk_medium

// 4 o mas --> ALTO
risk_high:
    adr x1, str_risk_high
    bl copiar_cadena
    b risk_done

// 1-3 --> MEDIO
risk_medium:
    adr x1, str_risk_medium
    bl copiar_cadena
    b risk_done

//0 --> NORMAL
risk_normal:
    adr x1, str_risk_normal
    bl copiar_cadena

risk_done:

    // ESCRIBIR EL ARCHIVO resultado_anomalias.txt
    mov x8, #56
    mov x0, #-100
    adr x1, archivo_salida
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

    // FIN DEL PROGRAMA
    mov x8, SYS_EXIT
    mov x0, 0
    svc 0

// NEWTON-RAPHSON para raiz cuadrada entera
// ENTRADA: x0 = numero a calcular raiz
// SALIDA:  x0 = raiz cuadrada entera (truncada)
raiz_cuadrada:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    str x20, [sp, #24]

    mov x19, x0     // Guardar numero

    cmp x19, #0
    beq raiz_es_cero    // beq: branch if equal (comparacion) √0 = 0

    lsr x20, x19, #1

    cmp x20, #0
    beq raiz_es_uno     // Si N/2 = 0, √N = 1

loop_newton:
    // x_nuevo = (x_actual + N/x_actual) / 2
    udiv x0, x19, x20   // x0 = N / x_actual
    add x0, x0, x20     // x0 = x_actual + N/x_actual
    lsr x0, x0, #1      // x0 = (x_actual + N/x_actual) / 2

    cmp x0, x20
    bge raiz_lista      // Si no mejora, convergió

    mov x20, x0         // Actualizar estimado
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

// ----- FUNCIONES PARA COPIAR AL BUFFER -----

// Copiar cadena terminada en \0 desde x1 hacia buffer_salida
// x9 mantiene la cuenta de bytes escritos
copiar_cadena:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
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

// Agregar salto de linea al buffer
copiar_newline:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10               // codigo ASCII del salto de linea
    strb w2, [x0, x9]
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret