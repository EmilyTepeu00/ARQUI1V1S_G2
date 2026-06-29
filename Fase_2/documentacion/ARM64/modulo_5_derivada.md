# Módulo 5 - Derivada Suavizada por Regresión Local

## Información General

- **Proyecto:** Invernadero Inteligente IoT
- **Curso:** Arquitectura y Organización de Computadoras y Ensambladores 1
- **Archivo fuente:** modulo_5_derivada_local.s
- **Responsable:** Emily Maritza Tepeu Guacamaya - 202402955
- **Variable analizada:** columna seleccionada por el usuario (parámetro de entrada)
- **Cantidad de datos procesados:** variable, según rango línea inicial - línea final indicado por el usuario (mínimo 5 datos)

---

# 1. Descripción del módulo

Este módulo implementa una rutina en lenguaje ensamblador ARM64 encargada de calcular la velocidad de cambio local de una variable del invernadero, dentro de un rango seleccionado del archivo `lecturas.csv`. A diferencia de una derivada simple (resta entre dos puntos consecutivos), este módulo utiliza mini-ventanas deslizantes de 5 puntos, calculando para cada una la pendiente mediante regresión lineal simple, y reporta la mayor pendiente local encontrada en todo el rango.

El resultado final se almacena en el archivo:

```text
resultado_derivada.txt
```

---

# 2. Objetivo

Analizar la velocidad de cambio local de una variable del invernadero mediante el cálculo de:

- Pendiente local de cada mini-ventana de 5 lecturas consecutivas
- Pendiente local máxima detectada en todo el rango analizado

---

# 3. Algoritmo Implementado

El algoritmo sigue las siguientes etapas:

## Paso 1: Lectura de argumentos (con valores por defecto)

El programa recibe 4 argumentos desde la línea de comandos. Si no se reciben los argumentos esperados (`argc < 5`), el módulo utiliza valores por defecto (columna 7, rango 1-30, archivo `lecturas.csv`), permitiendo ejecutarlo directamente sin parámetros durante pruebas.

```asm
ascii_a_int
```

---

## Paso 2: Lectura del rango solicitado

Se utiliza la rutina:

```asm
read_column_to_stack
```

proporcionada por `utils.s`.

---

## Paso 3: Validación de datos suficientes

Se valida que el rango tenga al menos 5 datos, ya que cada mini-ventana requiere exactamente 5 puntos consecutivos. Si no se cumple, se reporta el error `INSUFFICIENT_DATA` y el programa termina.

---

## Paso 4: Copia de los datos a un buffer propio

A diferencia de otros módulos que recorren directamente el área de la pila devuelta por `read_column_to_stack`, este módulo copia primero todos los datos leídos a un buffer dedicado (`datos_copia`), de forma que el recorrido posterior por mini-ventanas sea más simple de indexar secuencialmente.

---

## Paso 5: Cálculo de pendientes por mini-ventana

El total de ventanas posibles es `N - 4` (una ventana de tamaño 5 por cada posición inicial posible dentro del rango). Para cada ventana se recorren sus 5 puntos, tratando sus posiciones como `X = 0,1,2,3,4`, y se acumulan:

```text
suma(Y)
suma(X*Y)
```

Como para `X = 0,1,2,3,4` se cumple siempre `suma(X) = 10` y `suma(X*X) = 30`, el denominador de la regresión es constante (`DENOM = 50`), lo que permite simplificar la fórmula general de regresión a:

```text
LOCAL_SLOPE_X100 = ((5 * suma(X*Y)) - (10 * suma(Y))) * 100 / 50
                  = ((5 * suma(X*Y)) - (10 * suma(Y))) * 2
```

---

## Paso 6: Determinación de la pendiente máxima

Cada pendiente local calculada se compara contra la máxima encontrada hasta el momento, actualizándola cuando la nueva pendiente la supera. La ventana se desliza una posición a la vez (no de 5 en 5), de forma que se evalúan todas las posiciones posibles dentro del rango.

---

## Paso 7: Construcción del archivo de salida

Cada campo del resultado se copia al buffer de salida mediante la subrutina `copiar_cadena`, y los valores numéricos se convierten a texto mediante:

```asm
int_a_ascii
```

---

## Paso 8: Escritura del archivo

El programa crea el archivo `resultado_derivada.txt`, escribe el buffer completo, lo cierra y termina.

---

# 4. Flujo del Programa

```text
argv[] (archivo, linea_inicial, linea_final, columna) o valores por defecto
       │
       ▼
ascii_a_int() (x3 veces) / usar_default
       │
       ▼
read_column_to_stack()
       │
       ▼
validar N >= 5 ──► (si falla) escribir_error_insuficiente
       │
       ▼
copia_loop (copiar datos a datos_copia)
       │
       ▼
calcular_ventanas (por cada ventana de 5 puntos)
       │
       ▼
calcular_puntos_ventana (suma(Y), suma(X*Y))
       │
       ▼
calcular LOCAL_SLOPE_X100 y comparar con maximo actual
       │
       ▼
fin_calculo (guardar MAX_LOCAL_SLOPE_X100)
       │
       ▼
copiar_cadena() (por cada campo)
       │
       ▼
resultado_derivada.txt
```

---

# 5. Uso de Memoria

## Sección .data

Contiene las cadenas utilizadas para generar el archivo de salida y los mensajes de error estructurados.

Variables principales:

```asm
archivo_default
archivo_salida
str_calc
label_column / label_wstart / label_wend / label_count / label_wsize / label_max_slope
str_status_ok / str_status_error
str_error / str_detail
```

Constantes definidas con `.equ`:

```asm
WINDOW_SIZE = 5
SUMA_X = 10
SUMA_X2 = 30
DENOM = 50
```

---

## Sección .bss

Memoria reservada para almacenamiento temporal.

| Variable | Tamaño | Descripción |
|-----------|---------|-------------|
| buf_num1 | 32 bytes | Conversión de la columna/línea inicial/línea final/COUNT a ASCII |
| buf_num2 | 32 bytes | Conversión del resultado final (MAX_LOCAL_SLOPE_X100) a ASCII |
| buf_num3 | 32 bytes | Reservado para conversión numérica adicional |
| buffer_salida | 512 bytes | Construcción del archivo de salida |
| arg_columna | 8 bytes | Columna solicitada, guardada para reportarla en la salida |
| arg_window_start | 8 bytes | Línea inicial del rango, guardada para reportarla en la salida |
| arg_window_end | 8 bytes | Línea final del rango, guardada para reportarla en la salida |
| datos_copia | 16384 bytes | Copia local de hasta 2048 valores leídos, para recorrer las mini-ventanas de forma indexada |
| res_max_slope | 8 bytes | Resultado final: la mayor pendiente local encontrada |

---

# 6. Registros Utilizados

## Registros principales

| Registro | Uso |
|-----------|-----|
| x0 | Parámetros y retornos de syscalls/funciones |
| x1 | Direcciones de memoria / segundo parámetro |
| x4 | Puntero de escritura dentro de `datos_copia` |
| x5 | Contador de datos restantes por copiar |
| x6 | Puntero de recorrido sobre los datos leídos / inicio de la ventana actual |
| x9 | Dato actual leído / byte leído al copiar cadenas |
| x10 | Valor temporal en cálculos intermedios (5, 10, 2, según el paso) |
| x11 | Producto temporal (i * Y) / 5 * suma(X*Y) |
| x12 | 10 * suma(Y) |
| x13 | Diferencia (5*sumaXY - 10*sumaY) |
| x15 | LOCAL_SLOPE_X100 de la ventana actual |
| x19 | Puntero de recorrido dentro de la ventana actual |
| x20 | Contador de ventanas procesadas |
| x21 | Total de ventanas a procesar (N - 4) |
| x22 | Pendiente local máxima encontrada hasta el momento |
| x23 | Contador de puntos dentro de la ventana actual / posición temporal guardada al copiar cadenas |
| x24 | suma(Y) de la ventana actual / puntero inicio de los datos leídos |
| x25 | suma(X*Y) de la ventana actual / puntero fin de los datos leídos |
| x26 | Posición original de la pila, para restaurarla al finalizar |
| x27 | Cantidad total de datos leídos (N) |
| x30 | Link Register |

---

# 7. Ciclos Utilizados

## Ciclo de copiado de datos

Etiqueta:

```asm
copia_loop
```

Copia los datos leídos por `read_column_to_stack` hacia el buffer propio `datos_copia`, para facilitar el recorrido indexado posterior.

---

## Ciclo de recorrido de ventanas

Etiqueta:

```asm
calcular_ventanas
```

Recorre todas las posiciones iniciales posibles de una ventana de 5 puntos dentro del rango leído, desplazándose una posición a la vez.

---

## Ciclo interno de cada ventana

Etiqueta:

```asm
calcular_puntos_ventana
```

Recorre los 5 puntos de la ventana actual, acumulando `suma(Y)` y `suma(X*Y)` necesarios para calcular la pendiente local.

---

## Ciclo de copiado de cadenas al buffer de salida

Etiqueta:

```asm
loop_cc
```

Copia byte por byte una cadena terminada en NULL hacia el buffer de salida, dentro de la subrutina `copiar_cadena`.

---

# 8. Saltos Condicionales Utilizados

| Instrucción | Función |
|------------|----------|
| b | Salto incondicional |
| blt | Menor que (argumentos insuficientes) |
| bge | Mayor o igual (validar N >= 5, controlar fin de los ciclos de ventanas y puntos) |
| ble | Menor o igual (comparar pendiente local actual contra la máxima encontrada) |
| cbz | Comparar contra cero (fin de cadena al copiar, fin del recorrido de copia de datos) |
| beq | Igual (fin de cadena al copiar dentro de `copiar_cadena`) |

Los saltos permiten:

- Decidir entre usar argumentos reales o valores por defecto
- Validar que el rango tenga al menos 5 datos antes de calcular
- Controlar el recorrido de copiado de datos hacia el buffer propio
- Controlar el avance por todas las ventanas posibles dentro del rango
- Controlar el recorrido de los 5 puntos de cada ventana
- Actualizar la pendiente máxima cuando la ventana actual la supera
- Controlar el ciclo de copiado de cada cadena al buffer de salida

---

# 9. Subrutinas Implementadas

## copiar_cadena

Copia una cadena terminada en NULL hacia el buffer de salida, byte por byte, avanzando la posición de escritura `x9`.

Parámetro:

```text
x1 = direccion de la cadena a copiar
```

---

## copiar_newline

Agrega un salto de línea (`\n`) al buffer de salida en la posición actual.

---

## escribir_error_insuficiente

Construye y escribe un archivo de salida con formato de error estructurado cuando el rango solicitado no alcanza el mínimo de 5 datos requerido.

---

# 10. Formato de Entrada

Llamada esperada:

```text
./modulo_5_derivada_local lecturas.csv 1 30 2
```

Donde:

- `lecturas.csv` = archivo de entrada
- `1` = línea inicial del rango
- `30` = línea final del rango
- `2` = columna a analizar (posición dentro del CSV)

Si se ejecuta sin argumentos, el módulo usa por defecto el archivo `lecturas.csv`, rango 1-30 y columna 7.

---

# 11. Formato de Salida

Archivo generado:

```text
resultado_derivada.txt
```

Ejemplo (caso exitoso):

```text
CALC=LOCAL_DERIVATIVE
COLUMN=2
WINDOW_START=1
WINDOW_END=30
COUNT=30
WINDOW_SIZE=5
MAX_LOCAL_SLOPE_X100=420
STATUS=OK
```

Ejemplo (caso de error, menos de 5 datos):

```text
CALC=LOCAL_DERIVATIVE
COLUMN=2
STATUS=ERROR
ERROR=INSUFFICIENT_DATA
DETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES
```

Descripción de cada campo:

| Campo | Descripción |
|---------|-------------|
| CALC | Tipo de cálculo realizado |
| COLUMN | Columna analizada |
| WINDOW_START | Línea inicial del rango procesado |
| WINDOW_END | Línea final del rango procesado |
| COUNT | Cantidad de datos procesados dentro del rango |
| WINDOW_SIZE | Tamaño fijo de cada mini-ventana (siempre 5) |
| MAX_LOCAL_SLOPE_X100 | Mayor pendiente local detectada, multiplicada por 100 |
| STATUS | Resultado de la ejecución: OK o ERROR |
| ERROR | Código del error, cuando aplica |
| DETAIL | Detalle del error, cuando aplica |

---

# 12. Evidencia de Depuración con GDB

## Captura 1 — Breakpoint en _start
_(completar con captura propia)_

---

## Captura 2 — Lectura de argumentos
_(completar: mostrar x12/x13/x11 con linea_inicial, linea_final y columna ya convertidos)_

---

## Captura 3 — Validación de N >= 5
_(completar: mostrar x27 con el valor de N antes de la comparación)_

---

## Captura 4 — Copia de datos al buffer propio
_(completar: mostrar x5/x6 avanzando dentro de `copia_loop`)_

---

## Captura 5 — Primera ventana, acumulación de sumas
_(completar: mostrar x23/x24/x25 dentro de `calcular_puntos_ventana`)_

---

## Captura 6 — Actualización de la pendiente máxima
_(completar: mostrar el momento en que x15 supera a x22 dentro de `ventana_lista`)_

---

## Captura 7 — Programa terminado exitosamente
_(completar: mostrar el contenido final de resultado_derivada.txt)_