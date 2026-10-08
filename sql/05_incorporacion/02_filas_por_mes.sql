-- Ejercicio 5.5 - Filas por mes, 2024 frente a 2026
-- Objetivo: comparar mes a mes la cantidad de registros de cada archivo para
--           detectar archivos anomalos (vacios o con un volumen muy distinto
--           al del mismo mes en el otro anio).
-- Fuente:   data/raw/*/*/*.parquet (metadatos)
-- Nota:     NULL = archivo no publicado todavia (2026-09 en adelante). PIVOT
--           sin lista IN crea una columna por cada tipo y anio descargado.
WITH archivos AS (
    SELECT
        split_part(file_name, '/', 3) || '_' || split_part(file_name, '/', 4) AS serie,
        CAST(regexp_extract(file_name, '\d{4}-(\d{2})', 1) AS INTEGER)       AS mes,
        num_rows
    FROM parquet_file_metadata('data/raw/*/*/*.parquet')
)
PIVOT archivos
ON serie
USING sum(num_rows)
GROUP BY mes
ORDER BY mes;
