-- Ejercicio 5.6 - Analisis conjunto: viajes por mes, 2024 frente a 2026
-- Objetivo: ejemplo de consulta que solo es posible con varios anios: comparar
--           los viajes validos de cada mes con el mismo mes del anio anterior
--           disponible (hoy 2026 frente a 2024).
-- Fuente:   vista viajes_validos (sql/04_analisis/00_vistas.sql, todos los anios)
-- Nota:     una fila por tipo, mes y anio comparado; los meses aun no
--           publicados de 2026 (septiembre en adelante) no aparecen.
WITH por_mes AS (
    SELECT tipo, anio, month(inicio) AS mes, count(*) AS viajes
    FROM viajes_validos
    GROUP BY ALL
)
SELECT
    tipo,
    mes,
    lag(anio) OVER w                                       AS anio_base,
    lag(viajes) OVER w                                     AS viajes_base,
    anio,
    viajes,
    round(100.0 * viajes / lag(viajes) OVER w - 100, 1)    AS variacion_pct
FROM por_mes
WINDOW w AS (PARTITION BY tipo, mes ORDER BY anio)
QUALIFY anio_base IS NOT NULL
ORDER BY tipo DESC, anio, mes;
