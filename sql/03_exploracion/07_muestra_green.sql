-- Ejercicio 3.5 - Muestra de registros (taxis verdes)
-- Objetivo: observar registros reales para entender el contenido de cada
--           columna.
-- Fuente:   data/raw/green/2026/*.parquet
-- Nota:     ver 06_muestra_yellow.sql.
SELECT *
FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true) AS t
ORDER BY hash(t)
LIMIT 10;
