# Módulo 1 - RMSE respecto a un Valor Ideal

## Información General

- **Proyecto:** Invernadero Inteligente IoT
- **Curso:** Arquitectura y Organización de Computadoras y Ensambladores 1
- **Archivo fuente:** modulo_1_rmse.s
- **Responsable:** Alison Melysa Peréz Blanco
- **Variable analizada:** columna seleccionada por el usuario (parámetro de entrada)
- **Cantidad de datos procesados:** variable, según rango línea inicial - línea final indicado por el usuario

---

# 1. Descripción del módulo

Este módulo implementa una rutina en lenguaje ensamblador ARM64 encargada de calcular qué tanto se aleja una variable del invernadero respecto a un valor ideal de referencia, dentro de un rango seleccionado del archivo `lecturas.csv`. El indicador utilizado es el **RMSE** (raíz del error cuadrático medio), calculado mediante una raíz cuadrada entera implementada manualmente.

El resultado final se almacena en el archivo:

```text
resultado_rmse.txt
```

---

# 2. Objetivo

Analizar la desviación de una variable respecto a un valor ideal fijo mediante el cálculo de:

- Error de cada lectura respecto al valor ideal
- Error cuadrático de cada lectura
- Error cuadrático medio (MSE)
- Raíz cuadrada entera del MSE (RMSE)

---

# 3. Algoritmo Implementado

El algoritmo sigue las siguientes etapas:

## Paso 1: Apertura anticipada del archivo de salida

A diferencia de otros módulos, este abre el archivo `resultado_rmse.txt` al inicio del programa (antes incluso de validar los argumentos), guardando su descriptor para reutilizarlo tanto en el camino exitoso como en cualquiera de los caminos de error.

---

## Paso 2: Validación de argumentos

Se valida que `argc` sea exactamente 5 (programa + archivo + línea inicial + línea final + columna). Si no se cumple, el programa escribe un error estructurado y termina.

---

## Paso 3: Lectura de argumentos

Cada argumento de texto se convierte a entero mediante:

```asm
ascii_a_int
```

Los valores de línea inicial, línea final y columna se guardan tanto en registros como en variables de memoria (`guardado_linea_inicial`, `guardado_linea_final`, `guardado_columna`) para poder reportarlos más adelante en la salida.

---

## Paso 4: Lectura del rango solicitado

Se utiliza la rutina:

```asm
read_column_to_stack
```

proporcionada por `utils.s`.

Esta función abre el CSV, extrae la columna solicitada y almacena en la pila únicamente las lecturas comprendidas entre la línea inicial y la línea final.

---

## Paso 5: Validación de datos suficientes

Se valida que el rango tenga al menos 2 datos. Si no se cumple, se reporta el error `INSUFFICIENT_DATA` y el programa termina.

---

## Paso 6: Cálculo del error cuadrático acumulado

Se recorre cada valor del rango leído:

```text
ERROR_i  = Y_i - IDEAL
ERROR2_i = ERROR_i * ERROR_i
```

Cada `ERROR2_i` se va acumulando en un registro hasta recorrer los N datos del rango.

---

## Paso 7: Cálculo del MSE

```text
MSE = suma(ERROR2_i) / N
```

La división se realiza con `udiv`, ya que la suma de cuadrados siempre es no negativa.

---

## Paso 8: Cálculo del RMSE

Como ARM64 no tiene una instrucción de raíz cuadrada entera directa, se implementa una subrutina propia (`raiz_entera`) que prueba candidatos crecientes hasta encontrar el mayor entero cuyo cuadrado no supera el valor buscado.

```text
RMSE = raiz_entera(MSE)
```

---

## Paso 9: Construcción y escritura del archivo de salida

Cada campo del resultado se escribe directamente al archivo mediante la subrutina `rmse_escribir`, sin pasar por un buffer intermedio de texto completo. Los valores numéricos se convierten a texto mediante:

```asm
int_a_ascii
```

---

# 4. Flujo del Programa

```text
abrir resultado_rmse.txt (anticipado)
       │
       ▼
validar argc == 5 ──► (si falla) rmse_error_args
       │
       ▼
ascii_a_int() (x3 veces)
       │
       ▼
read_column_to_stack()
       │
       ▼
validar N >= 2 ──► (si falla) rmse_error_datos_insuficientes
       │
       ▼
rmse_ciclo_suma (acumular ERROR2_i)
       │
       ▼
MSE = suma / N
       │
       ▼
raiz_entera(MSE) -> RMSE
       │
       ▼
rmse_escribir() (por cada campo)
       │
       ▼
resultado_rmse.txt
```

---

# 5. Uso de Memoria

## Sección .data

Contiene el valor ideal de referencia y las cadenas utilizadas para generar el archivo de salida.

Variables principales:

```asm
IDEAL
nombre_archivo_salida
texto_calc
texto_columna
texto_inicio_ventana
texto_fin_ventana
texto_cantidad
texto_ideal
texto_rmse
texto_estado_ok / texto_estado_error
texto_etiqueta_error / texto_etiqueta_detalle
error_args / detalle_args
error_datos_insuficientes / detalle_datos_insuficientes
salto_linea
```

`IDEAL` almacena el valor de referencia (55) contra el cual se mide el error de cada lectura.

---

## Sección .bss

Memoria reservada para almacenamiento temporal.

| Variable | Tamaño | Descripción |
|-----------|---------|-------------|
| buffer_ascii | 32 bytes | Conversión de cada valor numérico a ASCII antes de escribirlo |
| guardado_linea_inicial | 8 bytes | Línea inicial del rango, guardada para reportarla en la salida |
| guardado_linea_final | 8 bytes | Línea final del rango, guardada para reportarla en la salida |
| guardado_columna | 8 bytes | Columna solicitada, guardada para reportarla en la salida |
| guardado_fd_salida | 8 bytes | Descriptor del archivo de salida, abierto al inicio del programa |

---

# 6. Registros Utilizados

## Registros principales

| Registro | Uso |
|-----------|-----|
| x0 | Parámetros y retornos de syscalls/funciones |
| x1 | Direcciones de memoria / segundo parámetro |
| x2 | Longitud de cadena / valor de retorno de `read_column_to_stack` |
| x3 | Permisos de archivo |
| x4 | Acumulador de suma(ERROR2_i) / direcciones temporales |
| x5 | Puntero de recorrido sobre los datos leídos |
| x6 | Contador de elementos recorridos |
| x7 | Valor actual Y_i / ERROR_i / ERROR2_i (reutilizado en cada paso) |
| x8 | Número de syscall |
| x9 | Puntero al nombre de archivo |
| x10 | MSE (resultado de la división) |
| x11 | Línea inicial convertida a entero |
| x12 | Línea inicial guardada (reutilizado como registro de propósito general) |
| x13 | Línea final guardada |
| x24 | Puntero inicio de los datos en la pila |
| x25 | Cantidad total de datos leídos (N) |
| x26 | Posición original de la pila, para restaurarla al finalizar |
| x27 | Línea inicial recuperada de memoria, para reportarla en la salida |
| x28 | RMSE (resultado final) |
| x29 | Valor IDEAL cargado desde memoria |
| x30 | Link Register |

---

# 7. Ciclos Utilizados

## Ciclo de acumulación de error cuadrático

Etiqueta:

```asm
rmse_ciclo_suma
```

Recorre todos los datos del rango leído, calculando `ERROR_i`, elevándolo al cuadrado y acumulando el resultado.

---

## Ciclo de raíz cuadrada entera

Etiqueta:

```asm
raiz_entera_ciclo
```

Prueba candidatos crecientes (1, 2, 3, ...) hasta encontrar el primero cuyo cuadrado supera el valor buscado, retornando el candidato anterior como la raíz entera aproximada.

---

## Ciclo de cálculo de longitud al escribir

Etiqueta:

```asm
rmse_calcular_longitud
```

Calcula la longitud de la cadena convertida a ASCII antes de escribirla, dentro de la subrutina `rmse_escribir_ascii_nl`.

---

# 8. Saltos Condicionales Utilizados

| Instrucción | Función |
|------------|----------|
| b | Salto incondicional |
| bne | Diferente (validar `argc != 5`) |
| blt | Menor que (validar N < 2) |
| bge | Mayor o igual (controlar el fin del ciclo de suma) |
| bgt | Mayor que (controlar el ciclo de raíz cuadrada entera) |
| cmp / bne | Comparación contra cero (fin de cadena al calcular longitud) |

Los saltos permiten:

- Validar que se recibieron los argumentos esperados
- Validar que el rango tenga al menos 2 datos antes de calcular
- Controlar el recorrido del ciclo de acumulación de errores
- Controlar la convergencia del cálculo de raíz cuadrada entera
- Controlar el cálculo de longitud de cada cadena al escribir

---

# 9. Subrutinas Implementadas

## raiz_entera

Calcula la raíz cuadrada entera de un número mediante búsqueda incremental.

Parámetro:

```text
x0 = numero del cual se busca la raiz (MSE)
```

Retorna:

```text
x0 = raiz cuadrada entera aproximada (RMSE)
```

---

## rmse_escribir

Escribe directamente una cadena en el archivo de salida mediante la syscall `write`.

Parámetros:

```text
x0 = direccion de la cadena
x1 = longitud de la cadena
```

---

## rmse_escribir_ascii_nl

Calcula la longitud del contenido actual en `buffer_ascii` (ya convertido por `int_a_ascii`), lo escribe en el archivo y agrega un salto de línea.

---

# 10. Formato de Entrada

Llamada esperada:

```text
./modulo_1_rmse lecturas.csv 1 30 2
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
resultado_rmse.txt
```

Ejemplo (caso exitoso):

```text
CALC=RMSE
COLUMN=2
WINDOW_START=1
WINDOW_END=30
COUNT=30
IDEAL=55
RMSE=18
STATUS=OK
```

Ejemplo (caso de error, argumentos inválidos):

```text
CALC=RMSE
STATUS=ERROR
ERROR=INVALID_ARGS
DETAIL=EXPECTED_4_ARGS
```

Descripción de cada campo:

| Campo | Descripción |
|---------|-------------|
| CALC | Tipo de cálculo realizado |
| COLUMN | Columna analizada |
| WINDOW_START | Línea inicial del rango procesado |
| WINDOW_END | Línea final del rango procesado |
| COUNT | Cantidad de datos procesados dentro del rango |
| IDEAL | Valor de referencia contra el cual se mide el error |
| RMSE | Raíz del error cuadrático medio calculada |
| STATUS | Resultado de la ejecución: OK o ERROR |
| ERROR | Código del error, cuando aplica |
| DETAIL | Detalle del error, cuando aplica |

---

# 12. Evidencia de Depuración con GDB

## Captura 1 — Breakpoint en _start
_(completar con captura propia)_

---

## Captura 2 — Apertura anticipada del archivo de salida
_(completar: mostrar x0 con el descriptor de archivo devuelto por `openat`)_

---

## Captura 3 — Lectura de argumentos
_(completar: mostrar x12/x13/x11 con linea_inicial, linea_final y columna ya convertidos)_

---

## Captura 4 — Entrada a read_column_to_stack
_(completar: mostrar el rango y columna pasados a la función)_

---

## Captura 5 — Primera iteración del ciclo de suma
_(completar: mostrar x7/x4/x29 en la primera iteración de `rmse_ciclo_suma`)_

---

## Captura 6 — Cálculo de raíz cuadrada entera
_(completar: mostrar x4 (candidato) avanzando dentro de `raiz_entera_ciclo`)_

---

## Captura 7 — Programa terminado exitosamente
_(completar: mostrar el contenido final de resultado_rmse.txt)_