-- Ejercicio 6 - Benchmark B1: conteo y monto por tipo y mes
-- Objetivo: consulta mas simple posible sobre todas las filas (recorrido
--           completo de pocas columnas y agregacion con pocos grupos). Mide
--           el costo base de leer los datos en cada estrategia.
-- Fuente:   vista/tabla viajes (Parquet: 00_vistas.sql; tabla: materializar.py)
-- Nota:     el monto se redondea en millones para que la comparacion de
--           resultados entre estrategias no dependa del orden de suma.
SELECT
    tipo,
    mes_archivo,
    count(*)                         AS viajes,
    round(sum(total) / 1e6, 2)       AS total_millones_usd
FROM viajes
GROUP BY tipo, mes_archivo
ORDER BY tipo DESC, mes_archivo;
