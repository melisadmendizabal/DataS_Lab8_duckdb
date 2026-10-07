-- Ejercicio 3.6 - Consistencia de total_amount con sus componentes
-- Objetivo: verificar si total_amount es igual a la suma de los cargos que lo
--           componen y, si no lo es, identificar los patrones de diferencia.
-- Fuente:   data/raw/yellow/2026/*.parquet
WITH diferencias AS (
    SELECT
        payment_type,
        round(total_amount - (fare_amount + extra + mta_tax + tip_amount
              + tolls_amount + improvement_surcharge
              + coalesce(congestion_surcharge, 0) + coalesce(Airport_fee, 0)
              + coalesce(cbd_congestion_fee, 0)), 2) AS diferencia
    FROM read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)
)
SELECT
    payment_type,
    diferencia,
    count(*)                                                AS filas,
    round(100.0 * count(*) / sum(count(*)) OVER (), 2)      AS pct_del_total
FROM diferencias
GROUP BY payment_type, diferencia
QUALIFY row_number() OVER (ORDER BY count(*) DESC) <= 10
ORDER BY filas DESC;
