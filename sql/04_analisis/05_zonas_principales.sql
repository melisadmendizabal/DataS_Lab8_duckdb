-- Ejercicio 4 - Pregunta 2 (zonas): zonas con mas viajes de origen y destino
-- Objetivo: identificar las 10 zonas donde mas viajes empiezan y terminan
--           para cada tipo de taxi, con su distrito y su participacion.
-- Fuente:   vista viajes_validos + vista zonas (00_vistas.sql)
--           -> data/raw/*/2026/*.parquet, data/raw/zones/taxi_zone_lookup.csv
-- Nota:     el porcentaje es sobre el total de viajes validos del tipo de
--           taxi (incluyendo zonas 264/265, que aparecen si estan en el top).
WITH por_zona AS (
    SELECT tipo, 'origen' AS rol, origen AS id_zona, count(*) AS viajes
    FROM viajes_validos
    GROUP BY ALL
    UNION ALL
    SELECT tipo, 'destino', destino, count(*)
    FROM viajes_validos
    GROUP BY ALL
),
ordenadas AS (
    SELECT
        *,
        100.0 * viajes / sum(viajes) OVER (PARTITION BY tipo, rol)        AS pct,
        row_number() OVER (PARTITION BY tipo, rol ORDER BY viajes DESC)  AS posicion
    FROM por_zona
)
SELECT
    o.tipo,
    o.rol,
    o.posicion,
    z.zona,
    z.distrito,
    o.viajes,
    round(o.pct, 2)                                                       AS pct,
    round(sum(o.pct) OVER (PARTITION BY o.tipo, o.rol ORDER BY o.posicion), 2) AS pct_acumulado
FROM ordenadas AS o
LEFT JOIN zonas AS z USING (id_zona)
WHERE o.posicion <= 10
ORDER BY o.tipo DESC, o.rol DESC, o.posicion;
