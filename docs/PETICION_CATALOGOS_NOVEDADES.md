# Petición de catálogos y columnas para Novedades — dominio Ubicación

**SLCOPRBA-1355.** Qué falta para que `MAT_INFO_UBICACION` salga completa, por
qué falta, y qué columna concreta desbloquea cada cosa.

El port de `PRO_Novedad_Linea_Ubicacion` está hecho y corre: produce las 42
columnas del contrato. **Cinco de ellas salen NULL** y dos CSV entregados
llegaron truncados. Nada de esto se resuelve escribiendo código.

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
| **`V_Hom_Tip_Ident_Linea`** | **no** | `TIPO_IDENTIFICACION` | `NOV-UB-18` |
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
| 1 | `Salida_Geo.pdf` (contrato de 32 columnas con su orden) | `BARRIO`, `ESTRATO`, `LOCALIDAD`, `CODIGO_POSTAL` — y de paso `ZONA` y `tipo_via`, que también viajan en ese contrato |
| 2 | Los cuatro catálogos de homologación a Línea | `TIPO`, `ZONA`, `TIPO_IDENTIFICACION` y la fuente de la etapa 2 |
| 3 | `V_TELEFONO_FIJO`, `V_TIPO_CORREO`, `V_DIRECCION_ELECTRONICA`, `V_ZONA_UBICACION`, `V_Tipo_Via` | `INDICATIVO`, `TIPO_CUENTA` |
| 4 | Reexport completo de `V_Geografia` y `V_Cod_Entrega_Dato` | los dominios que faltan por portar |

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
