-- Ejercicio 3.6 - Valores de las columnas categoricas
-- Objetivo: comparar los codigos presentes en las columnas categoricas con
--           los definidos en el diccionario de datos de la TLC para detectar
--           codigos no documentados.
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Diccionario TLC:
--   VendorID:     1 Creative Mobile Technologies, 2 Curb Mobility,
--                 6 Myle Technologies, 7 Helix
--   RatecodeID:   1 estandar, 2 JFK, 3 Newark, 4 Nassau/Westchester,
--                 5 negociada, 6 viaje grupal, 99 nulo/desconocido
--   payment_type: 0 Flex Fare, 1 tarjeta, 2 efectivo, 3 sin cargo,
--                 4 disputa, 5 desconocido, 6 viaje anulado
--   trip_type:    1 en la calle, 2 despacho (solo green)
WITH viajes AS (
    SELECT 'yellow' AS tipo,
           VendorID::VARCHAR      AS VendorID,
           RatecodeID::VARCHAR    AS RatecodeID,
           payment_type::VARCHAR  AS payment_type,
           store_and_fwd_flag,
           NULL::VARCHAR          AS trip_type,
           request_source
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
    UNION ALL
    SELECT 'green',
           VendorID::VARCHAR,
           RatecodeID::VARCHAR,
           payment_type::VARCHAR,
           store_and_fwd_flag,
           trip_type::VARCHAR,
           request_source
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true)
),
largo AS (
    FROM viajes
    UNPIVOT INCLUDE NULLS (valor FOR columna IN
        (VendorID, RatecodeID, payment_type, store_and_fwd_flag, trip_type, request_source))
)
SELECT
    columna,
    coalesce(valor, 'NULL')                          AS valor,
    count(*) FILTER (WHERE tipo = 'yellow')          AS yellow,
    count(*) FILTER (WHERE tipo = 'green')           AS green
FROM largo
WHERE NOT (columna = 'trip_type' AND tipo = 'yellow')
GROUP BY ALL
ORDER BY columna, valor;
