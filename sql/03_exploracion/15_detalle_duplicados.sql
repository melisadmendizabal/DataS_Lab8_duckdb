-- Ejercicio 3.6 - Detalle de los registros duplicados (taxis amarillos)
-- Objetivo: mostrar las filas repetidas encontradas en la consulta 14 y
--           confirmar que son duplicados reales y no colisiones de hash
--           (count(DISTINCT t) compara la fila completa, columna a columna).
-- Fuente:   data/raw/yellow/2026/*.parquet
-- Nota:     agrupar las ~30 M filas completas agota la memoria; primero se
--           buscan solo los hashes repetidos (8 bytes por fila) y despues se
--           recuperan unicamente esas filas con un SEMI JOIN.
WITH hashes_repetidos AS (
    SELECT hash(t) AS h
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
    GROUP BY h
    HAVING count(*) > 1
),
filas_repetidas AS (
    SELECT hash(t) AS h, t
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
    WHERE hash(t) IN (SELECT h FROM hashes_repetidos)
)
SELECT
    count(*)                              AS repeticiones,
    count(DISTINCT t)                     AS versiones_distintas,
    any_value(t).VendorID                 AS VendorID,
    any_value(t).tpep_pickup_datetime     AS inicio,
    any_value(t).tpep_dropoff_datetime    AS fin,
    any_value(t).PULocationID             AS origen,
    any_value(t).DOLocationID             AS destino,
    any_value(t).trip_distance            AS distancia,
    any_value(t).total_amount             AS total,
    any_value(t).payment_type             AS payment_type
FROM filas_repetidas
GROUP BY h
ORDER BY inicio;
