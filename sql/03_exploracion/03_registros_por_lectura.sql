-- Ejercicio 3.2 - Cantidad de registros (recorriendo los datos)
-- Objetivo: contar los registros leyendo los archivos con read_parquet y
--           confirmar que coinciden con los metadatos (consulta 02).
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     union_by_name = true es necesario porque desde 2026-06 los
--           archivos tienen una columna adicional (request_source).
SELECT
    coalesce(tipo, 'TOTAL')  AS tipo,
    count(*)                 AS archivos,
    sum(filas)               AS registros
FROM (
    SELECT split_part(filename, '/', 3) AS tipo, filename, count(*) AS filas
    FROM read_parquet('data/raw/*/2026/*.parquet', union_by_name = true, filename = true)
    GROUP BY ALL
)
GROUP BY ROLLUP (tipo)
ORDER BY tipo = 'TOTAL', tipo DESC;
