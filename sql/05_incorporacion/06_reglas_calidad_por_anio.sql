-- Ejercicio 5.6 - Reglas de calidad por anio
-- Objetivo: repetir las reglas de calidad del Ejercicio 3 (consulta 13) sobre
--           ambos anios para saber si los problemas detectados en 2026 tambien
--           existen en 2024 y si las reglas de limpieza de viajes_validos
--           siguen siendo adecuadas.
-- Fuente:   vista viajes (sql/04_analisis/00_vistas.sql, todos los anios)
-- Nota:     porcentaje de las filas de cada tipo y anio. Las reglas no son
--           excluyentes. PIVOT sin lista IN crea una columna por cada tipo y
--           anio cargado.
WITH conteos AS (
    SELECT
        tipo,
        anio,
        count(*)                                                AS total,
        count(*) FILTER (WHERE year(inicio) <> anio)            AS "01 inicio fuera del anio",
        count(*) FILTER (WHERE fin <= inicio)                   AS "02 duracion cero o negativa",
        count(*) FILTER (WHERE fin - inicio > INTERVAL 24 HOUR) AS "03 duracion mayor a 24 h",
        count(*) FILTER (WHERE distancia = 0)                   AS "04 distancia cero",
        count(*) FILTER (WHERE distancia > 100)                 AS "05 distancia mayor a 100 millas",
        count(*) FILTER (WHERE tarifa < 0)                      AS "06 tarifa negativa",
        count(*) FILTER (WHERE total < 0)                       AS "07 total negativo",
        count(*) FILTER (WHERE pasajeros = 0)                   AS "08 cero pasajeros",
        count(*) FILTER (WHERE pasajeros IS NULL)               AS "09 pasajeros nulo",
        count(*) FILTER (WHERE tipo_pago = 0)                   AS "10 payment_type 0 (Flex Fare)",
        count(*) FILTER (WHERE origen IN (264, 265)
                            OR destino IN (264, 265))           AS "11 zona desconocida o fuera de NYC"
    FROM viajes
    GROUP BY tipo, anio
),
largo AS (
    SELECT
        regla,
        'pct_' || tipo || '_' || anio           AS serie,
        round(100.0 * filas / total, 3)          AS pct
    FROM (UNPIVOT conteos ON COLUMNS(* EXCLUDE (tipo, anio, total)) INTO NAME regla VALUE filas)
)
PIVOT largo
ON serie
USING max(pct)
GROUP BY regla
ORDER BY regla;
