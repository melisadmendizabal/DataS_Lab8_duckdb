#!/usr/bin/env python3
"""Materializa los viajes en una base DuckDB (Ejercicio 6.2).

Copia a una base .duckdb los datos que las vistas de
sql/04_analisis/00_vistas.sql leen desde los Parquet, de modo que las mismas
consultas puedan ejecutarse sobre una tabla en lugar de sobre los archivos.

La base queda con:
    viajes          TABLA  copia de la vista viajes (yellow + green, columnas
                           unificadas, con anio y mes_archivo)
    zonas           TABLA  tabla de zonas de la TLC
    metodos_pago    TABLA  nombres de los codigos de payment_type
    viajes_validos  VISTA  misma definicion que en 00_vistas.sql, ahora sobre
                           la tabla viajes
    carga           TABLA  cuando y con que archivos se construyo la base

Las definiciones salen de 00_vistas.sql (no se copian a mano): primero se
crean las vistas temporales sobre los Parquet, se copian sus datos a tablas
y la definicion de viajes_validos se toma del catalogo de DuckDB. Asi las
reglas de limpieza viven en un solo archivo.

Uso:
    python scripts/materializar.py                       # todos los anios -> data/processed/taxis.duckdb
    python scripts/materializar.py --periodo '2026/*'    # solo 2026
    python scripts/materializar.py --base data/processed/otra.duckdb

La base se reemplaza completa en cada ejecucion. Un archivo .duckdb admite un
solo proceso con permiso de escritura: si Metabase u otro proceso lo tiene
abierto, cierrelo (o detenga Metabase) antes de materializar.
"""

import argparse
import re
import sys
import time
from pathlib import Path

import duckdb

from run_sql import MEMORIA_POR_DEFECTO, RAIZ_PROYECTO, conectar

VISTAS_BASE = RAIZ_PROYECTO / "sql" / "04_analisis" / "00_vistas.sql"
BASE_POR_DEFECTO = RAIZ_PROYECTO / "data" / "processed" / "taxis.duckdb"
TABLAS = ("viajes", "zonas", "metodos_pago")


def materializar(con: duckdb.DuckDBPyConnection) -> dict:
    """Crea las tablas y la vista en la base abierta por `con`.

    `con` debe tener definida (o no) la variable periodo, igual que para
    00_vistas.sql. Devuelve filas, archivos y segundos de la carga.
    """
    # Vistas temporales sobre los Parquet. con.sql() no ejecuta el SELECT de
    # resumen del final del archivo (queda como relacion sin evaluar).
    con.sql(VISTAS_BASE.read_text(encoding="utf-8"))
    definicion_validos = con.execute(
        "SELECT sql FROM duckdb_views() WHERE temporary AND view_name = 'viajes_validos'"
    ).fetchone()[0]

    inicio = time.perf_counter()
    for tabla in TABLAS:
        con.execute(f"CREATE OR REPLACE TABLE main.{tabla} AS SELECT * FROM temp.main.{tabla}")
    segundos = time.perf_counter() - inicio

    # Las vistas temporales tienen prioridad sobre las tablas con el mismo
    # nombre: se eliminan antes de crear la vista persistente.
    for vista in ("viajes_validos", *TABLAS):
        con.execute(f"DROP VIEW temp.main.{vista}")
    con.execute(re.sub(r"^CREATE TEMP(ORARY)? VIEW", "CREATE OR REPLACE VIEW", definicion_validos))

    filas, archivos = con.execute(
        "SELECT count(*), count(DISTINCT tipo || mes_archivo) FROM viajes"
    ).fetchone()
    con.execute("""
        CREATE OR REPLACE TABLE carga AS
        SELECT current_localtimestamp() AS fecha_carga,
               ? AS periodo, ? AS archivos, ? AS filas, ? AS segundos,
               (SELECT list(DISTINCT anio ORDER BY anio) FROM viajes) AS anios,
               (SELECT max(mes_archivo) FROM viajes) AS ultimo_mes
    """, [con.execute("SELECT getvariable('periodo')").fetchone()[0], archivos, filas, segundos])
    con.execute("CHECKPOINT")
    return {"filas": filas, "archivos": archivos, "segundos": segundos}


def main() -> int:
    parser = argparse.ArgumentParser(description="Materializa los viajes en una base DuckDB.")
    parser.add_argument("--base", default=str(BASE_POR_DEFECTO),
                        help="archivo .duckdb a crear (por defecto data/processed/taxis.duckdb)")
    parser.add_argument("--periodo",
                        help="patron de archivos relativo a data/raw/<tipo>/ (p. ej. '2026/*'); "
                             "por defecto todos los anios descargados")
    parser.add_argument("--memoria", default=MEMORIA_POR_DEFECTO,
                        help=f"limite de memoria de DuckDB (por defecto {MEMORIA_POR_DEFECTO})")
    argumentos = parser.parse_args()

    base = Path(argumentos.base).resolve()
    base.parent.mkdir(parents=True, exist_ok=True)
    # Se reemplaza la base completa: un .duckdb no reduce su tamanio al
    # reemplazar tablas, y asi la carga es siempre desde cero.
    for archivo in (base, base.with_name(base.name + ".wal")):
        archivo.unlink(missing_ok=True)

    con = conectar(argumentos.memoria, argumentos.periodo, str(base))
    resultado = materializar(con)
    print(con.sql("SELECT * FROM carga"))
    print(con.sql("""
        SELECT tipo, anio, count(*) AS viajes
        FROM viajes GROUP BY ALL ORDER BY tipo DESC, anio
    """))
    con.close()

    print(f"{resultado['filas']:,} filas de {resultado['archivos']} archivos en "
          f"{resultado['segundos']:.1f} s -> {base.relative_to(RAIZ_PROYECTO)} "
          f"({base.stat().st_size / 1024 ** 2:,.1f} MiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
