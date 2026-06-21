/* ====================================================================================
                        Modulo 4: Prediccion de Proximo Valor
   ====================================================================================
    modulo_4_prediccion.s
    Módulo 4: Predicción de Próximo Valor
    Proyecto: Invernadero Inteligente IoT - ACYE1
    Responsable: Diana Myriam Priscila Santizo Cáceres

    Entrada            : lecturas.csv
    Salida             : resultado_prediccion.txt

    Lee la columna que el usuario seleccione desde el dashboard.
    El numero de columna llega como argv[1] cuando Python ejecuta
    el binario. Si no viene argumento, usa columna 2 (TEMP).

     Modelo de Predicción:
    - Se calcula la diferencia entre cada par de valores consecutivos.
    - Se promedia esta diferencia para obtener una tendencia.
    - El próximo valor se predice sumando esta tendencia al último valor.

    Cálculos Realizados: 
    1. Valor inicial (datos[0])
    2. Valor final   (datos[29])
    3. Diferencia total = Final - Inicial
    4. Promedio de cambio = Diferencia / 29
    5. Predicción = Final + Promedio_cambio

   ====================================================================================
*/

.extern read_column_to_stack
.extern int_a_ascii
.extern ascii_a_int

.equ SYS_OPENAT,  56
.equ SYS_CLOSE,   57
.equ SYS_WRITE,   64
.equ SYS_EXIT,    93
.equ AT_FDCWD,   -100
.equ O_WRONLY,    1
.equ O_CREAT,     64
.equ O_TRUNC,     512
.equ PERM_644,    0644

.section .data

nombre_csv:     .asciz "lecturas.csv"
nombre_salida:  .asciz "resultado_prediccion.txt"

// Textos fijos en formato .asciz
lbl_header: .asciz "MODULE=PREDICTION\nINITIAL_VALUE="
lbl_final:  .asciz "\nFINAL_VALUE="
lbl_diff:   .asciz "\nTOTAL_DIFF="
lbl_avg:    .asciz "\nAVG_CHANGE="
lbl_next:   .asciz "\nNEXT_VALUE="
lbl_nl:     .asciz "\n"

.section .bss
buffer_salida:  .skip 512    // Buffer donde se armara el archivo completo
buf_conv:       .skip 32     // Buffer temporal para conversiones numéricas

.section .text
.global _start

_start:
    // --------------------------------------------------------
    // LECTURA DE argv[1]: el numero de columna que manda Python
    // --------------------------------------------------------
    ldr x0, [sp]            // x0 = argc
    cmp x0, #2              // hay al menos 1 argumento?
    blt .usar_default_4     // no -> default

    ldr x0, [sp, #16]       // x0 = puntero a argv[1]
    bl  ascii_a_int         // convierte string a entero en x0
    b   .configurar_utils

.usar_default_4:
    mov x0, #2              // default: columna 2 = TEMP

.configurar_utils:

/* --------------------------------------------------------
        Prepara parámetros para read_column_to_stack
    x11 = columna seleccionada
    x12 = linea inicial
    x13 = linea final
    x17 = puntero al nombre del archivo
    -------------------------------------------------------- 
*/

    mov x11, x0             // x11 <- columna de argv o default
    mov x12, #1             // Iniciar desde la fila 1 de datos
    mov x13, #30            // Leer hasta la fila 30
    adr x17, nombre_csv     // Apuntar al nombre del archivo
    
    bl  read_column_to_stack

/* --------------------------------------------------------
    Extraer datos del stack:
    El nuevo utils empuja usando sub sp, sp, #16. 
    Al finalizar:
      x0 = puntero a la última fila insertada (valor final).
      x1 = límite superior (justo arriba de la primera fila).
    Extraemos inmediateamente para que el stack no se corrompa.
    --------------------------------------------------------
*/
    ldr x22, [x0]           // x22 = valor final (datos[29])
    
    sub x9, x1, #16         // Calcular dirección de la primera inserción
    ldr x19, [x9]           // x19 = valor inicial (datos[0])

    // --------------------------------------------------------
    // CÁLCULOS de predicción lineal simple
    // --------------------------------------------------------
    sub x23, x22, x19       // diferencia total = final - inicial
    mov x4,  #29            // 29 intervalos entre 30 datos
    sdiv x24, x23, x4       // promedio de cambio = diferencia / 29
    add  x25, x22, x24      // predicción = final + promedio

    // --------------------------------------------------------
    // ARMAR EL TEXTO en buffer_salida
    // x20 es el puntero de escritura que avanza con cada caracter
    // --------------------------------------------------------
    adr x20, buffer_salida

    // --- Escribir Encabezado y Valor Inicial ---
    adr x0, lbl_header
    bl  copiar_a_buffer
    mov x0, x19
    adr x1, buf_conv
    bl  formatear_numero
    adr x0, buf_conv
    bl  copiar_a_buffer

    // --- Escribir Valor Final ---
    adr x0, lbl_final
    bl  copiar_a_buffer
    mov x0, x22
    adr x1, buf_conv
    bl  formatear_numero
    adr x0, buf_conv
    bl  copiar_a_buffer

    // --- Escribir Diferencia Total ---
    adr x0, lbl_diff
    bl  copiar_a_buffer
    mov x0, x23
    adr x1, buf_conv
    bl  formatear_numero
    adr x0, buf_conv
    bl  copiar_a_buffer

    // --- Escribir Promedio de Cambio ---
    adr x0, lbl_avg
    bl  copiar_a_buffer
    mov x0, x24
    adr x1, buf_conv
    bl  formatear_numero
    adr x0, buf_conv
    bl  copiar_a_buffer

    // --- Escribir Predicción (Siguiente Valor) ---
    adr x0, lbl_next
    bl  copiar_a_buffer
    mov x0, x25
    adr x1, buf_conv
    bl  formatear_numero
    adr x0, buf_conv
    bl  copiar_a_buffer

    // --- Escribir salto de línea final ---
    adr x0, lbl_nl
    bl  copiar_a_buffer

    // calcular cuántos bytes escribimos en el buffer
    adr x1, buffer_salida
    sub x26, x20, x1        // x26 = longitud total del texto

    // --------------------------------------------------------
    // ESCRIBIR AL ARCHIVO resultado_prediccion.txt
    // --------------------------------------------------------
    mov x8, #56
    mov x0, #-100
    adr x1, nombre_salida
    mov x2, #577
    mov x3, #0644
    svc #0
    mov x10, x0             // x10 = descriptor del archivo

    mov x8, #64
    mov x0, x10
    adr x1, buffer_salida
    mov x2, x26
    svc #0

    mov x8, #57
    mov x0, x10
    svc #0

    // MOSTRAR EN TERMINAL
    mov x8, #64
    mov x0, #1
    adr x1, buffer_salida
    mov x2, x26
    svc #0

    mov x8, #93
    mov x0, #0
    svc #0

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

conv_positivo:
    bl   int_a_ascii        // convierte x0 al texto en x1
    ldp  x29, x30, [sp], #16
    ret

/*  Ejecutar para pruebas:
    make modulo_4_prediccion
    qemu-aarch64 ./modulo_4_prediccion
    cat resultado_prediccion.txt
*/

