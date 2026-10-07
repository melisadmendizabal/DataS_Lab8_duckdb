-- Ejercicio 3.3 - Columnas presentes en los archivos
-- Objetivo: listar las columnas de cada tipo de taxi e indicar en cuantos de
--           los archivos mensuales aparece cada una (detecta cambios de esquema).
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     parquet_schema() lee solo los metadatos. La fila raiz 'schema'
--           (num_children no nulo) no es una columna y se excluye.
WITH esquema AS (
    SELECT
        split_part(file_name, '/', 3)  AS tipo,
        file_name,
        name                            AS columna,
        column_id
    FROM parquet_schema('data/raw/*/2026/*.parquet')
    WHERE num_children IS NULL
)
SELECT
    columna,
    min(column_id) FILTER (WHERE tipo = 'yellow')                 AS posicion_yellow,
    count(DISTINCT file_name) FILTER (WHERE tipo = 'yellow')      AS archivos_yellow,
    min(column_id) FILTER (WHERE tipo = 'green')                  AS posicion_green,
    count(DISTINCT file_name) FILTER (WHERE tipo = 'green')       AS archivos_green
FROM esquema
GROUP BY columna
ORDER BY coalesce(posicion_yellow, posicion_green), posicion_green;
