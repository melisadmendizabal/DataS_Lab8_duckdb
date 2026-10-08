-- Indicador 10 - Peso de los aeropuertos en viajes e ingresos
-- Pregunta: P10. ¿Que parte de los viajes y de los ingresos corresponde a
--           viajes desde o hacia los aeropuertos?
-- Indicador: % de viajes y % de ingresos (total_amount) de los viajes cuyo
--           origen o destino es JFK (132), LaGuardia (138) o Newark (1), por
--           anio y aeropuerto.
-- Fuente:   data/processed/taxis.duckdb, vista viajes_validos + tabla zonas
-- Nota:     solo meses publicados en todos los anios (hoy enero-agosto). Un
--           viaje entre dos aeropuertos se asigna al de origen. Yellow + green.
-- Formato largo (una fila por aeropuerto, anio y medida) para graficar las
-- dos medidas de ambos anios juntas: si % ingresos > % viajes, el viaje de
-- aeropuerto cuesta mas que el promedio.
-- Visualizacion: barras; x = aeropuerto, y = pct, serie = serie (anio + medida).
WITH meses_comunes AS (
    SELECT substr(mes_archivo, 6, 2) AS mes
    FROM viajes
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM viajes)
),
clasificados AS (
    SELECT
        anio,
        total,
        CASE
            WHEN origen  IN (1, 132, 138) THEN origen
            WHEN destino IN (1, 132, 138) THEN destino
        END AS id_aeropuerto
    FROM viajes_validos
    WHERE substr(mes_archivo, 6, 2) IN (SELECT mes FROM meses_comunes)
),
por_anio AS (
    SELECT
        anio,
        id_aeropuerto,
        count(*)                                                       AS viajes,
        100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio)      AS pct_viajes,
        100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio)  AS pct_ingresos
    FROM clasificados
    GROUP BY anio, id_aeropuerto
)
SELECT
    z.zona                                     AS aeropuerto,
    p.anio || ' ' || m.medida                  AS serie,
    round(CASE m.medida WHEN '% viajes' THEN p.pct_viajes ELSE p.pct_ingresos END, 2) AS pct
FROM por_anio AS p
JOIN zonas AS z ON z.id_zona = p.id_aeropuerto
CROSS JOIN (VALUES ('% viajes'), ('% ingresos')) AS m(medida)
ORDER BY aeropuerto, serie;
