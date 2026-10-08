# Evidencias Ordenamiento EDF completo (Reconocer consumidor)

Fecha: 2026-09-04T15:45:32

## Tiempos

```json
{
  "scoring_total_seg": 20.0
}
```

## Stages
- **sp_scoring_dir_edf**: OK
- **sp_scoring_tel_edf**: OK
- **sp_scoring_cel_edf**: OK
- **sp_scoring_ema_edf**: OK
- **sp_consolidacion_edf**: OK
- **sp_drop_staging**: OK
- **sp_ejecucion_edf**: OK
- **call_ejecucion_edf**: OK

## Validación Fase 2

```json
[
  {
    "query": "-- Validaci\u00f3n Fase 2 \u2014 scoring + consolidaci\u00f3n (sin tabla RPU materializada)",
    "rows": [
      {
        "canal": "CEL",
        "scores": 258,
        "min_score": 0.49,
        "max_score": 0.7325
      },
      {
        "canal": "DIR",
        "scores": 409014,
        "min_score": 0.6113,
        "max_score": 0.843
      },
      {
        "canal": "EMA",
        "scores": 407406,
        "min_score": 0.26,
        "max_score": 0.525
      },
      {
        "canal": "TEL",
        "scores": 407320,
        "min_score": 0.2675,
        "max_score": 0.635
      }
    ]
  },
  {
    "query": "SELECT 'total_scores' AS paso, COUNT(*)::BIGINT AS total FROM bdm_datos.score_or",
    "rows": [
      {
        "paso": "rpu_con_orden_prioridad",
        "total": 408624
      },
      {
        "paso": "total_scores",
        "total": 1223998
      },
      {
        "paso": "rpu_ganadoras_con_orden",
        "total": 410463
      },
      {
        "paso": "rpu_hijas_sin_orden",
        "total": 72448
      },
      {
        "paso": "rpu_hijas_con_orden_incorrecto",
        "total": 0
      },
      {
        "paso": "personas_con_orden",
        "total": 407351
      }
    ]
  },
  {
    "query": "SELECT 'integridad_orden_null_en_scores' AS check_name, COUNT(*) AS n",
    "rows": [
      {
        "check_name": "integridad_orden_null_en_scores",
        "n": 0
      }
    ]
  }
]
```
