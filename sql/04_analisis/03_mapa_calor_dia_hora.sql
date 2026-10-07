-- Ejercicio 4 - Pregunta 1 (temporal): mapa de calor dia de la semana x hora
-- Objetivo: ubicar las franjas (dia + hora) con mayor y menor demanda,
--           combinando las dos consultas anteriores.
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/*/2026/*.parquet
-- Nota:     formato largo (una fila por tipo, dia y hora); el notebook lo
--           pivotea para dibujar el mapa. Valor = viajes promedio por fecha.
WITH clasificados AS (
    SELECT tipo, CAST(inicio AS DATE) AS fecha, isodow(inicio) AS num_dia, hour(inicio) AS hora
    FROM viajes_validos
),
fechas AS (
    SELECT tipo, num_dia, count(DISTINCT fecha) AS num_fechas
    FROM clasificados
    GROUP BY ALL
)
SELECT
    c.tipo,
    c.num_dia,
    ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'][c.num_dia]  AS dia,
    c.hora,
    round(count(*) / any_value(f.num_fechas))                     AS viajes_promedio
FROM clasificados AS c
JOIN fechas AS f USING (tipo, num_dia)
GROUP BY c.tipo, c.num_dia, c.hora
ORDER BY c.tipo DESC, c.num_dia, c.hora;
