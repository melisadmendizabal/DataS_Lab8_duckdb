-- Ejercicio 4 - Pregunta 3 (green): viajes tomados en la calle vs despachados
-- Objetivo: comparar los viajes de taxis verdes segun trip_type:
--           1 = tomado en la calle (street-hail), 2 = despachado (dispatch).
--           Se agrega un tercer grupo con trip_type NULL, que corresponde a
--           los viajes sin payment_type (equivalente a Flex Fare, ver
--           Ejercicio 3).
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/green/2026/*.parquet
-- Nota:     porcentaje de propina solo con tarjeta, sobre el monto antes de
--           la propina. codigo_tarifa 5 = tarifa negociada.
WITH green AS (
    SELECT
        *,
        CASE tipo_viaje
            WHEN 1 THEN '1 Calle'
            WHEN 2 THEN '2 Despacho'
            ELSE '3 Sin registro (NULL)'
        END AS grupo
    FROM viajes_validos
    WHERE tipo = 'green'
)
SELECT
    grupo,
    count(*)                                                               AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (), 2)                     AS pct_viajes,
    round(median(distancia), 2)                                            AS distancia_mediana,
    round(median(duracion_min), 1)                                         AS duracion_mediana_min,
    round(median(tarifa), 2)                                               AS tarifa_mediana,
    round(median(total), 2)                                                AS total_mediano,
    round(100.0 * count(*) FILTER (WHERE codigo_tarifa = 5) / count(*), 1) AS pct_tarifa_negociada,
    round(100.0 * count(*) FILTER (WHERE tipo_pago = 1) / count(*), 1)     AS pct_tarjeta,
    round(100.0 * count(*) FILTER (WHERE tipo_pago = 2) / count(*), 1)     AS pct_efectivo,
    round(100.0 * median(propina / nullif(total - propina, 0))
          FILTER (WHERE tipo_pago = 1), 1)                                 AS pct_propina_mediana_tarjeta,
    round(avg(pasajeros), 2)                                               AS pasajeros_promedio,
    round(100.0 * count(*) FILTER (WHERE proveedor = 6) / count(*), 1)     AS pct_proveedor_6_myle,
    round(100.0 * count(*) FILTER (WHERE origen_solicitud IS NOT NULL) / count(*), 1)
                                                                           AS pct_con_origen_solicitud
FROM green
GROUP BY grupo
ORDER BY grupo;
