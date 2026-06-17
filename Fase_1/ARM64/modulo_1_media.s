// ============================================================
// modulo_1_media.s
// Alison Melysa Pérez Blanco - Media Aritmetica Ponderada
// Curso: ACYE1 - Vacaciones Junio 2026
//
// Leo la columna que el usuario seleccione desde el dashboard.
// El numero de columna llega como argv[1] cuando Python ejecuta
// el binario. Si no viene argumento, uso columna 2 (TEMP) por defecto.
//
// La formula que uso es:
//   MEDIA_PONDERADA = S(Xi * Wi) / SWi   donde Wi va de 1 a 30
//
// Para leer el CSV uso leer_datos de utils.s
// Para convertir numeros a texto uso int_a_ascii de utils.s
// Los datos quedan en el arreglo datos[] de utils.s
// ============================================================

// ------------------------------------------------------------
// DECLARACION DE SIMBOLOS EXTERNOS
// Estas funciones y variables estan definidas en utils.s
// Se declaran con .extern para que el linker las pueda encontrar
// al momento de ensamblar y enlazar el proyecto completo
// ------------------------------------------------------------
.extern leer_datos      // funcion que llena datos[] leyendo el CSV
.extern int_a_ascii     // funcion que convierte un entero a string ASCII
.extern datos           // arreglo global donde leer_datos deposita los 30 valores


// ------------------------------------------------------------
// SECCION .data
// Aqui van todas las cadenas y constantes que tienen valor
// desde el inicio del programa (datos inicializados)
// ------------------------------------------------------------
.section .data

// Nombre del archivo de salida donde se guardan los resultados
nombre_salida:
    .asciz "resultado_media.txt"

//-------------------------------------------------------------
//.asciz guarda un texto en memoria y automáticamente le agrega un cero al final 
//(ese cero se llama null terminator y le dice al programa "aquí termina el texto")
//-------------------------------------------------------------

linea_module:
    .asciz "MODULE=WEIGHTED_MEAN\n" // Guarda el texto con salto de linea
linea_module_len = . - linea_module //El punto . significa "la posición actual en memoria"
// Calcula cuantos bytes ocupa el texto (posicion actual menos posicion inicial)
// Se necesita para decirle al sistema operativo cuantos caracteres escribir

linea_total:
    .asciz "TOTAL_VALUES=30\n"
linea_total_len = . - linea_total


// Sin \n porque el numero se pega en la misma linea:
label_sumx:     .asciz "SUM_X="
label_sumx_len = . - label_sumx

label_wsum:     .asciz "WEIGHT_SUM="
label_wsum_len = . - label_wsum

label_mean:     .asciz "WEIGHTED_MEAN="
label_mean_len = . - label_mean

.section .bss //reservar espacio vacio en memoria 

buffer_salida:  .skip 512 //reserva ese espacio vacio para el archivo de salida (bytes)
buf_sumx:   .skip 32
buf_wsum:   .skip 32
buf_media:  .skip 32
//espacio temporal donde se convierte cada numero a texto 

.section .text //inicio codigo ejecutable 
.global _start //el programa arranca aqui

_start: //es lo primero que se ejecuta
    // --------------------------------------------------------
    // LECTURA DE argv[1]: el numero de columna que manda Python
    // Al arrancar el programa, [sp] tiene argc y [sp+16] tiene
    // un puntero al string de argv[1] (ej: "6" para GAS)
    // Si no viene argumento usamos columna 2 (TEMP) por defecto
    // --------------------------------------------------------
    ldr x0, [sp]            // x0 = argc carga el valor de sp en x0 nos dice cantidad de argumentos (si llego columna o solo nombre)
    cmp x0, #2              // es decir el dos indica si viene indicado el numero de columna (compara)
    blt usar_default_1      // si es menor a 2 se va al valor predeterminado

    ldr x0, [sp, #16]       //  a sp le suma 16 bytes y lo guarda en x0 (aqui es donde esta el numero de columna)
    //los corchetes nos ayudan a ir a la direccion y extraer el contenido de ahi
    bl  ascii_a_int         // convierte el string a numero entero en x0, bl llama a una funcion
    b   llamar_leer_1       // ir a llamar leer_datos con ese numero es decir salta hasta esta parte

usar_default_1:
    mov x0, #2              // default: columna 2 = TEMP (1-based en nuevo utils)

llamar_leer_1: //solo marca donde se inicia el programa luego del salto de arriba
    // x0 ya tiene el numero de columna correcto
    // leer_datos llena el arreglo datos[] con los 30 valores de esa columna
    bl leer_datos

    // --------------------------------------------------------
    // CALCULO de media ponderada con pesos Wi = 1, 2, 3 ... 30
    // x19 = puntero a datos[]
    // x20 = SUM_X  (suma simple de todos los datos) (no sirve en la formula)
    // x21 = indice i, va de 0 a 29, indica en que dato voy
    // x22 = suma_ponderada S(Xi * Wi)
    // x23 = suma_pesos S(Wi) = 465 
    // x24 = peso actual Wi, arranca en 1
    // --------------------------------------------------------
    adr x19, datos //adr sirve para obtener la direccion de algo

    // inicializan con el valor dado 
    mov x20, #0
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x24, #1

loop_media:
    cmp x21, #30 //compara el x21 con el valor 30, cuando llega a 30 sale del loop 
    beq fin_media //salta a esto si fueron iguales

    ldr x25, [x19, x21, lsl #3]    // (lsl 3 multipica por 8 bytes) x25 guarda el dato actual 
    // x19 + (x21 × 8)  =  inicio de datos[] + posición del dato actual 
    add x20, x20, x25              // suma dato actual a sumx x20=x20+x25, es el resultado de SUM_X
    mul x26, x25, x24              // Xi * Wi
    add x22, x22, x26              // suma_ponderada S(Xi * Wi)
    add x23, x23, x24              // suma_pesos += Wi
    add x21, x21, #1               // i++
    add x24, x24, #1               // Wi++
    b loop_media //le dice que se vaya aca y ejecute desde ahi 

fin_media:
    // MEDIA_PONDERADA = suma_ponderada / suma_pesos
    udiv x27, x22, x23             // x27 = WEIGHTED_MEAN

    // --------------------------------------------------------
    // ARMAR EL TEXTO en buffer_salida
    // x9 marca hasta donde hemos escrito en el buffer
    // --------------------------------------------------------
    mov x9, #0 // x9 registro que lleva la cuenta de cuántos bytes se han escrito en buffer_salida
    // empieza en 0 porque esta vacio y siempre apunta al final de lo que se escribio

    bl copiar_module // texto fijo de module
    bl copiar_total // texto fijo de total

    // SUM_X=valor
    bl copiar_label_sumx //Copia el texto "SUM_X=" al buffer de salida.
    mov x0, x20 // copia el valor de x20 en x0
    adr x1, buf_sumx // adr para cargar direccion de memoria
    // guarda en x1 la dirección de buf_sumx (aqui se convierte el numero)
    bl int_a_ascii // convierte el numero en x0 a ascii y lo guarda en x1 (en buf_sumx)
    adr x0, buf_sumx // guarda en x0 la dirección de buf_sumx para pasársela a la siguiente función.
    bl copiar_cadena // copia el texto de buf_sumx al buffer principal
    bl copiar_newline // Agrega un salto de línea al buffer.


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

    // --------------------------------------------------------
    // ESCRIBIR AL ARCHIVO resultado_media.txt
    // --------------------------------------------------------
    mov x8, #56             // llamada al sistema para abrir un archivo (openat)
    mov x0, #-100           // AT_FDCWD busca el archivo en la carpeta donde estoy ahorita
    adr x1, nombre_salida  // Guarda en x1 la dirección del texto "resultado_media.txt"
    // Le dice al sistema operativo el nombre del archivo a abrir.
    mov x2, #577            // O_WRONLY|O_CREAT|O_TRUNC
    // Abrir solo para escribir, crear si no existe, si existe se borra y empieza de 0
    mov x3, #0644 // permisos de linux 
    // el dueño puede leer y escribir los demás solo pueden leer
    svc #0 // ejecuta la llamada al sistema 
    mov x10, x0             // guarda el descriptor en x10 para usarlo después 
    // (descriptor es el numero que identifica al archivo que se abrio)

    mov x8, #64             // syscall write, llama al sistema para escribir algo 
    mov x0, x10 // le pasa el descriptor para que sepa en que archivo escribir
    adr x1, buffer_salida // Le dice dónde está el texto que quiere escribir
    mov x2, x9 // Le dice cuántos bytes escribir
    svc #0

    mov x8, #57             // syscall close 
    mov x0, x10 // Le pasa el descriptor para saber qué archivo cerrar
    svc #0

    // MOSTRAR EN TERMINAL 
    mov x8, #64 // write pero para escribir en la terminal 
    mov x0, #1 // El número 1 es el descriptor especial de la terminal
    adr x1, buffer_salida
    mov x2, x9 // escribe en la terminal lo mismo que en el archivo de salida
    svc #0

    // FIN DEL PROGRAMA
    mov x8, #93 // terminar el programa (exit)
    mov x0, #0 // El 0 significa que el programa terminó con éxito
    svc #0


// ---- funciones auxiliares para copiar texto al buffer ----

copiar_module: // copia MODULE=WEIGHTED_MEAN
    stp x29, x30, [sp, #-16]! // stp es guardar dos registros a la vez (la ultima parte baja 16 bytes para hacer espacio)
    // x29 guarda la dirección del stack anterior
    // x30 guarda la dirección de regreso, o sea a dónde volver cuando termine la función
    adr x0, buffer_salida // guarda dirección donde empieza buffer_salida
    adr x1, linea_module // guarda la dirección donde está el texto "MODULE=WEIGHTED_MEAN\n"
    
lp_mod: // Sirve para copiar el texto "MODULE=WEIGHTED_MEAN\n" al buffer de salida
    ldrb w2, [x1] // Lee la letra que está en la dirección x1 y la guarda en w2
    cmp w2, #0 // Compara la letra leída con 0
    beq fin_mod // salta aqui si encuentra \0 (fin texto)
    strb w2, [x0, x9] // Escribe la letra de w2 en la dirección x0 + x9
    add x9, x9, #1 // le suma 1 para avanzar en el buffer
    add x1, x1, #1 // Avanzar a la siguiente letra
    b lp_mod
fin_mod:
    ldp x29, x30, [sp], #16 // ldp recupera registros, sube 16 bytes 
    ret // return Ve a la dirección que tiene x30 y continúa ejecutando desde ahí

copiar_total: // copia TOTAL_VALUES=30
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, linea_total
lp_tot:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_tot
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b lp_tot
fin_tot:
    ldp x29, x30, [sp], #16
    ret

copiar_label_sumx: // copia SUM_X=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_sumx
lp_lsx:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lsx
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b lp_lsx
fin_lsx:
    ldp x29, x30, [sp], #16
    ret

copiar_label_wsum: // WEIGHT_SUM=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_wsum
lp_lws:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lws
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b lp_lws
fin_lws:
    ldp x29, x30, [sp], #16
    ret

copiar_label_mean: // copia WEIGHTED_MEAN=
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    adr x1, label_mean
lp_lmn:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_lmn
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b lp_lmn
fin_lmn:
    ldp x29, x30, [sp], #16
    ret

copiar_cadena:
    stp x29, x30, [sp, #-16]!
    mov x1, x0 // guarda el texto que llegó en x0 dentro de x1
    // Se guarda la dirección donde está el número convertido a texto
    adr x0, buffer_salida // x0 apunta al buffer donde escribir
lp_cad:
    ldrb w2, [x1]
    cmp w2, #0
    beq fin_cad
    strb w2, [x0, x9]
    add x9, x9, #1
    add x1, x1, #1
    b lp_cad
fin_cad:
    ldp x29, x30, [sp], #16
    ret

copiar_newline: // agrega salto de linea 
    stp x29, x30, [sp, #-16]!
    adr x0, buffer_salida
    mov w2, #10 // El número 10 es el código ASCII del salto de línea \n
    strb w2, [x0, x9] // x0 es donde empieza el buffer, el 10 se guarda en x9
    add x9, x9, #1
    ldp x29, x30, [sp], #16
    ret