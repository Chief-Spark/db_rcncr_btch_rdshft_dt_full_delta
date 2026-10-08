---
title: Pruebas QA — Metodologia y estado
audience: kiro, qa, lideres tecnicos
sources: GAP_ANALISIS_QA.md, criterios_validacion.md, Benchmark_20K runbooks
last_updated: 2026-09-03
---

# Pruebas QA — Reconocer Batch

## Metodologia

### Niveles de prueba

| Nivel | Que valida | Herramienta |
|-------|------------|-------------|
| **Unitario SQL** | Logica por regla/escenario | DBeaver, queries aisladas |
| **Integracion SP** | Cascada R1→R2→motor→R3 | `CALL` wrappers Framework Batch |
| **Benchmark volumen** | 20K personas, metricas perf | `perf_timings`, script 20K |
| **Regresion RF** | RF PDF vs implementacion | `GAP_ANALISIS_QA.md` |
| **Pipeline deploy** | Paquete STRCT/PGM/DT | Jenkins Dev → QA |
| **Cross-account** | Data Sharing edf_views | PP9999 Alpha en consumidor |

### Datasets de prueba

| Dataset | Personas | Uso |
|---------|----------|-----|
| Mock 19 personas | 19 | 12 escenarios unitarios ws-unificacion |
| Integral 5K | 5.000 | Validacion integral |
| Benchmark 20K | 20.000 | Certificacion E2E (SLCOPRBA-1147) |
| Ordenamiento 10K | 10.000 | Spec migracion-ordenamiento-242 |

### Criterios PASS benchmark 20K

| Metrica | Esperado |
|---------|----------|
| Personas procesadas | 20.000 |
| Unificaciones totales | 12.400 |
| `INV padre_no_hijo` | 0 |
| `INV control_vigentes` | 0 |
| `perf_timings.status` | OK en 10 hitos |

```sql
SELECT step_order, step_id, label, duration_sec, status
FROM bdm_stage.perf_timings
WHERE run_id = '<run_id_ambiente>'
ORDER BY step_order;
```

### Evidencias para Jira

- URL build Jenkins (Dev/QA/PDN)
- Export `perf_timings` (CSV)
- Resultado queries validacion
- Nota: tiempo E2E y cuello de botella

## GAP analisis (RF vs QA vs PP9999)

Matriz en `Framework-Batch/pp9999/docs/GAP_ANALISIS_QA.md`:

| Categoria | Estado tipico |
|-----------|---------------|
| R1 escenarios | OK en QA SP y PP9999 |
| R2 escenarios 1-6 | Parcial — esc 3 NIT, motor |
| R3 geo | Depende lat/long en insumo |
| Reglas generales G-01–G-06 | Validadas en benchmark |

## Donde vamos (estado sept 2026)

### Certificado

| Item | Ambiente | Evidencia |
|------|----------|-----------|
| Benchmark 20K mock | Dev | Build Jenkins #66 (1147) |
| PP9999 sandbox mock | Dev | 12.4K unificaciones ago-2026 |
| Deploy pipeline 3 repos | Dev | PP9999 SLCOPRBA-1220 |
| Unificacion R1-R3 codigo | Redshift local/mock | ws-unificacion + generated |

### En progreso

| Item | Bloqueo / siguiente paso |
|------|--------------------------|
| Unificacion Alpha edf_views | Certificar en cluster consumidor |
| Paquete SLCOPRBA-UNIF en Bitbucket | Rama `feature/unificacion-edf-views` |
| Aceptacion formal Experian | Cierre gaps RF (criterios_validacion.md) |
| Ordenamiento 242 completo | 17 SPs — pruebas 10K en curso |
| Framework Batch cross-account | Validacion PP9999 via Data API consumidor |

### Pendiente

| Item | Dependencia |
|------|-------------|
| QA PDN | Ventana cambio + PR aprobados |
| PDF reglas Ordenamiento | Experian |
| Geo E2E produccion | ArcGIS + contratos S3 |

## Runbooks de referencia

| Runbook | Uso |
|---------|-----|
| `Benchmark_20K_Split/RUNBOOK_DEV_QA.md` | Deploy split STRCT+DT |
| `Benchmark_20K/RUNBOOK_DBEAVER_BENCHMARK.md` | Validacion manual DBeaver |
| `Redshift/VALIDACION_POST_DEPLOY.sql` | Queries post-deploy |
| `pp9999/docs/CASOS_MOCK_R3.md` | Casos R3 mock |

## Metodologia ordenamiento (spec Kiro)

Spec formal: `.kiro/specs/pruebas-redshift-ordenamiento-242/`

- Dataset 10K con checkpoints por fase
- Helpers Data API para ejecucion automatizada
- Property tests en tasks.md
