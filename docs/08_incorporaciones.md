# Ejercicio 8 - Incorporación de datos de 2025 y análisis completo

Se incorporaron los datos de **2025** al flujo existente, manteniendo la misma estructura utilizada para 2024 y 2026. El análisis se realizó con DuckDB sobre `data/processed/taxis.duckdb` y las visualizaciones se actualizaron en Metabase.

## 8.1 Incorporación de datos de 2025

Se actualizó `scripts/download_data.py` para incluir por defecto los años `(2024, 2025, 2026)`.

Para 2025 se descargaron **24 archivos nuevos**:
- 12 archivos yellow: **48,722,602 registros**
- 12 archivos green: **591,375 registros**

Comando utilizado:

```bash
docker exec lab8-lab python scripts/download_data.py --anio 2025
```

## 8.2 Verificación de archivos existentes

El sistema conserva la validación que evita volver a descargar archivos ya disponibles.

```bash
docker exec lab8-lab python scripts/download_data.py --anio 2025 --solo-verificar
```

La verificación confirmó los 24 archivos existentes, sin pendientes, fallidos ni meses faltantes.

## 8.3 Verificación de consultas

La base DuckDB se actualizó con los datos de 2025 y se comprobó que las consultas I1-I11 continúan funcionando sobre el conjunto ampliado.

I2 pasó a comparar automáticamente:
- 2025 vs. 2024
- 2026 vs. 2025

Los indicadores que requieren períodos comunes utilizan **enero-agosto**.

## 8.4 Actualización de indicadores y visualizaciones

Las once visualizaciones fueron actualizadas para considerar **2024, 2025 y 2026**. No fue necesario modificar la lógica SQL de los indicadores.

El dashboard existente conserva las 11 visualizaciones sin duplicados y mantiene la misma organización del Ejercicio 7.

## 8.5 Evolución de los indicadores

Para comparar los tres años se utilizaron los meses de enero a agosto.

Los principales resultados fueron:
- La demanda aumentó **19.09%** de 2024 a 2025 y disminuyó **5.99%** de 2025 a 2026.
- El costo típico del viaje aumentó en ambas transiciones.
- Flex Fare pasó de **9.43%** a **23.07%** y luego a **25.85%**.
- Los aeropuertos redujeron su participación relativa en viajes e ingresos.
- La calidad de los registros yellow empeoró en 2025 y mejoró parcialmente en 2026.

## 8.6 Patrones principales

1. **Máximo de demanda en 2025.** El crecimiento de 2025 fue seguido por una reducción parcial en 2026.
2. **Crecimiento sostenido de Flex Fare.** Su participación aumentó durante los tres años.
3. **Aumento continuo del costo típico.** La mediana del cobro creció en los períodos comparables.
4. **Menor peso relativo de los aeropuertos.** Su participación en viajes e ingresos disminuyó de forma continua.
5. **Cambio en la calidad de yellow.** Los registros inválidos pasaron de 3.31% en 2024 a 9.05% en 2025 y 4.92% en 2026.

## 8.7 Consultas utilizadas

Se reutilizaron las mismas **11 consultas SQL** de los indicadores I1-I11 desarrolladas en el Ejercicio 7, ubicadas en:

`sql/07_indicadores/`

No fue necesario crear nuevas consultas analíticas para 8.5 o 8.6. Los resultados comparativos se obtuvieron a partir de las salidas existentes, utilizando enero-agosto como período común cuando fue necesario.

## Reproducción básica

```bash
docker exec lab8-lab python scripts/download_data.py --anio 2025
docker exec lab8-lab python scripts/materializar.py
docker exec lab8-lab python scripts/run_sql.py sql/07_indicadores --base data/processed/taxis.duckdb
docker exec --env-file .env lab8-lab python scripts/metabase_indicadores.py
```

El notebook del ejercicio se encuentra en:

`notebooks/08_incorporacion2025.ipynb`
