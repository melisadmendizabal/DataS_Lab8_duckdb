-- Ejercicio 3.5 - Muestra de registros (taxis amarillos)
-- Objetivo: observar registros reales para entender el contenido de cada
--           columna.
-- Fuente:   data/raw/yellow/2026/*.parquet
-- Nota:     muestra pseudoaleatoria de 10 filas tomada de todos los meses: se
--           ordena por el hash de la fila completa. A diferencia de
--           LIMIT 10 (primeras filas del primer archivo) o de
--           USING SAMPLE ... REPEATABLE (que con varios hilos devolvio solo
--           filas del 1 de enero), es reproducible y no esta sesgada al
--           inicio del primer archivo.
SELECT *
FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true) AS t
ORDER BY hash(t)
LIMIT 10;
