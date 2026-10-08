# Cómo funciona — Regla 1, Regla 2 y Ordenamiento (con IDs reales DEV)

**Para leer y corroborar en DBeaver.**  
**Ambiente:** Reconocer DEV · `dba_rncr_batch`  
**Host:** `eec-aws-us-eits-reconocerbatch-dev-redshift.cz7jl1sn7m8z.us-east-1.redshift.amazonaws.com` · puerto **5440**  
**Usuario:** `c32525e`  
**Fecha de extracción:** 2026-09-23  

> Los IDs de abajo salen de la misma lógica del HTML de unificación/ordenamiento (`padre_rpu=2`, `hija_rpu=3`) y se verificaron en vivo en DEV.

---

## 0. IDs que vas a buscar (anótalos)

### Caso A — El del HTML (par simple Regla 2 → Ordenamiento)

| Campo | Valor | Dónde se usa |
|-------|------:|--------------|
| **id_buro_persona** | `3228096126421495389` | Buscar en scores / orden |
| **cod_pin_persona** | `98746` | Referencia de persona |
| **RPU padre (ganadora)** | `2` | Quedó vigente |
| **RPU hija** | `3` | Absorbida por Regla 2 |
| **Regla** | `2` (`unifica_atributos = 2`) | Solo Regla 2 en este par |

En el HTML de unificación aparecía `hija_rpu: 3`, `padre_rpu: 2`. Ese par **sigue en DEV**. El `id_buro` dueño del padre es el de la tabla.

### Caso B — Más completo (2 hijas R2 + 2 direcciones ordenadas)

| Campo | Valor |
|-------|------:|
| **id_buro_persona** | `2848501447849812647` |
| **cod_pin_persona** | `165259` |
| **RPU ganadora lugar 1** | `166366` (score DIR más alto) |
| **RPU ganadora lugar 2** | `166369` (también padre de 2 hijas) |
| **Hijas R2** | `166367` y `166368` → padre `166369` |

Úsalo cuando quieras ver **ordenamiento con dos direcciones** y que las hijas no reciban score.

### Regla 1 en esta muestra DEV

Hoy en DEV: **0 filas** con `unifica_atributos = 1`.  
No hay un ID R1 que buscar: en datos reales actuales no hubo ganador único multitipo (empates / poca variedad). Eso es esperado, no es fallo del SP.

---

## 1. Historia en un minuto

1. **Unificación** decide qué reportes de dirección son la misma y cuál queda **vigente (padre/ganadora)** vs **absorbido (hija)**.  
2. **Ordenamiento** solo mira ganadoras y decide **qué contacto intentar primero** por canal (DIR, TEL, CEL, EMA).

Cascada:

```
Regla 1 → Regla 2 (+ motor) → Regla 3 → Ordenamiento
```

---

# PARTE A — REGLA 1 (teoría + por qué no hay ID hoy)

## 2. Qué hace Regla 1

**Pregunta:** ¿Misma puerta, distinto tipo de uso (RES / LAB / CRR)? ¿Quién es padre según CIIU?

| Escenario | CIIU | Preferencia de padre |
|-----------|------|----------------------|
| Esc 1 | `10` | LAB o CRR (más entidades reportantes) |
| Esc 2 | `81`, `82`, `90` | RES o CRR |
| Esc 3 | Otro | El de más entidades, sin filtrar tipo |

Si hay **empate** (dos con la misma fuerza), Regla 1 **no unifica**.

### Query — confirmar que R1 está en 0 en DEV

```sql
SELECT unifica_atributos, COUNT(*) AS n
FROM bdm_datos.unificacion_direccion
GROUP BY 1
ORDER BY 1;
```

**Resultado esperado hoy:** solo fila `(2, ~72549)`. Sin fila `1`.

---

# PARTE B — REGLA 2 con ID real (Caso A)

## 3. Qué hace Regla 2

**Pregunta:** Misma puerta (y tipología aplicable), **distinto complemento** (o uno vacío) → ¿quién gana?  
Escenarios: vacío vs valor, contenido, nomenclatura, **diccionario** (solo si hay ganador único; empate no se fuerza), nivel, frecuencia, motor de nuevas direcciones.

## 4. Caso A en números reales

| Rol | RPU | Qué pasó |
|-----|----:|----------|
| **Hija** | `3` | Absorbida |
| **Padre** | `2` | Vigente |
| Regla | **2** | `unifica_atributos = 2` |
| Fecha unificación | 2026-09-22 | Corrió Jenkins (`user_svc_jenkins`) |

### Query 1 — el par del HTML

```sql
SELECT
  cod_dw_persona_ubic      AS hija_rpu,
  cod_dw_direccion_unificada AS padre_rpu,
  unifica_atributos        AS regla,
  fecha_unificacion,
  usuario_bd
FROM bdm_datos.unificacion_direccion
WHERE cod_dw_persona_ubic = 3
  AND cod_dw_direccion_unificada = 2;
```

**Debes ver:** 1 fila · regla = **2**.

### Query 2 — ¿quién es la persona dueña del padre?

```sql
SELECT DISTINCT
  id_buro_persona,
  cod_pin_persona,
  cod_dw_persona_ubic AS rpu
FROM bdm_datos.score_ordenamiento
WHERE cod_dw_persona_ubic = 2;
```

**Debes ver:** `id_buro_persona = 3228096126421495389` · pin `98746`.

### Query 3 — la hija NO debe tener score ni orden

```sql
SELECT 'scores_hija' AS check, COUNT(*)::BIGINT AS n
FROM bdm_datos.score_ordenamiento
WHERE cod_dw_persona_ubic = 3
UNION ALL
SELECT 'orden_hija', COUNT(*)::BIGINT
FROM bdm_datos.rpu_orden_prioridad
WHERE cod_dw_persona_ubic = 3;
```

**Debes ver:** `0` y `0`.  
Así se demuestra el puente Regla 2 → Ordenamiento: **hija fuera**.

---

# PARTE C — ORDENAMIENTO con el mismo ID

## 5. Qué hace el ordenamiento

Por canal (DIR / TEL / CEL / EMA): calcula **score** con características × **betas** (47 coefs RITM) y asigna **lugar** 1, 2, 3…  
Solo canal **DIR** escribe `orden_prioridad` en `rpu_orden_prioridad`.

## 6. Caso A — scores de la persona del HTML

```sql
SELECT
  canal,
  cod_dw_persona_ubic AS rpu,
  cod_pin_persona,
  score,
  lugar
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 3228096126421495389
ORDER BY canal, lugar;
```

**Resultado DEV (2026-09-23):**

| canal | rpu | pin | score | lugar |
|-------|----:|----:|------:|------:|
| DIR | 2 | 98746 | 639.7849 | 1 |
| TEL | 2 | 98746 | 376.5281 | 1 |
| EMA | 2 | 98746 | 281.7705 | 1 |

Interpretación:

1. Solo aparece el **padre RPU 2** (la hija 3 no está).  
2. En cada canal hay un contacto lugar 1 (en esta persona, un solo RPU con score).  
3. DIR, TEL y EMA se ordenan **por separado** (no compiten entre sí).

### Query 4 — orden_prioridad DIR

```sql
SELECT
  cod_dw_persona_ubic AS rpu,
  id_buro_persona,
  orden_prioridad,
  fecha_actualizacion
FROM bdm_datos.rpu_orden_prioridad
WHERE id_buro_persona = 3228096126421495389;
```

**Debes ver:** RPU `2` · `orden_prioridad = 1`.

---

# PARTE D — Caso B (recorre más escenarios a la vez)

Persona: **`id_buro_persona = 2848501447849812647`** · pin **`165259`**

### Paso 1 — Unificación Regla 2 (dos hijas → un padre)

```sql
SELECT
  cod_dw_persona_ubic AS hija,
  cod_dw_direccion_unificada AS padre,
  unifica_atributos AS regla,
  fecha_unificacion
FROM bdm_datos.unificacion_direccion
WHERE cod_dw_direccion_unificada = 166369
ORDER BY hija;
```

**DEV:**

| hija | padre | regla |
|-----:|------:|------:|
| 166367 | 166369 | 2 |
| 166368 | 166369 | 2 |

### Paso 2 — Ordenamiento DIR (dos ganadoras compiten)

```sql
SELECT canal, cod_dw_persona_ubic AS rpu, score, lugar
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 2848501447849812647
  AND canal = 'DIR'
ORDER BY lugar;
```

**DEV:**

| rpu | score | lugar | Rol |
|----:|------:|------:|-----|
| 166366 | 611.8280 | **1** | Ganadora “mejor” para contactar primero |
| 166369 | 599.7849 | **2** | Otra ganadora (además es padre de las hijas) |

Las hijas `166367` / `166368` **no** aparecen aquí.

### Paso 3 — orden_prioridad

```sql
SELECT cod_dw_persona_ubic AS rpu, orden_prioridad
FROM bdm_datos.rpu_orden_prioridad
WHERE id_buro_persona = 2848501447849812647
ORDER BY orden_prioridad;
```

**DEV:** `166366 → 1` · `166369 → 2`

### Paso 4 — gate hijas (debe ser 0)

```sql
SELECT COUNT(*) AS hijas_con_score
FROM bdm_datos.score_ordenamiento
WHERE cod_dw_persona_ubic IN (166367, 166368);
```

**Debes ver:** `0`.

### Paso 5 — otros canales de la misma persona

```sql
SELECT canal, cod_dw_persona_ubic AS rpu, score, lugar
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 2848501447849812647
ORDER BY canal, lugar;
```

**DEV (además de DIR):** TEL y EMA también con lugar 1 sobre RPU `166366`.

---

## 7. Recorrido guiado (copia este guión en DBeaver)

Orden recomendado de pestañas SQL:

1. Conteos por regla → ver solo R2.  
2. Caso A unificación `3 → 2`.  
3. Caso A scores + orden del `id_buro 3228096126421495389`.  
4. Confirmar hija `3` sin score.  
5. Caso B unificación hijas `166367/166368`.  
6. Caso B DIR lugares 1 y 2.  
7. Caso B hijas sin score.

Con eso corroboras:

| Afirmación | Evidencia |
|------------|-----------|
| Regla 2 une hija→padre | `3→2` y `166367/166368→166369` |
| Regla 1 no hay en esta muestra | Solo `unifica_atributos=2` |
| Ordenamiento no toca hijas | Conteos 0 sobre RPUs hijas |
| Ordenamiento ordena ganadoras | Caso B lugares 1 y 2 |
| Canales separados | DIR / TEL / EMA en queries de score |

---

## 8. Gates globales (opcional, no por ID)

```sql
-- Calidad unificación
SELECT
  SUM(CASE WHEN cod_dw_direccion_unificada IS NULL THEN 1 ELSE 0 END) AS c03,
  SUM(CASE WHEN cod_dw_persona_ubic = cod_dw_direccion_unificada THEN 1 ELSE 0 END) AS c04
FROM bdm_datos.unificacion_direccion;

-- Betas
SELECT COUNT(*) AS betas FROM bdm_datos.beta_ordenamiento;  -- 47

-- Scores por canal
SELECT canal, COUNT(*) FROM bdm_datos.score_ordenamiento GROUP BY 1 ORDER BY 1;
```

---

## 9. Frases para memorizar

1. **Regla 1:** misma puerta, distinto tipo → padre por CIIU (hoy 0 filas en DEV).  
2. **Regla 2:** busca el par **`3 → 2`** o el `id_buro` **`3228096126421495389`**.  
3. **Ordenamiento:** mismo `id_buro`; solo el padre tiene score; hijas en 0.  
4. **Caso rico:** `id_buro` **`2848501447849812647`** — dos DIR ordenadas + dos hijas R2 limpias.

---

## 10. Nota sobre el HTML antiguo

En `MAPA_UNIFICACION_EDF_VIEWS_NEGOCIO.html` el KPI traía:

- `pid: -9194362089521182288` (otra persona de drill, RPU `157771`, **sin** fila en `unificacion_direccion`)  
- `hija_rpu: 3` / `padre_rpu: 2` ← **este es el par real de Regla 2**

Para corroborar unificación + ordenamiento juntos, usa **`3228096126421495389`** (dueño del padre 2), no el `pid` suelto del KPI.

---

## 11. Dónde más mirar

| Recurso | Uso |
|---------|-----|
| `MAPA_UNIFICACION_EDF_VIEWS_NEGOCIO.html` | Volumenes / cascada visual |
| `MAPA_ORDENAMIENTO_EDF_VIEWS_NEGOCIO.html` | Fases y guión de reunión |
| `ENTREGA_QA_UNIFICACION.md` / `ENTREGA_QA_ORDENAMIENTO.md` | Entrega formal QA |

---

*Extraído y verificado en DEV 2026-09-23 · Reconocer Batch*
