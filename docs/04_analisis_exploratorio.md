# Ejercicio 4 - Analisis exploratorio con DuckDB

Analisis exploratorio de los viajes de taxis amarillos (yellow) y verdes (green)
de **enero a agosto de 2026** (30,040,469 viajes), consultando directamente los
archivos Parquet con DuckDB.

| Elemento | Ubicacion |
|----------|-----------|
| Consultas SQL (una por archivo, con objetivo y fuente en el encabezado) | [`sql/04_analisis/`](../sql/04_analisis/) |
| Notebook con resultados y graficos | [`notebooks/04_analisis_exploratorio.ipynb`](../notebooks/04_analisis_exploratorio.ipynb) |
| Figuras | [`docs/figuras/ej4_*.png`](figuras/) |

Para reproducir:

```bash
docker exec lab8-lab python scripts/download_data.py          # datos + tabla de zonas
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis   # todas las consultas
# o ejecutar el notebook (genera tambien las figuras):
docker exec -w /workspace/notebooks lab8-lab jupyter nbconvert --to notebook --execute --inplace 04_analisis_exploratorio.ipynb
```

Resultados obtenidos el 07-oct-2026 con DuckDB 1.5.5.

---

## Preparacion: vistas base y datos adicionales

### Tabla de zonas

Para interpretar `PULocationID` / `DOLocationID` se agrego a
`scripts/download_data.py` la descarga de la tabla de zonas de la TLC
(`taxi_zone_lookup.csv`, 265 zonas) en `data/raw/zones/`. Se descarga una sola
vez y se valida su encabezado.

### Vistas ([`00_vistas.sql`](../sql/04_analisis/00_vistas.sql))

Todas las consultas usan cuatro vistas **temporales** definidas en un solo
archivo, de modo que las transformaciones quedan registradas en un unico
lugar. Son vistas, no tablas: no copian datos y cada consulta vuelve a leer los
Parquet.

| Vista | Contenido | Transformacion |
|-------|-----------|----------------|
| `viajes` | yellow + green, 2026 | Renombra columnas a nombres comunes en espanol (`tpep_*`/`lpep_*` -> `inicio`/`fin`, etc.), agrega `tipo`, `duracion_min` y `mes_archivo`. Columnas exclusivas de un tipo quedan en NULL en el otro. |
| `viajes_validos` | `viajes` sin registros invalidos | Excluye: fechas fuera de 2026, duracion <= 0 o > 24 h, distancia = 0 o > 100 mi, tarifa o total negativos (reglas del Ejercicio 3). |
| `zonas` | `taxi_zone_lookup.csv` | `LocationID` -> `distrito`, `zona`. |
| `metodos_pago` | 7 filas | Nombres de los codigos de `payment_type` segun el diccionario de la TLC. |

```sql
CREATE OR REPLACE TEMP VIEW viajes_validos AS
SELECT *
FROM viajes
WHERE year(inicio) = 2026                     -- fechas de otros anios (2001, 2008, ...)
  AND fin > inicio                            -- duracion cero o negativa
  AND fin - inicio <= INTERVAL 24 HOUR        -- duracion imposible
  AND distancia > 0                           -- distancia cero
  AND distancia <= 100                        -- errores de odometro (hasta 328,522 mi)
  AND tarifa >= 0                             -- reversiones / disputas
  AND total >= 0;
```

| tipo | viajes | viajes validos | % validos |
|------|-------:|---------------:|----------:|
| yellow | 29,703,355 | 28,242,805 | 95.08 |
| green | 337,114 | 324,231 | 96.18 |

**Decisiones:**

- No se excluyen los nulos estructurales (Flex Fare / `payment_type` NULL) ni
  las zonas 264/265: cada consulta decide si los necesita.
- Las preguntas sobre la **mezcla de metodos de pago** (consulta 12) y sobre
  **valores atipicos** (19-21) usan `viajes` y no `viajes_validos`, porque
  justamente estudian los registros que la limpieza elimina.
- **Advertencia descubierta en la Pregunta 6:** el proveedor Helix
  (`VendorID = 7`, 1.2% de yellow) registra la hora de fin igual a la de inicio
  en el 100% de sus viajes, por lo que `viajes_validos` **no contiene ningun
  viaje de Helix**. Los resultados de las preguntas 1 a 5 describen a los
  demas proveedores.

---

## 4.1 Preguntas planteadas

| # | Pregunta | Eje del enunciado | Justificacion a partir de los datos |
|---|----------|-------------------|-------------------------------------|
| 1 | ¿Como se distribuye la demanda por hora y por dia de la semana, y cambia el patron horario entre dias laborables y fines de semana? | Comportamiento temporal | El volumen mensual es estable (3.3-4.1 M viajes yellow por mes), asi que la variacion relevante esta dentro de la semana y del dia. Tarifa, propina y velocidad dependen de la hora, por lo que este patron es la base de las demas preguntas. |
| 2 | ¿Cuales son las zonas con mas viajes de origen y destino, y que caracteriza a los viajes de aeropuerto? | Caracteristicas de los viajes | Cada viaje tiene zona de origen y destino, y el diccionario define una tarifa fija (`RatecodeID = 2`, JFK) y un cargo (`Airport_fee`) exclusivos de aeropuerto: los aeropuertos son un segmento con reglas propias. |
| 3 | En los taxis verdes, ¿en que se diferencian los viajes tomados en la calle de los despachados? | Diferencias yellow/green | `trip_type` solo existe en green y separa dos formas de conseguir un viaje. El 14.5% de green no tiene `trip_type` (Ejercicio 3), lo que agrega un tercer grupo a explicar. |
| 4 | ¿Como pagan los pasajeros, como cambia la propina segun el metodo de pago y de que depende la propina con tarjeta (hora, dia, distancia, pasajeros)? | Variables de pago | El 26% de yellow es "Flex Fare", un metodo poco documentado que ademas explica los nulos de cinco columnas. La propina es la variable de pago con mayor variacion y su registro depende del medio de pago. |
| 5 | ¿Cuanto cuesta una milla segun la distancia del viaje y segun la hora? | Distribucion de valores relevantes | La mediana de distancia (1.86 mi) es muy inferior al promedio (5.55 mi); la tarifa combina un cargo inicial, un cobro por distancia y otro por tiempo, por lo que el precio por milla no deberia ser constante ni independiente del trafico. |
| 6 | ¿Las inconsistencias se concentran en algun proveedor o mes? | Valores atipicos e inconsistencias | El Ejercicio 3 cuantifico las inconsistencias pero no su origen. Cada `VendorID` es un sistema de registro distinto; si un error se concentra en uno, es un problema de captura y condiciona la limpieza. |

## 4.2 / 4.3 Consultas construidas

Cada archivo contiene en su encabezado el objetivo, la fuente y las notas de
metodo; aqui se resume su funcion. Todas leen los Parquet a traves de las vistas
de `00_vistas.sql`.

| Archivo | Pregunta | Objetivo | Fuente (vista) | Tecnica relevante |
|---------|:--------:|----------|----------------|-------------------|
| [`00_vistas.sql`](../sql/04_analisis/00_vistas.sql) | - | Vistas base y resumen de la limpieza | Parquet + CSV de zonas | `CREATE TEMP VIEW`, `UNION ALL`, `read_csv` |
| [`01_viajes_por_dia_semana.sql`](../sql/04_analisis/01_viajes_por_dia_semana.sql) | 1 | Viajes promedio por dia de la semana | `viajes_validos` | Promedio por **fecha** (no total) para no sesgar por dias que aparecen mas veces |
| [`02_viajes_por_hora.sql`](../sql/04_analisis/02_viajes_por_hora.sql) | 1 | Perfil horario laborable vs fin de semana | `viajes_validos` | Normaliza por numero de fechas de cada tipo de dia |
| [`03_mapa_calor_dia_hora.sql`](../sql/04_analisis/03_mapa_calor_dia_hora.sql) | 1 | Matriz dia x hora | `viajes_validos` | Formato largo, se pivotea en el notebook |
| [`04_franjas_extremas.sql`](../sql/04_analisis/04_franjas_extremas.sql) | 1 | 5 franjas de mayor y menor demanda | `viajes_validos` | `row_number()` en ambos sentidos |
| [`05_zonas_principales.sql`](../sql/04_analisis/05_zonas_principales.sql) | 2 | Top 10 zonas de origen y destino | `viajes_validos`, `zonas` | `JOIN` con zonas, % acumulado con ventana |
| [`06_viajes_por_distrito.sql`](../sql/04_analisis/06_viajes_por_distrito.sql) | 2 | Origenes por distrito | `viajes_validos`, `zonas` | |
| [`07_viajes_aeropuerto.sql`](../sql/04_analisis/07_viajes_aeropuerto.sql) | 2 | Viajes desde/hacia JFK, LaGuardia y Newark vs el resto | `viajes_validos`, `zonas` | Medianas, % de ingresos con ventana |
| [`08_aeropuerto_por_hora.sql`](../sql/04_analisis/08_aeropuerto_por_hora.sql) | 2 | Perfil horario de los viajes de aeropuerto | `viajes_validos` | |
| [`09_green_tipo_viaje.sql`](../sql/04_analisis/09_green_tipo_viaje.sql) | 3 | Calle vs despacho vs sin registro | `viajes_validos` | Agregados con `FILTER` |
| [`10_green_tipo_viaje_por_hora.sql`](../sql/04_analisis/10_green_tipo_viaje_por_hora.sql) | 3 | Perfil horario por tipo de viaje | `viajes_validos` | |
| [`11_green_tipo_viaje_zonas.sql`](../sql/04_analisis/11_green_tipo_viaje_zonas.sql) | 3 | Top 5 zonas de origen por tipo de viaje | `viajes_validos`, `zonas` | |
| [`12_metodos_pago_por_mes.sql`](../sql/04_analisis/12_metodos_pago_por_mes.sql) | 4 | Mezcla de metodos de pago por mes | `viajes`, `metodos_pago` | Usa `viajes` para no perder disputas |
| [`13_flex_fare_origen_solicitud.sql`](../sql/04_analisis/13_flex_fare_origen_solicitud.sql) | 4 | Origen de los viajes Flex Fare (jun-ago) | `viajes_validos` | Usa la columna nueva `request_source` |
| [`14_propina_por_metodo.sql`](../sql/04_analisis/14_propina_por_metodo.sql) | 4 | Propina segun metodo de pago | `viajes_validos` | % de propina sobre el monto antes de ella |
| [`15_propina_por_hora_y_dia.sql`](../sql/04_analisis/15_propina_por_hora_y_dia.sql) | 4 | Propina con tarjeta por hora y tipo de dia | `viajes_validos` | Porcentaje recortado a [0, 100] |
| [`16_propina_por_distancia_y_pasajeros.sql`](../sql/04_analisis/16_propina_por_distancia_y_pasajeros.sql) | 4 | Propina con tarjeta por distancia y pasajeros | `viajes_validos` | |
| [`17_tarifa_por_milla_por_distancia.sql`](../sql/04_analisis/17_tarifa_por_milla_por_distancia.sql) | 5 | USD por milla segun la distancia | `viajes_validos` | Solo tarifa estandar; mediana y P25-P75 |
| [`18_tarifa_por_milla_por_hora.sql`](../sql/04_analisis/18_tarifa_por_milla_por_hora.sql) | 5 | USD por milla y velocidad segun la hora | `viajes_validos` | Viajes de 1-5 mi para aislar el efecto de la hora |
| [`19_atipicos_por_proveedor.sql`](../sql/04_analisis/19_atipicos_por_proveedor.sql) | 6 | % de cada regla rota por proveedor | `viajes` | `UNPIVOT` de reglas booleanas |
| [`20_atipicos_por_mes.sql`](../sql/04_analisis/20_atipicos_por_mes.sql) | 6 | Evolucion mensual de errores por proveedor | `viajes` | Agrupa por mes del archivo |
| [`21_distancias_extremas.sql`](../sql/04_analisis/21_distancias_extremas.sql) | 6 | Perfil de los viajes > 100 mi | `viajes` | Velocidad implicita |

**Criterios comunes:**

- **Medianas en lugar de promedios** para distancia, duracion y montos, por las
  colas largas observadas en el Ejercicio 3.
- **Propina solo con tarjeta** cuando se analiza su magnitud: en efectivo
  practicamente nunca se registra (Pregunta 4), y mezclarlo confundiria
  comportamiento con forma de registro.
- **Promedios por fecha** en los analisis temporales, para que un dia de la
  semana o una hora no pesen mas solo por aparecer mas veces.

---

## 4.4 Resultados

### Pregunta 1 - Comportamiento temporal

![Viajes por dia de la semana](figuras/ej4_p1_dia_semana.png)

| Dia | yellow: viajes promedio | vs. dia promedio | green: viajes promedio | vs. dia promedio |
|-----|------------------------:|-----------------:|-----------------------:|-----------------:|
| Lun | 95,920 | -17.5% | 1,322 | -1.0% |
| Mar | 113,187 | -2.6% | 1,443 | +8.0% |
| Mie | 120,647 | +3.8% | 1,496 | +12.1% |
| Jue | 127,450 | +9.7% | 1,532 | **+14.7%** |
| Vie | 120,689 | +3.8% | 1,388 | +4.0% |
| Sab | 128,672 | **+10.7%** | 1,113 | -16.7% |
| Dom | 107,054 | -7.9% | 1,053 | **-21.1%** |

![Viajes por hora](figuras/ej4_p1_por_hora.png)

![Mapa de calor dia x hora](figuras/ej4_p1_mapa_calor.png)

**Explicacion:**

- **Yellow es un servicio de tarde-noche y de fin de semana.** Su dia mas
  fuerte es el sabado y sus franjas de mayor demanda son jueves 21 h
  (8,583 viajes por hora en promedio, 1.77 veces la franja promedio), sabado
  18 h y miercoles 21 h. En laborables el pico es 18 h y se mantiene alto hasta
  las 22 h.
- **Green sigue un patron de horario laboral.** Su pico es de martes a jueves a
  las 17 h (jueves 17 h: 2.31 veces la franja promedio), con un segundo pico a
  las 8 h, y cae 17-21% el fin de semana. Es un servicio de traslados
  cotidianos, no de ocio.
- **La madrugada del fin de semana es otro mercado.** En yellow, entre las 0 y
  las 3 h ocurre el 16.2% de los viajes de un dia de fin de semana frente al
  4.3% en laborables; a medianoche hay 2.8 veces mas viajes un sabado/domingo
  que un dia laborable. En cambio, la hora punta de la manana (8 h) casi
  desaparece el fin de semana (5,710 vs 2,333).
- La franja de menor demanda es martes 3 h (284 viajes yellow por hora, 30
  veces menos que la mayor).
- **El lunes es el dia mas bajo de yellow (-17.5%) y no se explica por los
  feriados:** sin los tres lunes feriados del periodo (19-ene, 16-feb, 25-may)
  el promedio apenas sube de 95,920 a 97,140. Si pesan dias con caidas
  extremas: el lunes 23-feb tuvo solo 22,852 viajes yellow (77% menos que un
  lunes tipico) y el domingo 25 y lunes 26 de enero 43,552 y 62,987. Estos
  dias son candidatos a eventos externos (por ejemplo, clima); no se verifico
  la causa con otra fuente.

### Pregunta 2 - Zonas y viajes de aeropuerto

![Zonas con mas viajes de origen](figuras/ej4_p2_zonas_origen.png)

| Distrito de origen | yellow | green |
|--------------------|-------:|------:|
| Manhattan | **86.63%** | 59.44% |
| Queens | 8.85% | 22.07% |
| Brooklyn | 3.60% | 15.81% |
| Bronx | 0.78% | 2.49% |
| Otros / desconocido | 0.14% | 0.20% |

- **Yellow esta repartido por Manhattan:** sus 10 zonas de origen principales
  (Upper East Side, Midtown, Penn Station, Times Square...) suman solo el 33.7%
  de los viajes. La unica zona fuera de Manhattan en el top es **JFK (3.99%,
  tercera)**.
- **Green esta muy concentrado:** East Harlem North (26.95%) y East Harlem South
  (12.96%) concentran el 40% de los origenes. Green no puede recoger pasajeros
  en la calle en el centro de Manhattan, y su operacion se ubica en el borde de
  esa zona y en Queens y Brooklyn (38% de sus origenes, frente a 12% de yellow).

![Peso de los viajes de aeropuerto](figuras/ej4_p2_aeropuertos.png)

| yellow | % viajes | % ingresos | distancia mediana | duracion mediana | total mediano | % tarifa fija JFK |
|--------|---------:|-----------:|------------------:|-----------------:|--------------:|------------------:|
| Desde JFK | 3.99 | **10.49** | 16.90 mi | 40.1 min | 86.75 | 45.4 |
| Desde LaGuardia | 2.54 | 5.92 | 9.36 mi | 29.4 min | 69.94 | 0.5 |
| Hacia LaGuardia | 0.82 | 1.91 | 9.90 mi | 28.0 min | 69.91 | 0.2 |
| Hacia JFK | 0.64 | 1.97 | 16.99 mi | 50.4 min | 95.46 | 67.7 |
| Hacia Newark | 0.17 | 0.74 | 17.36 mi | 37.5 min | 131.70 | 0.1 |
| Sin aeropuerto | 91.83 | 78.96 | 1.78 mi | 13.3 min | 22.45 | 0.1 |

- **Los viajes de aeropuerto son el 8.2% de los viajes yellow pero el 21.0% de
  los ingresos** (`total_amount`): un viaje desde JFK cuesta en mediana 86.75
  USD, casi cuatro veces un viaje sin aeropuerto (22.45 USD).
- **Asimetria:** salen de los aeropuertos 1.84 M viajes yellow y llegan solo
  0.46 M (4 veces menos). Al aeropuerto la gente llega por otros medios (auto,
  aplicaciones, transporte publico), pero al salir usa la fila de taxis.
- La tarifa mediana desde/hacia JFK es exactamente **70.00 USD**, la tarifa
  fija JFK-Manhattan; solo el 45% de los viajes desde JFK usa `RatecodeID = 2`
  porque la tarifa fija aplica unicamente a destinos en Manhattan.
- **Horario:** los viajes hacia el aeropuerto empiezan temprano (desde las
  5 h) y alcanzan su maximo a las 14 h (9.2% del grupo); casi no existen
  despues de las 20 h. Los viajes desde el aeropuerto crecen desde el mediodia
  y se mantienen altos hasta la medianoche (llegadas de vuelos).

  ![Perfil horario de aeropuerto](figuras/ej4_p2_aeropuerto_hora.png)

- **Anomalia:** 913 viajes yellow "desde Newark" tienen distancia mediana de
  0.05 mi y duracion de 0.2 min con una tarifa mediana de 114 USD. Los taxis
  amarillos no recogen pasajeros en Newark (Nueva Jersey), y un viaje de 0.05 mi
  no cuesta 114 USD: son registros con la zona de origen y la distancia mal
  capturadas (probablemente el cobro de un viaje hacia Newark registrado al
  llegar). Se mantienen en los conteos porque son pocos, pero no son viajes
  reales desde Newark.
- En green, los aeropuertos son casi solo destino: 8,326 viajes hacia
  LaGuardia frente a 73 desde LaGuardia (green no puede recoger en aeropuertos).

### Pregunta 3 - Taxis verdes: calle vs despacho

| | Calle (`trip_type = 1`) | Despacho (`trip_type = 2`) | Sin registro (NULL) |
|---|---:|---:|---:|
| Viajes | 266,102 | 10,452 | 47,677 |
| % de green | 82.07 | 3.22 | 14.70 |
| Distancia mediana | 1.93 mi | 4.05 mi | 5.01 mi |
| Duracion mediana | 12.3 min | 15.0 min | 25.9 min |
| Tarifa mediana (`fare_amount`) | 13.50 | **40.00** | 3.00 |
| Total mediano | 19.60 | 49.20 | 26.47 |
| % tarifa negociada (`RatecodeID = 5`) | 0.7 | **99.8** | 0.0 |
| % tarjeta / % efectivo | 76.6 / 23.1 | 84.3 / 14.2 | 0 / 0 (sin `payment_type`) |
| Propina mediana con tarjeta | 20.0% | 13.0% | - |
| % proveedor Myle (`VendorID = 6`) | 0.0 | 0.0 | **73.1** |
| Top 5 zonas de origen (% acumulado) | 61.8 (East Harlem N+S: 47.0) | 35.2 (Jamaica, Flushing Meadows, Downtown Brooklyn...) | 17.8 (Harlem y East Harlem) |

![Perfil horario green](figuras/ej4_p3_green_hora.png)

**Explicacion:**

- **Calle:** el green "clasico": viajes cortos (1.9 mi), concentrados en East
  Harlem (47% de los origenes) y en horario de tarde (pico 17 h). Es el grupo
  con mas pago en efectivo (23%).
- **Despacho:** un producto distinto. El 99.8% usa **tarifa negociada**
  (precio acordado de antemano), cuesta tres veces mas (40 USD de mediana),
  recorre el doble y se origina en Queens y Brooklyn, de forma dispersa. Su
  perfil horario es **nocturno**: el maximo es a las 22 h (9.4% de sus viajes)
  y es el unico grupo con actividad relevante de 0 a 3 h. Funciona como un
  servicio de auto por encargo (car service) y deja menos propina (13%).
- **Sin registro:** no es un error aleatorio, es un tercer canal. El 73% es del
  proveedor Myle, no tiene `trip_type`, `payment_type` ni pasajeros, viaja de
  dia (pico 8-13 h), es el grupo mas largo (25.9 min) y, desde junio, el 39%
  trae `request_source` de aplicacion (`A`, `HV0005`). Su `fare_amount`
  mediano es 3.00 USD con un total de 26.47 USD: en este grupo `fare_amount` no
  representa la tarifa real y **no debe usarse**; es el equivalente en green de
  los viajes Flex Fare de yellow (Pregunta 4).

### Pregunta 4 - Pago y propinas

![Metodos de pago por mes](figuras/ej4_p4_metodos_pago.png)

- **Yellow:** tarjeta 60-69%, **Flex Fare 21-30%**, efectivo 8-10% y disputas
  + sin cargo cerca del 1%. Flex Fare bajo de 29% en enero a 21% en abril y
  volvio a 28% en agosto; la tarjeta hizo el movimiento contrario.
- **Green:** tarjeta ~65%, efectivo ~19-20% (el doble que yellow) y "sin dato"
  13-16%. La mezcla es estable todos los meses.

**¿Que es Flex Fare?** (yellow, junio-agosto, consulta 13)

| Origen de la solicitud (`request_source`) | % de Flex Fare | distancia mediana | total mediano | % con propina |
|-------------------------------------------|---------------:|------------------:|--------------:|--------------:|
| HV0003 | **79.25** | 3.03 mi | 28.54 | 2.0 |
| A | 13.77 | 3.70 mi | 29.90 | 38.2 |
| HV0005 | 6.15 | 4.87 mi | 30.03 | 0.0 |
| EH0004, CC, otros | 0.83 | | | |

`request_source` **solo tiene valor en los viajes Flex Fare** (en tarjeta y
efectivo siempre es NULL). El 85% de ellos viene de `HV0003` y `HV0005`, que son
los codigos de licencia de la TLC para Uber y Lyft. Flex Fare corresponde
entonces a **viajes de taxi amarillo solicitados y pagados a traves de una
aplicacion**, con precio acordado de antemano. Esto explica por que esos viajes
no tienen pasajeros, `RatecodeID` ni recargos registrados (Ejercicio 3) y por
que casi nunca registran propina (la propina de la aplicacion no pasa por el
taximetro).

**Propina segun el metodo de pago** (consulta 14):

| tipo | metodo | viajes | con propina | % con propina | propina mediana (si hay) | % mediano (si hay) |
|------|--------|-------:|------------:|--------------:|-------------------------:|-------------------:|
| yellow | Tarjeta | 18,461,107 | 16,821,288 | **91.12** | 3.51 USD | **20.0%** |
| yellow | Flex Fare | 7,044,806 | 582,448 | 8.27 | 3.94 USD | 16.5% |
| yellow | Efectivo | 2,560,893 | **172** | **0.01** | 3.59 USD | 20.0% |
| green | Tarjeta | 212,519 | 194,105 | 91.34 | 3.35 USD | 20.0% |
| green | Efectivo | 62,931 | 0 | 0.00 | - | - |
| green | Sin dato (NULL) | 47,677 | 7,364 | 15.45 | 3.90 USD | 19.8% |

- Con tarjeta, 9 de cada 10 viajes dejan propina y la mediana es **exactamente
  20%**, que coincide con uno de los porcentajes sugeridos en la pantalla de pago.
- **En efectivo la propina no se registra** (172 de 2.56 M viajes). No es que
  no se de propina: el dataset no la captura. Cualquier "propina promedio" que
  incluya efectivo esta subestimada.

![Propina por hora](figuras/ej4_p4_propina_hora.png)

![Propina por distancia](figuras/ej4_p4_propina_distancia.png)

**Propina con tarjeta (yellow):**

- **Hora:** el porcentaje de viajes con propina cae de ~94% (20-21 h) a **72%**
  entre las 4 y 5 h de un dia laborable, y la propina promedio de 17.6% a 13.2%.
  Entre las 8 y las 23 h el porcentaje es estable (16.3-17.6%).
- **Distancia:** la propina en dolares crece con la distancia (2.39 USD en
  viajes < 1 mi, 16.29 USD en >= 20 mi), pero **como porcentaje baja** (18.2% ->
  13.8%) y tambien baja la proporcion de viajes con propina (94% -> 79%). En
  viajes largos (aeropuertos, tarifas altas) los pasajeros eligen montos
  menores en porcentaje.
- **Pasajeros:** casi no influye (16.9% con 1 pasajero, 17.6% con 2, 17.8% con 5
  o mas).

### Pregunta 5 - Tarifa por milla

![Tarifa por milla segun la distancia](figuras/ej4_p5_tarifa_por_milla.png)

| Distancia (yellow, tarifa estandar) | viajes | tarifa mediana | USD por milla (mediana) | P25 - P75 |
|-------------------------------------|-------:|---------------:|------------------------:|----------:|
| < 0.5 mi | 965,099 | 5.10 | **14.87** | 12.61 - 19.75 |
| 0.5-1 mi | 4,150,015 | 7.90 | 10.20 | 8.89 - 12.15 |
| 1-2 mi | 6,853,251 | 11.40 | 8.01 | 7.10 - 9.43 |
| 2-3 mi | 3,045,640 | 16.30 | 6.78 | 6.05 - 7.80 |
| 3-5 mi | 2,051,227 | 21.90 | 5.87 | 5.26 - 6.68 |
| 5-10 mi | 1,635,982 | 34.50 | 4.70 | 4.29 - 5.24 |
| 10-20 mi | 711,244 | 52.00 | 4.20 | 3.96 - 4.55 |
| >= 20 mi | 56,546 | 93.30 | **3.80** | 3.70 - 3.98 |

- Una milla cuesta **casi 4 veces mas en un viaje de menos de media milla
  (14.87 USD) que en uno de mas de 20 mi (3.80 USD)**. El cargo inicial fijo se
  reparte entre pocas millas en los viajes cortos, y el precio por milla se
  estabiliza en ~4 USD en los largos. Yellow y green tienen la misma curva
  (mismo taximetro), salvo mas dispersion en green en los extremos.

![Tarifa por milla y velocidad por hora](figuras/ej4_p5_milla_y_velocidad_hora.png)

- **La congestion encarece la milla.** En viajes yellow de 1 a 5 millas en dias
  laborables, la milla cuesta **5.65 USD a las 4 h y 8.47 USD a las 11 h (+50%)**,
  mientras la velocidad mediana cae de **14.3 a 6.9 mph**. Las dos curvas son
  espejo una de la otra: el taximetro cobra tambien por tiempo a baja
  velocidad, asi que el mismo trayecto cuesta mas cuando hay trafico. En fin de
  semana la congestion llega mas tarde y es menor (maximo 7.45 USD/mi a las
  16-17 h, velocidad minima 8.3 mph).

### Pregunta 6 - Concentracion de valores atipicos

![Atipicos por proveedor](figuras/ej4_p6_atipicos_proveedor.png)

Porcentaje de los viajes de cada proveedor que rompe cada regla (yellow) y que
parte del total de la regla aporta:

| Regla | Proveedor con la mayor tasa | % de sus viajes | % del total de la regla | % de los viajes yellow que aporta el proveedor |
|-------|-----------------------|----------------:|------------------------:|-----------------------------------------------:|
| Duracion cero o negativa | **7 Helix** | **100.00** | 98.8 | 1.2 |
| Total negativo | **2 Curb** | 0.68 | **100.0** | 80.2 |
| Cero pasajeros | **1 CMT** | 1.79 | **89.7** | 20.8 |
| Distancia cero | 2 Curb | 3.59 | 89.8 | 80.2 |
| Fecha fuera de 2026 | 2 Curb | <0.01 | 100.0 | 80.2 |
| Zona desconocida | 1 CMT | 1.00 | 27.1 | 18.4 |

En green el patron se repite: el 100% de los totales negativos es de Curb y el
92% de los "cero pasajeros" es de CMT (14.8% de sus viajes green).

**Explicacion:**

- **Cada tipo de error tiene un "dueno"**, lo que indica que se originan en el
  sistema de registro de cada proveedor y no en el comportamiento de los
  viajes:
  - **Helix** registra hora de fin igual a la de inicio en todos sus viajes,
    todos los meses: no envia la hora de llegada. El 98.8% de los viajes yellow
    de duracion cero es de Helix. Como consecuencia, la regla "duracion > 0"
    **elimina a un proveedor completo** del analisis.
  - **Solo Curb registra reversiones como filas con total negativo**; los demas
    proveedores no lo hacen (o las registran de otra forma).
  - **CMT** es el que registra "0 pasajeros" (probablemente el valor por
    defecto cuando el conductor no lo captura).
- **En el tiempo, las tasas son estables** (consulta 20), con una excepcion:
  la duracion cero de CMT sube de ~0.04% a **0.41% en agosto** (10 veces mas),
  un cambio que convendria vigilar con los proximos meses.
- **Las distancias absurdas son dos fenomenos distintos** (consulta 21):
  - 762 viajes Flex Fare de Curb tienen distancias medianas de **87,993 mi**
    con 24 min de duracion y 33 USD de tarifa (velocidad implicita de 214,000
    mph): es un error del campo distancia en los viajes por aplicacion. Lo
    mismo ocurre en green con los viajes sin `payment_type` (69 viajes,
    mediana 39,973 mi).
  - Los viajes > 100 mi pagados con tarjeta o efectivo tienen ~128 mi,
    2-3 h de duracion, tarifas de 300-600 USD y velocidades de ~50 mph: son
    **viajes largos reales** (fuera de la ciudad). La regla "distancia > 100 mi"
    los descarta igual; para analisis de viajes interurbanos convendria
    reemplazarla por una regla de velocidad maxima.

---

## 4.5 Hallazgos relevantes

1. **Flex Fare son viajes de taxi pedidos por aplicacion, principalmente Uber.**
   Representan el 21-30% de los viajes yellow cada mes y el 79% de ellos trae
   el codigo `HV0003` (licencia de Uber) en `request_source`. Esto explica los
   nulos estructurales del 26% de yellow (sin pasajeros, `RatecodeID` ni
   recargos), su propina casi nula y las distancias absurdas de Curb. Ademas,
   Flex Fare debe tratarse como un **canal de venta distinto**, no como un
   metodo de pago, y su `fare_amount` no es comparable con el de los viajes con
   taximetro.

2. **Los errores de datos tienen proveedor.** Helix (`VendorID = 7`) registra
   duracion cero en el 100% de sus viajes; solo Curb registra totales negativos;
   CMT concentra el 90% de los "cero pasajeros". La limpieza por reglas del
   Ejercicio 3 elimina sin aviso a todo un proveedor, por lo que **las reglas de
   calidad deben evaluarse por proveedor** antes de aplicarse.

3. **Los aeropuertos valen mucho mas de lo que pesan.** Son el 8.2% de los
   viajes yellow pero el 21% de los ingresos; un viaje desde JFK cuesta en
   mediana 86.75 USD frente a 22.45 USD de un viaje urbano. Ademas, por cada
   viaje hacia un aeropuerto hay cuatro desde un aeropuerto.

4. **La congestion encarece cada milla un 50%.** El mismo viaje de 1-5 mi cuesta
   5.65 USD/mi a las 4 h y 8.47 USD/mi a las 11 h de un dia laborable, cuando
   la velocidad mediana baja a la mitad (14.3 -> 6.9 mph). El precio por milla
   tambien depende de la distancia: casi 4 veces mas en viajes < 0.5 mi que en
   viajes > 20 mi.

5. **La propina en efectivo no existe en los datos.** Solo 172 de 2.56 M viajes
   en efectivo registran propina. Con tarjeta, el 91% deja propina y la mediana
   es exactamente 20%; el porcentaje baja con la distancia (18.2% -> 13.8%) y
   en la madrugada.

6. **Yellow y green atienden mercados distintos.** Yellow es un servicio de
   Manhattan (87% de sus origenes) con picos de noche y de fin de semana (sabado
   es su mejor dia). Green es un servicio de traslados cotidianos, con pico a
   las 17 h de martes a jueves, 20% menos viajes el fin de semana y el 40% de
   sus origenes en East Harlem. Dentro de green, los viajes despachados son un
   servicio aparte: tarifa negociada, nocturnos y tres veces mas caros.

## Limitaciones

- El periodo cubre enero-agosto de 2026; no permite observar estacionalidad
  anual completa ni comparar con anios anteriores (Ejercicio 5).
- Helix queda fuera de las preguntas 1-5 por su error de duracion.
- `request_source` solo existe desde junio y no esta en el diccionario de datos;
  la interpretacion de `HV0003`/`HV0005` como Uber/Lyft se basa en los codigos
  de licencia HVFHS de la TLC.
- Las causas de los dias con demanda extrema (23-feb, 25/26-ene) no se
  verificaron con fuentes externas.
- `total_amount` es el campo confiable de ingresos (Ejercicio 3, consulta 16);
  en Flex Fare y en green "sin registro" `fare_amount` no representa la tarifa.
