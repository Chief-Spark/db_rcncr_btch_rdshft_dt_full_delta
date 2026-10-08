# Evidencias — Carga betas RITM5226589 + re-scoring (2026-09-16)

**Ambiente:** Productor DEV · `dba_batch` · usuario `c32525e`  
**Motivo:** Catálogo betas reales Teradata (John / RITM5226589) según sesión/mesa → tablas auxiliares.

## 1. Carga catálogo

Script: `sql/dev_edf_ordenamiento/02_carga_betas_ritm5226589.sql`

| Canal | n | min β | max β |
|-------|--:|------:|------:|
| CEL | 11 | 41.49377593 | 203.31950210 |
| DIR | 12 | -51.61290323 | 135.48387100 |
| EMA | 13 | -130.80018340 | 180.30866400 |
| TEL | 11 | -130.39934800 | 179.29910350 |
| **Total** | **47** | | |

Muestra: `CO01TEL001 = 114.09942950` · `CO00DIR001IN = 80.64516129` · `CO01CEL020 = 203.31950210`

## 2. Re-scoring

SPs legacy productor (sin sufijo `_edf`):

```text
CALL bdm_datos.sp_ordenamiento_scoring_dir();
CALL bdm_datos.sp_ordenamiento_scoring_tel();
CALL bdm_datos.sp_ordenamiento_scoring_cel();
CALL bdm_datos.sp_ordenamiento_scoring_ema();
CALL bdm_datos.sp_ordenamiento_consolidacion();
```

Tiempo ≈ 14 s total.

| Canal | Scores | min (antes) | max (antes) | min (después) | max (después) |
|-------|-------:|------------:|------------:|--------------:|--------------:|
| CEL | 140.189 | 0.4375 | 0.7475 | **556.02** | **1044.61** |
| DIR | 28.636 | 0.6013 | 0.7730 | **499.78** | **686.45** |
| EMA | 40.053 | 0.4642 | 0.7100 | **318.44** | **683.19** |
| TEL | 28.636 | 0.5475 | 0.8175 | **617.77** | **967.40** |
| **Total** | **237.514** | | | avg **639.9** | |

La magnitud sube porque los coeficientes reales Teradata son ~±30…±200 (antes placeholder ~0.1). El **ranking** sigue siendo `ORDER BY score DESC` (lugar 1 = mayor score).

## 3. Consumidor Reconocer (`dba_rncr_batch`)

| Intento | Resultado |
|---------|-----------|
| Clave documentada `gl51TGx4nFhD` (`c32525e`) | Antes OK (ago-2026); **2026-09-16: Account locked** tras reintentos fallidos |
| Productor QA `8M993Uww4` | Auth OK en procesosbatch-qa; **sin WRITE** en `bdm_datos`/`bdm_stage` |
| Productor DEV `b27YWI2FL` | Auth + WRITE OK — carga RITM + re-scoring **hecho** |

→ Esperar desbloqueo de cuenta Reconocer y reintentar con `sp_ordenamiento_ejecucion_edf(TRUE)`.

### Mapa de claves usadas en el paquete

| Ambiente | Host | User | Clave (doc) | Estado hoy |
|----------|------|------|-------------|------------|
| Productor DEV | `…procesosbatch-dev…cee2enck00mg…` | `c32525e` | `b27YWI2FL` | OK |
| Productor QA | `…procesosbatch-qa…cwefyckvccgy…` | `c32525e` | `8M993Uww4` | Auth OK / sin write bdm_* |
| Consumidor DEV | `…reconocerbatch-dev…cz7jl1sn7m8z…` | `c32525e` | `gl51TGx4nFhD` | **LOCKED** |

## 4. Siguiente

1. Pedir password / grants consumidor para repetir con `sp_ordenamiento_ejecucion_edf(TRUE)`.
2. Commit/push `02_carga_betas_ritm5226589.sql` en `feature/ordenamiento`.
