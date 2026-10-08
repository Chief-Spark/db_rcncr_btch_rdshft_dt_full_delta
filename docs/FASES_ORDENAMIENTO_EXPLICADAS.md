# Ordenamiento — fases explicadas con ejemplos (1 SP = 1 paso)

**Para:** explicar el proceso sin SQL.  
**Fecha:** 2026-09-11 · **DEV validado:** R2 unificación 72.448 · ordenamiento 1.223.998 scores · c03/c04 = 0.

**Proceso completo:** [`PROCESO_RECONOCER_END_TO_END.md`](PROCESO_RECONOCER_END_TO_END.md) · contexto consolidado: [`contexto_reconocer/02_ORDENAMIENTO.md`](contexto_reconocer/02_ORDENAMIENTO.md)  
**Proceso punta a punta:** [`PROCESO_RECONOCER_END_TO_END.md`](PROCESO_RECONOCER_END_TO_END.md) · contexto: [`contexto_reconocer/02_ORDENAMIENTO.md`](contexto_reconocer/02_ORDENAMIENTO.md)

---

## Idea en 10 segundos

1. **Unificación** ya decidió qué direcciones están vigentes (**ganadoras**) y cuáles no (**hijas**). *(Acuerdo mesa: no avanzar ordenamiento sin eso.)*
2. **Ordenamiento** responde: *si hay varias opciones, ¿cuál contacto intento primero?*
3. Lo hace **por canal** (DIR, TEL, CEL, EMA). Un teléfono **no** compite con un email.
4. Los **betas son un catálogo** (RITM5226589): coeficientes × características → score → lugar.

**Fuera de este sprint (sesión):** malla 242 completa · incremental · recalcular betas · QA productor.

---

## Mapa de fases (así se explica en reunión)

| Fase | Pregunta de negocio | Qué corre | Ejemplo smoke |
|------|---------------------|-----------|---------------|
| **0** Precondición | ¿Quién es dirección vigente? | Unificación (ya hecha) | Hija RPU 10002 fuera; 10001 y 10003 entran |
| **1** Armar candidatos | ¿Qué contactos entran? | Vistas + `preparar_insumos` | Solo ganadoras; email sin `@` fuera |
| **2a** Ordenar calles | ¿Qué dirección primero? | `scoring_dir` | Persona **20001** (casa vs oficina) |
| **2b** Ordenar fijos | ¿Qué teléfono primero? | `scoring_tel` | Persona **20004** (válido vs no válido) |
| **2c** Ordenar celulares | ¿Qué celular primero? | `scoring_cel` | Persona **20006** (Claro vs otro) |
| **2d** Ordenar emails | ¿Qué correo primero? | `scoring_ema` | Persona **20008** (gmail vs corporativo) |
| **3** Guardar orden | ¿Qué queda en el RPU? | `consolidacion` | `lugar` → `orden_prioridad` |
| **4** Limpiar | ¿Queda basura? | `drop_staging` | Borra `stg_*` |
| **Run** | ¿Cómo se ejecuta todo? | `ejecucion_edf` + run `_dt` | Un solo `CALL ...(TRUE)` |

> **Nota:** En el mapa HTML la pestaña “Fase 1” = **armar candidatos** (fase 1 de arriba). No es la F1 Teradata de materialización incremental (esa no corre en Opción A DEV).

---

## Fase 0 — Ya unificado (sin SP de ordenamiento)

**Pregunta:** ¿Esta dirección sigue vigente?

| RPU | Calle | ind_unificacion | ¿Ordenamiento? |
|-----|-------|-----------------|----------------|
| 10001 | Calle 10 #20 | NULL | Sí |
| 10002 | Calle 10 #20 apto 3 | **1** (hija) | **No** |
| 10003 | Carrera 5 #1 | NULL | Sí |

**Cómo explicarlo:** “La hija ya no es el contacto vigente; el negocio llama al padre.”

---

## Fase 1 — Armar candidatos (qué entra)

### 1.1 Setup (una vez) — `_strct`

| ID | Archivo | En español |
|----|---------|------------|
| SP-00 | `01_ddl_ordenamiento.sql` | Crea tablas: scores, orden, betas |
| SP-01 | `02_catalogos_ordenamiento.sql` | Catálogos (sector, tipo cuenta, operador celular) |
| SP-02 | `03_vistas_contacto_canal…` | Traduce `contactType` → canal (TEL/CEL/EMA/DIR) |
| SP-03 | `04_vistas_insumo…` | Contrato de lectura: solo ganadoras |

**Ejemplo contactType:**

| Type | Canal | Ejemplo |
|------|-------|---------|
| 1,2,3,7 | DIR | Casa / oficina |
| 4,5 | TEL | Fijo |
| 9 | CEL | Celular |
| 10 | EMA | Email (debe tener `@`) |

### 1.2 Preparar insumos (cada corrida) — SP-04

**SP:** `sp_ordenamiento_preparar_insumos_edf`  
**Pregunta:** ¿Qué filas van a scoring hoy?

**Pasos internos (subdivisión para explicar):**

1. Leer RPUs post-unificación  
2. Quedarse solo con **ganadoras** (`ind_unificacion ≠ 1`)  
3. Armar contactos por canal desde XPM  
4. Materializar `stg_insumo_direccion / telefono / celular / email`  
5. `ANALYZE` staging  

**Ejemplo:** Persona con email `sinarroba.com` → **no entra** a EMA.  
Persona solo con hija → **no entra** a ningún canal.

---

## Fase 2a — DIR (direcciones) — SP-05

**SP:** `sp_ordenamiento_scoring_dir_edf`  
**Pregunta:** ¿Qué **calle** contactar primero?

**Pasos internos:**

1. Agrupar reportes por persona + dirección  
2. Calcular 12 métricas (antigüedad, reportes, sector, tipo RES/LAB/CRR…)  
3. Convertir a categorías × Beta → **score**  
4. `ROW_NUMBER` → **lugar** 1, 2, 3…

### Ejemplo A — Persona 20001 (dos calles)

| Dirección | Tipo | Reportes | Resultado |
|-----------|------|----------|-----------|
| CL 22 27 45 AP 101 | RES | 3 | Compite → lugar 1 o 2 |
| KR 15 80 22 OF 301 | LAB | 2 | Compite → la otra |

**Frase:** “Misma persona, dos calles distintas. Gana la de mejor historial.”

### Ejemplo B — Persona 20002 (una calle)

| Dirección | Resultado |
|-----------|-----------|
| TV 70 114 55 Suba RES (8 reportes) | **lugar = 1**, trivial |

### Ejemplo C — Persona 20003 (tres calles)

| Dirección | Tipo |
|-----------|------|
| DG 50 30 10 | CRR |
| KR 7 45 12 | RES |
| AC 40 12 08 Galicia | LAB |

**Frase:** “Tres scores DIR → lugar 1, 2 y 3. Ninguna se borra; solo se ordenan.”

---

## Fase 2b — TEL (fijo) — SP-06

**SP:** `sp_ordenamiento_scoring_tel_edf`  
**Pregunta:** ¿Qué **teléfono fijo** primero?

**Detalle fácil:** se calcula TEL020 (geo) pero **no suma al score** (igual Teradata).

### Ejemplo — Persona 20004

| Teléfono | Estado | ¿Compite igual? |
|----------|--------|-----------------|
| Fijo en CL 10 20 30 | VALIDA | Sí |
| Fijo en KR 20 55 18 | NO VALIDA | No / peor |

### Ejemplo — Persona 20005

Un solo fijo válido → **lugar = 1**.

**Frase:** “TEL no cambia el orden de la dirección; es un ranking aparte.”

---

## Fase 2c — CEL (celular) — SP-07

**SP:** `sp_ordenamiento_scoring_cel_edf`  
**Pregunta:** ¿Qué **celular** primero?

**Detalle fácil:** prefijo 310 → Claro en catálogo; prefijo desconocido → default **0.22**.

### Ejemplo — Persona 20006

| Celular | Prefijo | Operador |
|---------|---------|----------|
| 3101234567 | 310 | Claro |
| 3209876543 | 320 | Otro |

### Ejemplo — Persona 20007

Un solo celular → **lugar = 1**.

---

## Fase 2d — EMA (email) — SP-08

**SP:** `sp_ordenamiento_scoring_ema_edf`  
**Pregunta:** ¿Qué **email** primero?

**Detalle fácil:** algunas variables se calculan pero **no suman** (EMA003/007/018/025).

### Ejemplo — Persona 20008

| Email | Tipo |
|-------|------|
| user1@gmail.com | Personal / dominio popular |
| work@empresa.co | Corporativo |

### Ejemplo — Persona 20009

Un solo hotmail → **lugar = 1**.

---

## Fase 3 — Guardar orden — SP-09

**SP:** `sp_ordenamiento_consolidacion_edf`  
**Pregunta:** ¿Qué `orden_prioridad` queda guardado?

**Pasos:**

1. Tomar scores de RPUs **ganadoras**  
2. Mejor `lugar` por RPU  
3. Escribir `rpu_orden_prioridad` (DELETE + INSERT)

### Ejemplo consolidado

| Persona | Dirección | Score | lugar | orden_prioridad |
|---------|-----------|------:|------:|----------------:|
| P-100 | Calle 10 #20 | 0.84 | 1 | **1** |
| P-100 | Carrera 5 #1 | 0.71 | 2 | **2** |
| P-100 | Calle 10 apto 3 (hija) | — | — | **NULL** |

**DEV:** ~408.624 RPUs con orden · **0** hijas con orden incorrecto.

---

## Fase 4 — Limpiar — SP-10

**SP:** `sp_ordenamiento_drop_staging_edf`  
Borra `bdm_tempo.stg_*`. La próxima corrida las recrea.

---

## Run — Cómo se ejecuta todo — SP-11 / SP-12 / SP-13

```sql
CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);
```

Orden interno del orquestador:

```
preparar → DIR → TEL → CEL → EMA → consolidar → drop
```

| ID | Archivo | Rol |
|----|---------|-----|
| SP-11 | `sp_ordenamiento_ejecucion_edf.sql` | Orquestador |
| SP-12 | `run_ordenamiento_ejecucion_edf.sql` | Runbook Jenkins (`_dt`) |
| SP-13 | `validacion_ordenamiento_conteos.sql` | Gate: hijas con orden = 0 |

---

## Checklist “¿quedó bien?” (DEV)

| Check | Esperado |
|-------|----------|
| R2 unificación | ~72.448 |
| Scores totales ordenamiento | ~1.223.998 |
| Hijas con `orden_prioridad` | **0** |
| c03 / c04 unificación | **0** / **0** |

---

## Guión de 90 segundos

1. “Después de unificar, solo ganadoras entran.”  
2. “Preparamos insumos una vez por corrida.”  
3. “Rankeamos por canal: calles, fijos, celulares, emails — separados.”  
4. “Guardamos `orden_prioridad` y limpiamos temporales.”  
5. “Demo: 20001 dos calles; 20004 fijo válido/no válido; 20006 dos celulares.”

---

## Dónde está cada cosa

| Artefacto | Ruta |
|-----------|------|
| Este documento | `Documentacion/FASES_ORDENAMIENTO_EXPLICADAS.md` |
| Guía + PDF | `Documentacion/GUIA_ORDENAMIENTO_EJEMPLOS_BASICOS.*` |
| Mapa HTML | `Documentacion/MAPA_ORDENAMIENTO_EDF_VIEWS_NEGOCIO.html` |
| Smoke 9 personas | `sql/ordenamiento_mock/06_smoke_mock_9_personas.sql` |
| SPs DEV | `sql/dev_edf_ordenamiento/` |
| Bitbucket | rama `feature/ordenamiento` en `_strct` → `_pgm` → `_dt` |
