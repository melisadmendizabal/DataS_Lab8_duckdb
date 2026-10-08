-- Indicador 8 - Velocidad mediana de los viajes dentro de Manhattan por hora
-- Pregunta: P8. ¿Que tan congestionado esta el trafico a cada hora y cambio
--           la velocidad despues de la tarifa de congestion de 2025?
-- Indicador: mediana de distancia / duracion (millas por hora) de los
--           viajes yellow que empiezan y terminan en Manhattan, en dias
--           laborables, por hora y anio. La velocidad del taxi es una medida
--           indirecta del trafico.
-- Fuente:   data/processed/taxis.duckdb, vista viajes_validos + tabla zonas
-- Nota:     el cargo CBD (enero de 2025) se cobra al entrar a Manhattan al sur
--           de la calle 60, por lo que Manhattan es donde deberia notarse un
--           cambio. Se excluyen viajes de menos de 1 minuto o con velocidad
--           mayor a 60 mph (errores de registro). Solo meses publicados en
--           todos los anios (hoy enero-agosto): el trafico es estacional.
-- Visualizacion: lineas; x = hora, y = velocidad_mediana_mph, serie = anio.
WITH meses_comunes AS (
    -- meses publicados en todos los anios cargados (hoy enero-agosto)
    SELECT substr(mes_archivo, 6, 2) AS mes
    FROM viajes
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM viajes)
)
SELECT
    hour(v.inicio)                                         AS hora,
    CAST(v.anio AS VARCHAR)                                AS anio,
    count(*)                                               AS viajes,
    round(median(v.distancia / (v.duracion_min / 60)), 1)  AS velocidad_mediana_mph
FROM viajes_validos AS v
JOIN zonas AS zo ON zo.id_zona = v.origen
JOIN zonas AS zd ON zd.id_zona = v.destino
WHERE v.tipo = 'yellow'
  AND zo.distrito = 'Manhattan'
  AND zd.distrito = 'Manhattan'
  AND isodow(v.inicio) <= 5
  AND v.duracion_min >= 1
  AND v.distancia / (v.duracion_min / 60) <= 60
  AND substr(v.mes_archivo, 6, 2) IN (SELECT mes FROM meses_comunes)
GROUP BY ALL
ORDER BY anio, hora;
