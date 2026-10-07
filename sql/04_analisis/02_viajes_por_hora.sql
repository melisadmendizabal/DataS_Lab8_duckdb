-- Ejercicio 4 - Pregunta 1 (temporal): patron por hora, entre semana vs fin de semana
-- Objetivo: identificar las horas pico y verificar si el perfil horario
--           cambia entre dias laborables y fines de semana.
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/*/2026/*.parquet
-- Nota:     viajes promedio por hora = viajes en esa hora / numero de fechas
--           de ese tipo de dia (laborable o fin de semana), para que ambos
--           perfiles sean comparables aunque haya ~2.5 veces mas dias
--           laborables. pct_del_dia = parte de los viajes del dia que ocurre
--           en esa hora.
WITH clasificados AS (
    SELECT
        tipo,
        CAST(inicio AS DATE)                                     AS fecha,
        hour(inicio)                                             AS hora,
        CASE WHEN isodow(inicio) >= 6 THEN 'Fin de semana' ELSE 'Laborable' END AS tipo_dia
    FROM viajes_validos
),
fechas AS (
    SELECT tipo, tipo_dia, count(DISTINCT fecha) AS num_fechas
    FROM clasificados
    GROUP BY ALL
)
SELECT
    c.tipo,
    c.tipo_dia,
    c.hora,
    round(count(*) / any_value(f.num_fechas))                               AS viajes_promedio,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY c.tipo, c.tipo_dia), 2) AS pct_del_dia
FROM clasificados AS c
JOIN fechas AS f USING (tipo, tipo_dia)
GROUP BY c.tipo, c.tipo_dia, c.hora
ORDER BY c.tipo DESC, c.tipo_dia DESC, c.hora;
