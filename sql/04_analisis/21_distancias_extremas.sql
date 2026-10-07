-- Ejercicio 4 - Pregunta 6 (atipicos): perfil de los viajes con distancia mayor a 100 millas
-- Objetivo: caracterizar los viajes con distancias imposibles para entender
--           su origen: proveedor, metodo de pago, duracion y tarifa cobrada.
--           Si la tarifa y la duracion son normales, el error esta en el
--           odometro/distancia y no en el viaje.
-- Fuente:   vista viajes + vista metodos_pago (00_vistas.sql; SIN filtrar)
SELECT
    v.tipo,
    v.proveedor,
    coalesce(m.metodo_pago, 'Sin dato (NULL)')                      AS metodo_pago,
    count(*)                                                        AS viajes,
    round(median(v.distancia))                                      AS distancia_mediana,
    round(max(v.distancia))                                         AS distancia_maxima,
    round(median(v.duracion_min), 1)                                AS duracion_mediana_min,
    round(median(v.tarifa), 2)                                      AS tarifa_mediana,
    round(median(v.distancia / nullif(v.duracion_min / 60, 0)))     AS velocidad_implicita_mph
FROM viajes AS v
LEFT JOIN metodos_pago AS m USING (tipo_pago)
WHERE v.distancia > 100
GROUP BY v.tipo, v.proveedor, metodo_pago
ORDER BY v.tipo DESC, viajes DESC;
