-- Indicador 6 - Propina en pagos con tarjeta
-- Pregunta: P6. ¿Que tan generosas son las propinas y cambian entre anios?
-- Indicador: % de los viajes pagados con tarjeta que incluyen propina, por
--           mes y anio. Como referencia se agrega la propina promedio como %
--           de lo cobrado antes de ella (recortada a [0, 100]%).
-- Decision: la propina MEDIANA no sirve como indicador: es exactamente 20%
--           en todos los meses de ambos anios (la opcion sugerida por la
--           pantalla de pago), mientras que la proporcion de pasajeros que
--           deja propina si cambia.
-- Fuente:   data/processed/taxis.duckdb, vista viajes_validos
-- Nota:     solo tarjeta (payment_type = 1): en efectivo la propina casi
--           nunca se registra (Ejercicio 4, consulta 14). Yellow + green.
-- Visualizacion: lineas; x = mes, y = pct_con_propina, serie = anio.
SELECT
    CAST(substr(mes_archivo, 6, 2) AS INTEGER)                            AS mes,
    CAST(anio AS VARCHAR)                                                 AS anio,
    count(*)                                                              AS viajes_tarjeta,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 1)      AS pct_con_propina,
    round(100.0 * avg(least(propina / nullif(total - propina, 0), 1)), 1) AS pct_propina_promedio
FROM viajes_validos
WHERE tipo_pago = 1
GROUP BY ALL
ORDER BY anio, mes;
