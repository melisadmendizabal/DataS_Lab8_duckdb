-- Ejercicio 5.5 - Archivos incorporados por tipo de taxi y anio
-- Objetivo: verificar que los archivos de 2024 se agregaron junto a los de
--           2026 (que se conservan): cantidad de archivos, primer y ultimo
--           mes, meses faltantes antes del ultimo publicado, filas y tamanio.
-- Fuente:   data/raw/*/*/*.parquet (todos los archivos descargados)
-- Nota:     solo lee los metadatos (pie) de cada Parquet. Se esperan 12
--           archivos por tipo para 2024 y enero-agosto para 2026 (ultimo mes
--           publicado por la TLC al 07-oct-2026).
WITH archivos AS (
    SELECT
        split_part(file_name, '/', 3)                                   AS tipo,
        CAST(split_part(file_name, '/', 4) AS INTEGER)                  AS anio,
        CAST(regexp_extract(file_name, '\d{4}-(\d{2})', 1) AS INTEGER)  AS mes,
        num_rows,
        file_size_bytes
    FROM parquet_file_metadata('data/raw/*/*/*.parquet')
)
SELECT
    tipo,
    anio,
    count(*)                                                     AS archivos,
    min(mes)                                                     AS primer_mes,
    max(mes)                                                     AS ultimo_mes,
    list_filter(range(1, max(mes) + 1), m -> NOT list_contains(list(mes), m))
                                                                 AS meses_faltantes,
    sum(num_rows)                                                AS filas,
    round(sum(file_size_bytes) / 1024 ^ 2, 1)                    AS tamanio_mib
FROM archivos
GROUP BY tipo, anio
ORDER BY tipo DESC, anio;
