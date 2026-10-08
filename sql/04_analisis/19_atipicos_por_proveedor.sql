-- Ejercicio 4 - Pregunta 6 (atipicos): concentracion de inconsistencias por proveedor
-- Objetivo: calcular, para cada proveedor (VendorID) de cada tipo de taxi,
--           el porcentaje de sus viajes que rompe cada regla de calidad del
--           Ejercicio 3, para saber si los errores son generales o vienen de
--           un sistema de registro en particular.
-- Fuente:   vista viajes (00_vistas.sql; SIN filtrar, se buscan los invalidos)
-- Nota:     proveedores: 1 Creative Mobile Technologies, 2 Curb Mobility,
--           6 Myle Technologies, 7 Helix. Las reglas no son excluyentes.
--           'participacion_en_regla' = de todos los viajes que rompen la regla
--           (en ese tipo de taxi), que porcentaje aporta el proveedor.
WITH reglas AS (
    SELECT
        tipo,
        proveedor,
        year(inicio) <> anio                         AS "1 fecha fuera del anio",
        fin <= inicio                                AS "2 duracion cero o negativa",
        fin - inicio > INTERVAL 24 HOUR              AS "3 duracion mayor a 24 h",
        distancia = 0                                AS "4 distancia cero",
        distancia > 100                              AS "5 distancia mayor a 100 mi",
        total < 0                                    AS "6 total negativo",
        pasajeros = 0                                AS "7 cero pasajeros",
        origen IN (264, 265) OR destino IN (264, 265) AS "8 zona desconocida"
    FROM viajes
),
largo AS (
    FROM reglas
    UNPIVOT (incumple FOR regla IN (COLUMNS(* EXCLUDE (tipo, proveedor))))
),
por_proveedor AS (
    SELECT
        tipo,
        proveedor,
        regla,
        count(*)                                  AS viajes_proveedor,
        count(*) FILTER (WHERE incumple)          AS viajes_incumplen
    FROM largo
    GROUP BY ALL
)
SELECT
    tipo,
    regla,
    proveedor,
    viajes_proveedor,
    viajes_incumplen,
    round(100.0 * viajes_incumplen / viajes_proveedor, 3)                          AS pct_de_sus_viajes,
    round(100.0 * viajes_incumplen / nullif(sum(viajes_incumplen) OVER (PARTITION BY tipo, regla), 0), 1)
                                                                                    AS participacion_en_regla,
    round(100.0 * viajes_proveedor / sum(viajes_proveedor) OVER (PARTITION BY tipo, regla), 1)
                                                                                    AS participacion_en_viajes
FROM por_proveedor
ORDER BY tipo DESC, regla, proveedor;
