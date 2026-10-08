# Evidencias QA — Unificación por escenario (DEV)
Fecha: 2026-09-04T15:34:28

## Stages
- **prerequisitos**: OK
- **ddl**: OK
- **vistas**: OK
- **smoke**: OK
- **deploy_sp_unificacion_r1_preparar_insumo.sql**: OK
- **deploy_sp_unificacion_r1_esc1_ciiu10.sql**: OK
- **deploy_sp_unificacion_r1_esc2_ciiu81_90.sql**: OK
- **deploy_sp_unificacion_r1_esc3_otros_ciiu.sql**: OK
- **deploy_sp_unificacion_regla1.sql**: OK
- **deploy_sp_unificacion_r2_preparar_insumo.sql**: OK
- **deploy_sp_unificacion_r2_esc1_esc2_complemento.sql**: OK
- **deploy_sp_unificacion_r2_esc3_sin_nit_nomenclatura.sql**: OK
- **deploy_sp_unificacion_r2_esc4_diccionario.sql**: OK
- **deploy_sp_unificacion_r2_esc5_nivel_nomenclatura.sql**: OK
- **deploy_sp_unificacion_r2_esc6_frecuencia.sql**: OK
- **deploy_sp_unificacion_r2_motor.sql**: OK
- **deploy_sp_unificacion_regla2.sql**: OK
- **deploy_sp_unificacion_r3_geo.sql**: OK
- **deploy_sp_unificacion_regla3.sql**: OK
- **execute**: OK
- **validaciones**: OK

## Assertions
```json
[
  {
    "id": "B02_por_regla",
    "rows": [
      {
        "unifica_atributos": 2,
        "n": 72448
      }
    ],
    "ok": true
  },
  {
    "id": "PARITY_R2_COUNT",
    "expected": 72448,
    "actual": 72448,
    "ok": true
  },
  {
    "id": "C03_hijos_sin_padre",
    "expected": 0,
    "actual": 0,
    "ok": true
  },
  {
    "id": "C04_autoreferencia",
    "expected": 0,
    "actual": 0,
    "ok": true
  },
  {
    "id": "UNIVERSO_RPU",
    "rows": [
      {
        "rpus": 591166
      }
    ],
    "ok": true
  }
]
```

**Resultado:** PASS
