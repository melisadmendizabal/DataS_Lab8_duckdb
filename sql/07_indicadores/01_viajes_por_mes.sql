-- Indicador 1 - Viajes por mes
-- Pregunta: P1. ¿Cuantos viajes se realizan cada mes y como se compara la
--           demanda de un anio con la del otro?
-- Indicador: cantidad de viajes registrados por mes calendario, una serie
--           por anio (yellow + green). Se usa la tabla viajes completa (no
--           viajes_validos): un registro con una hora o distancia mal
--           capturada sigue siendo un viaje realizado.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes (scripts/materializar.py)
-- Visualizacion: lineas; x = mes, y = viajes, serie = anio.
SELECT
    CAST(substr(mes_archivo, 6, 2) AS INTEGER)   AS mes,
    CAST(anio AS VARCHAR)                        AS anio,
    count(*)                                     AS viajes
FROM viajes
GROUP BY ALL
ORDER BY anio, mes;
