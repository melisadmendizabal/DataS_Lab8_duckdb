-- Indicador 4 - Composicion del cobro promedio por viaje
-- Pregunta: P4. ¿Que componentes explican lo que se cobra por un viaje y
--           cuanto aporta el cargo por congestion (CBD) introducido en 2025?
-- Indicador: promedio por viaje, en USD, de cada componente de total_amount:
--           tarifa base, propina, peajes, cargo de aeropuerto, cargo CBD y
--           otros recargos (extra, MTA, mejora, congestion_surcharge = el
--           resto del total).
-- Fuente:   data/processed/taxis.duckdb, vista viajes_validos
-- Nota:     solo yellow y solo los meses publicados en TODOS los anios
--           cargados (hoy enero-agosto), para comparar periodos equivalentes.
--           Los cargos ausentes (NULL, p. ej. CBD en 2024) cuentan como 0.
-- Visualizacion: barras apiladas; x = anio, y = usd_promedio, serie = componente.
WITH meses_comunes AS (
    SELECT substr(mes_archivo, 6, 2) AS mes
    FROM viajes
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM viajes)
),
promedios AS (
    SELECT
        CAST(anio AS VARCHAR)                                              AS anio,
        avg(tarifa)                                                        AS "1 Tarifa base",
        avg(propina)                                                       AS "2 Propina",
        avg(peajes)                                                        AS "3 Peajes",
        avg(coalesce(cargo_aeropuerto, 0))                                 AS "4 Cargo aeropuerto",
        avg(coalesce(cargo_cbd, 0))                                        AS "5 Cargo congestion CBD",
        avg(total - tarifa - propina - peajes
            - coalesce(cargo_aeropuerto, 0) - coalesce(cargo_cbd, 0))      AS "6 Otros recargos"
    FROM viajes_validos
    WHERE tipo = 'yellow'
      AND substr(mes_archivo, 6, 2) IN (SELECT mes FROM meses_comunes)
    GROUP BY anio
)
SELECT anio, componente, round(usd_promedio, 2) AS usd_promedio
FROM (UNPIVOT promedios ON COLUMNS(* EXCLUDE (anio)) INTO NAME componente VALUE usd_promedio)
ORDER BY anio, componente;
