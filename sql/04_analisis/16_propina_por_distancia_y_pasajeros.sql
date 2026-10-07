-- Ejercicio 4 - Pregunta 4 (pago): propina segun distancia y pasajeros
-- Objetivo: ver si la propina (en USD y en %) cambia con la distancia del
--           viaje y con el numero de pasajeros.
-- Fuente:   vista viajes_validos (00_vistas.sql)
-- Nota:     solo pagos con tarjeta y solo yellow (green tiene muy pocos
--           viajes en los rangos largos). pasajeros = 0 o NULL se agrupa como
--           'Sin dato'; 5 o mas se agrupan.
WITH tarjeta AS (
    SELECT
        *,
        propina / nullif(total - propina, 0) AS fraccion_propina
    FROM viajes_validos
    WHERE tipo = 'yellow' AND tipo_pago = 1
)
SELECT
    'distancia'                                                        AS dimension,
    CASE
        WHEN distancia < 1  THEN '1) < 1 mi'
        WHEN distancia < 2  THEN '2) 1-2 mi'
        WHEN distancia < 5  THEN '3) 2-5 mi'
        WHEN distancia < 10 THEN '4) 5-10 mi'
        WHEN distancia < 20 THEN '5) 10-20 mi'
        ELSE                     '6) >= 20 mi'
    END                                                                AS rango,
    count(*)                                                           AS viajes,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 1)   AS pct_con_propina,
    round(median(propina), 2)                                          AS propina_mediana,
    round(100.0 * avg(least(fraccion_propina, 1)), 2)                  AS pct_propina_promedio
FROM tarjeta
GROUP BY rango
UNION ALL
SELECT
    'pasajeros',
    CASE
        WHEN pasajeros IS NULL OR pasajeros = 0 THEN '0) Sin dato'
        WHEN pasajeros >= 5 THEN '5) 5 o mas'
        ELSE pasajeros::VARCHAR || ') ' || pasajeros::VARCHAR
    END,
    count(*),
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 1),
    round(median(propina), 2),
    round(100.0 * avg(least(fraccion_propina, 1)), 2)
FROM tarjeta
GROUP BY 2
ORDER BY dimension, rango;
