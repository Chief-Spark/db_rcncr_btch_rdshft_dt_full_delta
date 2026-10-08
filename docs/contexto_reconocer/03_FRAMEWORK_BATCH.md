---
title: Framework Batch — Overview e inception
audience: kiro, devops, desarrolladores
sources: framework_batch_overview.md, FRAMEWORK_BATCH_CLUSTER_REVIEW.md
last_updated: 2026-09-03
---

# Framework Batch Dinamico

## Overview y alcance

Orquestador **serverless** en AWS que ejecuta Stored Procedures en Amazon Redshift. Reemplaza Control-M como scheduler de procesos batch Reconocer.

| Caracteristica | Detalle |
|----------------|---------|
| Trigger | Archivo `.val` en S3 |
| Definicion | YAML en bucket de definiciones |
| Ejecucion | Step Functions → Redshift Data API |
| Niveles | 0–3 (paralelo dentro de nivel, secuencial entre niveles) |
| Notificacion | SES email al completar/fallar |

### Flujo (10 pasos)

```
.val → S3 → SQS → Lambda Initiator → Step Function Principal
  → SourceValidator (YAML + archivos S3)
  → Builder (genera SF dinamica)
  → SF Dinamica ejecuta SPs por nivel
  → EventBridge + SP Updater (loop)
  → Glue consolida outputs → Notifier → SES
```

### 3 repos Terraform

| Repo TF | Crea |
|---------|------|
| TF FW Dynamo | DynamoDB logs |
| TF FW Dynbtch | 7 Lambdas, SF, S3, SQS, EventBridge, Glue, SES, IAM, KMS |
| TF FW RDSHFT | Cluster Redshift (si no existe) |

## Contrato SP (integracion Reconocer)

Todo SP invocado por Framework Batch expone **6 parametros**:

```sql
(in_solicitud, in_nit_suscriptor, in_path_archivo,
 in_nemotecnico, in_id_facturacion, in_fecha_ejecucion)
```

Wrappers en `bdm_stage` llaman helpers internos sin parametros.

### YAML ejemplo (Unificacion PP9999)

```yaml
procesos:
  directorio:
    ruta: PP9999reconocerunificacion
  niveles:
    - nivel: 0
      procedimientos:
        - step_procedure: bdm_stage.sp_pp9999_cleanup_sandbox
    - nivel: 1
      procedimientos:
        - step_procedure: bdm_stage.sp_pp9999_unificacion_regla1
    # niveles 2, 3...
```

## Inception / revision profunda

> No existe documento formal "Inception Review" para Reconocer. Esta seccion consolida la revision tecnica realizada.

### Hallazgos cluster (FRAMEWORK_BATCH_CLUSTER_REVIEW)

| Tema | Productor (procesosbatch) | Consumidor (reconocerbatch) |
|------|---------------------------|------------------------------|
| Cuenta AWS | 651706752126 | 647096294147 |
| Cluster | procesosbatch-dev | dba_rncr_batch |
| Lectura EDF | Local / otro modelo | `ds_dba_rncr_batch.edf_views.*` |
| Framework Batch | Desplegado en productor | SP ejecutan en **consumidor** |

**Validacion critica:** `SELECT current_database()` debe devolver `reconocerbatch` + `dba_rncr_batch` para corrida Alpha.

### Decisiones de arquitectura

1. Framework Batch permanece en cuenta productor; SP corren en consumidor via Data API cross-account.
2. Data Sharing ya configurado (`edf_views` operativo) — no incluir en scope despliegue SP.
3. PP9999 sandbox valido en mock local; certificacion Alpha pendiente en consumidor.
4. Estimacion cobertura datasharing: 3–4 dias (ver `ESTIMACION_FRAMEWORK_BATCH_CROSS_ACCOUNT_DATASHARING.md`).

### Componentes revisados (TF Dynbtch)

- Lambda Initiator, Builder, SourceValidator, SP Updater, Notifier
- Step Function principal (17 estados) + SF dinamica generada
- Integracion EventBridge ↔ Redshift (async SP completion)
- Buckets: source, definition, output, glue scripts

**Documentacion detallada:** `Framework-Batch/TF FW Dynbtch/docs/`

## Integracion con Unificacion

| Nivel YAML | SP |
|------------|-----|
| 0 | cleanup_sandbox + ensure_views + drill_crudo |
| 1 | unificacion_regla1 |
| 2 | unificacion_regla2 (6 escenarios + motor) |
| 3 | unificacion_regla3 |

Script manual equivalente: `call_unificacion_completa_alpha.sql`

## Despliegue en Experian

Guia: `proyecto/orquestacion/despliegue_framework_batch_reconocer.md`

- YAML en S3 definition repository
- Mnemotecnico en tabla de resolucion NIT
- SP previamente desplegados via pipeline DATABASE-REDSHIFT (PGM repo)
