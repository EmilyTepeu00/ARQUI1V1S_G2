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