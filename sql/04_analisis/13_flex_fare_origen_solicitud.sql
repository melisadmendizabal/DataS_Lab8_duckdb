-- Ejercicio 4 - Pregunta 4 (pago): de donde vienen los viajes Flex Fare
-- Objetivo: caracterizar los viajes con payment_type = 0 (Flex Fare) usando
--           request_source, columna que existe desde 2026-06, y compararlos
--           con los pagos con tarjeta y efectivo.
-- Fuente:   vista viajes_validos + vista metodos_pago (00_vistas.sql)
--           -> data/raw/yellow/2026/yellow_tripdata_2026-0[6-8].parquet
-- Nota:     request_source no aparece en el diccionario de datos de la TLC.
--           HV0003 y HV0005 coinciden con los codigos de licencia HVFHS de la
--           TLC (Uber y Lyft); el resto de codigos (A, CC, EH*) no tiene
--           documentacion publica disponible.
SELECT
    coalesce(m.metodo_pago, 'Sin dato (NULL)')                          AS metodo_pago,
    coalesce(v.origen_solicitud, 'NULL')                                AS origen_solicitud,
    count(*)                                                            AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY metodo_pago), 2) AS pct_del_metodo,
    round(median(v.distancia), 2)                                       AS distancia_mediana,
    round(median(v.total), 2)                                           AS total_mediano,
    round(100.0 * count(*) FILTER (WHERE v.propina > 0) / count(*), 1)  AS pct_con_propina
FROM viajes_validos AS v
LEFT JOIN metodos_pago AS m USING (tipo_pago)
WHERE v.tipo = 'yellow'
  AND v.mes_archivo >= '2026-06'
  AND v.tipo_pago IN (0, 1, 2)
GROUP BY metodo_pago, origen_solicitud
ORDER BY metodo_pago, viajes DESC;
