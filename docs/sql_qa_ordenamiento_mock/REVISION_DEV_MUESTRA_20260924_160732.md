# Revisión DEV — Ordenamiento (muestra pequeña aceptada)

- Fecha UTC: 2026-09-24T21:07:32.393244+00:00
- Premisa: muestra datashare pequeña = **normal** mientras hay columnas de estandarización
- Veredicto Opción A: **PASSED_OPCION_A**
- Ejemplo REAL muestra: `-9220270901488636595`

## Checks

| Check | Estado | Detalle |
|-------|--------|---------|
| `ENV-muestra` | PASSED | edf_views.xpm=1000 (muestra pequeña = OK según equipo) |
| `REAL-unif` | PASSED | n=0 por_regla=[] |
| `RUN-UNIF` | PASSED | OK → n=0 |
| `RUN-EDF` | PASSED | CALL OK |
| `REAL-scores-DIR` | PASSED | n=520 ('DIR', 520, 666.4516, 676.129) |
| `REAL-scores-TEL` | PASSED | n=104 ('TEL', 104, 288.5086, 288.5086) |
| `REAL-scores-EMA` | PASSED | n=0 (puede ser 0 en muestra) None |
| `REAL-scores-CEL` | PASSED | n=0 (bajo/0 OK en muestra) |
| `REAL-betas47` | PASSED | n=47 |
| `REAL-F3-02-orden` | PASSED | hijas_con_orden=0 |
| `REAL-F3-02-score` | PASSED | hijas_con_score=0 |
| `REAL-RANK-ejemplo-muestra` | PASSED | solo 1 DIR por persona en muestra; ejemplo=[(-9220270901488636595, 516, Decimal('676.1290'), 1)] |
| `MOCK-VEREDICTO` | PASSED | ('PASSED_ALL', 12, 0) |
| `MOCK-CA-O01` | PASSED | canales_distintos=4 scores=28 |
| `MOCK-CA-O02` | PASSED | beta_ordenamiento n=47 |
| `MOCK-CA-O03` | PASSED | hijas_con_orden=0 |
| `MOCK-CA-O04` | PASSED | 20001 DIR scores distintos + lugar1=max |
| `MOCK-CA-O05` | PASSED | scores_hija_91019=0 |
| `MOCK-CA-O06` | PASSED | 20001 canales con lugar1=3 |
| `MOCK-CA-O07` | PASSED | mismatches_orden_vs_lugar=0 |
| `MOCK-CA-O08` | PASSED | 20010 n=2 score=777.0000 |
| `MOCK-CA-O09` | PASSED | 20013 TEL scores iguales (TEL020 no mueve) |
| `MOCK-CA-O10` | PASSED | 20014 EMA scores iguales (003/007 fuera SUM) |
| `MOCK-CA-O11` | PASSED | 20012 CEL score=220.0000 |
| `MOCK-CA-O12` | PASSED | 20003 DIR n=3 |
| `MIG-prep-TEL02` | PASSED | TEL020 fuera SUM (alineado TD doc) |
| `MIG-prep-EMA03` | PASSED | EMA003/007/018/025 fuera SUM |
| `MIG-prep-CEL02` | PASSED | default operador 0.22 |
| `MIG-prep-F302` | PASSED | hijas fuera ranking |
| `MIG-prep-formula` | PASSED | beta×cat + ROW_NUMBER |
| `MIG-01-paridad-numerica` | FAILED | NO ejecutada: falta corrida lado a lado Teradata vs Redshift (externo) |
| `MIG-01-alcance-opcionA` | PASSED | Opción A = suma lineal betas RITM; no exige sigmoid 0-1 para cierre actual |

## Paridad Teradata (MIG-01)

| Tema | Estado |
|------|--------|
| Reglas de fórmula alineadas (TEL-02, EMA-03, CEL-02, F3-02, betas) | Listo en código |
| Comparación numérica 1:1 Teradata vs Redshift | **Pendiente externo** |
| ¿Bloquea cierre Opción A / muestra DEV? | **No** (mesa) |

## Siguiente

1. Usar MOCK PASSED_ALL + gates REAL de la muestra para entrega QA.
2. Cuando estandarización/datashare pase a full, re-correr y adjuntar volumen.
3. MIG-01 cuando Experian entregue set/corrida Teradata de referencia.
