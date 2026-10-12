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

| ARQ | Escenario | CIIU | Posición | FULL | DELTA *(pre‑M7)* |
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

**Totales R1 con N = 1000:** FULL → **12 000** filas · DELTA → **0 nuevas**.

> La columna `DELTA` de la tabla describe el comportamiento **anterior a M7**,
> cuando la vista exponía `ind_unificacion` como constante NULL y el filtro de
> estado no filtraba nada, así que cada DELTA re-procesaba lo ya unificado. Se
> conserva porque documenta justo el defecto que M7 corrige. Desde M7 un DELTA
> sobre datos sin cambios no produce filas nuevas ni re-toca las existentes.

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
| 51–55 | E7 vía **`X4`**, certifica el **motor** | `'TO 2 CS 4'` (padre) / `'TO 9 AP 1'` / `'TO 7 AP 1'` (hijas), las tres con `TO` inicial y con NIT | corre antes de `esc4`; ningún complemento es substring de otro, así que `esc2` no los consume |

> **`esc3` exige `ID` distinto entre las dos direcciones.** Elige al padre con
> `A.ID > B.ID` (comparación **estricta**, `Tmp_Unificacion_E03_E1`, línea 607
> de `PRO_UnificacionR2.sql`), donde
>
> ```
> ID = fecha_relacion_como_numero + numero_entidades_reportan + 10000000
> ```
>
> Una fecha y un día más pesan lo mismo que una entidad reportando más: ambos
> suman 1. Con un empate perfecto de `ID` la desigualdad falla en los dos
> sentidos y **no se forma par** — comportamiento legítimo del legado, que
> además calcula `COUNT_EMPATE` / `EMPATE` para detectarlo y deja el
> `QUALIFY EMPATE=1` comentado.
>
> Por eso la semilla le da al padre de estos arquetipos (`k = 1`, `'AP 201'`)
> una **segunda entidad reportando**. Sin ella, DENTRO, FUERA y NULL comparten
> fecha, los `ID` quedan idénticos y `esc3` no dispara: así salieron 0 en el
> job #302, mientras CABALLO —la única posición con fechas distintas— sí
> unificaba. El empate perfecto es un caso real que vale certificar, pero con
> su propio arquetipo; estas cuatro posiciones existen para probar la
> **ventana**, no el desempate.

Filas por réplica:

| Escenario | DENTRO | FUERA | NULL | CABALLO | YA_UNIF |
|---|---:|---:|---:|---:|---:|
| E1 · E2 · E3 · E4 · E5 | 1 | 1 | 1 | 1 | 0 |
| E6 | **1** | 1 | 1 | 1 | 0 |
| E7 | **3** | 3 | 3 | 3 | **2** |

*(filas del **FULL**. El DELTA sobre datos sin cambios da 0 en todas las
posiciones desde M7 — ver la nota de abajo. `FUERA` daba 0 en el DELTA incluso
antes, porque esa persona no entra a la ventana.)*

E7 produce **tres** filas porque el motor unifica el grupo completo contra la
dirección generada, **el padre incluido** — eso es textual del legado. Y es el
único arquetipo en que `YA_UNIF` sí produce fila: tiene tres direcciones, así
que excluir la hija deja todavía un par. En los demás el grupo se queda sin
pareja.

**Totales R2 con N = 1000:** FULL → **42 000** filas · DELTA → **0 nuevas**.

> ### El DELTA ahora da cero, y está bien
>
> Hasta M7 la vista de insumo exponía `ind_unificacion` como
> `CAST(NULL AS INTEGER)`, es decir «nada está unificado nunca», así que el
> filtro de estado del legado (`ind_unificacion IS NULL`) no filtraba nada y
> **cada DELTA re-procesaba todo**. De ahí los 32 000.
>
> Con el estado derivado de `unificacion_direccion_mock`, un DELTA sobre datos
> **sin cambios** no tiene nada que hacer: las hijas que unificó el FULL quedan
> excluidas y los padres se quedan sin pareja. Arquetipo por arquetipo:
>
> | | Qué queda en el insumo del DELTA | Filas nuevas |
> |---|---|---:|
> | E1 · E2 · E3 · E4 · E5 | solo el padre, sin pareja | 0 |
> | E6 | las dos empatadas; nadie por debajo, así que `esc6` no dispara | 0 |
> | E7 | **nada**: el motor unificó el grupo completo, el padre incluido | 0 |
>
> Eso **es** la semántica de un incremental, y por sí misma es una afirmación
> que vale certificar: *un DELTA sobre datos que no cambiaron no produce filas
> nuevas ni des-unifica nada*.
>
> **Consecuencia para la fase 5:** para certificar el DELTA con algo más que
> cero, la batería necesita un paso de **mutación** entre el FULL y el DELTA —
> una dirección nueva que llega, o el complemento de una que cambia. Sin eso el
> `run_*_full_delta` solo puede probar idempotencia, no incrementalidad. Es el
> insumo principal del diseño de la fase 5.

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
| E7 | `'TO 2 CS 4 AP 1'` | 1 | 1 / **0** | 1 | 1 | **1** |
| los demás | — | 0 | 0 | 0 | 0 | 0 |

**E6 no genera**, y la razón es `MDIR`: el padre es `'CA 1 LT 2'` (la más rica),
y ni `'CA 3 LT 4'` ni `'CA 9'` le aportan un componente que no tenga. Los
hijos no aportan **ningún** componente que el padre no tenga, así que no se crea
dirección *ni se marca*, y el grupo sigue su camino hasta `esc6` como antes.
**E4 y E5** no entran porque sus nomenclaturas iniciales difieren (`OF`/`LC`,
`BR`/`AP`). **E1, E2, E3** no llevan NIT.

En `YA_UNIF` de E7 la hija excluida es `'TO 7 AP 1'`, que solo aportaba `AP 1`
duplicado: el complemento generado **no cambia**, `'TO 2 CS 4 AP 1'`. Lo que baja
es el número de filas de unificación, de tres a dos.

**Totales motor con N = 1000:** FULL → **5 000** · DELTA → **0 nuevas**
(la direccion generada ya existe y su clave es determinista, así que el UPSERT
la actualizaría; pero el grupo ya está unificado y no vuelve al insumo).

### Dos hallazgos del diseño

**1. Con grupos de dos direcciones el escenario 6 es inalcanzable.** `esc4` y
`esc6` leen la **misma** fuente de frecuencia. Con dos direcciones de frecuencia
distinta, `esc4` siempre encuentra un máximo único y dispara primero; con
frecuencias iguales, `esc6` tampoco dispara (`fa.freq > fb.freq` es falso). Para
alcanzarlo hace falta un empate arriba y alguien por debajo — de ahí las tres
direcciones del arquetipo E6.

**2. El escenario 6 producía una hija con varios padres — y era un defecto.**
Como emparejaba la de menor frecuencia contra **cada** una de las empatadas, E6
generaba 2 filas con `'CA 9'` apuntando a dos padres a la vez. Durante un tiempo
esto se documentó aquí como «el comportamiento del escenario»; no lo era. El
conteo salía bien y la **forma** estaba mal, y por eso `CA-U01` no lo veía
mientras `CA-U05` sí. `SLCOPRBA-1355 (C)` lo reduce a **un** padre por hija, de
modo que E6 produce **1** fila.

Lo que queda abierto es con qué criterio el legado rompe el empate 5/5. La
frecuencia no lo rompe, y el `esc6` del legado no es un escenario de
emparejamiento sino el **sitio 2** de creación de direcciones
(`Tmp_Unificacion_E061_D` empareja con `T1.ID > T2.ID` y su `ID_PADRE` lleva el
marcador `/*#6*/` del secuenciador `MAX_ID`). Hasta decodificar ese pivote, E6
mide una fila consistente y el gate declara que falta la otra.

## ARQ 51–55 — E7, el arquetipo del motor

Antes no se sembraban porque el motor era **inobservable**: se quedaba en tablas
de staging que nadie consumía. Ya no: crea la dirección, unifica el grupo contra
ella y marca `X4`.

E7 ejercita el **sitio 1** del legado (`PRO_UnificacionR2.sql:1602`, etapa 3),
cuya población es `Tmp_Unificacion_E031` (línea 650) más el auto-join de
`Tmp_Unificacion_E03_B` (línea 703): **con NIT**, mismo grupo, complemento
distinto y **misma nomenclatura inicial**. Es el complemento exacto de `esc3`,
que resuelve «sin NIT, misma nomenclatura» uniendo contra un padre real.

### Quién es el padre: `MDIR`, no la fecha

`Tmp_Unificacion_E031_codigo` (línea 1491) — de donde sale `COMPLEMENTO_PADRE` —
se arma `FROM Tmp_Unificacion_E051_P` (el padre) `LEFT JOIN
Tmp_Unificacion_E051_H` (la hija), y `E051_P` (línea 1337) es
`ROW_NUMBER() OVER (… ORDER BY MDIR, ORDEN) = 1`: **`MDIR` primero**, y `ORDEN`
—la fecha combinada con `Numero_entidades_que_Reportan`, línea 712— solo como
desempate.

`MDIR` (línea 891, *«ID para identificar la dirección de mayor jerarquía»*) sale
del SQL dinámico de `Tmp_Unificacion_E03_Bx`, que pivota los componentes de cada
dirección y ordena **ascendente** por el nivel del 1.º componente más bajo, el
del 2.º, el del 3.º…, **rellenando con 99** los slots que la dirección no tiene.
El relleno con 99 manda al final a las direcciones con **pocos** componentes, de
modo que `MDIR = 1` es la que tiene **más** componentes y de nivel **más bajo**:
la más **rica**.

> **Este arquetipo se reconstruyó por eso.** Hasta `SLCOPRBA-1355` era
> `'AP 9'` (padre) / `'AP 301 TO 2 CS 4'` / `'AP 302 TO 5'`, sobre la premisa de
> que el padre es el complemento más **pobre** y las hijas lo enriquecen. Con
> `MDIR` leído bien el padre habría sido `'AP 301 TO 2 CS 4'` —la más rica— y
> entonces **ninguna hija puede aportarle nada**: el motor no generaría nunca y
> el arquetipo no certificaría nada. Un arquetipo del motor necesita al padre
> arriba en la jerarquía **y** una hija con un componente que al padre le falte.
>
> El job **#305** lo mostró en los datos: con el orden invertido el padre de E6
> pasaba a ser `'CA 9'`, sus hijas aportaban `LT`, E6 entraba al motor y generaba
> 4 000 direcciones que no le corresponden (ARQ 46–49 a 3 000 filas, total
> 59 000 en vez de 51 000).

Ningún complemento del arquetipo es substring de otro, de modo que `esc2` no se
los come antes de llegar al motor.

Lo que certifica, en un solo arquetipo:

| | |
|---|---|
| Catálogo de niveles | `TO`=4 · `CS`=5 · `AP`=7 |
| El padre es el de **mayor jerarquía** | `'TO 2 CS 4'` → niveles (4,5,99); las hijas (4,7,99) |
| Un padre con **varias** hijas | el legado agrupa por padre y agrega todas sus hijas |
| Deduplicación por `nomen` | `AP` lo aportan las **dos** hijas; se conserva uno |
| El resultado **no depende del desempate** | las dos aportan `AP 1`, el mismo valor |
| El complemento del padre se **conserva** | `'TO 2 CS 4'` encabeza, no se re-ordena todo |
| **El padre también se unifica** | las tres filas apuntan a la generada, no solo los hijos |

### Sitio 2 del legado (`A6`) — no implementado

El legado tiene un **segundo** sitio de creación (`:3423`, etapa 5.1). Su
población base está leída (`Tmp_Unificacion_E051`, línea 2280: grupo sin
unificar con complemento distinto, **sin** filtro de NIT ni de nomenclatura),
pero **no la regla con que elige al padre**: eso vive en el pivote dinámico de
`E051_A`/`E051_D` (líneas 2331‑2900), que genera SQL dinámico sobre hasta 15
posiciones de componente.

No se implementó por analogía con `esc5` por dos razones: sería una suposición,
y además *starvaría* a `esc5` —misma población, el sitio 2 corre antes— lo que
cambiaría el resultado de arquetipos ya certificados. Queda pendiente hasta
decodificar ese pivote.

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
| Regla 2 (ARQ 21–55) | 42 000 | 0 |
| GEO coords (ARQ 56) | 1 000 | 0 |
| **Total `unificacion_direccion`** | **51 000** | **0 nuevas** |
| Direcciones generadas por el motor | 5 000 | 0 nuevas |

La columna DELTA es cero **por diseño** desde M7: ver la nota de la sección de
Regla 2. Para que el DELTA mida incrementalidad hace falta mutar datos entre las
dos corridas.

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

### Lo que el gate predice tras M6

El motor persiste la dirección generada con `ind_unificacion` en NULL, y las
vistas de insumo la exponen con `UNION ALL`, así que **vuelve a entrar al insumo
de la corrida siguiente**. El legado lo neutraliza marcando los hijos con
`IND_UNIFICACION = 1` sobre la tabla real
(`P0020_UNIFICACION_DIRECCION_130.TPT`, quinta pasada, líneas 281‑292). En
Redshift no se puede: el datashare es de solo lectura y las vistas exponen
`ind_unificacion` como `CAST(NULL AS INTEGER)` fijo.

Aun así el ciclo converge, y la razón es M6. Simulación sobre E7:

| Corrida | `unificacion_direccion` | Tabla acumulada | Hijos con dos padres |
|---|---|---|---|
| FULL | `u1→G`, `u2→G`, `u3→G` (`X4`) | 3 filas | ninguno |
| DELTA1 | `u1→G` (`K2`) — **el mismo par** | sin cambios | ninguno |
| DELTA2 | idéntico a DELTA1 | sin cambios | ninguno |

Al escribir el parentesco en la corrida 1, lo único que la corrida 2 puede hacer
es **re-derivar el mismo par** (`esc2` captura al padre porque su complemento es
substring del generado, y es exactamente el par que el motor ya escribió), de
modo que el UPSERT **actualiza** en vez de insertar. Antes de M6 el motor no
escribía nada y la corrida 2 descubría un parentesco *distinto* del de la FULL:
como la Clave_Unificacion es el **par**, ambos coexistían y la misma dirección
acababa con dos padres.

Se espera entonces que los ocho criterios pasen. `CA-C01` (el FULL es
reproducible) depende además de la corrección de **secuencia** de M5: el borrado
del histórico de direcciones generadas pasó del motor —que corre al final— al
paso 6 del orquestador, antes de preparar el insumo. Mientras vivía en el motor,
el insumo del propio FULL veía las generadas de la corrida anterior y un FULL
nunca era un reproceso limpio.

Esto es una **predicción por simulación**, no una medición: el gate hay que
correrlo en el clúster.

## La batería (fase 5)

`run_reconocer_e2e_mock_full_delta.sql` corre la secuencia completa y deja el
veredicto en `bdm_stage.mock_unif_ca_result`. Es auto-contenido: resetea salidas
y control, y asume el insumo ya sembrado por `seed_mock_matriz*.sql`.

| Paso | Lote | Qué prueba |
|---|---:|---|
| **1. FULL** | 1356601 | la matriz completa, arquetipo por arquetipo |
| **2. DELTA** sin mutar | 1356602 | **idempotencia**: 0 filas nuevas |
| **3. Mutación** | — | llega una dirección nueva a 100 personas del ARQ 21 y 100 del ARQ 22 |
| **4. DELTA** mutado | 1356604 | **incrementalidad**: exactamente 200 filas nuevas |

### Los gates

`sp_unificacion_mock_gate_arq(p_fase, p_lote)` compara contra la matriz de este
documento. La matriz va **codificada explícitamente** en el SP, los 56
arquetipos uno por uno: un gate de certificación se audita leyéndolo, no
deduciéndolo.

| Criterio | Qué comprueba |
|---|---|
| `FULL/CA-U01` | el conteo de **cada** ARQ coincide con la matriz |
| `FULL/CA-U02` | total = 51 000 |
| `FULL/CA-U03` | 5 000 direcciones generadas, todas con `generada_enriquecida = 1` |
| `FULL/CA-U04` | el complemento generado de E7 es `'TO 2 CS 4 AP 1'` |
| `DELTA1/CA-U07` | 0 filas nuevas sobre datos sin cambios |
| `DELTA2/CA-U08` | 100 en ARQ 21 + 100 en ARQ 22 = 200 |
| `DELTA2/CA-U09` | **contrafáctico del Diseño 2** (ver abajo) |
| `DELTA2/CA-U10` | total = 51 200, nada del FULL se re-escribió |
| `*/CA-U05` | un hijo, un padre |
| `*/CA-U06` | sin padres huérfanos |

`CA-U04` es el que distingue «el motor corrió» de «el motor fusionó bien»: lleva
el complemento del padre al frente y el aporte de las hijas deduplicado.

### Lo que `CA-U08`/`CA-U09`/`CA-U10` acabaron encontrando

Los tres estuvieron en rojo desde el job **#302** hasta el **#307**: el DELTA2
daba **0** filas en vez de 200. No eran tres defectos, era uno, y no estaba en
el DELTA.

El insumo de las Reglas 1 y 2 unía `reporte_relacion_persona_ubica` con **`INNER
JOIN`**. Una dirección **sin ninguna entidad que la reporte** quedaba fuera del
insumo y no podía unificarse nunca — ni en FULL ni en DELTA, ni en esa corrida
ni en las siguientes. No daba error: daba cero, en silencio.

El paso de mutación no le siembra reporte a las 200 direcciones nuevas, porque
el escenario 1 no mira entidades. Eso las hacía invisibles. Y la huella quedaba
en `unif_control`, a la vista: la persona **sí** entraba al driver —que lee la
vista sin ese join— de modo que `personas_distintas` subía 100 y
`relaciones_entrada` 300, mientras `total_unificaciones` seguía en 0. El dato
entraba y no se unificaba.

**El legado trata el conteo como nullable**, y por tanto admite la dirección sin
reporte: en `PRO_UnificacionR2.sql` todo uso aritmético de
`Numero_entidades_que_Reportan` va envuelto en `COALESCE(...,0)` —líneas 531 y
712, que son la fórmula del `ID` que ordena `ORDEN` y desempata al padre del
motor— y las direcciones que el propio proceso crea se insertan con
`CAST(NULL AS INTEGER)` en esa columna (líneas 1679, 1701, 1725, 3507, 3529).

`SLCOPRBA-1355` lo pasó a `LEFT JOIN` en los cuatro insumos (R1 y R2, real y
mock). El `COALESCE(COUNT(DISTINCT …), 0)` que ya estaba escrito lo delataba:
con un `INNER JOIN` ese conteo nunca puede ser 0, así que era código muerto —
la agregación estaba escrita para un `LEFT JOIN` y el join no.

> **Lo que importa de esto no es el mock.** En datos reales toda dirección sin
> entidad reportante estaba excluida de las Reglas 1 y 2. Entre ellas, las que
> el **motor** crea: `rpu_generada` nace sin fila de reporte, de modo que la
> dirección fusionada no volvía a entrar al insumo nunca.

Dejar esas 200 direcciones sin reporte es lo que convierte a estos tres
criterios en la **prueba de regresión** del defecto: si alguien vuelve a poner
`INNER`, los tres caen.

### Por qué la mutación toca el ARQ 22 y no solo el 21

El `ARQ 21` es la posición `DENTRO`: su fecha ya cae en la ventana, así que
entraría al DELTA de todos modos. El `ARQ 22` es `FUERA` (2024‑01‑15): queda
fuera y entra **solo porque le llegó algo nuevo** (2026‑06‑15, posterior al
watermark 2026‑03‑01 que dejó el FULL). Al entrar **arrastra consigo al padre**,
que sigue con la fecha vieja.

Con una ventana por **fila** el padre no entraría, la dirección nueva se
quedaría sin pareja y el ARQ 22 daría 0. Que dé 100 es el contrafáctico que
prueba que el driver es por **persona** — el Diseño 2.

El complemento de la dirección nueva es vacío a propósito: dispara el
escenario 1, el primero de la cascada, así que el resultado esperado no depende
de ningún otro escenario.

## Pendiente

- **Correr la batería en el clúster.** Todo lo anterior está verificado por
  simulación, no por ejecución: paréntesis, `$$`, encoding, espejo real↔mock y
  paridad de manifiestos. Eso no es un parser ni un motor.
- **Ordenamiento**: su matriz quedó obsoleta. Desde M2 consume las direcciones
  que genera el motor (`v_mock_relacion_persona_ubicacion` las une con
  `UNION ALL`) y nadie ha derivado el efecto sobre el scoring y el orden.
- **Sitio 2 del legado (`A6`)**: decodificar el pivote dinámico de
  `E051_A`/`E051_D` para conocer su regla de padre.
- **Del cliente**: el fuente de `PRO_CreaDicNomenclaturaReg2`, y si el `conteo`
  del diccionario es por persona o global por `cod_dw_ubic`. En mock es
  indistinguible; en datos reales cambia resultados.

---

## Arquetipos del Grupo A (SLCOPRBA-1355)

Tres arquetipos nuevos para cerrar los criterios que el codigo contemplaba pero
ningun dato ejercitaba. Van en la banda `9570000..9590999`, **disjunta** de R1
(`9010000..9200999`) y de R2 (`9210000..9560999`), para que el orden de
ejecucion de los dos seeds no importe: ningun `DELETE` de uno pisa las filas
del otro.

| ARQ | Caso | Forma | Parejas esperadas | Cierra |
|-----|------|-------|-------------------|--------|
| 57 | CIIU **82** | padre CRR, hija LAB, 1 entidad cada una | **1** por persona | R1-07 |
| 58 | CIIU **90** | padre CRR, hija LAB, 1 entidad cada una | **1** por persona | R1-07 |
| 59 | hija **BLOQUEADA** | CIIU 10, padre CRR, hija RES, `bloqueado = 1` | **0** | R1-06, G-04 |

### Por que el 0 del ARQ 59 es la afirmacion

El filtro `COALESCE(bloqueado, 0) = 0` del insumo saca a la hija, el grupo se
queda con un solo miembro y no hay nada que unificar. El padre sigue vigente: el
criterio excluye la **direccion** bloqueada, no a la persona. Se bloquea la hija
y no el padre a proposito — sin padre el grupo no tiene con que unificar, y la
ausencia de pareja no distinguiria "el filtro funciono" de "no habia caso".

### Dos trampas que costaron un diagnostico

**La columna `ciiu` de la matriz es decoracion.** Nada la lee: el `INSERT` de
`relacion_persona_ubicacion` solo usa `arq`, `tipo_*`, `fecha_*` e
`indunif_hija`. El CIIU se deriva de un `CASE` sobre el numero de arquetipo en
el `INSERT` de `ciiu_persona`. Agregar un arquetipo con CIIU nuevo **sin tocar
ese CASE** lo hace nacer con `'10'`: ARQ 57 y 58 habrian salido CIIU 10 con
padre CRR y hija LAB, o sea los dos tipos preferidos, habrian empatado y
producido 0 parejas donde el gate espera 1.

**`bloqueado` no existia en la tabla mock.** Hubo que agregarla al contrato de
`bdm_stage.relacion_persona_ubicacion` y propagarla en
`v_mock_relacion_persona_ubicacion`, que la fijaba en `CAST(0 AS SMALLINT)`.
Mientras fue constante, el filtro de bloqueo era siempre verdadero y R1-06 y
G-04 no se podian afirmar.

### Cifras que se mueven

| Gate | Antes | Ahora |
|------|-------|-------|
| `CA-U02` total del FULL | 51 000 | **53 000** (+2 000 de ARQ 57 y 58) |
| `CA-U10` total tras la mutacion | 51 200 | **53 200** |
| Rango de la semilla en el gate | `..95609999` | **`..95909999`** |

Los **checksums de convergencia no se mueven**: `sp_unif_gate_convergencia_evaluar`
compara FULL contra FULL2 y DELTA1 contra DELTA2 **entre si**, sin un solo valor
cableado. Los 8/8 se mantienen.
