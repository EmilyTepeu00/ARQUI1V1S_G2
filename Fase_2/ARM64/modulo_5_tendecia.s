//Modulo 5 - Tendencia

//Definicion de cadenas de texto para el archivo de salida
.data
 
filename_out:
    .asciz "resultado_tendencia.txt"
 
msg_no_arg:
    .ascii "Debe enviar una columna\n"
    msg_no_arg_len = . - msg_no_arg
 
str_module:
    .asciz "MODULE=ADVANCED_TREND\n"
 
str_total:
    .asciz "TOTAL_VALUES="
 
str_incr:
    .asciz "INCREMENTS="
 
str_decr:
    .asciz "DECREMENTS="
 
str_max_up:
    .asciz "MAX_UP_STREAK="
 
str_max_down:
    .asciz "MAX_DOWN_STREAK="
 
str_accum:
    .asciz "ACCUM_DIFF="
 
str_trend:
    .asciz "TREND="
 
str_up:
    .asciz "UP\n"
 
str_down:
    .asciz "DOWN\n"
 
str_stable:
    .asciz "STABLE\n"
 
str_minus:
    .asciz "-"
 
str_nl:
    .asciz "\n"
 
.bss
 
num_buffer:
    .skip 32
 
.text


 
// Inicializacion del Programa importando al Utils.s
.include "utils.s"

.global _start

_start:

    ldr x0, [sp]            //Revisa el numero de columna q deseamos analizar
    cmp x0, #2              // Se compara con el #2
    blt no_argumento        // Muestra error si el no. de columna < 2
 
    ldr x21, [sp, #16]      //Toma el numero de columna a trabajar
    mov x5, #10             //Aviso para trabajar en base 10
    bl atoi_csv             //Cambia el texto extraido a numero real
    cbz x7, no_argumento    //Error si el texto extraido no es un numero
 
    mov x11, x10            //Mueve el numero de columna ingresado
    bl read_column_to_stack //Esta funcion abre el csv, lo lee y guarda los 30 datos
 
    mov x24, x0             //Se guardan 4 datos importantes (Ultimo dato guardado, donde se guardo el ultimo dato, datos totales leidos, dato extra para ordenar de nuevo la pila)
    mov x25, x1
    mov x26, x2
    mov x27, x3
 
    mov x10, #0             //Se limpian 7 registros para contar y guardar calculos
    mov x11, #0
    mov x12, #0
    mov x13, #0
    mov x14, #0
    mov x15, #0
    mov x16, #0
 
    cmp x26, #2            //Revision de datos totales leidos
    blt fin_calculo        //Error si hubieron menos de 2 datos
 
    sub x21, x25, #16      //Se calcula donde se encuentra el dato mas reciente
    ldr x22, [x21]         //Se guarda ese dato reciente listo para empezar a comparar
    sub x21, x21, #16      //Se mueve al segundo dato para compararse con el anterior

bucle_diferencias:         //Estas etiquetas las puse a lo largo del codigo para evitar repetir codigo, aqui se hacen las comparaciones y se van guardando los resultados       
    ldr x17, [x21]         //Se carga el dato a comparar
    sub x18, x17, x22      //Se calcula la diferencia entre el dato actual y el anterior
    add x16, x16, x18      //Se va acumulando la diferencia total para despues sacar la tendencia
 
    cmp x18, #0            //Se revisa si la diferencia es positiva, negativa o cero para contar incrementos, decrementos y rachas    
    bgt es_incremento      //Si es mayor a 0, es un incremento
    cmp x18, #0            //Si no es mayor a 0, se revisa si es menor a 0 para saber si es un decremento
    blt es_decremento      //Si es menor a 0, es un decremento
 
    mov x12, #0            //Si no es ni mayor ni menor a 0, se resetean las rachas y se cuenta como estable
    mov x14, #0            //Se resetean las rachas y se cuenta como estable
    b actualizar_prev      //Se actualiza el dato previo para la siguiente iteracion
 
es_incremento:             //Si es un incremento, se cuentan los incrementos y se actualizan las rachas 
    add x10, x10, #1       //Se cuenta el incremento  
    add x12, x12, #1       //Se cuenta la racha de incrementos
    mov x14, #0            //Se resetea la racha de decrementos
    cmp x12, x13           //Se compara la racha de incrementos con la racha maxima de incrementos
    ble actualizar_prev    //Si la racha de incrementos es menor o igual a la racha maxima de incrementos, se actualiza el dato previo para la siguiente iteracion
    mov x13, x12           //Si la racha de incrementos es mayor a la racha maxima de incrementos, se actualiza la racha maxima de incrementos y se actualiza el dato previo para la siguiente iteracion
    b actualizar_prev      //Se actualiza el dato previo para la siguiente iteracion
 
es_decremento:
    add x11, x11, #1        //Se cuenta el decremento
    add x14, x14, #1        //Se cuenta la racha de decrementos
    mov x12, #0             //Se resetea la racha de incrementos
    cmp x14, x15            //Se compara la racha de decrementos con la racha maxima de decrementos
    ble actualizar_prev     //Si la racha de decrementos es menor o igual a la racha maxima de decrementos, se actualiza el dato previo para la siguiente iteracion
    mov x15, x14            //Si la racha de decrementos es mayor a la racha maxima de decrementos, se actualiza la racha maxima de decrementos y se actualiza el dato previo para la siguiente iteracion
 
actualizar_prev:             
    mov x22, x17             //Se actualiza el dato previo para la siguiente iteracion
 
    cmp x21, x24             //Se revisa si ya se compararon todos los datos leidos
    beq fin_calculo           //Si ya se compararon todos los datos leidos, se termina el ciclo de comparaciones y se va a imprimir resultados
 
    sub x21, x21, #16         //Si no se han comparado todos los datos leidos, se mueve al siguiente dato para comparar y se repite el ciclo de comparaciones
    b bucle_diferencias       //Se repite el ciclo de comparaciones
 
fin_calculo:                  
    mov x0, #-100              //Se prepara para abrir el archivo de salida, se le asigna un numero negativo para que lo cree si no existe o lo sobreescriba si ya existe
    ldr x1, =filename_out      //Se carga la direccion del nombre del archivo de salida
    mov x2, #577             //Flags para abrir el archivo (O_WRONLY | O_CREAT | O_TRUNC)
    mov x3, #420             //Permisos para el archivo (rw-r--r--)
    mov x8, #56                //Numero de syscall para abrir archivos
    svc #0                     //Se hace la syscall para abrir el archivo de salida
    mov x23, x0                 //Se guarda el descriptor del archivo de salida para usarlo despues al escribir en el archivo
 
    ldr x1, =str_module         //Se empiezan a escribir los resultados en el archivo de salida, se cargan las cadenas de texto y se convierten los numeros a texto para escribirlos
    bl write_str                //Se escribe el nombre del modulo
 
    ldr x1, =str_total          //Se escribe el total de valores leidos
    bl write_str                //Se convierte el total de valores leidos a texto para escribirlo
    mov x0, x26                 //Se mueve el total de valores leidos a x0 para convertirlo a texto
    ldr x1, =num_buffer         //Se carga la direccion del buffer para convertir el total de valores leidos a texto
    bl int_a_ascii               //Se convierte el total de valores leidos a texto
    ldr x1, =num_buffer          //Se carga la direccion del buffer para escribir el total de valores leidos
    bl write_str                 //Se escribe el total de valores leidos
    ldr x1, =str_nl              //Se escribe un salto de linea
    bl write_str                 //Se escribe un salto de linea
 
    ldr x1, =str_incr             //Se escribe el total de incrementos
    bl write_str                  //Se convierte el total de incrementos a texto para escribirlo
    mov x0, x10                   //Se mueve el total de incrementos a x0 para convertirlo a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para convertir el total de incrementos a texto
    bl int_a_ascii                //Se convierte el total de incrementos a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para escribir el total de incrementos
    bl write_str                  //Se escribe el total de incrementos
    ldr x1, =str_nl               //Se escribe un salto de linea
    bl write_str                  //Se escribe un salto de linea
 
    ldr x1, =str_decr             //Se escribe el total de decrementos
    bl write_str                  //Se convierte el total de decrementos a texto para escribirlo
    mov x0, x11                   //Se mueve el total de decrementos a x0 para convertirlo a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para convertir el total de decrementos a texto
    bl int_a_ascii                //Se convierte el total de decrementos a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para escribir el total de decrementos
    bl write_str                  //Se escribe el total de decrementos
    ldr x1, =str_nl               //Se escribe un salto de linea
    bl write_str                  //Se escribe un salto de linea
 
    ldr x1, =str_max_up           //Se escribe la racha maxima de incrementos
    bl write_str                  //Se convierte la racha maxima de incrementos a texto para escribirla
    mov x0, x13                   //Se mueve la racha maxima de incrementos a x0 para convertirla a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para convertir la racha maxima de incrementos a texto
    bl int_a_ascii                //Se convierte la racha maxima de incrementos a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para escribir la racha maxima de incrementos
    bl write_str                  //Se escribe la racha maxima de incrementos
    ldr x1, =str_nl               //Se escribe un salto de linea
    bl write_str                  //Se escribe un salto de linea
 
    ldr x1, =str_max_down         //Se escribe la racha maxima de decrementos
    bl write_str                  //Se convierte la racha maxima de decrementos a texto para escribirla
    mov x0, x15                   //Se mueve la racha maxima de decrementos a x0 para convertirla a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para convertir la racha maxima de decrementos a texto
    bl int_a_ascii                //Se convierte la racha maxima de decrementos a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para escribir la racha maxima de decrementos
    bl write_str                  //Se escribe la racha maxima de decrementos
    ldr x1, =str_nl               //Se escribe un salto de linea
    bl write_str                  //Se escribe un salto de linea
 
    ldr x1, =str_accum            //Se escribe la diferencia acumulada
    bl write_str                  //Se convierte la diferencia acumulada a texto para escribirla
 
    cmp x16, #0                   //Se revisa si la diferencia acumulada es negativa o positiva para escribir el signo correspondiente
    bge accum_no_negativo         //Si es positiva, se escribe la diferencia acumulada
 
    ldr x1, =str_minus            //Si es negativa, se escribe el signo negativo
    bl write_str                  //Se convierte la diferencia acumulada a texto para escribirla
    neg x0, x16                   //Se convierte la diferencia acumulada a positiva para escribirla
    b accum_convertir             //Se convierte la diferencia acumulada a texto para escribirla
 
accum_no_negativo:                //Si es positiva, se escribe la diferencia acumulada
    mov x0, x16                   //Se mueve la diferencia acumulada a x0 para convertirla a texto