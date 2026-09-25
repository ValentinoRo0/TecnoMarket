# TecnoMarket — Business Intelligence & Data Mart para Retail

Proyecto de Business Intelligence construido sobre un retail ficticio de tecnología (**TecnoMarket**), desarrollado como trabajo del curso **Base de Datos Avanzada y Big Data** de la carrera de Ingeniería de Sistemas Computacionales, Universidad Privada del Norte (UPN), 2026.

El proyecto resuelve un problema típico de retail: información comercial y logística dispersa en archivos y bases aisladas, sin visión consolidada para detectar quiebres de stock ni analizar el desempeño entre años. La solución construye un **Data Mart con modelo dimensional en estrella**, alimentado por un pipeline ETL, con dos implementaciones complementarias: una en **PySpark → BigQuery → Looker Studio**, y otra directamente en **SQL Server**.

## Flujo del pipeline (PySpark)

```
CSV originales (clientes, productos, geografía, ventas)
        │
        ▼
   PySpark (Google Colab)
   Extracción · Limpieza · Transformación
        │
        ▼
Modelo Estrella (7 dimensiones + 1 tabla de hechos)
        │
        ▼
      BigQuery
        │
        ▼
   Looker Studio (dashboards y KPIs)
```

**Lo que hace el notebook (`notebooks/TecnoMarket_PySpark.ipynb`):**
- Extrae los datos de origen desde archivos CSV (clientes, productos, geografía y ventas).
- Detecta y reporta valores nulos antes y después de la limpieza.
- Limpia y estandariza texto, corrige tipos de datos y normaliza fechas en múltiples formatos.
- Construye 7 dimensiones (`dim_clientes`, `dim_productos`, `dim_geografia`, `dim_tiempo`, `dim_sucursales`, `dim_promociones`, `dim_metodos_pago`) y una tabla de hechos (`fact_ventas`), integrándolas mediante joins.
- Calcula métricas de negocio: crecimiento interanual por categoría (unidades vendidas, facturación bruta, descuentos, ingreso neto) e inteligencia territorial (transacciones, productos despachados, venta neta, ticket promedio).
- Exporta las tablas resultantes y las carga en Google BigQuery para su análisis en Looker Studio.

## Implementación complementaria en SQL Server

El archivo `sql/TecnoMarket_SQLServer.sql` implementa el mismo modelo dimensional directamente en SQL Server, añadiendo:
- Claves foráneas y restricciones `CHECK` para integridad de datos.
- Procedimientos almacenados (por ejemplo, para procesar devoluciones e identificar clientes inactivos).
- Una función definida por el usuario (UDF).
- Transacciones (`BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`).
- Vistas analíticas y datos de prueba.

Esta implementación es independiente del flujo PySpark → BigQuery: ambas comparten el mismo modelo dimensional, pero cada una construye y carga sus dimensiones por su cuenta (por ejemplo, `dim_tiempo` se genera automáticamente a partir de las fechas de venta en PySpark, mientras que en SQL Server se carga con fechas de referencia).

## Estructura del repositorio

```
TecnoMarket/
├── README.md
├── data/
│   ├── raw/                  # CSV originales de entrada
│   └── modelo_estrella/      # Dimensiones y tabla de hechos generadas por el ETL
├── notebooks/
│   └── TecnoMarket_PySpark.ipynb
├── sql/
│   └── TecnoMarket_SQLServer.sql
└── docs/
    └── TecnoMarket_Documentacion.docx   # Documentación completa del proyecto
```

## Tecnologías

Python (PySpark) · SQL Server · Google BigQuery · Looker Studio · Google Colab

## Nota sobre los datos

Todos los datos (clientes, productos, ventas y geografía) son **ficticios**, generados con fines académicos. No representan personas, productos ni transacciones reales.

## Equipo

Proyecto grupal desarrollado por:
- Bujaico Gutiérrez, Richard Joaquín
- Chávez Barrueto, Anyerson Marcial
- Huamani Soto, Renzo Omar Jefferson
- **Rocero Murillo, Roberto Valentino**

Curso: Base de Datos Avanzada y Big Data — Docente: Alcántara Pinedo, Elvis Wilson
Universidad Privada del Norte (UPN), 2026
