-- Ejercicio 3.6 - Perfil estadistico (taxis verdes)
-- Objetivo: igual que 08_resumen_yellow.sql para taxis verdes.
-- Fuente:   data/raw/green/2026/*.parquet
SELECT column_name, column_type, min, max, approx_unique,
       round(TRY_CAST(avg AS DOUBLE), 2) AS avg, q50, null_percentage
FROM (SUMMARIZE SELECT * FROM read_parquet('data/raw/green/2026/*.parquet', union_by_name = true));
