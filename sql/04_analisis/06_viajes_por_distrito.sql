-- Ejercicio 4 - Pregunta 2 (zonas): distribucion de origenes por distrito
-- Objetivo: ver en que distritos (boroughs) operan yellow y green; complementa
--           el top de zonas con una vista agregada.
-- Fuente:   vista viajes_validos + vista zonas (00_vistas.sql)
-- Nota:     'Unknown' y 'N/A' corresponden a las zonas 264 y 265.
SELECT
    v.tipo,
    coalesce(z.distrito, 'Sin zona')                                   AS distrito_origen,
    count(*)                                                           AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY v.tipo), 2) AS pct
FROM viajes_validos AS v
LEFT JOIN zonas AS z ON z.id_zona = v.origen
GROUP BY v.tipo, distrito_origen
ORDER BY v.tipo DESC, viajes DESC;
