#!/usr/bin/env python3
"""Descarga los archivos Parquet del NYC TLC Trip Record Data.

Descarga los registros de viajes de taxis amarillos (yellow) y verdes (green).
Por defecto descarga el anio 2026, que es el conjunto de datos inicial del
laboratorio; con --anio se pueden indicar otros anios.

Fuente oficial de los datos:
    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Uso:
    python scripts/download_data.py                     # amarillos y verdes, 2026
    python scripts/download_data.py --taxi yellow
    python scripts/download_data.py --taxi green
    python scripts/download_data.py --anio 2024 2025    # otros anios
    python scripts/download_data.py --solo-verificar    # no descarga, solo compara

Los archivos se guardan en:
    data/raw/<tipo>/<anio>/<nombre-original>.parquet
    data/raw/zones/taxi_zone_lookup.csv     (tabla de zonas, una sola vez)

La ruta es relativa a la raiz del proyecto (no al directorio actual), de modo
que el script puede ejecutarse desde cualquier carpeta.

Comportamiento:
  - La TLC publica cada mes con varias semanas de atraso, por lo que no todos
    los meses existen todavia. El script consulta al servidor que meses estan
    publicados en lugar de suponerlos. El servidor responde 403/404 para los
    meses no publicados.
  - Un archivo que ya existe localmente no se vuelve a descargar, siempre que
    sea un Parquet valido y su tamanio coincida con el publicado por la TLC.
    Si difiere (archivo truncado o version republicada por la TLC) se
    descarga de nuevo.
  - Una falla de red no se confunde con un mes no publicado: se reporta como
    fallida y el script termina con codigo de salida distinto de cero.
  - La descarga se hace sobre un nombre temporal y solo se renombra al
    terminar y validar el archivo, de modo que una interrupcion no deja
    archivos .parquet a medias.
  - Al final se muestra un inventario de lo que hay en disco (archivos,
    filas y tamanio) y se advierte si hay huecos en los meses publicados.
"""

import argparse
import sys
from pathlib import Path

import pyarrow.parquet as pq
import requests

ANIO_POR_DEFECTO = 2026
TIPOS_TAXI = ("yellow", "green")
URL_BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data"
RAIZ_PROYECTO = Path(__file__).resolve().parent.parent
DIR_DESTINO = RAIZ_PROYECTO / "data" / "raw"

TIEMPO_ESPERA = 60          # segundos por peticion
INTENTOS = 3                # intentos por archivo antes de darse por vencido
BLOQUE = 1024 * 1024        # 1 MiB por bloque de descarga
SUFIJO_TEMPORAL = ".part"
CODIGOS_NO_PUBLICADO = (403, 404)   # S3/CloudFront responde 403 si no existe
FIRMA_PARQUET = b"PAR1"             # bytes al inicio y al final de todo Parquet

# Tabla de zonas de la TLC: relaciona PULocationID/DOLocationID con su
# distrito (Borough) y nombre de zona. Es la misma para todos los anios.
URL_ZONAS = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
RUTA_ZONAS = DIR_DESTINO / "zones" / "taxi_zone_lookup.csv"
ENCABEZADO_ZONAS = '"LocationID","Borough","Zone","service_zone"'


def construir_nombre(tipo: str, anio: int, mes: int) -> str:
    """Nombre del archivo publicado por la TLC, p. ej. yellow_tripdata_2026-01.parquet."""
    return f"{tipo}_tripdata_{anio}-{mes:02d}.parquet"


def construir_url(tipo: str, anio: int, mes: int) -> str:
    """URL completa del archivo Parquet mensual."""
    return f"{URL_BASE}/{construir_nombre(tipo, anio, mes)}"


def ruta_destino(tipo: str, anio: int, mes: int) -> Path:
    """Ruta local donde se guarda el archivo."""
    return DIR_DESTINO / tipo / str(anio) / construir_nombre(tipo, anio, mes)


def ruta_legible(ruta: Path) -> str:
    """Ruta relativa a la raiz del proyecto, para mensajes."""
    try:
        return str(ruta.relative_to(RAIZ_PROYECTO))
    except ValueError:
        return str(ruta)


def consultar_servidor(url: str) -> tuple:
    """Pregunta al servidor por un archivo sin descargarlo.

    Devuelve una tupla (estado, dato):
      ("publicado", tamanio_en_bytes_o_None)
      ("no_publicado", codigo_http)
      ("error", mensaje)   -> falla de red u otra respuesta inesperada
    """
    ultimo_error = None
    for _ in range(INTENTOS):
        try:
            respuesta = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
        except requests.RequestException as error:
            ultimo_error = str(error)
            continue
        if respuesta.ok:
            tamanio = respuesta.headers.get("Content-Length")
            return "publicado", int(tamanio) if tamanio else None
        if respuesta.status_code in CODIGOS_NO_PUBLICADO:
            return "no_publicado", respuesta.status_code
        ultimo_error = f"HTTP {respuesta.status_code}"
    return "error", ultimo_error


def es_parquet_valido(ruta: Path) -> bool:
    """Comprueba la firma PAR1 al inicio y al final del archivo.

    Un archivo truncado pierde el pie (footer) del Parquet, por lo que esta
    verificacion barata detecta descargas incompletas sin leer los datos.
    """
    try:
        if ruta.stat().st_size < 2 * len(FIRMA_PARQUET):
            return False
        with ruta.open("rb") as archivo:
            inicio = archivo.read(len(FIRMA_PARQUET))
            archivo.seek(-len(FIRMA_PARQUET), 2)
            fin = archivo.read(len(FIRMA_PARQUET))
    except OSError:
        return False
    return inicio == FIRMA_PARQUET and fin == FIRMA_PARQUET


def contar_filas(ruta: Path):
    """Cantidad de filas segun los metadatos del Parquet (no lee los datos)."""
    try:
        return pq.ParquetFile(ruta).metadata.num_rows
    except Exception:  # archivo corrupto o ilegible
        return None


def formato_tamanio(n: float) -> str:
    for unidad in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unidad == "GiB":
            return f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n:.1f} GiB"


def limpiar_temporales(directorio: Path) -> None:
    """Elimina archivos .part que hayan quedado de ejecuciones interrumpidas."""
    if directorio.exists():
        for temporal in directorio.glob(f"*{SUFIJO_TEMPORAL}"):
            temporal.unlink(missing_ok=True)


def descargar_archivo(url: str, destino: Path, tamanio_esperado) -> int:
    """Descarga `url` en `destino`. Devuelve la cantidad de bytes escritos.

    Antes de renombrar el archivo temporal verifica que el tamanio coincida
    con el anunciado por el servidor y que sea un Parquet valido.
    """
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporal = destino.with_name(destino.name + SUFIJO_TEMPORAL)

    ultimo_error = None
    for intento in range(1, INTENTOS + 1):
        try:
            with requests.get(url, stream=True, timeout=TIEMPO_ESPERA) as respuesta:
                respuesta.raise_for_status()
                escritos = 0
                with temporal.open("wb") as archivo:
                    for bloque in respuesta.iter_content(chunk_size=BLOQUE):
                        if bloque:
                            archivo.write(bloque)
                            escritos += len(bloque)
            if escritos == 0:
                raise requests.RequestException("el servidor devolvio un archivo vacio")
            if tamanio_esperado is not None and escritos != tamanio_esperado:
                raise requests.RequestException(
                    f"descarga incompleta ({escritos} de {tamanio_esperado} bytes)"
                )
            if not es_parquet_valido(temporal):
                raise requests.RequestException("el archivo descargado no es un Parquet valido")
            temporal.replace(destino)
            return escritos
        except requests.RequestException as error:
            ultimo_error = error
            if intento < INTENTOS:
                print(f"      intento {intento}/{INTENTOS} fallido ({error}); reintentando")
        finally:
            # Tambien cubre Ctrl+C: nunca queda un .part a medias.
            temporal.unlink(missing_ok=True)

    raise requests.RequestException(f"no se pudo descargar {url}: {ultimo_error}")


def resumen_vacio() -> dict:
    return {"descargados": 0, "actualizados": 0, "omitidos": 0,
            "no_publicados": [], "fallidos": [], "pendientes": [], "publicados": []}


def descargar(tipo: str, anio: int, solo_verificar: bool = False) -> dict:
    """Descarga todos los meses publicados de un tipo de taxi para un anio."""
    print(f"\n=== {tipo.upper()} {anio} ===")
    resumen = resumen_vacio()
    limpiar_temporales(DIR_DESTINO / tipo / str(anio))

    for mes in range(1, 13):
        etiqueta = f"{anio}-{mes:02d}"
        destino = ruta_destino(tipo, anio, mes)
        url = construir_url(tipo, anio, mes)

        estado, dato = consultar_servidor(url)
        existe = destino.exists()
        local_valido = existe and es_parquet_valido(destino)

        if estado == "error":
            if local_valido:
                print(f"  {etiqueta}  ya existe; no se pudo verificar con el servidor ({dato})")
                resumen["omitidos"] += 1
            else:
                print(f"  {etiqueta}  ERROR al consultar el servidor: {dato}")
                resumen["fallidos"].append(etiqueta)
            continue

        if estado == "no_publicado":
            if local_valido:
                print(f"  {etiqueta}  ya existe localmente, pero el servidor ya no lo publica")
                resumen["omitidos"] += 1
            else:
                print(f"  {etiqueta}  aun no publicado por la TLC (HTTP {dato})")
                resumen["no_publicados"].append(etiqueta)
            continue

        resumen["publicados"].append(mes)
        tamanio_remoto = dato
        tamanio_local = destino.stat().st_size if existe else None
        coincide = tamanio_remoto is None or tamanio_local == tamanio_remoto

        if local_valido and coincide:
            print(f"  {etiqueta}  ya existe, se omite")
            resumen["omitidos"] += 1
            continue

        if existe:
            motivo = ("no es un Parquet valido" if not local_valido else
                      f"tamanio local {tamanio_local} != servidor {tamanio_remoto}")
            accion = "se vuelve a descargar"
        else:
            motivo, accion = "no existe localmente", "descargando..."

        if solo_verificar:
            print(f"  {etiqueta}  PENDIENTE: {motivo}")
            resumen["pendientes"].append(etiqueta)
            continue

        print(f"  {etiqueta}  {motivo}; {accion}" if existe else f"  {etiqueta}  {accion}")
        try:
            escritos = descargar_archivo(url, destino, tamanio_remoto)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR: {error}")
            resumen["fallidos"].append(etiqueta)
        else:
            print(f"  {etiqueta}  listo ({formato_tamanio(escritos)}) -> {ruta_legible(destino)}")
            resumen["actualizados" if existe else "descargados"] += 1

    return resumen


def meses_con_huecos(resumen: dict) -> list:
    """Meses no publicados anteriores al ultimo mes que si esta publicado.

    La TLC publica en orden; si falta un mes intermedio es una anomalia
    que debe revisarse.
    """
    if not resumen["publicados"]:
        return []
    ultimo_publicado = max(resumen["publicados"])
    return [m for m in (int(e[-2:]) for e in resumen["no_publicados"]) if m < ultimo_publicado]


def inventario(tipo: str, anio: int) -> None:
    """Muestra los archivos en disco con su cantidad de filas y tamanio."""
    archivos = sorted((DIR_DESTINO / tipo / str(anio)).glob("*.parquet"))
    if not archivos:
        print(f"  {tipo:<6} {anio}  (sin archivos)")
        return
    total_filas, total_bytes = 0, 0
    for archivo in archivos:
        filas = contar_filas(archivo)
        tamanio = archivo.stat().st_size
        total_bytes += tamanio
        total_filas += filas or 0
        texto_filas = f"{filas:>12,}" if filas is not None else "   ILEGIBLE "
        print(f"  {archivo.name:<36} {texto_filas} filas  {formato_tamanio(tamanio):>10}")
    print(f"  {'TOTAL ' + tipo + ' ' + str(anio):<36} {total_filas:>12,} filas  "
          f"{formato_tamanio(total_bytes):>10}  ({len(archivos)} archivos)")


def descargar_zonas(solo_verificar: bool = False) -> str:
    """Descarga la tabla de zonas de la TLC si no existe localmente.

    Devuelve "omitido", "descargado", "pendiente" o "fallido".
    """
    print("\n=== ZONAS (taxi_zone_lookup.csv) ===")
    if RUTA_ZONAS.exists() and RUTA_ZONAS.read_text(encoding="utf-8").startswith(ENCABEZADO_ZONAS):
        print(f"  ya existe, se omite -> {ruta_legible(RUTA_ZONAS)}")
        return "omitido"
    if solo_verificar:
        print("  PENDIENTE: no existe localmente o no es valido")
        return "pendiente"

    RUTA_ZONAS.parent.mkdir(parents=True, exist_ok=True)
    temporal = RUTA_ZONAS.with_name(RUTA_ZONAS.name + SUFIJO_TEMPORAL)
    try:
        respuesta = requests.get(URL_ZONAS, timeout=TIEMPO_ESPERA)
        respuesta.raise_for_status()
        if not respuesta.text.startswith(ENCABEZADO_ZONAS):
            raise requests.RequestException("el archivo no tiene el encabezado esperado")
        temporal.write_text(respuesta.text, encoding="utf-8")
        temporal.replace(RUTA_ZONAS)
    except requests.RequestException as error:
        print(f"  ERROR: {error}")
        return "fallido"
    finally:
        temporal.unlink(missing_ok=True)
    zonas = len(RUTA_ZONAS.read_text(encoding="utf-8").splitlines()) - 1
    print(f"  listo ({zonas} zonas) -> {ruta_legible(RUTA_ZONAS)}")
    return "descargado"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Descarga los datos de viajes de taxi del NYC TLC."
    )
    parser.add_argument(
        "--taxi", choices=(*TIPOS_TAXI, "all"), default="all",
        help="tipo de taxi a descargar (por defecto: all)",
    )
    parser.add_argument(
        "--anio", type=int, nargs="+", default=[ANIO_POR_DEFECTO],
        help=f"anio o anios a descargar (por defecto: {ANIO_POR_DEFECTO})",
    )
    parser.add_argument(
        "--solo-verificar", action="store_true",
        help="no descarga nada; solo compara los archivos locales con el servidor",
    )
    argumentos = parser.parse_args()

    tipos = TIPOS_TAXI if argumentos.taxi == "all" else (argumentos.taxi,)

    total = resumen_vacio()
    huecos = []
    for anio in argumentos.anio:
        for tipo in tipos:
            resumen = descargar(tipo, anio, argumentos.solo_verificar)
            for clave in ("descargados", "actualizados", "omitidos"):
                total[clave] += resumen[clave]
            for clave in ("no_publicados", "fallidos", "pendientes"):
                total[clave] += [f"{tipo} {m}" for m in resumen[clave]]
            huecos += [f"{tipo} {anio}-{m:02d}" for m in meses_con_huecos(resumen)]

    estado_zonas = descargar_zonas(argumentos.solo_verificar)
    if estado_zonas in ("fallido", "pendiente"):
        total[estado_zonas + "s"].append("zonas")

    print("\n" + "=" * 60)
    print("RESUMEN" + (" (solo verificacion)" if argumentos.solo_verificar else ""))
    print("=" * 60)
    print(f"  descargados   : {total['descargados']}")
    print(f"  actualizados  : {total['actualizados']}")
    print(f"  ya existian   : {total['omitidos']}")
    print(f"  no publicados : {len(total['no_publicados'])}")
    if total["no_publicados"]:
        print(f"      {', '.join(total['no_publicados'])}")
    if argumentos.solo_verificar:
        print(f"  pendientes    : {len(total['pendientes'])}")
        if total["pendientes"]:
            print(f"      {', '.join(total['pendientes'])}")
    print(f"  fallidos      : {len(total['fallidos'])}")
    if total["fallidos"]:
        print(f"      {', '.join(total['fallidos'])}")
    if huecos:
        print(f"  ADVERTENCIA: meses intermedios no publicados: {', '.join(huecos)}")
    print("=" * 60)

    print("\nINVENTARIO LOCAL")
    print("-" * 60)
    for anio in argumentos.anio:
        for tipo in tipos:
            inventario(tipo, anio)
    print("-" * 60)

    return 1 if total["fallidos"] or total["pendientes"] else 0


if __name__ == "__main__":
    sys.exit(main())
