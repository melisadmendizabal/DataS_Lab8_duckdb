-- Indicador 3 - Costo tipico de un viaje por mes
-- Pregunta: P3. ¿Cuanto paga un pasajero por un viaje tipico y como cambia
--           ese monto en el tiempo?
-- Indicador: mediana de total_amount por viaje, por mes y anio (taxis
--           amarillos). Se usa la mediana porque la distribucion de montos es
--           asimetrica (viajes de aeropuerto y largos elevan el promedio).
-- Fuente:   data/processed/taxis.duckdb, vista viajes_validos
-- Nota:     solo yellow (95%+ de los viajes): mezclar con green, que tiene
--           otra tarifa y otra cobertura, cambiaria la mediana por cambios de
--           composicion y no de precio. Se excluyen montos en cero.
-- Visualizacion: lineas; x = mes, y = total_mediano_usd, serie = anio.
SELECT
    CAST(substr(mes_archivo, 6, 2) AS INTEGER)   AS mes,
    CAST(anio AS VARCHAR)                        AS anio,
    round(median(total), 2)                      AS total_mediano_usd,
    round(median(tarifa), 2)                     AS tarifa_mediana_usd,
    round(median(distancia), 2)                  AS distancia_mediana_mi
FROM viajes_validos
WHERE tipo = 'yellow'
  AND total > 0
GROUP BY ALL
ORDER BY anio, mes;
