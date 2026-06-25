/* ====================================================================================
                           Módulo 2: Regresión Lineal Simple
   ====================================================================================
    modulo_2_regresion.s
    Módulo 2: Regresión Lineal Simple
    Proyecto: Invernadero Inteligente IoT - ACYE1
    Responsable: Diana Myriam Priscila Santizo Cáceres

    Entrada            : lecturas.csv (pasado por parámetro)
    Salida             : resultado_prediccion.txt

    Funcionamiento:
    - Calcula la tendencia de la variable en una ventana usando regresión lineal.
    - Numerador = (N * suma(X_i * Y_i)) - (suma(X_i) * suma(Y_i))
    - Denominador = (N * suma(X_i * X_i)) - (suma(X_i) * suma(X_i))
    - M_X100 = (Numerador * 100) / Denominador

   ==================================================================================== 
   */

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.section .data
nombre_csv:     .asciz "lecturas.csv"
nombre_salida:  .asciz "resultado_regresion.txt"

// ============================================================
// FUNCIONES AUXILIARES INTERNAS
// ============================================================

// --- Función: copiar_a_buffer ---
copiar_a_buffer:
    ldrb w21, [x0], #1      // leer byte y avanzar x0
    cbz  w21, fin_copiar    // si es \0 terminamos
    strb w21, [x20], #1     // guardar byte y avanzar x20
    b    copiar_a_buffer
fin_copiar:
    ret

// --- Función: formatear_numero ---
formatear_numero:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    cmp  x0, #0
    bge  conv_positivo      // Si es mayor o igual a 0, saltar 

    // Si es negativo: colocar '-' en el buffer de conversión
    mov  w9, #45            // Código ASCII para '-'
    strb w9, [x1], #1       // Guardar el '-' y avanzar el puntero del buffer
    neg  x0, x0             // Volver el número positivo para int_a_ascii

// --- Función: conv_positivo ---
conv_positivo:
    bl   int_a_ascii        // convierte x0 al texto en x1
    ldp  x29, x30, [sp], #16
    ret
    
/*  Ejecutar para pruebas:
    make modulo_2_regresion
    qemu-aarch64 ./modulo_2_regresion lecturas.csv 1 25 3
    cat resultado_regresion.txt
*/
