# Ejercicio 5 - Incorporacion de datos de 2024

Ampliacion del sistema para trabajar con los taxis amarillos y verdes de
**2024** ademas de los de **2026**, obteniendo los datos directamente de la
TLC.

| Elemento | Ubicacion |
|----------|-----------|
| Script de descarga | [`scripts/download_data.py`](../scripts/download_data.py) |
| Consultas de validacion | [`sql/05_incorporacion/`](../sql/05_incorporacion/) |
| Vistas generalizadas | [`sql/04_analisis/00_vistas.sql`](../sql/04_analisis/00_vistas.sql) |

Para reproducir:

```bash
docker exec lab8-lab python scripts/download_data.py                  # 2024 y 2026
docker exec lab8-lab python scripts/download_data.py --solo-verificar # comprobar sin descargar
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis/00_vistas.sql sql/05_incorporacion
```

Resultados obtenidos el 07-oct-2026 con DuckDB 1.5.5.

---

## 5.1 Cambios al sistema de descarga

El script ya aceptaba otros anios desde el Ejercicio 2 (`--anio`), porque el
anio fijo en el codigo era uno de los problemas corregidos entonces. Por eso
el cambio para incorporar 2024 es minimo y no toca la logica de descarga:

| Cambio | Motivo |
|--------|--------|
| `ANIO_POR_DEFECTO = 2026` -> `ANIOS_POR_DEFECTO = (2024, 2026)` | Ejecutar el script sin argumentos descarga **todos** los anios del laboratorio. Asi el proceso reproducible es un solo comando y no depende de recordar que anios pasar. Para el Ejercicio 8 basta con agregar `2025` a esta tupla. |
| `argumentos.anio = sorted(set(argumentos.anio))` | Si se repite un anio en `--anio` no se procesa dos veces, y el inventario sale en orden cronologico. |
| Docstring y `--help` actualizados | Documentan los anios por defecto y como pedir uno solo (`--anio 2026`). |

## 5.2 - 5.4 Ejecucion

Para mostrar que se conservan los archivos de 2026, primero se descargo solo
2026 (estado al terminar el Ejercicio 2) y despues se ejecuto el script sin
argumentos:

```text
$ python scripts/download_data.py --anio 2026
  descargados   : 16        (8 meses x 2 tipos; 2026-09 a 2026-12 aun no publicados, HTTP 403)

$ python scripts/download_data.py
=== YELLOW 2024 ===
  2024-01  descargando...
  2024-01  listo (47.6 MiB) -> data/raw/yellow/2024/yellow_tripdata_2024-01.parquet
  ...
=== YELLOW 2026 ===
  2026-01  ya existe, se omite
  ...
  2026-08  ya existe, se omite
  2026-09  aun no publicado por la TLC (HTTP 403)
  ...
RESUMEN
  descargados   : 24
  actualizados  : 0
  ya existian   : 16
  no publicados : 8
  fallidos      : 0

$ python scripts/download_data.py --solo-verificar
  descargados   : 0
  ya existian   : 40
  pendientes    : 0
  fallidos      : 0
```

- **5.2** Los 16 archivos de 2026 se conservan: el script los compara con el
  servidor (Parquet valido y mismo tamanio que el `Content-Length` publicado)
  y los omite.
- **5.3** Ningun archivo existente se volvio a descargar (`actualizados: 0`).
  La tabla de zonas tampoco (`ya existe, se omite`).
- **5.4** Se descargaron los 24 archivos de 2024 (12 meses x 2 tipos, 676 MiB).

## 5.5 Verificacion de los archivos incorporados

**Consulta [`01_archivos_por_anio.sql`](../sql/05_incorporacion/01_archivos_por_anio.sql)**
- Objetivo: contar archivos, meses y filas por tipo y anio, y detectar meses
  faltantes antes del ultimo publicado.
- Fuente: `data/raw/*/*/*.parquet` (solo metadatos).

| tipo | anio | archivos | primer mes | ultimo mes | meses faltantes | filas | MiB |
|------|-----:|---------:|-----------:|-----------:|-----------------|------:|----:|
| yellow | 2024 | 12 | 1 | 12 | [] | 41,169,720 | 660.9 |
| yellow | 2026 | 8 | 1 | 8 | [] | 29,703,355 | 487.8 |
| green | 2024 | 12 | 1 | 12 | [] | 660,218 | 15.2 |
| green | 2026 | 8 | 1 | 8 | [] | 337,114 | 7.9 |

Las filas de 2026 coinciden exactamente con las del Ejercicio 3, lo que
confirma que esos archivos no cambiaron.

**Consulta [`02_filas_por_mes.sql`](../sql/05_incorporacion/02_filas_por_mes.sql)**
- Objetivo: comparar mes a mes las filas de cada archivo para detectar
  archivos vacios o anomalos.

| mes | yellow 2024 | yellow 2026 | green 2024 | green 2026 |
|----:|------------:|------------:|-----------:|-----------:|
| 1 | 2,964,624 | 3,724,889 | 56,551 | 40,272 |
| 2 | 3,007,526 | 3,399,866 | 53,577 | 37,373 |
| 3 | 3,582,628 | 3,952,451 | 57,457 | 44,208 |
| 4 | 3,514,289 | 3,831,240 | 56,471 | 44,238 |
| 5 | 3,723,833 | 4,090,836 | 61,003 | 44,921 |
| 6 | 3,539,193 | 3,837,248 | 54,748 | 44,163 |
| 7 | 3,076,903 | 3,530,109 | 51,837 | 41,252 |
| 8 | 2,979,183 | 3,336,716 | 51,771 | 40,687 |
| 9 | 3,633,030 | NULL | 54,440 | NULL |
| 10 | 3,833,771 | NULL | 56,147 | NULL |
| 11 | 3,646,369 | NULL | 52,222 | NULL |
| 12 | 3,668,371 | NULL | 53,994 | NULL |

Ningun archivo esta vacio y todos los meses tienen un volumen del mismo orden
que el resto del anio. **Decision:** se dan por completos los datos de 2024.

**Consulta [`03_esquema_por_anio.sql`](../sql/05_incorporacion/03_esquema_por_anio.sql)**
- Objetivo: listar las columnas que no estan en todos los archivos o que
  cambian de tipo entre anios (las que pueden romper una lectura conjunta).

| tipo | columna | tipo de dato | archivos por anio | aparece desde |
|------|---------|--------------|-------------------|---------------|
| yellow | `cbd_congestion_fee` | DOUBLE | 2024: 0 de 12 \| 2026: 8 de 8 | 2026-01 |
| yellow | `request_source` | VARCHAR | 2024: 0 de 12 \| 2026: 3 de 8 | 2026-06 |
| green | `cbd_congestion_fee` | DOUBLE | 2024: 0 de 12 \| 2026: 8 de 8 | 2026-01 |
| green | `request_source` | VARCHAR | 2024: 0 de 12 \| 2026: 3 de 8 | 2026-06 |

Las otras 19 columnas de yellow y 20 de green existen en los 20 archivos con el
**mismo tipo de dato**. `cbd_congestion_fee` no existe en 2024 porque el cargo
por congestion de Manhattan (CBD) empezo a cobrarse en enero de 2025.
**Decision:** en 2024 ese cargo se trata como NULL (no se cobraba), y toda
lectura de varios anios debe hacerse por nombre de columna (ver 5.7).

## 5.6 Consulta conjunta de 2024 y 2026

**Consulta [`04_lectura_conjunta.sql`](../sql/05_incorporacion/04_lectura_conjunta.sql)**
- Objetivo: leer con un solo `read_parquet` todos los archivos de ambos anios y
  comparar las filas leidas con los metadatos.
- Fuente: `data/raw/yellow/*/*.parquet`, `data/raw/green/*/*.parquet`.

| tipo | anio | filas (metadatos) | filas leidas | diferencia | con cargo CBD | primer inicio | ultimo inicio |
|------|-----:|------------------:|-------------:|-----------:|--------------:|---------------|---------------|
| yellow | 2024 | 41,169,720 | 41,169,720 | 0 | 0 | 2002-12-31 16:46 | **2026-06-26 23:53** |
| yellow | 2026 | 29,703,355 | 29,703,355 | 0 | 29,703,355 | 2001-01-01 09:23 | 2026-08-31 23:59 |
| green | 2024 | 660,218 | 660,218 | 0 | 0 | 2008-12-31 00:00 | 2025-01-01 22:21 |
| green | 2026 | 337,114 | 337,114 | 0 | 337,114 | 2008-12-31 17:35 | 2026-08-31 23:58 |

DuckDB lee los 71.9 M de registros de ambos anios en una sola consulta (1.7 s)
sin perder ni duplicar filas. Un archivo de 2024 contiene un viaje fechado en
**junio de 2026**, una fecha futura respecto al momento en que se publico el
archivo: otro error de reloj como los ya vistos en 2026 (2001, 2008).

**Consulta [`05_fechas_por_anio.sql`](../sql/05_incorporacion/05_fechas_por_anio.sql)**
- Objetivo: verificar con la vista `viajes` que los viajes pertenecen al mes y
  anio de su archivo (igual que la consulta 10 del Ejercicio 3).

| tipo | anio | mes del archivo | otro mes del mismo anio | anio anterior | otro anio |
|------|-----:|----------------:|------------------------:|--------------:|----------:|
| yellow | 2024 | 41,169,300 | 364 | 10 | 46 |
| yellow | 2026 | 29,703,209 | 129 | 6 | 11 |
| green | 2024 | 660,054 | 144 | 2 | 18 |
| green | 2026 | 337,016 | 84 | 4 | 10 |

Mas del 99.97% de los viajes esta en su mes. **Decision:** la regla de
`viajes_validos` se generalizo de `year(inicio) = 2026` a
`year(inicio) = anio` (anio del archivo), que excluye las columnas "anio
anterior" y "otro anio" sin depender de un anio fijo.

**Consulta [`06_reglas_calidad_por_anio.sql`](../sql/05_incorporacion/06_reglas_calidad_por_anio.sql)**
- Objetivo: repetir las reglas de calidad del Ejercicio 3 en ambos anios.

| regla | % yellow 2024 | % yellow 2026 | % green 2024 | % green 2026 |
|-------|-------------:|-------------:|------------:|------------:|
| 01 inicio fuera del anio | 0.000 | 0.000 | 0.003 | 0.004 |
| 02 duracion cero o negativa | 0.033 | **1.251** | 0.100 | 0.069 |
| 03 duracion mayor a 24 h | 0.001 | 0.001 | 0.000 | 0.001 |
| 04 distancia cero | 1.886 | 3.206 | 5.237 | 3.623 |
| 05 distancia mayor a 100 millas | 0.004 | 0.004 | 0.036 | 0.021 |
| 06 tarifa negativa | **1.776** | 0.530 | 0.325 | 0.296 |
| 07 total negativo | 1.480 | 0.545 | 0.329 | 0.303 |
| 08 cero pasajeros | 0.975 | 0.308 | 1.029 | 1.343 |
| 09 pasajeros nulo | 9.937 | 25.979 | 3.685 | 14.468 |
| 10 payment_type 0 (Flex Fare) | **9.937** | **25.979** | 0.000 | 0.000 |
| 11 zona desconocida o fuera de NYC | 1.034 | 0.678 | 1.303 | 1.746 |

Los mismos tipos de problema existen en 2024, con tasas parecidas. Por lo
tanto **las reglas de limpieza de `viajes_validos` siguen siendo adecuadas**
y no fue necesario agregar reglas: con ellas queda el 96.5% de yellow 2024 y el
94.5% de green 2024 (ver salida de `00_vistas.sql`). Dos diferencias
relevantes para el analisis conjunto:

- **Flex Fare** (`payment_type = 0`, con los nulos de `passenger_count`
  asociados) ya existia en 2024 pero pasa del 9.9% al 26% de los viajes yellow.
- Las **tarifas negativas** (reversiones) eran tres veces mas frecuentes en 2024.

**Consulta [`07_proveedores_por_anio.sql`](../sql/05_incorporacion/07_proveedores_por_anio.sql)**
- Objetivo: comprobar si la advertencia del Ejercicio 4 sobre Helix
  (`VendorID = 7`, duracion cero en el 100% de sus viajes) aplica a 2024.

| tipo | anio | proveedor | viajes | % viajes | % duracion cero |
|------|-----:|----------:|-------:|---------:|----------------:|
| yellow | 2024 | 1 CMT | 9,715,918 | 23.60 | 0.11 |
| yellow | 2024 | 2 Curb | 31,451,503 | 76.39 | 0.01 |
| yellow | 2024 | 6 Myle | 2,069 | 0.01 | 21.56 |
| yellow | 2024 | 7 Helix | 230 | 0.00 | 100.00 |
| yellow | 2026 | 1 CMT | 5,467,071 | 18.41 | 0.08 |
| yellow | 2026 | 2 Curb | 23,809,774 | 80.16 | 0.00 |
| yellow | 2026 | 6 Myle | 59,390 | 0.20 | 0.01 |
| yellow | 2026 | 7 Helix | 367,120 | 1.24 | 100.00 |
| green | 2024 | 1 CMT | 80,450 | 12.19 | 0.41 |
| green | 2024 | 2 Curb | 579,768 | 87.81 | 0.06 |
| green | 2026 | 1 CMT | 28,696 | 8.51 | 0.30 |
| green | 2026 | 2 Curb | 273,571 | 81.15 | 0.05 |
| green | 2026 | 6 Myle | 34,847 | 10.34 | 0.01 |

Helix casi no operaba en 2024 (230 viajes), asi que la exclusion de sus
registros afecta solo a 2026 (1.2% de yellow). **Decision:** los indicadores
que cuentan viajes usan la tabla completa `viajes` y no `viajes_validos`, para
no subestimar la demanda de 2026 (Ejercicio 7).

**Consulta [`08_comparacion_mensual.sql`](../sql/05_incorporacion/08_comparacion_mensual.sql)**
- Objetivo: ejemplo de analisis que solo es posible con ambos anios.

| mes | yellow 2024 | yellow 2026 | var. % | green 2024 | green 2026 | var. % |
|----:|------------:|------------:|-------:|-----------:|-----------:|-------:|
| 1 | 2,869,922 | 3,517,979 | +22.6 | 53,517 | 38,887 | -27.3 |
| 2 | 2,901,731 | 3,211,607 | +10.7 | 50,593 | 35,924 | -29.0 |
| 3 | 3,440,432 | 3,764,195 | +9.4 | 54,285 | 42,681 | -21.4 |
| 4 | 3,414,644 | 3,675,670 | +7.6 | 53,130 | 42,544 | -19.9 |
| 5 | 3,618,158 | 3,913,587 | +8.2 | 57,730 | 43,290 | -25.0 |
| 6 | 3,428,602 | 3,647,756 | +6.4 | 51,879 | 42,580 | -17.9 |
| 7 | 2,974,156 | 3,347,456 | +12.6 | 48,701 | 39,518 | -18.9 |
| 8 | 2,867,601 | 3,164,555 | +10.4 | 48,964 | 38,807 | -20.7 |

(viajes validos; septiembre a diciembre solo existen en 2024.) Entre 2024 y
2026 los viajes yellow crecieron entre 6% y 23% en cada mes, mientras que los
green cayeron entre 18% y 29%.

## 5.7 ¿Hay que modificar las consultas anteriores?

Se ejecutaron todas las consultas de los Ejercicios 3 y 4 con los dos anios
descargados.

| Consultas | ¿Cambios? | Detalle |
|-----------|-----------|---------|
| Ejercicio 3 (`sql/03_exploracion/`) | **No se modificaron** | Su objetivo era explorar el conjunto **inicial** (2026), por lo que sus rutas apuntan explicitamente a `data/raw/*/2026/*.parquet` y siguen dando exactamente los mismos resultados. La consulta 01 ya usaba `data/raw/*/*/*.parquet` y ahora cuenta tambien los archivos de 2024 sin cambios. Las comprobaciones relevantes del Ejercicio 3 se repitieron para ambos anios en `sql/05_incorporacion/`. |
| Ejercicio 4: `00_vistas.sql` | **Si** (un archivo concentra el cambio) | (1) La ruta fija `.../2026/*.parquet` se reemplazo por `'data/raw/<tipo>/' \|\| getvariable('periodo') \|\| '.parquet'`, con `periodo = '*/*'` (todos los anios) por defecto. (2) Nueva columna `anio`, tomada del nombre del archivo. (3) La regla `year(inicio) = 2026` paso a `year(inicio) = anio`. (4) `cbd_congestion_fee` y `request_source` se declaran como columnas opcionales (`UNION ALL BY NAME` con una relacion vacia), para que la vista no falle si el periodo elegido no las tiene (p. ej. solo 2024 o solo enero de 2026; se detecto al preparar el benchmark del Ejercicio 6). (5) El resumen final se desglosa por anio. |
| Ejercicio 4: `12_metodos_pago_por_mes.sql` y `19_atipicos_por_proveedor.sql` | **Si**, una linea cada una | Tenian la condicion `year(inicio) = 2026` / `<> 2026`, que se cambio por `anio`. |
| Ejercicio 4: las otras 19 consultas | **No** | Leen las vistas, no los archivos, por lo que heredan el cambio de alcance automaticamente. |
| `notebooks/04_analisis_exploratorio.ipynb` | Una linea | Abre la conexion con `conectar(periodo="2026/*")`, porque los hallazgos del Ejercicio 4 describen 2026. Se reejecuto y produce los mismos resultados (unica diferencia: el nombre de la regla "fecha fuera del anio" en una figura). |
| `scripts/run_sql.py` | Nueva opcion | `--periodo` define la variable antes de ejecutar los archivos. |

Con `--periodo '2026/*'` las 22 consultas del Ejercicio 4 reproducen
exactamente los resultados documentados (p. ej. 28,242,805 viajes yellow
validos). Sin `--periodo` las mismas 22 consultas se ejecutan sobre 2024 + 2026
sin errores: tardan 102 s en total frente a 51 s con solo 2026, para 2.4
veces mas filas.

**Problema encontrado: `union_by_name` es obligatorio.** Sin el, DuckDB toma el
esquema del **primer** archivo del glob. Con 2024 incluido, el primer archivo
es `yellow_tripdata_2024-01.parquet`, que no tiene `cbd_congestion_fee`:

```text
SELECT count(cbd_congestion_fee) FROM read_parquet('data/raw/yellow/*/*.parquet')
-> Binder Error: Referenced column "cbd_congestion_fee" not found in FROM clause!

SELECT count(*), count(cbd_congestion_fee)
FROM read_parquet(['data/raw/yellow/2026/*.parquet', 'data/raw/yellow/2024/*.parquet'])
-> Invalid Input Error: schema mismatch in glob: column "cbd_congestion_fee" was read
   from the original file ".../2026/yellow_tripdata_2026-01.parquet", but could not
   be found in file ".../2024/yellow_tripdata_2024-01.parquet"
```

Todas las consultas del laboratorio ya usaban `union_by_name = true` desde el
Ejercicio 3 (por `request_source`), por eso siguieron funcionando.

**Como elegir el alcance.** Las vistas leen la variable `periodo` cada vez que
se consultan:

```bash
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis                       # 2024 + 2026
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis --periodo '2026/*'     # solo 2026
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis --periodo '2024/*'     # solo 2024
```

## 5.8 Consultas usadas para validar la incorporacion de 2024

| Archivo | Valida |
|---------|--------|
| [`01_archivos_por_anio.sql`](../sql/05_incorporacion/01_archivos_por_anio.sql) | Cantidad de archivos, meses y filas por tipo y anio; meses faltantes. |
| [`02_filas_por_mes.sql`](../sql/05_incorporacion/02_filas_por_mes.sql) | Que ningun archivo mensual este vacio o sea anomalo. |
| [`03_esquema_por_anio.sql`](../sql/05_incorporacion/03_esquema_por_anio.sql) | Columnas que aparecen, desaparecen o cambian de tipo entre anios. |
| [`04_lectura_conjunta.sql`](../sql/05_incorporacion/04_lectura_conjunta.sql) | Lectura conjunta de ambos anios sin perder filas. |
| [`05_fechas_por_anio.sql`](../sql/05_incorporacion/05_fechas_por_anio.sql) | Que los viajes pertenezcan al mes y anio del archivo. |
| [`06_reglas_calidad_por_anio.sql`](../sql/05_incorporacion/06_reglas_calidad_por_anio.sql) | Que las reglas de limpieza sigan siendo adecuadas para 2024. |
| [`07_proveedores_por_anio.sql`](../sql/05_incorporacion/07_proveedores_por_anio.sql) | Proveedores por anio (alcance de la advertencia sobre Helix). |
| [`08_comparacion_mensual.sql`](../sql/05_incorporacion/08_comparacion_mensual.sql) | Un analisis que combina ambos anios a traves de las vistas. |

Las consultas 01-04 leen los archivos directamente; las 05-08 usan las vistas
de `00_vistas.sql`, por lo que deben ejecutarse despues de ese archivo (el
comando del inicio lo hace).

## 5.9 ¿Que permite incorporar archivos sin modificar todo el flujo?

1. **Una estructura de carpetas predecible.** Los archivos se guardan como
   `data/raw/<tipo>/<anio>/<tipo>_tripdata_<anio>-<mes>.parquet`. Un anio
   nuevo es solo otra carpeta, y un patron glob (`*/*`) la incluye sin listar
   archivos.
2. **Un script de descarga parametrizado e idempotente.** El anio es un
   parametro, no una constante; los archivos validos ya descargados se omiten
   y se comparan con el servidor, por lo que volver a ejecutar el proceso
   completo es seguro y barato.
3. **Lectura por nombre de columna (`union_by_name`).** Absorbe las columnas
   nuevas de cada anio (`cbd_congestion_fee`, `request_source`) sin
   reescribir las consultas; las columnas opcionales se declaran una sola vez
   en la vista.
4. **Un unico punto de acceso a los datos.** Ninguna consulta del analisis
   lee archivos: todas usan las vistas de `00_vistas.sql`. El cambio de
   fuente o de alcance se hace en un archivo, y las otras 19 consultas
   heredaron el cambio sin tocarse.
5. **Reglas relativas a los datos, no a constantes.** El anio se deriva del
   nombre del archivo y la regla de validez compara contra ese anio, no contra
   `2026`.
6. **Alcance configurable sin editar SQL** (variable `periodo` /
   `--periodo`), para reproducir un analisis anterior sobre un subconjunto.
7. **Validaciones baratas sobre metadatos.** `parquet_file_metadata` y
   `parquet_schema` verifican completitud y esquema leyendo solo el pie de
   cada archivo (0.2-0.3 s para los 40 archivos), por lo que se pueden repetir
   cada vez que llegan datos nuevos.

8. **Consultas de validacion sin anios fijos.** Las consultas de
   `sql/05_incorporacion/` generan una columna o fila por cada anio
   encontrado (`PIVOT` sin lista de valores, `lag()` sobre el anio anterior
   disponible), por lo que sirven igual con dos o tres anios.

Al agregar 2025 (Ejercicio 8) el plan es: agregar `2025` a
`ANIOS_POR_DEFECTO`, ejecutar la descarga y volver a correr
`sql/05_incorporacion/` para validar; las vistas y consultas no deberian
requerir cambios.
