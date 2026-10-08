-- Ejercicio 5.5 / 5.7 - Cambios de esquema entre anios
-- Objetivo: listar las columnas que NO estan en todos los archivos de un
--           tipo de taxi, o que cambian de tipo de dato, indicando en cuantos
--           archivos de cada anio aparecen. Son las columnas que pueden romper
--           una consulta que lea varios anios a la vez.
-- Fuente:   data/raw/*/*/*.parquet (parquet_schema, solo metadatos)
-- Nota:     las columnas presentes en todos los archivos con un solo tipo de
--           dato no aparecen en el resultado.
WITH esquema AS (
    SELECT
        split_part(file_name, '/', 3)                   AS tipo,
        CAST(split_part(file_name, '/', 4) AS INTEGER)  AS anio,
        file_name,
        name                                            AS columna,
        duckdb_type
    FROM parquet_schema('data/raw/*/*/*.parquet')
    WHERE num_children IS NULL
),
archivos AS (
    -- archivos de cada tipo y anio (denominador)
    SELECT tipo, anio, count(DISTINCT file_name) AS total
    FROM esquema
    GROUP BY ALL
),
presencia AS (
    -- en cuantos archivos de cada anio aparece cada columna (0 si en ninguno)
    SELECT
        a.tipo,
        c.columna,
        a.anio,
        a.total,
        count(DISTINCT e.file_name)                       AS archivos
    FROM archivos AS a
    JOIN (SELECT DISTINCT tipo, columna FROM esquema) AS c USING (tipo)
    LEFT JOIN esquema AS e ON e.tipo = a.tipo AND e.anio = a.anio AND e.columna = c.columna
    GROUP BY ALL
),
por_columna AS (
    SELECT
        p.tipo,
        p.columna,
        sum(p.archivos)                                                         AS archivos,
        sum(p.total)                                                            AS total,
        string_agg(p.anio || ': ' || p.archivos || ' de ' || p.total, ' | ' ORDER BY p.anio)
                                                                                AS archivos_por_anio
    FROM presencia AS p
    GROUP BY ALL
),
tipos AS (
    SELECT
        tipo,
        columna,
        string_agg(DISTINCT duckdb_type, ', ')                                 AS tipos_de_dato,
        count(DISTINCT duckdb_type)                                            AS cantidad_tipos,
        min(regexp_extract(file_name, '(\d{4}-\d{2})', 1))                     AS aparece_desde
    FROM esquema
    GROUP BY ALL
)
SELECT
    c.tipo,
    c.columna,
    t.tipos_de_dato,
    c.archivos_por_anio,
    t.aparece_desde
FROM por_columna AS c
JOIN tipos AS t USING (tipo, columna)
WHERE c.archivos < c.total OR t.cantidad_tipos > 1
ORDER BY c.tipo DESC, c.columna;
