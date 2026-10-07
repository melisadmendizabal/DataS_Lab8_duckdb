-- Ejercicio 4 - Pregunta 5 (distribucion): tarifa por milla y velocidad segun la hora
-- Objetivo: verificar si una milla cuesta mas en las horas de mayor trafico.
--           El taximetro cobra por distancia y tambien por tiempo detenido o
--           a baja velocidad, por lo que la congestion deberia encarecer la
--           milla. Se acompania de la velocidad mediana como medida de trafico.
-- Fuente:   vista viajes_validos (00_vistas.sql)
-- Nota:     solo yellow, tarifa estandar (codigo_tarifa = 1) y viajes de
--           1 a 5 millas, para comparar viajes de longitud parecida y aislar
--           el efecto de la hora del efecto de la distancia (consulta 17).
SELECT
    CASE WHEN isodow(inicio) >= 6 THEN 'Fin de semana' ELSE 'Laborable' END  AS tipo_dia,
    hour(inicio)                                                              AS hora,
    count(*)                                                                  AS viajes,
    round(median(tarifa / distancia), 2)                                      AS usd_por_milla_mediana,
    round(median(distancia / (duracion_min / 60)), 1)                         AS velocidad_mediana_mph
FROM viajes_validos
WHERE tipo = 'yellow'
  AND codigo_tarifa = 1
  AND tarifa > 0
  AND distancia BETWEEN 1 AND 5
GROUP BY tipo_dia, hora
ORDER BY tipo_dia DESC, hora;
