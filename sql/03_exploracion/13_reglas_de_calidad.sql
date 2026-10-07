-- Ejercicio 3.6 - Reglas de calidad
-- Objetivo: cuantificar registros con valores imposibles o sospechosos segun
--           reglas de negocio simples.
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     las reglas NO son excluyentes (una fila puede romper varias).
--           Los LocationID 264 y 265 corresponden a zona desconocida / fuera
--           de NYC en la tabla de zonas de la TLC.
WITH viajes AS (
    SELECT 'yellow' AS tipo, tpep_pickup_datetime AS inicio,
           tpep_dropoff_datetime AS fin, passenger_count, trip_distance,
           fare_amount, total_amount, PULocationID, DOLocationID
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green', lpep_pickup_datetime, lpep_dropoff_datetime,
           passenger_count, trip_distance, fare_amount, total_amount,
           PULocationID, DOLocationID
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
),
conteos AS (
    SELECT
        tipo,
        count(*)                                                AS total,
        count(*) FILTER (WHERE year(inicio) <> 2026)            AS "01 inicio fuera de 2026",
        count(*) FILTER (WHERE fin < inicio)                    AS "02 fin antes del inicio",
        count(*) FILTER (WHERE fin = inicio)                    AS "03 duracion cero",
        count(*) FILTER (WHERE fin - inicio > INTERVAL 24 HOUR) AS "04 duracion mayor a 24 h",
        count(*) FILTER (WHERE trip_distance = 0)               AS "05 distancia cero",
        count(*) FILTER (WHERE trip_distance > 100)             AS "06 distancia mayor a 100 millas",
        count(*) FILTER (WHERE fare_amount < 0)                 AS "07 tarifa negativa",
        count(*) FILTER (WHERE total_amount < 0)                AS "08 total negativo",
        count(*) FILTER (WHERE fare_amount > 1000)              AS "09 tarifa mayor a 1000 USD",
        count(*) FILTER (WHERE passenger_count = 0)             AS "10 cero pasajeros",
        count(*) FILTER (WHERE passenger_count > 6)             AS "11 mas de 6 pasajeros",
        count(*) FILTER (WHERE PULocationID IN (264, 265)
                            OR DOLocationID IN (264, 265))      AS "12 zona desconocida o fuera de NYC"
    FROM viajes
    GROUP BY tipo
),
largo AS (
    UNPIVOT conteos ON COLUMNS(* EXCLUDE (tipo, total)) INTO NAME regla VALUE filas
)
SELECT
    regla,
    max(filas) FILTER (WHERE tipo = 'yellow')                             AS yellow,
    round(max(100.0 * filas / total) FILTER (WHERE tipo = 'yellow'), 4)   AS pct_yellow,
    max(filas) FILTER (WHERE tipo = 'green')                              AS green,
    round(max(100.0 * filas / total) FILTER (WHERE tipo = 'green'), 4)    AS pct_green
FROM largo
GROUP BY regla
ORDER BY regla;
