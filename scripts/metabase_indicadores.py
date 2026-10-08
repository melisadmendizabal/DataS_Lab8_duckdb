#!/usr/bin/env python3
"""Crea en Metabase las visualizaciones de los indicadores (Ejercicio 7.4).

Las preguntas (cards) de Metabase se guardan en su volumen de Docker, no en
el repositorio. Este script las genera a partir de los archivos versionados
en sql/07_indicadores/, de modo que las visualizaciones son reproducibles:

  1. inicia sesion con MB_USER / MB_PASSWORD;
  2. registra (si no existe) la base data/processed/taxis.duckdb en modo
     solo lectura;
  3. crea (o actualiza, si ya existe con el mismo nombre) una pregunta SQL
     por indicador en la coleccion "Lab 8 - Indicadores", con su tipo de
     grafico definido en INDICADORES;
  4. ejecuta cada pregunta y reporta cuantas filas devolvio.

Uso (desde la raiz del proyecto, con el ambiente levantado y la base
materializada con scripts/materializar.py):

    docker exec --env-file .env lab8-lab python scripts/metabase_indicadores.py

Variables de entorno:
    MB_USER, MB_PASSWORD   usuario de Metabase (archivo .env, no versionado)
    MB_URL                 por defecto http://metabase:3000 (red de Docker Compose)

Solo usa la libreria estandar de Python.
"""

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

RAIZ_PROYECTO = Path(__file__).resolve().parent.parent
DIR_SQL = RAIZ_PROYECTO / "sql" / "07_indicadores"

NOMBRE_BASE = "Taxis NYC (DuckDB)"
# Ruta de la base dentro del contenedor de Metabase (data/ esta montada ahi).
ARCHIVO_BASE = "/workspace/data/processed/taxis.duckdb"
NOMBRE_COLECCION = "Lab 8 - Indicadores"
# Direccion para abrir los enlaces desde el navegador del host.
URL_NAVEGADOR = "http://localhost:3000"


def grafico(display, x, serie, metrica, x_titulo, y_titulo, apilado=None, ordinal=False):
    """visualization_settings de Metabase para un grafico con una serie."""
    ajustes = {
        "graph.dimensions": [x, serie] if serie else [x],
        "graph.metrics": [metrica],
        "graph.x_axis.title_text": x_titulo,
        "graph.y_axis.title_text": y_titulo,
        "graph.show_values": False,
    }
    if apilado:
        ajustes["stackable.stack_type"] = apilado
    if ordinal:
        ajustes["graph.x_axis.scale"] = "ordinal"
    return display, ajustes


# archivo -> (titulo, (display, visualization_settings))
INDICADORES = {
    "01_viajes_por_mes.sql": (
        "I1 Viajes por mes",
        grafico("line", "mes", "anio", "viajes", "Mes", "Viajes", ordinal=True)),
    "02_variacion_interanual.sql": (
        "I2 Variacion interanual de viajes por tipo de taxi",
        grafico("bar", "mes", "serie", "variacion_pct", "Mes",
                "Variacion vs. mismo mes del anio anterior (%)", ordinal=True)),
    "03_costo_por_viaje.sql": (
        "I3 Costo tipico de un viaje (total mediano, yellow)",
        grafico("line", "mes", "anio", "total_mediano_usd", "Mes", "Total mediano (USD)",
                ordinal=True)),
    "04_composicion_del_cobro.sql": (
        "I4 Composicion del cobro promedio por viaje (yellow, ene-ago)",
        grafico("bar", "anio", "componente", "usd_promedio", "Anio", "USD por viaje",
                apilado="stacked")),
    "05_metodos_de_pago.sql": (
        "I5 Metodos de pago por mes",
        grafico("bar", "mes", "metodo_pago", "pct_del_mes", "Mes", "% de los viajes",
                apilado="stacked")),
    "06_propina_con_tarjeta.sql": (
        "I6 Viajes con propina (pagos con tarjeta)",
        grafico("line", "mes", "anio", "pct_con_propina", "Mes",
                "% de viajes con tarjeta que dejan propina", ordinal=True)),
    "07_demanda_por_hora.sql": (
        "I7 Demanda promedio por hora del dia",
        grafico("line", "hora", "serie", "viajes_promedio", "Hora de inicio",
                "Viajes promedio por fecha", ordinal=True)),
    "08_velocidad_manhattan.sql": (
        "I8 Velocidad mediana en Manhattan por hora (laborables, yellow)",
        grafico("line", "hora", "anio", "velocidad_mediana_mph", "Hora de inicio",
                "Velocidad mediana (mph)", ordinal=True)),
    "09_zonas_de_origen.sql": (
        "I9 Zonas con mas viajes de origen",
        grafico("row", "zona", "anio", "pct_viajes", "Zona de origen", "% de los viajes del anio")),
    "10_aeropuertos.sql": (
        "I10 Aeropuertos: participacion en viajes e ingresos (ene-ago)",
        grafico("bar", "aeropuerto", "serie", "pct", "Aeropuerto", "% del anio")),
    "11_calidad_de_datos.sql": (
        "I11 Registros que no pasan las reglas de calidad",
        grafico("line", "mes", "tipo", "pct_invalidos", "Mes", "% de registros invalidos")),
}


class Metabase:
    def __init__(self, url: str):
        self.url = url.rstrip("/")
        self.sesion = None

    def pedir(self, metodo: str, ruta: str, cuerpo=None):
        datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
        encabezados = {"Content-Type": "application/json"}
        if self.sesion:
            encabezados["X-Metabase-Session"] = self.sesion
        peticion = urllib.request.Request(self.url + ruta, data=datos,
                                          headers=encabezados, method=metodo)
        try:
            with urllib.request.urlopen(peticion, timeout=600) as respuesta:
                contenido = respuesta.read()
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"{metodo} {ruta} -> HTTP {error.code}: "
                               f"{error.read().decode(errors='replace')[:500]}") from None
        return json.loads(contenido) if contenido else None

    def iniciar_sesion(self, usuario: str, clave: str):
        self.sesion = self.pedir("POST", "/api/session",
                                 {"username": usuario, "password": clave})["id"]


def obtener_base(mb: Metabase) -> int:
    bases = mb.pedir("GET", "/api/database")
    bases = bases.get("data", bases) if isinstance(bases, dict) else bases
    for base in bases:
        if base["name"] == NOMBRE_BASE:
            return base["id"]
    base = mb.pedir("POST", "/api/database", {
        "engine": "duckdb",
        "name": NOMBRE_BASE,
        # Solo lectura: permite que notebooks y scripts abran la base al mismo
        # tiempo (un .duckdb admite un solo proceso con permiso de escritura).
        "details": {"database_file": ARCHIVO_BASE, "read_only": True, "memory_limit": "2GB"},
        "is_full_sync": True,
    })
    print(f"  base registrada: {NOMBRE_BASE} (id {base['id']}) -> {ARCHIVO_BASE}")
    return base["id"]


def obtener_coleccion(mb: Metabase) -> int:
    for coleccion in mb.pedir("GET", "/api/collection"):
        if coleccion.get("name") == NOMBRE_COLECCION and not coleccion.get("archived"):
            return coleccion["id"]
    coleccion = mb.pedir("POST", "/api/collection", {
        "name": NOMBRE_COLECCION,
        "description": "Indicadores del Ejercicio 7 generados por scripts/metabase_indicadores.py",
    })
    return coleccion["id"]


def descripcion(ruta: Path) -> str:
    """Encabezado del archivo SQL sin los guiones, como descripcion de la pregunta."""
    lineas = []
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if not linea.startswith("--"):
            break
        lineas.append(linea[2:].strip())
    return "\n".join(lineas[1:]) + f"\n\nConsulta: sql/07_indicadores/{ruta.name}"


def main() -> int:
    usuario, clave = os.environ.get("MB_USER"), os.environ.get("MB_PASSWORD")
    if not usuario or not clave:
        print("Defina MB_USER y MB_PASSWORD (p. ej. docker exec --env-file .env ...)")
        return 1
    mb = Metabase(os.environ.get("MB_URL", "http://metabase:3000"))
    mb.iniciar_sesion(usuario, clave)

    id_base = obtener_base(mb)
    id_coleccion = obtener_coleccion(mb)
    existentes = {item["name"]: item["id"] for item in
                  mb.pedir("GET", f"/api/collection/{id_coleccion}/items?models=card")["data"]}

    errores = 0
    for archivo, (titulo, (display, ajustes)) in INDICADORES.items():
        ruta = DIR_SQL / archivo
        tarjeta = {
            "name": titulo,
            "description": descripcion(ruta),
            "collection_id": id_coleccion,
            "display": display,
            "visualization_settings": ajustes,
            "dataset_query": {
                "type": "native",
                "native": {"query": ruta.read_text(encoding="utf-8")},
                "database": id_base,
            },
        }
        if titulo in existentes:
            id_tarjeta = existentes[titulo]
            mb.pedir("PUT", f"/api/card/{id_tarjeta}", tarjeta)
            accion = "actualizada"
        else:
            id_tarjeta = mb.pedir("POST", "/api/card", tarjeta)["id"]
            accion = "creada"

        resultado = mb.pedir("POST", f"/api/card/{id_tarjeta}/query", {})
        if resultado.get("status") == "completed":
            filas = resultado.get("row_count", len(resultado["data"]["rows"]))
            print(f"  {titulo:<66} {accion:<11} {filas:>4} filas  {URL_NAVEGADOR}/question/{id_tarjeta}")
        else:
            errores += 1
            print(f"  {titulo:<66} {accion:<11} ERROR: {resultado.get('error')}")

    print(f"\nColeccion: {URL_NAVEGADOR}/collection/{id_coleccion}")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
