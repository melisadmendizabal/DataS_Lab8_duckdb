# Ejercicio 2 - Sistema de descarga

Documentacion del analisis y de los cambios realizados a
`scripts/download_data.py`.

## 2.1 Analisis del script proporcionado

El script original ya contaba con una base razonable: construia las URLs de la
TLC, consultaba con `HEAD` si cada mes estaba publicado, descargaba sobre un
archivo temporal `.part` y omitia archivos existentes. Sin embargo, al
probarlo se encontraron los siguientes problemas:

| # | Problema | Consecuencia | Como se detecto |
|---|----------|--------------|-----------------|
| 1 | `DIR_DESTINO = Path("data/raw")` es relativo al **directorio actual**. | Si se ejecuta desde `scripts/` (u otra carpeta) los datos terminan en `scripts/data/raw/`, ruta que **no** esta en `.gitignore`: se podrian subir cientos de MB a Git. | `cd scripts && python download_data.py` -> `DIR_DESTINO.resolve()` = `/workspace/scripts/data/raw`. |
| 2 | `esta_publicado()` devuelve `False` ante **cualquier** excepcion de red. | Una caida de red o un timeout se reporta como "aun no publicado por la TLC"; el resumen dice `fallidos: 0` y el codigo de salida es 0, aunque falten datos. Un conjunto incompleto parece completo. | Simulando `requests.ConnectionError` en `requests.head`. |
| 3 | La verificacion de "ya existe" solo revisa `st_size > 0`. | Un archivo truncado/corrupto, o una version que la TLC **republico** (los encabezados `Last-Modified` muestran que la TLC vuelve a subir meses, p. ej. yellow 2026-06 fue republicado el 17-sep-2026), se omite para siempre. | Truncando un archivo local: el script original lo daba por bueno. |
| 4 | No se verifica que lo descargado este completo (bytes vs. `Content-Length`) ni que sea un Parquet valido. | Se podria renombrar a `.parquet` un archivo incompleto. | Revision del codigo de `descargar_archivo()`. |
| 5 | El `.part` solo se borra ante `RequestException`. | Una interrupcion con Ctrl+C deja archivos `.part` huerfanos. | Revision del codigo. |
| 6 | El anio esta fijo en el codigo (`ANIO = 2026`). | Ejercicios posteriores (5.1 y 8.1) requieren otros anios y habria que editar el codigo. | Revision del enunciado. |
| 7 | No hay forma de comprobar el estado de los datos sin descargar, ni un inventario final. | No hay evidencia de que el conjunto este completo. | Requisito 2.5 / 2.7. |

## 2.2 - 2.4 / 2.6 Cambios realizados

| Cambio | Resuelve |
|--------|----------|
| `RAIZ_PROYECTO = Path(__file__).resolve().parent.parent` y `DIR_DESTINO = RAIZ_PROYECTO / "data" / "raw"`. Los datos siempre quedan en `data/raw/<tipo>/<anio>/`, sin importar desde donde se ejecute. | 1, 2.3 |
| `esta_publicado()` se reemplazo por `consultar_servidor()`, que distingue tres estados: `publicado` (con su `Content-Length`), `no_publicado` (HTTP 403/404, que es lo que responde CloudFront/S3 para meses inexistentes) y `error` (red, timeout u otro codigo HTTP; con reintentos). Un `error` se cuenta como **fallido** y produce codigo de salida 1. | 2 |
| Nueva funcion `es_parquet_valido()`: verifica la firma `PAR1` al inicio y al final del archivo (un archivo truncado pierde el pie del Parquet). Es una comprobacion barata que no lee los datos. | 3, 4 |
| Un archivo existente se omite (no se vuelve a descargar) solo si es un Parquet valido **y** su tamanio coincide con el `Content-Length` del servidor. Si no, se vuelve a descargar y se cuenta como `actualizado`. Si el servidor no responde pero el archivo local es valido, se conserva. | 3, 2.4 |
| `descargar_archivo()` compara los bytes escritos con el tamanio esperado y valida la firma Parquet **antes** de renombrar el `.part`. | 4 |
| El borrado del `.part` se hace en un `finally` (cubre Ctrl+C) y al inicio de cada tipo/anio se limpian `.part` huerfanos (`limpiar_temporales()`). | 5 |
| Parametro `--anio` (uno o varios, por defecto 2026). Las funciones reciben el anio como argumento. | 6, 2.2 |
| Parametro `--solo-verificar`: consulta el servidor y compara con lo local sin descargar; los archivos faltantes o distintos se reportan como `pendientes` (codigo de salida 1). | 7 |
| Inventario final: para cada archivo en disco muestra filas (leidas de los metadatos Parquet con `pyarrow`, sin leer los datos) y tamanio, con totales por tipo/anio. Un archivo ilegible aparece como `ILEGIBLE`. | 7, 2.5 |
| Deteccion de huecos: advierte si un mes no esta publicado pero uno posterior si (la TLC publica en orden). | 2.7 |

Se mantuvieron el nombre del script, la estructura de carpetas, el formato de
salida, el parametro `--taxi` y la descarga atomica via `.part`.

### Pruebas realizadas

| Prueba | Resultado |
|--------|-----------|
| Primera ejecucion | 16 descargados, 8 no publicados (sep-dic), 0 fallidos, exit 0. |
| Re-ejecucion desde `scripts/` | 0 descargados, 16 ya existian; no se creo `scripts/data/`. |
| Truncar `green_tripdata_2026-03.parquet` y ejecutar `--solo-verificar` | `PENDIENTE: no es un Parquet valido`, inventario lo muestra `ILEGIBLE`, exit 1. |
| Ejecutar de nuevo sin `--solo-verificar` | `no es un Parquet valido; se vuelve a descargar` -> `actualizados: 1`, 44,208 filas. |
| Simular red caida (`requests.head` lanza `ConnectionError`) | `ERROR al consultar el servidor`, contado como fallido, exit 1 (antes: "aun no publicado", exit 0). |
| Archivos `.part` tras las pruebas | Ninguno. |

## 2.5 Resultado de la descarga (06-oct-2026)

```text
yellow_tripdata_2026-01.parquet         3,724,889 filas    61.2 MiB
yellow_tripdata_2026-02.parquet         3,399,866 filas    56.0 MiB
yellow_tripdata_2026-03.parquet         3,952,451 filas    64.7 MiB
yellow_tripdata_2026-04.parquet         3,831,240 filas    61.8 MiB
yellow_tripdata_2026-05.parquet         4,090,836 filas    66.5 MiB
yellow_tripdata_2026-06.parquet         3,837,248 filas    62.4 MiB
yellow_tripdata_2026-07.parquet         3,530,109 filas    58.8 MiB
yellow_tripdata_2026-08.parquet         3,336,716 filas    56.3 MiB
TOTAL yellow 2026                      29,703,355 filas   487.8 MiB  (8 archivos)
green_tripdata_2026-01.parquet             40,272 filas   968.4 KiB
green_tripdata_2026-02.parquet             37,373 filas   899.2 KiB
green_tripdata_2026-03.parquet             44,208 filas     1.0 MiB
green_tripdata_2026-04.parquet             44,238 filas     1.0 MiB
green_tripdata_2026-05.parquet             44,921 filas     1.1 MiB
green_tripdata_2026-06.parquet             44,163 filas     1.0 MiB
green_tripdata_2026-07.parquet             41,252 filas   994.4 KiB
green_tripdata_2026-08.parquet             40,687 filas   983.9 KiB
TOTAL green 2026                          337,114 filas     7.9 MiB  (8 archivos)
```

Meses septiembre a diciembre de 2026: no publicados por la TLC (HTTP 403).

## 2.7 Como se determino que el conjunto esta completo

La completitud se verifico en cuatro niveles:

1. **Contra la fuente (que meses existen).** No se supuso que meses existen: se
   consulto al servidor cada uno de los 12 meses de cada tipo. Enero-agosto
   respondieron `200` y septiembre-diciembre `403` (CloudFront/S3 responde 403
   para objetos inexistentes). Como no hay meses no publicados *antes* del
   ultimo publicado (sin huecos) y el patron coincide con el atraso de
   publicacion de la TLC, los 8 meses por tipo son todo lo disponible a la
   fecha. Las fallas de red ya no se confunden con "no publicado", por lo que
   un resumen con `fallidos: 0` es confiable.

2. **Integridad de cada archivo.** Para cada archivo se comprobo que el tamanio
   local sea identico al `Content-Length` publicado por el servidor y que tenga
   la firma Parquet `PAR1` al inicio y al final. Ademas `pyarrow` pudo leer los
   metadatos de los 16 archivos (ninguno `ILEGIBLE`). Esto se puede repetir en
   cualquier momento con:

   ```bash
   docker exec lab8-lab python scripts/download_data.py --solo-verificar
   ```

   que termina con `pendientes: 0`, `fallidos: 0` y codigo de salida 0 cuando
   el conjunto local coincide con el publicado.

3. **Lectura completa con DuckDB.** Se leyeron los 16 archivos completos con
   `read_parquet` (no solo los metadatos), sin errores, y el conteo de filas
   coincide con el del inventario (29,703,355 yellow y 337,114 green).

4. **Cobertura temporal del contenido.** Para cada archivo se contaron los dias
   distintos con viajes dentro de su mes:

   | Mes | Dias del mes | Dias con viajes (yellow) | Dias con viajes (green) |
   |-----|-------------:|-------------------------:|------------------------:|
   | 2026-01 | 31 | 31 | 31 |
   | 2026-02 | 28 | 28 | 28 |
   | 2026-03 | 31 | 31 | 31 |
   | 2026-04 | 30 | 30 | 30 |
   | 2026-05 | 31 | 31 | 31 |
   | 2026-06 | 30 | 30 | 30 |
   | 2026-07 | 31 | 31 | 31 |
   | 2026-08 | 31 | 31 | 31 |

   Todos los dias de cada mes tienen viajes, por lo que ningun archivo esta
   parcialmente vacio. Los volumenes mensuales son estables (3.3-4.1 M yellow,
   37-45 mil green), sin meses anomalamente pequenios.

   Consulta utilizada (analoga para green con `lpep_pickup_datetime`):

   ```sql
   SELECT regexp_extract(filename, '(\d{4}-\d{2})', 1)            AS mes,
          count(*)                                                 AS filas,
          count(DISTINCT CAST(tpep_pickup_datetime AS DATE))
            FILTER (WHERE strftime(tpep_pickup_datetime, '%Y-%m')
                          = regexp_extract(filename, '(\d{4}-\d{2})', 1)) AS dias_con_viajes,
          count(*) FILTER (WHERE strftime(tpep_pickup_datetime, '%Y-%m')
                          <> regexp_extract(filename, '(\d{4}-\d{2})', 1)) AS fuera_de_mes
   FROM read_parquet('data/raw/yellow/2026/*.parquet', filename = true)
   GROUP BY mes
   ORDER BY mes;
   ```

### Observaciones sobre los datos

- **Registros fuera de su mes.** Cada archivo contiene unas pocas filas (3 a 46)
  cuya fecha de inicio no pertenece al mes del archivo (errores de reloj del
  taximetro). No afecta la completitud, pero debe tenerse en cuenta al agrupar
  por fecha: conviene filtrar por la fecha del viaje y no solo por el archivo.
- **Cambio de esquema.** A partir de **junio de 2026** los archivos de ambos
  tipos incluyen una columna nueva, `request_source`, que no existe en
  enero-mayo. Al leer varios meses a la vez se debe usar
  `read_parquet(..., union_by_name = true)` para que DuckDB combine los
  esquemas por nombre de columna (los meses anteriores quedan con `NULL`).
- **Republicaciones.** La TLC vuelve a subir meses ya publicados (segun
  `Last-Modified`). Ejecutar el script periodicamente detecta un cambio de
  tamanio y descarga la nueva version.
