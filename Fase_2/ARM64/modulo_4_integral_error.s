//Modulo 4 - Integral del Error por Regla del Trapecio

//Definicion de cadenas de texto para el archivo de salida
.data

filename_out:
    .asciz "resultado_integral.txt"

msg_no_arg:
    .ascii "Faltan argumentos\n"
    msg_no_arg_len = . - msg_no_arg

str_module:
    .asciz "MODULE=ERROR_INTEGRAL\n"

str_calc:
    .asciz "CALC=ERROR_INTEGRAL\n"

str_column:
    .asciz "COLUMN="

str_wstart:
    .asciz "WINDOW_START="

str_wend:
    .asciz "WINDOW_END="

str_count:
    .asciz "COUNT="

str_ideal:
    .asciz "IDEAL="

str_integral:
    .asciz "ERROR_INTEGRAL="

str_status_ok:
    .asciz "STATUS=OK\n"

str_status_err:
    .asciz "STATUS=ERROR\n"

str_err_insuf:
    .asciz "ERROR=INSUFFICIENT_DATA\n"

str_detail_insuf:
    .asciz "DETAIL=INTEGRAL_REQUIRES_AT_LEAST_2_VALUES\n"

str_nl:
    .asciz "\n"

ideal_val:
    .quad 55

.bss

num_buffer:
    .skip 32

g_columna:
    .skip 8

g_wstart:
    .skip 8

g_wend:
    .skip 8

g_count:
    .skip 8

g_integral:
    .skip 8

.text

//Inicializacion del Programa
//.extern solo para utilizar las funciones q se encuentran dentro del utils.s
.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.global _start

_start:

    ldr x0, [sp]                //Toma el argc para revisar cantidad de argumentos
    cmp x0, #5                  //Se esperan 4 argumentos reales mas argv[0]
    blt no_argumento            //Si no hay suficientes, se va al error

    ldr x0, [sp, #24]           //Toma el puntero al texto de la linea inicial
    bl ascii_a_int              //Convierte el texto a numero real (resultado en x0)
    mov x6, x0                  //Guarda la linea inicial en x6

    ldr x0, [sp, #32]           //Toma el puntero al texto de la linea final
    bl ascii_a_int              //Convierte el texto a numero real (resultado en x0)
    mov x7, x0                  //Guarda la linea final en x7

    ldr x0, [sp, #40]           //Toma el puntero al texto de la columna
    bl ascii_a_int              //Convierte el texto a numero real (resultado en x0)
    mov x9, x0                  //Guarda la columna en x9

    ldr x0, =g_columna          //Carga la direccion de la variable de columna
    str x9, [x0]                //Guarda la columna en memoria para usarla en la salida
    ldr x0, =g_wstart           //Carga la direccion de la variable de linea inicial
    str x6, [x0]                //Guarda la linea inicial en memoria para la salida
    ldr x0, =g_wend             //Carga la direccion de la variable de linea final
    str x7, [x0]                //Guarda la linea final en memoria para la salida

    mov x11, x9                 //Mueve la columna al registro que espera read_column_to_stack
    mov x12, x6                 //Mueve la linea inicial al registro que espera read_column_to_stack
    mov x13, x7                 //Mueve la linea final al registro que espera read_column_to_stack
    ldr x17, [sp, #16]          //Pasa el nombre de archivo en x17, lo necesita utils.s
    bl read_column_to_stack     //Esta funcion abre el csv, lo lee y guarda los datos del rango

    mov x24, x0                 //Se guarda el inicio de los datos en pila
    mov x25, x1                 //Se guarda el limite final de los datos en pila
    mov x26, x2                 //Se guarda la cantidad total de datos leidos
    mov x27, x3                 //Se guarda la posicion para restaurar la pila

    ldr x0, =g_count            //Carga la direccion del contador de datos
    str x26, [x0]               //Guarda N en memoria para usarlo en la salida

    cmp x26, #2                 //Revision de datos totales leidos
    blt error_insuficiente      //Si hay menos de 2 datos no se puede calcular el trapecio