---
title: GEO — Proceso de geocodificacion
audience: kiro, desarrolladores
sources: ENTENDIMIENTO_PROCESO_GEO.md, PDFs Insumo/Salida Geo
last_updated: 2026-09-03
---

# Proceso Geo — Enriquecimiento geografico

## Overview y alcance

Etapa del pipeline **Reconocer Master Cloud** que geocodifica direcciones fisicas estandarizadas via **ArcGIS Enterprise**, enriquece atributos espaciales y devuelve resultados a Redshift.

| Aspecto | Detalle |
|---------|---------|
| Horario | Valle (EventBridge → Step Functions) |
| Trigger | Delta geo desde Redshift |
| Plataforma geo | ArcGIS Server + Aurora PostGIS |
| Integracion | S3 cross-account + SQS completion |

### Responsabilidades Reconocer

| # | Actividad |
|---|-----------|
| 1 | **INPUT:** UNLOAD delta geo → `s3://<bucket>/reconocer_input/` |
| 2 | **OUTPUT:** COPY desde `reconocer_output/` → staging → UPDATE tablas destino |

ArcGIS gestiona geocodificacion, enriquecimiento PostGIS y notificacion SQS.

## Flujo end-to-end

```
Redshift → UNLOAD CSV GZIP → S3 input
  → Step Functions → ArcGIS Server → Aurora PostGIS
  → S3 output + SQS
  → Lambda ResultTransfer → COPY staging → UPDATE tablas geo
```

## Contratos de archivo (PDFs oficiales)

| PDF | Contenido |
|-----|-----------|
| **Insumo GEO** | Esquema CSV INPUT (pipe-delimited, columnas delta geo) |
| **Salida Geo** | Esquema archivos retorno ArcGIS (coordenadas, barrio, estrato, DANE) |
| **Reconocer Master Cloud - Etapa d** | Etapa geo en contexto Master Cloud |

Copias referenciadas en [`referencias/INDICE_PDFS.md`](../referencias/INDICE_PDFS.md).

### INPUT (resumen)

- Formato: CSV pipe-delimited, comprimido GZIP
- Origen: UNLOAD Redshift de ubicaciones con delta (cambios desde ultima corrida geo)
- Destino S3: `reconocer_input/`

### OUTPUT (resumen)

- Archivos en `reconocer_output/` con atributos enriquecidos
- Lambda `ResultTransfer`: COPY a `adf_stages` staging
- UPDATE/UPSERT en tablas destino geo en Redshift

## Tablas Redshift relevantes

| Tabla / esquema | Rol |
|-----------------|-----|
| `relacion_ubicac_estandar_geo` | Relacion ubicacion ↔ geo |
| `adf_stages.*` | Staging post-ArcGIS |
| Tablas destino en `bdm_datos` | Atributos geo finales (barrio, estrato, lat/long validados) |

## Dependencias con otros procesos

- **Post-estandarizacion:** requiere direcciones estandarizadas en XPM
- **Pre-ordenamiento:** scores de direccion usan atributos geo
- **Regla 3 Unificacion:** usa lat/long de geo cuando disponible

## Estado implementacion

| Item | Estado |
|------|--------|
| Contratos PDF INPUT/OUTPUT | Documentados |
| Runbook S3/ArcGIS | `geo_runbook_s3_arcgis.md` |
| Scripts SQL dev/mock | `Geo/sql/` |
| Deploy Redshift pipeline | Referencia SLCOPRBA-1147/1148 |
| Integracion produccion | En curso con equipo ArcGIS Experian |
