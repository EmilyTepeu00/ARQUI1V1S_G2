// decision.s

.data

//Umbrales
GAS_ALTO:       .quad 90
GAS_ADVERTENCIA: .quad 80
GAS_AMP_ALTA:   .quad 80
SOIL_BAJO:      .quad 700   
LUZ_BAJA:       .quad 1
TEMP_ALTA:      .quad 32

// --- Codigos de accion internos (se traducen a texto al imprimir) ---
.equ ACT_RIEGO_1_ON,  1
.equ ACT_RIEGO_2_ON,  2
.equ ACT_FAN_ON,      3
.equ ACT_LIGHT_ON,    4
.equ ACT_ALARM_ON,    5
.equ ACT_LED_GREEN,   6
.equ ACT_LED_YELLOW,  7
.equ ACT_LED_RED,     8
.equ ACT_NO_ACTION,   9

// --- Codigos de sensor/target internos (para decision_target) ---
.equ TGT_TEMP,   1
.equ TGT_HUM,    2
.equ TGT_SOIL1,  3
.equ TGT_SOIL2,  4
.equ TGT_LUZ,    5
.equ TGT_GAS,    6
.equ TGT_GENERAL,7   

// --- Codigos de riesgo internos (para decision_risk) ---
.equ RISK_LOW,      0
.equ RISK_MEDIUM,   1
.equ RISK_HIGH,     2
.equ RISK_CRITICAL, 3

// --- Codigos de razon internos (para REASON) ---
.equ REASON_GAS_ALTO,           1
.equ REASON_SOIL1_LOW_DESC,     2
.equ REASON_SOIL2_LOW_DESC,     3
.equ REASON_LUZ_LOW_DESC,       4
.equ REASON_TEMP_HIGH_ASC,      5
.equ REASON_ESTADO_NORMAL,      6
.equ REASON_SIN_ACCION,         7
.equ REASON_GAS_ADVERTENCIA,    8

// --- Textos de salida ---
str_action:    .ascii "ACTION="
str_target:    .ascii ";TARGET="
str_risk:      .ascii ";RISK="
str_reason:    .ascii ";REASON="
str_value:     .ascii ";VALUE="
str_indicator: .ascii ";INDICATOR="
str_status_ok: .ascii ";STATUS=OK\n"

str_status_error: .ascii "STATUS=ERROR\n"
str_error_eq:      .ascii "ERROR="
str_detail_eq:      .ascii "DETAIL="
newline:              .ascii "\n"
signo_negativo:        .ascii "-"

// Texto de ACTION
.align 3
tabla_accion:
    .quad txt_riego1     // ACT_RIEGO_1_ON  = 1
    .quad txt_riego2     // ACT_RIEGO_2_ON  = 2
    .quad txt_fan        // ACT_FAN_ON      = 3
    .quad txt_light      // ACT_LIGHT_ON    = 4
    .quad txt_alarm      // ACT_ALARM_ON    = 5
    .quad txt_green      // ACT_LED_GREEN   = 6
    .quad txt_yellow     // ACT_LED_YELLOW  = 7
    .quad txt_red        // ACT_LED_RED     = 8
    .quad txt_noaction   // ACT_NO_ACTION   = 9

txt_riego1:  .asciz "RIEGO_1_ON"
txt_riego2:  .asciz "RIEGO_2_ON"
txt_fan:     .asciz "FAN_ON"
txt_light:   .asciz "LIGHT_ON"
txt_alarm:   .asciz "ALARM_ON"
txt_green:   .asciz "LED_GREEN"
txt_yellow:  .asciz "LED_YELLOW"
txt_red:     .asciz "LED_RED"
txt_noaction:.asciz "NO_ACTION"

txt_low:      .asciz "LOW"
txt_medium:   .asciz "MEDIUM"
txt_high:     .asciz "HIGH"
txt_critical: .asciz "CRITICAL"

// Texto de RISK
.align 3
tabla_risk:
    .quad txt_low
    .quad txt_medium
    .quad txt_high
    .quad txt_critical

// Texto de TARGET
txt_tgt_temp:    .asciz "TEMP"
txt_tgt_hum:     .asciz "HUM_AIRE"
txt_tgt_soil1:   .asciz "SOIL1"
txt_tgt_soil2:   .asciz "SOIL2"
txt_tgt_luz:     .asciz "LUZ"
txt_tgt_gas:     .asciz "GAS"
txt_tgt_general: .asciz "GENERAL"

.align 3
tabla_target:
    .quad txt_tgt_temp     // TGT_TEMP    = 1
    .quad txt_tgt_hum      // TGT_HUM     = 2
    .quad txt_tgt_soil1    // TGT_SOIL1   = 3
    .quad txt_tgt_soil2    // TGT_SOIL2   = 4
    .quad txt_tgt_luz      // TGT_LUZ     = 5
    .quad txt_tgt_gas      // TGT_GAS     = 6
    .quad txt_tgt_general  // TGT_GENERAL = 7

// Texto de REASON
txt_reason_gas_alto:   .asciz "GAS_HIGH_OR_AMPLITUDE_HIGH"
txt_reason_soil1:        .asciz "SOIL1_LOW_AND_DESCENDING"
txt_reason_soil2:         .asciz "SOIL2_LOW_AND_DESCENDING"
txt_reason_luz:            .asciz "LUZ_LOW_AND_DESCENDING"
txt_reason_temp:            .asciz "TEMP_HIGH_AND_ASCENDING"
txt_reason_normal:           .asciz "ESTADO_NORMAL_OBSERVADO"
txt_reason_sin_accion:        .asciz "SIN_CONDICION_APLICABLE"
txt_reason_gas_advertencia:    .asciz "GAS_MODERADO_ADVERTENCIA"

.align 3
tabla_reason:
    .quad txt_reason_gas_alto    // REASON_GAS_ALTO       = 1
    .quad txt_reason_soil1        // REASON_SOIL1_LOW_DESC = 2
    .quad txt_reason_soil2         // REASON_SOIL2_LOW_DESC = 3
    .quad txt_reason_luz            // REASON_LUZ_LOW_DESC   = 4
    .quad txt_reason_temp            // REASON_TEMP_HIGH_ASC  = 5
    .quad txt_reason_normal           // REASON_ESTADO_NORMAL  = 6
    .quad txt_reason_sin_accion        // REASON_SIN_ACCION     = 7
    .quad txt_reason_gas_advertencia    // REASON_GAS_ADVERTENCIA = 8

.bss
// --- Resultados de indicadores ---
promedio_temp:    .skip 8
tendencia_temp:   .skip 8

promedio_hum:     .skip 8
amplitud_hum:     .skip 8

promedio_soil1:   .skip 8
tendencia_soil1:  .skip 8

promedio_soil2:   .skip 8
tendencia_soil2:  .skip 8

promedio_luz:     .skip 8
tendencia_luz:    .skip 8

promedio_gas:     .skip 8
amplitud_gas:     .skip 8

// --- Resultado de la decision ---
decision_action:    .skip 8
decision_target:    .skip 8
decision_value:     .skip 8
decision_indicator: .skip 8
decision_risk:       .skip 8
decision_reason:     .skip 8

out_buffer: .skip 256

.text

.global calcular_indicadores
calcular_indicadores:
    mov x26, x30

    // --- TEMP: promedio + tendencia ---
    ldr x0, =temp_buffer
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_temp
    str x0, [x2]

    ldr x0, =temp_buffer
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x2, =tendencia_temp
    str x0, [x2]

    // --- HUM_AIRE: promedio + amplitud ---
    ldr x0, =hum_buffer
    ldr x1, =hum_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_hum
    str x0, [x2]

    ldr x0, =hum_buffer
    ldr x1, =hum_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x2, =amplitud_hum
    str x0, [x2]

    // --- SOIL1: promedio + tendencia ---
    ldr x0, =soil1_buffer
    ldr x1, =soil1_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_soil1
    str x0, [x2]

    ldr x0, =soil1_buffer
    ldr x1, =soil1_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x2, =tendencia_soil1
    str x0, [x2]

    // --- SOIL2: promedio + tendencia ---
    ldr x0, =soil2_buffer
    ldr x1, =soil2_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_soil2
    str x0, [x2]

    ldr x0, =soil2_buffer
    ldr x1, =soil2_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x2, =tendencia_soil2
    str x0, [x2]

    // --- LUZ: promedio + tendencia ---
    ldr x0, =luz_buffer
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_luz
    str x0, [x2]

    ldr x0, =luz_buffer
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x2, =tendencia_luz
    str x0, [x2]

    // --- GAS: promedio + amplitud ---
    ldr x0, =gas_buffer
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x2, =promedio_gas
    str x0, [x2]

    ldr x0, =gas_buffer
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x2, =amplitud_gas
    str x0, [x2]

    mov x30, x26
    ret

calcular_amplitud:
    cbz x1, amplitud_vacia

    lsl x4, xzr, #3            // x4 = 0 (offset del primer elemento)
    add x5, x0, x4
    ldr x6, [x5]                 // x6 = max (inicia con el primer valor)
    mov x7, x6                    // x7 = min (inicia igual)

    mov x3, #1                    // x3 = indice i, ya tomamos i=0 arriba

amplitud_loop:
    cmp x3, x1
    bge fin_amplitud

    lsl x4, x3, #3
    add x5, x0, x4
    ldr x8, [x5]                  // x8 = X_i

    cmp x8, x6
    ble amplitud_no_max
    mov x6, x8                      // Nuevo maximo
amplitud_no_max:
    cmp x8, x7
    bge amplitud_no_min
    mov x7, x8                      // Nuevo minimo
amplitud_no_min:

    add x3, x3, #1
    b amplitud_loop

fin_amplitud:
    sub x0, x6, x7
    ret

amplitud_vacia:
    mov x0, #0
    ret

.global decidir_accion
decidir_accion:
    mov x25, x30
    // --- Prioridad 1: GAS critico (alto o amplitud alta) - ALARM_ON ---
    ldr x0, =promedio_gas
    ldr x0, [x0]
    ldr x1, =GAS_ALTO
    ldr x1, [x1]
    cmp x0, x1
    bgt prioridad_1_cumple

    ldr x0, =amplitud_gas
    ldr x0, [x0]
    ldr x1, =GAS_AMP_ALTA
    ldr x1, [x1]
    cmp x0, x1
    bgt prioridad_1_cumple

    // --- Prioridad 1b: GAS en nivel de advertencia (moderado) - LED_YELLOW ---
    ldr x0, =promedio_gas
    ldr x0, [x0]
    ldr x1, =GAS_ADVERTENCIA
    ldr x1, [x1]
    cmp x0, x1
    bgt prioridad_1_advertencia
    b prioridad_2

prioridad_1_advertencia:
    ldr x0, =decision_action
    mov x1, #ACT_LED_YELLOW
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_GAS
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_MEDIUM
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_GAS_ADVERTENCIA
    str x1, [x0]
    ldr x0, =lectura_gas
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =promedio_gas
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_1_cumple:
    ldr x0, =decision_action
    mov x1, #ACT_ALARM_ON
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_GAS
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_CRITICAL
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_GAS_ALTO
    str x1, [x0]
    ldr x0, =lectura_gas
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =promedio_gas
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_2:
    // --- Prioridad 2: SOIL1 seco (no humedeciendose claramente) - RIEGO_1_ON ---
    ldr x0, =promedio_soil1
    ldr x0, [x0]
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    ble prioridad_3

    ldr x0, =decision_action
    mov x1, #ACT_RIEGO_1_ON
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_SOIL1
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_HIGH
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_SOIL1_LOW_DESC
    str x1, [x0]
    ldr x0, =lectura_soil1
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =tendencia_soil1
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_3:
    // --- Prioridad 3: SOIL2 seco (no humedeciendose claramente) - RIEGO_2_ON ---
    ldr x0, =promedio_soil2
    ldr x0, [x0]
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    ble prioridad_4

    ldr x0, =decision_action
    mov x1, #ACT_RIEGO_2_ON
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_SOIL2
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_HIGH
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_SOIL2_LOW_DESC
    str x1, [x0]
    ldr x0, =lectura_soil2
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =tendencia_soil2
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_4:
    // --- Prioridad 4: LUZ baja (mayoria de lecturas recientes en BAJO=0) - LIGHT_ON ---
    ldr x0, =promedio_luz
    ldr x0, [x0]
    ldr x1, =LUZ_BAJA
    ldr x1, [x1]
    cmp x0, x1
    bge prioridad_5

    ldr x0, =decision_action
    mov x1, #ACT_LIGHT_ON
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_LUZ
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_MEDIUM
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_LUZ_LOW_DESC
    str x1, [x0]
    ldr x0, =lectura_luz
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =tendencia_luz
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_5:
    // --- Prioridad 5: TEMP alta y tendencia ascendente - FAN_ON ---
    ldr x0, =promedio_temp
    ldr x0, [x0]
    ldr x1, =TEMP_ALTA
    ldr x1, [x1]
    cmp x0, x1
    ble prioridad_6

    ldr x0, =tendencia_temp
    ldr x0, [x0]
    cmp x0, #0
    ble prioridad_6

    ldr x0, =decision_action
    mov x1, #ACT_FAN_ON
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_TEMP
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_MEDIUM
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_TEMP_HIGH_ASC
    str x1, [x0]
    ldr x0, =lectura_temp
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =tendencia_temp
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_6:
    // --- Prioridad 6: estado general sin condicion critica - LED_GREEN ---
    ldr x0, =temp_count
    ldr x0, [x0]
    cbz x0, prioridad_7

    ldr x0, =decision_action
    mov x1, #ACT_LED_GREEN
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_GENERAL
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_LOW
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_ESTADO_NORMAL
    str x1, [x0]
    ldr x0, =lectura_temp
    ldr x0, [x0]
    ldr x1, =decision_value
    str x0, [x1]
    ldr x0, =promedio_temp
    ldr x0, [x0]
    ldr x1, =decision_indicator
    str x0, [x1]
    b decision_fin

prioridad_7:
    // --- Prioridad 7: ninguna condicion aplica - NO_ACTION ---
    ldr x0, =decision_action
    mov x1, #ACT_NO_ACTION
    str x1, [x0]
    ldr x0, =decision_target
    mov x1, #TGT_GENERAL
    str x1, [x0]
    ldr x0, =decision_risk
    mov x1, #RISK_LOW
    str x1, [x0]
    ldr x0, =decision_reason
    mov x1, #REASON_SIN_ACCION
    str x1, [x0]
    ldr x0, =decision_value
    mov x1, #0
    str x1, [x0]
    ldr x0, =decision_indicator
    mov x1, #0
    str x1, [x0]
    b decision_fin

decision_fin:
    mov x30, x25
    ret

.global imprimir_respuesta
imprimir_respuesta:
    mov x26, x30

    // --- ACTION= ---
    ldr x0, =str_action
    mov x1, #7
    bl escribir_literal

    ldr x0, =decision_action
    ldr x0, [x0]
    ldr x1, =tabla_accion
    bl escribir_desde_tabla

    // --- ;TARGET= ---
    ldr x0, =str_target
    mov x1, #8
    bl escribir_literal

    ldr x0, =decision_target
    ldr x0, [x0]
    ldr x1, =tabla_target
    bl escribir_desde_tabla

    // --- ";RISK= ---
    ldr x0, =str_risk
    mov x1, #6
    bl escribir_literal

    ldr x0, =decision_risk
    ldr x0, [x0]
    add x0, x0, #1
    ldr x1, =tabla_risk
    bl escribir_desde_tabla

    // --- ;REASON= ---
    ldr x0, =str_reason
    mov x1, #8
    bl escribir_literal

    ldr x0, =decision_reason
    ldr x0, [x0]
    ldr x1, =tabla_reason
    bl escribir_desde_tabla

    // --- ;VALUE= + entero ---
    ldr x0, =str_value
    mov x1, #7
    bl escribir_literal

    ldr x0, =decision_value
    ldr x0, [x0]
    bl escribir_entero

    // --- ;INDICATOR= + entero ---
    ldr x0, =str_indicator
    mov x1, #11
    bl escribir_literal

    ldr x0, =decision_indicator
    ldr x0, [x0]
    bl escribir_entero

    // --- ;STATUS=OK\n ---
    ldr x0, =str_status_ok
    mov x1, #11
    bl escribir_literal

    mov x30, x26
    ret

escribir_literal:
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x8, #64
    svc #0
    ret


escribir_desde_tabla:
    mov x27, x30
    sub x0, x0, #1                
    lsl x0, x0, #3                   
    add x0, x1, x0                    
    ldr x0, [x0]                     

    mov x9, x0                          
    bl contar_longitud                 
    mov x2, x1
    mov x1, x9
    mov x0, #1
    mov x8, #64
    svc #0

    mov x30, x27
    ret

contar_longitud:
    mov x1, #0
contar_longitud_loop:
    ldrb w2, [x0, x1]
    cbz w2, contar_longitud_fin
    add x1, x1, #1
    b contar_longitud_loop
contar_longitud_fin:
    ret

escribir_entero:
    mov x28, x30               
    mov x29, x0                   

    cmp x29, #0
    bge escribir_entero_positivo

    ldr x1, =signo_negativo
    mov x2, #1
    mov x0, #1
    mov x8, #64
    svc #0

    neg x29, x29                  

escribir_entero_positivo:
    mov x0, x29
    ldr x1, =out_buffer
    bl int_a_ascii               

    ldr x0, =out_buffer
    bl contar_longitud            

    mov x2, x1
    ldr x1, =out_buffer
    mov x0, #1
    mov x8, #64
    svc #0

    mov x30, x28
    ret

.global imprimir_error_estructurado
imprimir_error_estructurado:
    mov x26, x30               
    mov x24, x0                
    mov x25, x1            

    // --- STATUS=ERROR\n ---
    ldr x0, =str_status_error
    mov x1, #13
    bl escribir_literal

    // --- ERROR= + texto ---
    ldr x0, =str_error_eq
    mov x1, #6
    bl escribir_literal

    mov x0, x24
    bl contar_longitud
    mov x2, x1
    mov x1, x24
    mov x0, #1
    mov x8, #64
    svc #0

    // --- \n ---
    ldr x0, =newline
    mov x1, #1
    bl escribir_literal

    // --- DETAIL= + texto ---
    ldr x0, =str_detail_eq
    mov x1, #7
    bl escribir_literal

    mov x0, x25
    bl contar_longitud
    mov x2, x1
    mov x1, x25
    mov x0, #1
    mov x8, #64
    svc #0

    // --- \n ---
    ldr x0, =newline
    mov x1, #1
    bl escribir_literal

    mov x30, x26                
    ret