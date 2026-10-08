-- Ejercicio 5.6 - Lectura conjunta de 2024 y 2026
-- Objetivo: comprobar que DuckDB puede leer en una sola consulta todos los
--           archivos de ambos anios, y que la cantidad de filas leidas
--           coincide exactamente con la de los metadatos (ninguna fila se
--           pierde ni se duplica al unir los anios).
-- Fuente:   data/raw/yellow/*/*.parquet, data/raw/green/*/*.parquet
-- Nota:     union_by_name = true es obligatorio con varios anios: 2024 no
--           tiene cbd_congestion_fee y solo 2026-06+ tiene request_source.
--           Sin el, DuckDB toma el esquema del PRIMER archivo (2024-01): la
--           columna cbd_congestion_fee "no existe" y la consulta falla.
WITH leidos AS (
    SELECT
        'yellow'                                                        AS tipo,
        CAST(regexp_extract(filename, '(\d{4})-\d{2}', 1) AS INTEGER)   AS anio,
        count(*)                                                        AS filas_leidas,
        count(cbd_congestion_fee)                                       AS con_cargo_cbd,
        min(tpep_pickup_datetime)                                       AS primer_inicio,
        max(tpep_pickup_datetime)                                       AS ultimo_inicio
    FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true, filename = true)
    GROUP BY anio
    UNION ALL
    SELECT
        'green',
        CAST(regexp_extract(filename, '(\d{4})-\d{2}', 1) AS INTEGER),
        count(*),
        count(cbd_congestion_fee),
        min(lpep_pickup_datetime),
        max(lpep_pickup_datetime)
    FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true, filename = true)
    GROUP BY 2
),
metadatos AS (
    SELECT
        split_part(file_name, '/', 3)                    AS tipo,
        CAST(split_part(file_name, '/', 4) AS INTEGER)   AS anio,
        sum(num_rows)                                    AS filas_metadatos
    FROM parquet_file_metadata('data/raw/*/*/*.parquet')
    GROUP BY ALL
)
SELECT
    l.tipo,
    l.anio,
    m.filas_metadatos,
    l.filas_leidas,
    l.filas_leidas - m.filas_metadatos      AS diferencia,
    l.con_cargo_cbd,
    l.primer_inicio,
    l.ultimo_inicio
FROM leidos AS l
JOIN metadatos AS m USING (tipo, anio)
ORDER BY l.tipo DESC, l.anio;
