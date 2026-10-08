-- Ejercicio 5.6 - Proveedores (VendorID) por anio
-- Objetivo: comparar la participacion de cada proveedor en 2024 y 2026 y su
--           tasa de viajes con duracion cero, para saber si la advertencia
--           del Ejercicio 4 (Helix, VendorID 7, registra fin = inicio en el
--           100% de sus viajes y queda fuera de viajes_validos) aplica a 2024.
-- Fuente:   vista viajes (sql/04_analisis/00_vistas.sql, todos los anios)
-- Nota:     proveedores: 1 Creative Mobile Technologies, 2 Curb Mobility,
--           6 Myle Technologies, 7 Helix.
SELECT
    tipo,
    anio,
    proveedor,
    count(*)                                                                  AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo, anio), 2) AS pct_viajes,
    round(100.0 * count(*) FILTER (WHERE fin <= inicio) / count(*), 2)        AS pct_duracion_cero
FROM viajes
GROUP BY tipo, anio, proveedor
ORDER BY tipo DESC, anio, proveedor;
