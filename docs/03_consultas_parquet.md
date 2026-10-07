# Ejercicio 3 - Consultas directas sobre archivos Parquet

Exploracion inicial de los viajes de taxis amarillos (yellow) y verdes (green)
de 2026 con DuckDB, **sin importar los datos a ninguna tabla**: todas las
consultas leen directamente `data/raw/<tipo>/2026/*.parquet` mediante
`read_parquet`, `parquet_file_metadata` y `parquet_schema`, sobre una base
DuckDB en memoria.

| Elemento | Ubicacion |
|----------|-----------|
| Consultas SQL (un archivo por consulta) | [`sql/03_exploracion/`](../sql/03_exploracion/) |
| Notebook que las ejecuta, con resultados | [`notebooks/03_exploracion_parquet.ipynb`](../notebooks/03_exploracion_parquet.ipynb) |
| Ejecutor por linea de comandos | [`scripts/run_sql.py`](../scripts/run_sql.py) |

Para reproducir los resultados:

```bash
docker exec lab8-lab python scripts/run_sql.py sql/03_exploracion
# o abrir notebooks/03_exploracion_parquet.ipynb en http://localhost:8888
```

Datos utilizados: los 16 archivos descargados en el Ejercicio 2 (enero-agosto
2026; ver [`descarga_datos.md`](descarga_datos.md)). Resultados obtenidos el
06-oct-2026 con DuckDB 1.5.5.

## Decisiones generales de configuracion

- **`union_by_name = true` en toda lectura de varios meses.** Desde 2026-06 los
  archivos tienen una columna mas (`request_source`). Sin esta opcion DuckDB
  usa el esquema del primer archivo y la columna desaparece
  (`Binder Error: Referenced column "request_source" not found`).
- **`memory_limit = 3GB`.** Docker Desktop asigna ~7.6 GB a todos los
  contenedores y Metabase usa ~1.4 GB. Con el limite por defecto de DuckDB
  (80% de la RAM) las consultas pesadas fallaron con
  `Cannot allocate memory`. Con un limite explicito DuckDB administra su
  memoria y puede usar disco para operaciones grandes. Se configura en
  `scripts/run_sql.py` (`conectar()`), que tambien usa el notebook.
- **Rutas relativas a la raiz del proyecto** (`data/raw/...`). El ejecutor y el
  notebook cambian a la raiz antes de ejecutar.
- **Yellow y green se consultan por separado o se unifican con alias.** Las
  columnas de fecha tienen distinto nombre (`tpep_*` vs `lpep_*`) y cada tipo
  tiene columnas propias, por lo que las consultas que combinan ambos tipos
  seleccionan columnas explicitas con un alias comun (`inicio`, `fin`, ...).

---

## 3.1 Cantidad de archivos disponibles

**Consulta:** [`01_cantidad_archivos.sql`](../sql/03_exploracion/01_cantidad_archivos.sql)

```sql
SELECT
    coalesce(split_part(file_name, '/', 3), 'TOTAL')            AS tipo,
    coalesce(split_part(file_name, '/', 4), '')                 AS anio,
    count(*)                                                    AS archivos,
    round(sum(file_size_bytes) / 1024 ^ 2, 1)                   AS tamanio_mib
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ROLLUP ((split_part(file_name, '/', 3), split_part(file_name, '/', 4)))
ORDER BY tipo = 'TOTAL', tipo DESC, anio;
```

- **Objetivo:** contar los archivos Parquet disponibles por tipo y anio, con su tamanio.
- **Fuente:** `data/raw/*/*/*.parquet` (glob sobre todos los tipos y anios).
- **Resultado:**

  | tipo | anio | archivos | tamanio_mib |
  |------|------|---------:|------------:|
  | yellow | 2026 | 8 | 487.8 |
  | green | 2026 | 8 | 7.9 |
  | TOTAL | | 16 | 495.7 |

- **Decision:** se usa un glob con comodines (`*/*/*.parquet`) en lugar de una
  lista fija de archivos, de modo que la consulta incluye automaticamente los
  meses o anios que se agreguen despues. El volumen de green es ~60 veces menor
  que el de yellow, por lo que las conclusiones generales estaran dominadas por
  yellow y conviene analizar ambos tipos por separado.

## 3.2 Cantidad de registros disponibles

Se obtuvo de dos formas para validar el resultado.

### a) Desde los metadatos

**Consulta:** [`02_registros_por_metadatos.sql`](../sql/03_exploracion/02_registros_por_metadatos.sql)

```sql
SELECT
    split_part(file_name, '/', 3)                        AS tipo,
    regexp_extract(file_name, '(\d{4}-\d{2})', 1)        AS mes,
    num_rows                                             AS filas,
    num_row_groups                                       AS row_groups,
    round(file_size_bytes / 1024 ^ 2, 1)                 AS tamanio_mib,
    created_by
FROM parquet_file_metadata('data/raw/*/2026/*.parquet')
ORDER BY tipo DESC, mes;
```

- **Objetivo:** obtener las filas de cada archivo leyendo solo el pie Parquet.
- **Fuente:** `data/raw/*/2026/*.parquet`.
- **Resultado:**

  | mes | filas yellow | filas green |
  |-----|-------------:|------------:|
  | 2026-01 | 3,724,889 | 40,272 |
  | 2026-02 | 3,399,866 | 37,373 |
  | 2026-03 | 3,952,451 | 44,208 |
  | 2026-04 | 3,831,240 | 44,238 |
  | 2026-05 | 4,090,836 | 44,921 |
  | 2026-06 | 3,837,248 | 44,163 |
  | 2026-07 | 3,530,109 | 41,252 |
  | 2026-08 | 3,336,716 | 40,687 |

  Cada archivo yellow tiene 4 row groups (~1 M filas cada uno) y cada green 1.
  Los archivos fueron generados con distintas versiones de `parquet-cpp-arrow`
  (16.1.0, 21.0.0 y 24.0.0), lo que confirma que la TLC los genera o
  republica en momentos distintos.

### b) Recorriendo los datos

**Consulta:** [`03_registros_por_lectura.sql`](../sql/03_exploracion/03_registros_por_lectura.sql)

```sql
SELECT
    coalesce(tipo, 'TOTAL')  AS tipo,
    count(*)                 AS archivos,
    sum(filas)               AS registros
FROM (
    SELECT split_part(filename, '/', 3) AS tipo, filename, count(*) AS filas
    FROM read_parquet('data/raw/*/2026/*.parquet', union_by_name = true, filename = true)
    GROUP BY ALL
)
GROUP BY ROLLUP (tipo)
ORDER BY tipo = 'TOTAL', tipo DESC;
```

- **Objetivo:** contar los registros con `read_parquet` y confirmar que coinciden con los metadatos.
- **Fuente:** `data/raw/*/2026/*.parquet`.
- **Resultado:**

  | tipo | archivos | registros |
  |------|---------:|----------:|
  | yellow | 8 | 29,703,355 |
  | green | 8 | 337,114 |
  | TOTAL | 16 | **30,040,469** |

- **Decision:** ambos metodos coinciden. Para conteos totales basta con los
  metadatos (no requiere leer datos); el conteo por lectura se usa cuando hay
  filtros.

## 3.3 Columnas presentes en los archivos

**Consulta:** [`04_columnas.sql`](../sql/03_exploracion/04_columnas.sql)

```sql
WITH esquema AS (
    SELECT split_part(file_name, '/', 3) AS tipo, file_name, name AS columna, column_id
    FROM parquet_schema('data/raw/*/2026/*.parquet')
    WHERE num_children IS NULL
)
SELECT
    columna,
    min(column_id) FILTER (WHERE tipo = 'yellow')                 AS posicion_yellow,
    count(DISTINCT file_name) FILTER (WHERE tipo = 'yellow')      AS archivos_yellow,
    min(column_id) FILTER (WHERE tipo = 'green')                  AS posicion_green,
    count(DISTINCT file_name) FILTER (WHERE tipo = 'green')       AS archivos_green
FROM esquema
GROUP BY columna
ORDER BY coalesce(posicion_yellow, posicion_green), posicion_green;
```

- **Objetivo:** listar las columnas de cada tipo y en cuantos archivos aparece cada una.
- **Fuente:** `data/raw/*/2026/*.parquet` (solo metadatos).
- **Resultado:** yellow tiene 21 columnas y green 22. De ellas, 17 son comunes
  (aunque en distinto orden):

  | Grupo | Columnas |
  |-------|----------|
  | Comunes (17) | `VendorID`, `passenger_count`, `trip_distance`, `RatecodeID`, `store_and_fwd_flag`, `PULocationID`, `DOLocationID`, `payment_type`, `fare_amount`, `extra`, `mta_tax`, `tip_amount`, `tolls_amount`, `improvement_surcharge`, `total_amount`, `congestion_surcharge`, `cbd_congestion_fee` |
  | Solo yellow | `tpep_pickup_datetime`, `tpep_dropoff_datetime`, `Airport_fee` |
  | Solo green | `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `ehail_fee`, `trip_type` |
  | Solo en 3 de 8 archivos (2026-06 a 2026-08) | `request_source` (ambos tipos) |

- **Decision:** (1) usar `union_by_name = true` siempre; (2) para combinar
  yellow y green, renombrar las fechas a nombres comunes; (3) no depender del
  orden de las columnas (`SELECT *` con `UNION ALL` posicional mezclaria
  columnas distintas), sino seleccionarlas por nombre.

## 3.4 Tipos de datos de las columnas

**Consulta:** [`05_tipos_de_datos.sql`](../sql/03_exploracion/05_tipos_de_datos.sql)

```sql
SELECT
    split_part(file_name, '/', 3)  AS tipo,
    name                           AS columna,
    type                           AS tipo_parquet,
    converted_type                 AS tipo_convertido,
    duckdb_type                    AS tipo_duckdb,
    count(DISTINCT file_name)      AS archivos
FROM parquet_schema('data/raw/*/2026/*.parquet')
WHERE num_children IS NULL
GROUP BY ALL
ORDER BY tipo DESC, min(column_id);
```

- **Objetivo:** obtener el tipo fisico Parquet, el tipo logico y el tipo DuckDB
  de cada columna, y verificar que no cambie entre archivos.
- **Fuente:** `data/raw/*/2026/*.parquet` (solo metadatos).
- **Resultado:** cada columna aparece en una sola fila por tipo de taxi, es decir,
  **ningun tipo cambia entre meses**.

  | Tipo Parquet (logico) | Tipo DuckDB | Columnas |
  |-----------------------|-------------|----------|
  | INT32 | INTEGER | `VendorID`, `PULocationID`, `DOLocationID` |
  | INT64 | BIGINT | `passenger_count`, `RatecodeID`, `payment_type`, `trip_type` |
  | INT64 (TIMESTAMP_MICROS) | TIMESTAMP | `*_pickup_datetime`, `*_dropoff_datetime` |
  | DOUBLE | DOUBLE | `trip_distance` y todos los montos (`fare_amount`, `extra`, `mta_tax`, `tip_amount`, `tolls_amount`, `ehail_fee`, `improvement_surcharge`, `total_amount`, `congestion_surcharge`, `Airport_fee`, `cbd_congestion_fee`) |
  | BYTE_ARRAY (UTF8) | VARCHAR | `store_and_fwd_flag`, `request_source` |

- **Decision / observaciones:**
  - Los codigos categoricos (`RatecodeID`, `payment_type`, `passenger_count`)
    se guardan como BIGINT aunque tienen pocos valores; no afecta las
    consultas, pero en una tabla materializada podrian reducirse a
    `TINYINT`/`SMALLINT`.
  - Los montos son `DOUBLE`, no `DECIMAL`, por lo que pueden aparecer errores de
    redondeo (p. ej. `0.30000000000000004`). Al comparar montos se redondea a 2
    decimales (ver consulta 16).
  - Los timestamps no tienen zona horaria (`isAdjustedToUTC=0`): son hora local
    de Nueva York. No deben convertirse como si fueran UTC.

## 3.5 Muestra de registros

**Consultas:** [`06_muestra_yellow.sql`](../sql/03_exploracion/06_muestra_yellow.sql) y [`07_muestra_green.sql`](../sql/03_exploracion/07_muestra_green.sql)

```sql
SELECT *
FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
ORDER BY hash(t)
LIMIT 10;
```

- **Objetivo:** observar registros reales de todos los meses.
- **Fuente:** `data/raw/yellow/2026/*.parquet` y `data/raw/green/2026/*.parquet`.
- **Resultado (extracto yellow, columnas seleccionadas):**

  | VendorID | inicio | fin | pasajeros | distancia | RatecodeID | payment_type | total | congestion | request_source |
  |---:|---|---|---:|---:|---:|---:|---:|---:|---|
  | 2 | 2026-07-02 15:31:48 | 2026-07-02 15:44:54 | 1 | 2.57 | 1 | 2 | 20.35 | 2.5 | NULL |
  | 2 | 2026-06-06 17:40:39 | 2026-06-06 17:48:19 | NULL | 0.93 | NULL | 0 | 15.83 | NULL | HV0003 |
  | 1 | 2026-08-11 20:46:28 | 2026-08-11 20:59:10 | NULL | 2.40 | NULL | 0 | 27.95 | NULL | HV0003 |
  | 2 | 2026-02-22 11:13:01 | 2026-02-22 11:28:00 | NULL | 3.63 | NULL | 0 | 26.34 | NULL | NULL |
  | 2 | 2026-05-26 17:47:29 | 2026-05-26 17:49:01 | 1 | 0.07 | 1 | 4 | **-10.20** | -2.5 | NULL |

  La muestra completa esta en el notebook.

- **Decision:** la muestra ya deja ver tres patrones que se investigan en 3.6:
  filas con varios campos nulos a la vez (`payment_type = 0`), montos negativos
  (`payment_type = 4`, disputa) y codigos `HV0003` en `request_source`.
  **Sobre el metodo de muestreo:** primero se uso
  `USING SAMPLE reservoir(10 ROWS) REPEATABLE (42)`, pero devolvio solo
  viajes del 1 de enero (con varios hilos el muestreo no fue representativo).
  `LIMIT 10` tiene el mismo problema (primeras filas del primer archivo). Se
  decidio ordenar por el hash de la fila completa: es pseudoaleatorio,
  reproducible y abarca todos los meses, a costa de recorrer los datos (~7 s
  en yellow).

## 3.6 Problemas de calidad de datos

### Perfil estadistico por columna

**Consultas:** [`08_resumen_yellow.sql`](../sql/03_exploracion/08_resumen_yellow.sql) y [`09_resumen_green.sql`](../sql/03_exploracion/09_resumen_green.sql)

```sql
SELECT column_name, column_type, min, max, approx_unique,
       round(TRY_CAST(avg AS DOUBLE), 2) AS avg, q50, null_percentage
FROM (SUMMARIZE SELECT * FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true));
```

- **Objetivo:** obtener por columna minimo, maximo, cardinalidad, promedio, mediana y % de nulos.
- **Fuente:** `data/raw/yellow/2026/*.parquet` / `data/raw/green/2026/*.parquet`.
- **Resultado (columnas con hallazgos):**

  | Columna | yellow min | yellow max | yellow % nulos | green min | green max | green % nulos |
  |---------|-----------:|-----------:|---------------:|----------:|----------:|--------------:|
  | pickup_datetime | **2001-01-01** | 2026-08-31 | 0 | **2008-12-31** | 2026-08-31 | 0 |
  | passenger_count | 0 | 9 | **25.98** | 0 | 9 | **14.47** |
  | trip_distance | 0 | **328,522.2** | 0 | 0 | **179,830.92** | 0 |
  | RatecodeID | 1 | 99 | **25.98** | 1 | 99 | **14.47** |
  | fare_amount | **-2,555.20** | 7,045.00 | 0 | **-500.00** | 1,676.70 | 0 |
  | total_amount | **-2,560.20** | 7,053.50 | 0 | **-501.50** | 1,678.20 | 0 |
  | tip_amount | **-222.00** | 766.00 | 0 | -14.00 | 495.00 | 0 |
  | congestion_surcharge | -2.50 | 2.75 | **25.98** | -2.75 | 2.75 | **14.47** |
  | ehail_fee | - | - | - | NULL | NULL | **100.00** |
  | request_source | A | HV0005 | **90.23** | A | HV0005 | **94.30** |

  Mediana de `trip_distance`: 1.86 millas (yellow) frente a un promedio de 5.55,
  lo que indica valores extremos que distorsionan el promedio.

- **Decision:** investigar con consultas especificas (10 a 16) cada anomalia:
  fechas, nulos, codigos, valores imposibles, duplicados y consistencia de
  montos. Usar la **mediana** en lugar del promedio para distancias y montos.

### Fechas fuera del periodo esperado

**Consulta:** [`10_fechas_fuera_de_rango.sql`](../sql/03_exploracion/10_fechas_fuera_de_rango.sql)

```sql
WITH viajes AS (
    SELECT 'yellow' AS tipo, filename, tpep_pickup_datetime AS inicio
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true, filename = true)
    UNION ALL
    SELECT 'green', filename, lpep_pickup_datetime
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true, filename = true)
),
clasificados AS (
    SELECT tipo, inicio,
        CASE
            WHEN strftime(inicio, '%Y-%m') = regexp_extract(filename, '(\d{4}-\d{2})', 1)
                THEN '1 mes del archivo'
            WHEN year(inicio) = 2026 THEN '2 otro mes de 2026'
            ELSE '3 otro anio'
        END AS ubicacion
    FROM viajes
)
SELECT tipo, ubicacion, count(*) AS filas, min(inicio) AS minimo, max(inicio) AS maximo
FROM clasificados
GROUP BY ALL
ORDER BY tipo DESC, ubicacion;
```

- **Objetivo:** verificar que cada viaje pertenezca al mes del archivo que lo contiene.
- **Fuente:** ambos tipos, 2026.
- **Resultado:**

  | tipo | ubicacion | filas | minimo | maximo |
  |------|-----------|------:|--------|--------|
  | yellow | mes del archivo | 29,703,209 | 2026-01-01 00:00:00 | 2026-08-31 23:59:59 |
  | yellow | otro mes de 2026 | 129 | 2026-01-31 23:31:23 | 2026-08-05 20:54:00 |
  | yellow | otro anio | 17 | 2001-01-01 09:23:58 | 2025-12-31 23:59:06 |
  | green | mes del archivo | 337,016 | 2026-01-01 00:03:27 | 2026-08-31 23:58:28 |
  | green | otro mes de 2026 | 84 | 2026-01-26 23:38:06 | 2026-08-01 14:36:42 |
  | green | otro anio | 14 | 2008-12-31 17:35:31 | 2025-12-31 22:00:16 |

- **Decision:** solo 244 filas (<0.001%) estan fuera de su mes; muchas son
  viajes iniciados minutos antes de la medianoche del mes anterior y otras son
  fechas imposibles (2001, 2008, 2009). Para analisis temporales se filtrara
  por la **fecha del viaje** (`inicio` entre 2026-01-01 y el ultimo mes
  descargado), no por el archivo de origen, y se excluiran las fechas de otros
  anios.

### Patron de valores nulos

**Consulta:** [`11_nulos_por_tipo_pago.sql`](../sql/03_exploracion/11_nulos_por_tipo_pago.sql)

```sql
WITH viajes AS (
    SELECT 'yellow' AS tipo, payment_type, passenger_count, RatecodeID,
           store_and_fwd_flag, congestion_surcharge
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green', payment_type, passenger_count, RatecodeID,
           store_and_fwd_flag, congestion_surcharge
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
)
SELECT tipo, payment_type, count(*) AS filas,
    count(*) FILTER (WHERE passenger_count IS NULL)         AS pasajeros_nulos,
    count(*) FILTER (WHERE RatecodeID IS NULL)              AS ratecode_nulos,
    count(*) FILTER (WHERE store_and_fwd_flag IS NULL)      AS flag_nulos,
    count(*) FILTER (WHERE congestion_surcharge IS NULL)    AS congestion_nulos
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, payment_type NULLS LAST;
```

- **Objetivo:** explicar el 26% (yellow) y 14.5% (green) de nulos del perfil.
- **Fuente:** ambos tipos, 2026.
- **Resultado:**

  | tipo | payment_type | filas | pasajeros nulos | ratecode nulos | flag nulos | congestion nulos |
  |------|---:|---:|---:|---:|---:|---:|
  | yellow | 0 (Flex Fare) | 7,716,688 | 7,716,688 | 7,716,688 | 7,716,688 | 7,716,688 |
  | yellow | 1 a 5 | 21,986,667 | 0 | 0 | 0 | 0 |
  | green | NULL | 48,775 | 48,775 | 48,775 | 48,775 | 48,775 |
  | green | 1 a 4 | 288,339 | 0 | 0 | 0 | 0 |

- **Decision:** los nulos **no son aleatorios**: ocurren todos juntos y
  exactamente en las filas con `payment_type = 0` ("Flex Fare", yellow) o
  `payment_type` nulo (green). Son viajes con tarifa acordada previamente (por
  ejemplo, solicitados por aplicacion) que no registran esos campos. No se
  eliminaran (son el 26% de los viajes yellow), pero cualquier analisis de
  pasajeros, tarifa (`RatecodeID`) o recargo de congestion debe excluirlos o
  tratarlos como categoria aparte. No se imputaran valores.

### Valores de las columnas categoricas

**Consulta:** [`12_valores_categoricos.sql`](../sql/03_exploracion/12_valores_categoricos.sql)

```sql
WITH viajes AS (
    SELECT 'yellow' AS tipo, VendorID::VARCHAR AS VendorID, RatecodeID::VARCHAR AS RatecodeID,
           payment_type::VARCHAR AS payment_type, store_and_fwd_flag,
           NULL::VARCHAR AS trip_type, request_source
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green', VendorID::VARCHAR, RatecodeID::VARCHAR, payment_type::VARCHAR,
           store_and_fwd_flag, trip_type::VARCHAR, request_source
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
),
largo AS (
    FROM viajes
    UNPIVOT INCLUDE NULLS (valor FOR columna IN
        (VendorID, RatecodeID, payment_type, store_and_fwd_flag, trip_type, request_source))
)
SELECT columna, coalesce(valor, 'NULL') AS valor,
       count(*) FILTER (WHERE tipo = 'yellow') AS yellow,
       count(*) FILTER (WHERE tipo = 'green')  AS green
FROM largo
WHERE NOT (columna = 'trip_type' AND tipo = 'yellow')
GROUP BY ALL
ORDER BY columna, valor;
```

- **Objetivo:** comparar los codigos presentes con el diccionario de datos de la TLC.
- **Fuente:** ambos tipos, 2026.
- **Resultado (resumen):**

  | Columna | Valores encontrados (yellow / green) | Observacion |
  |---------|---------------------------------------|-------------|
  | VendorID | 1, 2, 6, 7 / 1, 2, 6 | Todos documentados (7 = Helix, solo yellow). |
  | RatecodeID | 1-6, **99** (769,693 / 2), NULL | 99 = "nulo/desconocido": 2.6% de yellow tiene una tarifa desconocida ademas de los NULL. |
  | payment_type | 0-5 / 1-4, NULL | Todos documentados; 5 (desconocido) solo 2 filas. |
  | store_and_fwd_flag | N, Y, NULL | Correcto (NULL = Flex Fare). |
  | trip_type (green) | 1, 2, NULL (48,777) | 2 filas mas con NULL que `payment_type`. |
  | request_source | A, CC, EH0004, EH0010, HV0003, HV0005, NULL | **No documentado** en el diccionario disponible. `HV0003` y `HV0005` coinciden con los codigos de licencia HVFHS de la TLC (Uber y Lyft), lo que sugiere viajes de taxi despachados por esas aplicaciones. |

- **Decision:** tratar `RatecodeID = 99` igual que NULL (desconocido). Usar
  `request_source` solo a partir de 2026-06 y con cautela hasta contar con
  documentacion oficial. No hay codigos fuera de dominio que obliguen a
  descartar filas.

### Reglas de calidad

**Consulta:** [`13_reglas_de_calidad.sql`](../sql/03_exploracion/13_reglas_de_calidad.sql)
(se muestra abreviada; ver el archivo para la lista completa de reglas)

```sql
WITH viajes AS (
    SELECT 'yellow' AS tipo, tpep_pickup_datetime AS inicio, tpep_dropoff_datetime AS fin,
           passenger_count, trip_distance, fare_amount, total_amount, PULocationID, DOLocationID
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green', lpep_pickup_datetime, lpep_dropoff_datetime, passenger_count, trip_distance,
           fare_amount, total_amount, PULocationID, DOLocationID
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
),
conteos AS (
    SELECT tipo, count(*) AS total,
        count(*) FILTER (WHERE year(inicio) <> 2026)            AS "01 inicio fuera de 2026",
        count(*) FILTER (WHERE fin < inicio)                    AS "02 fin antes del inicio",
        count(*) FILTER (WHERE fin = inicio)                    AS "03 duracion cero",
        -- ... reglas 04 a 12 ...
    FROM viajes
    GROUP BY tipo
),
largo AS (UNPIVOT conteos ON COLUMNS(* EXCLUDE (tipo, total)) INTO NAME regla VALUE filas)
SELECT regla,
    max(filas) FILTER (WHERE tipo = 'yellow')                             AS yellow,
    round(max(100.0 * filas / total) FILTER (WHERE tipo = 'yellow'), 4)   AS pct_yellow,
    max(filas) FILTER (WHERE tipo = 'green')                              AS green,
    round(max(100.0 * filas / total) FILTER (WHERE tipo = 'green'), 4)    AS pct_green
FROM largo
GROUP BY regla
ORDER BY regla;
```

- **Objetivo:** cuantificar valores imposibles o sospechosos con reglas simples.
- **Fuente:** ambos tipos, 2026.
- **Resultado:**

  | Regla | yellow | % yellow | green | % green |
  |-------|-------:|---------:|------:|--------:|
  | 01 inicio fuera de 2026 | 17 | 0.0001 | 14 | 0.0042 |
  | 02 fin antes del inicio | 10 | 0.0000 | 5 | 0.0015 |
  | 03 duracion cero | 371,673 | 1.2513 | 229 | 0.0679 |
  | 04 duracion mayor a 24 h | 263 | 0.0009 | 4 | 0.0012 |
  | 05 distancia cero | 952,231 | 3.2058 | 12,212 | 3.6225 |
  | 06 distancia mayor a 100 millas | 1,223 | 0.0041 | 72 | 0.0214 |
  | 07 tarifa negativa | 157,364 | 0.5298 | 999 | 0.2963 |
  | 08 total negativo | 161,835 | 0.5448 | 1,023 | 0.3034 |
  | 09 tarifa mayor a 1000 USD | 42 | 0.0001 | 1 | 0.0003 |
  | 10 cero pasajeros | 91,359 | 0.3076 | 4,527 | 1.3429 |
  | 11 mas de 6 pasajeros | 28 | 0.0001 | 99 | 0.0294 |
  | 12 zona desconocida o fuera de NYC (264/265) | 201,486 | 0.6783 | 5,886 | 1.7460 |

- **Decision / interpretacion:**
  - **Distancias extremas:** los viajes de mas de 300,000 millas duran 6-30
    minutos y cobran 19-44 USD; son errores del odometro, no viajes reales.
    Se excluiran distancias > 100 millas en analisis de distancia/velocidad.
  - **Montos negativos:** 118,584 de los 161,835 totales negativos de yellow
    (73%) tienen `payment_type` 3 (sin cargo) o 4 (disputa): son reversiones
    contables de un cobro. Se excluiran de analisis de ingresos por viaje,
    pero se documentaran por separado.
  - **Duracion o distancia cero:** probablemente viajes cancelados o registros
    de prueba. Se excluiran de analisis de duracion, distancia y velocidad.
  - **Cero pasajeros:** el conductor no registro pasajeros; se trataran como
    desconocido, igual que NULL.
  - **Zonas 264/265:** se conservan para conteos generales, pero se excluyen de
    analisis geograficos.
  - Ninguna regla afecta mas del ~3.6% de las filas, asi que el conjunto es
    utilizable. **No se elimina ni modifica nada en `data/raw/`**: las reglas
    se aplicaran como filtros explicitos y documentados en cada analisis
    posterior.

### Registros duplicados

**Consultas:** [`14_duplicados.sql`](../sql/03_exploracion/14_duplicados.sql) y [`15_detalle_duplicados.sql`](../sql/03_exploracion/15_detalle_duplicados.sql)

```sql
-- 14: conteo
SELECT 'yellow' AS tipo, count(*) AS filas, count(DISTINCT hash(t)) AS filas_distintas,
       count(*) - count(DISTINCT hash(t)) AS duplicados
FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
UNION ALL
SELECT 'green', count(*), count(DISTINCT hash(t)), count(*) - count(DISTINCT hash(t))
FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true) AS t;

-- 15: detalle (abreviado)
WITH hashes_repetidos AS (
    SELECT hash(t) AS h
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
    GROUP BY h HAVING count(*) > 1
),
filas_repetidas AS (
    SELECT hash(t) AS h, t
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
    WHERE hash(t) IN (SELECT h FROM hashes_repetidos)
)
SELECT count(*) AS repeticiones, count(DISTINCT t) AS versiones_distintas,
       any_value(t).tpep_pickup_datetime AS inicio, ...
FROM filas_repetidas
GROUP BY h
ORDER BY inicio;
```

- **Objetivo:** detectar filas identicas en todas sus columnas.
- **Fuente:** ambos tipos, 2026.
- **Resultado:**

  | tipo | filas | filas distintas | duplicados |
  |------|------:|----------------:|-----------:|
  | yellow | 29,703,355 | 29,703,348 | **7** |
  | green | 337,114 | 337,114 | 0 |

  Las 7 parejas duplicadas (`versiones_distintas = 1`, es decir, son copias
  exactas y no colisiones de hash) son todas de `VendorID = 1`, entre el 20 y
  el 23 de agosto, con inicio = fin, distancia 0, total 0, zona 264 y
  `payment_type = 4` (disputa).

- **Decision:** la duplicacion es despreciable (7 de 29.7 M) y las filas
  duplicadas ya quedan excluidas por las reglas de duracion cero y zona
  desconocida. No se deduplica.
  **Sobre el metodo:** `SELECT DISTINCT *` sobre 30 M filas y 21 columnas fallo
  por memoria (`Cannot allocate memory`), al igual que agrupar las filas
  completas. Se resolvio comparando un hash de 64 bits por fila (8 bytes) y
  recuperando solo las filas sospechosas, verificandolas despues columna a
  columna con `count(DISTINCT t)`.

### Consistencia de `total_amount` con sus componentes

**Consulta:** [`16_consistencia_total.sql`](../sql/03_exploracion/16_consistencia_total.sql)

```sql
WITH diferencias AS (
    SELECT payment_type,
        round(total_amount - (fare_amount + extra + mta_tax + tip_amount
              + tolls_amount + improvement_surcharge
              + coalesce(congestion_surcharge, 0) + coalesce(Airport_fee, 0)
              + coalesce(cbd_congestion_fee, 0)), 2) AS diferencia
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
)
SELECT payment_type, diferencia, count(*) AS filas,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct_del_total
FROM diferencias
GROUP BY payment_type, diferencia
QUALIFY row_number() OVER (ORDER BY count(*) DESC) <= 10
ORDER BY filas DESC;
```

- **Objetivo:** verificar si `total_amount` es la suma de sus componentes.
- **Fuente:** `data/raw/yellow/2026/*.parquet`.
- **Resultado (10 combinaciones mas frecuentes):**

  | payment_type | diferencia | filas | % del total |
  |---:|---:|---:|---:|
  | 1 | 0.00 | 15,469,459 | 52.08 |
  | 0 | **+2.50** | 4,747,991 | 15.98 |
  | 1 | **-3.25** | 2,440,215 | 8.22 |
  | 2 | 0.00 | 2,269,576 | 7.64 |
  | 0 | 0.00 | 812,122 | 2.73 |
  | 1 | **-2.50** | 646,881 | 2.18 |
  | 2 | **-3.25** | 294,687 | 0.99 |
  | 4 | 0.00 | 209,877 | 0.71 |
  | 0 | +5.50 | 112,169 | 0.38 |
  | 0 | +3.50 | 86,542 | 0.29 |

- **Decision:** ~37% de las filas no cuadran, pero las diferencias son
  cantidades fijas que coinciden con recargos: +2.50 en Flex Fare (el
  `congestion_surcharge` es NULL pero si se cobro) y -3.25 = 2.50 + 0.75 o
  -2.50 en pagos con tarjeta/efectivo (el recargo de congestion y/o la tarifa
  CBD estan incluidos tambien en `extra`, es decir, contados dos veces). Por
  lo tanto **`total_amount` es el campo confiable** y los componentes no deben
  sumarse para reconstruirlo. Los analisis de ingresos usaran `total_amount`
  (o `fare_amount` para la tarifa base) y no la suma de recargos.

### Resumen de problemas de calidad identificados

| # | Problema | Magnitud | Tratamiento propuesto |
|---|----------|----------|-----------------------|
| 1 | Cambio de esquema (`request_source` desde 2026-06) | 3 de 8 archivos | `union_by_name = true` |
| 2 | Nombres de columnas distintos entre yellow y green | 7 columnas | Alias comunes al combinar |
| 3 | Nulos estructurales en Flex Fare / payment_type nulo | 26% yellow, 14.5% green | Categoria aparte; no imputar |
| 4 | `RatecodeID = 99` (desconocido) | 2.6% yellow | Tratar como NULL |
| 5 | Fechas de otros anios / fuera del mes del archivo | 244 filas | Filtrar por fecha del viaje |
| 6 | Fin antes del inicio, duracion cero o > 24 h | ~1.25% yellow | Excluir en analisis de duracion |
| 7 | Distancia cero o > 100 millas (hasta 328,522) | ~3.2% yellow | Excluir en analisis de distancia |
| 8 | Montos negativos (reversiones) | ~0.5% | Excluir de ingresos por viaje |
| 9 | Cero pasajeros | 0.3% yellow, 1.3% green | Tratar como desconocido |
| 10 | Zonas 264/265 (desconocida / fuera de NYC) | 0.7% yellow, 1.7% green | Excluir de analisis geograficos |
| 11 | Duplicados exactos | 7 filas | Sin accion (ya excluidos por 6 y 10) |
| 12 | `total_amount` no es la suma de sus componentes | ~37% yellow | Usar `total_amount` directamente |
| 13 | `ehail_fee` siempre NULL (green) | 100% | Ignorar la columna |
| 14 | `request_source` sin documentacion oficial | 90% NULL | Usar con cautela |
| 15 | Montos `DOUBLE` (no `DECIMAL`) | todas | Redondear a 2 decimales al comparar |

## 3.7 Uso directo de los archivos Parquet

Todas las consultas anteriores se ejecutaron sobre una conexion DuckDB **en
memoria** (`duckdb.connect()` sin archivo `.duckdb`) y leen los Parquet en cada
ejecucion; no se uso `CREATE TABLE`, `COPY` ni `INSERT`. Se usaron tres
funciones:

| Funcion | Que lee | Usada en |
|---------|---------|----------|
| `parquet_file_metadata(glob)` | Solo el pie de cada archivo (filas, row groups, tamanio) | 01, 02 |
| `parquet_schema(glob)` | Solo el esquema guardado en el pie | 04, 05 |
| `read_parquet(glob, union_by_name, filename)` | Los datos, solo de las columnas usadas | 03, 06-16 |

## 3.9 Que significa consultar directamente un archivo Parquet

**Consultar directamente** un Parquet significa usar el archivo como si fuera
una tabla (`FROM read_parquet('data/raw/yellow/2026/*.parquet')`) sin cargarlo
antes a una base de datos ni a la memoria de un programa. El motor lee del
archivo solo lo que la consulta necesita, en el momento de ejecutarla.

Esto es eficiente por la forma en que esta organizado Parquet:

1. **Formato columnar.** Los valores de cada columna se guardan juntos y
   comprimidos. Si la consulta usa `trip_distance`, DuckDB lee y descomprime
   solo esa columna (1 de 21) y no las demas (*projection pushdown*).
2. **Metadatos en el pie.** Cada archivo guarda su esquema, el numero de filas
   y estadisticas (minimo/maximo) por *row group*. Por eso se pueden contar
   filas o listar columnas sin leer datos (consultas 01, 02, 04 y 05: menos
   de 0.4 s cada una), y DuckDB puede **saltarse row groups completos** cuyo rango no
   cumple un filtro (*filter pushdown*).
3. **Globs y multiples archivos.** Un solo `read_parquet('.../*.parquet')`
   consulta todos los meses como una tabla y los lee en paralelo. Cuando la TLC
   publica un mes nuevo, basta con descargarlo; las consultas lo incluyen sin
   cambios.

### Evidencia medida (notebook, seccion 3.9)

**Plan de ejecucion** de
`SELECT avg(trip_distance) ... WHERE tpep_pickup_datetime >= '2026-07-01' AND payment_type = 2`:

```text
READ_PARQUET
   Projections: trip_distance
   Filters:     tpep_pickup_datetime >= '2026-07-01 00:00:00'
                payment_type = 2
```

Las columnas y los filtros se resuelven **dentro del lector Parquet**, antes de
que los datos lleguen al resto de la consulta.

**Conteo de filas (30,040,469):** `parquet_file_metadata` 0.07 s,
`count(*)` 0.19 s (DuckDB tambien lo responde con los conteos de los row
groups) y `sum(total_amount)`, que si lee una columna completa, 0.43 s.

**DuckDB directo vs. cargar en memoria con pandas** (cada uno en un proceso
nuevo; memoria = pico de memoria residente):

| Estrategia | Filas | Tiempo | Memoria maxima |
|------------|------:|-------:|---------------:|
| DuckDB: `avg(trip_distance)` sobre los 8 meses, directo del Parquet | 29.7 M | 0.39 s | **93 MiB** |
| pandas: `read_parquet` de **un** mes completo y `.mean()` | 3.7 M | 0.91 s | **1,437 MiB** |

pandas necesita ~15 veces mas memoria para procesar **un octavo** de los datos.
El DataFrame de un solo mes ocupa 528 MiB; los 8 meses ocuparian ~4.2 GB solo
en el DataFrame, con picos de lectura bastante mayores, cerca o por encima de
los ~7.6 GB asignados a Docker en este equipo. DuckDB los procesa con menos
de 100 MiB porque nunca materializa la tabla completa.

### Por que es util cuando el volumen es grande

- **El volumen de datos no esta limitado por la RAM**: solo se leen las
  columnas y row groups necesarios, en bloques, y en paralelo.
- **No hay paso de carga (ETL)**: no se duplica el almacenamiento en una base de
  datos ni hay que esperar una importacion antes de empezar a explorar.
- **Siempre se consulta la version vigente de los datos**: al agregar o
  reemplazar un archivo mensual, la siguiente consulta ya lo usa.
- **No requiere un servidor de base de datos**: DuckDB es una libreria
  embebida en el proceso de Python.
- **Limitaciones:** cada consulta vuelve a leer y descomprimir los archivos, y
  las operaciones que necesitan todas las columnas de todas las filas
  (`SELECT DISTINCT *`, agrupar filas completas) siguen siendo costosas y
  pueden agotar la memoria, como ocurrio en la consulta de duplicados. Para
  consultas repetidas sobre el mismo subconjunto puede convenir materializar
  una tabla, lo que se compara en el Ejercicio 6.
