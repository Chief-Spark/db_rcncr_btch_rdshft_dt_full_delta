---
title: Guia IA — Reorganizacion codigo en 3 repos Redshift
audience: agentes_ia, desarrolladores
last_updated: 2026-09-03
---

# Guia para IA: reorganizar codigo bajo pipeline DATABASE-REDSHIFT

> **Proposito:** Input canonico para Kiro, Cursor u otra IA que deba partir, mover o regenerar SQL de Reconocer en los 3 repos Bitbucket sin romper el pipeline Jenkins.

## 1. Los 3 repos

| Repo | `global.type` | Que va aqui |
|------|---------------|-------------|
| `db_rcncr_btch_rdshft_strct` | `structure` | CREATE TABLE, ALTER, vistas de lectura sobre `ds_dba_rncr_batch.edf_views`, catálogos, grants |
| `db_rcncr_btch_rdshft_pgm` | `program` | `CREATE OR REPLACE PROCEDURE`, funciones |
| `db_rcncr_btch_rdshft_dt` | `data` | DML lineal, `CALL` de certificacion, seeds, validaciones |

**Orden obligatorio por ambiente:** STRCT → PGM → DT.

## 2. Estructura de carpetas (no negociable)

```
<repo>/
├── .jenkins.yml
└── deploy/redshift/
    ├── deploy.par
    ├── rollback.par
    ├── SQL/
    └── RevSQL/
```

- Una linea en `.par` = un archivo en `SQL/` (deploy) o `RevSQL/` (rollback).
- `RevSQL/` usa **el mismo basename** que la linea de `rollback.par` (sin sufijo `_rev`).
- Archivos `.par` en **UTF-8 sin BOM** (error `REDSHIFT:207` si hay BOM).

## 3. Tabla de decision: tipo de objeto → repo

| Si el cambio es... | Repo |
|--------------------|------|
| Nueva tabla de salida, catalogo local, vista RO sobre `edf_views` | STRCT |
| `CREATE OR REPLACE PROCEDURE` | PGM |
| Script que se ejecuta statement a statement (`CALL`, `INSERT`, benchmark) | DT |
| `GRANT` sobre objeto creado en el mismo paquete | Mismo repo que el objeto |

## 4. Data Sharing — reglas de lectura/escritura

```
Productor (Alpha)                    Consumidor (Reconocer Batch)
edf_views.*  ──datashare──>  ds_dba_rncr_batch.edf_views.*
                                      │
                                      v
                             bdm_datos.pp9999_* (vistas SELECT)
                                      │
                                      v
                             bdm_tempo.pp9999_stg_* (staging)
                                      │
                                      v
                             bdm_datos.pp9999_unificacion_direccion (salida)
```

| Regla | Detalle |
|-------|---------|
| Lectura Alpha | Solo `SELECT` desde `ds_dba_rncr_batch.edf_views.*` |
| Prohibido | `INSERT`/`UPDATE`/`COPY` desde el datashare |
| Escritura local | `bdm_datos`, `bdm_tempo`, `bdm_stage` |
| Puente | Vistas en STRCT mapean columnas XPM → contrato U01–U18 |

**Mapeo completo:** ver `MAPEO_EDF_VIEWS_PP9999.md` en fuentes PP9999.

## 5. Mapeo fuente ws-unificacion → repos (Unificacion completa)

| Fuente (`ws-unificacion/src/redshift/sql/`) | Destino | Repo |
|---------------------------------------------|---------|------|
| `01_schemas_roles.sql` | Incluido en DDL Alpha | STRCT |
| Vistas `pp9999_*` sobre `edf_views` | `SLCOPRBA-*-unificacion_alpha_ddl.sql` | STRCT |
| `02_regla1_unificacion.sql` | `sp_pp9999_unificacion_r1` + wrapper `sp_pp9999_unificacion_regla1` | PGM |
| `03-09` regla2 escenarios | `sp_pp9999_unificacion_r2_*`, motor `sp_pp9999_motor_batch_*` | PGM |
| `06_motor_nuevas_direcciones.sql` | Wrappers regla2 | PGM |
| `10_regla3_geo.sql` | `sp_pp9999_unificacion_r3` + wrapper regla3 | PGM |
| `00_checklist_pre_ejecucion.sql` | Validacion pre-CALL | DT |
| `call_unificacion_completa_alpha.sql` | Script certificacion E2E | DT |

**Script de sync:** `scripts/build_unificacion_repos.ps1 -HuId <ID_JIRA>`

## 6. Convencion de nombres

```
<ID_HU_JIRA>-<descripcion_corta>.sql
```

Ejemplos en este consolidado (HU placeholder `SLCOPRBA-UNIF`):

- `SLCOPRBA-UNIF-unificacion_alpha_ddl.sql` (STRCT)
- `SLCOPRBA-UNIF-unificacion_pgm_deploy.sql` (PGM)
- `SLCOPRBA-UNIF-unificacion_alpha_validate.sql` (DT)
- `SLCOPRBA-UNIF-call_unificacion_completa_alpha.sql` (DT)

## 7. `.jenkins.yml` minimo (patron que despliega)

```yaml
version: 1.0.0
global:
  application: dba_batch
  type: structure   # structure | program | data
  tech: database
  language: redshift
  jdk: 8
```

Jenkins inyecta `host` y `credentialsId`. **No** poner bloques `develop:` con `host: null`.

## 8. Flujo Jira / Git

1. Crear rama **desde subtarea** Jira (nombre incluye ID subtarea).
2. Commit con ID subtarea en mensaje.
3. Subtarea → **Execution** → Deploy Dev.
4. Tras Dev OK: rama `QA/<ID_HU>` → PR → Deploy QA.
5. Tras QA OK: rama `PDN/<ID_HU>` → PR → Deploy PDN.

## 9. Checklist pre-push (PowerShell)

```powershell
$repo = "repos\db_rcncr_btch_rdshft_strct"
$b = [IO.File]::ReadAllBytes("$repo\deploy\redshift\deploy.par")
"deploy.par BOM ok: $($b[0] -ne 0xEF)"
$rb = (Get-Content "$repo\deploy\redshift\rollback.par").Trim()
Test-Path "$repo\deploy\redshift\RevSQL\$rb"
$dp = (Get-Content "$repo\deploy\redshift\deploy.par").Trim()
Test-Path "$repo\deploy\redshift\SQL\$dp"
```

## 10. Anti-patrones (incidentes reales)

| Error | Causa | Fix |
|-------|-------|-----|
| JENKINS:104 | Subtarea sin rama/commit en Development | Rama desde subtarea + push |
| JENKINS:105 | Rama sin ID subtarea | Renombrar rama |
| REDSHIFT:207 | BOM en `.par` | Regenerar UTF-8 sin BOM |
| REDSHIFT:219 | RevSQL basename distinto a `rollback.par` | Mismo nombre, sin `_rev` |
| REDSHIFT:105/109 | `.jenkins.yml` con `host: null` | Solo bloque `global` |

## 11. Instrucciones para la IA al reorganizar

1. Identificar si el artefacto es DDL, SP o script lineal → elegir repo.
2. Nunca mezclar tipos en un solo `deploy.par`.
3. Al adaptar de mock local a Alpha: reemplazar tablas `bdm_datos.relacion_*` por vistas `bdm_datos.pp9999_*` que lean `edf_views`.
4. Mantener wrappers Framework Batch (6 parametros) en PGM para integracion YAML.
5. Regenerar `deploy.par` y `rollback.par` tras cada cambio de archivos.
6. Ejecutar `build_unificacion_repos.ps1 -ValidateOnly` antes de commit.
