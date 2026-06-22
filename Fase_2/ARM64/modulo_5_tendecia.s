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

str_column:
    .asciz "COLUMN="

str_wstart:
    .asciz "WINDOW_START="

str_wend:
    .asciz "WINDOW_END="

str_count:
    .asciz "COUNT="
 
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

str_status_ok:
    .asciz "STATUS=OK\n"
 
.bss
 
num_buffer:
    .skip 32

g_columna:
    .skip 8

g_wstart:
    .skip 8

g_wend:
    .skip 8
 
.text


 
// Inicializacion del Programa 
//.extern solo para utilizar las funciones q se encuentran dentro del utils.s
.extern read_column_to_stack 
.extern int_a_ascii
.extern ascii_a_int

.global _start

_start:

    ldr x0, [sp, #24]       //argv[2] = linea inicial
    bl ascii_a_int
    cmp x0, #0
    beq no_argumento
    mov x6, x0              //Guarda linea inicial en x6

    ldr x0, [sp, #32]       //argv[3] = linea final
    bl ascii_a_int
    cmp x0, #0
    beq no_argumento
    mov x7, x0              //Guarda linea final en x7

    ldr x0, [sp, #40]       //argv[4] = columna
    bl ascii_a_int
    cmp x0, #0
    beq no_argumento
    mov x9, x0              //Guarda columna en x9

    ldr x0, =g_columna
    str x9, [x0]            //Guarda columna en memoria, read_column_to_stack usa x7 internamente
    ldr x0, =g_wstart
    str x6, [x0]            //Guarda linea inicial en memoria
    ldr x0, =g_wend
    str x7, [x0]            //Guarda linea final en memoria

    mov x11, x9             //Columna pedida por el usuario
    mov x12, x6             //Linea inicial pedida por el usuario
    mov x13, x7             //Linea final pedida por el usuario
    bl read_column_to_stack //Esta funcion abre el csv, lo lee y guarda solo el rango pedido
 
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

    ldr x1, =str_column         //Se escribe la columna analizada
    bl write_str
    ldr x0, =g_columna
    ldr x0, [x0]
    ldr x1, =num_buffer
    bl int_a_ascii
    ldr x1, =num_buffer
    bl write_str
    ldr x1, =str_nl
    bl write_str

    ldr x1, =str_wstart         //Se escribe la linea inicial pedida
    bl write_str
    ldr x0, =g_wstart
    ldr x0, [x0]
    ldr x1, =num_buffer
    bl int_a_ascii
    ldr x1, =num_buffer
    bl write_str
    ldr x1, =str_nl
    bl write_str

    ldr x1, =str_wend           //Se escribe la linea final usada
    bl write_str
    ldr x0, =g_wend
    ldr x0, [x0]
    ldr x1, =num_buffer
    bl int_a_ascii
    ldr x1, =num_buffer
    bl write_str
    ldr x1, =str_nl
    bl write_str

    ldr x1, =str_count          //Se escribe la cantidad real de datos usados
    bl write_str
    mov x0, x26
    ldr x1, =num_buffer
    bl int_a_ascii
    ldr x1, =num_buffer
    bl write_str
    ldr x1, =str_nl
    bl write_str
 
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

accum_convertir:                //Se convierte la diferencia acumulada a texto para escribirla
    ldr x1, =num_buffer           //Se carga la direccion del buffer para convertir
    bl int_a_ascii                //Se convierte la diferencia acumulada a texto
    ldr x1, =num_buffer           //Se carga la direccion del buffer para escribir
    bl write_str                  //Se escribe la diferencia acumulada
    ldr x1, =str_nl               //Se escribe un salto de linea
    bl write_str                  //Se escribe un salto de linea

    ldr x1, =str_trend            //Se escribe la tendencia general
    bl write_str                  //Se revisa la tendencia general para escribirla

    cmp x16, #0                    //Si la diferencia acumulada es positiva, la tendencia es al alza
    bgt trend_up
    blt trend_down                 //Si la diferencia acumulada es negativa, la tendencia es a la baja

    ldr x1, =str_stable            //Si la diferencia acumulada es cero, la tendencia es estable
    bl write_str
    b escribir_status_ok

    trend_up:
    ldr x1, =str_up                //Escribe la tendencia al alza
    bl write_str                   //Escribe la tendencia al alza
    b escribir_status_ok

    trend_down:
    ldr x1, =str_down              //Escribe la tendencia a la baja
    bl write_str                   //Escribe la tendencia a la baja

escribir_status_ok:
    ldr x1, =str_status_ok         //Se escribe el status final del calculo
    bl write_str
    b cerrar_archivo

cerrar_archivo:
    mov x0, x23                    //Se cierra el archivo de salida
    mov x8, #57
    svc #0

    mov sp, x27                    //Se restaura el stack pointer antes de terminar el programa
    b salir_ok
    
no_argumento:
    mov x0, #1                     //Si no se ingreso un numero de columna o el numero de columna es menor a 2, se muestra un mensaje de error
    ldr x1, =msg_no_arg            //Se carga la direccion del mensaje de error
    mov x2, msg_no_arg_len         //Se carga la longitud del mensaje de error
    mov x8, #64                    //Numero de syscall para escribir en pantalla
    svc #0                         //Se hace la syscall para escribir el mensaje de error en pantalla
    b salir_error                  //Termina el programa con un codigo de error

write_str:
    mov x2, #0                     //Se calcula la longitud de la cadena de texto a escribir

wrte_str_strlen:
    ldrb w0, [x1, x2]                //Se carga un byte de la cadena de texto
    cbz w0, write_str_done           //Si el byte es cero, se ha
    add x2, x2, #1                   //Si el byte no es cero, se incrementa la longitud de la cadena de texto
    b wrte_str_strlen                //Se repite el proceso para calcular la longitud de la

write_str_done:
    mov x0, x23                    //Se mueve el descriptor del archivo de salida a x0 para escribir en el archivo
    mov x8, #64                    //Numero de syscall para escribir en archivos
    svc #0                         //Se hace la syscall para escribir la cadena de texto en el archivo de salida
    ret

salir_ok:
    mov x0, #0                     //Termina el programa con un codigo de exito
    mov x8, #93
    svc #0

salir_error:
    mov x0, #1                     //Termina el programa con un codigo de error
    mov x8, #93
    svc #0