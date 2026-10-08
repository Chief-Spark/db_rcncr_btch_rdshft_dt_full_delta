---
title: RECONOCER — Overview del proyecto
audience: kiro, desarrolladores, arquitectos
sources: AGENTS.md, 01_contexto_proyecto.md, RESUMEN_EJECUTIVO.md
last_updated: 2026-09-03
---

# RECONOCER — Migracion Teradata a Redshift

## Que es Reconocer

Sistema de Experian Colombia que procesa **~65–70 millones** de registros de contacto (direcciones, telefonos, emails) de ciudadanos colombianos. Consolida, estandariza, unifica y ordena datos de contactabilidad para productos de buró y servicios en linea.

## Driver de migracion

| Hito | Fecha / estado |
|------|----------------|
| Apagado Teradata | **31 marzo 2027** (deadline Experian) |
| Destino compute SQL | **Amazon Redshift** (cluster consumidor Reconocer Batch) |
| Destino estandarizacion | **EDF** (Spark/Scala) en cuenta productor |
| Orquestacion legacy | Control-M → **Framework Batch** (AWS Step Functions) |

## Arquitectura objetivo

```
COBOL (ICBDIR) → EDF (Spark/Scala) → Redshift (SQL) → DB2 (Online)
                  Ingesta +            Unificacion
                  Estandarizacion      Ordenamiento
                                       Calculo + Batch
```

### Procesos principales en Redshift

| Proceso | Descripcion | Estado migracion |
|---------|-------------|------------------|
| **Estandarizacion** | Libreria J17 / IFR sobre direcciones | En EDF (no Redshift) |
| **Unificacion** | 3 reglas + motor nuevas direcciones | Migrado (R1–R3 + motor) |
| **Ordenamiento** | Scoring contactabilidad 4 canales | En progreso (17 SPs) |
| **Geo** | Geocodificacion ArcGIS + enriquecimiento | Contratos S3 definidos |

## Codigo Teradata original (TBT)

Ubicacion de solo lectura: `Experian Reconocer/` en repo MT-EXP-005-MAP-RECONOCER.

### Convenciones de nomenclatura Teradata

| Sufijo | Rol |
|--------|-----|
| `_111` | Setup (DDL tablas/vistas) |
| `_120` | Carga de datos |
| `_130` | Transformacion principal (logica negocio) |
| `_140` | Exportacion / resultado |

| Extension | Rol |
|-----------|-----|
| `.TPT` | Teradata Parallel Transporter |
| `.BTQ` | BTEQ script (batch) |

### Procesos Teradata clave

| Proceso | Scripts origen | Tamano / notas |
|---------|----------------|----------------|
| Unificacion | P0019, P0020, P0021 (`.TPT`) | `Unificacion.sql` ~311 KB; motor 6.220 lineas |
| Ordenamiento | P0027, P0029 | `Ordenamiento.sql`; `Caracteristicas.txt` ~133 KB SQL dinamico |
| Orquestacion | `ORDENAMIENTO_242_131.BTQ` | Malla Control-M |

### Vistas y parametros compartidos Experian

- `V_Insumo_Unificacion_Regla*.txt` — vistas de insumo por regla
- `Caracteristicas.txt` — ~160 sentencias SQL de coeficientes Beta (ordenamiento)
- Modelo XPM: tablas `xpm`, `xpm_location`, `xpm_location_val_contactinformations`

## Data Sharing (lectura desde Alpha)

El cluster **consumidor** lee datos estandarizados via:

```
ds_dba_rncr_batch.edf_views.*
```

Sin copiar tablas del productor. Los SP de Unificacion escriben solo en esquemas locales `bdm_datos`, `bdm_tempo`, `bdm_stage`.

## Repos de despliegue (pipeline Redshift)

| Repo | Tipo |
|------|------|
| `db_rcncr_btch_rdshft_strct` | Estructura |
| `db_rcncr_btch_rdshft_pgm` | Programas (SP) |
| `db_rcncr_btch_rdshft_dt` | Datos / ejecucion |

Ver [`GUIA_IA_REORGANIZACION_REPOS.md`](GUIA_IA_REORGANIZACION_REPOS.md).

## Workspaces de desarrollo

| Carpeta | Contenido |
|---------|-----------|
| `ws-unificacion/` | Migracion Unificacion Teradata → Redshift |
| `ws-ordenamiento/` | Migracion Ordenamiento 242 |
| `proyecto/` | Arquitectura, gestion, orquestacion |
| `Framework-Batch/` | YAML, PP9999 sandbox, datasharing |

## Reglas para agentes IA

1. **NO modificar** `Experian Reconocer/` (dump original cliente).
2. Codigo migrado va en `src/redshift/` del workspace o en los 3 repos Bitbucket.
3. Documentacion nueva en `docs/` del workspace o en este consolidado.
4. Promocion Dev → QA → PDN solo via pipeline Jira + Jenkins.
