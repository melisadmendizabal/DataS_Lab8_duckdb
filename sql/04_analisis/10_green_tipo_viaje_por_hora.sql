-- Ejercicio 4 - Pregunta 3 (green): perfil horario por tipo de viaje
-- Objetivo: verificar si los viajes despachados y los tomados en la calle
--           ocurren a horas distintas.
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/green/2026/*.parquet
-- Nota:     pct_del_grupo = parte de los viajes de cada grupo en esa hora.
WITH green AS (
    SELECT
        hour(inicio) AS hora,
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
    hora,
    count(*)                                                              AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY grupo), 2)  AS pct_del_grupo
FROM green
GROUP BY grupo, hora
ORDER BY grupo, hora;
