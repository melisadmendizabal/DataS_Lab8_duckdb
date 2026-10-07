-- Ejercicio 4 - Pregunta 4 (pago): propina segun la hora y el tipo de dia
-- Objetivo: verificar si la propina cambia a lo largo del dia y entre dias
--           laborables y fines de semana.
-- Fuente:   vista viajes_validos (00_vistas.sql)
-- Nota:     solo pagos con tarjeta (payment_type = 1): en efectivo la
--           propina casi nunca se registra (ver consulta 14), por lo que
--           incluirlo mezclaria comportamiento con forma de registro. Se usa
--           el promedio del porcentaje recortado a [0, 100] para que viajes
--           con total casi cero no distorsionen el resultado.
SELECT
    tipo,
    CASE WHEN isodow(inicio) >= 6 THEN 'Fin de semana' ELSE 'Laborable' END   AS tipo_dia,
    hour(inicio)                                                               AS hora,
    count(*)                                                                   AS viajes,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 1)           AS pct_con_propina,
    round(100.0 * avg(least(propina / nullif(total - propina, 0), 1)), 2)      AS pct_propina_promedio,
    round(avg(propina), 2)                                                     AS propina_promedio
FROM viajes_validos
WHERE tipo_pago = 1
GROUP BY tipo, tipo_dia, hora
ORDER BY tipo DESC, tipo_dia DESC, hora;
