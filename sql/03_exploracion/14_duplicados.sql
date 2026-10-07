-- Ejercicio 3.6 - Registros duplicados
-- Objetivo: detectar filas exactamente repetidas (todas las columnas iguales).
-- Fuente:   data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
-- Nota:     SELECT DISTINCT * sobre ~30 M filas y 21 columnas agota la memoria
--           del contenedor; en su lugar se compara un hash de 64 bits de la
--           fila completa (hash(t)), que ocupa 8 bytes por fila. La
--           probabilidad de una colision es despreciable (~1e-5 para 30 M
--           filas) y la consulta 15 confirma los duplicados encontrados.
SELECT 'yellow' AS tipo, count(*) AS filas, count(DISTINCT hash(t)) AS filas_distintas,
       count(*) - count(DISTINCT hash(t)) AS duplicados
FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
UNION ALL
SELECT 'green', count(*), count(DISTINCT hash(t)), count(*) - count(DISTINCT hash(t))
FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true) AS t;
