# Lab 8 - DuckDB

Repositorio base del laboratorio 8 del curso **CC3084 - Data Science**
(Universidad del Valle de Guatemala, Ciclo 2, 2026).

Este es el repositorio **proporcionado por el docente**. Contiene la estructura
del proyecto, el ambiente de ejecucion basado en Docker y un script que descarga
los datos de **2026**. Todo lo demas debe ser construido por cada equipo.

## Trabajo con fork

El laboratorio se desarrolla y se entrega sobre un **fork** de este repositorio.
No se trabaja directamente sobre el repositorio del docente.

1. Realice un fork de este repositorio:
   <https://github.com/menene/duckdb>

2. Clone **su propio fork** (no el del docente):

   ```bash
   git clone https://github.com/<su-usuario>/duckdb.git
   cd duckdb
   ```

3. Opcional, para recibir correcciones publicadas por el docente:

   ```bash
   git remote add upstream https://github.com/menene/duckdb.git
   git fetch upstream
   ```

Realice commits frecuentes y descriptivos: el historial del repositorio es parte
de la evaluacion. **La entrega del laboratorio es la URL de su fork.**

## Estructura

```text
duckdb/
|
+-- data/
|   +-- raw/
|   +-- processed/
|
+-- notebooks/
|
+-- scripts/
|
+-- sql/
|
+-- docs/
|
+-- Dockerfile
+-- metabase.Dockerfile
+-- docker-compose.yml
+-- README.md
```

## Requisitos

- Docker, con Docker Compose
- Git

La primera construccion del ambiente descarga varios cientos de MB y puede
tardar algunos minutos.

Considere el espacio en disco: las imagenes de Docker ocupan unos 3 GB y los
datos de los tres anios del laboratorio superan 1.5 GB, a los que se suma la
base materializada del Ejercicio 6. Se recomienda tener al menos 10 GB libres.

## Datos

El repositorio incluye `scripts/download_data.py`, que descarga los archivos de
2026 publicados por la TLC (`--help` muestra las opciones disponibles). Los
archivos se guardan en `data/raw/<tipo>/<anio>/`.

La TLC publica cada mes con varias semanas de atraso, por lo que los ultimos
meses de 2026 todavia no existen. El script consulta al servidor que meses estan
publicados, de modo que vuelve a ejecutarse sin problema conforme aparezcan
nuevos archivos.

Los datos descargados **no deben incluirse en el repositorio Git**. El archivo
`.gitignore` ya esta configurado para evitarlo.

Fuente de datos: NYC TLC Trip Record Data
<https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page>

Dentro de los contenedores, la carpeta `data/` del proyecto esta montada en
`/workspace/data`. Esa es la ruta que deben usar las herramientas que corren
dentro del ambiente, no la ruta de su computadora.

> **Nota sobre DuckDB:** un archivo `.duckdb` admite un solo proceso con permiso
> de escritura a la vez. Si conecta una herramienta externa a su base de datos,
> use el modo de solo lectura (`read_only`) en esa conexion; de lo contrario los
> demas procesos no podran abrir el archivo.

## Material a entregar

Al finalizar, su fork debe contener:

- el codigo fuente modificado y los scripts de descarga;
- las consultas SQL desarrolladas;
- el notebook o notebooks utilizados;
- la documentacion de las consultas;
- los scripts utilizados para los benchmarks;
- el codigo de los indicadores y visualizaciones;
- el tablero o la evidencia del tablero desarrollado;
- este `README.md`, completado segun la siguiente seccion.

Los archivos de datos descargados **no** deben incluirse.

---

# Documentacion del equipo

Las siguientes secciones deben ser completadas por cada equipo. El README final
debe permitir que una persona que no participo en el desarrollo pueda levantar el
ambiente, descargar los datos, ejecutar el analisis, reproducir los benchmarks y
generar los resultados principales.

## Proposito de cada directorio

| Directorio / archivo   | Proposito |
|------------------------|-----------|
| `data/raw/`            | Datos originales tal como los publica la TLC (Parquet mensuales en `data/raw/<tipo>/<anio>/`). No se modifican: son la fuente de verdad a partir de la cual se puede regenerar todo lo demas. |
| `data/processed/`      | Resultados derivados de `raw/`: datos limpios o transformados, la base `.duckdb` materializada, tablas agregadas, etc. Se puede borrar y volver a generar con los scripts. |
| `notebooks/`           | Notebooks de Jupyter para exploracion, analisis, indicadores y visualizaciones. |
| `scripts/`             | Codigo Python reproducible y ejecutable desde la linea de comandos: descarga de datos, preparacion/transformacion y benchmarks. |
| `sql/`                 | Consultas SQL de DuckDB versionadas como archivos `.sql`, para que queden documentadas y puedan reutilizarse desde notebooks, scripts o Metabase. |
| `docs/`                | Documentacion del trabajo: explicacion de consultas y transformaciones, resultados de benchmarks y evidencia del tablero. |
| `Dockerfile`           | Imagen del ambiente de analisis (Python 3.11 + JupyterLab + DuckDB + pandas/pyarrow/matplotlib). |
| `metabase.Dockerfile`  | Imagen de Metabase con el driver de DuckDB, para construir tableros. |
| `docker-compose.yml`   | Orquesta ambos servicios, sus puertos y los volumenes que montan las carpetas del proyecto dentro de los contenedores. |
| `requirements.txt`     | Versiones fijas de las librerias de Python, para que el ambiente sea identico en cualquier maquina. |

Los directorios `data/raw/` y `data/processed/` estan excluidos de Git en
`.gitignore` (solo se versiona su `.gitkeep`), de modo que el repositorio guarda
el *proceso* y no los datos.

## Como levantar el ambiente

### Requisitos previos

- Docker Desktop (o Docker Engine) con Docker Compose v2. Verificar con:

  ```bash
  docker --version
  docker compose version
  ```

- Al menos 10 GB de disco libres (ver seccion *Requisitos*).
- Los puertos `8888` y `3000` libres en la maquina local.

### Pasos

1. Clonar el fork y entrar a la carpeta:

   ```bash
   git clone https://github.com/melisadmendizabal/DataS_Lab8_duckdb.git
   cd DataS_Lab8_duckdb
   ```

2. Construir las imagenes y levantar los servicios en segundo plano:

   ```bash
   docker compose up --build -d
   ```

   La primera vez tarda varios minutos (descarga la imagen de Python, las
   librerias, Metabase y el driver de DuckDB). Las siguientes veces basta con
   `docker compose up -d`.

3. Verificar que ambos contenedores esten en estado `Up`:

   ```bash
   docker compose ps
   ```

   ```text
   NAME            SERVICE    STATUS   PORTS
   lab8-lab        lab        Up       127.0.0.1:8888->8888/tcp
   lab8-metabase   metabase   Up       127.0.0.1:3000->3000/tcp
   ```

4. Abrir los servicios en el navegador:

   | Servicio   | URL                     | Notas |
   |------------|-------------------------|-------|
   | JupyterLab | <http://localhost:8888> | Sin token ni contrasena (solo escucha en `127.0.0.1`). |
   | Metabase   | <http://localhost:3000> | Tarda ~1 minuto en iniciar. La primera vez pide crear un usuario administrador. |

5. Verificar el funcionamiento de los servicios:

   ```bash
   # DuckDB y librerias dentro del contenedor de analisis
   docker exec lab8-lab python -c "import duckdb; print(duckdb.__version__, duckdb.sql('select 42').fetchone())"

   # Salud de Metabase (debe responder {"status":"ok"})
   curl http://localhost:3000/api/health
   ```

### Herramientas disponibles en el ambiente

**Servicio `lab` (contenedor `lab8-lab`)** — imagen `python:3.11.14-slim` (Debian 13):

| Herramienta  | Version | Uso |
|--------------|---------|-----|
| Python       | 3.11.14 | Lenguaje base de scripts y notebooks. |
| JupyterLab   | 4.6.4   | Notebooks interactivos (puerto 8888). |
| DuckDB       | 1.5.5   | Motor SQL analitico embebido (libreria de Python; no incluye el CLI `duckdb`). |
| pandas       | 3.0.6   | Manipulacion de DataFrames. |
| pyarrow      | 25.0.1  | Lectura/escritura de Parquet y formato Arrow. |
| matplotlib   | 3.11.2  | Visualizaciones. |
| requests     | 2.34.2  | Descarga HTTP de los archivos de la TLC. |
| curl         | -       | Utilidad de linea de comandos para HTTP. |

**Servicio `metabase` (contenedor `lab8-metabase`)** — imagen `eclipse-temurin:21-jre-jammy`:

| Herramienta           | Version  | Uso |
|-----------------------|----------|-----|
| Metabase              | v0.63.19 | Herramienta de BI para tableros (puerto 3000). |
| Driver DuckDB         | 1.5.5.0  | Permite a Metabase leer archivos `.duckdb` / Parquet. |
| Java (OpenJDK)        | 21       | Runtime de Metabase. |

Carpetas montadas en los contenedores:

- `lab`: `data/`, `notebooks/`, `scripts/`, `sql/` y `docs/` en `/workspace/...`.
  Los cambios hechos dentro del contenedor se reflejan en la carpeta local y viceversa.
- `metabase`: `data/` en `/workspace/data` y un volumen de Docker
  (`metabase-data`) donde Metabase guarda su configuracion, de modo que los
  tableros sobreviven a reinicios del contenedor.

### Comandos utiles

```bash
docker compose logs -f lab          # ver logs de Jupyter
docker compose logs -f metabase     # ver logs de Metabase
docker exec -it lab8-lab bash       # abrir una terminal dentro del ambiente
docker compose stop                 # detener los servicios
docker compose down                 # detener y eliminar contenedores (conserva datos y volumen)
docker compose down -v              # ademas elimina el volumen de Metabase
```

### Por que un ambiente reproducible (Ejercicio 1.6)

- **Mismos resultados en cualquier maquina.** Las versiones de Python, DuckDB,
  pandas, Metabase y el driver estan fijadas en `requirements.txt` y en los
  Dockerfiles. Cualquier integrante (o el docente) obtiene exactamente el mismo
  software, por lo que las consultas y benchmarks producen los mismos resultados
  y se evita el clasico "en mi maquina si funciona".
- **Compatibilidad entre componentes.** El archivo `.duckdb` debe abrirse con la
  misma version de DuckDB en Python y en el driver de Metabase; un ambiente
  fijado garantiza esa alineacion.
- **Independencia del sistema operativo.** El equipo puede trabajar en Windows,
  macOS o Linux sin instalar ni configurar dependencias manualmente.
- **Comparaciones de desempeno validas.** Para que los benchmarks sean
  comparables, deben ejecutarse sobre el mismo motor y las mismas librerias.
- **Trazabilidad y auditoria.** Codigo, consultas y configuracion del ambiente
  quedan versionados en Git; los datos se regeneran con los scripts. Asi
  cualquier resultado puede rastrearse y volver a producirse cuando lleguen
  nuevos archivos de la TLC.
- **Aislamiento.** Las dependencias del laboratorio no interfieren con otros
  proyectos instalados en la computadora, y el ambiente se puede destruir y
  reconstruir sin riesgo.

## Como descargar los datos

Con el ambiente levantado, ejecutar el script dentro del contenedor `lab`:

```bash
# Taxis amarillos y verdes de 2026 (todos los meses publicados a la fecha)
docker exec lab8-lab python scripts/download_data.py
```

Los archivos quedan en `data/raw/<tipo>/<anio>/<tipo>_tripdata_<anio>-<mes>.parquet`
(dentro del contenedor: `/workspace/data/raw/...`). El script tambien descarga,
una sola vez, la tabla de zonas de la TLC en `data/raw/zones/taxi_zone_lookup.csv`
(relaciona `PULocationID`/`DOLocationID` con distrito y zona; la usa el
Ejercicio 4). La ruta se calcula a partir
de la ubicacion del script, asi que puede ejecutarse desde cualquier carpeta.

Opciones:

| Opcion | Descripcion |
|--------|-------------|
| `--taxi {yellow,green,all}` | Tipo de taxi (por defecto `all`). |
| `--anio 2026 [2025 ...]` | Uno o varios anios (por defecto `2026`). |
| `--solo-verificar` | No descarga; compara lo local con el servidor y reporta archivos pendientes. |

El script se puede ejecutar cuantas veces se quiera:

- no vuelve a descargar archivos que ya existen, son Parquet validos y tienen
  el mismo tamanio que el publicado por la TLC;
- descarga los meses que la TLC haya publicado desde la ultima ejecucion, y
  vuelve a descargar archivos truncados o republicados por la TLC;
- distingue un mes no publicado (HTTP 403/404) de una falla de red; ante fallas
  termina con codigo de salida 1;
- al final muestra un inventario con filas y tamanio por archivo.

Para comprobar que los datos locales estan completos sin descargar nada:

```bash
docker exec lab8-lab python scripts/download_data.py --solo-verificar
```

El analisis del script original, los cambios realizados, las pruebas y la
verificacion de completitud (Ejercicio 2) estan documentados en
[`docs/descarga_datos.md`](docs/descarga_datos.md).

> **Nota:** a partir de junio de 2026 los archivos incluyen la columna
> `request_source`. Para leer varios meses juntos use
> `read_parquet('data/raw/yellow/2026/*.parquet', union_by_name = true)`.

## Como ejecutar el analisis

Las consultas SQL estan versionadas en `sql/`, un archivo por consulta, con
su objetivo y los archivos fuente en el encabezado. Se pueden ejecutar de dos
formas (con el ambiente levantado y los datos descargados):

**Desde la linea de comandos**, con `scripts/run_sql.py`, que ejecuta los
archivos en orden sobre una base DuckDB en memoria y muestra resultado y
tiempo de cada uno:

```bash
# Ejercicio 3: exploracion directa de los Parquet
docker exec lab8-lab python scripts/run_sql.py sql/03_exploracion

# Una sola consulta, mostrando hasta 60 filas
docker exec lab8-lab python scripts/run_sql.py sql/03_exploracion/13_reglas_de_calidad.sql --filas 60
```

**Desde JupyterLab** (<http://localhost:8888>), abriendo
`notebooks/03_exploracion_parquet.ipynb` y ejecutando todas las celdas. Para
regenerar el notebook con sus resultados sin abrir el navegador:

```bash
docker exec -w /workspace/notebooks lab8-lab jupyter nbconvert --to notebook --execute --inplace 03_exploracion_parquet.ipynb
```

| Ejercicio | Consultas | Notebook | Documentacion |
|-----------|-----------|----------|---------------|
| 3 - Consultas directas sobre Parquet | `sql/03_exploracion/` | `notebooks/03_exploracion_parquet.ipynb` | [`docs/03_consultas_parquet.md`](docs/03_consultas_parquet.md) |
| 4 - Analisis exploratorio | `sql/04_analisis/` | `notebooks/04_analisis_exploratorio.ipynb` | [`docs/04_analisis_exploratorio.md`](docs/04_analisis_exploratorio.md) (figuras en `docs/figuras/`) |

En el Ejercicio 4, `sql/04_analisis/00_vistas.sql` define las vistas
temporales (`viajes`, `viajes_validos`, `zonas`, `metodos_pago`) que usan las
demas consultas, por lo que debe ejecutarse primero. `run_sql.py` y el notebook
lo hacen automaticamente al recorrer los archivos en orden. Para ejecutar una
sola consulta, incluya las vistas:

```bash
docker exec lab8-lab python scripts/run_sql.py sql/04_analisis/00_vistas.sql sql/04_analisis/07_viajes_aeropuerto.sql
```

> **Memoria:** `run_sql.py` limita DuckDB a 3 GB (`--memoria` para cambiarlo).
> Con el limite por defecto (80% de la RAM del contenedor) algunas consultas
> fallan con `Cannot allocate memory` porque Metabase comparte la memoria
> asignada a Docker.

## Como reproducir los benchmarks

<!-- TODO (Ejercicio 6) -->

## Como generar los resultados principales

<!-- TODO -->
