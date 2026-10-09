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
| 36–40 | E4 vía `esc4` | `'OF 301'` (frec 9) / `'LC 2'` (frec 1), con NIT | nomenclaturas distintas **y** NIT |
| 41–45 | E5 vía `esc5` | `'BR 5'` (nivel 1) / `'AP 301'` (nivel 7), con NIT, **sin diccionario** | conteo 0 en ambos → empate → `esc4` exige ganador único |
| 46–50 | E6 vía `esc6` | `'ZA 1'` (10) / `'ZA 2'` (10) / `'ZB 9'` (3), con NIT | empate en el máximo → `esc4` no dispara; `ZA`/`ZB` fuera del catálogo → `esc5` tampoco |

Filas por réplica:

| Escenario | DENTRO | FUERA | NULL | CABALLO | YA_UNIF |
|---|---:|---:|---:|---:|---:|
| E1 · E2 · E3 · E4 · E5 | 1 | 1 / **0** | 1 | 1 | 0 |
| E6 | **2** | 2 / **0** | 2 | 2 | 0 |

*(FULL / DELTA donde difieren)*

**Totales R2 con N = 1000:** FULL → **35 000** filas · DELTA → **28 000**.

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

## ARQ 51–55 — no se siembran

Estaban reservados para el motor
(`sp_unificacion_mock_r2_motor_nit_empates_nuevas_direcciones`). Ese SP solo
construye tres tablas de staging (`stg_mock_motor_keys` / `_ranked` / `_insumo`)
que **nadie consume**: las únicas otras referencias en los tres repos son los
`DROP TABLE` del propio orquestador de Regla 2. No escribe en
`unificacion_direccion` ni en ninguna otra tabla observable.

**No hay resultado que certificar.** Queda como hallazgo para el equipo
funcional: el motor de nuevas direcciones está desconectado, en real y en mock.

## ARQ 56 — GEO con coordenadas

Control negativo del Exportador_GEO: misma forma que E1 (unifica vía `esc1`,
1 fila por réplica) pero su ubicación trae `latitud`/`longitud`. **No debe
generar `Ubicacion_Candidata`**, porque el predicado exige
`sin fila en geo_atributos OR latitud IS NULL OR longitud IS NULL`.

## Verificación de la Regla 2

La matriz de R2 tampoco es una predicción. Se simuló la **cascada completa**
—los seis escenarios en orden, con su tabla de trabajo y su marcado de estado—
sobre los 30 arquetipos en FULL y en DELTA. Cada arquetipo resultó consumido por
el escenario previsto (`vía esc1`… `vía esc6`), sin que ninguno fuera capturado
por un escenario anterior.

## Totales de la batería

| | FULL | DELTA |
|---|---:|---:|
| Regla 1 (ARQ 1–20) | 12 000 | 9 000 |
| Regla 2 (ARQ 21–50) | 35 000 | 28 000 |
| GEO coords (ARQ 56) | 1 000 | 1 000 |
| **Total** | **48 000** | **38 000** |

Personas sembradas: **51 000**. Relaciones: **107 000**.

## Pendiente

- Scripts `run_*`, `reset_mock` y gates de validación (fase 5).
- El motor de nuevas direcciones (ARQ 51–55) sigue sin cubrir mientras no se
  conecte su salida.
