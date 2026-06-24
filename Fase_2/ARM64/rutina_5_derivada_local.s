// rutina_5_derivada_local.s
// Derivada Suavizada por Regresion Local
// Emily Maritza Tepeu Guacamaya - 202402955
//
// Calcula la velocidad de cambio local usando mini-ventanas de 5 puntos
// Para cada ventana se calcula la pendiente por regresion lineal simple
// Formula simplificada para X = 0,1,2,3,4
//      suma(X) = 10, suma(X*X) = 30, denominador = 50
//      LOCAL_SLOPE_X100 = ((5 * suma(X*Y) - 10 * suma(Y)) * 100) / 50


// FUNCIONES EXTERNAS
.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

// CONSTANTES
.equ SYS_OPENAT,  56    // abrir archivo
.equ SYS_CLOSE,   57    // cerrar archivo
.equ SYS_WRITE,   64    // escribir en el archivo
.equ SYS_EXIT,    93    // terminar el programa
.equ AT_FDCWD,   -100   // le dice al sistema que use el directorio actual
.equ O_WRONLY,    1     // modo escribir solo
.equ O_CREAT,     64    // crear archivo si no existe
.equ O_TRUNC,     512   // borrar contenido si ya existe
.equ PERM_644,    0644  // permisos del archivo (rw-r--r--)
.equ WINDOW_SIZE, 5     // Tamaño fijo de cada mini-ventana
.equ SUMA_X,     10     // sum(X) para X=0,1,2,3,4
.equ SUMA_X2,    30     // sum(X*X) para X=0,1,2,3,4
.equ DENOM,      50     // (5*SUMA_X2) - (SUMA_X*SUMA_X)

.section .data

// NOMBRE DEL ARCHIVO DE ENTRADA Y SALIDA
archivo_default: .asciz "lecturas.csv"
archivo_salida:  .asciz "resultado_derivada.txt"

// ETIQUETAS PARA EL ARCHIVO DE SALIDA
str_calc:        .asciz "CALC=LOCAL_DERIVATIVE\n"
label_column:    .asciz "COLUMN="
label_wstart:    .asciz "WINDOW_START="
label_wend:      .asciz "WINDOW_END="
label_count:     .asciz "COUNT="
label_wsize:     .asciz "WINDOW_SIZE=5\n"
label_max_slope: .asciz "MAX_LOCAL_SLOPE_X100="
str_status_ok:   .asciz "STATUS=OK\n"
str_status_error:.asciz "STATUS=ERROR\n"
str_error:       .asciz "ERROR=INSUFFICIENT_DATA\n"
str_detail:      .asciz "DETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES\n"

.section .bss

// BUFFERS NUMERICOS
buf_num1:      .skip 32
buf_num2:      .skip 32
buf_num3:      .skip 32

// BUFFER PRINCIPAL
buffer_salida: .skip 512

// ARGUMENTOS GUARDADOS EN MEMORIA
arg_columna:      .skip 8
arg_window_start: .skip 8
arg_window_end:   .skip 8

// DATOS COPIADOS
datos_copia:   .skip 1024    // hasta 64 datos de 8 bytes cada uno

// RESULTADOS
res_max_slope: .skip 8

.section .text
.global _start

// ----- PROGRAMA PRINCIPAL -----
_start:
    // LECTURA DE ARGUMENTOS
    // [sp] = argc
    ldr x0, [sp]
    cmp x0, #5
    blt usar_default

    ldr x17, [sp, #16]      // archivo

    ldr x0, [sp, #24]       // argv[2] = linea inicial
    bl ascii_a_int
    mov x12, x0

    ldr x0, [sp, #32]       // argv[3] = linea final
    bl ascii_a_int
    mov x13, x0

    ldr x0, [sp, #40]       // argv[4] = columna
    bl ascii_a_int
    mov x11, x0

    // GUARDAR COPIAS PARA LA SALIDA
    adr x0, arg_columna
    str x11, [x0]

    adr x0, arg_window_start
    str x12, [x0]

    adr x0, arg_window_end
    str x13, [x0]

    b llamar_leer_5

usar_default:
    mov x11, #7
    mov x12, #1
    mov x13, #30
    adr x17, archivo_default

    adr x0, arg_columna
    str x11, [x0]

    adr x0, arg_window_start
    str x12, [x0]

    adr x0, arg_window_end
    str x13, [x0]

llamar_leer_5:
    bl read_column_to_stack

    mov x24, x0
    mov x25, x1
    mov x26, x3
    mov x27, x2     // COUNT = cantidad de datos

    // VERIFICAR QUE HAYA AL MENOS 5 DATOS
    cmp x27, #5
    bge copiar_datos

    // Si hay menos, mostrar error y salir
    bl escribir_error_insuficiente

copiar_datos:
    // COPIAR DATOS AL BUFFER
    mov x6, x24
    adr x4, datos_copia
    mov x5, x27

copia_loop:
    cbz x5, copia_fin
    ldr x9, [x6], #16
    str x9, [x4], #8
    sub x5, x5, #1
    b copia_loop

copia_fin:

    // CALCULAR PENDIENTES LOCALES
    // Cada ventana usa 5 puntos consecutivos
    // Total de ventanas = N - 5 + 1 = N - 4
    adr x6, datos_copia
    mov x20, #0         // contador de ventanas procesadas
    mov x21, #0         // total de ventanas = x27 - 4
    sub x21, x27, #4
    mov x22, #0         // maximo slope encontrado (inicializar en 0)
    mov x23, #0         // contador de puntos dentro de la ventana

calcular_ventanas:
    cmp x20, x21
    bge fin_calculo

    // Reiniciar acumuladores para esta ventana
    mov x24, #0         // suma(Y)
    mov x25, #0         // suma(X*Y)  (X = 0,1,2,3,4)
    mov x23, #0         // contador de puntos en ventana

    // Guardar puntero al inicio de la ventana
    mov x19, x6

calcular_puntos_ventana:
    cmp x23, #5
    bge ventana_lista

    ldr x9, [x19]       // cargar Y actual

    // sumar Y
    add x24, x24, x9

    // sumar X*Y (X = 0,1,2,3,4)
    // Con el contador x23 como X
    mul x10, x23, x9
    add x25, x25, x10

    add x23, x23, #1
    add x19, x19, #8
    b calcular_puntos_ventana

ventana_lista:
    // Calcular slope para esta ventana
    // LOCAL_SLOPE_X100 = ((5 * suma(X*Y) - 10 * suma(Y)) * 100) / 50
    //                  = ((5*sumaXY - 10*sumaY) * 100) / 50
    //                  = (5*sumaXY - 10*sumaY) * 2

    // 5 * sumaXY
    mov x10, #5
    mul x11, x25, x10

    // 10 * sumaY
    mov x10, #10
    mul x12, x24, x10

    // 5*sumaXY - 10*sumaY
    sub x13, x11, x12

    // Simplificado: (5*sumaXY - 10*sumaY) * 2
    mov x10, #2
    mul x15, x13, x10

    // Comparar con maximo actual
    cmp x15, x22
    ble ventana_siguiente

    // Nuevo maximo
    mov x22, x15

ventana_siguiente:
    // Avanzar al siguiente dato (ventana se desplaza 1 posicion)
    add x6, x6, #8
    add x20, x20, #1
    b calcular_ventanas

fin_calculo:
    // Guardar el maximo slope
    adr x9, res_max_slope
    str x22, [x9]

    // RESTAURAR STACK
    mov sp, x26

    // GENERAR SALIDA
    adr x0, buffer_salida
    mov x9, #0

    // CALC=LOCAL_DERIVATIVE
    adr x1, str_calc
    bl copiar_cadena

    // COLUMN=
    adr x1, label_column
    bl copiar_cadena
    mov x23, x9

    adr x2, arg_columna
    ldr x0, [x2]

    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_START=
    adr x1, label_wstart
    bl copiar_cadena
    mov x23, x9

    adr x2, arg_window_start
    ldr x0, [x2]

    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_END=
    adr x1, label_wend
    bl copiar_cadena
    mov x23, x9

    adr x2, arg_window_end
    ldr x0, [x2]

    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // COUNT=
    adr x1, label_count
    bl copiar_cadena
    mov x23, x9
    mov x0, x27
    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_SIZE=5
    adr x1, label_wsize
    bl copiar_cadena

    // MAX_LOCAL_SLOPE_X100=
    adr x1, label_max_slope
    bl copiar_cadena
    mov x23, x9

    adr x2, res_max_slope
    ldr x0, [x2]

    adr x1, buf_num2
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num2
    bl copiar_cadena
    bl copiar_newline

    // STATUS=OK
    adr x1, str_status_ok
    bl copiar_cadena

    // ESCRIBIR ARCHIVO
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


// ----- ESCRIBIR ERROR POR DATOS INSUFICIENTES -----
escribir_error_insuficiente:
    adr x0, buffer_salida
    mov x9, #0

    adr x1, str_calc
    bl copiar_cadena

    adr x1, label_column
    bl copiar_cadena
    mov x23, x9

    adr x2, arg_columna
    ldr x0, [x2]

    adr x1, buf_num1
    bl int_a_ascii
    mov x9, x23
    adr x0, buf_num1
    bl copiar_cadena
    bl copiar_newline

    adr x1, str_status_error
    bl copiar_cadena

    adr x1, str_error
    bl copiar_cadena

    adr x1, str_detail
    bl copiar_cadena

    // ESCRIBIR ARCHIVO DE ERROR
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

    // TERMINAR EL PROGRAMA
    mov x8, SYS_EXIT
    mov x0, #1
    svc 0

// ----- FUNCIONES AUXILIARES -----

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

copiar_newline:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10
    strb w2, [x0, x9]
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret