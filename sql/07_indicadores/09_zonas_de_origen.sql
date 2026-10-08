-- Indicador 9 - Zonas con mas viajes de origen
-- Pregunta: P9. ¿Donde se origina la demanda y cambiaron las zonas
--           principales entre anios?
-- Indicador: % de los viajes de cada anio que inicia en cada una de las 10
--           zonas con mas viajes del anio mas reciente.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes + tabla zonas
-- Nota:     solo meses publicados en todos los anios (hoy enero-agosto), y
--           porcentajes sobre el total del anio. Yellow + green.
-- Visualizacion: barras horizontales; y = zona, x = pct_viajes, serie = anio.
WITH meses_comunes AS (
    -- meses publicados en todos los anios cargados (hoy enero-agosto)
    SELECT substr(mes_archivo, 6, 2) AS mes
    FROM viajes
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM viajes)
),
por_zona AS (
    SELECT anio, origen AS id_zona, count(*) AS viajes
    FROM viajes
    WHERE substr(mes_archivo, 6, 2) IN (SELECT mes FROM meses_comunes)
    GROUP BY ALL
),
porcentajes AS (
    SELECT *, 100.0 * viajes / sum(viajes) OVER (PARTITION BY anio) AS pct
    FROM por_zona
),
top_reciente AS (
    SELECT id_zona, row_number() OVER (ORDER BY pct DESC) AS posicion
    FROM porcentajes
    WHERE anio = (SELECT max(anio) FROM viajes)
    QUALIFY posicion <= 10
)
SELECT
    t.posicion,
    z.zona || ' (' || z.distrito || ')'      AS zona,
    CAST(p.anio AS VARCHAR)                  AS anio,
    p.viajes,
    round(p.pct, 2)                          AS pct_viajes
FROM top_reciente AS t
JOIN porcentajes AS p USING (id_zona)
JOIN zonas AS z USING (id_zona)
ORDER BY t.posicion, p.anio;
