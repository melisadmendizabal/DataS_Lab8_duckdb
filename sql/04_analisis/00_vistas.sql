-- Ejercicio 4 - Vistas base del analisis exploratorio
-- Objetivo: definir en un solo lugar (y dejar registradas) las
--           transformaciones que usan todas las consultas del ejercicio:
--             * viajes:          yellow + green con nombres de columna comunes
--             * viajes_validos:  viajes sin los registros invalidos detectados
--                                en el Ejercicio 3
--             * zonas:           tabla de zonas de la TLC
--             * metodos_pago:    nombres de los codigos de payment_type
-- Fuente:   data/raw/yellow/<periodo>.parquet, data/raw/green/<periodo>.parquet,
--           data/raw/zones/taxi_zone_lookup.csv
-- Nota:     son vistas TEMPORALES: no copian datos; cada consulta que las usa
--           vuelve a leer los Parquet. Este archivo debe ejecutarse antes que
--           los demas (run_sql.py y el notebook lo hacen por orden de nombre).
--
-- Alcance (Ejercicio 5): la variable 'periodo' es el patron de archivos
-- relativo a data/raw/<tipo>/. Por defecto '*/*' = todos los anios
-- descargados, de modo que un anio nuevo se incorpora sin editar este
-- archivo. Para limitarlo, definala ANTES de ejecutar este archivo:
--   SET VARIABLE periodo = '2026/*';            -- solo 2026 (Ejercicio 4)
--   SET VARIABLE periodo = '2026/*2026-01';     -- un solo mes
-- (run_sql.py --periodo '2026/*' hace lo mismo). Las vistas leen la variable
-- cada vez que se consultan.
SET VARIABLE periodo = coalesce(getvariable('periodo'), '*/*');

-- Viajes de ambos tipos con columnas unificadas (en espanol).
-- yellow no tiene trip_type; green no tiene Airport_fee.
-- Columnas que no existen en todos los anios: cbd_congestion_fee (desde 2025)
-- y request_source (desde 2026-06). Se unen POR NOMBRE con una relacion vacia
-- que las declara, para que la vista no falle si el periodo elegido no las
-- tiene (p. ej. solo 2024); en ese caso quedan en NULL.
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
    regexp_extract(filename, '(\d{4}-\d{2})', 1)          AS mes_archivo,
    CAST(regexp_extract(filename, '(\d{4})-\d{2}', 1) AS INTEGER) AS anio
FROM (
    FROM read_parquet('data/raw/yellow/' || getvariable('periodo') || '.parquet',
                      union_by_name = true, filename = true)
    UNION ALL BY NAME
    SELECT NULL::DOUBLE AS cbd_congestion_fee, NULL::VARCHAR AS request_source WHERE false
)
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
    regexp_extract(filename, '(\d{4}-\d{2})', 1),
    CAST(regexp_extract(filename, '(\d{4})-\d{2}', 1) AS INTEGER)
FROM (
    FROM read_parquet('data/raw/green/' || getvariable('periodo') || '.parquet',
                      union_by_name = true, filename = true)
    UNION ALL BY NAME
    SELECT NULL::DOUBLE AS cbd_congestion_fee, NULL::VARCHAR AS request_source WHERE false
);

-- Viajes validos: se excluyen los registros imposibles identificados en el
-- Ejercicio 3 (consulta 13). NO se excluyen los nulos estructurales de
-- Flex Fare / payment_type nulo ni las zonas 264/265: cada consulta decide
-- si los necesita. La fecha se compara con el anio del archivo (no con un
-- anio fijo) para que la regla sirva con cualquier anio incorporado.
CREATE OR REPLACE TEMP VIEW viajes_validos AS
SELECT *
FROM viajes
WHERE year(inicio) = anio                     -- fechas de otros anios (2001, 2008, ...)
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
    t.anio,
    t.viajes,
    v.viajes                                    AS viajes_validos,
    round(100.0 * v.viajes / t.viajes, 2)       AS pct_validos
FROM (SELECT tipo, anio, count(*) AS viajes FROM viajes GROUP BY ALL) AS t
JOIN (SELECT tipo, anio, count(*) AS viajes FROM viajes_validos GROUP BY ALL) AS v USING (tipo, anio)
ORDER BY t.tipo DESC, t.anio;
