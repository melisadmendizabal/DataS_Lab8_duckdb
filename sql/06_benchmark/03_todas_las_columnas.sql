-- Ejercicio 6 - Benchmark B3: recorrido de todas las columnas
-- Objetivo: leer y descomprimir TODOS los valores de todas las columnas,
--           sumando el hash de cada valor por columna. Contrasta con B1, que
--           solo lee pocas columnas (el formato columnar de ambas
--           estrategias permite leer solo las columnas necesarias).
-- Fuente:   vista/tabla viajes (Parquet: 00_vistas.sql; tabla: materializar.py)
-- Nota:     no se usa count(columna): en la tabla DuckDB puede resolverlo con
--           las estadisticas guardadas sin leer los valores. La suma de
--           hashes no depende del orden de las filas, por lo que el resultado
--           es identico en ambas estrategias.
SELECT sum(hash(COLUMNS(*)))
FROM viajes;
