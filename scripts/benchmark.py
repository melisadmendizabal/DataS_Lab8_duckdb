#!/usr/bin/env python3
"""Benchmark: consultas sobre Parquet frente a una tabla DuckDB (Ejercicio 6).

Para cada escala de datos (cantidad de archivos) ejecuta las mismas consultas
con dos estrategias:

    parquet  base en memoria; las vistas de sql/04_analisis/00_vistas.sql leen
             los archivos Parquet en cada consulta.
    tabla    base .duckdb creada con scripts/materializar.py a partir de esas
             mismas vistas; las consultas leen la tabla materializada.

El texto SQL de cada consulta es identico en ambas estrategias: solo cambia
si `viajes` es una vista sobre Parquet o una tabla. Ademas se verifica que
ambas estrategias devuelvan el mismo resultado.

Cada consulta se ejecuta una vez en una conexion recien abierta ("primera",
sin datos en la cache de DuckDB) y luego --repeticiones veces mas
("repetida"). La tabla se vuelve a abrir en solo lectura despues de
cargarla, para que su primera ejecucion tampoco aproveche la carga.

Resultados (se sobrescriben en cada ejecucion):
    docs/06_benchmark/tiempos.csv   una fila por escala, estrategia, consulta y ejecucion
    docs/06_benchmark/escalas.csv   filas, archivos, tamanio y tiempo de carga por escala

Uso:
    python scripts/benchmark.py
    python scripts/benchmark.py --repeticiones 5
    python scripts/benchmark.py --escalas 1mes 2026        # solo algunas escalas

La base temporal data/processed/benchmark.duckdb se elimina al terminar
(--conservar para mantenerla).
"""

import argparse
import csv
import platform
import sys
import time
from pathlib import Path

import duckdb
import pandas as pd

from materializar import materializar
from run_sql import MEMORIA_POR_DEFECTO, RAIZ_PROYECTO, conectar

# (clave, descripcion, patron de archivos relativo a data/raw/<tipo>/)
ESCALAS = [
    ("1mes",  "1 mes (2026-01)",         "2026/*2026-01"),
    ("3meses", "3 meses (2026-01 a 03)", "2026/*2026-0[1-3]"),
    ("2026",  "2026 (8 meses)",          "2026/*"),
    ("todo",  "2024 + 2026 (20 meses)",  "*/*"),
]

# Consultas representativas: tres propias del benchmark y seis del analisis
# exploratorio (Ejercicio 4), elegidas por tener patrones de acceso distintos.
CONSULTAS = [
    ("B1", "Conteo por mes",           "sql/06_benchmark/01_conteo_por_mes.sql"),
    ("B2", "Consulta selectiva",       "sql/06_benchmark/02_consulta_selectiva.sql"),
    ("B3", "Todas las columnas",       "sql/06_benchmark/03_todas_las_columnas.sql"),
    ("B4", "Dia de la semana",         "sql/04_analisis/01_viajes_por_dia_semana.sql"),
    ("B5", "Mapa de calor dia x hora", "sql/04_analisis/03_mapa_calor_dia_hora.sql"),
    ("B6", "Zonas principales",        "sql/04_analisis/05_zonas_principales.sql"),
    ("B7", "Propina por metodo",       "sql/04_analisis/14_propina_por_metodo.sql"),
    ("B8", "Tarifa por milla",         "sql/04_analisis/17_tarifa_por_milla_por_distancia.sql"),
    ("B9", "Atipicos por proveedor",   "sql/04_analisis/19_atipicos_por_proveedor.sql"),
]

VISTAS_BASE = RAIZ_PROYECTO / "sql" / "04_analisis" / "00_vistas.sql"
BASE_BENCHMARK = RAIZ_PROYECTO / "data" / "processed" / "benchmark.duckdb"
DIR_RESULTADOS = RAIZ_PROYECTO / "docs" / "06_benchmark"


def ejecutar(con, sql: str):
    """Ejecuta una consulta y devuelve (segundos, resultado como DataFrame)."""
    inicio = time.perf_counter()
    df = con.sql(sql).df()
    return time.perf_counter() - inicio, df


def normalizar(df: pd.DataFrame) -> pd.DataFrame:
    """Ordena filas y columnas para comparar resultados sin depender del orden."""
    df = df.copy()
    df.columns = [str(c) for c in df.columns]
    return df.sort_values(list(df.columns)).reset_index(drop=True)


def medir(con, estrategia, escala, repeticiones, resultados_previos, filas):
    """Ejecuta todas las consultas y devuelve las mediciones."""
    mediciones = []
    for clave, nombre, ruta in CONSULTAS:
        sql = (RAIZ_PROYECTO / ruta).read_text(encoding="utf-8")
        for ejecucion in range(repeticiones + 1):
            segundos, df = ejecutar(con, sql)
            if ejecucion == 0:
                if clave in resultados_previos:
                    # Validez de la comparacion: el resultado debe ser el mismo.
                    pd.testing.assert_frame_equal(
                        normalizar(df), normalizar(resultados_previos[clave]),
                        check_exact=False, rtol=1e-9, check_dtype=False)
                else:
                    resultados_previos[clave] = df
            mediciones.append({
                "escala": escala, "filas": filas, "estrategia": estrategia,
                "consulta": clave, "nombre": nombre,
                "ejecucion": "primera" if ejecucion == 0 else "repetida",
                "segundos": round(segundos, 4),
            })
        repetidas = [m["segundos"] for m in mediciones[-repeticiones:]]
        print(f"    {clave} {nombre:<26} primera {mediciones[-repeticiones - 1]['segundos']:7.2f} s"
              f"   repetida (mediana) {sorted(repetidas)[len(repetidas) // 2]:7.2f} s")
    return mediciones


def tamanio_parquet(con) -> float:
    return con.execute("""
        SELECT sum(file_size_bytes) / 1024 ^ 2
        FROM parquet_file_metadata(['data/raw/yellow/' || getvariable('periodo') || '.parquet',
                                    'data/raw/green/'  || getvariable('periodo') || '.parquet'])
    """).fetchone()[0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Parquet vs tabla DuckDB.")
    parser.add_argument("--repeticiones", type=int, default=3,
                        help="ejecuciones adicionales despues de la primera (por defecto 3)")
    parser.add_argument("--escalas", nargs="+", choices=[e[0] for e in ESCALAS],
                        default=[e[0] for e in ESCALAS], help="escalas a medir (por defecto todas)")
    parser.add_argument("--memoria", default=MEMORIA_POR_DEFECTO,
                        help=f"limite de memoria de DuckDB (por defecto {MEMORIA_POR_DEFECTO})")
    parser.add_argument("--conservar", action="store_true",
                        help="no eliminar data/processed/benchmark.duckdb al terminar")
    argumentos = parser.parse_args()

    DIR_RESULTADOS.mkdir(parents=True, exist_ok=True)
    tiempos, escalas = [], []
    hilos = None

    for clave, descripcion, periodo in (e for e in ESCALAS if e[0] in argumentos.escalas):
        print(f"\n=== Escala {descripcion}  (periodo '{periodo}') ===")
        resultados = {}

        # --- Parquet: vistas temporales sobre los archivos ----------------
        con = conectar(argumentos.memoria, periodo)
        con.sql(VISTAS_BASE.read_text(encoding="utf-8"))
        filas, archivos = con.execute(
            "SELECT count(*), count(DISTINCT tipo || mes_archivo) FROM viajes").fetchone()
        mib_parquet = tamanio_parquet(con)
        hilos = con.execute("SELECT current_setting('threads')").fetchone()[0]
        con.close()
        # Conexion nueva para que la primera ejecucion no aproveche el conteo.
        con = conectar(argumentos.memoria, periodo)
        con.sql(VISTAS_BASE.read_text(encoding="utf-8"))
        print(f"  parquet: {filas:,} filas, {archivos} archivos, {mib_parquet:,.1f} MiB")
        tiempos += medir(con, "parquet", clave, argumentos.repeticiones, resultados, filas)
        con.close()

        # --- Tabla: materializar y volver a abrir en solo lectura ---------
        for archivo in (BASE_BENCHMARK, BASE_BENCHMARK.with_name(BASE_BENCHMARK.name + ".wal")):
            archivo.unlink(missing_ok=True)
        con = conectar(argumentos.memoria, periodo, str(BASE_BENCHMARK))
        carga = materializar(con)
        con.close()
        mib_tabla = BASE_BENCHMARK.stat().st_size / 1024 ** 2
        print(f"  tabla:   carga {carga['segundos']:.1f} s, {mib_tabla:,.1f} MiB")
        con = conectar(argumentos.memoria, base=str(BASE_BENCHMARK), solo_lectura=True)
        tiempos += medir(con, "tabla", clave, argumentos.repeticiones, resultados, filas)
        con.close()

        escalas.append({
            "escala": clave, "descripcion": descripcion, "periodo": periodo,
            "archivos": archivos, "filas": filas,
            "parquet_mib": round(mib_parquet, 1), "tabla_mib": round(mib_tabla, 1),
            "carga_segundos": round(carga["segundos"], 2),
        })

    if not argumentos.conservar:
        for archivo in (BASE_BENCHMARK, BASE_BENCHMARK.with_name(BASE_BENCHMARK.name + ".wal")):
            archivo.unlink(missing_ok=True)

    for nombre, filas_csv in (("tiempos.csv", tiempos), ("escalas.csv", escalas)):
        with (DIR_RESULTADOS / nombre).open("w", newline="", encoding="utf-8") as archivo:
            escritor = csv.DictWriter(archivo, fieldnames=list(filas_csv[0]))
            escritor.writeheader()
            escritor.writerows(filas_csv)

    (DIR_RESULTADOS / "ambiente.txt").write_text(
        f"fecha: {time.strftime('%Y-%m-%d %H:%M')}\n"
        f"duckdb: {duckdb.__version__}\n"
        f"python: {platform.python_version()}\n"
        f"hilos: {hilos}\n"
        f"memory_limit: {argumentos.memoria}\n"
        f"repeticiones: {argumentos.repeticiones} (+1 primera ejecucion)\n",
        encoding="utf-8")

    df = pd.DataFrame(tiempos)
    resumen = (df[df.ejecucion == "repetida"]
               .groupby(["escala", "consulta", "estrategia"], sort=False).segundos.median()
               .unstack("estrategia"))
    resumen["parquet/tabla"] = (resumen.parquet / resumen.tabla).round(1)
    print("\nMediana de las ejecuciones repetidas (segundos):")
    print(resumen.round(3).to_string())
    print(f"\nResultados en {DIR_RESULTADOS.relative_to(RAIZ_PROYECTO)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
