// motor.s
//
// Conecta con:
//   promedio  = calcular_promedio 
//   tendencia = calcular_tendencia 
//   decision = calcular_amplitud + decidir_accion + imprimir_respuesta

.data

err_invalid_input: .asciz "INVALID_INPUT"
err_detail_fields:  .asciz "EXPECTED_7_FIELDS"

.equ HIST_SIZE, 5
.equ CAMPOS_ESPERADOS, 7

.bss
in_buffer: .skip 128     // buffer crudo de la linea leida de stdin

// --- Valores ya convertidos de la lectura actual ---
lectura_temp:   .skip 8
lectura_hum:    .skip 8
lectura_soil1:  .skip 8
lectura_soil2:  .skip 8
lectura_luz:    .skip 8
lectura_gas:    .skip 8
lectura_modo:   .skip 8

// --- Arreglos circulares ---
temp_buffer:   .skip 40    // 5 * 8 bytes
hum_buffer:    .skip 40
soil1_buffer:  .skip 40
soil2_buffer:  .skip 40
luz_buffer:    .skip 40
gas_buffer:    .skip 40

// --- Posicion de escritura, una por sensor ---
temp_pos:      .skip 8
hum_pos:       .skip 8
soil1_pos:     .skip 8
soil2_pos:     .skip 8
luz_pos:       .skip 8
gas_pos:       .skip 8

// --- Cantidad de datos validos almacenados ---
temp_count:    .skip 8
hum_count:     .skip 8
soil1_count:   .skip 8
soil2_count:   .skip 8
luz_count:     .skip 8
gas_count:     .skip 8

.text
.global _start

.include "utils.s"
.include "promedio.s"
.include "tendencia.s"
.include "decision.s"


//   leer stdin = parsear = guardar en arreglos = calculos
//   decision = imprimir = 'de regreso al inicio'
_start:
main_loop:
    // read(0, in_buffer, 128)
    mov x0, #0
    ldr x1, =in_buffer
    mov x2, #128
    mov x8, #63             // read
    svc #0

    cmp x0, #0
    beq fin_programa         // Python cierra el stdin
    blt fin_programa_error

    mov x6, x0                // x6 = cantidad de bytes leidos
    ldr x1, =in_buffer
    add x1, x1, x6
    mov w2, '$'
    strb w2, [x1]

    ldr x21, =in_buffer       // x21 es el puntero que consume atoi_csv

    bl parse_lectura          
    cbz x0, reportar_error_entrada

    bl insertar_historial
    bl calcular_indicadores       
    bl decidir_accion              // se encuentra en decisión
    bl imprimir_respuesta         

    b main_loop

reportar_error_entrada:
    ldr x0, =err_invalid_input
    ldr x1, =err_detail_fields
    bl imprimir_error_estructurado   
    b main_loop                         // el motor SIGUE VIVO tras un error

fin_programa:
    mov x0, #0
    mov x8, #93
    svc #0

fin_programa_error:
    mov x0, #1
    mov x8, #93
    svc #0

// parse_lectura
.global parse_lectura
parse_lectura:
    mov x26, x30              // guardar direccion de retorno antes de cualquier bl
                              
    mov x5, #10               // base decimal
    mov x9, #0                // x9 = contador de campos leidos correctamente

    // --- Campo 1: TEMP ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_temp
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 2: HUM_AIRE ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_hum
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 3: SOIL1 ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_soil1
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 4: SOIL2 ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_soil2
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 5: LUZ ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_luz
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 6: GAS ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_gas
    str x10, [x0]
    add x9, x9, #1

    // --- Campo 7: MODO ---
    bl atoi_csv
    cbz x7, parse_error
    ldr x0, =lectura_modo
    str x10, [x0]
    add x9, x9, #1

    // Validar que el campo MODO haya cerrado con '\n' y no con ','
    cmp w23, #10
    bne parse_error

    cmp x9, #CAMPOS_ESPERADOS
    bne parse_error

    mov x0, #1
    mov x30, x26               // restaurar antes de retornar a quien llamo
    ret

parse_error:
    mov x0, #0
    mov x30, x26                
    ret
    

//   Entrada:  ninguna en registro; lee lectura_temp, el de gas, etc
//   Salida:   ninguna; actualiza los 6 buffers circulares
.global insertar_historial
insertar_historial:
    mov x26, x30               // guardar x30 antes del primer bl 

    // --- TEMP ---
    ldr x0, =lectura_temp
    ldr x0, [x0]
    ldr x1, =temp_pos
    ldr x2, =temp_count
    ldr x3, =temp_buffer
    bl guardar_dato_circular

    // --- HUM_AIRE ---
    ldr x0, =lectura_hum
    ldr x0, [x0]
    ldr x1, =hum_pos
    ldr x2, =hum_count
    ldr x3, =hum_buffer
    bl guardar_dato_circular

    // --- SOIL1 ---
    ldr x0, =lectura_soil1
    ldr x0, [x0]
    ldr x1, =soil1_pos
    ldr x2, =soil1_count
    ldr x3, =soil1_buffer
    bl guardar_dato_circular

    // --- SOIL2 ---
    ldr x0, =lectura_soil2
    ldr x0, [x0]
    ldr x1, =soil2_pos
    ldr x2, =soil2_count
    ldr x3, =soil2_buffer
    bl guardar_dato_circular

    // --- LUZ ---
    ldr x0, =lectura_luz
    ldr x0, [x0]
    ldr x1, =luz_pos
    ldr x2, =luz_count
    ldr x3, =luz_buffer
    bl guardar_dato_circular

    // --- GAS ---
    ldr x0, =lectura_gas
    ldr x0, [x0]
    ldr x1, =gas_pos
    ldr x2, =gas_count
    ldr x3, =gas_buffer
    bl guardar_dato_circular

    mov x30, x26                // restaurar antes de retornar
    ret


//   Entrada:
//     x0 = valor a guardar
//     x1 = puntero a la variable "posicion" de este sensor
//     x2 = puntero a la variable "cantidad" de este sensor
//     x3 = puntero al arreglo (buffer) de este sensor
//   Salida: ninguna; escribe en buffer[pos]
guardar_dato_circular:
    ldr x4, [x1]              // x4 = posicion actual

    mov x5, #8
    mul x6, x4, x5
    add x7, x3, x6
    str x0, [x7]               // guardar valor en buffer[pos]

    add x4, x4, #1
    cmp x4, #HIST_SIZE
    bne guardar_pos
    mov x4, #0

guardar_pos:
    str x4, [x1]               // actualizar posicion 

    ldr x8, [x2]                 // x8 = cantidad actual
    cmp x8, #HIST_SIZE
    bge fin_guardar_circular
    add x8, x8, #1
    str x8, [x2]                 // actualizar cantidad

fin_guardar_circular:
    ret
