-- Ejercicio 3.2 - Cantidad de registros (desde los metadatos Parquet)
-- Objetivo: obtener la cantidad de filas de cada archivo leyendo solo los
--           metadatos del pie Parquet, sin recorrer los datos.
-- Fuente:   data/raw/*/2026/*.parquet
SELECT
    split_part(file_name, '/', 3)                        AS tipo,
    regexp_extract(file_name, '(\d{4}-\d{2})', 1)        AS mes,
    num_rows                                             AS filas,
    num_row_groups                                       AS row_groups,
    round(file_size_bytes / 1024 ^ 2, 1)                 AS tamanio_mib,
    created_by
FROM parquet_file_metadata('data/raw/*/2026/*.parquet')
ORDER BY tipo DESC, mes;
