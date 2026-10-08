# Evidencias Ordenamiento DEV — fórmulas corregidas (2026-09-04)

**Ambiente:** `dba_rncr_batch` Reconocer DEV  
**Corrida:** `py -3 tools/dev_edf_ordenamiento_run.py --fase2-only` (post-unificación activa)

## Brechas cerradas (baseline Teradata / doc v2.0)

| ID | Ajuste | Estado |
|----|--------|--------|
| TEL-02 | `CO01TEL020` calculado pero **fuera de SUM** | OK |
| EMA-03 | `CO01EMA003/007` fuera de SUM (+ `018/025` alineado Teradata) | OK |
| CEL-02 | `CO01CEL018` = `100 × COALESCE(catalogo_operador, 0.22)` | OK |

## Métricas post-corrida

| Canal | Scores | min | max |
|-------|-------:|----:|----:|
| DIR | 409.014 | 0.6113 | 0.8430 |
| TEL | 407.320 | 0.2675 | 0.6350 |
| EMA | 407.406 | 0.2600 | 0.5250 |
| CEL | 258 | 0.4900 | 0.7325 |
| **Total** | **1.223.998** | | |

| Gate | Valor |
|------|------:|
| RPUs con `orden_prioridad` | 408.624 |
| Hijas con orden incorrecto | **0** |
| Tiempo ejecución | ~20 s |

## Artefactos Bitbucket (rama `feature/ordenamiento`)

```
deploy_bitbucket/
├── db_rcncr_btch_rdshft_strct/  DDL + catálogos + vistas insumo
├── db_rcncr_btch_rdshft_pgm/    SPs preparar + scoring + orquestador
└── db_rcncr_btch_rdshft_dt/     run + validacion_ordenamiento_conteos.sql
```

Sync: `py -3 tools/sync_deploy_bitbucket_ordenamiento.py`  
Repos: `py -3 tools/sync_repos_ordenamiento.py`

## Pendiente (no bloquea DEV)

Ver listado completo: **`Documentacion/PENDIENTES_Y_CIERRE_2026-09-04.md`**

- Betas: **snapshot RITM5226589 cargado** (`BETAS_ORDENAMIENTO_RITM5226589.md`) — re-correr scoring; datashare IFR continuo opcional
- Paridad Teradata (MIG-01) más viable con coeficientes reales
- PRs unificación en aprobación; ordenamiento: rama `feature/ordenamiento` — **abrir PRs**
