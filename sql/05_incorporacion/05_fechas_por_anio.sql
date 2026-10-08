-- Ejercicio 5.6 - Fechas de los viajes segun el anio del archivo
-- Objetivo: verificar, con la vista viajes, que los viajes de cada archivo
--           pertenecen a su mes y anio, igual que la consulta 10 del
--           Ejercicio 3 pero para los dos anios.
-- Fuente:   vista viajes (sql/04_analisis/00_vistas.sql, todos los anios)
-- Nota:     requiere ejecutar antes sql/04_analisis/00_vistas.sql sin
--           --periodo (ver README).
SELECT
    tipo,
    anio,
    CASE
        WHEN strftime(inicio, '%Y-%m') = mes_archivo THEN '1 mes del archivo'
        WHEN year(inicio) = anio                     THEN '2 otro mes del mismo anio'
        WHEN year(inicio) = anio - 1                 THEN '3 anio anterior'
        ELSE                                              '4 otro anio'
    END                                                                     AS ubicacion,
    count(*)                                                                AS filas,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo, anio), 4) AS pct,
    min(inicio)                                                             AS minimo,
    max(inicio)                                                             AS maximo
FROM viajes
GROUP BY tipo, anio, ubicacion
ORDER BY tipo DESC, anio, ubicacion;
