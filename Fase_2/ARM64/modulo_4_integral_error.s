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
    ldr x9, [sp, #16]           //Pasa el nombre de archivo en x9, lo necesita utils.s
    bl read_column_to_stack     //Esta funcion abre el csv, lo lee y guarda los datos del rango

    mov x24, x0                 //Se guarda el inicio de los datos en pila
    mov x25, x1                 //Se guarda el limite final de los datos en pila
    mov x26, x2                 //Se guarda la cantidad total de datos leidos
    mov x27, x3                 //Se guarda la posicion para restaurar la pila

    ldr x0, =g_count            //Carga la direccion del contador de datos
    str x26, [x0]               //Guarda N en memoria para usarlo en la salida

    cmp x26, #2                 //Revision de datos totales leidos
    blt error_insuficiente      //Si hay menos de 2 datos no se puede calcular el trapecio

    ldr x0, =ideal_val          //Carga la direccion del valor IDEAL
    ldr x10, [x0]               //Carga el valor IDEAL (55) en x10

    mov x21, x24                //Apunta al primer dato leido (mas antiguo)
    mov x16, #0                 //Inicia el acumulador AREA_ERROR en cero
    mov x14, x26                //Carga N en x14
    sub x14, x14, #1            //Se haran N-1 iteraciones (pares consecutivos)

bucle_trapecio:                 //Aqui se calculan las areas de los trapecios y se acumulan
    cbz x14, fin_calculo        //Si ya no quedan iteraciones se termina

    ldr x18, [x21]              //Carga Y_i del par actual
    add x22, x21, #16           //Calcula la direccion del siguiente dato Y_(i+1)
    ldr x19, [x22]              //Carga Y_(i+1) del par actual

    sub x20, x18, x10           //Calcula Y_i - IDEAL
    cmp x20, #0                 //Revisa si el resultado es negativo
    bge err_i_pos               //Si es positivo o cero, pasa de largo
    neg x20, x20                //Si es negativo, lo convierte a positivo (valor absoluto)
err_i_pos:                      //Aqui x20 ya tiene ERROR_i = abs(Y_i - IDEAL)

    sub x23, x19, x10           //Calcula Y_(i+1) - IDEAL
    cmp x23, #0                 //Revisa si el resultado es negativo
    bge err_next_pos            //Si es positivo o cero, pasa de largo
    neg x23, x23                //Si es negativo, lo convierte a positivo (valor absoluto)
err_next_pos:                   //Aqui x23 ya tiene ERROR_NEXT = abs(Y_(i+1) - IDEAL)

    add x28, x20, x23           //Suma los dos errores consecutivos
    lsr x28, x28, #1            //Divide entre 2 para obtener AREA_TRAPECIO

    add x16, x16, x28           //Acumula AREA_TRAPECIO en AREA_ERROR

    add x21, x21, #16           //Avanza el puntero al siguiente dato
    sub x14, x14, #1            //Reduce el contador de iteraciones
    b bucle_trapecio            //Repite el ciclo con el siguiente par

fin_calculo:
    ldr x0, =g_integral         //Carga la direccion de la variable de integral
    str x16, [x0]               //Guarda el resultado final AREA_ERROR en memoria

    mov sp, x27                 //Se restaura el stack antes de escribir el archivo

    mov x0, #-100               //Se prepara para abrir el archivo de salida
    ldr x1, =filename_out       //Se carga la direccion del nombre del archivo de salida
    mov x2, #577                //Flags para abrir el archivo (O_WRONLY | O_CREAT | O_TRUNC)
    mov x3, #420                //Permisos para el archivo (rw-r--r--)
    mov x8, #56                 //Numero de syscall para abrir archivos
    svc #0                      //Se hace la syscall para abrir el archivo
    mov x23, x0                 //Se guarda el descriptor del archivo de salida

    ldr x1, =str_module         //Se escribe el nombre del modulo
    bl write_str

    ldr x1, =str_calc           //Se escribe el calculo realizado
    bl write_str

    ldr x1, =str_column         //Se escribe la columna analizada
    bl write_str
    ldr x0, =g_columna          //Carga la direccion de la columna guardada
    ldr x0, [x0]                //Carga el valor de la columna
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte la columna a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe la columna
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_wstart         //Se escribe la linea inicial
    bl write_str
    ldr x0, =g_wstart           //Carga la direccion de la linea inicial guardada
    ldr x0, [x0]                //Carga el valor de la linea inicial
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte la linea inicial a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe la linea inicial
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_wend           //Se escribe la linea final
    bl write_str
    ldr x0, =g_wend             //Carga la direccion de la linea final guardada
    ldr x0, [x0]                //Carga el valor de la linea final
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte la linea final a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe la linea final
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_count          //Se escribe la cantidad de datos usados
    bl write_str
    ldr x0, =g_count            //Carga la direccion del contador de datos
    ldr x0, [x0]                //Carga el valor de N
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte N a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe N
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_ideal          //Se escribe el valor IDEAL
    bl write_str
    ldr x0, =ideal_val          //Carga la direccion del valor IDEAL
    ldr x0, [x0]                //Carga el valor IDEAL
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte el IDEAL a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe el IDEAL
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_integral       //Se escribe la integral del error acumulada
    bl write_str
    ldr x0, =g_integral         //Carga la direccion de la integral guardada
    ldr x0, [x0]                //Carga el valor final de la integral
    ldr x1, =num_buffer         //Carga el buffer para convertir el numero
    bl int_a_ascii              //Convierte la integral a texto
    ldr x1, =num_buffer         //Carga el buffer para escribirlo
    bl write_str                //Escribe la integral
    ldr x1, =str_nl             //Escribe un salto de linea
    bl write_str

    ldr x1, =str_status_ok      //Se escribe el status final OK
    bl write_str

    mov x0, x23                 //Se cierra el archivo de salida
    mov x8, #57                 //Numero de syscall para cerrar archivos
    svc #0
    b salir_ok

error_insuficiente:
    mov sp, x27                 //Se restaura el stack antes de escribir el error

    mov x0, #-100               //Se prepara para abrir el archivo de salida
    ldr x1, =filename_out       //Se carga la direccion del nombre del archivo
    mov x2, #577                //Flags para abrir el archivo
    mov x3, #420                //Permisos para el archivo
    mov x8, #56                 //Numero de syscall para abrir archivos
    svc #0
    mov x23, x0                 //Se guarda el descriptor del archivo

    ldr x1, =str_module         //Se escribe el nombre del modulo
    bl write_str
    ldr x1, =str_status_err     //Se escribe STATUS=ERROR
    bl write_str
    ldr x1, =str_err_insuf      //Se escribe el tipo de error
    bl write_str
    ldr x1, =str_detail_insuf   //Se escribe el detalle del error
    bl write_str

    mov x0, x23                 //Se cierra el archivo de salida
    mov x8, #57
    svc #0
    b salir_error

no_argumento:
    mov x0, #1                  //Si no se ingresaron suficientes argumentos
    ldr x1, =msg_no_arg         //Se carga la direccion del mensaje de error
    mov x2, msg_no_arg_len      //Se carga la longitud del mensaje de error
    mov x8, #64                 //Numero de syscall para escribir en pantalla
    svc #0                      //Se imprime el mensaje de error
    b salir_error               //Termina el programa con un codigo de error

write_str:
    mov x2, #0                  //Se calcula la longitud de la cadena de texto a escribir

write_str_len:
    ldrb w0, [x1, x2]           //Se carga un byte de la cadena de texto
    cbz w0, write_str_done      //Si el byte es cero, ya termino la cadena
    add x2, x2, #1              //Si el byte no es cero, se incrementa la longitud
    b write_str_len             //Se repite el proceso para seguir contando

write_str_done:
    mov x0, x23                 //Se mueve el descriptor del archivo a x0
    mov x8, #64                 //Numero de syscall para escribir en archivos
    svc #0                      //Se hace la syscall para escribir la cadena
    ret

salir_ok:
    mov x0, #0                  //Termina el programa con un codigo de exito
    mov x8, #93
    svc #0

salir_error:
    mov x0, #1                  //Termina el programa con un codigo de error
    mov x8, #93
    svc #0