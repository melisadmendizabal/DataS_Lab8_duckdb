-- Ejercicio 3.6 - Perfil estadistico (taxis amarillos)
-- Objetivo: obtener por columna minimo, maximo, cardinalidad aproximada,
--           promedio, mediana y porcentaje de nulos para detectar valores
--           fuera de rango y columnas incompletas.
-- Fuente:   data/raw/yellow/2026/*.parquet
SELECT column_name, column_type, min, max, approx_unique,
       round(TRY_CAST(avg AS DOUBLE), 2) AS avg, q50, null_percentage
FROM (SUMMARIZE SELECT * FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true));
