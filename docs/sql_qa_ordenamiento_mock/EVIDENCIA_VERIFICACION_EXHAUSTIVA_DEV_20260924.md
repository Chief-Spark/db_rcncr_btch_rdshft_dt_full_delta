# Evidencia verificación exhaustiva DEV — Ordenamiento

- **Fecha:** 2026-09-24 (UTC ~20:14–20:20)
- **DB:** `dba_rncr_batch` · host Reconocer DEV :5440
- **Alcance:** recorrido completo SPs REAL (`_edf`) + MOCK + gates CA + revisión código vs Teradata/docs

---

## Veredicto global

| Capa | Resultado |
|------|-----------|
| Inventario 8 SPs `_edf` | **PASSED** |
| Inventario 3 SPs mock | **PASSED** (desplegados en DEV) |
| `CALL sp_ordenamiento_ejecucion_edf(TRUE)` | **Ejecutó OK** (~18 s) |
| `CALL sp_ordenamiento_ejecucion_mock()` | **PASSED_ALL** (12/12) |
| Betas RITM | **47 PASSED** |
| Código TEL-02 / EMA-03 / CEL-02 / F3-02 / sin sigmoid | **PASSED** (revisión estática) |
| Universo REAL histórico + Caso A/B | **BLOQUEADO — ambiente** |

**No se puede firmar “REAL exhaustivo OK con Casos A/B”** hasta restaurar datashare.

---

## Hallazgo crítico de ambiente (bloqueante)

Antes de esta corrida (evidencias previas del chat):

| Objeto | Antes | Ahora (post-corrida) |
|--------|------:|---------------------:|
| Scores DIR | ~410 455 | **520** |
| Scores TEL | ~408 498 | **104** |
| Scores EMA | ~408 683 | **0** |
| `edf_views.xpm` | universo grande | **1 000** |
| `edf_views.xpm_location` | universo grande | **1 000** |
| `unificacion_direccion` | ~72 549 (R2) | **0** |
| Caso A `3228096126421495389` | scores OK | **sin filas** |
| Caso B `2848501447849812647` | DIR 611.8 / 599.8 | **sin filas** |

`v_xpm_relacion_persona_ubicacion` solo ve **520** RPUs porque el datashare quedó en muestra ~1000.

La corrida EDF **funcionó**, pero **reemplazó** scores sobre ese universo reducido. Por eso el recorrido exhaustivo REAL no puede validar los IDs históricos.

---

## Recorrido ejecutado

### 1) Inventario SPs
- `bdm_datos.sp_ordenamiento_*_edf` × 8 → presentes  
- Deploy en sesión: DDL `05_ddl_ordenamiento_mock` + 3 SPs `bdm_stage.sp_ordenamiento_*_mock` → OK  

### 2) REAL — orquestador
```sql
CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);  -- OK ~18s
```
Post-corrida (universo reducido): DIR=520, TEL=104, EMA=0, CEL=0.

### 3) Gates REAL (sobre data post-corrida)
| Check | Estado | Nota |
|-------|--------|------|
| Scores DIR/TEL > 0 | PASSED | volumen **no** comparable a histórico |
| EMA > 0 | FAILED | 0 filas en muestra actual |
| Betas 47 (12+11+11+13) | PASSED | |
| Hijas con orden/score | PASSED (0) | con `unificacion` vacía el gate es trivial |
| Caso A / Caso B | FAILED | IDs no existen en scores actuales |
| Empates DIR | N/A | 0 filas |

### 4) MOCK — orquestador
```sql
CALL bdm_stage.sp_ordenamiento_ejecucion_mock();
```
| Criterio | Estado |
|----------|--------|
| CA-O01 … CA-O12 | **PASSED** × 12 |
| Veredicto | **PASSED_ALL** (failed=0) |
| HTML 20001 | casa 850 lugar1 · oficina 700 lugar2 |

### 5) Código vs Teradata / docs aceptación
| Criterio | Evidencia en SP | Estado |
|----------|-----------------|--------|
| TEL-02 TEL020 fuera SUM | `scoring_tel_edf` | PASSED |
| EMA-03 003/007/018/025 fuera | `scoring_ema_edf` | PASSED |
| CEL-02 default 0.22 | `scoring_cel_edf` | PASSED |
| F3-02 hijas fuera | `preparar` + `consolidacion` | PASSED |
| Ranking ROW_NUMBER | 4 canales | PASSED |
| Sin sigmoid (Opción A) | scoring | PASSED |
| Betas RITM fórmula `(cat/max)×beta` | carga 47 + SPs | PASSED |
| MIG-01 paridad 1:1 Teradata | — | **PENDIENTE** externo |

---

## Qué falta para cerrar “todo validado en DEV”

1. **DBA / Data Sharing:** restaurar `edf_views` al universo completo (no 1000 filas).  
2. Re-ejecutar **Unificación** R1→R2→R3.  
3. Re-ejecutar **`sp_ordenamiento_ejecucion_edf(TRUE)`**.  
4. Re-validar Caso A / Caso B + gates volumen (~410k DIR).  
5. Adjuntar esta evidencia + output MOCK `PASSED_ALL` a la HU.

---

## Conclusión

| Pregunta | Respuesta |
|----------|-----------|
| ¿SPs reales existen y corren? | **Sí** |
| ¿SPs mock existen, se desplegaron y pasan CA? | **Sí — PASSED_ALL** |
| ¿Código alineado a criterios/Teradata Opción A? | **Sí** |
| ¿DEV queda validado extremo a extremo con data real histórica? | **No** — datashare reducido borró el universo; hay que restaurar y re-correr |
