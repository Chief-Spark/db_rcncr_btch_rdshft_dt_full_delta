# Drill-down de la vía real — reporte medido

Job **DEV/DATABASE #491**, lote `1356301`, pasada 1 de DPLY · mediciones del
2026-10-23 al 26 · consultas en `DRILLDOWN_VIA_REAL.sql`.

Todo lo de abajo está **medido**, no estimado. Lo que es hipótesis lo dice.

---

## El embudo en una línea

```
299.575 relaciones  ->  78.173 entran (26,1%)  ->  19 unificaciones
                                              ->  185.242 scores
                                              ->  363.327 filas MAT
                        263 segundos de cadena
```

---

## Nivel 0 · Entrada: se cae el 73,9% antes de empezar

| | Relaciones | % |
|---|---|---|
| `v_xpm_relacion_persona_ubicacion` | **299.575** | 100% |
| Caen por **bloqueada** | **221.383** | **73,9%** |
| Caen por ya unificada | 19 | 0,006% |
| **Entran al proceso** | **78.173** | **26,1%** |

**La suma cuadra exacta.** El filtro es
`sp_unificacion_r1_preparar_insumo.sql:52,104,105`.

**El `INNER JOIN` contra `v_xpm_ubicacion_estandarizada` de la línea 52 no
descarta nada:** la estandarización cubre **el 100%** de las 114.703
ubicaciones. Era la sospecha principal y quedó descartada.

### Quién se cae: personas jurídicas

Personas con más de 500 relaciones:

| Tipo | Personas | Relaciones | % de la RPU |
|---|---|---|---|
| **NIT** | **106** | **134.357** | **44,9%** |
| CC | 8 | 7.257 | 2,4% |

**Ciento seis empresas concentran casi la mitad del universo.** Son entidades
con cientos de sedes, las marca el `blockreason` del suscriptor
(`02_vistas_insumo_edf_views.sql:219-220`) y **el legado las anti-une igual**
(`Prc_Ordenamiento2.sql:1122-1126`). El filtro es correcto; lo que nadie había
medido es su tamaño.

### El grano de la RPU son CANALES, no ubicaciones

299.575 filas sobre **114.703 ubicaciones físicas** = ~2,6 filas por ubicación.
Esa relación son los canales de contacto de cada ubicación (dirección, teléfono,
celular, correo son filas distintas de
`xpm_location_val_contactinformations`). **Las 114.703 son exactamente el
`conteo_esperado` del Lote GEO**, porque GEO trabaja al grano de ubicación.

Las 8 CC con más de 500 relaciones tienen 51-207 ubicaciones distintas y 3-16
filas por ubicación: **dentro del ratio global, no es colapso de llave.** Es
calidad de dato del origen sobre el 2,4% del universo.

---

## Nivel 1 · Unificación — 78.173 entran, 130 s

`unifica_atributos` sella la regla (1=R1, 2=R2, 3=R3, literal del `INSERT` de
cada `_persist`):

| Regla | Unifica | Destinos | Tiempo | % del proceso |
|---|---|---|---|---|
| **R1** misma dirección exacta | **0** | — | 21 s | 16% |
| **R2** cascada de complementos | **2** | 2 | **73 s** | **56%** |
| **R3** GEO misma vía, puerta cercana | **17** | 5 | 19 s | 15% |
| GEO export | 114.703 candidatos | — | 8 s | 6% |

GEO murió en el `UNLOAD` por el rol IAM; **no bloquea** por decisión de negocio.

### El reparto de la R2, escenario por escenario

| Sello | Escenario | Direcciones |
|---|---|---|
| `H1` | esc1 — complemento vacío | **2** |
| `K2` `L3` `X4` `B5` `A6` `D9` `C7` `A8` `E6` | los otros nueve | **0** |
| — | **sin pareja posible** (un solo complemento en el grupo) | **78.188** |
| — | **BRECHA** — tenía pareja y nadie la resolvió | **0** |

**La brecha en cero es el dato que vale:** no existe un solo caso donde hubiera
pareja y el port no supiera resolverla. **El port no tiene hueco.**

### Por qué la tasa de unificación es 0,024% y NO es un defecto

Las direcciones con más probabilidad de estar duplicadas —las de las empresas
con cientos de sedes— son **justo las que el filtro de bloqueo saca antes de
empezar**. Quitadas, quedan personas naturales con **1,33 ubicaciones de
media**, y con 1,33 no hay nada que unificar.

Los 73 s de la R2 se gastan **barriendo 78.188 grupos de uno**. No es una
cascada cara resolviendo poco: es un barrido sobre un universo sin duplicados.

---

## Nivel 2 · Ordenamiento — 61 s, 185.242 scores

**Aquí el embudo se bifurca, no se estrecha.** DIR sale de las 78.173
relaciones; TEL, CEL y EMAIL salen de `v_xpm_contacto_canal`, que es otra tabla
y otro grano. Por eso los cuatro suman 185.242 y no 78.173.

| Canal | Filas | Personas | Ítems/persona | `lugar_max` |
|---|---|---|---|---|
| DIR | 64.393 | 58.642 | 1,10 | 47 |
| EMA | 59.756 | 58.485 | 1,02 | 57 |
| CEL | 48.493 | 47.978 | 1,01 | 5 |
| TEL | 12.600 | 10.746 | 1,17 | 40 |
| **Total** | **185.242** | 58.878 | | |

Cuadra exacto con `ord_control.scores_generados`. **`lugar_max` de 47 y 57 dice
que el canal rankea de verdad**, cosa que el mock no puede demostrar: allí todos
se quedan en 2.

**Tiempos por etapa:** preparar 24 s · ubicaciones (F3) 9 s · cleanup 8 s ·
los cuatro scoring 9 s · cuentas (F2) + consolidación 6 s.

**Alcance:** 58.878 personas, todas por la rama `por_ubicacion`;
`por_unificacion` y `por_cuenta` en 0 (es FULL, esas ramas no se evalúan);
`stg_residuales` = 0.

---

## Nivel 3 · Novedades — 70 s, 363.327 filas

| Dominio | Filas | Personas | Tiempo |
|---|---|---|---|
| actividad económica | 124.263 | 58.512 | 8 s |
| ubicación | 60.452 | 55.259 | **23 s** |
| contactabilidad | 60.452 | — | 3 s |
| ubicación agregada | 59.282 | 55.259 | **21 s** |
| info básica | 58.878 | 58.878 | 5 s |
| punto de interés | **0** | 0 | 1 s |
| movilidad | **0** | 0 | 4 s |

**Dos etapas en verde con la tabla vacía** (punto de interés y movilidad). La
bitácora lo atribuía a efecto de secuencia, pero en el #491 **las otras cinco ya
estaban pobladas cuando ellas corrieron**, así que ese motivo ya no aplica.
**Abierto.**

**Contactabilidad: 60.452 filas y tres columnas de doce con dato** —
`ubicacion_id` 60.452, `fecha_ultimo_contacto` 60.382, `reportado_por` 4.048
(6,7%). Las otras nueve en 0 es el estado documentado (D-NOV-08). Contar filas
aquí no es contar dominio resuelto.

---

## Tiempos: la cadena completa

| Proceso | Pasada 1 | Pasada 2 | Rendimiento |
|---|---|---|---|
| Unificación | **130 s** | 153 s | 601 rel/s |
| Ordenamiento | **61 s** | 61 s | 3.037 scores/s |
| Novedades | **70 s** | 76 s | 5.190 filas/s |
| **Cadena** | **263 s** | 291 s | 224 personas/s |

**Tres salvedades que van pegadas a esos 263 s:**

1. **Los 8 s de `geo` son el coste de FALLAR**, no de exportar. Cuando el rol
   IAM esté, escribir 114.703 filas a S3 cuesta un tiempo que no está aquí.
2. **Volumen de DEV, ~20x por debajo del buró** (1.194.682 contra 58.878).
   La proyección lineal da ~88 min y **es el suelo, no la estimación**: la R2 es
   la única pieza con joins entre etapas.
3. **La pasada 2 no es comparable**: arranca tras 25 minutos de batería mock.
   Todo el delta está en la R2 (95 s contra 73) y no está explicado.

**EL REPARTO POR ETAPA NO SALE DE LAS TABLAS DE TRAZA.** `unif_control_etapa` y
`ord_control_etapa` traen los conteos en **0 literal**
(`16_sp_unificacion_ciclo.sql:282`, `:302-308` — son marcadores, y `:255-257` lo
dice), y las seis `regla2_esc*` comparten intervalo, de modo que sus 71-72 s son
el mismo tramo repetido seis veces. El reparto de la R2 sale de
`unif_escenario_censo`; el de tiempos finos, de `stl_query`.

---

## Volumetría: lo que falta medir

Las filas están; **los bytes no**. Pendiente de una sesión en DBeaver
(`DRILLDOWN_VIA_REAL.sql`, nivel 3b): peso, `skew_rows`, `stats_off`,
`unsorted` y ancho real contra declarado en **BYTES** (`OCTET_LENGTH`, no `LEN`
— `VARCHAR(n)` en Redshift son n bytes, y es la distinción que tumbó el #477).

---

## Lo que este drill-down deja abierto

| Qué | Estado |
|---|---|
| `punto_interes` y `movilidad` en verde con 0 filas | **abierto**, el efecto de secuencia ya no lo explica |
| La pasada 2 de la R2, 22 s más lenta | **abierto**, pide `svl_query_summary` |
| Volumetría física de las 7 MAT | **pendiente**, consulta escrita |
| Cobertura MAT → `BATCH_CUBO_*` | **pendiente**, y es lo único que convierte «5 de 7 tablas» en un porcentaje de lo que el Batch necesita |
| Rol IAM GEO en las dos cuentas | externo |

## La lección

**Un porcentaje bajo no prueba un defecto mientras no se sepa a quién se le
aplica.** El denominador estaba recortado al 26% y la población superviviente
era justo la que no puede ejercitar la regla. Es la hermana de «un DELTA en cero
no prueba que no haya cambios», y esta semana las dos han costado lo mismo.
