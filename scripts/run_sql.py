#!/usr/bin/env python3
"""Ejecuta archivos .sql con DuckDB y muestra su resultado.

Las consultas del laboratorio se guardan como archivos en sql/ para que
queden versionadas y documentadas. Este script las ejecuta en orden sobre una
base DuckDB en memoria (es decir, consultando directamente los Parquet, sin
importarlos a una tabla) y muestra el resultado y el tiempo de cada una.

Uso:
    python scripts/run_sql.py sql/03_exploracion                 # toda la carpeta
    python scripts/run_sql.py sql/03_exploracion/01_*.sql         # algunos archivos
    python scripts/run_sql.py sql/03_exploracion --filas 50       # mas filas por resultado
    python scripts/run_sql.py sql/03_exploracion --memoria 2GB

Las rutas dentro de las consultas (p. ej. 'data/raw/...') son relativas a la
raiz del proyecto; el script cambia a ese directorio antes de ejecutarlas.
"""

import argparse
import os
import sys
import time
from pathlib import Path

import duckdb

RAIZ_PROYECTO = Path(__file__).resolve().parent.parent

# Docker Desktop suele asignar ~8 GB a todos los contenedores y Metabase usa
# parte de ellos. El limite por defecto de DuckDB (80% de la RAM) provoca
# errores "Cannot allocate memory"; con un limite menor DuckDB usa disco.
MEMORIA_POR_DEFECTO = "3GB"


def conectar(memoria: str = MEMORIA_POR_DEFECTO) -> duckdb.DuckDBPyConnection:
    """Conexion en memoria configurada para el ambiente del laboratorio."""
    os.chdir(RAIZ_PROYECTO)
    con = duckdb.connect()
    con.execute(f"SET memory_limit = '{memoria}'")
    try:
        con.execute("SET enable_progress_bar = false")
    except duckdb.Error:
        # Dentro de Jupyter DuckDB exige ipywidgets para tocar este ajuste.
        pass
    return con


def encabezado(ruta: Path) -> list:
    """Lineas de comentario iniciales (-- ...) del archivo SQL."""
    lineas = []
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if not linea.startswith("--"):
            break
        lineas.append(linea)
    return lineas


def expandir(rutas: list) -> list:
    archivos = []
    for ruta in rutas:
        ruta = Path(ruta)
        if not ruta.is_absolute():
            ruta = (Path.cwd() / ruta).resolve()
        archivos += sorted(ruta.glob("*.sql")) if ruta.is_dir() else [ruta]
    return archivos


def main() -> int:
    parser = argparse.ArgumentParser(description="Ejecuta archivos .sql con DuckDB.")
    parser.add_argument("rutas", nargs="+", help="archivos .sql o carpetas que los contienen")
    parser.add_argument("--filas", type=int, default=40, help="filas maximas a mostrar (por defecto 40)")
    parser.add_argument("--memoria", default=MEMORIA_POR_DEFECTO,
                        help=f"limite de memoria de DuckDB (por defecto {MEMORIA_POR_DEFECTO})")
    argumentos = parser.parse_args()

    archivos = expandir(argumentos.rutas)
    con = conectar(argumentos.memoria)

    errores = 0
    for archivo in archivos:
        print("=" * 100)
        print(archivo.relative_to(RAIZ_PROYECTO))
        print("\n".join(encabezado(archivo)))
        print("-" * 100)
        inicio = time.perf_counter()
        try:
            resultado = con.sql(archivo.read_text(encoding="utf-8"))
            if resultado is not None:
                resultado.show(max_rows=argumentos.filas, max_width=250)
        except duckdb.Error as error:
            errores += 1
            print(f"ERROR: {error}")
        print(f"tiempo: {time.perf_counter() - inicio:.2f} s\n")

    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
