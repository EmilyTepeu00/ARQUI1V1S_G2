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
    mov x28, x3         // Guarda x3 para restaurar el stack luego
    mov x19, x0         // x19 = puntero al primer dato
    mov x27, x2         // x27 = N (cantidad de datos)

    // CALCULAR MEDIA
    // Se usa x20 como contador y x21 como acumulador de suma
    bl  subr_calcular_media

    // CALCULAR DESVIACION ESTANDAR
    // Se usa x24 = media, x22 = acumulador de cuadrados
    bl  subr_calcular_desviacion

    // CONTAR ANOMALIAS
    // Se usa x24 = media, x25 = desviacion estandar
    bl  subr_contar_anomalias

    // ESCRIBIR RESULTADOS EN ARCHIVO
    bl  subr_escribir_resultado

    // RESTAURAR STACK Y TERMINAR
    mov sp, x28         // Se restaura la pila a su estado original
    mov x8, SYS_EXIT
    mov x0, 0
    svc 0

// CALCULAR MEDIA ARITMETICA: MEDIA = ΣX / N
// ENTRADA: x19 = puntero al primer dato, x27 = N
// SALIDA:  res_mean tiene la media calculada
subr_calcular_media:
    stp x29, x30, [sp, #-32]!   // Guarda frame pointer y link register
    stp x19, x20, [sp, #16]     // Guarda registros
    mov x29, sp                 // Establecer frame pointer

    // Guardar una copia del puntero original porque vamos a modificarlo
    mov x28, x19                // x28 = copia del puntero al primer dato

    // Inicializar contadores
    mov x20, #0     // x20 = i = 0
    mov x21, #0     // x21 = suma = 0

calc_mean_loop:
    cmp x20, x27             // i == N?
    bge calc_mean_fin        // Si si, terminar

    ldr x23, [x28]           // x23 = datos[i] (leer del stack)
    add x21, x21, x23        // suma += datos[i]

    add x20, x20, #1         // i++
    sub x28, x28, #16        // Avanzar al siguiente dato (se resta porque el stack crece hacia abajo)
    b calc_mean_loop

calc_mean_fin:
    udiv x24, x21, x27       // x24 = MEDIA = suma / N

    adr x9, res_mean
    str x24, [x9]            // Guardar resultado

    ldp x19, x20, [sp, #16]  // Restaurar registros
    ldp x29, x30, [sp], #32  // Restaurar frame pointer y retornar
    ret

// VAR = Σ(X - MEDIA)² / N, DESV = √VAR
// ENTRADA: x19 = puntero al primer dato, x27 = N, res_mean = media
// SALIDA:  res_std tiene la desviacion estandar
subr_calcular_desviacion:
    stp x29, x30, [sp, #-48]!   // Guardar frame pointer y link register
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp

    // Leer la media desde memoria
    adr x9, res_mean
    ldr x24, [x9]       // x24 = MEDIA

    // Guardar copia del puntero original
    mov x28, x19        // x28 = copia del puntero al primer dato

    // Inicializar contadores
    mov x20, #0         // i = 0
    mov x21, #0         // suma_cuadrados = 0

calc_var_loop:
    cmp x20, x27        // i == N?
    bge calc_var_fin

    ldr x22, [x28]           // x22 = datos[i]
    sub x22, x22, x24        // x22 = datos[i] - MEDIA
    mul x23, x22, x22        // x23 = (datos[i] - MEDIA)²
    add x21, x21, x23        // suma_cuadrados += (datos[i] - MEDIA)²

    add x20, x20, #1         // i++
    sub x28, x28, #16        // Siguiente dato
    b calc_var_loop

calc_var_fin:
    udiv x26, x21, x27       // x26 = VARIANZA = suma_cuadrados / N

    // Calcular raiz cuadrada con Newton-Raphson
    mov x0, x26
    bl subr_raiz_cuadrada    // x0 = DESVIACION ESTANDAR

    adr x9, res_std
    str x0, [x9]             // Guardar desviacion estandar

    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// NEWTON-RAPHSON para raiz cuadrada entera
// ENTRADA: x0 = numero a calcular raiz
// SALIDA:  x0 = raiz cuadrada entera (truncada)
subr_raiz_cuadrada:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp

    mov x19, x0     // Guardar numero

    cmp x19, #0
    beq sqrt_cero   // beq: branch if equal (comparacion) √0 = 0

    lsr x20, x19, #1    // x20 = estimado inicial = N/2
    cmp x20, #0
    beq sqrt_uno        // Si N/2 = 0, √N = 1

sqrt_loop:
    // x_nuevo = (x_actual + N/x_actual) / 2
    udiv x0, x19, x20   // x0 = N / x_actual
    add x0, x0, x20     // x0 = x_actual + N/x_actual
    lsr x0, x0, #1      // x0 = (x_actual + N/x_actual) / 2

    cmp x0, x20
    bge sqrt_listo      // Si no mejora, convergió

    mov x20, x0         // Actualizar estimado
    b sqrt_loop

sqrt_listo:
    mov x0, x20
    b sqrt_fin

sqrt_cero:
    mov x0, #0
    b sqrt_fin

sqrt_uno:
    mov x0, #1

sqrt_fin:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Cuenta datos donde |Z| >= 2, usando Z = (X - MEDIA) / DESV
// ENTRADA: x19 = puntero al primer dato, x27 = N
// SALIDA:  res_anomalias tiene la cantidad de anomalias
subr_contar_anomalias:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp

    // Leer media y desviacion estandar
    adr x9, res_mean
    ldr x24, [x9]       // x24 = MEDIA
    adr x9, res_std
    ldr x25, [x9]       // x25 = DESV

    // Guardar copia del puntero original
    mov x28, x19        // x28 = copia del puntero al primer dato

    mov x20, #0         // i = 0
    mov x26, #0         // contador_anomalias = 0

    // Si DESV = 0, todos los datos son iguales y no hay anomalias
    cmp x25, #0
    beq anom_fin

anom_loop:
    cmp x20, x27        // i == N?
    bge anom_fin

    ldr x21, [x28]      // x21 = datos[i]

    // Calcular |dato - media|
    sub x22, x21, x24
    cmp x22, #0
    bge anom_positivo
    neg x22, x22        // Si es negativo, hacerlo positivo

anom_positivo:
    // Z = |dato - media| / desv
    // Se multiplica por 10 para evitar decimales
    // |Z| >= 2 equivale a |Z|*10 >= 20
    mov x9, #10
    mul x22, x22, x9
    udiv x23, x22, x25

    cmp x23, #20
    blt anom_siguiente

    // Si |Z| >= 2, es una anomalia
    add x26, x26, #1

anom_siguiente:
    add x20, x20, #1
    sub x28, x28, #16   // Siguiente dato
    b anom_loop

anom_fin:
    adr x9, res_anomalias
    str x26, [x9]       // Guardar cantidad de anomalias

    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Genera el archivo resultado_anomalias.txt con todos los resultados
// Clasificacion de riesgo segun las anomalias
subr_escribir_resultado:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp

    // Inicializar buffer de salida
    adr x20, buffer_salida   // x20 = puntero de escritura en el buffer

    // MODULE=ANOMALY_DETECTION
    adr x0, str_module
    bl copiar_a_buffer

    // TOTAL_VALUES=30
    adr x0, str_total
    bl copiar_a_buffer

    // MEAN=
    adr x0, str_mean_label
    bl copiar_a_buffer
    adr x9, res_mean
    ldr x0, [x9]
    bl convertir_y_copiar

    // STD_DEV=
    adr x0, str_std_label
    bl copiar_a_buffer
    adr x9, res_std
    ldr x0, [x9]
    bl convertir_y_copiar

    // ANOMALIES=
    adr x0, str_anom_label
    bl copiar_a_buffer
    adr x9, res_anomalias
    ldr x0, [x9]
    bl convertir_y_copiar

    // SYSTEM_RISK=
    adr x0, str_risk_label
    bl copiar_a_buffer

    // Clasificar segun la cantidad de anomalias
    adr x9, res_anomalias
    ldr x0, [x9]
    cmp x0, #0
    beq er_risk_normal
    cmp x0, #4
    blt er_risk_medium

// 4 o mas --> ALTO
er_risk_high:
    adr x0, str_risk_high
    bl copiar_a_buffer
    b er_guardar_archivo

// 1-3 --> MEDIO
er_risk_medium:
    adr x0, str_risk_medium
    bl copiar_a_buffer
    b er_guardar_archivo

//0 --> NORMAL
er_risk_normal:
    adr x0, str_risk_normal
    bl copiar_a_buffer

er_guardar_archivo:
    // Calcular longitud total del buffer
    adr x1, buffer_salida
    sub x26, x20, x1        // x26 = bytes totales escritos

    // ABRIR/CREAR ARCHIVO DE SALIDA
    mov x8, SYS_OPENAT
    mov x0, AT_FDCWD
    adr x1, archivo_salida
    mov x2, O_WRONLY | O_CREAT | O_TRUNC
    mov x3, PERM_644
    svc 0
    cmp x0, 0
    blt er_fin
    mov x19, x0     // x19 = descriptor del archivo

    // ESCRIBIR AL ARCHIVO
    mov x8, SYS_WRITE
    mov x0, x19
    adr x1, buffer_salida
    mov x2, x26
    svc 0

    // CERRAR ARCHIVO
    mov x8, SYS_CLOSE
    mov x0, x19
    svc 0

er_fin:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Convertir numero en x0 a texto y lo copia al buffer con salto de linea
convertir_y_copiar:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adr x1, buf_conv
    bl int_a_ascii
    adr x0, buf_conv
    bl copiar_a_buffer

    // Agregar salto de linea
    mov w9, #10
    strb w9, [x20], #1

    ldp x29, x30, [sp], #16
    ret

// ----- FUNCIONES AUXILIARES ------

// Copiar cadena terminada en \0 desde x0 hacia x20
// x20 avanza automaticamente con cada caracter copiado
copiar_a_buffer:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

copiar_loop:
    ldrb w9, [x0], #1       // Leer byte y avanzar x0
    cbz w9, copiar_fin      // Si es '\0', terminar
    strb w9, [x20], #1      // Guardar byte y avanzar x20
    b copiar_loop

copiar_fin:
    ldp x29, x30, [sp], #16
    ret