// Alison Melysa Pérez Blanco - Media Aritmetica Ponderada

// La formula que uso es:
// MEDIA_PONDERADA = S(Xi * Wi) / SWi   donde Wi va de 1 a N

// Para leer el CSV uso read_column_to_stack de utils.s. Ahora recibe
// columna (x11), linea inicial (x12) y linea final (x13), y deja los
// datos guardados en el stack con cantidad variable N.
// Para convertir los argumentos de texto (columna, linea inicial, linea
// final) a numero uso ascii_a_int de utils.s.
// Para convertir numeros a texto uso int_a_ascii de utils.s.
// La cantidad real de datos leidos viene en x2 al regresar de
// read_column_to_stack.

// DECLARACION DE SIMBOLOS EXTERNOS
// Estas funciones estan definidas en utils.s
// Se declaran con .extern para que el linker las pueda encontrar
// al momento de ensamblar y enlazar el proyecto completo

// ------------------------------------------------------------
.extern read_column_to_stack   // Lee la columna del CSV en el rango [linea_inicial, linea_final] y guarda los datos en el stack
.extern int_a_ascii            // Convierte un entero a string ASCII (para escribir resultados)
.extern ascii_a_int            // Convierte texto a entero
// ------------------------------------------------------------
// SECCION .data
// Aqui van todas las cadenas y constantes que tienen valor
// Desde el inicio del programa (datos inicializados)
// ------------------------------------------------------------

.section .data

//-------------------------------------------------------------
// .asciz guarda un texto en memoria y automáticamente le agrega un cero al final 
// (ese cero se llama null terminator y le dice al programa "aquí termina el texto")
//-------------------------------------------------------------

// Nombre del archivo de salida donde se guardan los resultados
nombre_salida:
    .asciz "resultado_media.txt"

linea_module:
    .asciz "MODULE=WEIGHTED_MEAN\n" // Guarda el texto con salto de linea
linea_module_len = . - linea_module // El punto . significa "la posición actual en memoria"
// Calcula cuantos bytes ocupa el texto (posicion actual menos posicion inicial)
// Se necesita para decirle al sistema operativo cuantos caracteres escribir

label_total:     .asciz "TOTAL_VALUES="
label_total_len = . - label_total

label_sumx:     .asciz "SUM_X="
label_sumx_len = . - label_sumx

label_wsum:     .asciz "WEIGHT_SUM="
label_wsum_len = . - label_wsum

label_mean:     .asciz "WEIGHTED_MEAN="
label_mean_len = . - label_mean

label_column:    .asciz "COLUMN="
label_column_len = . - label_column

label_wstart:    .asciz "WINDOW_START="
label_wstart_len = . - label_wstart

label_wend:      .asciz "WINDOW_END="
label_wend_len = . - label_wend

label_status:    .asciz "STATUS=OK\n"
label_status_len = . - label_status

.section .bss               // Reservar espacio vacio en memoria 

buffer_salida:  .skip 512   // Reserva ese espacio vacio para el archivo de salida (bytes)
buf_total:  .skip 32
buf_sumx:   .skip 32
buf_wsum:   .skip 32
buf_media:  .skip 32
buf_column:  .skip 32
buf_wstart:  .skip 32
buf_wend:    .skip 32
// Espacio temporal donde se convierte cada numero a texto 

.section .text             // Inicio codigo ejecutable 
.global _start             // El programa arranca aqui

_start:                   // Es lo primero que se ejecuta

    // --------------------------------------------------------
    // Archivo_entrada linea_inicial linea_final columna_sensor
    // --------------------------------------------------------

    ldr x9, [sp, #16]        // Archivo entrada

    ldr x0, [sp, #24]        // Linea inicial
    bl  ascii_a_int
    mov x12, x0              // Guarda linea inicial

    ldr x0, [sp, #32]        // Linea final
    bl  ascii_a_int
    mov x13, x0              // Guarda linea final

    ldr x0, [sp, #40]        // Columna sensor
    bl  ascii_a_int
    mov x11, x0              // Columna seleccionada

    bl read_column_to_stack

    // Al regresar de read_column_to_stack:
    // x0 = direccion del ULTIMO dato leido (el mas reciente, quedo arriba en el stack)
    // x1 = limite superior, una posicion arriba de donde quedo el primer dato leido
    // x2 = cantidad real de datos leidos (N), ya no se asume 30 fijo
    // x3 = posicion original del stack, para restaurarlo cuando ya no se usen los datos
    mov x28, x3          // guardo en x28 donde restaurar el stack al terminar
    sub x19, x1, #16     // x19 = direccion del primer dato leido (cada dato ocupa 16 bytes en el stack)


    // Si no hay datos en el rango pedido, salir antes de dividir entre 0 mas adelante
    cmp x2, #1
    blt error_datos_insuficientes

    // --------------------------------------------------------
    // Calculo de media ponderada con pesos Wi = 1, 2, 3 ... 30
    // x19 = puntero al dato actual dentro del stack
    // x20 = SUM_X  (suma simple de todos los datos) (no sirve en la formula)
    // x21 = indice i, va de 0 a 29, indica en que dato voy
    // x22 = suma_ponderada S(Xi * Wi)
    // x23 = suma_pesos S(Wi)
    // x24 = peso actual Wi, arranca en 1
    // x2  = N, cantidad real de datos leidos (viene de read_column_to_stack)
    // --------------------------------------------------------

    // Inicializan con el valor dado 

    mov x20, #0
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x24, #1

loop_media:
    cmp x21, x2                    // Compara el x21 contra la cantidad real de datos
    beq fin_media                  // Salta a esto si fueron iguales

    ldr x25, [x19]                 // x25 guarda el dato actual
    add x20, x20, x25              // Suma dato actual a sumx x20=x20+x25, es el resultado de SUM_X
    mul x26, x25, x24              // Xi * Wi
    add x22, x22, x26              // suma_ponderada S(Xi * Wi)
    add x23, x23, x24              // suma_pesos += Wi
    add x21, x21, #1               // i++
    add x24, x24, #1               // Wi++
    sub x19, x19, #16              
    // Avanza al siguiente dato; el bloque va de direccion alta (dato mas viejo) a baja (dato mas nuevo), por eso se resta y no se suma
    b loop_media                   // Le dice que se vaya aca y ejecute desde ahi 

fin_media:
    mov sp, x28 // Restauro el stack a su posicion original, ya no necesito los datos

    // MEDIA_PONDERADA = suma_ponderada / suma_pesos
    udiv x27, x22, x23       // x27 = WEIGHTED_MEAN

    // --------------------------------------------------------
    // Armar el texto en buffer_salida
    // x14 marca hasta donde hemos escrito en el buffer
    // --------------------------------------------------------

    mov x14, #0              // x14 registro que lleva la cuenta de cuántos bytes se han escrito en buffer_salida
    // Empieza en 0 porque esta vacio y siempre apunta al final de lo que se escribio

    mov x9, x2               // Se guarda N aqui

    mov x16, x11            // Guardamos columna 
    mov x17, x12            // Guardamos linea inicial
    mov x15, x13            // Guardamos linea final

    bl copiar_module        // texto fijo de module
    
    // TOTAL_VALUES=N 
    bl copiar_label_total
    mov x0, x9              // x9 = N
    adr x1, buf_total
    bl int_a_ascii
    adr x0, buf_total
    bl copiar_cadena
    bl copiar_newline

    // COLUMN=columna
    bl copiar_label_column
    mov x0, x16
    adr x1, buf_column
    bl int_a_ascii
    adr x0, buf_column
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_START=linea_inicial
    bl copiar_label_wstart
    mov x0, x17
    adr x1, buf_wstart
    bl int_a_ascii
    adr x0, buf_wstart
    bl copiar_cadena
    bl copiar_newline

    // WINDOW_END=linea_final
    bl copiar_label_wend
    mov x0, x15
    adr x1, buf_wend
    bl int_a_ascii
    adr x0, buf_wend
    bl copiar_cadena
    bl copiar_newline

    // SUM_X=valor
    bl copiar_label_sumx    // Copia el texto "SUM_X=" al buffer de salida.
    mov x0, x20             // Copia el valor de x20 en x0
    adr x1, buf_sumx        // adr para cargar direccion de memoria
    // Guarda en x1 la dirección de buf_sumx (aqui se convierte el numero)
    bl int_a_ascii          // convierte el numero en x0 a ascii y lo guarda en x1 (en buf_sumx)
    adr x0, buf_sumx        // Guarda en x0 la dirección de buf_sumx para pasársela a la siguiente función.
    bl copiar_cadena        // Copia el texto de buf_sumx al buffer principal
    bl copiar_newline       // Agrega un salto de línea al buffer.


    // ESTOS DE ABAJO HACEN LO MISMO QUE EL DE ARRIBA 

    // WEIGHT_SUM=valor
    bl copiar_label_wsum
    mov x0, x23
    adr x1, buf_wsum
    bl int_a_ascii
    adr x0, buf_wsum
    bl copiar_cadena
    bl copiar_newline

    // WEIGHTED_MEAN=valor
    bl copiar_label_mean
    mov x0, x27
    adr x1, buf_media
    bl int_a_ascii
    adr x0, buf_media
    bl copiar_cadena
    bl copiar_newline

    // STATUS=OK
     bl copiar_label_status

    // --------------------------------------------------------
    // Escribir el arcgivo de resultado_media.txt
    // --------------------------------------------------------
    mov x8, #56                // llamada al sistema para abrir un archivo (openat)
    mov x0, #-100              // AT_FDCWD busca el archivo en la carpeta donde estoy ahorita
    adr x1, nombre_salida      // Guarda en x1 la dirección del texto "resultado_media.txt"
    // Le dice al sistema operativo el nombre del archivo a abrir.
    mov x2, #577             // O_WRONLY|O_CREAT|O_TRUNC
    // Abrir solo para escribir, crear si no existe, si existe se borra y empieza de 0
    mov x3, #0644            // Permisos de linux 
    // el dueño puede leer y escribir los demás solo pueden leer
    svc #0                     // Ejecuta la llamada al sistema 
    mov x10, x0                // Guarda el descriptor en x10 para usarlo después 
    // (descriptor es el numero que identifica al archivo que se abrio)

    mov x8, #64                // syscall write, llama al sistema para escribir algo 
    mov x0, x10                // Le pasa el descriptor para que sepa en que archivo escribir
    adr x1, buffer_salida      // Le dice dónde está el texto que quiere escribir
    mov x2, x14                // Le dice cuántos bytes escribir
    svc #0

    mov x8, #57                // syscall close 
    mov x0, x10                // Le pasa el descriptor para saber qué archivo cerrar
    svc #0

    // MOSTRAR EN TERMINAL 
    mov x8, #64                // write pero para escribir en la terminal 
    mov x0, #1                 // El número 1 es el descriptor especial de la terminal
    adr x1, buffer_salida
    mov x2, x14                // Escribe en la terminal lo mismo que en el archivo de salida
    svc #0

    // FIN DEL PROGRAMA
    mov x8, #93 // Terminar el programa (exit)
    mov x0, #0  // El 0 significa que el programa terminó con éxito
    svc #0

error_datos_insuficientes: // se llega aqui si el rango pedido no trajo ningun dato (N=0)
    mov sp, x28            // restaurar el stack que habia reservado read_column_to_stack
    mov x8, #93            // syscall exit
    mov x0, #1             // codigo de salida 1 = error
    svc #0

// Funciones auxiliares para copiar texto al buffer

copiar_module:                // Copia MODULE=WEIGHTED_MEAN
    stp x29, x30, [sp, #-16]! // stp es guardar dos registros a la vez (la ultima parte baja 16 bytes para hacer espacio)
    // x29 guarda la dirección del stack anterior
    // x30 guarda la dirección de regreso, o sea a dónde volver cuando termine la función
    adr x0, buffer_salida     // Guarda dirección donde empieza buffer_salida
    adr x1, linea_module      // Guarda la dirección donde está el texto "MODULE=WEIGHTED_MEAN\n"
    
lp_mod:                       // Sirve para copiar el texto "MODULE=WEIGHTED_MEAN\n" al buffer de salida
    ldrb w2, [x1]             // Lee la letra que está en la dirección x1 y la guarda en w2
    cmp w2, #0                // Compara la letra leída con 0
    beq fin_mod               // Salta aqui si encuentra \0 (fin texto)
    strb w2, [x0, x14]        // Escribe la letra de w2 en la dirección x0 + x14
    add x14, x14, #1          // Le suma 1 para avanzar en el buffer
    add x1, x1, #1            // Avanzar a la siguiente letra
    b lp_mod
fin_mod:
    ldp x29, x30, [sp], #16   // ldp recupera registros, sube 16 bytes 
    ret                       // return Ve a la dirección que tiene x30 y continúa ejecutando desde ahí

copiar_label_total:           // copia el texto "TOTAL_VALUES=" al buffer de salida
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_total
lp_tot:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_tot
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_tot
fin_tot:
    ldp x29, x30, [sp], #16
    ret

copiar_label_sumx:             // Copia SUM_X=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_sumx
lp_lsx:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lsx
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_lsx
fin_lsx:
    ldp x29, x30, [sp], #16
    ret

copiar_label_wsum:             // WEIGHT_SUM=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wsum
lp_lws:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lws
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_lws
fin_lws:
    ldp x29, x30, [sp], #16
    ret

copiar_label_mean:            // Copia WEIGHTED_MEAN=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_mean
lp_lmn:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lmn
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_lmn
fin_lmn:
    ldp x29, x30, [sp], #16
    ret

// Copia COLUMN=
copiar_label_column:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_column
lp_col:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_col
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_col
fin_col:
    ldp x29, x30, [sp], #16
    ret

// Copia WINDOW_START=
copiar_label_wstart:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wstart
lp_wst:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_wst
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_wst
fin_wst:
    ldp x29, x30, [sp], #16
    ret

// Copia WINDOW_END=
copiar_label_wend:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wend
lp_wen:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_wen
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_wen
fin_wen:
    ldp x29, x30, [sp], #16
    ret

// Copia STATUS=OK 
copiar_label_status:
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_status
lp_sta:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_sta
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_sta
fin_sta:
    ldp x29, x30, [sp], #16
    ret

copiar_cadena:
    stp x29, x30, [sp, #-16]!
    mov x1, x0               // Guarda el texto que llegó en x0 dentro de x1
    // Se guarda la dirección donde está el número convertido a texto
    adr x0, buffer_salida    // x0 apunta al buffer donde escribir
lp_cad:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cad
    strb w2, [x0, x14]
    add x14, x14, #1
    add x1, x1, #1
    b lp_cad
fin_cad:
    ldp x29, x30, [sp], #16
    ret

copiar_newline:               // Agrega salto de linea 
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10               // El número 10 es el código ASCII del salto de línea \n
    strb w2, [x0, x14]        // x0 es donde empieza el buffer, el 10 se guarda en x14
    add x14, x14, #1
    ldp x29, x30, [sp], #16
    ret