-- Ejercicio 3.6 - Patron de valores nulos
-- Objetivo: explicar los nulos que muestra el perfil (08/09) en
--           passenger_count, RatecodeID, store_and_fwd_flag y
--           congestion_surcharge: verificar si ocurren en las mismas filas y
--           si dependen del tipo de pago.
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     segun el diccionario de la TLC, payment_type 0 = "Flex Fare trip".
WITH viajes AS (
    SELECT 'yellow' AS tipo, payment_type, passenger_count, RatecodeID,
           store_and_fwd_flag, congestion_surcharge
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green', payment_type, passenger_count, RatecodeID,
           store_and_fwd_flag, congestion_surcharge
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
)
SELECT
    tipo,
    payment_type,
    count(*)                                                AS filas,
    count(*) FILTER (WHERE passenger_count IS NULL)         AS pasajeros_nulos,
    count(*) FILTER (WHERE RatecodeID IS NULL)              AS ratecode_nulos,
    count(*) FILTER (WHERE store_and_fwd_flag IS NULL)      AS flag_nulos,
    count(*) FILTER (WHERE congestion_surcharge IS NULL)    AS congestion_nulos
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, payment_type NULLS LAST;
