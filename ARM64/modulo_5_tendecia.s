// ============================================================
// modulo_5_tendencia.s
// Rutina ARM64 - Tendencia Acumulada Avanzada
// Proyecto: Invernadero Inteligente IoT - ACYE1
// José Fernando Ramírez Ambrocio
//
// Lo que hace este modulo:
//   Analiza como cambia la humedad del suelo a lo largo del tiempo.
//   Lee 30 lecturas de HUM_SUELO_1 (columna 3) y HUM_SUELO_2 (columna 4)
//   y para cada columna calcula:
//     - cuantas veces subio el valor (incrementos)
//     - cuantas veces bajo el valor (decrementos)
//     - la racha mas larga de subidas consecutivas
//     - la racha mas larga de bajadas consecutivas
//     - la diferencia acumulada total
//     - la tendencia final: UP, DOWN o STABLE
//
// Formulas:
//   DIF_i    = X_i - X_(i-1)    diferencia entre dato actual y anterior
//   DIF_ACUM = S(DIF_i)         suma de todas las diferencias
//   DIF_ACUM > 0 => TREND=UP
//   DIF_ACUM < 0 => TREND=DOWN
//   DIF_ACUM = 0 => TREND=STABLE
//
// Entrada : lecturas.csv
// Salida  : resultado_tendencia.txt
// ============================================================

// numeros de syscall que uso para hablar con el sistema operativo
.equ SYS_OPENAT,  56    // para abrir archivos
.equ SYS_CLOSE,   57    // para cerrar archivos
.equ SYS_READ,    63    // para leer archivos
.equ SYS_WRITE,   64    // para escribir archivos
.equ SYS_EXIT,    93    // para terminar el programa
.equ AT_FDCWD,   -100   // le dice al sistema que busque en el directorio actual
.equ O_RDONLY,    0     // abrir solo para lectura
.equ O_WRONLY,    1     // abrir solo para escritura
.equ O_CREAT,     64    // crear el archivo si no existe
.equ O_TRUNC,     512   // borrar el contenido anterior si ya existe
.equ PERM_644,    0644  // permisos del archivo: yo puedo leer y escribir, otros solo leer

// numeros de columna en el CSV (empezando desde 0)
// ID=0, TEMP=1, HUM_AIRE=2, HUM_SUELO_1=3, HUM_SUELO_2=4
.equ COL_SUELO_1,  3
.equ COL_SUELO_2,  4
.equ N_DATOS,      30   // siempre trabajo con exactamente 30 datos

// ============================================================
// SECCION DE DATOS
// aqui guardo los textos que siempre van igual en el resultado
// los defino aqui porque nunca cambian
// ============================================================
.section .data

archivo_entrada:  .asciz "lecturas.csv"
archivo_salida:   .asciz "resultado_tendencia.txt"

// lineas fijas del encabezado
str_module:       .ascii "MODULE=ADVANCED_TREND\n"
.equ str_module_len, . - str_module

str_total:        .ascii "TOTAL_VALUES=30\n"
.equ str_total_len, . - str_total

// separador visual entre los dos bloques de resultados
str_sep:          .ascii "---\n"
.equ str_sep_len, . - str_sep

// etiquetas de cada seccion
str_area1:        .ascii "AREA=HUM_SUELO_1\n"
.equ str_area1_len, . - str_area1

str_area2:        .ascii "AREA=HUM_SUELO_2\n"
.equ str_area2_len, . - str_area2

// etiquetas antes de cada valor calculado
str_inc_lbl:      .ascii "INCREMENTS="
.equ str_inc_lbl_len, . - str_inc_lbl

str_dec_lbl:      .ascii "DECREMENTS="
.equ str_dec_lbl_len, . - str_dec_lbl

str_mup_lbl:      .ascii "MAX_UP_STREAK="
.equ str_mup_lbl_len, . - str_mup_lbl

str_mdn_lbl:      .ascii "MAX_DOWN_STREAK="
.equ str_mdn_lbl_len, . - str_mdn_lbl

str_acc_lbl:      .ascii "ACCUM_DIFF="
.equ str_acc_lbl_len, . - str_acc_lbl

// los tres posibles resultados de tendencia
str_trend_up:     .ascii "TREND=UP\n"
.equ str_trend_up_len, . - str_trend_up

str_trend_down:   .ascii "TREND=DOWN\n"
.equ str_trend_down_len, . - str_trend_down

str_trend_stable: .ascii "TREND=STABLE\n"
.equ str_trend_stable_len, . - str_trend_stable

str_newline:      .ascii "\n"
str_minus:        .ascii "-"   // para escribir el signo de negativos

// ============================================================
// SECCION BSS
// aqui reservo espacio en memoria para cosas que calculo
// durante la ejecucion, todo empieza en cero
// ============================================================
.section .bss

// aqui leo todo el CSV de una sola vez, 4096 bytes es suficiente
buf_csv:          .skip 4096

// buffer pequeño para convertir numeros a texto antes de escribirlos
buf_conv:         .skip 32

// guardo cuantos bytes leyo el sistema al leer el CSV
bytes_leidos:     .skip 8

// arreglos donde guardo los 30 valores ya convertidos de cada columna
// cada valor ocupa 8 bytes (64 bits), entonces 30 x 8 = 240 bytes
arr_suelo1:       .skip 240
arr_suelo2:       .skip 240

// aqui guardo los 5 resultados calculados para HUM_SUELO_1
s1_increments:    .skip 8
s1_decrements:    .skip 8
s1_max_up:        .skip 8
s1_max_down:      .skip 8
s1_accum_diff:    .skip 8

// aqui guardo los 5 resultados calculados para HUM_SUELO_2
s2_increments:    .skip 8
s2_decrements:    .skip 8
s2_max_up:        .skip 8
s2_max_down:      .skip 8
s2_accum_diff:    .skip 8

// variable para guardar el descriptor del archivo de salida
fd_out:           .skip 8

// ============================================================
// SECCION DE CODIGO
// ============================================================
.section .text
.global _start

// ============================================================
// _start - punto de entrada del programa
// aqui empieza todo cuando ejecuto el binario
// ============================================================
_start:
    // --- paso 1: abrir lecturas.csv ---
    // le pido al sistema operativo que abra el archivo
    // x8 = numero de syscall, x0 = directorio actual, x1 = nombre del archivo
    // x2 = modo solo lectura, svc 0 ejecuta la llamada
    // el sistema me devuelve en x0 el descriptor del archivo (un numero)
    // si es negativo significa que no pudo abrir el archivo
    mov  x8,  SYS_OPENAT
    mov  x0,  AT_FDCWD
    adr  x1,  archivo_entrada
    mov  x2,  O_RDONLY
    mov  x3,  0
    svc  0
    cmp  x0,  0
    blt  salir_error        // si fd < 0 el archivo no existe o no tengo permiso
    mov  x19, x0            // guardo el descriptor en x19 para usarlo despues

    // --- paso 2: leer todo el CSV de una sola vez ---
    // es mas eficiente hacer una sola lectura grande que 30 lecturas pequenas
    // el sistema pone el contenido en buf_csv y me dice cuantos bytes leyo
    mov  x8,  SYS_READ
    mov  x0,  x19           // el archivo que abri
    adr  x1,  buf_csv       // donde quiero que guarde el contenido
    mov  x2,  4096          // maximo de bytes a leer
    svc  0
    adr  x9,  bytes_leidos
    str  x0,  [x9]          // guardo cuantos bytes leyo para saber hasta donde procesar

    // --- paso 3: cerrar el CSV ---
    // ya no lo necesito abierto porque todo el contenido esta en buf_csv
    mov  x8,  SYS_CLOSE
    mov  x0,  x19
    svc  0

    // --- paso 4: extraer los 30 valores de HUM_SUELO_1 ---
    // le paso a mi funcion donde quiero que guarde los datos y que columna extraer
    adr  x0,  arr_suelo1    // destino: mi arreglo de suelo1
    mov  x1,  COL_SUELO_1   // columna 3
    bl   subr_parsear_columna

    // --- paso 5: extraer los 30 valores de HUM_SUELO_2 ---
    adr  x0,  arr_suelo2    // destino: mi arreglo de suelo2
    mov  x1,  COL_SUELO_2   // columna 4
    bl   subr_parsear_columna

    // --- paso 6: calcular tendencia de HUM_SUELO_1 ---
    // le paso el arreglo de datos y donde quiero que guarde los 5 resultados
    adr  x0,  arr_suelo1
    adr  x1,  s1_increments
    bl   subr_calcular_tendencia

    // --- paso 7: calcular tendencia de HUM_SUELO_2 ---
    adr  x0,  arr_suelo2
    adr  x1,  s2_increments
    bl   subr_calcular_tendencia

    // --- paso 8: escribir el archivo de salida ---
    bl   subr_escribir_resultado

    // --- paso 9: terminar el programa con exito ---
    mov  x8,  SYS_EXIT
    mov  x0,  0             // codigo 0 = todo salio bien
    svc  0

salir_error:
    mov  x8,  SYS_EXIT
    mov  x0,  1             // codigo 1 = hubo un error
    svc  0


// ============================================================
// SUBRUTINA: subr_parsear_columna
//
// Esta funcion recorre el texto del CSV byte por byte y extrae
// solo los valores de la columna que le indico.
//
// Como funciona:
//   - Primero salta la primera linea (la cabecera con nombres)
//   - Para cada fila va leyendo caracteres:
//     * si es un digito lo acumula (convierte texto a numero)
//     * si es coma sabe que termino esa columna
//     * si es \n sabe que termino la fila
//     * si es $ sabe que llego al fin del archivo
//
// Parametros que recibe:
//   x0 = donde quiero que guarde los 30 valores extraidos
//   x1 = numero de columna que quiero extraer
//
// Registros que uso internamente:
//   x19 = puntero al caracter actual del CSV que estoy leyendo
//   x20 = puntero al final del buffer, para saber cuando parar
//   x21 = indice de fila actual (va de 0 a 29)
//   x22 = numero de columna actual dentro de la fila
//   x23 = acumulador donde voy armando el numero de texto a entero
//   x24 = donde voy a guardar los valores (el arreglo destino)
//   x25 = la columna que me pidieron extraer
//   x26 = el byte que acabo de leer
// ============================================================
subr_parsear_columna:
    // guardo en la pila los registros que voy a usar
    // para no perder los valores que tenia quien me llamo
    stp  x29, x30, [sp, #-80]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]
    stp  x23, x24, [sp, #48]
    stp  x25, x26, [sp, #64]

    mov  x24, x0            // guardo el arreglo destino
    mov  x25, x1            // guardo el numero de columna objetivo

    // calculo donde empieza y donde termina el contenido del CSV
    adr  x19, buf_csv
    adr  x9,  bytes_leidos
    ldr  x9,  [x9]
    add  x20, x19, x9       // fin = inicio + bytes leidos

    mov  x21, 0             // empiezo desde la fila 0

    // saltar la primera linea (cabecera con nombres de columnas)
    // leo byte por byte hasta encontrar el salto de linea
spc_skip_header:
    cmp  x19, x20
    bge  spc_fin
    ldrb w26, [x19], #1     // leo un byte y avanzo x19 al siguiente
    cmp  w26, '\n'
    bne  spc_skip_header    // si no es \n sigo leyendo

    // procesamiento de cada fila de datos
spc_fila:
    cmp  x21, N_DATOS       // ya procese las 30 filas?
    bge  spc_fin
    cmp  x19, x20           // llegue al fin del buffer?
    bge  spc_fin

    // verifico si el primer caracter es el marcador de fin '$'
    ldrb w26, [x19]
    cmp  w26, '$'
    beq  spc_fin

    mov  x22, 0             // empiezo desde la columna 0 de esta fila
    mov  x23, 0             // reseteo el acumulador del numero

    // proceso caracter por caracter dentro de la fila
spc_columna:
    cmp  x19, x20
    bge  spc_fin

    ldrb w26, [x19], #1     // leo un byte y avanzo

    // ignoro el \r porque algunos archivos vienen con formato Windows
    cmp  w26, '\r'
    beq  spc_columna

    // si es \n termino esta fila
    cmp  w26, '\n'
    beq  spc_fin_linea

    // si es coma termino esta columna y paso a la siguiente
    cmp  w26, ','
    beq  spc_separador

    // si es un digito lo acumulo para armar el numero
    // por ejemplo para "45": primero acumulo 4, luego 4*10+5=45
    cmp  w26, '0'
    blt  spc_columna        // si es menor que '0' no es digito, lo ignoro
    cmp  w26, '9'
    bgt  spc_columna        // si es mayor que '9' no es digito, lo ignoro

    mov  x9,  10
    mul  x23, x23, x9       // acumulador = acumulador * 10
    sub  w26, w26, '0'      // convierto el caracter ASCII a numero (ej: '5' -> 5)
    add  x23, x23, x26      // acumulador = acumulador + digito
    b    spc_columna

spc_separador:
    // llego aqui cuando encuentro una coma
    cmp  x22, x25           // es esta la columna que me pidieron?
    beq  spc_guardar        // si es, guardo el valor
    add  x22, x22, 1        // si no, paso a la siguiente columna
    mov  x23, 0             // reseteo el acumulador para el siguiente campo
    b    spc_columna

spc_fin_linea:
    // llego aqui cuando encuentro \n (fin de fila)
    // puede que la columna buscada sea la ultima de la fila
    cmp  x22, x25
    beq  spc_guardar_avanzar
    add  x21, x21, 1        // cuento esta fila aunque no encontre el dato
    b    spc_fila

spc_guardar:
    // guardo el valor en el arreglo destino
    // uso lsl #3 porque cada elemento ocupa 8 bytes, entonces
    // para ir al elemento x21 tengo que saltar x21*8 bytes
    str  x23, [x24, x21, lsl #3]
    add  x21, x21, 1
    // salto el resto de la fila hasta el siguiente \n
spc_skip_resto:
    cmp  x19, x20
    bge  spc_fin
    ldrb w26, [x19], #1
    cmp  w26, '\n'
    bne  spc_skip_resto
    b    spc_fila

spc_guardar_avanzar:
    // igual que spc_guardar pero cuando la columna es la ultima de la fila
    str  x23, [x24, x21, lsl #3]
    add  x21, x21, 1
    b    spc_fila

spc_fin:
    // restauro los registros que guarde al inicio
    ldp  x25, x26, [sp, #64]
    ldp  x23, x24, [sp, #48]
    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #80
    ret


// ============================================================
// SUBRUTINA: subr_calcular_tendencia
//
// Recorre los 30 datos comparando cada uno con el anterior
// y calcula los 5 valores de tendencia.
//
// Para cada par de datos consecutivos calculo:
//   DIF_i = datos[i] - datos[i-1]
//   si DIF_i > 0: es un incremento, sumo a la racha de subida
//   si DIF_i < 0: es un decremento, sumo a la racha de bajada
//   si DIF_i = 0: reseteo ambas rachas
//
// El indice i empieza en 1 (no en 0) porque necesito comparar
// cada dato con el anterior, y datos[0] no tiene anterior.
//
// Parametros:
//   x0 = arreglo de 30 datos a analizar
//   x1 = bloque donde guardo los 5 resultados
//
// Registros que uso:
//   x19 = arreglo de datos
//   x20 = bloque de resultados
//   x21 = indice i (empieza en 1)
//   x22 = contador de incrementos
//   x23 = contador de decrementos
//   x24 = racha de subida actual (se resetea cuando hay bajada)
//   x25 = racha de bajada actual (se resetea cuando hay subida)
//   x26 = racha maxima de subida (solo sube, nunca baja)
//   x27 = racha maxima de bajada (solo sube, nunca baja)
//   x28 = diferencia acumulada total (puede ser negativa)
// ============================================================
subr_calcular_tendencia:
    stp  x29, x30, [sp, #-96]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]
    stp  x23, x24, [sp, #48]
    stp  x25, x26, [sp, #64]
    stp  x27, x28, [sp, #80]

    mov  x19, x0            // guardo el arreglo de datos
    mov  x20, x1            // guardo donde voy a poner los resultados

    // inicializo todos los contadores en 0
    mov  x21, 1             // empieza en 1 para poder ver datos[i-1]
    mov  x22, 0             // incrementos
    mov  x23, 0             // decrementos
    mov  x24, 0             // racha_up actual
    mov  x25, 0             // racha_down actual
    mov  x26, 0             // max_up
    mov  x27, 0             // max_down
    mov  x28, 0             // accum_diff

sct_loop:
    cmp  x21, N_DATOS       // ya procese los 30 datos?
    bge  sct_fin

    // cargo datos[i-1] y datos[i]
    // el lsl #3 multiplica por 8 porque cada dato ocupa 8 bytes
    sub  x9,  x21, 1
    ldr  x10, [x19, x9,  lsl #3]   // datos[i-1]
    ldr  x9,  [x19, x21, lsl #3]   // datos[i]

    // calculo la diferencia entre el dato actual y el anterior
    sub  x11, x9, x10              // DIF_i = datos[i] - datos[i-1]
    add  x28, x28, x11             // sumo al acumulador total

    cmp  x11, 0
    bgt  sct_incremento     // si la diferencia es positiva: subio
    blt  sct_decremento     // si la diferencia es negativa: bajo

    // si la diferencia es 0: el valor no cambio, reseteo ambas rachas
    mov  x24, 0
    mov  x25, 0
    b    sct_siguiente

sct_incremento:
    add  x22, x22, 1        // cuento este incremento
    add  x24, x24, 1        // aumento la racha de subida actual
    mov  x25, 0             // reseteo la racha de bajada porque hubo subida
    // verifico si esta racha supera el record anterior
    cmp  x24, x26
    ble  sct_siguiente      // si no supera, sigo
    mov  x26, x24           // si supera, actualizo el record de racha maxima
    b    sct_siguiente

sct_decremento:
    add  x23, x23, 1        // cuento este decremento
    add  x25, x25, 1        // aumento la racha de bajada actual
    mov  x24, 0             // reseteo la racha de subida porque hubo bajada
    cmp  x25, x27
    ble  sct_siguiente
    mov  x27, x25           // actualizo el record de racha maxima de bajada

sct_siguiente:
    add  x21, x21, 1        // paso al siguiente dato
    b    sct_loop

sct_fin:
    // guardo los 5 resultados en el bloque de memoria que me pasaron
    // cada uno ocupa 8 bytes, por eso los offsets son 0, 8, 16, 24, 32
    str  x22, [x20, #0]     // increments
    str  x23, [x20, #8]     // decrements
    str  x26, [x20, #16]    // max_up
    str  x27, [x20, #24]    // max_down
    str  x28, [x20, #32]    // accum_diff

    ldp  x27, x28, [sp, #80]
    ldp  x25, x26, [sp, #64]
    ldp  x23, x24, [sp, #48]
    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #96
    ret


// ============================================================
// SUBRUTINA: subr_escribir_resultado
//
// Crea resultado_tendencia.txt y escribe los resultados
// de ambas columnas. Primero el encabezado, luego el bloque
// de HUM_SUELO_1, un separador, y el bloque de HUM_SUELO_2.
// ============================================================
subr_escribir_resultado:
    stp  x29, x30, [sp, #-32]!
    stp  x19, x20, [sp, #16]
    mov  x29, sp

    // abro o creo el archivo de salida
    // O_WRONLY|O_CREAT|O_TRUNC = escribir, crear si no existe, borrar contenido anterior
    mov  x8,  SYS_OPENAT
    mov  x0,  AT_FDCWD
    adr  x1,  archivo_salida
    mov  x2,  O_WRONLY | O_CREAT | O_TRUNC
    mov  x3,  PERM_644
    svc  0
    cmp  x0,  0
    blt  ser_fin            // si fallo la apertura no escribo nada
    mov  x19, x0            // guardo el descriptor del archivo de salida

    // escribo el encabezado
    adr  x0,  str_module
    mov  x1,  str_module_len
    bl   ser_write

    adr  x0,  str_total
    mov  x1,  str_total_len
    bl   ser_write

    // escribo el bloque de resultados de HUM_SUELO_1
    adr  x0,  str_area1
    mov  x1,  str_area1_len
    bl   ser_write
    adr  x20, s1_increments // apunto al primer resultado de suelo1
    bl   ser_escribir_bloque

    // escribo el separador entre las dos secciones
    adr  x0,  str_sep
    mov  x1,  str_sep_len
    bl   ser_write

    // escribo el bloque de resultados de HUM_SUELO_2
    adr  x0,  str_area2
    mov  x1,  str_area2_len
    bl   ser_write
    adr  x20, s2_increments // apunto al primer resultado de suelo2
    bl   ser_escribir_bloque

    // cierro el archivo cuando termino de escribir
    mov  x8,  SYS_CLOSE
    mov  x0,  x19
    svc  0

ser_fin:
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret


// ============================================================
// SUBRUTINA: ser_escribir_bloque
//
// Escribe los 6 campos de una seccion de resultados:
// INCREMENTS, DECREMENTS, MAX_UP_STREAK, MAX_DOWN_STREAK,
// ACCUM_DIFF y TREND.
//
// x19 = descriptor del archivo ya abierto
// x20 = puntero al bloque de 5 resultados en memoria
//        los 5 valores estan guardados consecutivamente cada 8 bytes:
//        [x20+0]  = increments
//        [x20+8]  = decrements
//        [x20+16] = max_up
//        [x20+24] = max_down
//        [x20+32] = accum_diff
// ============================================================
ser_escribir_bloque:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    // escribo INCREMENTS=valor
    adr  x0,  str_inc_lbl
    mov  x1,  str_inc_lbl_len
    bl   ser_write
    ldr  x0,  [x20, #0]    // cargo el valor de incrementos
    bl   ser_escribir_uint_nl

    // escribo DECREMENTS=valor
    adr  x0,  str_dec_lbl
    mov  x1,  str_dec_lbl_len
    bl   ser_write
    ldr  x0,  [x20, #8]
    bl   ser_escribir_uint_nl

    // escribo MAX_UP_STREAK=valor
    adr  x0,  str_mup_lbl
    mov  x1,  str_mup_lbl_len
    bl   ser_write
    ldr  x0,  [x20, #16]
    bl   ser_escribir_uint_nl

    // escribo MAX_DOWN_STREAK=valor
    adr  x0,  str_mdn_lbl
    mov  x1,  str_mdn_lbl_len
    bl   ser_write
    ldr  x0,  [x20, #24]
    bl   ser_escribir_uint_nl

    // escribo ACCUM_DIFF=valor
    // este puede ser negativo, por eso uso ser_escribir_int_nl
    adr  x0,  str_acc_lbl
    mov  x1,  str_acc_lbl_len
    bl   ser_write
    ldr  x0,  [x20, #32]
    bl   ser_escribir_int_nl

    // determino y escribo la tendencia segun el signo de accum_diff
    ldr  x0,  [x20, #32]
    cmp  x0,  0
    bgt  seb_up             // si accum_diff > 0: tendencia hacia arriba
    blt  seb_down           // si accum_diff < 0: tendencia hacia abajo
    // si accum_diff = 0: estable
    adr  x0,  str_trend_stable
    mov  x1,  str_trend_stable_len
    bl   ser_write
    b    seb_fin
seb_up:
    adr  x0,  str_trend_up
    mov  x1,  str_trend_up_len
    bl   ser_write
    b    seb_fin
seb_down:
    adr  x0,  str_trend_down
    mov  x1,  str_trend_down_len
    bl   ser_write
seb_fin:
    ldp  x29, x30, [sp], #16
    ret


// ============================================================
// ser_write
// Funcion generica para escribir al archivo.
// Recibe en x0 el texto a escribir y en x1 cuantos bytes son.
// Usa x19 como descriptor del archivo (ya abierto antes de llamarla).
// ============================================================
ser_write:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    mov  x8,  SYS_WRITE
    mov  x2,  x1            // cuantos bytes escribir
    mov  x1,  x0            // donde esta el texto
    mov  x0,  x19           // a que archivo escribir
    svc  0
    ldp  x29, x30, [sp], #16
    ret


// ============================================================
// ser_escribir_uint_nl
// Convierte el numero en x0 a texto y lo escribe en el archivo
// seguido de un salto de linea.
//
// ARM64 no puede escribir numeros directamente, necesita
// convertirlos a texto primero. Los digitos se extraen de
// derecha a izquierda dividiendo entre 10 repetidamente
// y tomando el residuo. Por eso los construyo al reves
// en buf_conv y luego escribo desde donde termino.
// ============================================================
ser_escribir_uint_nl:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    adr  x9,  buf_conv
    add  x10, x9, #28       // x10 apunta al final del buffer, construyo de derecha a izquierda
    mov  w11, '\n'
    strb w11, [x10]         // pongo \n en la ultima posicion

    // caso especial: si el numero es 0 simplemente escribo "0"
    cbnz x0,  seun_loop
    mov  w11, '0'
    sub  x10, x10, #1
    strb w11, [x10]
    b    seun_write

seun_loop:
    // extraigo un digito por vuelta dividiendo entre 10
    cbz  x0,  seun_write    // cuando el numero llega a 0 termine
    mov  x12, 10
    udiv x13, x0, x12       // x13 = x0 / 10
    msub x13, x13, x12, x0  // x13 = x0 % 10 (el residuo es el digito)
    add  w13, w13, '0'      // convierto el digito a su caracter ASCII
    sub  x10, x10, #1       // muevo el cursor a la izquierda
    strb w13, [x10]         // guardo el digito
    udiv x0,  x0, x12       // elimino el ultimo digito del numero
    b    seun_loop

seun_write:
    // calculo cuantos bytes tengo que escribir
    // desde donde quedo x10 hasta la posicion 28 (donde esta el \n) + 1
    adr  x9,  buf_conv
    add  x9,  x9, #28
    sub  x1,  x9, x10
    add  x1,  x1, #1        // +1 para incluir el \n
    mov  x0,  x10           // x0 apunta al inicio del numero en el buffer
    bl   ser_write

    ldp  x29, x30, [sp], #16
    ret


// ============================================================
// ser_escribir_int_nl
// Igual que ser_escribir_uint_nl pero maneja numeros negativos.
// Si el numero es negativo escribe el signo '-' primero
// y luego el valor absoluto.
// ============================================================
ser_escribir_int_nl:
    stp  x29, x30, [sp, #-32]!
    stp  x19, x20, [sp, #16]
    mov  x29, sp

    cmp  x0,  0
    bge  sein_positivo      // si es positivo o cero, lo proceso normal

    // si es negativo: primero escribo el signo menos
    mov  x20, x0
    neg  x20, x20           // calculo el valor absoluto negando el numero
    mov  x8,  SYS_WRITE
    mov  x0,  x19
    adr  x1,  str_minus     // escribo el caracter '-'
    mov  x2,  1
    svc  0
    mov  x0,  x20           // paso el valor absoluto para convertir y escribir

sein_positivo:
    bl   ser_escribir_uint_nl   // llamo a la funcion normal con el valor ya positivo

    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ---- Fin modulo_5_tendencia.s -----------------------------