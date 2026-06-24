// utils.s
//
// Entrada:
//   x11 = columna seleccionada
//   x12 = linea inicial
//   x13 = linea final 
//
// Salida:
//   x0 = inicio de datos en stack
//   x1 = limite final de datos
//   x2 = cantidad de numeros guardados
//   x3 = posicion para restaurar stack

.data

filename:
    .asciz "lecturas.csv"

err_open:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=CANNOT_OPEN_FILE\n"
    len_err_open = . - err_open

err_read:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=READ_ERROR\nDETAIL=CANNOT_READ_FILE\n"
    len_err_read = . - err_read

err_col:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_DOES_NOT_EXIST\n"
    len_err_col = . - err_col

err_rango:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=RANGE_OUT_OF_BOUNDS\n"
    len_err_rango = . - err_rango

err_no_numerico:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=NON_NUMERIC_VALUE\nDETAIL=VALUE_NOT_NUMERIC\n"
    len_err_no_numerico = . - err_no_numerico

err_sin_datos:
    .ascii "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=NO_VALID_VALUES_IN_RANGE\n"
    len_err_sin_datos = . - err_sin_datos

.bss

buffer:
    .skip 65536         // para permitir archivos con miles de filas

.text

.global read_column_to_stack
.global int_a_ascii
.global ascii_a_int

read_column_to_stack:
    mov x26, x30
    mov x28, sp

    mov x5, #10              // base 10
    mov x22, #0              // contador de numeros
    mov x14, #0              // linea actual

    //validar columna
    cmp x11, #1
    blt utils_error_columna

    // validar linea inicial
    cmp x12, #1
    blt utils_error_rango

    // validar linea final
    cmp x13, x12
    blt utils_error_rango

    bl utils_open_file
    bl utils_read_file
    bl utils_close_file

    ldr x21, =buffer

    mov x16, #1               // x16 = contador de columnas en encabezado

utils_contar_encabezado:
    ldrb w23, [x21], #1

    cmp w23, '$'
    beq utils_fin_contar
    cmp w23, #0
    beq utils_fin_contar
    cmp w23, #10
    beq utils_fin_contar

    cmp w23, ','
    bne utils_contar_encabezado

     add x16, x16, #1
    b utils_contar_encabezado

utils_fin_contar:
    cmp x11, x16
    bgt utils_error_columna   // la columna pedida no existe en este archivo

    // reposicionar el puntero al inicio del buffer para procesar normal
    ldr x21, =buffer

    bl utils_skip_to_next_line

    cmp w23, '$'
    beq utils_done

utils_process_line:
    add x14, x14, #1            // siguiente fila de datos

    // optimizacion, linea final no seguir buscando columna
    cmp x14, x13
    bgt utils_done

    mov x15, #1                 // columna actual

utils_find_column:
    cmp x15, x11
    beq utils_read_column

    bl utils_skip_to_next_column

    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    beq utils_process_line

    add x15, x15, #1
    b utils_find_column

utils_read_column:
    bl atoi_csv

    cmp x14, x12
    blt utils_after_column

    cmp x14, x13
    bgt utils_after_column

    cmp x8, #1                  // si esta dentro del rango, validar que sea numerico
    beq utils_error_no_numerico
    cbz x7, utils_after_column

    bl utils_save_number

utils_after_column:
    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    beq utils_process_line

    bl utils_skip_to_next_line

    cmp w23, '$'
    beq utils_done

    b utils_process_line

utils_done:
    cmp x14, x13
    blt utils_error_rango

    cmp x22, #1
    blt utils_error_sin_datos

    mov x0, sp        // inicio de datos (ascendente)
    mov x1, x28       // limite final 
    mov x2, x22     
    mov x3, x28       // posicion para restaurar

    mov sp, x28
    mov x30, x26      
    ret

utils_open_file:
    mov x0, #-100
    ldr x1, =filename
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0

    cmp x0, #0
    blt utils_open_error

    mov x19, x0
    ret

utils_read_file:
    mov x20, #0 

utils_read_file_loop:
    mov x0, x19
    ldr x1, =buffer
    add x1, x1, x20
    mov x2, #65536
    sub x2, x2, x20
    cmp x2, #0
    ble utils_read_file_done

    mov x8, #63
    svc #0

    cmp x0, #0
    blt utils_read_error
    beq utils_read_file_done        // 0 bytes = ya no hay mas archivos

    add x20, x20, x0          // sumar lo leido en esta vuelta
    b utils_read_file_loop

utils_read_file_done:
    // marcar fin del contenido leído
    ldr x1, =buffer
    add x1, x1, x20
    mov w2, '$'
    strb w2, [x1]
    ret

utils_close_file:
    mov x0, x19
    mov x8, #57
    svc #0
    ret

utils_skip_to_next_line:
    ldrb w23, [x21], #1

    cmp w23, '$'
    beq utils_skip_done
    cmp w23, #10
    beq utils_skip_done

    b utils_skip_to_next_line

utils_skip_to_next_column:
    ldrb w23, [x21], #1

    cmp w23, '$'
    beq utils_skip_done
    cmp w23, #10
    beq utils_skip_done
    cmp w23, ','
    beq utils_skip_done

    b utils_skip_to_next_column

utils_skip_done:
    ret

utils_save_number:
    sub sp, sp, #16
    str x10, [sp]

    add x22, x22, #1
    ret

utils_open_error:
    mov x0, #1
    ldr x1, =err_open
    mov x2, len_err_open
    mov x8, #64
    svc #0
    b utils_exit_error

utils_read_error:
    mov x0, #1
    ldr x1, =err_read
    mov x2, len_err_read
    mov x8, #64
    svc #0
    b utils_exit_error

utils_error_columna:
    mov x0, #1
    ldr x1, =err_col
    mov x2, len_err_col
    mov x8, #64
    svc #0
    b utils_exit_error

utils_error_rango:
    mov x0, #1
    ldr x1, =err_rango
    mov x2, len_err_rango
    mov x8, #64
    svc #0
    b utils_exit_error

utils_error_no_numerico:
    mov x0, #1
    ldr x1, =err_no_numerico
    mov x2, len_err_no_numerico
    mov x8, #64
    svc #0
    b utils_exit_error

utils_error_sin_datos:
    mov x0, #1
    ldr x1, =err_sin_datos
    mov x2, len_err_sin_datos
    mov x8, #64
    svc #0
    b utils_exit_error

utils_exit_error:
    mov x0, #1
    mov x8, #93
    svc #0

// Convierte el numero del CSV a entero
// x10 = resultado
// x7 = indica si encontro digitos
// x8 = indicar si encontro un caracter invalido (no digito, no separador)
// x6 = signo, 1 = positivo, -1 = negativo
atoi_csv:
    mov x10, #0
    mov x7, #0
    mov x8, #0
    mov x6, #1            // signo por defecto: positivo

    // el primer caracter puede ser '-' 
    ldrb w23, [x21], #1

    cmp w23, '-'
    bne atoi_csv_check_first

    mov x6, #-1
    b atoi_csv_loop

atoi_csv_check_first:
    cmp w23, ','
    beq atoi_csv_done
    cmp w23, #10
    beq atoi_csv_done
    cmp w23, #13
    beq atoi_csv_done
    cmp w23, '$'
    beq atoi_csv_done
    cmp w23, #0
    beq atoi_csv_done

    cmp w23, '0'
    blt atoi_csv_invalido
    cmp w23, '9'
    bgt atoi_csv_invalido

    sub w23, w23, '0'
    mul x10, x10, x5
    add x10, x10, x23
    mov x7, #1

atoi_csv_loop:
    ldrb w23, [x21], #1

    cmp w23, ','
    beq atoi_csv_done
    cmp w23, #10
    beq atoi_csv_done
    cmp w23, #13
    beq atoi_csv_done
    cmp w23, '$'
    beq atoi_csv_done
    cmp w23, #0
    beq atoi_csv_done

    cmp w23, '0'
    blt atoi_csv_loop
    cmp w23, '9'
    bgt atoi_csv_loop

    sub w23, w23, '0'
    mul x10, x10, x5
    add x10, x10, x23
    mov x7, #1
    b atoi_csv_loop

atoi_csv_invalido:
    mov x8, #1
    b atoi_csv_loop

atoi_csv_done:
    cbz x7, atoi_csv_ret
    cmp x6, #-1
    bne atoi_csv_ret
    neg x10, x10

atoi_csv_ret:
    ret

// int_a_ascii: convierte numero en x0 a texto en buffer x1

int_a_ascii:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]

    mov x19, x0
    mov x20, x1
    mov x21, #0             // bandera: 1 si el numero es negativo

    cmp x19, #0
    bge int_a_ascii_check_cero
    mov x21, #1
    neg x19, x19              // trabajar con el valor absoluto

int_a_ascii_check_cero:
    cbnz x19, int_a_ascii_normal
    mov w2, '0'
    strb w2, [x20]
    strb wzr, [x20, #1]
    b int_a_ascii_fin

int_a_ascii_normal:
    sub sp, sp, #32
    mov x2, sp
    mov x3, #0

int_a_ascii_extraer:
    cbz x19, int_a_ascii_invertir
    mov x4, #10
    udiv x6, x19, x4
    msub x9, x6, x4, x19
    add w9, w9, '0'
    strb w9, [x2, x3]
    add x3, x3, #1
    mov x19, x6
    b int_a_ascii_extraer

int_a_ascii_invertir:
    mov x4, #0

    cbz x21, int_a_ascii_inv_loop
    mov w9, '-'
    strb w9, [x20, x4]
    add x4, x4, #1

int_a_ascii_inv_loop:
    cbz x3, int_a_ascii_nulo
    sub x3, x3, #1
    ldrb w9, [x2, x3]
    strb w9, [x20, x4]
    add x4, x4, #1
    b int_a_ascii_inv_loop

int_a_ascii_nulo:
    strb wzr, [x20, x4]
    add sp, sp, #32

int_a_ascii_fin:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret


// ascii_a_int: convierte texto en x0 a numero entero
ascii_a_int:
    mov x1, #0
    mov x3, #1            // signo: 1 = positivo, -1 = negativo

    ldrb w2, [x0]
    cmp w2, '-'
    bne ascii_a_int_loop
    mov x3, #-1
    add x0, x0, #1

ascii_a_int_loop:
    ldrb w2, [x0]
    cmp w2, '0'
    blt ascii_a_int_fin
    cmp w2, '9'
    bgt ascii_a_int_fin
    mov x3, #10
    mul x1, x1, x3
    sub w2, w2, '0'
    add x1, x1, x2
    add x0, x0, #1
    b ascii_a_int_loop

ascii_a_int_fin:
    cmp x3, #-1
    bne ascii_a_int_ret
    neg x1, x1

ascii_a_int_ret:
    mov x0, x1
    ret
