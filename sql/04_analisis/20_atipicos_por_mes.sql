-- Ejercicio 4 - Pregunta 6 (atipicos): evolucion mensual de las inconsistencias
-- Objetivo: verificar si las tasas de error son estables en el tiempo o si
--           aparecen/desaparecen en algun mes para algun proveedor (taxis
--           amarillos, que concentran el volumen).
-- Fuente:   vista viajes (00_vistas.sql; SIN filtrar)
-- Nota:     se agrupa por el mes del archivo (no por la fecha del viaje),
--           porque una fecha invalida es justamente uno de los errores.
SELECT
    mes_archivo                                                                    AS mes,
    proveedor,
    count(*)                                                                       AS viajes,
    round(100.0 * count(*) FILTER (WHERE fin <= inicio) / count(*), 3)             AS pct_duracion_cero,
    round(100.0 * count(*) FILTER (WHERE distancia = 0) / count(*), 3)             AS pct_distancia_cero,
    count(*) FILTER (WHERE distancia > 100)                                        AS viajes_distancia_mayor_100,
    round(100.0 * count(*) FILTER (WHERE total < 0) / count(*), 3)                 AS pct_total_negativo,
    round(100.0 * count(*) FILTER (WHERE origen IN (264, 265) OR destino IN (264, 265)) / count(*), 3)
                                                                                   AS pct_zona_desconocida
FROM viajes
WHERE tipo = 'yellow'
GROUP BY mes, proveedor
ORDER BY mes, proveedor;
