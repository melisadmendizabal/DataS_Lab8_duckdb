-- Indicador 11 - Registros que no pasan las reglas de calidad
-- Pregunta: P11. ¿Que tan confiables son los registros de cada mes y
--           proveedor? ¿Empeora o mejora la calidad de los datos?
-- Indicador: % de los registros de cada mes que quedan fuera de
--           viajes_validos (reglas del Ejercicio 3), por tipo de taxi.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes + vista viajes_validos
-- Nota:     un % alto no significa viajes falsos sino registros con datos
--           imposibles (p. ej. hora de fin igual a la de inicio); el
--           Ejercicio 5 mostro que en 2026 el proveedor Helix aporta casi
--           todos los de duracion cero.
-- Visualizacion: lineas; x = mes (YYYY-MM), y = pct_invalidos, serie = tipo.
WITH totales AS (
    SELECT tipo, mes_archivo, count(*) AS registros
    FROM viajes
    GROUP BY ALL
),
validos AS (
    SELECT tipo, mes_archivo, count(*) AS registros_validos
    FROM viajes_validos
    GROUP BY ALL
)
SELECT
    t.mes_archivo                                                            AS mes,
    t.tipo,
    t.registros,
    t.registros - v.registros_validos                                        AS registros_invalidos,
    round(100.0 * (t.registros - v.registros_validos) / t.registros, 2)      AS pct_invalidos
FROM totales AS t
JOIN validos AS v USING (tipo, mes_archivo)
ORDER BY t.tipo DESC, mes;
