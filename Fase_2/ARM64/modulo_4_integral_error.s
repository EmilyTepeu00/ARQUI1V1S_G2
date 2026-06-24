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