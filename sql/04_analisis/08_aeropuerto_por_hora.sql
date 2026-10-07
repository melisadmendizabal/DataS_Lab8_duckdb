-- Ejercicio 4 - Pregunta 2 (aeropuertos): horario de los viajes de aeropuerto
-- Objetivo: comparar el perfil horario de los viajes desde/hacia aeropuertos
--           con el del resto de viajes (taxis amarillos).
-- Fuente:   vista viajes_validos (00_vistas.sql)
-- Nota:     pct_del_grupo = parte de los viajes de cada grupo que ocurre en
--           esa hora, para comparar perfiles de distinto tamanio.
WITH clasificados AS (
    SELECT
        hour(inicio) AS hora,
        CASE
            WHEN origen  IN (1, 132, 138) THEN 'Desde aeropuerto'
            WHEN destino IN (1, 132, 138) THEN 'Hacia aeropuerto'
            ELSE 'Sin aeropuerto'
        END AS grupo
    FROM viajes_validos
    WHERE tipo = 'yellow'
)
SELECT
    grupo,
    hora,
    count(*)                                                                AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY grupo), 2)    AS pct_del_grupo
FROM clasificados
GROUP BY grupo, hora
ORDER BY grupo, hora;
