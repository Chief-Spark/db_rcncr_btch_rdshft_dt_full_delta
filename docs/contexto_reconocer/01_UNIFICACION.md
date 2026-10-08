---
title: UNIFICACION — Overview, criterios y practicas
audience: kiro, qa, desarrolladores
sources: documento_funcional_v1.md, RF VF PDF, requerimientos_criterios_aceptacion.md
last_updated: 2026-09-03
---

# Unificacion de Direcciones Fisicas

## Overview y alcance

Consolida direcciones duplicadas de una misma persona (misma puerta + ciudad, distinto tipo de uso o complemento). Aplica **3 reglas en cascada** y un **motor de nuevas direcciones** cuando la Regla 2 debe combinar complementos.

| Regla | Teradata | Descripcion |
|-------|----------|-------------|
| **R1** | P0019 | Misma puerta, distinto tipo uso → padre por CIIU |
| **R2** | P0020 | Misma puerta, distinto complemento → 6 escenarios + motor |
| **R3** | P0021 | Diferencia via generadora → lat/long + diccionario via |
| **Motor** | PRO_Unifi_MOTOR_TMP | Genera RPU/DF nuevas cuando R2 lo exige |

**Volumen:** ~65–70M registros en produccion.  
**Entrada:** direcciones estandarizadas (post-EDF) via `edf_views` en consumidor.  
**Salida:** `unificacion_direccion`, `ind_unificacion` en tablas locales.

## Criterios de aceptacion (resumen)

### Regla 1

| ID | Criterio |
|----|----------|
| R1-01 | CIIU=10 → padre LAB o CRR con mas entidades |
| R1-02 | CIIU 81/82/90 → padre RES o CRR |
| R1-03 | Otro CIIU → mayor entidades sin filtro tipo |
| R1-04 | Hijo con `ind_unificacion = 1` |
| R1-05 | Par en `unificacion_direccion` con `unifica_atributos = 1` |
| R1-06 | Excluir ya unificadas y bloqueadas |

### Regla 2 (escenarios)

| ID | Escenario |
|----|-----------|
| R2-01 | Complemento vacio vs no vacio |
| R2-02 | Un complemento contenido en otro |
| R2-03 | Misma nomenclatura, distinto valor (sin NIT) |
| R2-04 | Misma nomenclatura, distinto valor (NIT) → nueva direccion |
| R2-05 | Nomenclaturas distintas, mismo nivel → diccionario |
| R2-06 | Nomenclaturas distintas, distinto nivel → nueva direccion |
| R2-07–11 | Invariantes padre/hijo, trazabilidad |

### Regla 3

| ID | Criterio |
|----|----------|
| R3-01 | Solo tipo Via (excluye Manzana/Rural) |
| R3-02–04 | Via generadora: geo o diccionario |
| R3-05–06 | Puerta: unifica solo si diferencia ≤ 2 |

### Reglas generales

| ID | Criterio |
|----|----------|
| G-01 | Cascada R1 → R2 → R3 |
| G-03 | No reprocesar `ind_unificacion = 1` |
| G-05 | Toda unificacion en `unificacion_direccion` |
| G-06 | Idempotencia |

**Documento completo:** `ws-unificacion/docs/funcional/requerimientos_criterios_aceptacion.md`

## Reglas funcionales (PDF aprobado Experian)

**Fuente oficial:** `Requerimiento Funcional - Unificacion de Direcciones Fisicas_VF.pdf`

- Autor: Andy Garcia (Experian), 2019
- Define las 3 reglas, escenarios R1-01 a R3-10, reglas G-01 a G-05
- Copia en consolidado: [`referencias/`](../referencias/INDICE_PDFS.md)

**Resumen funcional adicional:** `documento_funcional_v1.md` en ws-unificacion.

## Practicas de codigo (sintesis)

> **Nota:** No existe un PDF unico de "practicas de codigo" aprobado por Experian. Esta seccion sintetiza steering Kiro + manuales DevSecOps Redshift.

### SQL Redshift / XPM

- Usar esquemas fijos: `bdm_stage` (SP), `bdm_datos` (salida/catalogos), `bdm_tempo` (staging)
- Lectura Alpha: `ds_dba_rncr_batch.edf_views.*` solo SELECT
- Vistas puente `pp9999_*` encapsulan joins XPM (pin, location, contactinformations)
- `DISTKEY`/`SORTKEY` en tablas staging por `id_buro_persona`
- SP con `NONATOMIC` + `LANGUAGE plpgsql` para Framework Batch

### Empaquetado pipeline

- Un artefacto por tipo en repo correspondiente (STRCT/PGM/DT)
- `deploy.par` / `rollback.par` sin BOM UTF-8
- RevSQL mismo basename que rollback.par
- Prefijo Jira en nombres: `SLCOPRBA-XXXX-descripcion.sql`

### Desarrollo con IA

- No modificar logica de negocio sin cruzar con RF PDF
- Mapear escenario ↔ archivo: `mapeo_escenarios_codigo.md`
- Validar con benchmark 20K antes de promover QA

**Fuentes steering:** `ws-unificacion/.kiro/steering/sql-redshift-xpm.md`, `desarrollo-ia-redshift.md`, `estandar-paquete-deploy-sql.md`

## Codigo migrado

| Ubicacion | Contenido |
|-----------|-----------|
| `ws-unificacion/src/redshift/sql/` | Scripts fuente R1–R3 (mock local) |
| `Framework-Batch/pp9999/generated/` | Paquete Alpha edf_views |
| `repos/db_rcncr_btch_rdshft_*` | Despliegue pipeline (este consolidado) |

## Certificacion post-deploy

```sql
CALL bdm_stage.sp_pp9999_unificacion_regla1(...);
-- R2, R3 via wrappers
SELECT COUNT(*) FROM bdm_datos.pp9999_unificacion_direccion;
```

Benchmark 20K: 20.000 personas, 12.400 unificaciones, 0 invalidaciones padre/hijo.
