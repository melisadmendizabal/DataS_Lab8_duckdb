-- Ejercicio 4 - Vistas base del analisis exploratorio
-- Objetivo: definir en un solo lugar (y dejar registradas) las
--           transformaciones que usan todas las consultas del ejercicio:
--             * viajes:          yellow + green con nombres de columna comunes
--             * viajes_validos:  viajes sin los registros invalidos detectados
--                                en el Ejercicio 3
--             * zonas:           tabla de zonas de la TLC
--             * metodos_pago:    nombres de los codigos de payment_type
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet,
--           data/raw/zones/taxi_zone_lookup.csv
-- Nota:     son vistas TEMPORALES: no copian datos; cada consulta que las usa
--           vuelve a leer los Parquet. Este archivo debe ejecutarse antes que
--           los demas (run_sql.py y el notebook lo hacen por orden de nombre).

-- Viajes de ambos tipos con columnas unificadas (en espanol).
-- yellow no tiene trip_type; green no tiene Airport_fee.
CREATE OR REPLACE TEMP VIEW viajes AS
SELECT
    'yellow'                                              AS tipo,
    VendorID                                              AS proveedor,
    tpep_pickup_datetime                                  AS inicio,
    tpep_dropoff_datetime                                 AS fin,
    date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS duracion_min,
    passenger_count                                       AS pasajeros,
    trip_distance                                         AS distancia,
    RatecodeID                                            AS codigo_tarifa,
    PULocationID                                          AS origen,
    DOLocationID                                          AS destino,
    payment_type                                          AS tipo_pago,
    fare_amount                                           AS tarifa,
    tip_amount                                            AS propina,
    tolls_amount                                          AS peajes,
    total_amount                                          AS total,
    Airport_fee                                           AS cargo_aeropuerto,
    cbd_congestion_fee                                    AS cargo_cbd,
    NULL::BIGINT                                          AS tipo_viaje,
    request_source                                        AS origen_solicitud,
    regexp_extract(filename, '(\d{4}-\d{2})', 1)          AS mes_archivo
FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true, filename = true)
UNION ALL
SELECT
    'green',
    VendorID,
    lpep_pickup_datetime,
    lpep_dropoff_datetime,
    date_diff('second', lpep_pickup_datetime, lpep_dropoff_datetime) / 60.0,
    passenger_count,
    trip_distance,
    RatecodeID,
    PULocationID,
    DOLocationID,
    payment_type,
    fare_amount,
    tip_amount,
    tolls_amount,
    total_amount,
    NULL::DOUBLE,
    cbd_congestion_fee,
    trip_type,
    request_source,
    regexp_extract(filename, '(\d{4}-\d{2})', 1)
FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true, filename = true);

-- Viajes validos: se excluyen los registros imposibles identificados en el
-- Ejercicio 3 (consulta 13). NO se excluyen los nulos estructurales de
-- Flex Fare / payment_type nulo ni las zonas 264/265: cada consulta decide
-- si los necesita.
CREATE OR REPLACE TEMP VIEW viajes_validos AS
SELECT *
FROM viajes
WHERE year(inicio) = 2026                     -- fechas de otros anios (2001, 2008, ...)
  AND fin > inicio                            -- duracion cero o negativa
  AND fin - inicio <= INTERVAL 24 HOUR        -- duracion imposible
  AND distancia > 0                           -- distancia cero
  AND distancia <= 100                        -- errores de odometro (hasta 328,522 mi)
  AND tarifa >= 0                             -- reversiones / disputas
  AND total >= 0;

-- Tabla de zonas (LocationID -> distrito y zona).
CREATE OR REPLACE TEMP VIEW zonas AS
SELECT
    LocationID    AS id_zona,
    Borough       AS distrito,
    Zone          AS zona,
    service_zone  AS zona_servicio
FROM read_csv('data/raw/zones/taxi_zone_lookup.csv', header = true);

-- Nombres de los codigos de payment_type segun el diccionario de la TLC.
-- En green el equivalente a Flex Fare llega con payment_type NULL (mismo
-- patron de nulos, ver Ejercicio 3, consulta 11).
CREATE OR REPLACE TEMP VIEW metodos_pago AS
SELECT * FROM (VALUES
    (0, 'Flex Fare'),
    (1, 'Tarjeta'),
    (2, 'Efectivo'),
    (3, 'Sin cargo'),
    (4, 'Disputa'),
    (5, 'Desconocido'),
    (6, 'Anulado')
) AS t(tipo_pago, metodo_pago);

-- Resumen: cuantos viajes quedan despues de la limpieza.
SELECT
    t.tipo,
    t.viajes,
    v.viajes                                    AS viajes_validos,
    round(100.0 * v.viajes / t.viajes, 2)       AS pct_validos
FROM (SELECT tipo, count(*) AS viajes FROM viajes GROUP BY tipo) AS t
JOIN (SELECT tipo, count(*) AS viajes FROM viajes_validos GROUP BY tipo) AS v USING (tipo)
ORDER BY t.tipo DESC;
