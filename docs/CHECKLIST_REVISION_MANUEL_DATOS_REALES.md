# Checklist revisión — Unificación datos reales (Manuel / transcripción)

> **Alcance:** solo lo acordado con Manuel — `edf_views` vía datasharing, 3 repos Bitbucket, SPs **por escenario** (no monolíticos), **sin mocks** (`perf_persona_meta`, benchmark 20K, `SLCOPRBA-1147`).
>
> **Ambiente:** Reconocer consumidor DEV — `dba_rncr_batch` @ `eec-aws-us-eits-reconocerbatch-dev-redshift.cz7jl1sn7m8z.us-east-1.redshift.amazonaws.com`

---

## 1. Arquitectura (transcripción)

| Requisito | Estado | Evidencia |
|-----------|:------:|-----------|
| Lectura productor sin copiar tablas XPM | OK | Vistas `bdm_tempo.v_xpm_*` → `ds_dba_rncr_batch.edf_views.*` |
| Staging temporal en `bdm_tempo` | OK | SPs por escenario + `stg_regla2_*` |
| Salida persistente `bdm_datos.unificacion_direccion` | OK | DDL en `_strct` |
| No materializar millones de filas XPM en consumidor | OK | `ARQUITECTURA_DATASHARING_LECTURA_PRODUCTOR.md` |

---

## 2. Tres repos + convención Manuel (sin ticket Jira)

| Repo | Rama | PR | Contenido clave |
|------|------|-----|-----------------|
| `db_rcncr_btch_rdshft_strct` | `feature/unificacion-edf-views` | [#2](https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_strct/pull-requests/2) | `00_prerequisitos_schemas.sql`, `01_ddl_…`, `02_vistas_insumo_edf_views.sql` |
| `db_rcncr_btch_rdshft_pgm` | `feature/unificacion-edf-views` | [#2](https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_pgm/pull-requests/2) | **15 SPs por escenario** + orquestadores R1/R2/R3 |
| `db_rcncr_btch_rdshft_dt` | `feature/unificacion-edf-views` | [#6](https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_dt/pull-requests/6) | `run_unificacion_ejecucion_secuencial.sql`, `validacion_unificacion_conteos.sql` |

| Convención Manuel | Cumple |
|-------------------|:------:|
| Sin `SLCOPRBA-XXXX` en nombres de archivo | OK |
| Prefijo `00_`, `01_` en `_strct` | OK |
| `sp_unificacion_*` funcional en `_pgm` | OK |
| `run_*` / `validacion_*` en `_dt` | OK |
| `deploy.par` un archivo por línea, orden ejecución | OK |
| Mock `SLCOPRBA-1147` eliminado | OK (commit en `_dt`) |

**Pendiente operativo:** aprobación PR + merge `_strct` → `_pgm` → `_dt` (Jenkins lunes).

---

## 3. SPs por escenario (no monolíticos)

| Regla | Archivos | Orquestador |
|-------|----------|-------------|
| R1 | `r1_preparar_insumo`, `r1_esc1_ciiu10_mismo_texto_padre_lab_crr`, `r1_esc2_ciiu81_90_mismo_texto_padre_res_crr`, `r1_esc3_otros_ciiu_mayor_entidades_reportan` | `sp_unificacion_regla1` |
| R2 | `r2_preparar_insumo`, `r2_esc1_complemento_vacio_esc2_substring_complemento`, `r2_esc3_sin_nit_misma_nomenclatura`, `r2_esc4_diccionario_frecuencia_complemento`, `r2_esc5_nomenclatura_menor_nivel_pierde`, `r2_esc6_frecuencia_complemento_gana`, `r2_motor_nit_empates_nuevas_direcciones` | `sp_unificacion_regla2` |
| R3 | `r3_esc1_geo_misma_via_puerta_cercana` | `sp_unificacion_regla3` |

Regenerar: `py -3 tools/gen_unificacion_sps_por_escenario.py`

---

## 4. QA datos reales DEV (2026-09-04) — **no mock**

Runner: `tools/dev_unificacion_escenarios_qa_run.py`  
Evidencia: `Documentacion/Evidencias_QA_UNIFICACION_ESCENARIOS_DEV.md`

| Check | Resultado | Nota |
|-------|-----------|------|
| Deploy 15 SPs | OK | |
| Ejecución R1 → R2 → R3 | OK | |
| `03_validaciones_unificacion.sql` | OK | Fuentes `v_xpm_*`, salida `bdm_datos` |
| **R2 unificaciones** | **72.448** | Paridad baseline monolito |
| C03 hijos sin padre | 0 | |
| C04 autoreferencia | 0 | |
| Universo RPU | 591.166 | |
| R1 salida | 0 | Esperado en DEV real (sin ganador único multitipo) |
| R3 salida | 0 | Esperado (sin latitud en fuente) |

Validación manual post-deploy: `validacion_unificacion_conteos.sql` (`_dt`) / `sql/dev_edf_datasharing/00_drill_down_validaciones.sql`

---

## 5. Qué **no** revisar en este cierre

| Fuera de alcance | Motivo |
|------------------|--------|
| `sql/benchmark_20k/`, `perf_persona_meta` | Mock sintético SPEC — ya cerrado aparte |
| `procesosbatch-dev` / `bdm_stage` 40K | Ambiente productor/mock histórico |
| TC-R1-01…TC-R2-14 con `scenario_code` | Suite QA mock — **no aplica** a `edf_views` |
| `Reporte_Ejecucion_QA_R1_R2_Redshift.md` (22/22 mock) | Legacy `bdm_stage` procesosbatch — ignorar para este entregable |
| Ordenamiento | Rama aparte `feature/ordenamiento` (después de unificación) |

---

## 6. Orden deploy Jenkins (lunes)

1. `_strct` — vistas + DDL  
2. `_pgm` — SPs  
3. `_dt` — `CALL` secuencial + validación conteos  

---

## 7. Comandos útiles (datos reales)

```powershell
$env:REDSHIFT_CONSUMER_PASSWORD="<clave>"
cd PAQUETE_UNIFICACION_BDM_STAGE
py -3 tools/dev_unificacion_escenarios_qa_run.py
```

---

*Única guía de revisión para entrega Manuel — datos reales `edf_views` / Reconocer.*
