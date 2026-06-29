# Módulo 2 - Regresión Lineal Simple

## Información General

- **Proyecto:** Invernadero Inteligente IoT
- **Curso:** Arquitectura y Organización de Computadoras y Ensambladores 1
- **Archivo fuente:** modulo_2_regresion.s
- **Responsable:** Diana Myriam Priscila Santizo Cáceres
- **Variable analizada:** columna seleccionada por el usuario (parámetro de entrada)
- **Cantidad de datos procesados:** variable, según rango línea inicial - línea final indicado por el usuario

---

# 1. Descripción del módulo

Este módulo implementa una rutina en lenguaje ensamblador ARM64 encargada de calcular la tendencia general de una variable del invernadero dentro de un rango seleccionado del archivo `lecturas.csv`, mediante regresión lineal simple. A diferencia de una tendencia calculada únicamente con el primer y el último valor, este módulo utiliza todos los puntos de la ventana para obtener una pendiente representativa del comportamiento completo.

El resultado final se almacena en el archivo:

```text
resultado_regresion.txt
```

---

# 2. Objetivo

Analizar la tendencia general de una variable del invernadero mediante el cálculo de:

- Sumatorias necesarias para la regresión lineal (suma de X, suma de Y, suma de X·Y, suma de X²)
- Pendiente de la recta de regresión, escalada por 100 para mantener precisión entera
- Clasificación de la tendencia: ascendente, descendente o estable

---

# 3. Algoritmo Implementado

El algoritmo sigue las siguientes etapas:

## Paso 1: Lectura de argumentos (con valores por defecto)

El programa recibe 4 argumentos desde la línea de comandos. Si no se reciben los argumentos esperados (`argc < 5`), el módulo no termina con error: en su lugar utiliza valores por defecto (archivo `lecturas.csv`, rango 1000-1050, columna 5/LUZ), lo que permite ejecutarlo directamente sin parámetros durante pruebas.

```asm
ascii_a_int
```

---

## Paso 2: Lectura del rango solicitado

Se utiliza la rutina:

```asm
read_column_to_stack
```

proporcionada por `utils.s`, que devuelve el conteo de datos leídos (N) en `x2`, guardado luego en `x27`.

---

## Paso 3: Validación de datos suficientes

Se valida que el rango tenga al menos 2 datos, requisito mínimo para una regresión lineal.

```text
Si N < 2 -> STATUS=ERROR (ERROR=INSUFFICIENT_DATA)
```

---

## Paso 4: Cálculo de sumatorias

Se recorre el rango leído asignando a cada dato una posición temporal `X_i` (1, 2, 3, ..., N) y acumulando:

```text
sum(X_i)
sum(Y_i)
sum(X_i * Y_i)
sum(X_i * X_i)
```

El recorrido avanza retrocediendo el puntero de datos 16 bytes en cada iteración, ya que `read_column_to_stack` almacena las lecturas en la pila en orden inverso al cronológico.

---

## Paso 5: Cálculo de la pendiente (SLOPE_X100)

```text
NUMERADOR   = (N * sum(X_i*Y_i)) - (sum(X_i) * sum(Y_i))
DENOMINADOR = (N * sum(X_i*X_i)) - (sum(X_i) * sum(X_i))
SLOPE_X100  = (NUMERADOR * 100) / DENOMINADOR
```

Si el denominador es cero, se evita la división y se asigna directamente `SLOPE_X100 = 0` (tendencia estable), en lugar de provocar un error de división entre cero.

---

## Paso 6: Clasificación de la tendencia

```text
SLOPE_X100 > 0  -> ASCENDING
SLOPE_X100 < 0  -> DESCENDING
SLOPE_X100 = 0  -> STABLE
```

---

## Paso 7: Identificación del nombre de columna

El módulo incluye un pequeño diccionario que traduce el número de columna recibido al nombre real de la variable (`TEMP`, `HUM_AIRE`, `HUM_SUELO_1`, etc.), mediante una cadena de comparaciones (`cmp`/`beq`) contra cada valor posible.

---

## Paso 8: Construcción del archivo de salida

A diferencia de otros módulos que escriben directamente al archivo campo por campo, este módulo arma primero el contenido completo en un buffer en memoria (`buffer_salida`) mediante la subrutina `copiar_a_buffer`, y recién al final realiza una única escritura del buffer completo al archivo.

---

## Paso 9: Escritura del archivo

El programa:

1. Calcula el tamaño real del contenido armado en el buffer
2. Crea el archivo `resultado_regresion.txt`
3. Escribe el buffer completo de una sola vez
4. Cierra el archivo
5. Termina con código de salida exitoso

---

# 4. Flujo del Programa

```text
argv[] (archivo, linea_inicial, linea_final, columna) o valores por defecto
       │
       ▼
ascii_a_int() (x3 veces) / usar_defaults
       │
       ▼
read_column_to_stack()
       │
       ▼
validar N >= 2 ──► (si falla) error_datos
       │
       ▼
loop_sumatorias (sum(X), sum(Y), sum(X*Y), sum(X^2))
       │
       ▼
calcular SLOPE_X100 ──► (denominador=0) es_estable
       │
       ▼
evaluar_tendencia (ASCENDING / DESCENDING / STABLE)
       │
       ▼
armar_salida (copiar_a_buffer por cada campo)
       │
       ▼
guardar_archivo (escritura unica del buffer completo)
       │
       ▼
resultado_regresion.txt
```

---

# 5. Uso de Memoria

## Sección .data

Contiene las cadenas utilizadas para generar el archivo de salida, el diccionario de nombres de columna y el mensaje de error estructurado.

Variables principales:

```asm
nombre_csv / nombre_salida
lbl_calc / lbl_win_start / lbl_win_end / lbl_count / lbl_slope / lbl_trend / lbl_status
col_1_nom ... col_8_nom / col_unk
trend_asc / trend_desc / trend_stab
err_insuficiente
```

---

## Sección .bss

Memoria reservada para almacenamiento temporal.

| Variable | Tamaño | Descripción |
|-----------|---------|-------------|
| buffer_salida | 1024 bytes | Construcción completa del archivo de salida antes de escribirlo |
| buf_conv | 32 bytes | Conversión de cada valor numérico a ASCII antes de copiarlo al buffer |

---

# 6. Registros Utilizados

## Registros principales

| Registro | Uso |
|-----------|-----|
| x0 | Parámetros y retornos / dirección de cadena a copiar |
| x1 | Segundo parámetro / buffer de salida en `read_column_to_stack` |
| x2 | Cantidad de datos leídos (devuelto por `read_column_to_stack`) |
| x9 | Nombre del archivo de entrada |
| x11 | Columna solicitada |
| x12 | Línea inicial solicitada |
| x13 | Línea final solicitada |
| x19 | sum(X_i) |
| x20 | sum(Y_i) |
| x20 (reutilizado) | buffer de salida (puntero de escritura, sección de armado) |
| x21 | sum(X_i * Y_i) |
| x21 (reutilizado) | byte leído al copiar cadenas al buffer |
| x22 | sum(X_i * X_i) |
| x23 | Contador X_i (posición temporal, de 1 a N) / pendiente SLOPE_X100 |
| x24 | Puntero al dato actual durante el recorrido |
| x25 | Dato Y_i actual / cadena de tendencia seleccionada |
| x26 | Producto temporal (X_i*Y_i o X_i*X_i) / tamaño final del contenido a escribir |
| x27 | Cantidad total de datos leídos (N) |
| x30 | Link Register |

---

# 7. Ciclos Utilizados

## Ciclo de cálculo de sumatorias

Etiqueta:

```asm
loop_sumatorias
```

Recorre todos los datos del rango leído, acumulando `sum(X)`, `sum(Y)`, `sum(X*Y)` y `sum(X*X)` necesarios para la fórmula de regresión.

---

## Ciclo de copiado al buffer de salida

Etiqueta:

```asm
copiar_a_buffer
```

Copia byte por byte una cadena terminada en NULL hacia el buffer de salida, avanzando el puntero de escritura en cada iteración.

---

# 8. Saltos Condicionales Utilizados

| Instrucción | Función |
|------------|----------|
| b | Salto incondicional |
| blt | Menor que (argumentos insuficientes, datos insuficientes) |
| bgt | Mayor que (clasificar tendencia ascendente) |
| beq | Igual (identificar columna en el diccionario, fin de cadena al copiar) |
| cbz | Comparar contra cero (denominador igual a cero) |

Los saltos permiten:

- Decidir entre usar argumentos reales o valores por defecto
- Validar que el rango tenga al menos 2 datos antes de calcular
- Evitar la división entre cero cuando el denominador de la regresión es cero
- Clasificar la tendencia final (ASCENDING / DESCENDING / STABLE)
- Identificar el nombre de la columna analizada dentro del diccionario
- Controlar el ciclo de copiado de cada cadena al buffer de salida

---

# 9. Subrutinas Implementadas

## copiar_a_buffer

Copia una cadena terminada en NULL hacia el buffer de salida, byte por byte.

Parámetros:

```text
x0 = direccion de la cadena a copiar
x20 = puntero de escritura dentro de buffer_salida (se actualiza)
```

---

## formatear_numero

Convierte un número entero (positivo o negativo) a su representación en texto, anteponiendo el signo `-` cuando corresponde antes de llamar a `int_a_ascii`.

Parámetros:

```text
x0 = numero a convertir
x1 = direccion del buffer destino
```

---

# 10. Formato de Entrada

Llamada esperada:

```text
./modulo_2_regresion lecturas.csv 1 30 2
```

Donde:

- `lecturas.csv` = archivo de entrada
- `1` = línea inicial del rango
- `30` = línea final del rango
- `2` = columna a analizar (posición dentro del CSV)

Si se ejecuta sin argumentos, el módulo usa por defecto el archivo `lecturas.csv`, rango 1000-1050 y columna 5 (LUZ).

---

# 11. Formato de Salida

Archivo generado:

```text
resultado_regresion.txt
```

Ejemplo (caso exitoso):

```text
CALC=LINEAR_REGRESSION
COLUMN=TEMP
WINDOW_START=1
WINDOW_END=30
COUNT=30
SLOPE_X100=-42
TREND=DESCENDING
STATUS=OK
```

Ejemplo (caso de error, menos de 2 datos):

```text
STATUS=ERROR
ERROR=INSUFFICIENT_DATA
DETAIL=REQUIRES_AT_LEAST_2_VALUES
```

Descripción de cada campo:

| Campo | Descripción |
|---------|-------------|
| CALC | Tipo de cálculo realizado |
| COLUMN | Nombre de la columna analizada (traducido desde el número de columna) |
| WINDOW_START | Línea inicial del rango procesado |
| WINDOW_END | Línea final del rango procesado |
| COUNT | Cantidad de datos procesados dentro del rango |
| SLOPE_X100 | Pendiente de la regresión, multiplicada por 100 |
| TREND | Clasificación final: ASCENDING, DESCENDING o STABLE |
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

## Captura 3 — Entrada a read_column_to_stack
_(completar: mostrar el rango y columna pasados a la función)_

---

## Captura 4 — Primera iteración del ciclo de sumatorias
_(completar: mostrar x19/x20/x21/x22/x23 en la primera iteración de `loop_sumatorias`)_

---

## Captura 5 — Cálculo de la pendiente
_(completar: mostrar x6 (numerador), x7 (denominador) y x23 (SLOPE_X100) tras el cálculo)_

---

## Captura 6 — Clasificación de tendencia
_(completar: mostrar el salto tomado en `evaluar_tendencia` según el signo de x23)_

---

## Captura 7 — Programa terminado exitosamente
_(completar: mostrar el contenido final de resultado_regresion.txt)_