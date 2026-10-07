-- Ejercicio 4 - Pregunta 1 (temporal): demanda por dia de la semana
-- Objetivo: comparar cuantos viajes hay, en promedio, cada dia de la semana
--           para yellow y green.
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/*/2026/*.parquet
-- Nota:     se usa el PROMEDIO de viajes por fecha (no el total), porque cada
--           dia de la semana aparece un numero distinto de veces entre enero y
--           agosto. isodow: 1 = lunes ... 7 = domingo.
WITH por_fecha AS (
    SELECT tipo, CAST(inicio AS DATE) AS fecha, count(*) AS viajes
    FROM viajes_validos
    GROUP BY ALL
)
SELECT
    tipo,
    isodow(fecha)                                                       AS num_dia,
    ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'][isodow(fecha)]    AS dia,
    count(*)                                                            AS fechas,
    round(avg(viajes))                                                  AS viajes_promedio,
    round(100.0 * avg(viajes) / avg(avg(viajes)) OVER (PARTITION BY tipo) - 100, 1)
                                                                        AS pct_vs_promedio_semana
FROM por_fecha
GROUP BY tipo, num_dia, dia
ORDER BY tipo DESC, num_dia;
