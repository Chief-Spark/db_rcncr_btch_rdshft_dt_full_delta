# Petición de catálogos y columnas para Novedades — dominios Ubicación, Actividad Económica y Ubicación Agregada

**SLCOPRBA-1355.** Qué falta para que `MAT_INFO_UBICACION` salga completa, por
qué falta, y qué columna concreta desbloquea cada cosa.

> **CORRECCIÓN 2026-10-20.** Escrito sin el legado de Novedades ni el catálogo
> real de `edf_views`. Con los dos en el repo (`docs/legado_teradata/`,
> `docs/edf_views/`), cambian cinco cosas:
> 1. **`V_Geografia` no "corta en Santander".** El archivo no está ordenado (trae
>    11 departamentos) y su grano es **centro poblado** (~7.978 códigos), no
>    municipio. El sustituto es `Dane Divipola Villages Codes (NH).csv`.
> 2. **`INDICATIVO` sale de `V_TELEFONO_FIJO.COD_AREA`** (`Novedad.sql:7966`), no
>    de `V_Geografia`.
> 3. **El universo de Actividad Económica** es `TMP_INBAS_ETAPA_10` cruzado con
>    `VU_PERSONA_ACTIVIDAD_ECONOMICA` (`:1288-1291`): **todas** las actividades,
>    no solo la principal.
> 4. **`Fecha_Matricula` sí está en EDF**:
>    `xpm_chamberofcommerce."…dateofmercantileregistration"`. Los CIIU
>    secundarios están en `xpm_personalinformation` y `xpm_chamberofcommerce`.
> 5. **La tabla de Actividad Económica no "sólo crece"**: `111.BTQ:823` la
>    vacía en cada corrida y el `ID` se renumera.
>
> Detalle: `docs/ANALISIS_AS_IS_HOMOLOGACION.md` y
> `docs/edf_views/RESULTADOS_CONSULTAS_EDF.md`.

El port de `PRO_Novedad_Linea_Ubicacion` está hecho y corre: produce las 42
columnas del contrato. **Cinco de ellas salen NULL** y dos CSV entregados
llegaron truncados. Nada de esto se resuelve escribiendo código.

---

## 0. LO MÁS URGENTE: `V_Hom_Tip_Ident_Linea` bloquea un dominio entero

**Ha dejado de ser "una columna sale NULL". Hoy vacía la salida completa de
Ubicación Agregada**, el tercer dominio portado.

`TIPO_IDENTIFICACION` sale NULL en toda fila porque falta este catálogo
(`sp_novedades_ubicacion_edf.sql:362`). La etapa 5 del legado une por igualdad
en esa columna (`Novedad.sql:5431`), y `NULL = NULL` es falso: el join vacía la
cadena entera. Medido en el banco con el mock: **las etapas 1 a 4 traen 8.500
filas y la 5 trae cero**, de modo que `MAT_UBICACION_AGREGADA` queda vacía.

**No es un defecto del port y no se arregla con código.** El legado no pone
centinela ahí y la etapa 2 arrastra la columna cruda (`:8624`). Meter un
`COALESCE` fundiría filas que el legado no funde: cambiaría un bloqueo visible
por un defecto silencioso.

**Lo que se pide son dos columnas y pocas filas:**

| Columna | Para qué |
|---|---|
| `Valor_Fuente` | la llave; se une contra `COD_TIPO_IDENT_FTE`, que **ya tenemos** |
| `Descripcion_Hom_Tip_Ident_Linea` | el valor publicable |

En el mock `cod_tipo_ident_fte` está poblado con dos valores distintos (`1` en
7.000 filas y `3` en 1.500), así que la llave existe; sólo falta contra qué
unirla. Con este volcado se desbloquean `NOV-UB-18`, `NOV-AE-07` y los siete
`NOV-AG-02..08`.

**Matiz para cuando se porte `Info_Basica`:** allí la llave no es la columna
pelada sino `COALESCE(COD_TIPO_IDENT_FTE_2, COD_TIPO_IDENT_FTE)` (`:3475`), y
`cod_tipo_ident_fte_2` hoy no está en nuestras vistas.

---

## 1. Los nueve catálogos que el SP consume y no se entregaron

Cruzados los catálogos que `PRO_Novedad_Linea_Ubicacion` lee
(`Novedad.sql:7303-8887`) contra los diez CSV del paquete
`novedades_mapeo_y_catalogos.zip`:

| Catálogo del legado | ¿Entregado? | Columna que bloquea | Criterio |
|---|---|---|---|
| `V_GEOGRAFIA` | sí, **truncado** | ver §3 | — |
| `V_TIPO_UBICACION_DIRECCION` | sí | — | — |
| `V_FUENTE`, `V_FUENTE_DATO` | sí | — | — |
| `V_Razon_Bloqueo` | sí | — | — |
| `V_GESTION_REGISTRO` | sí | — | — |
| **`V_Hom_TipoUbic_Dir_Linea`** | **no** | `TIPO` | `NOV-UB-16` |
| **`V_ZONA_UBICACION`** y **`V_Hom_Zona_Linea`** | **no** | `ZONA` | `NOV-UB-17` |
| **`V_Hom_Tip_Ident_Linea`** | **no** | `TIPO_IDENTIFICACION` | `NOV-UB-18`, `NOV-AE-07` y `NOV-AG-02..08` — **ver §0: vacía un dominio entero** |
| **`V_TELEFONO_FIJO`** | **no** | `INDICATIVO` | `NOV-UB-19` |
| **`V_TIPO_CORREO`** | **no** | `TIPO_CUENTA` | `NOV-UB-20` |
| **`V_DIRECCION_ELECTRONICA`** | **no** | puente a `V_TIPO_CORREO` | `NOV-UB-20` |
| **`V_Tipo_Via`** | **no** | descripción de tipo de vía | — |
| **`V_Hom_Fuente_Linea`** | **no** | `FUENTE` de la etapa 2 | — |

**Lo que pedimos:** el volcado completo de esos nueve, en el mismo formato CSV
que los seis que sí llegaron (cabecera entrecomillada, `NULL` como texto).

**Un matiz sobre `V_Hom_Fuente_Linea`, para no pagar dos veces:** en el legado
**nunca se aplica**. `Novedad.sql:8635` escribe
`COALESCE(COALESCE(VFT.DESCRIPCION_FUENTE,'CAM'), h2.Descripcion_Hom_Fuente_Linea)`
y el `COALESCE` interno jamás devuelve NULL, así que toda fuente desconocida
sale como `'CAM'` y la homologación es código muerto. Lo hemos portado literal.
Si el catálogo llega, hay que decidir **antes** si se corrige la fórmula o se
conserva el defecto — no es una decisión de migración, es funcional.

---

## 2. Las cuatro columnas del contrato GEO que no se persisten

El contrato `Salida_Georreferenciacion` entrega **32 columnas** y
`bdm_datos.geo_atributos` guarda cinco. El cargador lee las 32 al staging y
mapea sólo cinco posiciones —`sp_geo_cargar_georreferenciacion.sql:268-291`—
porque **las demás posiciones no están fijadas en ningún documento que
tengamos**. El propio código lo dice en `:443-446`:

> *"Los atributos barrio/estrato del contrato de 32 columnas son extensibles;
> no hay columna de origen fija en el staging, por lo que se dejan sin
> sobrescribir (NULL según DDL) hasta pinnar su posición en el contrato."*

| Columna de `MAT_INFO_UBICACION` | Origen en el legado | Estado | Criterio |
|---|---|---|---|
| `BARRIO` | `RELACION_UBICAC_ESTANDAR_GEO.URBANIZACION_BARRIO` | columna declarada en `geo_atributos`, **nunca escrita** | `NOV-UB-21` |
| `ESTRATO` | `V_ESTRATO_DIRECCION.DESCRIPCION_ESTRATO` | ídem | `NOV-UB-21` |
| `LOCALIDAD` | `RELACION_UBICAC_ESTANDAR_GEO.LOCALIDAD_COMUNA` | **no existe columna** | `NOV-UB-22` |
| `CODIGO_POSTAL` | `RELACION_UBICAC_ESTANDAR_GEO.COD_POSTAL` | **no existe columna** | `NOV-UB-22` |

**Lo que pedimos:** `Salida_Geo.pdf` —el contrato de las 32 columnas con su
orden— para pinar las posiciones. Con eso se amplía `geo_atributos` y las
cuatro se desbloquean de una vez.

**Lo que NO hace falta pedir:** `CODIGO_DANE`. Sale del datashare, no del
contrato GEO: es `standardizeddanecode`, que
`02_vistas_insumo_edf_views.sql:52-58` ya expone como `cod_dw_ciudad`. Lo
mismo con `CIUDAD` y `DEPARTAMENTO`, que vienen estandarizados en la misma
vista.

---

## 3. Dos CSV llegaron truncados a 1.000 filas exactas

| Archivo | Filas | Señal |
|---|---|---|
| `REC_VISTA - V_Geografia.csv` | **1.000** | corta en `68872 VILLANUEVA (SANTANDER)`, a mitad del departamento 68 en orden alfabético. Colombia tiene ~1.100 municipios |
| `BDM_VISTA - V_Cod_Entrega_Dato.csv` | **1.000** | catálogo de suscriptores con exactamente 1.000 filas es improbable |

Es la firma de un export con límite de 1.000 filas. Por eso
`21_ddl_catalogos_dominio.sql:23-25` decidió **no cargarlos**: un catálogo
geográfico a medias no da error, da *joins* que no casan, en silencio.

**Lo que pedimos:** el reexport completo de los dos.

**Impacto hoy:** bajo para Ubicación, porque `CODIGO_DANE`, `CIUDAD` y
`DEPARTAMENTO` los resolvemos por el datashare. Alto para los dominios que
falten por portar, y para el `INDICATIVO`, que en `V_Geografia` viene como
`Indicativo_Telefonico`.

---

## 4. Resumen de lo que se pide, en orden de valor

| # | Qué | Desbloquea |
|---|---|---|
| **0** | **`V_Hom_Tip_Ident_Linea`** (dos columnas, ver §0) | **el dominio Ubicación Agregada entero**, más `NOV-UB-18` y `NOV-AE-07` |
| 1 | `Salida_Geo.pdf` (contrato de 32 columnas con su orden) | `BARRIO`, `ESTRATO`, `LOCALIDAD`, `CODIGO_POSTAL` — y de paso `ZONA` y `tipo_via`, que también viajan en ese contrato |
| 2 | Los cuatro catálogos de homologación a Línea | `TIPO`, `ZONA`, `TIPO_IDENTIFICACION` y la fuente de la etapa 2 |
| 3 | `V_TELEFONO_FIJO`, `V_TIPO_CORREO`, `V_DIRECCION_ELECTRONICA`, `V_ZONA_UBICACION`, `V_Tipo_Via` | `INDICATIVO`, `TIPO_CUENTA` |
| 4 | Reexport completo de `V_Geografia` y `V_Cod_Entrega_Dato` | los dominios que faltan por portar |
| 5 | **`V_ACTIVIDAD_ECONO_CIIU`** (ver §6) | `ACTIVIDAD_ECONOMICA` y `VERSION` de `MAT_INFO_ACTIVIDAD_ECONOMICA` |

---

## 5. Decisiones funcionales que no son una petición de datos

**(a) CERRADA — las cinco columnas en blanco y el `'CAM'` de la fuente se
reproducen tal cual.** Decisión del equipo, SLCOPRBA-1355.

`REPORTADO_DESDE`, `ULTIMO_REPORTE`, `FUENTE`, `NUMERO_REPORTES` y
`NUMERO_ENTIDADES` llegan a `MAT_INFO_UBICACION` como NULL y 0 **literales**
(`Novedad.sql:8358-8363`); sus valores reales viven en `TMP_UBICA_ETAPA_2`,
que esa ruta no consume. Y la homologación de fuente nunca se aplica, porque
el `COALESCE` interno de `:8635` jamás devuelve NULL: todo sale `'CAM'`.

**No se pueblan y no se corrige.** El criterio es reproducir el legado, y esto
deja de ser una divergencia abierta: es el comportamiento esperado. El
criterio `NOV-UB-09` del tablero verifica justamente que **sigan** en blanco.
Si alguien los ve vacíos en el entregable, esto es la razón.

**(b) CERRADA — la baja por bloqueo no existe en el AS-IS, y no la inventamos.**

`FLAG_OP = 'E'` **es código muerto en el legado**, y con él la única vía de
borrado de `MAT_INFO_UBICACION`. La etapa 1 hace el anti-join contra
`V_BLOQUEO` (`Novedad.sql:7590-7594`: `LEFT JOIN … WHERE BLQ.COD_DW_PERSONA_UBIC
IS NULL`) y la etapa 9 vuelve a unir **esa misma tabla por esa misma llave**
para preguntar `BLQ.FECHA_BLOQUEO = DATE - 1` (`:8393`, `:8416`). Lo que
sobrevivió a la etapa 1 no está en `V_BLOQUEO`, así que la comparación nunca
da TRUE.

Arrastra al TPT: `Severidad = 2` —el borrado— sale únicamente de
`WHEN STG.FLAG_OP = 'E' THEN 2` (`120.TPT:163`). **Sin `'E'` no hay Severidad 2
y el UPSERT de `130.TPT` nunca borra una fila: el AS-IS sólo inserta y
actualiza.**

Lo reproducimos tal cual, igual que las otras trampas, y los criterios
`NOV-UB-13` y `NOV-UB-15` verifican que **sigamos sin emitir bajas**. Si el
TO-BE quiere que una ubicación bloqueada se dé de baja de verdad, eso es un
cambio funcional y hay que pedirlo: no es un defecto de la migración.

**(c) El control de lote del legado no funciona.** `LOG_TD` se borra al inicio
de cada corrida (`P0035_Extractor_Novedades_111.BTQ:64-65`) y el watermark que
los SP leen es `MAX(FECHA_HORA_FIN)` de esa misma tabla
(`Novedad.sql:242-247`): siempre NULL, así que **toda corrida del AS-IS es
FULL** y la lógica DELTA es código latente nunca ejercitado. Además
`_140.BTQ` declara `FncUpdate_LogTD` (`:47-61`) y no la llama (`:853-858`).
Hemos construido el control desde cero sobre el patrón `unif_control`, que sí
está certificado. **Hay que confirmar que el TO-BE quiere delta de verdad**, y
no la recarga completa que el AS-IS hace en la práctica.

---

## 6. Dominio ACTIVIDAD ECONÓMICA: un catálogo más, y dos columnas en blanco

El segundo dominio ya está portado
(`sp_novedades_actividad_economica_edf.sql`, del legado
`PRO_Novedad_Linea_Historial`, `Novedad.sql:1060-1420`) y corre en Redshift
real. Produce las ocho columnas del contrato y **dos salen NULL por el mismo
motivo que las de Ubicación: falta el catálogo.**

| Catálogo del legado | ¿Entregado? | Columna que bloquea | Cita |
|---|---|---|---|
| **`V_ACTIVIDAD_ECONO_CIIU`** | **no** | `ACTIVIDAD_ECONOMICA` y `VERSION` | `Novedad.sql:1352-1354` |
| `V_Hom_Tip_Ident_Linea` | **no** (ya pedido en §1) | `TIPO_IDENTIFICACION` | — |

**`V_ACTIVIDAD_ECONO_CIIU` no estaba en esta petición y es un olvido nuestro:**
no aparece en los diez CSV de `novedades_mapeo_y_catalogos.zip` y tampoco se
había pedido. Se pide ahora, en el mismo formato que el resto.

**Lo que NO se pide, para no confundir una divergencia con un dato que falta:**

- **`V_PERSONA_ACT_ECONOMICA_CIIU`.** El legado arma su universo de ahí y trae
  `COD_DW_ACT_ECONO_CIIU`, `FECHA_REPORTE` e `INFO_BASICA_ID` por fila.
  Nosotros lo sacamos de `v_xpm_ciiu_persona`, que son **dos** columnas
  (`02_vistas_insumo_edf_views.sql:364-370`), y el CIIU viene directo del
  datashare en `bestpersonalinformation.mainisiccodeforproduct`. Funciona; no
  hay nada que pedir.
- **`V_Persona_Juridica_Camara`.** El legado hace
  `COALESCE(VPAE.FECHA_REPORTE, VPJC.Fecha_Matricula)` (`:1355`). Esa vista no
  está en el datashare y la rama de `Fecha_Matricula` no se porta. **Es una
  divergencia de grano, no un catálogo:** nuestro único fechado es `cutoffdate`,
  que vive por ubicación, así que agregamos con `MAX` por persona. Lo que
  escribimos es *"la fecha más reciente en que se vio a la persona"*, no la del
  reporte de su CIIU. Si el TO-BE necesita el grano fino, hay que pedir la
  vista; si no, esto es lo que hay y queda documentado.

**(d) ~~ABIERTA — la tabla final sólo crece, y es del legado.~~ CERRADA 2026-10-20: falso. `111.BTQ:823` vacía la tabla antes de cada carga; lo que sigue describe el UPSERT sobre una tabla ya vacía.** El UPSERT de
`130.TPT` no actualiza nunca en este dominio: el `ID` se asigna como
`MAX(ID) + SUM(1) OVER (ROWS UNBOUNDED PRECEDING)` sobre la tabla viva
(`120.TPT:177`), de modo que cada fila preparada estrena un `ID` por encima del
máximo y el `UPDATE … WHERE ID = :IN_ID` (`:722`) no encuentra nada; el
`INSERT FOR MISSING UPDATE ROWS` (`:750`) inserta siempre. Y el `DELETE` de
`:753` es código muerto, porque ninguna rama de su Severidad devuelve 2
(`120.TPT:186-197`) — el mismo patrón que el `FLAG_OP = 'E'` de §5(b).

**Hoy no se nota** porque `ACTIVIDAD_ECONOMICA` y `VERSION` salen NULL y la
comparación de Severidad da falso. **El día que llegue
`V_ACTIVIDAD_ECONO_CIIU`, una persona cuyo CIIU cambie de descripción acumulará
una fila nueva en cada corrida.** Lo reproducimos literal, como el resto, pero
esta es la decisión funcional que hay que tomar **antes** de entregar el
catálogo, no después.
