//Modulo 5 - Tendencia
//Definicion de cadenas de texto para el archivo de salida

.data
 
filename_out:
    .asciz "resultado_tendencia.txt"
 
msg_no_arg:
    .ascii "Debe enviar una columna\n"
    msg_no_arg_len = . - msg_no_arg
 
str_module:
    .asciz "MODULE=ADVANCED_TREND\n"
 
str_total:
    .asciz "TOTAL_VALUES="
 
str_incr:
    .asciz "INCREMENTS="
 
str_decr:
    .asciz "DECREMENTS="
 
str_max_up:
    .asciz "MAX_UP_STREAK="
 
str_max_down:
    .asciz "MAX_DOWN_STREAK="
 
str_accum:
    .asciz "ACCUM_DIFF="
 
str_trend:
    .asciz "TREND="
 
str_up:
    .asciz "UP\n"
 
str_down:
    .asciz "DOWN\n"
 
str_stable:
    .asciz "STABLE\n"
 
str_minus:
    .asciz "-"
 
str_nl:
    .asciz "\n"
 
.bss
 
num_buffer:
    .skip 32
 
.text


 
// Inicializacion del Programa importando al Utils.s
.include "utils.s"

.global _start

_start:

    ldr x0, [sp]            //Revisa el numero de columna q deseamos analizar
    cmp x0, #2              // Se compara con el #2
    blt no_argumento        // Muestra error si el no. de columna < 2
 
    ldr x21, [sp, #16]      //Toma el numero de columna a trabajar
    mov x5, #10             //Aviso para trabajar en base 10
    bl atoi_csv             //Cambia el texto extraido a numero real
    cbz x7, no_argumento    //Error si el texto extraido no es un numero
 
    mov x11, x10            //Mueve el numero de columna ingresado
    bl read_column_to_stack //Esta funcion abre el csv, lo lee y guarda los 30 datos
 
    mov x24, x0             //Se guardan 4 datos importantes (Ultimo dato guardado, donde se guardo el ultimo dato, datos totales leidos, dato extra para ordenar de nuevo la pila)
    mov x25, x1
    mov x26, x2
    mov x27, x3
 
    mov x10, #0             //Se limpian 7 registros para contar y guardar calculos
    mov x11, #0
    mov x12, #0
    mov x13, #0
    mov x14, #0
    mov x15, #0
    mov x16, #0
 
    cmp x26, #2            //Revision de datos totales leidos
    blt fin_calculo        //Error si hubieron menos de 2 datos
 
    sub x21, x25, #16      //Se calcula donde se encuentra el dato mas reciente
    ldr x22, [x21]         //Se guarda ese dato reciente listo para empezar a comparar
    sub x21, x21, #16      //Se mueve al segundo dato para compararse con el anterior
