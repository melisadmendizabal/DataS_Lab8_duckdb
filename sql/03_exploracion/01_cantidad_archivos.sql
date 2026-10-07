-- Ejercicio 3.1 - Cantidad de archivos disponibles
-- Objetivo: contar los archivos Parquet descargados por tipo de taxi y anio,
--           junto con su tamanio en disco.
-- Fuente:   data/raw/*/*/*.parquet (todos los archivos descargados)
-- Nota:     parquet_file_metadata() solo lee el pie (footer) de cada archivo,
--           no los datos. GROUP BY ROLLUP agrega una fila de total general.
SELECT
    coalesce(split_part(file_name, '/', 3), 'TOTAL')            AS tipo,
    coalesce(split_part(file_name, '/', 4), '')                 AS anio,
    count(*)                                                    AS archivos,
    round(sum(file_size_bytes) / 1024 ^ 2, 1)                   AS tamanio_mib
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ROLLUP ((split_part(file_name, '/', 3), split_part(file_name, '/', 4)))
ORDER BY tipo = 'TOTAL', tipo DESC, anio;
