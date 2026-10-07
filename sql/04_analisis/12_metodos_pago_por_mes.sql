-- Ejercicio 4 - Pregunta 4 (pago): metodos de pago por mes
-- Objetivo: medir la participacion de cada metodo de pago por tipo de taxi
--           y mes, y ver si cambia en el tiempo.
-- Fuente:   vista viajes + vista metodos_pago (00_vistas.sql)
-- Nota:     se usa la vista viajes (no viajes_validos) limitada a 2026,
--           porque los filtros de validez eliminan montos negativos y con
--           ellos la mayoria de las disputas; aqui interesa la mezcla real de
--           metodos. En green, payment_type NULL se etiqueta 'Sin dato (NULL)'.
SELECT
    v.tipo,
    strftime(v.inicio, '%Y-%m')                                         AS mes,
    coalesce(m.metodo_pago, 'Sin dato (NULL)')                          AS metodo_pago,
    count(*)                                                            AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY v.tipo, mes), 2) AS pct_del_mes
FROM viajes AS v
LEFT JOIN metodos_pago AS m USING (tipo_pago)
WHERE year(v.inicio) = 2026
GROUP BY v.tipo, mes, metodo_pago
ORDER BY v.tipo DESC, mes, viajes DESC;
