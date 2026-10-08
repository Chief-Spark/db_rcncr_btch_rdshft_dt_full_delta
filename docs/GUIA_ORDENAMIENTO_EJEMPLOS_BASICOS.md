# Guía de ordenamiento — ejemplos básicos y validación DEV

**Para quién:** negocio, QA, DBA y cualquier persona que deba explicar *qué hace el ordenamiento* sin entrar al SQL.  
**Fecha:** 2026-09-11 · **Entorno validado:** DEV Reconocer (`dba_rncr_batch`) con datos reales `edf_views`.

> **Documento principal para explicar fases:** [`FASES_ORDENAMIENTO_EXPLICADAS.md`](FASES_ORDENAMIENTO_EXPLICADAS.md)  
> (1 SP = 1 paso · ejemplos smoke 20001–20009 · guión 90 s)

---

## 1. La idea en una frase

> **Unificación** responde: *“¿estas dos direcciones son la misma?”*  
> **Ordenamiento** responde: *“si tengo varias direcciones o contactos, ¿cuál intento primero?”*

No mezcla personas. No mezcla canales (teléfono no compite con email). Solo ordena **dentro de cada canal** para cada persona.

---

## 2. Analogía del día a día

Imagina a **María** en el buró:

| Lo que tiene María | Canal | Pregunta del ordenamiento |
|--------------------|-------|---------------------------|
| Casa en Suba + oficina en Chapinero | **DIR** | ¿Llamo primero a la casa o a la oficina? |
| Fijo de la casa + fijo del trabajo | **TEL** | ¿Cuál fijo uso primero? |
| Celular Claro + celular Movistar | **CEL** | ¿Cuál celular priorizo? |
| Gmail personal + correo del trabajo | **EMA** | ¿Cuál email contacto primero? |

El sistema asigna un **score** (0 a 1, aprox.) a cada opción y un **lugar**: 1 = el mejor, 2 = el segundo, etc.

Solo el canal **DIR** escribe el campo final `orden_prioridad` en el RPU (reporte de persona-ubicación). Los demás canales guardan su ranking aparte.

---

## 3. Antes de ordenar: ganadoras vs hijas

Esto viene de la **unificación** (R1, R2, R3). Ordenamiento **no redefine** quién es padre o hija; solo consume el resultado.

### Ejemplo simple — tres RPUs de la misma persona

| RPU | Dirección | `ind_unificacion` | ¿Entra al ordenamiento? | Por qué |
|-----|-----------|-------------------|-------------------------|---------|
| 10001 | Calle 10 #20 | NULL (ganadora) | **Sí** | Dirección vigente |
| 10002 | Calle 10 #20 apto 3 | **1** (hija) | **No** | Absorbida por RPU 10001 en R2 |
| 10003 | Carrera 5 #1 | NULL (ganadora) | **Sí** | Otra calle distinta; compite con 10001 |

**Regla F3-02 (documento v2.0):** las hijas **nunca** reciben score ni `orden_prioridad`. Solo quedan en `unificacion_direccion` para trazabilidad.

### Números reales DEV (2026-09-04)

| Concepto | Cantidad | ¿Correcto? |
|----------|----------:|:----------:|
| RPUs ganadoras (compiten) | 518.718 | ✓ |
| RPUs hijas (excluidas) | 72.448 | ✓ |
| Hijas con orden incorrecto | **0** | ✓ **gate crítico** |
| Personas con al menos una ganadora | 407.351 | ✓ |

---

## 4. Las fases del proceso (pipeline DEV)

En DEV corre la **Opción A**: lectura directa desde `edf_views` (datasharing), sin copia permanente de XPM.

```mermaid
flowchart LR
    A[Unificación previa] --> B[Fase 1: Preparar insumos]
    B --> C[Fase 2: Scoring ×4 canales]
    C --> D[Salida: Consolidación]
    D --> E[Limpieza staging]
```

| Fase | Qué hace (lenguaje simple) | Entrada | Salida |
|------|---------------------------|---------|--------|
| **0 — Precondición** | Ya corrió unificación R1→R2→R3 | RPUs + `unificacion_direccion` | `ind_unificacion` por RPU |
| **1 — Insumos** | Lee contactos de XPM, filtra ganadoras, arma tablas temporales | `edf_views` + unificación | `stg_insumo_dir`, `tel`, `cel`, `ema` |
| **2 — Scoring** | Calcula score y `lugar` por canal | Insumos + betas | `score_ordenamiento` |
| **3 — Salida** | Persiste el mejor orden de dirección por RPU | Scores DIR + RPUs ganadoras | `rpu_orden_prioridad` |
| **4 — Limpieza** | Borra tablas temporales de la corrida | `stg_*` | — |

**Comando de corrida completa:**

```sql
CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);
```

**Tiempos DEV reales:** preparar ~78 s · scoring ~20 s · **1.223.998** scores totales.

---

## 5. Los cuatro canales — qué pregunta responde cada uno

| Canal | Pregunta de negocio | Agrupa por | Escribe `orden_prioridad` |
|-------|---------------------|------------|:-------------------------:|
| **DIR** | ¿Qué **dirección** contactar primero? | Persona + calle física | **Sí** |
| **TEL** | ¿Qué **teléfono fijo** primero? | Persona + número | No |
| **CEL** | ¿Qué **celular** primero? | Persona + número | No |
| **EMA** | ¿Qué **email** primero? | Persona + correo | No |

**Regla transversal:** TEL, CEL y EMA solo aplican si la persona tiene **al menos una dirección ganadora**.

### Mapeo contactType → canal (XPM / edf_views)

| contactType | Canal | Ejemplo |
|:-----------:|:-----:|---------|
| 1, 2, 3, 7, 8 | DIR | Residencia, laboral, correspondencia |
| 4, 5, 8 | TEL | Fijo casa, fijo trabajo |
| 9 | CEL | Celular |
| 10 | EMA | Email (debe tener `@`) |

---

## 6. Cómo se calcula el score (explicación simple)

Todos los canales siguen la misma lógica:

```
1. Agrupar reportes por persona + contacto (ej. persona + calle, o persona + teléfono)
2. Calcular métricas (meses de antigüedad, cantidad de reportes, sector financiero, etc.)
3. Meter cada métrica en una “categoría” (bin 1, 2, 3…) según umbrales fijos del documento
4. Score = Σ (categoría / máximo_de_esa_categoría) × Beta
5. lugar = posición al ordenar de mayor a menor score dentro de la misma persona
```

### Mini-ejemplo numérico (DIR, simplificado)

Supón que para la dirección **Calle 10 #20** solo miramos 2 características:

| Característica | Valor real | Categoría (1–4) | Beta | Aporte al score |
|----------------|------------|-----------------|------|-----------------|
| Meses con reportes recientes | Alto | 4 / 4 | 0.15 | 0.15 |
| % sector financiero | Medio | 2 / 3 | 0.20 | 0.13 |
| **Total score** | | | | **≈ 0.28** *(+ otras 10 vars)* |

La dirección **Carrera 5 #1** con menos historial podría quedar en **0.21** → `lugar = 2`.

En DEV real el score DIR va de **0.6113** a **0.8430** (12 características, todas en la suma).

---

## 7. Ejemplos básicos por persona (smoke test — 9 personas)

Estos datos están en `sql/ordenamiento_mock/06_smoke_mock_9_personas.sql`. Sirven para demo en reunión porque son **pequeños y legibles**.

### Persona 20001 — dos direcciones compiten (DIR)

| Dirección | Tipo | Reportes | Qué pasa |
|-----------|------|----------|----------|
| CL 22 27 45 AP 101 | RES (casa) | 3 | Compite → `lugar` 1 o 2 |
| KR 15 80 22 OF 301 | LAB (oficina) | 2 | Compite → la otra posición |

**Qué explicar:** misma persona, dos calles distintas. La que tenga mejor historial de reportes gana `lugar = 1`.

---

### Persona 20002 — una sola dirección (caso más simple)

| Campo | Valor |
|-------|-------|
| Dirección | TV 70 114 55, barrio Suba, tipo RES |
| Reportes | 8 (2022–2025) |
| Resultado | **1 score DIR**, `lugar = 1`, `orden_prioridad = 1` |

**Qué explicar:** cuando solo hay una dirección ganadora, el ranking es trivial: siempre lugar 1.

---

### Persona 20003 — tres direcciones (ranking completo)

| Dirección | Tipo | Reportes aprox. |
|-----------|------|-----------------|
| DG 50 30 10 TO 3 | CRR | 3 |
| KR 7 45 12 AP 504 | RES | 1 |
| AC 40 12 08 ED GALICIA | LAB | 4 |

**Qué explicar:** tres scores DIR, `lugar` 1, 2 y 3. La oficina con más reportes suele subir; el sistema no elimina ninguna (todas son ganadoras).

---

### Persona 20004 — teléfono válido vs no válido (TEL)

| Teléfono | Dirección vinculada | Estado | ¿Compite igual? |
|----------|---------------------|--------|-----------------|
| Fijo en CL 10 20 30 | Casa | VALIDA | Sí |
| Fijo en KR 20 55 18 | Otra | **NO VALIDA** | Penalizado / filtrado en agregación |

**Qué explicar:** datos sucios no rankean igual que los válidos. Es el espíritu de F3-01 (NO VÁLIDO).

---

### Persona 20006 — dos celulares, operadores distintos (CEL)

| Celular | Prefijo | Operador (catálogo) | Tipo |
|---------|---------|---------------------|------|
| 3101234567 | 310 | Claro (62.0 en catálogo) | Prepago |
| 3209876543 | 320 | Otro operador | Pospago |

**Qué explicar:** el prefijo alimenta la variable CEL018. Si no hay operador en catálogo → default **0.22** (regla CEL-02).

---

### Persona 20008 — dos emails (EMA)

| Email | Dominio | Tipo |
|-------|---------|------|
| user1@gmail.com | gmail (popular) | Personal |
| work@empresa.co | empresa.co | Corporativo |

**Qué explicar:** dominio popular vs corporativo mueve variables distintas (EMA014, EMA024). El ranking EMA es independiente del DIR.

---

### Persona 20005 — un solo fijo (TEL simple)

Un teléfono VALIDA → **lugar = 1**. Caso trivial para mostrar ranking TEL independiente.

---

### Persona 20007 — un solo celular (CEL simple)

Un celular → **lugar = 1**.

---

### Persona 20009 — un solo email (EMA simple)

`otro@hotmail.com` → **lugar = 1**.

---

### Resumen smoke (corrida 2026-08-26)

| Métrica | Resultado | ¿OK? |
|---------|----------:|:----:|
| Scores DIR | 6 | ✓ |
| Scores TEL | 3 | ✓ |
| Scores CEL | 3 | ✓ |
| Scores EMA | 3 | ✓ |
| **Total** | **15** | ✓ |
| RPUs con `orden_prioridad` | 15 | ✓ |

---

## 8. Casos especiales — ya corregidos y explicados

### F3-02 — Hija de unificación

| Campo | Hija | Padre ganador |
|-------|------|---------------|
| `ind_unificacion` | 1 | NULL |
| `score_ordenamiento` | No existe | Sí (ej. 0.72) |
| `orden_prioridad` | NULL | 1 |

**DEV:** 72.448 hijas, **0** con orden incorrecto.

---

### TEL-02 — Variable geo calculada pero fuera del score

| Variable | ¿Se calcula? | ¿Suma al score? |
|----------|:------------:|:---------------:|
| TEL010 (sector financiero) | Sí | Sí |
| **TEL020** (coincidencia geográfica) | Sí | **No** (como Teradata) |

**Por qué importa:** si TEL020 sumara, el ranking cambiaría vs producción Teradata. Corregido 2026-09-04.

---

### EMA-03 — Variables de trazabilidad fuera del score

| Variable | ¿Calcula? | ¿En suma final? |
|----------|:---------:|:---------------:|
| EMA003, EMA007, EMA018, EMA025 | Sí | **No** |
| EMA010, EMA014, EMA016, … | Sí | Sí |

**Por qué importa:** Teradata las calcula para auditoría pero no las usa en `Sumatoria_Score_Email`.

---

### CEL-02 — Operador desconocido

| Prefijo | Catálogo | CEL018 (= valor × 100) |
|---------|----------|------------------------|
| 310 | Claro | 62.0 |
| 300 | Comcel | 55.0 |
| 999 | Sin mapeo | **22.0** (default 0.22) |

---

### RANK-02 — Empate de score

Si dos direcciones tienen el **mismo score**, no hay regla nueva de desempate: `ROW_NUMBER` elige un orden (igual que baseline Teradata). Si en paridad hay diferencia, se documenta como hallazgo; **no se inventa criterio**.

---

## 9. Salida final — consolidación

| Paso | Regla |
|------|-------|
| 1 | Tomar scores del canal **DIR** |
| 2 | Solo RPUs **ganadoras** |
| 3 | Mejor `lugar` por RPU → `orden_prioridad` |
| 4 | Guardar en `rpu_orden_prioridad` |

### Ejemplo consolidado

| Persona | Dirección | Score DIR | lugar | orden_prioridad |
|---------|-----------|----------:|------:|----------------:|
| P-100 | Calle 10 #20 | 0.84 | 1 | **1** |
| P-100 | Carrera 5 #1 | 0.71 | 2 | **2** |
| P-100 | Calle 10 apto 3 (hija) | — | — | **NULL** |

**DEV:** 408.624 RPUs con `orden_prioridad` asignado.

---

## 10. ¿Quedó bien? — Checklist de validación

Usar después de cada corrida en DEV:

| # | Pregunta | Cómo verificar | Resultado esperado DEV | Estado |
|---|----------|----------------|------------------------|:------:|
| 1 | ¿Corrió el pipeline completo? | Stages en evidencias E2E | Todos OK | ✓ |
| 2 | ¿Hay scores en los 4 canales? | `COUNT(*)` por canal | DIR/TEL/EMA ~407K; CEL bajo (datos) | ✓ |
| 3 | ¿Ninguna hija tiene orden? | `rpu_hijas_con_orden_incorrecto` | **0** | ✓ |
| 4 | ¿Todas las ganadoras DIR tienen score? | Comparar conteos | ~409K scores DIR | ✓ |
| 5 | ¿Fórmulas alineadas a Teradata? | TEL-02, EMA-03, CEL-02 | Corregidas 2026-09-04 | ✓ |
| 6 | ¿Betas cargadas? | `beta_ordenamiento` | 47 filas mock | ✓ (mock) |
| 7 | ¿Tiempo aceptable? | Log corrida | ~98 s total | ✓ |

### Query rápida — gate de hijas (debe dar 0)

```sql
SELECT COUNT(*) AS hijas_con_orden_incorrecto
FROM bdm_datos.relacion_persona_ubicacion
WHERE COALESCE(ind_unificacion, 0) = 1
  AND orden_prioridad IS NOT NULL;
```

### Query rápida — scores por canal

```sql
SELECT canal,
       COUNT(*) AS scores,
       ROUND(MIN(score::FLOAT), 4) AS min_s,
       ROUND(MAX(score::FLOAT), 4) AS max_s
FROM bdm_datos.score_ordenamiento
GROUP BY 1
ORDER BY 1;
```

---

## 11. Cómo explicarlo en 2 minutos (guión — lenguaje de sesiones)

1. **Contexto:** “Después de unificar, a cada persona le quedan direcciones *ganadoras* y contactos en XPM.”
2. **Problema:** “Si María tiene casa, oficina, dos celulares y tres emails, ¿por cuál empezamos?”
3. **Solución:** “Ordenamiento calcula un score por canal usando el **catálogo de betas** (RITM) y asigna lugar 1, 2, 3… Solo DIR escribe `orden_prioridad`.”
4. **Filtro clave:** “Las *hijas* de unificación no compiten — ya no son vigentes.” *(mesa)*
5. **Evidencia:** “DEV: 1,2M scores, 0 hijas mal ordenadas, fórmulas TEL/EMA/CEL y betas reales.”
6. **Demo:** “20001 casa/oficina · 20004 fijo válido · 20006 celulares · 20008 emails.”
7. **Qué no es:** “No recalculamos betas, no hacemos 242 completo ni incremental en este sprint.”

---

## 12. Qué falta (alineado a sesiones — no bloquea Opción A)

| Tema | Estado | Impacto |
|------|--------|---------|
| Betas catálogo RITM5226589 | **Cargado** (47 coefs Teradata) | Datashare IFR continuo = opcional |
| Paridad Teradata Opción B / MIG-01 | Diferido en sesión | Scoring Opción A OK |
| Procesamiento incremental (F1) | Fuera de alcance Opción A | Full refresh acordado |
| Cobertura CEL en DEV | Baja (115 personas) | Dato del ambiente, no del SP |
| PRs `feature/ordenamiento` | Pendiente abrir | Rama lista |
| Re-evidencia consumidor post-betas | Parcial | Productor DEV OK; Reconocer cuando se desbloquee |

---

## 13. Documentos relacionados

| Documento | Para qué |
|-----------|----------|
| `FASES_ORDENAMIENTO_EXPLICADAS.md` | **Explicar fases** — 1 SP = 1 paso + ejemplos |
| `MAPA_ORDENAMIENTO_EDF_VIEWS_NEGOCIO.html` | Mapa interactivo (pestañas 1→2a→2b→2c→2d→3-4→SPs) |
| `Evidencias_DEV_ORDENAMIENTO_EDF_COMPLETO.md` | Números E2E con datos reales |
| `Evidencias_Ordenamiento_Smoke_DEV.md` | Smoke 9 personas |
| `Evidencias_ORDENAMIENTO_FORMULAS_DEV.md` | Detalle TEL-02, EMA-03, CEL-02 |
| `PRESENTACION_ORDENAMIENTO_NEGOCIO.md` | Preguntas para sesión con negocio |

---

*Generado para el paquete PAQUETE_UNIFICACION_BDM_STAGE — ordenamiento DEV edf_views.*
