// decision.s

.data

//Umbrales

GAS_ALTO:       .quad 70
GAS_AMP_ALTA:   .quad 25
SOIL_BAJO:      .quad 40
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

.align 3
tabla_reason:
    .quad txt_reason_gas_alto    // REASON_GAS_ALTO       = 1
    .quad txt_reason_soil1        // REASON_SOIL1_LOW_DESC = 2
    .quad txt_reason_soil2         // REASON_SOIL2_LOW_DESC = 3
    .quad txt_reason_luz            // REASON_LUZ_LOW_DESC   = 4
    .quad txt_reason_temp            // REASON_TEMP_HIGH_ASC  = 5
    .quad txt_reason_normal           // REASON_ESTADO_NORMAL  = 6
    .quad txt_reason_sin_accion        // REASON_SIN_ACCION     = 7