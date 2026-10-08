---
title: Documentacion Confluence — Reconocer Master Cloud
audience: confluence, sponsors, equipo completo
sources: INDICE_DOCUMENTACION.md, RECONOCER_GO_Arquitectura.md
last_updated: 2026-09-03
---

# Reconocer Master Cloud — Documentacion de proyecto

> Plantilla lista para publicar en Confluence. Adaptar IDs Jira y fechas al publicar.

---

## 1. Objetivo

Migrar el sistema **Reconocer** de Experian Colombia desde Teradata hacia una arquitectura cloud-native en AWS, manteniendo la logica de negocio de estandarizacion, unificacion, ordenamiento y geo-codificacion sobre ~65–70 millones de registros de contacto.

**Meta:** Apagar Teradata antes del **31 de marzo de 2027**.

---

## 2. Contexto

### Situacion actual (AS-IS)

- Procesamiento batch en **Teradata** con UDFs en C
- Orquestacion **Control-M**
- Ingesta legacy **COBOL** → Teradata
- Datos de contacto en modelo XPM

### Situacion objetivo (TO-BE)

- **EDF** (Spark/Scala) para ingesta y estandarizacion en cuenta productor
- **Amazon Redshift** para unificacion, ordenamiento y calculo batch
- **Framework Batch** (Step Functions) reemplaza Control-M
- **Data Sharing** cross-account para lectura `edf_views` sin copiar datos
- **ArcGIS** para enriquecimiento geografico
- Salida a **DB2** para servicios online

### Stakeholders

| Rol | Responsabilidad |
|-----|-----------------|
| Experian — Producto | RF, aceptacion funcional |
| Experian — DBA / DevSecOps | Pipeline Redshift, grants, ventanas PDN |
| Macondotek — Migracion | Codigo SQL, pruebas, documentacion |
| Nubitral | Migracion paralela Teradata (otros procesos) |

---

## 3. Como se desarrollo?

### 3.1 Procedimientos

#### Migracion Teradata → Redshift

1. Analisis SP Teradata origen (`.TPT`, `.BTQ`, `.sql`)
2. Traduccion a SQL estatico Redshift (sin SQL dinamico)
3. Adaptacion modelo XPM → vistas `edf_views` via Data Sharing
4. Empaquetado en 3 repos Bitbucket (STRCT / PGM / DT)
5. Despliegue pipeline Dev → QA → PDN desde Jira
6. Certificacion benchmark + aceptacion Experian

#### Convenciones de desarrollo

- Workspaces: `ws-unificacion`, `ws-ordenamiento`
- Steering Kiro en `.kiro/steering/`
- Sandbox PP9999 para validacion integrada Framework Batch
- No modificar dump original `Experian Reconocer/`

### 3.2 Ejecucion

#### Pipeline batch (Framework Batch)

```
Archivo .val en S3
  → Step Functions
  → SP nivel 0 (cleanup + vistas)
  → SP nivel 1 (Regla 1)
  → SP nivel 2 (Regla 2 + motor)
  → SP nivel 3 (Regla 3)
  → Glue consolidacion + email SES
```

#### Pipeline despliegue SQL (DATABASE-REDSHIFT)

```
Commit Bitbucket (ID Jira)
  → Subtarea Execution
  → Jenkins ejecuta deploy.par en orden
  → Validacion post-deploy (DBeaver / queries)
  → PR a QA → PR a PDN
```

#### Orden de deploy por release

1. **STRCT** — tablas, vistas lectura, catalogos
2. **PGM** — stored procedures
3. **DT** — validacion y CALL certificacion

---

## 4. Diagrama de arquitectura

Ver archivo: [`diagramas/arquitectura_reconocer_datasharing.drawio`](../diagramas/arquitectura_reconocer_datasharing.drawio)

### Componentes principales

| Capa | Tecnologia |
|------|------------|
| Ingesta / Estandarizacion | EDF (Spark), cuenta productor Alpha |
| Almacenamiento compartido | Redshift Data Sharing `edf_views` |
| Procesamiento batch | Redshift consumidor + SP |
| Orquestacion | Framework Batch (Step Functions, Lambda) |
| Geo | ArcGIS + S3 + Lambda ResultTransfer |
| Despliegue SQL | Bitbucket + Jira + Jenkins |
| Salida online | DB2 |

### Cuentas AWS

| Cuenta | ID | Rol |
|--------|-----|-----|
| Productor (procesosbatch) | 651706752126 | EDF, Framework Batch, datashare productor |
| Consumidor (reconocerbatch) | 647096294147 | Redshift batch, SP Reconocer |

---

## 5. Alcance, limitaciones y fuera de alcance

### En alcance

- Migracion Unificacion (R1, R2, R3, motor) a Redshift
- Migracion Ordenamiento 242 (17 SPs)
- Integracion Framework Batch + YAML procesos
- Data Sharing lectura `edf_views`
- Contratos Geo INPUT/OUTPUT
- Pipeline DATABASE-REDSHIFT (3 repos)
- Benchmark y certificacion QA

### Limitaciones conocidas

- Data Sharing es **solo lectura** — estado de unificacion en tablas locales
- Framework Batch en cuenta productor ejecuta SP en consumidor (cross-account)
- PDF reglas Ordenamiento no entregado — specs derivadas de Teradata
- Certificacion Alpha edf_views en consumidor pendiente de cierre

### Fuera de alcance

- Migracion COBOL / ICBDIR (otro equipo)
- Configuracion infra Data Sharing (DBA/Infra)
- Desarrollo ArcGIS / PostGIS
- Estandarizacion en EDF (libreria J17 — equipo EDF)
- Procesos Teradata fuera de Reconocer Batch (Nubitral)

---

## 6. En que punto estamos

### Hitos completados

| Hito | Fecha aprox. |
|------|--------------|
| Analisis funcional Unificacion | May 2026 |
| Migracion R1–R3 a SQL Redshift | Jun–Ago 2026 |
| Benchmark 20K certificado (mock) | Jul 2026 |
| PP9999 sandbox + pipeline 3 repos | Ago 2026 |
| Data Sharing cross-account validado | Ago 2026 |
| Consolidado Kiro (este paquete) | Sep 2026 |

### En curso

| Actividad | % estimado |
|-----------|------------|
| Unificacion Alpha edf_views en consumidor | 80% |
| Ordenamiento 242 migracion SP | 60% |
| Framework Batch cross-account PP9999 | 70% |
| Geo integracion S3 | 50% |

### Proximos pasos

1. Cerrar HU `SLCOPRBA-UNIF` — deploy Unificacion edf_views Dev→QA
2. Certificacion formal Experian (benchmark Alpha)
3. Continuar Ordenamiento SP + pruebas 10K
4. Publicar documentacion Confluence desde este consolidado
5. Ventana PDN post-aprobacion CAB

---

## Anexos

| Documento | Ubicacion consolidado |
|-----------|----------------------|
| Overview proyecto | `docs/00_RECONOCER.md` |
| Unificacion | `docs/01_UNIFICACION.md` |
| Ordenamiento | `docs/02_ORDENAMIENTO.md` |
| Framework Batch | `docs/03_FRAMEWORK_BATCH.md` |
| Geo | `docs/04_GEO.md` |
| QA | `docs/05_PRUEBAS_QA.md` |
| Guia IA repos | `docs/GUIA_IA_REORGANIZACION_REPOS.md` |
