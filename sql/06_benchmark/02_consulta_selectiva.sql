-- Ejercicio 6 - Benchmark B2: consulta muy selectiva (un dia, un aeropuerto)
-- Objetivo: medir una consulta que solo necesita una fraccion minima de las
--           filas: viajes que salieron de JFK (zona 132) el 15 de enero de
--           2026, por hora. Pone a prueba la poda de bloques (estadisticas
--           min/max de los row groups Parquet y zonemaps de la tabla).
-- Fuente:   vista/tabla viajes_validos (Parquet: 00_vistas.sql; tabla: materializar.py)
-- Nota:     todas las escalas del benchmark contienen enero de 2026.
SELECT
    hour(inicio)                     AS hora,
    count(*)                         AS viajes,
    round(median(total), 2)          AS total_mediano
FROM viajes_validos
WHERE inicio >= TIMESTAMP '2026-01-15 00:00:00'
  AND inicio <  TIMESTAMP '2026-01-16 00:00:00'
  AND origen = 132
GROUP BY hora
ORDER BY hora;
