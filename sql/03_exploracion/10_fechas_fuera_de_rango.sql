-- Ejercicio 3.6 - Fechas fuera del periodo esperado
-- Objetivo: verificar que la fecha de inicio de cada viaje pertenezca al mes
--           del archivo que lo contiene.
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     yellow usa tpep_* y green lpep_*; se unifican como 'inicio'.
WITH viajes AS (
    SELECT 'yellow' AS tipo, filename, tpep_pickup_datetime AS inicio
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true, filename = true)
    UNION ALL
    SELECT 'green', filename, lpep_pickup_datetime
    FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true, filename = true)
),
clasificados AS (
    SELECT
        tipo,
        inicio,
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
