-- Ejercicio 4 - Pregunta 2 (aeropuertos): caracteristicas de los viajes de aeropuerto
-- Objetivo: cuantificar los viajes que salen o llegan a JFK, LaGuardia y
--           Newark y compararlos con el resto en distancia, duracion, tarifa,
--           total, propina y uso de la tarifa fija de JFK (RatecodeID = 2).
-- Fuente:   vista viajes_validos + vista zonas (00_vistas.sql)
-- Nota:     un viaje es "de aeropuerto" si su origen o su destino es una de
--           las zonas 1 (Newark), 132 (JFK) o 138 (LaGuardia). Si empieza y
--           termina en aeropuertos se clasifica por el origen. El porcentaje
--           de propina se calcula solo para pagos con tarjeta (las propinas en
--           efectivo no se registran) sobre el monto antes de la propina.
WITH clasificados AS (
    SELECT
        v.*,
        CASE
            WHEN v.origen  IN (1, 132, 138) THEN 'Desde ' || zo.zona
            WHEN v.destino IN (1, 132, 138) THEN 'Hacia ' || zd.zona
            ELSE 'Sin aeropuerto'
        END AS categoria
    FROM viajes_validos AS v
    LEFT JOIN zonas AS zo ON zo.id_zona = v.origen
    LEFT JOIN zonas AS zd ON zd.id_zona = v.destino
)
SELECT
    tipo,
    categoria,
    count(*)                                                              AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2)  AS pct_viajes,
    round(median(distancia), 2)                                           AS distancia_mediana,
    round(median(duracion_min), 1)                                        AS duracion_mediana_min,
    round(median(tarifa), 2)                                              AS tarifa_mediana,
    round(median(total), 2)                                               AS total_mediano,
    round(100.0 * median(propina / nullif(total - propina, 0))
          FILTER (WHERE tipo_pago = 1), 1)                                AS pct_propina_mediana_tarjeta,
    round(100.0 * count(*) FILTER (WHERE codigo_tarifa = 2) / count(*), 1) AS pct_tarifa_fija_jfk,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY tipo), 2) AS pct_ingresos
FROM clasificados
GROUP BY tipo, categoria
ORDER BY tipo DESC, categoria = 'Sin aeropuerto', viajes DESC;
