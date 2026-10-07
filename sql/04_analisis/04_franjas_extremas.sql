-- Ejercicio 4 - Pregunta 1 (temporal): franjas de mayor y menor demanda
-- Objetivo: listar, para cada tipo de taxi, las 5 combinaciones dia + hora
--           con mas viajes promedio y las 5 con menos, y cuanto representan
--           respecto a la franja promedio.
-- Fuente:   vista viajes_validos (00_vistas.sql) -> data/raw/*/2026/*.parquet
WITH clasificados AS (
    SELECT tipo, CAST(inicio AS DATE) AS fecha, isodow(inicio) AS num_dia, hour(inicio) AS hora
    FROM viajes_validos
),
fechas AS (
    -- fechas de cada dia de la semana (una franja sin viajes en alguna fecha
    -- debe promediar con esa fecha en cero)
    SELECT tipo, num_dia, count(DISTINCT fecha) AS num_fechas
    FROM clasificados
    GROUP BY ALL
),
franjas AS (
    SELECT
        c.tipo,
        ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'][c.num_dia] || ' ' || lpad(c.hora::VARCHAR, 2, '0') || 'h' AS franja,
        count(*) / any_value(f.num_fechas) AS viajes_promedio
    FROM clasificados AS c
    JOIN fechas AS f USING (tipo, num_dia)
    GROUP BY c.tipo, c.num_dia, c.hora
),
ordenadas AS (
    SELECT
        *,
        row_number() OVER (PARTITION BY tipo ORDER BY viajes_promedio DESC) AS pos_mayor,
        row_number() OVER (PARTITION BY tipo ORDER BY viajes_promedio ASC)  AS pos_menor,
        viajes_promedio / avg(viajes_promedio) OVER (PARTITION BY tipo)     AS veces_promedio
    FROM franjas
)
SELECT
    tipo,
    CASE WHEN pos_mayor <= 5 THEN 'mayor demanda' ELSE 'menor demanda' END AS grupo,
    least(pos_mayor, pos_menor)                                           AS posicion,
    franja,
    round(viajes_promedio)                                                AS viajes_promedio,
    round(veces_promedio, 2)                                              AS veces_el_promedio
FROM ordenadas
WHERE pos_mayor <= 5 OR pos_menor <= 5
ORDER BY tipo DESC, grupo, posicion;
