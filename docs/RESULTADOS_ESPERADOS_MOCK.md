# Resultados esperados — certificación mock FULL/DELTA

> SLCOPRBA-1356. Acompaña a `deploy/redshift/SQL/seed_mock_matriz.sql`.
> Cubre **Regla 1 (ARQ 1..20)**, **Regla 2 (ARQ 21..50)** y **GEO con coordenadas (ARQ 56)**.
> Archivos: `seed_mock_matriz.sql` (R1) y `seed_mock_matriz_r2.sql` (R2 + GEO).

## Método

Las semillas se generan por **arquetipos**, no al azar. Un arquetipo es una celda
de la matriz *escenario de regla × posición respecto al Watermark*, replicada
`N` veces (N = 1000) con identificadores distintos y estructura idéntica. El
resultado esperado es por tanto exacto:

```
filas_esperadas(arquetipo) = N × filas_por_caso
```

Todo se deriva de `bdm_stage.mock_numeros.i`. **No hay `RANDOM()`**: dos
ejecuciones producen exactamente los mismos datos.

### Identificadores

| Campo | Fórmula |
|---|---|
| `id_buro_persona` | `9000000 + ARQ*10000 + i` |
| `cod_dw_persona_ubic` | `id_buro_persona*10 + k` (k = 1 padre, 2 hija) |
| `cod_dw_ubic` | `id_buro_persona*10 + 1` (compartido: mismo texto) |
| `cod_dw_direccion_fisica` | `= cod_dw_persona_ubic` |

El arquetipo se recupera con `ARQ = (id_buro_persona - 9000000) / 10000`, así que
los gates agrupan por caso sin tabla auxiliar. Estos ids no colisionan con los
reales, que son `FNV_HASH(pin)` (64 bits, típicamente negativos).

### Posiciones respecto al Watermark

El FULL siembra el Watermark con `MAX(fecha_relacion_persona_ubicaci)` = `2026-03-01`.
La ventana DELTA es entonces `fecha >= 2026-03-01 OR fecha IS NULL`.

| Posición | Semilla | Qué certifica |
|---|---|---|
| `DENTRO` | ambas fechas `2026-03-01` | caso base |
| `FUERA` | ambas `2024-01-15` | la persona queda fuera del driver |
| `NULL` | ambas NULL | el nulo es inclusivo |
| `CABALLO` | una `2026-03-01`, otra `2024-01-15` | **la ventana por persona** |
| `YA_UNIF` | fechas dentro, hija con `ind_unificacion = 1` | el incremental **por estado** del legado |

## Matriz de resultados — Regla 1

Filas en `unificacion_direccion_mock` **por réplica** (multiplicar por N):

| ARQ | Escenario | CIIU | Posición | FULL | DELTA |
|----:|---|---|---|----:|----:|
| 1 | E1 — padre LAB/CRR | `10` | DENTRO | 1 | 1 |
| 2 | E1 | `10` | FUERA | 1 | **0** |
| 3 | E1 | `10` | NULL | 1 | 1 |
| 4 | E1 | `10` | CABALLO | 1 | **1** |
| 5 | E1 | `10` | YA_UNIF | 0 | 0 |
| 6 | E2 — padre RES/CRR | `81` | DENTRO | 1 | 1 |
| 7 | E2 | `81` | FUERA | 1 | **0** |
| 8 | E2 | `81` | NULL | 1 | 1 |
| 9 | E2 | `81` | CABALLO | 1 | **1** |
| 10 | E2 | `81` | YA_UNIF | 0 | 0 |
| 11 | E3 — más entidades | `47` | DENTRO | 1 | 1 |
| 12 | E3 | `47` | FUERA | 1 | **0** |
| 13 | E3 | `47` | NULL | 1 | 1 |
| 14 | E3 | `47` | CABALLO | 1 | **1** |
| 15 | E3 | `47` | YA_UNIF | 0 | 0 |
| 16–20 | EMPATE | `10` | las 5 | 0 | 0 |

**Totales R1 con N = 1000:** FULL → **12 000** filas · DELTA → **9 000** nuevas
o re-tocadas (las 3 000 de `FUERA` sobreviven del FULL sin re-tocarse, con
`lote_actualizacion` en NULL).

### Por qué cada 0

- **`FUERA` en DELTA:** la persona no tiene ninguna relación en la ventana, así
  que no entra al driver. La fila creada por el FULL permanece intacta.
- **`YA_UNIF`:** la hija lleva `ind_unificacion = 1` y el filtro de estado del
  legado la excluye del insumo. La persona queda con una sola dirección: no hay
  pareja padre/hija.
- **`EMPATE`:** las dos direcciones empatan en score máximo y el ganador exige
  `HAVING COUNT(*) = 1`.

## Verificación previa a la ejecución

La matriz **no es una predicción**: se simuló la generación de semillas junto
con la lógica de `preparar_insumo` + los tres escenarios de R1 (score,
`ROW_NUMBER`, ganador único, emparejamiento con tipo distinto). Los 20
arquetipos arrojaron exactamente los valores de la tabla.

Además se corrió el **contrafactual** con la ventana anterior (por fila en vez
de por persona):

| ARQ | Posición | Ventana por persona | Ventana por fila |
|----:|---|---:|---:|
| 4 | CABALLO | 1 | **0** |
| 9 | CABALLO | 1 | **0** |
| 14 | CABALLO | 1 | **0** |

Es decir: los arquetipos `CABALLO` **fallarían** con el diseño anterior. La
prueba discrimina; no es una tautología.

## Canales de Ordenamiento

Cada persona recibe tres contactos colgados de su dirección **padre**:

| `contact_type` | Canal | Valor sembrado |
|---|---|---|
| `4` | TEL fijo | `601` + 7 dígitos → clasifica `VALIDA` |
| `9` | CEL | `310` + 7 dígitos → resuelve operador |
| `10` | EMA | `mock<id>@gmail.com` → dominio `PERSONAL` |

Como el Ordenamiento solo toma canales de personas con al menos una RPU no-hija
(`stg_persona_dir_ganadora`), estos contactos entran al scoring de TEL/CEL/EMA.

## GEO

Todas las ubicaciones se siembran con `latitud`/`longitud` en NULL, de modo que
son `Ubicacion_Candidata` para el Exportador_GEO. El arquetipo con coordenadas
(ARQ 56, que **no** debe generar candidato) se sembrará junto con R2.

Comportamiento esperado del ciclo GEO mock:

| Corrida | Candidatos | Lote |
|---|---|---|
| FULL | 20 000 ubicaciones | lote 1, queda `fallido` (UNLOAD sin rol IAM) |
| DELTA | **0** | no se crea lote: el 1 no está `cargado` (Req 1.5) |

El fallo del UNLOAD es **resultado esperado**, no defecto: no es bloqueante y el
flujo continúa con R1+R2 hacia Ordenamiento.


## Matriz de resultados — Regla 2

Los seis escenarios de R2 forman una **cascada con estado compartido**: se
ejecutan en orden `esc1 → esc2 → esc3 → esc4 → esc5 → esc6` sobre
`stg_mock_regla2_e2`, cada uno leyendo solo las filas en `ind_unificacion = 'N'`
—lo que los anteriores no consumieron— y marcando `'S'` lo que toma. Por eso
cada arquetipo está diseñado para ser **inmune a todos los escenarios previos**.

Predicado base común: misma persona, mismo `texto_ubicacion`, **mismo
`cod_dw_tipo_ubicacion_dir`**, mismo municipio, distinto `cod_dw_persona_ubic`.
R2 exige el tipo **igual**, al revés que R1 que lo exige **distinto**: por eso
todas las direcciones de R2 usan RES, lo que por sí solo las hace inmunes a R1.

| ARQ | Escenario | Semilla | Blindaje frente a los anteriores |
|----:|---|---|---|
| 21–25 | E1 vía `esc1` | `'AP 301'` / `''` | primero en la cadena |
| 26–30 | E2 vía `esc2` | `'TO 1 AP 502'` / `'TO 1'` | ambos complementos no vacíos |
| 31–35 | E3 vía `esc3` | `'AP 201'` / `'AP 202'`, sin NIT | ninguno es substring del otro |
| 36–40 | E4 vía `esc4` | `'OF 301 TO 2'` (conteo 2) / `'LC 2'` (conteo 1), con NIT | nomenclaturas distintas **y** NIT |
| 41–45 | E5 vía `esc5` | `'BR 5'` (nivel 1) / `'AP 301'` (nivel 7), con NIT | ambos tokens están en el catálogo y aparecen una sola vez → conteo 1 y 1 → empate → `esc4` exige ganador único |
| 46–50 | E6 vía `esc6` | `'CA 1 LT 2'` (5) / `'CA 3 LT 4'` (5) / `'CA 9'` (3), con NIT | empate en el máximo → `esc4` no dispara; las tres arrancan con `CA` (mismo nivel) → `esc5` tampoco |
| 51–55 | E7 vía `esc5`, certifica el **motor** | `'BR 5'` (padre, nivel 1) / `'AP 301 TO 2'` / `'AP 302 CS 4'` (hijos, los dos nivel 7), con NIT | empate en el máximo (3 y 3) → `esc4` no dispara; los dos hijos comparten token inicial `AP`, así que `esc5` solo los empareja contra `'BR 5'` y el padre queda **determinista** |

Filas por réplica:

| Escenario | DENTRO | FUERA | NULL | CABALLO | YA_UNIF |
|---|---:|---:|---:|---:|---:|
| E1 · E2 · E3 · E4 · E5 | 1 | 1 / **0** | 1 | 1 | 0 |
| E6 | **2** | 2 / **0** | 2 | 2 | 0 |
| E7 | 1 | 1 / **0** | 1 | 1 | **1** |

*(FULL / DELTA donde difieren)*

E7 es el único arquetipo en que `YA_UNIF` **sí** produce fila: tiene tres
direcciones, así que excluir la hija deja todavía un par y `esc5` sigue
disparando. En los demás el grupo se queda sin pareja.

**Totales R2 con N = 1000:** FULL → **33 000** filas · DELTA → **25 000**.

> El total anterior (35 000 / 28 000) no concordaba con esta misma tabla:
> contaba `YA_UNIF` como productiva (5 familias × 1 + E6 × 2 = 7 por réplica,
> los 7 000 de diferencia). Se corrigió al recalcularlo para añadir E7.

### Direcciones generadas por el motor

Tabla aparte: `bdm_datos.direccion_fisica_generada_mock` y
`bdm_datos.rpu_generada_mock`. Una dirección **por padre**, no por par ni por
grupo. La población del motor son los pares que marcaron `esc3` (`n_id = 'L3'`)
y `esc5` (`n_id = 'E5'`), que son los dos únicos sitios donde el legado crea
direcciones (`PRO_UnificacionR2.sql:1602` y `:3423`).

| Escenario | complemento generado | DENTRO | FUERA | NULL | CABALLO | YA_UNIF |
|---|---|---:|---:|---:|---:|---:|
| E5 | `'BR 5 AP 301'` | 1 | 1 / **0** | 1 | 1 | 0 |
| E7 | `'BR 5 TO 2 CS 4 AP 301'` | 1 | 1 / **0** | 1 | 1 | **1** |
| E1 · E2 · E3 · E4 · E6 | — | 0 | 0 | 0 | 0 | 0 |

E3 está en la población (`esc3` marca `'L3'`) pero **no genera**: sus dos
complementos tienen el mismo `nomen` (`AP`), así que el hijo no aporta ningún
componente nuevo. E6 no está en la población, igual que en el legado, donde la
cadena `E06` no contiene `MAX_ID`.

En `YA_UNIF` de E7 el hijo excluido es `'AP 302 CS 4'`, así que desaparece el
aporte de `CS`: el complemento generado es `'BR 5 TO 2 AP 301'`.

**Totales motor con N = 1000:** FULL → **9 000** · DELTA → **7 000**.

### Dos hallazgos del diseño

**1. Con grupos de dos direcciones el escenario 6 es inalcanzable.** `esc4` y
`esc6` leen la **misma** fuente de frecuencia. Con dos direcciones de frecuencia
distinta, `esc4` siempre encuentra un máximo único y dispara primero; con
frecuencias iguales, `esc6` tampoco dispara (`fa.freq > fb.freq` es falso). Para
alcanzarlo hace falta un empate arriba y alguien por debajo — de ahí las tres
direcciones del arquetipo E6.

**2. El escenario 6 produce una hija con varios padres.** Como empareja la de
menor frecuencia contra **cada** una de las empatadas, E6 genera 2 filas. No es
un defecto de la semilla: es el comportamiento del escenario, y queda
documentado como resultado esperado.

## ARQ 51–55 — E7, el arquetipo del motor

Antes no se sembraban porque el motor era **inobservable**: se quedaba en
tablas de staging que nadie consumía y no escribía en ninguna tabla
certificable. Ya no: persiste en `direccion_fisica_generada_mock` y
`rpu_generada_mock`, con el UPSERT del legado.

El arquetipo está construido para que el padre sea **determinista**. Con tres
niveles distintos no lo sería: `'BR 5'` / `'TO 2'` / `'AP 301'` genera los pares
`(BR,TO)`, `(BR,AP)` y `(TO,AP)`, y como el `UPDATE` de `esc5` lleva
`AND id_padre IS NULL`, el padre de `AP` depende de cuál fila gane primero. Al
dar a los dos hijos el mismo token inicial (`AP`) solo se emparejan contra
`'BR 5'`, porque `esc5` exige `a.nomenclatura_pri <> b.nomenclatura_pri`.

Lo que certifica, en un solo arquetipo:

| | |
|---|---|
| Un padre con **varios** hijos | el legado agrupa por padre y agrega todos sus hijos |
| Deduplicación por `nomen` | `AP` lo aportan los **dos** hijos; se conserva uno, el del hijo de menor `cod_dw_persona_ubic` |
| Orden por `nivel_complemento` | `TO`(4) → `CS`(5) → `AP`(7) |
| El complemento del padre se **conserva** | `'BR 5'` encabeza, no se re-ordena todo |

## ARQ 56 — GEO con coordenadas

Control negativo del Exportador_GEO: misma forma que E1 (unifica vía `esc1`,
1 fila por réplica) pero su ubicación trae `latitud`/`longitud`. **No debe
generar `Ubicacion_Candidata`**, porque el predicado exige
`sin fila en geo_atributos OR latitud IS NULL OR longitud IS NULL`.

## Verificación de la Regla 2

La matriz de R2 tampoco es una predicción. Se simuló la **cascada completa**
—los seis escenarios en orden, con su tabla de trabajo y su marcado de estado—
sobre los 35 arquetipos en FULL y en DELTA. Cada arquetipo resultó consumido por
el escenario previsto (`vía esc1`… `vía esc6`), sin que ninguno fuera capturado
por un escenario anterior.

## Totales de la batería

| | FULL | DELTA |
|---|---:|---:|
| Regla 1 (ARQ 1–20) | 12 000 | 9 000 |
| Regla 2 (ARQ 21–55) | 33 000 | 25 000 |
| GEO coords (ARQ 56) | 1 000 | 1 000 |
| **Total `unificacion_direccion`** | **46 000** | **35 000** |
| Direcciones generadas por el motor | 9 000 | 7 000 |

Personas sembradas: **56 000**. Relaciones: **122 000**.

## Gate de convergencia (M5)

`run_unif_convergencia_mock.sql` corre la secuencia **FULL → DELTA1 → DELTA2 →
FULL2**, toma una huella del estado tras cada corrida y deja el veredicto en
`bdm_stage.mock_unif_ca_result`. La cuarta corrida es un FULL de *reproceso* a
propósito: es la única que detecta si el FULL parte de un insumo limpio.

| Criterio | Qué comprueba |
|---|---|
| `CA-C01` | El FULL es reproducible: `FULL2` reconstruye el estado de `FULL` |
| `CA-C02` | Convergencia de `unificacion_direccion_mock`: `DELTA2` = `DELTA1` |
| `CA-C03` | Convergencia de `direccion_fisica_generada_mock` |
| `CA-C04` | Convergencia de `rpu_generada_mock` |
| `CA-C05` | Sin cascada: las direcciones generadas no crecen entre DELTAs |
| `CA-C06` | **Un hijo, un padre**: ningún `cod_dw_persona_ubic` con dos padres |
| `CA-C07` | **Sin padres huérfanos**: todo padre existe como relación |
| `CA-C08` | La DELTA no altera el estado del FULL: `DELTA1` = `FULL` |

### Lo que el gate reporta hoy, y por qué

El motor persiste la dirección generada con `ind_unificacion` en NULL, y las
vistas de insumo la exponen con `UNION ALL`. Por lo tanto **vuelve a entrar al
insumo de la corrida siguiente**. El legado lo tolera porque al final de la
carga marca los hijos con `IND_UNIFICACION = 1` sobre la tabla real
(`P0020_UNIFICACION_DIRECCION_130.TPT`, quinta pasada, líneas 281‑292) y el
filtro de estado del insumo los saca para siempre. En Redshift **no se puede**:
el datashare es de solo lectura y las vistas exponen `ind_unificacion` como
`CAST(NULL AS INTEGER)` fijo.

Simulación de la cascada completa sobre E7 (`'BR 5'` padre, `'AP 301 TO 2'` y
`'AP 302 CS 4'` hijos):

| Corrida | `unificacion_direccion` | Genera |
|---|---|---|
| FULL | `u2→u1`, `u3→u1` | `'BR 5 TO 2 CS 4 AP 301'` |
| DELTA1 | `u1→G`, `u2→G`, `u3→G` | nada |
| DELTA2 | igual que DELTA1 | nada |

En DELTA1 la dirección **generada se vuelve el padre**: `esc2` captura a
`'BR 5'` porque es substring del complemento generado, y `esc4` captura a los
otros dos porque el generado tiene el conteo máximo — su complemento contiene
*todos* los tokens del grupo.

De ahí tres consecuencias medibles:

1. **Padres duplicados** (`CA-C06`). La Clave_Unificacion es el **par**
   `(cod_dw_persona_ubic, cod_dw_direccion_unificada)`, así que el UPSERT no
   impide que una dirección acabe con dos padres: basta que una corrida
   posterior le asigne otro. Tras DELTA1, `u2` y `u3` tienen `u1` **y** `G`.
2. **El estado estable no es el del FULL** (`CA-C08`). Converge en dos
   corridas, pero al estado «todo → G».
3. **Padres huérfanos** (`CA-C07`, `CA-C01`). Un FULL de reproceso ya no
   regenera la dirección —su insumo contiene `G`, `esc2`/`esc4` la capturan y
   `esc5` nunca dispara— así que el motor borra y no reinserta, y
   `unificacion_direccion` queda apuntando a una dirección que ya no existe.

Estos fallos **no son del gate: son el hallazgo**. El gate se escribió para
medirlos en vez de suponerlos.

Como parte de M5 sí se corrigió la **secuencia** del FULL: el borrado del
histórico de direcciones generadas pasó del motor (que corre al final) al paso 6
del orquestador, antes de preparar el insumo. Mientras vivía en el motor, el
insumo del propio FULL alcanzaba a ver las generadas de la corrida anterior, de
modo que un FULL nunca era un reproceso limpio.

## Pendiente

- Scripts `reset_mock` y gates de validación restantes (fase 5).
- **Decisión funcional sobre la realimentación.** Tres opciones, de menor a
  mayor fidelidad:
  1. Excluir las direcciones generadas del insumo (`generada_enriquecida = 1`
     fuera). Hace todo idempotente y el estado estable pasa a ser el del FULL,
     al coste de no unificar nunca el padre contra la dirección generada.
  2. Reconstruir el marcado de estado del legado en una **tabla propia**
     (`unif_estado_rpu`), que el insumo consulta en lugar del `ind_unificacion`
     del datashare. Es literalmente la quinta pasada del TPT reubicada. Es la
     opción fiel, pero cambia la semántica DELTA de **todos** los arquetipos:
     tras un FULL los hijos salen del insumo, así que un DELTA inmediato daría
     ~0 filas nuevas y habría que re-derivar la matriz de certificación.
  3. Dejarlo como está y documentarlo. No recomendable: `CA-C06` y `CA-C07`
     describen corrupción acumulativa, no una diferencia cosmética.
