# db_rcncr_btch_rdshft_dt — Ejecución Unificación

Paquete **type: struct** (data/exec) — corrida productiva post-deploy `_strct` + `_pgm`.

## Contenido activo

| Archivo | Descripción |
|---------|-------------|
| `run_unificacion_ejecucion_secuencial.sql` | TRUNCATE salida + `CALL` R1→R2→R3 |
| `validacion_unificacion_conteos.sql` | SELECT conteos post-corrida (manual / evidencia) |

## Prerrequisitos

1. `_strct` desplegado
2. `_pgm` desplegado

## QA DEV

Ejecutado OK 2026-09-04 — R2=72448, C03/C04=0.

## Documentación (mapa + checklist Manuel)

| Archivo | Descripción |
|---------|-------------|
| [docs/MAPA_UNIFICACION_EDF_VIEWS_NEGOCIO.html](docs/MAPA_UNIFICACION_EDF_VIEWS_NEGOCIO.html) | Mapa interactivo R1/R2/R3 — datos reales edf_views (actualizado 2026-09-04) |
| [docs/CHECKLIST_REVISION_MANUEL_DATOS_REALES.md](docs/CHECKLIST_REVISION_MANUEL_DATOS_REALES.md) | Checklist entrega Manuel / transcripción |
| [docs/Evidencias_QA_UNIFICACION_ESCENARIOS_DEV.md](docs/Evidencias_QA_UNIFICACION_ESCENARIOS_DEV.md) | Evidencia QA DEV (15 SPs, paridad R2) |

Abrir el HTML en el navegador desde Bitbucket (Raw) o clonar el repo.

## Post-merge Jenkins

1. `_strct` → `_pgm` → `_dt`
2. Ejecutar `run_unificacion_ejecucion_secuencial.sql`
3. Validar con `validacion_unificacion_conteos.sql`
