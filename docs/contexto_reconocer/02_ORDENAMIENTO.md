---
title: ORDENAMIENTO — Overview, criterios y practicas
audience: kiro, qa, desarrolladores
sources: migracion-ordenamiento-242/requirements.md, Caracteristicas.txt
last_updated: 2026-09-03
---

# Ordenamiento 242 — Scoring de Contactabilidad

## Overview y alcance

Calcula un **score de contactabilidad** por dato de contacto usando **regresion logistica** con coeficientes Beta. Cuatro canales: telefono fijo, celular, email, direccion fisica.

| Aspecto | Detalle |
|---------|---------|
| Origen | Teradata — malla `ORDENAMIENTO_242_131.BTQ` |
| Destino | Amazon Redshift (`rec_stage`, `rec_datos`) |
| SPs a migrar | **17** stored procedures |
| Volumen | ~65–70M registros |
| Dependencia | Post-Unificacion (usa tablas unificadas) |

### Fases del proceso

1. **Materializacion BTT** — personas con cambios en modelo Bureau
2. **Materializacion REC** — personas con cambios en ubicaciones/unificacion
3. **Unificacion BTT+REC** → tabla `UNIFICA_BTT_RECONOCER`
4. **Rama atributos cuenta** — enriquecimiento portafolio, ventana 12 meses
5. **Rama ubicaciones** — vectores direccion, hash MD5 para detectar cambios
6. **Scoring** — aplicacion coeficientes Beta por canal

## Criterios de aceptacion (resumen)

Fuente formal: `.kiro/specs/migracion-ordenamiento-242/requirements.md`

| Req | User story | Criterio clave |
|-----|------------|----------------|
| 1 | Materializacion BTT | Mismo conjunto personas que `PRO_ORD_MATERIALIZA_BTT` |
| 2 | Materializacion REC | Mismo conjunto que `PRO_ORD_MATERIALIZA_REC` |
| 3 | Unificacion BTT+REC | `UNIFICA_BTT_RECONOCER` sin duplicados |
| 4 | Limpieza post-unificacion | DROP temporales, fail-fast en errores |
| 5–8 | Atributos cuenta | Equivalente a `PRO_ORD_CTA_ATRIBUTOS` |
| 9–12 | Ventana temporal / portafolio | 12 meses comportamiento |
| 13–17 | Scoring por canal | Beta por caracteristica, 4 canales |

**Pruebas:** dataset 10K documentado en `pruebas_ejecucion_redshift_10k.md`.

## Reglas de funcionamiento

> **Gap documentado:** No se encontro PDF funcional oficial de Ordenamiento equivalente al RF de Unificacion.

**Fuentes sustitutas:**

| Fuente | Contenido |
|--------|-----------|
| `data/parametros/Caracteristicas.txt` | ~160 sentencias SQL dinamicas con coeficientes Beta |
| `src/teradata/Ordenamiento.sql` | DDL + SPs cursor Teradata |
| `.kiro/specs/migracion-ordenamiento-242/design.md` | Mapeo SP Teradata → Redshift |
| `docs/tecnico/analisis_scripts.md` | Analisis modelo scoring |

### Conceptos clave

- **Score_Contactabilidad:** probabilidad contacto exitoso por canal
- **Coeficiente_Beta:** peso por caracteristica (`V_Beta_Ordenamiento_*`)
- **Hash_MD5:** detecta cambios entre ejecuciones
- **Portafolio:** CO, RO, VE, HP, IN, OT, CC, AH, CT

## Practicas de codigo

Mismas convenciones que Unificacion (ver `01_UNIFICACION.md`):

- Esquemas fijos `rec_stage` / `rec_datos` (no SQL dinamico `SP_EXECSTRING_DES`)
- Reemplazar `SET TABLE` Teradata por `SELECT DISTINCT` / `GROUP BY`
- Reemplazar `QUALIFY` por subquery + `WHERE`
- SP en repo PGM; scripts de carga en DT; DDL en STRCT
- Empaquetado pipeline identico a Unificacion

**Pendiente Experian:** PDF reglas de negocio Ordenamiento para cierre formal QA.

## Estado migracion

| Componente | Estado |
|------------|--------|
| Analisis Teradata | Completo |
| Spec Kiro (req/design/tasks) | Completo |
| SQL Redshift por fase | En `ws-ordenamiento/src/redshift/` |
| Pruebas 10K | Ejecutadas (resultados en docs/tecnico) |
| Deploy pipeline 3 repos | Pendiente (post-Unificacion) |
