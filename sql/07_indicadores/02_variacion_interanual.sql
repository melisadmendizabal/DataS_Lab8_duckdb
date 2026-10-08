-- Indicador 2 - Variacion interanual de viajes por tipo de taxi
-- Pregunta: P2. ¿La demanda crece o cae respecto al mismo mes del anio
--           anterior disponible, y evolucionan igual yellow y green?
-- Indicador: (viajes del mes / viajes del mismo mes del anio anterior
--           disponible - 1) x 100, por tipo de taxi. Comparar el mismo mes
--           elimina la estacionalidad.
-- Fuente:   data/processed/taxis.duckdb, tabla viajes
-- Nota:     el "anio anterior disponible" es el anio cargado inmediatamente
--           anterior (hoy 2026 frente a 2024; al agregar 2025 en el
--           Ejercicio 8 seran 2025 vs 2024 y 2026 vs 2025, sin cambiar la
--           consulta).
-- Visualizacion: barras; x = mes, y = variacion_pct, serie = serie (tipo + comparacion).
WITH por_mes AS (
    SELECT
        tipo,
        anio,
        CAST(substr(mes_archivo, 6, 2) AS INTEGER)   AS mes,
        count(*)                                     AS viajes
    FROM viajes
    GROUP BY ALL
),
comparados AS (
    SELECT
        *,
        lag(anio)   OVER (PARTITION BY tipo, mes ORDER BY anio)   AS anio_base,
        lag(viajes) OVER (PARTITION BY tipo, mes ORDER BY anio)   AS viajes_base
    FROM por_mes
)
SELECT
    mes,
    tipo || ' ' || anio || ' vs ' || anio_base           AS serie,
    viajes_base,
    viajes,
    round(100.0 * viajes / viajes_base - 100, 1)         AS variacion_pct
FROM comparados
WHERE viajes_base IS NOT NULL
ORDER BY serie DESC, mes;
