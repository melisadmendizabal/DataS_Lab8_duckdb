-- Ejercicio 3.4 - Tipos de datos de las columnas
-- Objetivo: obtener, para cada columna, el tipo fisico Parquet, el tipo
--           convertido (logico) y el tipo con el que DuckDB la interpreta, y
--           verificar que el tipo sea el mismo en todos los archivos (si una
--           columna cambiara de tipo apareceria en dos filas).
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
SELECT
    split_part(file_name, '/', 3)            AS tipo,
    name                                     AS columna,
    type                                     AS tipo_parquet,
    converted_type                           AS tipo_convertido,
    duckdb_type                              AS tipo_duckdb,
    count(DISTINCT file_name)                AS archivos
FROM parquet_schema('data/raw/*/2026/*.parquet')
WHERE num_children IS NULL
GROUP BY ALL
ORDER BY tipo DESC, min(column_id);
