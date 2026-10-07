-- Ejercicio 4 - Pregunta 4 (pago): propina segun el metodo de pago
-- Objetivo: comparar cuantos viajes registran propina y de que tamanio,
--           segun el metodo de pago y el tipo de taxi.
-- Fuente:   vista viajes_validos + vista metodos_pago (00_vistas.sql)
-- Nota:     pct_propina = propina / (total - propina), es decir, la propina
--           como porcentaje de lo cobrado antes de ella (asi la calculan las
--           pantallas de pago de los taxis).
SELECT
    v.tipo,
    coalesce(m.metodo_pago, 'Sin dato (NULL)')                         AS metodo_pago,
    count(*)                                                           AS viajes,
    count(*) FILTER (WHERE v.propina > 0)                              AS viajes_con_propina,
    round(100.0 * count(*) FILTER (WHERE v.propina > 0) / count(*), 2) AS pct_con_propina,
    round(avg(v.propina), 2)                                           AS propina_promedio,
    round(median(v.propina) FILTER (WHERE v.propina > 0), 2)           AS propina_mediana_si_hay,
    round(100.0 * median(v.propina / nullif(v.total - v.propina, 0))
          FILTER (WHERE v.propina > 0), 1)                             AS pct_propina_mediana_si_hay
FROM viajes_validos AS v
LEFT JOIN metodos_pago AS m USING (tipo_pago)
GROUP BY v.tipo, metodo_pago
ORDER BY v.tipo DESC, viajes DESC;
