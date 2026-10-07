-- Ejercicio 4 - Pregunta 3 (green): zonas de origen por tipo de viaje
-- Objetivo: identificar las 5 zonas de origen mas frecuentes de cada grupo
--           de trip_type y que tan concentrado esta cada grupo.
-- Fuente:   vista viajes_validos + vista zonas (00_vistas.sql)
WITH por_zona AS (
    SELECT
        CASE tipo_viaje
            WHEN 1 THEN '1 Calle'
            WHEN 2 THEN '2 Despacho'
            ELSE '3 Sin registro (NULL)'
        END            AS grupo,
        origen         AS id_zona,
        count(*)       AS viajes
    FROM viajes_validos
    WHERE tipo = 'green'
    GROUP BY ALL
),
ordenadas AS (
    SELECT
        *,
        100.0 * viajes / sum(viajes) OVER (PARTITION BY grupo)           AS pct,
        row_number() OVER (PARTITION BY grupo ORDER BY viajes DESC)      AS posicion
    FROM por_zona
)
SELECT
    o.grupo,
    o.posicion,
    z.zona,
    z.distrito,
    o.viajes,
    round(o.pct, 2)                                                           AS pct,
    round(sum(o.pct) OVER (PARTITION BY o.grupo ORDER BY o.posicion), 2)      AS pct_acumulado
FROM ordenadas AS o
LEFT JOIN zonas AS z USING (id_zona)
WHERE o.posicion <= 5
ORDER BY o.grupo, o.posicion;
