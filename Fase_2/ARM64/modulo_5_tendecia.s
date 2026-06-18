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
 