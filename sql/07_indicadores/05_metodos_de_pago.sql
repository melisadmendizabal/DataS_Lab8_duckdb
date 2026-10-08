-- Indicador 5 - Participacion de cada metodo de pago por mes
-- Pregunta: P5. ¿Como pagan los pasajeros y esta cambiando la mezcla de
--           metodos de pago?
-- Indicador: % de los viajes de cada mes pagados con cada metodo (yellow +
--           green). Tarjeta, efectivo y Flex Fare se muestran por separado; el
--           resto (sin cargo, disputa, desconocido, anulado) se agrupa.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes + tabla metodos_pago
-- Nota:     se usa viajes (no viajes_validos), igual que en el Ejercicio 4:
--           los filtros de validez eliminan casi todas las disputas. En green
--           el equivalente a Flex Fare llega con payment_type NULL.
-- Visualizacion: barras apiladas al 100%; x = mes (YYYY-MM), serie = metodo.
SELECT
    v.mes_archivo                                                      AS mes,
    CASE
        WHEN m.metodo_pago IN ('Tarjeta', 'Efectivo', 'Flex Fare') THEN m.metodo_pago
        WHEN v.tipo_pago IS NULL THEN 'Flex Fare'
        ELSE 'Otros'
    END                                                                AS metodo_pago,
    count(*)                                                           AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY v.mes_archivo), 2) AS pct_del_mes
FROM viajes AS v
LEFT JOIN metodos_pago AS m USING (tipo_pago)
GROUP BY v.mes_archivo, 2
ORDER BY mes, metodo_pago;
