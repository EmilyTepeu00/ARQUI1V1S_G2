# Módulo 5 - Tendencia Avanzada

## Información General

- **Proyecto:** Invernadero Inteligente IoT
- **Curso:** Arquitectura y Organización de Computadoras y Ensambladores 1
- **Archivo fuente:** modulo_5_tendecia.s
- **Responsable:** José Fernando Ramirez Ambrocio
- **Variable analizada:** columna seleccionada por el usuario (parámetro de entrada)
- **Cantidad de datos procesados:** variable, según rango línea inicial - línea final indicado por el usuario

---

# 1. Descripción del módulo

Este módulo implementa una rutina en lenguaje ensamblador ARM64 encargada de analizar la tendencia de una serie de lecturas dentro de un rango seleccionado del archivo `lecturas.csv`. A diferencia de una tendencia simple (que solo compararía el primer y el último valor), este módulo recorre **todas** las diferencias consecutivas de la ventana para contar incrementos, decrementos, determinar la racha máxima de cada tipo y acumular la diferencia total.

El resultado final se almacena en el archivo:

```text
resultado_tendencia.txt
```

---

# 2. Objetivo

Analizar el comportamiento histórico de una variable del invernadero mediante el cálculo de:

- Cantidad total de incrementos y decrementos entre lecturas consecutivas
- Racha máxima de incrementos consecutivos
- Racha máxima de decrementos consecutivos
- Diferencia acumulada total (suma de todas las diferencias)
- Clasificación final de la tendencia: ascendente, descendente o estable

---

# 3. Algoritmo Implementado

El algoritmo sigue las siguientes etapas:

## Paso 1: Lectura de argumentos

El programa recibe 4 argumentos desde la línea de comandos:

```text
archivo_entrada linea_inicial linea_final columna
```

Cada argumento de texto se convierte a entero mediante:

```asm
ascii_a_int
```

Si no se reciben los argumentos esperados, el programa termina con un mensaje de error.

---

## Paso 2: Lectura del rango solicitado

Se utiliza la rutina:

```asm
read_column_to_stack
```

proporcionada por `utils.s`.

Esta función:

- Abre el archivo `lecturas.csv`
- Extrae únicamente la columna solicitada
- Convierte los valores ASCII a enteros
- Almacena en la pila solo las lecturas comprendidas entre la línea inicial y la línea final
- Devuelve el inicio de los datos, el límite final, la cantidad total leída (N) y la posición original de la pila para restaurarla después

---

## Paso 3: Cálculo de diferencias consecutivas

Se recorre el rango leído comparando cada dato con el dato inmediatamente anterior.

Fórmula:

```text
DIF_i = X_i - X_(i-1)
```

Para cada diferencia se evalúa:

- Si `DIF_i > 0`: se cuenta como incremento y se extiende la racha de incrementos
- Si `DIF_i < 0`: se cuenta como decremento y se extiende la racha de decrementos
- Si `DIF_i = 0`: se reinician ambas rachas (lectura estable)

En cada paso también se acumula la diferencia total:

```text
DIF_ACUM = Σ DIF_i
```

---

## Paso 4: Determinación de rachas máximas

Mientras se recorren las diferencias, el programa compara la racha actual de incrementos (o decrementos) contra la racha máxima registrada hasta ese momento, actualizándola cuando la racha actual la supera.

---

## Paso 5: Clasificación de la tendencia general

Una vez recorrido todo el rango, se evalúa el signo de la diferencia acumulada:

```text
DIF_ACUM > 0  -> Tendencia ascendente (UP)
DIF_ACUM < 0  -> Tendencia descendente (DOWN)
DIF_ACUM = 0  -> Tendencia estable (STABLE)
```

---

## Paso 6: Construcción del archivo de salida

Se construye el archivo de resultado escribiendo directamente, etiqueta por etiqueta, mediante la subrutina `write_str`. Los valores numéricos se convierten a texto mediante:

```asm
int_a_ascii
```

---

## Paso 7: Escritura del archivo

El programa:

1. Crea el archivo `resultado_tendencia.txt`
2. Escribe cada campo del resultado en orden
3. Cierra el archivo
4. Termina con código de salida exitoso

---

# 4. Flujo del Programa

```text
argv[] (archivo, linea_inicial, linea_final, columna)
       │
       ▼
ascii_a_int() (x3 veces)
       │
       ▼
read_column_to_stack()
       │
       ▼
bucle_diferencias (incrementos, decrementos, rachas, acumulado)
       │
       ▼
fin_calculo (clasificar tendencia)
       │
       ▼
write_str() (por cada campo)
       │
       ▼
resultado_tendencia.txt
```

---

# 5. Uso de Memoria

## Sección .data

Contiene las cadenas utilizadas para generar el archivo de salida.

Variables principales:

```asm
filename_out
str_module
str_column
str_wstart
str_wend
str_count
str_total
str_incr
str_decr
str_max_up
str_max_down
str_accum
str_trend
str_up / str_down / str_stable
str_minus
str_nl
str_status_ok
```

Estas cadenas se escriben directamente al archivo de salida mediante `write_str`, sin pasar por un buffer intermedio.

---

## Sección .bss

Memoria reservada para almacenamiento temporal.

| Variable | Tamaño | Descripción |
|-----------|---------|-------------|
| num_buffer | 32 bytes | Conversión de cada valor numérico a ASCII antes de escribirlo |
| g_columna | 8 bytes | Columna solicitada por el usuario, guardada para reportarla en la salida |
| g_wstart | 8 bytes | Línea inicial del rango, guardada para reportarla en la salida |
| g_wend | 8 bytes | Línea final del rango, guardada para reportarla en la salida |

---

# 6. Registros Utilizados

## Registros principales

| Registro | Uso |
|-----------|-----|
| x0 | Parámetros y retornos de syscalls/funciones |
| x1 | Direcciones de memoria / segundo parámetro |
| x2 | Longitud de cadena / flags |
| x3 | Permisos de archivo / valor de retorno de `read_column_to_stack` |
| x6 | Línea inicial convertida a entero |
| x7 | Línea final convertida a entero |
| x8 | Número de syscall |
| x9 | Columna solicitada / nombre de archivo (según el punto del flujo) |
| x10 | Contador de incrementos |
| x11 | Contador de decrementos |
| x12 | Racha actual de incrementos |
| x13 | Racha máxima de incrementos |
| x14 | Racha actual de decrementos |
| x15 | Racha máxima de decrementos |
| x16 | Diferencia acumulada total (DIF_ACUM) |
| x17 | Dato actual a comparar dentro del bucle |
| x18 | Diferencia entre el dato actual y el anterior |
| x21 | Puntero de recorrido sobre los datos leídos |
| x22 | Dato anterior (previo) usado para la comparación |
| x23 | Descriptor del archivo de salida |
| x24 | Inicio de los datos leídos en la pila |
| x25 | Límite final de los datos leídos en la pila |
| x26 | Cantidad total de datos leídos (N) |
| x27 | Posición original de la pila, para restaurarla al finalizar |
| x30 | Link Register |

---

# 7. Ciclos Utilizados

## Ciclo de diferencias consecutivas

Etiqueta:

```asm
bucle_diferencias
```

Recorre todos los datos leídos comparando cada par consecutivo, actualizando contadores de incrementos/decrementos, rachas máximas y la diferencia acumulada.

---

## Ciclo de escritura del buffer/archivo

No existe un ciclo de copiado a buffer intermedio como en el módulo 2; en su lugar, cada campo se escribe directamente al archivo mediante llamadas repetidas a `write_str`, cada una con su propio ciclo interno de cálculo de longitud:

```asm
write_str_len
```

---

# 8. Saltos Condicionales Utilizados

| Instrucción | Función |
|------------|----------|
| b | Salto incondicional |
| beq | Igual (fin de rango, argumento inválido) |
| bgt | Mayor que (detectar incremento) |
| blt | Menor que (detectar decremento / argumentos insuficientes) |
| bge | Mayor o igual (signo de la diferencia acumulada) |
| ble | Menor o igual (comparar racha actual contra racha máxima) |
| cbz | Comparar contra cero (fin de cadena al escribir) |

Los saltos permiten:

- Validar que se recibieron los argumentos esperados
- Clasificar cada diferencia como incremento, decremento o estable
- Actualizar las rachas máximas cuando corresponde
- Determinar el signo de la diferencia acumulada antes de imprimirla
- Clasificar la tendencia final (UP / DOWN / STABLE)
- Controlar el ciclo de cálculo de longitud de cada cadena al escribir

---

# 9. Subrutinas Implementadas

## write_str

Calcula la longitud de una cadena terminada en NULL y la escribe en el archivo de salida mediante la syscall `write`.

Parámetro:

```text
x1 = direccion de la cadena a escribir
```

Usa:

```text
x23 = descriptor del archivo de salida
```

---

# 10. Formato de Entrada

Llamada esperada:

```text
./modulo_5_tendecia lecturas.csv 1 30 2
```

Donde:

- `lecturas.csv` = archivo de entrada
- `1` = línea inicial del rango
- `30` = línea final del rango
- `2` = columna a analizar (posición dentro del CSV)

El módulo procesa únicamente la columna indicada por el usuario, dentro del rango de líneas indicado.

---

# 11. Formato de Salida

Archivo generado:

```text
resultado_tendencia.txt
```

Ejemplo:

```text
MODULE=ADVANCED_TREND
COLUMN=2
WINDOW_START=1
WINDOW_END=30
COUNT=30
TOTAL_VALUES=30
INCREMENTS=18
DECREMENTS=11
MAX_UP_STREAK=4
MAX_DOWN_STREAK=3
ACCUM_DIFF=-5
TREND=DOWN
STATUS=OK
```

Descripción de cada campo:

| Campo | Descripción |
|---------|-------------|
| MODULE | Nombre del módulo ejecutado |
| COLUMN | Columna analizada |
| WINDOW_START | Línea inicial del rango procesado |
| WINDOW_END | Línea final del rango procesado |
| COUNT | Cantidad de datos procesados dentro del rango |
| TOTAL_VALUES | Total de valores leídos (igual a COUNT) |
| INCREMENTS | Cantidad total de incrementos detectados |
| DECREMENTS | Cantidad total de decrementos detectados |
| MAX_UP_STREAK | Racha máxima de incrementos consecutivos |
| MAX_DOWN_STREAK | Racha máxima de decrementos consecutivos |
| ACCUM_DIFF | Diferencia acumulada total (puede ser negativa) |
| TREND | Clasificación final: UP, DOWN o STABLE |
| STATUS | Resultado de la ejecución: OK |

---

# 12. Evidencia de Depuración con GDB

## Captura 1 — Breakpoint en _start
_(completar con captura propia)_

---

## Captura 2 — Lectura de argumentos
_(completar: mostrar x6/x7/x9 con linea_inicial, linea_final y columna ya convertidos)_

---

## Captura 3 — Entrada a read_column_to_stack
_(completar: mostrar el rango y columna pasados a la función)_

---

## Captura 4 — Inicio del bucle de diferencias
_(completar: mostrar x24/x25/x26/x27 tras el retorno de read_column_to_stack)_

---

## Captura 5 — Primera iteración del bucle
_(completar: mostrar x17/x18/x22 en la primera comparación)_

---

## Captura 6 — Actualización de racha máxima
_(completar: mostrar el momento en que x12 supera a x13, o x14 supera a x15)_

---

## Captura 7 — Programa terminado exitosamente
_(completar: mostrar el contenido final de resultado_tendencia.txt)_