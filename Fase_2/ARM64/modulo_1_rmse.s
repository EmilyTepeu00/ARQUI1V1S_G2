// modulo_1_rmse.s

// archivo linea_inicial linea_final columna_sensor

// Formulas:
//   ERROR_i  = Y_i - IDEAL
//   ERROR2_i = ERROR_i * ERROR_i
//   MSE      = suma(ERROR2_i) / N       
//   RMSE     = sqrt_entera(MSE)

.data

IDEAL:
    .quad 55         

msg_calc:
    .ascii "CALC=RMSE\n"
    len_msg_calc = . - msg_calc

msg_column:
    .ascii "COLUMN="
    len_msg_column = . - msg_column

msg_wstart:
    .ascii "WINDOW_START="
    len_msg_wstart = . - msg_wstart

msg_wend:
    .ascii "WINDOW_END="
    len_msg_wend = . - msg_wend

msg_count:
    .ascii "COUNT="
    len_msg_count = . - msg_count

msg_ideal:
    .ascii "IDEAL="
    len_msg_ideal = . - msg_ideal

msg_rmse:
    .ascii "RMSE="
    len_msg_rmse = . - msg_rmse

msg_status_ok:
    .ascii "STATUS=OK\n"
    len_msg_status_ok = . - msg_status_ok

msg_status_error:
    .ascii "STATUS=ERROR\n"
    len_msg_status_error = . - msg_status_error

msg_err_label:
    .ascii "ERROR="
    len_msg_err_label = . - msg_err_label

msg_detail_label:
    .ascii "DETAIL="
    len_msg_detail_label = . - msg_detail_label

err_args:
    .ascii "INVALID_ARGS\n"
    len_err_args = . - err_args

detail_args:
    .ascii "EXPECTED_4_ARGS\n"
    len_detail_args = . - detail_args

err_insufficient:
    .ascii "INSUFFICIENT_DATA\n"
    len_err_insufficient = . - err_insufficient

detail_insufficient:
    .ascii "RMSE_REQUIRES_AT_LEAST_2_VALUES\n"
    len_detail_insufficient = . - detail_insufficient

newline:
    .ascii "\n"

.bss

ascii_buffer:
    .skip 32

// almacenamiento temporal de los argumentos de entrada, guardados

saved_linea_inicial:
    .skip 8
saved_linea_final:
    .skip 8
saved_columna:
    .skip 8
