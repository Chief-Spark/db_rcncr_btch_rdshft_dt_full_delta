# Diccionario de datos · las 7 tablas dominio de Novedades

**Qué es esto.** El contrato de salida de Reconocer hacia el producto Batch:
siete tablas en `bdm_datos`, columna por columna, con su tipo, su significado,
de dónde sale el dato y si hoy trae valor o no.

**Fecha: 2026-10-22.** Todo lo que dice de poblamiento está medido en el banco
sobre datos mock; **ninguna de las siete se ha corrido todavía contra el
datashare real**, y ese es el riesgo abierto más grande del proyecto.

## Cómo se lee

Cada tabla tiene una ficha y una tabla de columnas con cinco campos:

| Campo | Qué dice |
|---|---|
| **Columna** / **Tipo** | tal como están en el DDL de `strct` |
| **Significado** | qué es el dato, en negocio |
| **Origen** | de dónde sale: la línea del legado Teradata y/o la fuente nuestra |
| **Estado** | uno de los cinco de abajo |

Los cinco estados:

| Estado | Significa |
|---|---|
| **OK** | se puebla |
| **NULL · legado** | sale vacía **también en Teradata**. No es un defecto del port: el legado emite el literal. Se reproduce tal cual |
| **NULL · catálogo** | falta un catálogo que no se entregó. Se desbloquea con un volcado, sin tocar código |
| **NULL · sin fuente** | el dato no existe en EDF por ninguna vía. No se desbloquea pidiendo |
| **NULL · decisión** | existe, pero se dejó fuera a propósito (legal o alcance) |

**Las tres columnas de trazabilidad** — `lote INTEGER`, `fecha_actualizacion
TIMESTAMP DEFAULT GETDATE()`, `usuario_bd VARCHAR(100)` — las llevan las siete
y **no están en el contrato del legado**: son nuestras, para poder auditar qué
corrida escribió cada fila. No se repiten en cada ficha.

---

## Resumen: las siete de un vistazo

| | Tabla | Llave | Filas por persona | Columnas del contrato | Pobladas |
|---|---|---|---|---|---|
| d1 | `mat_info_ubicacion` | `id` (= `cod_dw_persona_ubic`) | N | 42 | 29 |
| d2 | `mat_info_actividad_economica` | `(info_basica_id, ciiu)` | N | 8 | 5 |
| d3 | `mat_ubicacion_agregada` | 7 columnas | N | 29 | 21 |
| d4 | `mat_info_basica` | `id` (= persona) | **1** | 22 | 20 |
| d5 | `mat_info_contactabilidad` | `(id, sector, ubicacion_id)` | N | 12 | **2** |
| d6 | `mat_info_movilidad` | `id` (evento) | **0..N** | 8 | 6 |
| d7 | `mat_info_punto_interes` | `(id, ubicacion_id)` | N | 10 | 7 |

**Contrato de carga, en las siete: foto completa.** El AS-IS hace
`DELETE … ALL` de las siete antes de cargar (`111.BTQ:817-836`), así que
nuestro port es `TRUNCATE` + `INSERT`. **Ninguna acumula entre corridas.**

**Solo d4 tiene una fila por persona.** Las otras seis son 1:N. Quien modele
aguas abajo con una clave por persona tiene que añadir discriminador, o
colapsará filas.

**Y dos no pueden construir una llave de persona por sí solas:** d5 y d7 no
traen `tipo_identificacion` ni `numero_identificacion` — solo `ubicacion_id` —,
de modo que necesitan un join. **Y los dos joins no son iguales**: el de d5 es
por `cod_dw_persona_ubic` (1:1 con la persona) y el de d7 por `cod_dw_ubic`,
que es la ubicación física y **puede colgar de varias personas**.

---

## d1 · `bdm_datos.mat_info_ubicacion`

**Qué es.** Una fila por **ubicación de una persona**: la dirección, el
teléfono, el celular o el correo, con sus atributos y su orden de prioridad.
Es la tabla raíz: las otras cuatro de ubicación cuelgan de su etapa 9.

**Legado:** `PRO_Novedad_Linea_Ubicacion`, salida `TMP_UBICA_ETAPA_9`
(42 columnas) → `Vstg_Reconocer_Info_Ubica` (`120.TPT:86-176`) → UPSERT
(`130.TPT:573-703`). **Llave:** `id`.

| Columna | Tipo | Significado | Origen | Estado |
|---|---|---|---|---|
| `id` | BIGINT | **la llave**: la relación persona-ubicación | `cod_dw_persona_ubic` | OK |
| `info_basica` | BIGINT | la persona | `id_buro_persona` = `FNV_HASH(pin)` | OK |
| `cod_pin_persona` | BIGINT | PIN de la persona | `xpm.pin` | OK |
| `cod_tipo_ident_fte` | VARCHAR(20) | código del tipo de documento | RPU | OK |
| `tipo_identificacion` | VARCHAR(30) | descripción homologada (CC, NIT, CE…) | `V_Hom_Tip_Ident_Linea` (`NOV:8406`) | OK *(desde 2026-10-21)* |
| `numero_identificacion` | BIGINT | número de documento | `cod_pin_persona` | OK |
| `orden` | INTEGER | orden de prioridad del Ordenamiento | `rpu_orden_prioridad`, `MIN` por ubicación | OK |
| `dato` | VARCHAR(201) | **el valor**: la dirección, el teléfono, el correo | etapa 9 | OK |
| `clase` | VARCHAR(5) | DIR / TEL / CEL / EMAIL | tipo de la **propia** ubicación | OK |
| `ciudad` | VARCHAR(30) | ciudad | `ubicacion_estandarizada` | OK |
| `departamento` | VARCHAR(30) | departamento | ídem | OK |
| `codigo_dane` | VARCHAR(20) | código DANE de la ciudad | ídem | OK |
| `latitud` / `longitud` | DECIMAL(10,6) | coordenadas | `ubicacion_estandarizada` ∪ `geo_atributos` | OK |
| `cod_dw_ubic` | BIGINT | la ubicación física | RPU | OK |
| `cod_dw_direccion_fisica` | BIGINT | la dirección | RPU | OK |
| `cod_dw_tipo_ubicacion_dir` | INTEGER | tipo de ubicación-dirección | RPU | OK |
| `ind_unificacion` | INTEGER | si la ubicación quedó unificada | Unificación | OK |
| `es_tipo_crr` | VARCHAR(1) | bandera: es correspondencia | etapa 9 | OK |
| `es_tipo_res` | VARCHAR(1) | bandera: es residencia | etapa 9 | OK |
| `es_tipo_lab` | VARCHAR(1) | bandera: es laboral | etapa 9 | OK |
| `flag_op` | SMALLINT | 1 = alta, 2 = cambio, 3 = baja | `120.TPT:163` | OK · **el 3 no ocurre nunca** (ver abajo) |
| `reportado_desde` | DATE | primer reporte | — | **NULL · legado** (`NOV:8358-8363`) |
| `ultimo_reporte` | DATE | último reporte | — | **NULL · legado** |
| `fuente` | INTEGER | fuente del dato | — | **NULL · legado** |
| `numero_reportes` | INTEGER | nº de reportes | — | **0 literal · legado** |
| `numero_entidades` | INTEGER | nº de entidades reportantes | — | **0 literal · legado** |
| `es_tipo_ppl` `es_tipo_agn` `es_tipo_suc` `es_tipo_est` `es_tipo_cdi` | VARCHAR(1) | otras cinco banderas de tipo | — | **NULL · legado** (`NOV:8377-8381`) |
| `indicativo` | VARCHAR(20) | indicativo del teléfono fijo | `V_TELEFONO_FIJO` | **NULL · catálogo** |
| `tipo` | VARCHAR(30) | tipo de ubicación homologado | `V_Hom_TipoUbic_Dir_Linea` | **NULL · catálogo** |
| `zona` | VARCHAR(30) | zona (urbana / rural) | `V_ZONA_UBICACION` + `V_Hom_Zona_Linea` | **NULL · catálogo** |
| `tipo_cuenta` | VARCHAR(1) | tipo de correo | `V_TIPO_CORREO` | **NULL · catálogo** |
| `estrato` | VARCHAR(10) | estrato socioeconómico | contrato GEO sin pinar · **ver nota** | **NULL · sin fuente** |
| `barrio` | VARCHAR(100) | barrio | ídem · **ver nota** | **NULL · sin fuente** |
| `localidad` | VARCHAR(100) | localidad / comuna | — | **NULL · sin fuente** |
| `codigo_postal` | VARCHAR(20) | código postal | ídem · **ver nota** | **NULL · sin fuente** |
| `cod_dw_telefono` | BIGINT | llave del teléfono | — | **NULL · sin fuente** |
| `cod_dw_direccion_electronica` | BIGINT | llave del correo | — | **NULL · sin fuente** |

**Nota sobre estrato, barrio y código postal.** El 2026-10-21 se encontró que
**sí existen en el datashare**, por una fuente distinta de GEO:
`xpm_location."location.val.stratum"`,
`…contactinformations.val.contactneighborhood` y `…contactzipcode`. **No las
leemos todavía.** Medido: barrio 15,9 % de cobertura en un ambiente y 1,9 % en
otro; código postal 11,9 % y **26 filas**; estrato **0,08 % y 0,75 %**, con 7
valores distintos (o sea bien mapeada y vacía). Cablear barrio es trabajo
anotado; estrato y postal, con esa cobertura, no sirven todavía.

**`flag_op = 3` (baja) es código muerto**, y conviene saberlo antes de
construir lógica de borrado encima: `Severidad = 2` sale únicamente de
`FLAG_OP = 'E'` (`120.TPT:163`) y esa rama nunca es verdadera en el legado
(`NOV:7590-7594` contra `:8393`). **El UPSERT nunca borra una fila.**

---

## d2 · `bdm_datos.mat_info_actividad_economica`

**Qué es.** Una fila por **persona y actividad económica (CIIU)**.

**Legado:** `PRO_Novedad_Linea_Historial` (la nomenclatura está cruzada: manda
el `120.TPT`, no el nombre). **Llave:** `(info_basica_id, ciiu)`.

**No depende del Ordenamiento**: lee la RPU directamente, no la etapa 9.

| Columna | Tipo | Significado | Origen | Estado |
|---|---|---|---|---|
| `info_basica_id` | BIGINT | la persona | `id_buro_persona` | OK |
| `ciiu` | VARCHAR(20) | código de actividad económica | `v_xpm_actividad_economica_persona` (11 fuentes) | OK |
| `fecha_reporte` | DATE | fecha del reporte | RPU | OK |
| `tipo_identificacion` | VARCHAR(30) | descripción homologada | `V_Hom_Tip_Ident_Linea` | OK *(desde 2026-10-21)* |
| `numero_identificacion` | BIGINT | número de documento | `cod_pin_persona` | OK |
| `id` | INTEGER | correlativo de la fila | lo asigna el TPT en el legado (`120.TPT:177`) | **NULL · decisión** |
| `actividad_economica` | VARCHAR(500) | descripción del CIIU | `V_ACTIVIDAD_ECONO_CIIU` | **NULL · catálogo** |
| `version` | INTEGER | versión del CIIU | ídem | **NULL · catálogo** |

---

## d3 · `bdm_datos.mat_ubicacion_agregada`

**Qué es.** La **vista agregada** de las ubicaciones de una persona: una fila
por combinación de persona, ciudad y dato, con listas concatenadas de tipos,
fuentes e ids.

**Legado:** `PRO_Novedad_Linea_Ubi_Agregada` (`NOV:5032-7302`, 22 etapas).
**Llave:** siete columnas. Lee las **dos** etapas de d1.

| Columna | Tipo | Significado | Estado |
|---|---|---|---|
| `info_basica` | BIGINT | la persona | OK |
| `tipo_identificacion` | VARCHAR(30) | descripción homologada | OK *(desde 2026-10-21)* |
| `numero_identificacion` | BIGINT | número de documento | OK |
| `ciudad` `departamento` `codigo_dane` | VARCHAR | geografía de la persona | OK |
| `ubicacion_dato` | VARCHAR(201) | el valor de la ubicación | OK |
| `ubicacion_ciudad` `ubicacion_departamento` `ubicacion_codigodane` | VARCHAR | geografía de la ubicación | OK |
| `ubicacion_reportdesde` `ubicacion_ultreporte` | DATE | ventana de reporte | OK · **vienen de la etapa 2** |
| `ubicacion_numentidades` `ubicacion_numreportes` | INTEGER | conteos | OK · **de la etapa 2** |
| `ubicacion_clase` | VARCHAR(5) | DIR / TEL / CEL / EMAIL | OK |
| `ubicacion_orden` | INTEGER | orden de prioridad | OK |
| `ubicacion_longitud` `ubicacion_latitud` | DECIMAL(10,6) | coordenadas | OK |
| `tipo` | VARCHAR(30) | **cadena agregada**, p. ej. `'R - L - C'` | OK |
| `fuente` | VARCHAR(30) | **cadena agregada**, p. ej. `'SUS - CAM'` | OK |
| `id` | VARCHAR(1000) | **lista** de `cod_dw_ubic` separada por comas | OK |
| `ubicacion_tipocuenta` | VARCHAR(1) | tipo de correo | **NULL · catálogo** (`V_TIPO_CORREO`) |
| `ubicacion_indicativo` | VARCHAR(20) | indicativo | **NULL · catálogo** (`V_TELEFONO_FIJO`) |
| `ubicacion_zona` | VARCHAR(30) | zona | **NULL · catálogo** (`V_ZONA_UBICACION`) |
| `cod_pais` | VARCHAR(3) | país | **NULL · catálogo** (`V_PAIS`) |
| `ubicacion_estrato` `ubicacion_barrio` `ubicacion_localidad` `ubicacion_codigopostal` | VARCHAR | atributos GEO | **NULL · sin fuente** (misma nota que d1) |

**Ojo con `id`, `tipo` y `fuente`**: no son escalares, son **cadenas
concatenadas**. Quien las consuma tiene que separarlas.

---

## d4 · `bdm_datos.mat_info_basica`

**Qué es.** Los **atributos de la persona**: nombres, documento, género, edad,
actividad principal. **La única tabla con una fila por persona.**

**Legado:** `PRO_Novedad_Linea_Info_Basica` (`NOV:2166-3920`, doce etapas).
**Llave:** `id` sola.

**No es un port de esas doce etapas: es una re-especificación.** El trabajo
entero de esas etapas es elegir, por persona, el valor más confiable de cada
atributo (`COALESCE(valor_2, valor)`, `NOV:3447-3466`). En EDF esa elección
**ya viene hecha**: `bestName`, `bestIdentifications` y
`bestPersonalInformation` *son* el registro más confiable.

| Columna | Tipo | Significado | Origen EDF | Estado |
|---|---|---|---|---|
| `id` | BIGINT | **la llave**: la persona | `FNV_HASH(xpm.pin)` | OK |
| `cod_pin_persona` | BIGINT | PIN | `xpm.pin` | OK |
| `primer_nombre` | VARCHAR(100) | primer nombre | `bestname.firstname` | OK |
| `segundo_nombre` | VARCHAR(100) | segundo nombre | `bestname.secondname` | OK |
| `primer_apellido` | VARCHAR(100) | primer apellido | `bestname.firstlastname` | OK |
| `segundo_apellido` | VARCHAR(100) | segundo apellido | `bestname.secondlastname` | OK |
| `nombre_completo` | VARCHAR(200) | nombre completo | `bestname.fullname` | OK |
| `cod_tipo_ident_fte` | VARCHAR(20) | código del tipo de documento | `bestidentifications.personidtype` | OK |
| `tipo_identificacion` | VARCHAR(30) | descripción homologada | `V_Hom_Tip_Ident_Linea` | OK *(desde 2026-10-21)* |
| `numero_identificacion` | BIGINT | número de documento | `bestidentifications.personidnumber` | OK |
| `estado_documento` | VARCHAR(20) | estado del documento (`00` vigente, `21` cancelada por muerte) | `businessidstatus` con `LPAD(…,2,'0')` | OK · **D-EDF-13** |
| `rango_edad` | VARCHAR(25) | rango de edad | `bestpersonalinformation.agerange` | OK |
| `genero` | VARCHAR(508) | `M` / `F` / `O` / vacío | `bestpersonalinformation.gender`: 1→M, 2→F, 3→O, resto vacío | OK · **D-EDF-14** |
| `fecha_expedicion` | DATE | expedición del documento | `bestidentifications.issuedate` (epoch) | OK |
| `lugar_expedicion` | VARCHAR(100) | ciudad de expedición | `issuingcityname` | OK |
| `departamento_expedicion` | VARCHAR(100) | departamento de expedición | `issuingstatename` | OK |
| `ciiu` | VARCHAR(20) | actividad principal | `mainisiccodeforproduct` | OK |
| `actividad_economica` | VARCHAR(500) | descripción de la actividad | `productmainisicdescription` | OK |
| `razon_social` | VARCHAR(500) | razón social (personas jurídicas) | **derivada**: `fullname` cuando el tipo es NIT | OK · **D-NOV-10** |
| `rut` | VARCHAR(1) | `S` / `N`: registro tributario | `citizentaxregistrationindicator` | OK |
| `pagina_web` | VARCHAR(100) | página web | — | **NULL · sin fuente** |
| `mosaic_id` | INTEGER | segmento Mosaic | — | **NULL · decisión** |

**`pagina_web` no se desbloquea pidiendo**: el campo `WebSite` del contrato
Alpha está marcado *"NO APLICA (NO EXISTE CAMPO EN ALPHA)"*
(Confluence `CCBR` 251264543). **`mosaic_id`** queda fuera por decisión legal.

**El género tiene un valor nuevo frente al AS-IS**: el `O` (no binario). El
AS-IS solo conocía `M` y `F`. Y la ausencia se escribe **vacío, no NULL**,
porque el legado hace `COALESCE(GENERO_2, GENERO, '')` (`NOV:3461`).

**Divergencia anotada (D-NOV-09):** una persona con varias identificaciones
aporta la **validada contra fuente oficial**; el legado usa su propia cascada
de prioridad, que no tenemos. Pueden no ser la misma.

---

## d5 · `bdm_datos.mat_info_contactabilidad`

**Qué es.** El resumen de la **gestión de contacto** sobre una ubicación: si se
contesta, cuándo fue el último contacto, qué día y a qué hora conviene llamar,
y con qué resultado.

**Legado:** `PRO_Novedad_Linea_Contact` (`NOV:186-1059`, siete etapas).
**Llave:** `(id, sector, ubicacion_id)`.

> ### ⚠ Diez de las doce columnas salen en NULL, y no es un defecto del port
>
> **No existe la fuente.** `V_CONTACTABILIDAD` es un log de eventos de gestión
> y una de las seis fuentes del buró (`V_Fuente`, `Cod_Dw_Fuente = 31937`). No
> está en el datashare, no está en la documentación de EDF —la sección
> `contactInformations` del contrato Alpha tiene nueve campos y los nueve son
> el **dato** de contacto, ninguno la **gestión**— y el cargador de esa fuente
> no está en el material entregado.
>
> **Y las dos que sí se pueblan lo hacen con OTRA semántica** (decisión del
> usuario, 2026-10-21, D-NOV-08). Quien consuma esta tabla tiene que saberlo.

| Columna | Tipo | Significado en el legado | Qué trae hoy | Estado |
|---|---|---|---|---|
| `ubicacion_id` | BIGINT | la ubicación gestionada | `cod_dw_persona_ubic` | OK |
| `fecha_ultimo_contacto` | TIMESTAMP | **última vez que alguien contactó** (`MAX(FECHA_GESTION)`, `NOV:855`) | **la última vez que se actualizó el dato** (`ContactEventLastUpdated`) | OK · **otra semántica** |
| `reportado_por` | INTEGER | quien **gestionó** (`NOV:598`) | quien **reportó** la ubicación | OK · **otra semántica** |
| `id` | BIGINT | `COD_DW_CONTACTABILIDAD`, la llave del evento | — | **NULL · sin fuente** |
| `contactabilidad` | VARCHAR(2) | `SI` / `NO`: si el contacto fue efectivo | — | **NULL · sin fuente** |
| `fecha_gestion` | TIMESTAMP | fecha de la gestión | — | **NULL · sin fuente** |
| `mejor_dia_gestion` | VARCHAR(10) | día de la semana, en español | — | **NULL · sin fuente** |
| `mejor_hora_gestion` | VARCHAR(20) | franja horaria (`08:01 a 12:00`…) | — | **NULL · sin fuente** |
| `sector` | VARCHAR(100) | clase buró del suscriptor | — | **NULL · catálogo** |
| `peso` | BIGINT | `COUNT(*) × 1e8 + fecha` | — | **NULL · sin fuente** |
| `mejor_resultado_3meses` | VARCHAR(100) | código de gestión más frecuente, 3 meses | — | **NULL · sin fuente** |
| `mejor_resultado_6meses` | VARCHAR(100) | ídem, 6 meses | — | **NULL · sin fuente** |

**El NULL es deliberado y no debe sustituirse por un valor por defecto.** Un
`'NO'` en `contactabilidad` lo leería el Batch como *"se intentó contactar y no
se pudo"*, que es falso: la verdad es *"no se sabe"*.

---

## d6 · `bdm_datos.mat_info_movilidad`

**Qué es.** **"Esta persona se mudó."** Una fila por **evento detectado**, no
por persona.

**Legado:** `PRO_Novedad_Linea_Indic_Movilidad` (`NOV:1508-2165`) y
`P0029_INDICADORES_MOVILIDAD`. **Llave:** `id`.

> ### Es una tabla de EVENTOS, no de banderas
>
> Las cuatro ramas del legado son `UNION ALL` y cada una filtra por **su**
> cambio (`P0029…111.BTQ:62-68`): **una fila existe solo cuando ese cambio se
> detectó**. No hay fila que diga *"no cambió de estrato"*. **La ausencia de
> fila es "no se detectó", no "no cambió"** — y que una persona no tenga
> ninguna fila aquí es correcto, no dato faltante.
>
> **Las cuatro ramas exigen cambio de dirección.** Ningún indicador se dispara
> sin él: los otros tres son atributos que se comparan sobre ese mismo evento.

| Columna | Tipo | Significado | Origen | Estado |
|---|---|---|---|---|
| `id` | BIGINT | la llave del evento | **derivada**: `FNV_HASH(persona\|indicador\|fecha)` | OK · **D-NOV-16** |
| `info_basica_id` | BIGINT | la persona | `id_buro_persona` | OK |
| `fecha` | DATE | **cuándo se detectó** el cambio, no cuándo se mudó | fecha de la corrida (igual que el legado, `P0029:40`) | OK |
| `novedad` | VARCHAR(1000) | `Cambio de Direccion` \| `de Ciudad` \| `de Estrato` | literales del propio P0029 | OK |
| `tipo_identificacion` | VARCHAR(30) | descripción homologada | `V_Hom_Tip_Ident_Linea` | OK |
| `numero_identificacion` | BIGINT | número de documento | `cod_pin_persona` | OK |
| `descripcion` | VARCHAR(100) | valor del indicador | `V_INDICADOR_MOVILIDAD` | **NULL · catálogo** |
| `novedad_2` | VARCHAR(30) | la novedad homologada a Línea | `V_Hom_Ind_Mov_Linea` | **NULL · catálogo** |

**Tres de los cuatro indicadores.** Falta `Cambio de Localidad`: `LOCALIDAD` /
comuna **no existe en EDF por ninguna vía** (buscado en el inventario de 1.072
columnas del datashare y en Confluence, espacios `CCBR` y `EDCLMI`).

**Medido en el banco:** `Cambio de Direccion` detecta los 100 del ARQ 97
exactos. **Ciudad y estrato salen en 0 porque el mock no los siembra**, así que
esas dos ramas están cableadas pero **no probadas**.

**Tabla de apoyo:** `bdm_datos.nov_movilidad_foto`, insert-only, es la pieza
que el legado no entregó (`MTCalcularIndicadoresMovilidad`). No es contrato de
salida: es cómo se detecta el cambio.

---

## d7 · `bdm_datos.mat_info_punto_interes`

**Qué es.** Los **puntos de interés cercanos** a una ubicación — un banco, un
colegio — con su distancia en metros.

**Legado:** `PRO_Novedad_Linea_Punto_Interes` (`NOV:4585-5031`).
**Llave:** `(id, ubicacion_id)`. **Fuente:** nuestra propia
`bdm_datos.geo_distancias`, que es la respuesta de ArcGIS al contrato
`Salida_Distancias`.

| Columna | Tipo | Significado | Origen | Estado |
|---|---|---|---|---|
| `id` | BIGINT | la llave de la relación ubicación-punto | **derivada**: `FNV_HASH` de la clave 1:N del contrato | OK · **D-NOV-11** |
| `ubicacion_id` | BIGINT | **`cod_dw_ubic`** — la ubicación física, **no** la relación persona-ubicación | contrato, col01 | OK · **ojo al join** |
| `nombre` | VARCHAR(200) | nombre del punto de interés | contrato, **col08** | OK *(desde 2026-10-21)* |
| `distancia` | INTEGER | distancia en metros | contrato, col11 | OK |
| `latitud` / `longitud` | VARCHAR(40) | coordenadas **del punto**, no de la ubicación | contrato, col09 / col10 | OK |
| `descripcion_tipo_punto_interes` | VARCHAR(1000) | tipo de punto | contrato col07, **valor crudo sin homologar** | OK · **divergencia** |
| `tipo` | VARCHAR(30) | tipo homologado a Línea | `V_Hom_Tipo_Pto_Int_Linea` | **NULL · catálogo** |
| `nombre_entidad` | VARCHAR(1000) | entidad dueña del punto | `RELACION_PUNTO_INTERES_X_PERS` | **NULL · sin fuente** |
| `nit_entidad` | VARCHAR(20) | NIT de esa entidad | ídem | **NULL · sin fuente** |

**El nombre llegaba y se tiraba hasta el 2026-10-21.** El contrato siempre lo
trajo en `col08`; era `geo_distancias` la que no tenía columna (D-GEO-08).

**`nombre_entidad` y `nit_entidad` no viajan en el contrato de distancias**:
son petición, no código.

---

## Lo que NINGUNA de las siete trae, y conviene saber de entrada

| Hueco | Afecta | ¿Se desbloquea pidiendo? |
|---|---|---|
| La gestión de contacto (`V_CONTACTABILIDAD` + 5 satélites) | d5 entera | **sí**, pero probablemente la respuesta sea *no se migra* |
| `V_ACTIVIDAD_ECONO_CIIU` | d2 | sí |
| `V_INDICADOR_MOVILIDAD`, `V_Hom_Ind_Mov_Linea` | d6 | sí |
| `V_Hom_Tipo_Pto_Int_Linea`, `V_TIPO_PUNTO_INTERES` | d7 | sí |
| `V_TELEFONO_FIJO`, `V_TIPO_CORREO`, `V_ZONA_UBICACION`, `V_Hom_Zona_Linea`, `V_Hom_TipoUbic_Dir_Linea`, `V_PAIS` | d1, d3 | sí |
| **`LOCALIDAD` / comuna** | d1, d3, d6 | **no**: no existe en EDF |
| **`PAGINA_WEB`** | d4 | **no**: marcada *NO APLICA* en el contrato Alpha |
| **`MOSAIC_ID`** | d4 | **no**: decisión legal |
| **Estrato, barrio, código postal** | d1, d3 | **existen en el datashare y no los leemos**; barrio es trabajo nuestro, estrato y postal están casi vacíos |

**Las consultas de volcado de los catálogos pedibles están escritas** en
`docs/PETICION_CATALOGOS_NOVEDADES.md`, listas para enviar.
