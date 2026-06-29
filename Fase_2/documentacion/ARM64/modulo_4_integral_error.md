# Módulo 4 - Integral del Error por Regla del Trapecio

## Información General

- **Proyecto:** Invernadero Inteligente IoT
- **Curso:** Arquitectura y Organización de Computadoras y Ensambladores 1
- **Archivo fuente:** modulo_4_integral_error.s
- **Responsable:** José Fernando Ramirez Ambrocio
- **Variable analizada:** columna seleccionada por el usuario (parámetro de entrada)
- **Cantidad de datos procesados:** variable, según rango línea inicial - línea final indicado por el usuario

---

# 1. Descripción del módulo

Este módulo implementa una rutina en lenguaje ensamblador ARM64 encargada de calcular el error acumulado de una variable respecto a un valor ideal de referencia, dentro de un rango seleccionado del archivo `lecturas.csv`. El error acumulado se aproxima mediante la regla del trapecio, integrando el error absoluto entre cada par de lecturas consecutivas.

El resultado final se almacena en el archivo:

```text
resultado_integral.txt
```

---

# 2. Objetivo

Analizar qué tanto se aleja una variable del invernadero respecto a un valor ideal de referencia a lo largo de un rango de tiempo, mediante el cálculo de:

- Error absoluto de cada lectura respecto al valor ideal
- Área aproximada bajo la curva del error entre lecturas consecutivas (regla del trapecio)
- Suma acumulada de todas las áreas (integral total del error)

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

## Paso 3: Validación de datos suficientes

Antes de calcular, se valida que el rango tenga al menos 2 datos, ya que el cálculo del trapecio necesita pares de valores consecutivos.

```text
Si N < 2 -> STATUS=ERROR (ERROR=INSUFFICIENT_DATA)
```

---

## Paso 4: Cálculo del error absoluto por lectura

Para cada par de lecturas consecutivas (Y_i, Y_(i+1)) se calcula el error absoluto respecto al valor ideal:

```text
ERROR_i    = abs(Y_i - IDEAL)
ERROR_NEXT = abs(Y_(i+1) - IDEAL)
```

El valor absoluto se obtiene comparando el resultado de la resta contra cero: si es negativo, se invierte el signo con `neg`.

---

## Paso 5: Cálculo del área del trapecio

Con los dos errores consecutivos se calcula el área aproximada entre ellos:

```text
AREA_TRAPECIO = (ERROR_i + ERROR_NEXT) / 2
```

La división entre 2 se realiza mediante desplazamiento de bits (`lsr`, shift a la derecha), ya que ambos operandos son siempre no negativos en este punto del cálculo.

---

## Paso 6: Acumulación del área total

```text
AREA_ERROR = AREA_ERROR + AREA_TRAPECIO
```

Este cálculo se repite desde el primer par hasta el penúltimo dato del rango, es decir, N-1 veces.

---

## Paso 7: Construcción del archivo de salida

Una vez terminado el recorrido, se construye el archivo de resultado escribiendo directamente, etiqueta por etiqueta, mediante la subrutina `write_str`. Los valores numéricos se convierten a texto mediante:

```asm
int_a_ascii
```

---

## Paso 8: Escritura del archivo

El programa:

1. Crea el archivo `resultado_integral.txt`
2. Escribe cada campo del resultado en orden
3. Cierra el archivo
4. Termina con código de salida exitoso (o de error, si no había suficientes datos)

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
validar N >= 2 ──► (si falla) error_insuficiente
       │
       ▼
bucle_trapecio (ERROR_i, ERROR_NEXT, AREA_TRAPECIO, AREA_ERROR)
       │
       ▼
fin_calculo
       │
       ▼
write_str() (por cada campo)
       │
       ▼
resultado_integral.txt
```

---

# 5. Uso de Memoria

## Sección .data

Contiene las cadenas utilizadas para generar el archivo de salida, además del valor ideal de referencia.

Variables principales:

```asm
filename_out
str_module
str_calc
str_column
str_wstart
str_wend
str_count
str_ideal
str_integral
str_status_ok
str_status_err
str_err_insuf
str_detail_insuf
str_nl
ideal_val
```

`ideal_val` almacena el valor de referencia (IDEAL = 55) contra el cual se mide el error de cada lectura. Estas cadenas se escriben directamente al archivo de salida mediante `write_str`, sin pasar por un buffer intermedio.

---

## Sección .bss

Memoria reservada para almacenamiento temporal.

| Variable | Tamaño | Descripción |
|-----------|---------|-------------|
| num_buffer | 32 bytes | Conversión de cada valor numérico a ASCII antes de escribirlo |
| g_columna | 8 bytes | Columna solicitada por el usuario, guardada para reportarla en la salida |
| g_wstart | 8 bytes | Línea inicial del rango, guardada para reportarla en la salida |
| g_wend | 8 bytes | Línea final del rango, guardada para reportarla en la salida |
| g_count | 8 bytes | Cantidad total de datos leídos (N), guardada para reportarla en la salida |
| g_integral | 8 bytes | Resultado final de la integral del error (AREA_ERROR) |

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
| x10 | Valor IDEAL cargado desde `ideal_val` |
| x14 | Contador de iteraciones restantes (N-1) |
| x16 | Acumulador AREA_ERROR (integral total del error) |
| x18 | Valor Y_i del par actual |
| x19 | Valor Y_(i+1) del par actual |
| x20 | ERROR_i = abs(Y_i - IDEAL) |
| x21 | Puntero al dato actual dentro del rango leído |
| x22 | Dirección del siguiente dato (Y_(i+1)) |
| x23 | ERROR_NEXT = abs(Y_(i+1) - IDEAL) |
| x24 | Inicio de los datos leídos en la pila |
| x25 | Límite final de los datos leídos en la pila |
| x26 | Cantidad total de datos leídos (N) |
| x27 | Posición original de la pila, para restaurarla al finalizar |
| x28 | AREA_TRAPECIO = (ERROR_i + ERROR_NEXT) / 2 |
| x30 | Link Register |

---

# 7. Ciclos Utilizados

## Ciclo de cálculo del trapecio

Etiqueta:

```asm
bucle_trapecio
```

Recorre todos los pares consecutivos del rango leído, calculando el error absoluto de cada lectura respecto al valor ideal, el área del trapecio entre cada par y acumulando el resultado total.

---

## Ciclo de escritura del buffer/archivo

No existe un ciclo de copiado a buffer intermedio; cada campo se escribe directamente al archivo mediante llamadas repetidas a `write_str`, cada una con su propio ciclo interno de cálculo de longitud:

```asm
write_str_len
```

---

# 8. Saltos Condicionales Utilizados

| Instrucción | Función |
|------------|----------|
| b | Salto incondicional |
| blt | Menor que (validar argumentos insuficientes, validar N < 2) |
| bge | Mayor o igual (determinar si una diferencia ya es positiva, sin necesidad de invertir el signo) |
| cbz | Comparar contra cero (fin de iteraciones del bucle, fin de cadena al escribir) |

Los saltos permiten:

- Validar que se recibieron los argumentos esperados
- Validar que el rango tenga al menos 2 datos antes de calcular
- Calcular el valor absoluto de cada error (evitando una instrucción dedicada de valor absoluto)
- Controlar el avance del ciclo de trapecios hasta agotar las N-1 iteraciones
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
./modulo_4_integral_error lecturas.csv 1 30 2
```

Donde:

- `lecturas.csv` = archivo de entrada
- `1` = línea inicial del rango
- `30` = línea final del rango
- `2` = columna a analizar (posición dentro del CSV)

El módulo procesa únicamente la columna indicada por el usuario, dentro del rango de líneas indicado, comparando cada lectura contra el valor ideal fijo (`IDEAL=55`).

---

# 11. Formato de Salida

Archivo generado:

```text
resultado_integral.txt
```

Ejemplo (caso exitoso):

```text
MODULE=ERROR_INTEGRAL
CALC=ERROR_INTEGRAL
COLUMN=2
WINDOW_START=1
WINDOW_END=30
COUNT=30
IDEAL=55
ERROR_INTEGRAL=740
STATUS=OK
```

Ejemplo (caso de error, menos de 2 datos):

```text
MODULE=ERROR_INTEGRAL
STATUS=ERROR
ERROR=INSUFFICIENT_DATA
DETAIL=INTEGRAL_REQUIRES_AT_LEAST_2_VALUES
```

Descripción de cada campo:

| Campo | Descripción |
|---------|-------------|
| MODULE | Nombre del módulo ejecutado |
| CALC | Tipo de cálculo realizado |
| COLUMN | Columna analizada |
| WINDOW_START | Línea inicial del rango procesado |
| WINDOW_END | Línea final del rango procesado |
| COUNT | Cantidad de datos procesados dentro del rango |
| IDEAL | Valor de referencia contra el cual se mide el error |
| ERROR_INTEGRAL | Resultado final: área acumulada del error (integral aproximada) |
| STATUS | Resultado de la ejecución: OK o ERROR |
| ERROR | Código del error, cuando aplica |
| DETAIL | Detalle del error, cuando aplica |

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

## Captura 4 — Validación de N >= 2
_(completar: mostrar x26 con el valor de N antes de la comparación)_

---

## Captura 5 — Primera iteración del bucle del trapecio
_(completar: mostrar x18/x19/x20/x23/x28 en la primera iteración)_

---

## Captura 6 — Acumulación del área total
_(completar: mostrar x16 incrementándose entre dos iteraciones consecutivas)_

---

## Captura 7 — Programa terminado exitosamente
_(completar: mostrar el contenido final de resultado_integral.txt)_