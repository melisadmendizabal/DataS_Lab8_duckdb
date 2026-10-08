-- Indicador 7 - Demanda promedio por hora del dia
-- Pregunta: P7. ¿En que horas se concentra la demanda en dias laborables y
--           en fines de semana, y se mantiene el patron entre anios?
-- Indicador: viajes promedio que inician en cada hora (viajes de la hora /
--           fechas de ese tipo de dia), por tipo de dia y anio.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes
-- Nota:     solo los meses publicados en todos los anios (hoy enero-agosto)
--           para no mezclar estacionalidad, y solo viajes cuya fecha cae en
--           el anio de su archivo. Se divide entre el numero de fechas de
--           cada tipo de dia.
-- Visualizacion: lineas; x = hora, y = viajes_promedio, serie = serie (anio + tipo de dia).
WITH meses_comunes AS (
    -- meses publicados en todos los anios cargados (hoy enero-agosto)
    SELECT substr(mes_archivo, 6, 2) AS mes
    FROM viajes
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM viajes)
),
clasificados AS (
    SELECT
        anio,
        CAST(inicio AS DATE)                                                      AS fecha,
        hour(inicio)                                                              AS hora,
        CASE WHEN isodow(inicio) >= 6 THEN 'fin de semana' ELSE 'laborable' END   AS tipo_dia
    FROM viajes
    WHERE year(inicio) = anio
      AND substr(mes_archivo, 6, 2) IN (SELECT mes FROM meses_comunes)
),
fechas AS (
    SELECT anio, tipo_dia, count(DISTINCT fecha) AS num_fechas
    FROM clasificados
    GROUP BY ALL
)
SELECT
    c.hora,
    c.anio || ' ' || c.tipo_dia                       AS serie,
    round(count(*) / any_value(f.num_fechas))         AS viajes_promedio
FROM clasificados AS c
JOIN fechas AS f USING (anio, tipo_dia)
GROUP BY c.hora, c.anio, c.tipo_dia
ORDER BY serie, c.hora;
