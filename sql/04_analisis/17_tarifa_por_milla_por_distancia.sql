-- Ejercicio 4 - Pregunta 5 (distribucion): tarifa por milla segun la distancia
-- Objetivo: medir cuanto cuesta cada milla segun la longitud del viaje, para
--           mostrar el efecto del cargo inicial (bajada de bandera) y de la
--           parte de la tarifa que se cobra por tiempo.
-- Fuente:   vista viajes_validos (00_vistas.sql)
-- Nota:     solo tarifa estandar con taximetro (codigo_tarifa = 1), para
--           excluir tarifas fijas (JFK), negociadas y Flex Fare (cuya
--           fare_amount no refleja el taximetro). Se usa fare_amount (tarifa
--           base, sin propina ni recargos). Mediana y percentiles 25/75
--           porque la distribucion es asimetrica.
WITH estandar AS (
    SELECT
        tipo,
        tarifa / distancia AS tarifa_por_milla,
        CASE
            WHEN distancia < 0.5 THEN '1) < 0.5 mi'
            WHEN distancia < 1   THEN '2) 0.5-1 mi'
            WHEN distancia < 2   THEN '3) 1-2 mi'
            WHEN distancia < 3   THEN '4) 2-3 mi'
            WHEN distancia < 5   THEN '5) 3-5 mi'
            WHEN distancia < 10  THEN '6) 5-10 mi'
            WHEN distancia < 20  THEN '7) 10-20 mi'
            ELSE                      '8) >= 20 mi'
        END AS rango_distancia,
        tarifa
    FROM viajes_validos
    WHERE codigo_tarifa = 1 AND tarifa > 0
)
SELECT
    tipo,
    rango_distancia,
    count(*)                                                    AS viajes,
    round(median(tarifa), 2)                                    AS tarifa_mediana,
    round(quantile_cont(tarifa_por_milla, 0.25), 2)             AS usd_por_milla_p25,
    round(median(tarifa_por_milla), 2)                          AS usd_por_milla_mediana,
    round(quantile_cont(tarifa_por_milla, 0.75), 2)             AS usd_por_milla_p75
FROM estandar
GROUP BY tipo, rango_distancia
ORDER BY tipo DESC, rango_distancia;
