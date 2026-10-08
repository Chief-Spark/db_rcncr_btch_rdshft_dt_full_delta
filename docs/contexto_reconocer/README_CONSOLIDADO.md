# RECONOCER — Consolidado

Paquete único de contexto para **Kiro**, **Confluence** y despliegue vía pipeline **DATABASE-REDSHIFT**.

## Contenido

| Carpeta / archivo | Descripción |
|-------------------|-------------|
| [`repos/`](repos/) | 3 repos Bitbucket: `db_rcncr_btch_rdshft_{strct,pgm,dt}` |
| [`docs/`](docs/) | Documentación de contexto para IA (steering Kiro) |
| [`diagramas/`](diagramas/) | Arquitectura Data Sharing + Reconocer (drawio) |
| [`referencias/`](referencias/) | Índice de PDFs y fuentes oficiales |
| [`scripts/`](scripts/) | Clone repos, build Unificación, validación pipeline |

## Documentos Kiro (leer en orden)

1. [`docs/00_RECONOCER.md`](docs/00_RECONOCER.md) — Proyecto, migración Teradata → Redshift
2. [`docs/01_UNIFICACION.md`](docs/01_UNIFICACION.md) — Reglas R1/R2/R3 + motor
3. [`docs/02_ORDENAMIENTO.md`](docs/02_ORDENAMIENTO.md) — Scoring contactabilidad
4. [`docs/03_FRAMEWORK_BATCH.md`](docs/03_FRAMEWORK_BATCH.md) — Orquestación batch
5. [`docs/04_GEO.md`](docs/04_GEO.md) — Proceso geocodificación
6. [`docs/05_PRUEBAS_QA.md`](docs/05_PRUEBAS_QA.md) — Metodología y estado QA
7. [`docs/06_DOCUMENTACION_CONFLUENCE.md`](docs/06_DOCUMENTACION_CONFLUENCE.md) — Plantilla Confluence
8. [`docs/GUIA_IA_REORGANIZACION_REPOS.md`](docs/GUIA_IA_REORGANIZACION_REPOS.md) — **Input para IA**: mapeo código → 3 repos

## Repos Redshift (orden de deploy)

```
STRCT (structure) → PGM (program) → DT (data)
```

| Repo | `global.type` | Contenido |
|------|---------------|-----------|
| `db_rcncr_btch_rdshft_strct` | `structure` | DDL, vistas lectura `edf_views`, catálogos |
| `db_rcncr_btch_rdshft_pgm` | `program` | Stored procedures Unificación |
| `db_rcncr_btch_rdshft_dt` | `data` | Validación, CALL certificación |

## Scripts rápidos

```powershell
# Clonar repos desde Bitbucket (requiere acceso code.experian.local)
.\scripts\clone_repos.ps1

# Generar / sincronizar paquete Unificación edf_views en los 3 repos
.\scripts\build_unificacion_repos.ps1 -HuId SLCOPRBA-UNIF

# Validar deploy.par / rollback.par sin BOM
.\scripts\build_unificacion_repos.ps1 -ValidateOnly
```

## Fuentes origen

Código y documentación derivados de:

`Documentos\Repos\Reconocer\demo_unificacion_completa\`

---

*Equipo Reconocer Batch — Macondotek / Experian Colombia*
