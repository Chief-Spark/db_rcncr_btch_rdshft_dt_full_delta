# Bitácora de diferencias Teradata ↔ Redshift

Exigida por el RF de Ordenamiento (G-01 a G-03, CA-M02) y aplicada a los cuatro procesos. **Toda diferencia entre el requerimiento (RF), el código legado (AS-IS) y Redshift va aquí.** Ninguna se resuelve en silencio en el código.

## Cómo se lee

**Tipo (G-01):**

| Tipo | Significado |
|---|---|
| **a** | **Paridad de migración.** Redshift hace lo mismo que el código Teradata. Si el RF dice otra cosa, la diferencia es con el RF, no con el AS-IS |
| **b** | **Cambio funcional.** Redshift hace algo distinto a propósito. Requiere aprobación funcional (G-02) |
| **c** | **Asunto técnico pendiente.** Todavía no se puede decidir: falta un dato, un catálogo o una medición |

**Estado:**
- `ABIERTA`: sin decisión.
- `DECIDIDA`: decisión técnica tomada, falta la aprobación funcional.
- `APROBADA`: aprobada por el área funcional (G-02).
- `CERRADA`: resuelta, sin diferencia.

**Responsable:** quien tomó la decisión. "Usuario (sesión)" es una decisión tomada por el líder técnico durante la sesión de trabajo.

**ESTA BITÁCORA ES PARTE DE LA ENTREGA, no un anexo.** La meta del proyecto no es que Redshift dé un resultado idéntico a Teradata, sino **similar, con cada diferencia decidida y escrita** (usuario, 2026-10-21). Así que una diferencia que aparezca con datos reales no bloquea: se decide, se documenta aquí con su cita, y se sigue.

*(Esta nota decía antes "Ninguna fila está APROBADA todavía". Dejó de ser cierto: el usuario ha aprobado varias en sesión -- el umbral `>= 0.80` de D-EDF-12, el género de D-EDF-14, D-EDF-16 y las tandas T1 a T5 --. Lo que sigue en pie es que la aprobación FORMAL del área funcional (G-02) está pendiente para todas.)*

Prefijos de evidencia: `CAR` = `legado_teradata/reconocer/ordenamiento/Caracteristicas.txt` (numeración CR+LF salvo que diga LF), `NOV` = `…/novedades/DB/Novedad.sql`, `UNI` = `…/unificacion/DB/Unificacion.sql`.

---

## Ordenamiento: RF contra código legado

El RF describe algo distinto de lo que hace el código Teradata. El repo sigue al código (regla 4 del `CLAUDE.md`), pero sin aprobación formal.

| ID | Tema | RF dice | Código legado | Redshift | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|---|
| D-ORD-01 | F3-06 actualización de hash | los registros modificados se actualizan | `UPDATE` comentado "por solicitud de Experian" (`FINAL_UBIC_DIRECCIONES.sql:216`, `FINAL_CTA_ATRIBUTOS.sql:200`) | solo inserta; el cambio deja una segunda fila | a | DECIDIDA | paridad con el código · equipo (SLCOPRBA-1355) · 2026-10 |
| D-ORD-02 | F3-09 cuentas ICBDIR | solo ubicaciones con cuentas activas ICBDIR | `ICBDIR` no aparece en todo el legado | no se filtra | a | ABIERTA | criterio BLOQUEADO; hay que preguntar al área funcional de dónde sale la regla |
| D-ORD-03 | F3-10 ubicaciones NO VALIDA | no se ordenan las no válidas | `NO VALIDA` solo existe en F4 (divisor DIR, `CAR` CR1950-1954) | no se filtra en F3 | a | ABIERTA | ídem |
| D-ORD-04 | F4-TEL-02 TEL010 | % de reportes con coincidencia geográfica | cuota de la ventana ≤12 sobre `Total_Reportes_12` (`CAR` CR2972-2977) | igual que el código | a | DECIDIDA | paridad · equipo · 2026-10 |
| D-ORD-05 | F4-CEL-03 CEL014 | indicador de cuenta POSPAGO | cuota de la ventana >24 (`CAR` CR2450-2453); `POSPAGO` no aparece | igual que el código | a | DECIDIDA | paridad · equipo · 2026-10 |
| D-ORD-06 | F4-EMA-02 EMA014 | dominios gmail, hotmail, yahoo, outlook | **cinco**: también `live` (`CAR` CR1091) | igual que el código | a | DECIDIDA | paridad · equipo · 2026-10 |
| D-ORD-07 | F4-CEL-06 operador no mapeado | valor por defecto definido funcionalmente | `MAX(valor)` NULL → categoría 0 | igual que el código | c | ABIERTA | falta la definición funcional del valor por defecto |
| D-ORD-08 | F1-05 / CA-T03 tablas intermedias | 14, se eliminan al final de **cada fase** | 14 en el legado | 18, se eliminan al **final del ciclo** (F3 deja los insumos que lee el Scoring) | c | DECIDIDA | técnica: el borrado por fase rompería la dependencia F3→F4 · equipo · 2026-10-20 |

## Ordenamiento: Redshift contra código legado

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-ORD-10 | **Ranking por canal** | lugar por canal, un valor por RPU (`P0027_130.TPT:136-145`); el RF lo exige (§2, CA-F01) | `rpu_orden_prioridad = MIN(lugar)` **mezclando canales**; el lugar va a una sola RPU por valor | — | ABIERTA → **defecto** | corregir en F5 (lugar por canal y por RPU) · plan aprobado · 2026-10-20 |
| D-ORD-11 | `V_Operador_Ord_Cel` | 20 filas reales | 16 valores inventados | — | DECIDIDA → **corregido en código** (F2, local) | cargado el real en `strct/02_catalogos_ordenamiento.sql`. Mueve el ARQ 83 del mock, que se sembró sobre los valores inventados · usuario (sesión) · 2026-10-20 |
| D-ORD-12 | Versión de Betas por corrida (G-06) | — | no se registra | — | DECIDIDA → **brecha** | `version_betas` en `ord_control` (F3) · plan · 2026-10-20 |
| D-ORD-13 | Compuerta `TEL022_cat > 0` del ranking TEL | sí (`CAR` CR1213) | no | c | ABIERTA | depende de que GEO entregue coincidencia; portarla hoy vaciaría TEL |
| D-ORD-14 | Sobrescritura 999999 por CONTACTABILIDAD en CEL | sí (`CAR` CR2907) | no | c | ABIERTA | la contactabilidad no está en EDF (verificado 2026-10-20) |
| D-ORD-15 | `sector_financiero` | sector por cuenta en `{CO,CC,RE,FI,OT}` | bandera 0/1 a partir de una cubeta de hash | c | ABIERTA | conectar `economicsector` o `businesslinecode` de EDF tras la consulta C14 · 2026-10-20: `economicsector` (catálogo 180, grano suscriptor) es F financiero y R real, CONFIRMADO en Confluence; ~~la C es Cooperativo (PROBABLE alto)~~ **CORRECCIÓN 2026-10-21 (C32c): C = Telecomunicaciones** (`219_ECONOMIC_SECTOR_HO`: F financiero, O cooperativo, R real, C telcos; 180 y 308: tipos de cuenta 06 y 27 = C). HIPÓTESIS para el puente con el legado: F → FI, R → RE, C → CC (comunicaciones), O → CO (cooperativo). Falta medir con C30 cuántos reportes lo encuentran por el NIT del suscriptor |
| D-ORD-16 | Censo de residuales (F1-05) | — | revisaba 17 tablas; faltaba `stg_ord_cta_vector`, que el drop sí borra | c | **corregido en código** (F2, local) | lista de 18 en `19_sp_ordenamiento_ciclo.sql`. El espejo mock (`sp_ordenamiento_ejecucion_mock.sql:301-319`) conserva la lista de 17, por la regla de tocar solo SP reales · 2026-10-20 |
| D-ORD-17 | Bootstrap | — | solo si se pedía DELTA; un FULL inicial quedaba con `bootstrap = FALSE` | c | **corregido en código** (F2, local) | misma regla que Unificación (`16_sp_unificacion_ciclo.sql:167-178`) · 2026-10-20 |
| D-ORD-18 | `sp_ordenamiento_ejecucion_edf` | — | no corría F2 ni F3; los docs lo llaman con 1 parámetro y la firma pide 4 | c | **corregido en código** (F2, local); se retira en F4 | añadidas las llamadas a cuentas y ubicaciones · 2026-10-20 |

## Unificación

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-UNI-01 | NIT en la R2 | `Nombre_Tipo_Ident LIKE '%Nit%'` (`UNI:2210`, `:2393`) | cableado `'3'`; en EDF el NIT es **2** (43.735 filas contra 5; el 3 es Persona Jurídica del Extranjero en ID Type NH) | — | **corregido en código** (F2, local) | `'2'` en `sp_unificacion_r2_esc3_…` y `_motor_nit_…`. El espejo mock conserva el `'3'` porque sus semillas lo siembran así · confirmado con datos y catálogo · 2026-10-20 |
| D-UNI-02 | Llave de la ubicación | RPU 1:1 con su contacto | `ci.id` = un **reporte** con ~4 contactos de distinto tipo | c | DECIDIDA → **confirmada con datos** | C4: `(id, index)` única en los 568.544 contactos reales; 136.146 reportes traen 4 tipos. Pasar a `(id, index)` y re-certificar · usuario (sesión) · 2026-10-20 |
| D-UNI-03 | `REPORTE_UNIFICACION_DIRECCION` | histórico diario (`P0019_130.TPT:147-185`) | no existe | c | ABIERTA | decidir si el Batch o En Línea lo necesitan |
| D-UNI-04 | Severidad | 1 o 3, con `COD_RECHAZO` | siempre 1 | c | ABIERTA | |
| D-UNI-05 | Insumo de la R1 por Documento Funcional | el docx iguala departamento, localidad, zona y estrato | el código no los usa | a | DECIDIDA | manda el código (regla 4) · equipo |
| D-UNI-06 | `Cod_DW_Municipio` frente a ciudad | ciudad de 8 dígitos (centro poblado) ≠ municipio de 5 | el mismo valor | — | **corregido en código** (local) | `cod_dw_municipio = cod_dw_ciudad / 1000` · usuario (OK 2026-10-20) |

## Novedades

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-NOV-01 | Contrato de carga | `DELETE … ALL` de las 7 `MAT_*` y recarga; delta contra `BK_*` (`111.BTQ:817-836`, `120.TPT:455-602`) | UPSERT incremental, nunca borra | b | DECIDIDA | **foto completa + delta, como el AS-IS** · usuario (sesión) · 2026-10-20 |
| D-NOV-02 | Cinco columnas de Ubicación en NULL/0 | literales (`NOV:8358-8363`) | iguales | a | DECIDIDA | se reproduce el legado · equipo (SLCOPRBA-1355) |
| D-NOV-03 | Fuente | `V_FUENTE` o `'CAM'` (`NOV:8635`) | `'CAM'` literal siempre | — | ABIERTA → **defecto** | portar el join a `V_FUENTE` (F6) |
| D-NOV-04 | `INFO_BASICA` | `Id_Buro_Persona` | `CAST` a INTEGER de un hash de 64 bits: **probablemente aborta con datos reales** | — | **corregido en código** (local) | BIGINT en `stg_nov_ubica_etapa_9` (DROP + CREATE, es staging) y en `mat_info_ubicacion` (migración condicional `sp_rcn_ctl_nov_migrar_info_basica`, que conserva los datos y no hace nada si ya es BIGINT). Probado en el banco: Novedades real completa con ids fuera de INTEGER · usuario (OK 2026-10-20) |
| D-NOV-05 | CIUDAD y DEPARTAMENTO | `COALESCE(…,'')` (`NOV:8354-8355`) | NULL | — | **corregido en código** (local, 2026-10-21) | `COALESCE(…, '')` en la etapa 9 de `sp_novedades_ubicacion_edf`; espejo mock regenerado con la herramienta. Banco aislado con datos sintéticos: las 4 filas sin ciudad salen con `''` y la etapa 2 ya les pone contadores (antes NULL) |
| D-NOV-06 | Universo de Actividad Económica | todas las actividades de Info Básica (`NOV:1288-1291`) | solo el CIIU principal | — | ABIERTA → **defecto** | F6, con `personalinformation` y `chamberofcommerce` |
| D-NOV-07 | Mosaic | dominio de Info Básica; `140.BTQ:515-527` lo exige para exportar | excluido por decisión legal | b | DECIDIDA | excluido · decisión legal · hay que rehacer la validación de extractos |
| D-NOV-08 | Contactabilidad (d5) | `V_CONTACTABILIDAD`: log de eventos de gestión, una de las seis fuentes del buró (`V_Fuente`, `Cod_Dw_Fuente = 31937`), resumido en siete etapas (`NOV:186-1059`) | **la tabla se entrega con 2 de 12 columnas pobladas y las otras 10 en NULL.** `fecha_ultimo_contacto` ← `ContactEventLastUpdated` (última **actualización del dato**, no último contacto) y `reportado_por` ← suscriptor que **reportó**, no el que gestionó | c | **DECIDIDA** | **usuario, 2026-10-21**, sabiendo que las dos columnas cambian de semántica. Las otras diez quedan en NULL y no en un valor por defecto: un `'NO'` en `contactabilidad` diría "se intentó y no se pudo". No está en `edf_views`, ni en la documentación de EDF (sección `contactInformations`: nueve campos, ninguno de gestión — Confluence `CCBR` 251264536), ni hay cargador de la fuente 31937 en el material entregado. La petición sigue abierta |
| D-NOV-09 | Info Básica (d4) | doce etapas que eligen por persona el valor **más confiable** de cada atributo, con `COALESCE(valor_2, valor)` (`NOV:3447-3466`) | **no se portan: en EDF la elección ya viene hecha** (`bestName`, `bestIdentifications`, `bestPersonalInformation`). 19 de 22 columnas pobladas | b | **DECIDIDA** | re-especificación, misma forma que la Fase 1 del Ordenamiento. Las tres que faltan: `TIPO_IDENTIFICACION` (falta `V_Hom_Tip_Ident_Linea`, C37), `PAGINA_WEB` (**no existe en EDF**: `WebSite` está marcado *NO APLICA* en el contrato Alpha, Confluence `CCBR` 251264543) y `MOSAIC_ID` (decisión legal, D-NOV-07). Divergencia menor anotada: con varias identificaciones elegimos la validada contra fuente oficial y el legado su propia cascada |
| D-NOV-10 | Razón social | columna propia de `VU_PERSONA` | **derivada**: `bestname.fullname` cuando el tipo de documento es NIT (2), NULL en otro caso | c | DECIDIDA | en EDF no hay campo aparte — el nombre completo de una persona jurídica *es* su razón social. Riesgo anotado: un NIT con `fullname` vacío sale NULL donde el legado traería el valor |
| D-NOV-11 | Punto de interés (d7) · llave | `COD_DW_UBIC_PUNTO_INTERES`, la llave de la fila de relación (`NOV:4793`) | **derivada**: `FNV_HASH(cod_dw_ubic \| tipo_punto_interes \| cod_punto_interes_host)`, la clave 1:N del contrato Salida_Distancias | c | DECIDIDA | esa llave no viaja en el contrato. Mismo patrón que `cod_dw_persona_ubic` desde `(id, index)`. El **valor** no coincide con Teradata; la **identidad** de la fila sí, y es estable entre corridas, que es lo que el UPSERT necesita. Medido: 2.000 ids distintos para 2.000 filas, sin colisión |
| D-NOV-12 | Punto de interés · tres columnas sin fuente | `TIPO` de `V_Hom_Tipo_Pto_Int_Linea` (`NOV:4888-4890`); `NOMBRE_ENTIDAD` y `NIT_ENTIDAD` de `RELACION_PUNTO_INTERES_X_PERS` (`NOV:4801-4802`) | **NULL** | c | ABIERTA | el `TIPO` es un join en cuanto llegue el catálogo: el valor de entrada (`cod_punto_interes_host`) ya lo tenemos. Las dos de entidad **no viajan en el contrato de distancias**: son petición, no código. `Descripcion_Tipo_Punto_Interes` lleva el valor **crudo** del contrato en vez de la descripción de `V_TIPO_PUNTO_INTERES` |
| D-GEO-08 | Nombre del punto de interés | `col08` del contrato Salida_Distancias | **llegaba y se tiraba**; `geo_distancias` no tenía columna | — | **corregido en código** (2026-10-21) | columna `nombre_punto_interes` añadida (+ migración aditiva en `sp_rcn_ctl_obs_migrar`) y persistida en el cargador, **sin entrar en ningún predicado de validación** para no mover el conteo de rechazo que miden los criterios GEO. Medido: 2.800 distancias, 2.800 con nombre, y los cinco `CA-0x` intactos. **Corrige la nota del tablero** que decía *"el contrato de distancias no persiste el nombre"*: el contrato sí lo trae |
| D-NOV-13 | Tipo de identificación homologado | `V_Hom_Tip_Ident_Linea` por `Valor_Fuente` (`NOV:3455`, `:3475-3476`, `:8406`) | **portado el 2026-10-21**: el catálogo llegó (11 filas) y se carga en `bdm_datos.catalogo_hom_tipo_ident` | — | **corregido en código** | tres consumidores que escribían NULL: `mat_info_basica` (d4), la etapa 9 de Ubicación (`NOV-UB-18`) y Actividad Económica (`NOV-AE-07`). Va por **`LEFT JOIN`**, como el legado: un tipo ausente del catálogo sale NULL y **no pierde la fila**. `valor_fuente` se declara `VARCHAR(20)` y no `INTEGER` — el legado lo usa como llave de texto y castear reabriría el job #293. Los once valores cubren 0..10 sin huecos |
| D-NOV-14 | Movilidad (d6) · el productor que falta | `REC_STAGE.MTCalcularIndicadoresMovilidad`, cuyo **productor no está en el material entregado** (`MANIFIESTO.md:68` ya lo listaba) | **construido como `nov_movilidad_foto`**: una foto insert-only de los tres atributos por `(persona, ubicación)`, y el evento sale de comparar las dos más recientes | b | **DECIDIDA** | no sirve `ubicacion_atributo_hash` de la Fase 3: dice **que** algo cambió pero no **qué** — guarda el MD5, no los atributos. Añadírselos sería tocar una tabla certificada de otra fase |
| D-NOV-15 | Movilidad · tres de los cuatro indicadores | `Cambio de Direccion`, `de Estrato`, `de Ciudad` y `de Localidad` (`P0029_INDICADORES_MOVILIDAD_111.BTQ:62-68`) | **tres**: falta `Cambio de Localidad` | c | **DECIDIDA** | `LOCALIDAD` / comuna **no existe en EDF por ninguna vía**: buscado en el inventario de 1.072 columnas del datashare y en Confluence (`CCBR`, `EDCLMI`). Se puede entregar a tres porque la tabla es de **eventos**: la ausencia de fila es *no se detectó*, no *no cambió* |
| D-NOV-16 | Movilidad · el `ID` | `COD_DW_PERSONA_IND_MOVIL`, correlativo de `REC_MTDAT.MAX_ID` (`P0029:75`) | **derivado**: `FNV_HASH(persona \| indicador \| fecha)` | c | DECIDIDA | no tenemos esa secuencia. Mismo patrón que el `id` de d7 (D-NOV-11): el **valor** no coincide con Teradata, la **identidad** de la fila sí |
| ~~D-NOV-17~~ | Movilidad · dos columnas sin catálogo | `DESCRIPCION` de `V_INDICADOR_MOVILIDAD` (`NOV:1782`) y `NOVEDAD_2` de `V_Hom_Ind_Mov_Linea` (`:1923-1924`) | ~~NULL~~ **pobladas** | c | **CERRADA 2026-10-22** | llegaron los dos volcados (`26_ddl_catalogo_movilidad.sql`). d6 pasa de 6 a **8 de 8** columnas. **`NOVEDAD` ya se poblaba** con los literales que el propio P0029 escribe en su `WHERE`, y resulta que ese literal es además la **llave** de los dos joins |
| D-NOV-18 | Movilidad · el duplicado de `V_INDICADOR_MOVILIDAD` | la vista trae **cinco** filas y **cuatro** indicadores: `Cambio de Direccion` viene dos veces (71948 y 77295, misma frase salvo la tilde). El legado no lo nota porque une por `COD_DW_INDICADOR_MOVILIDAD`, que es único | se carga **deduplicado**, por `MIN(Cod_DW_Indicador_Movilidad)` = 71948 | c | **DECIDIDA 2026-10-22** | nosotros no tenemos ese código — las ramas salen de literales — y tenemos que unir por el nombre corto: con las cinco filas cada evento de dirección se **multiplicaría por dos**. 71948 es además el de la banda `719xx` de los otros tres y el único cuyo texto es ASCII |
| D-NOV-19 | Punto de interés · la llave del catálogo de tipo | el legado une `V_Hom_Tipo_Pto_Int_Linea` por `VTPI.Cod_Tipo_Punto_Interes_Host` (`NOV:4891`), columna de `V_TIPO_PUNTO_INTERES` | se une por `geo_distancias.tipo_punto_interes` (`col07` del contrato `Salida_Distancias`) | c | **ABIERTA · hipótesis** | `V_TIPO_PUNTO_INTERES` es el único de los cuatro catálogos que **no** se entregó. Los 34 `Valor_Fuente` son códigos **SIC** de cuatro dígitos (3578 cajero, 6000 banca, 5800 restaurantes), que es la taxonomía de ArcGIS. **No probado**: en mock `geo_distancias` está vacía y en DEV no ha llegado archivo real. Riesgo nulo al cablearlo: va por `LEFT JOIN`, una llave errónea deja NULL — que es donde estaba — y nunca un valor equivocado. La consulta que lo cierra está en la cabecera de `27_ddl_catalogo_hom_tipo_pto_int.sql` |
| D-NOV-20 | Punto de interés · `V_Corr_Tipo_Pto_Int_Linea` no se porta | el legado la une (`NOV:4886-4887`) | **no se porta ni se pide** | c | **DECIDIDA 2026-10-22** | es un **join muerto**: no proyecta ni una columna suya, igual que `TMP_UBICA_ETAPA_0`. Pedirla gastaría un viaje |

## Transversales y datos de EDF

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-EDF-01 | Bloqueo | registro en `V_BLOQUEO`, cualquier razón | `bloqueado = 0` literal | b | **corregido en código** (local; suscriptor y cuenta, 2026-10-20) | bandera en la RPU y filtro en `v_xpm_contacto_canal` · usuario (OK 2026-10-20) · 2026-10-20: **negocio confirma la regla** (lo bloqueado no se muestra; el campo de bloqueo es a nivel de suscriptor). Pendiente con Experian: si el bloqueo **de cuenta** llega propagado a `location` o hay que leerlo de `xpm_bestaccounts` · 2026-10-20, Confluence (`edf_views/RESULTADOS_CONSULTAS_EDF.md` §18): el bloqueo de `location` es **del suscriptor**; la regla (b) de CCBR, "estado 0 y razón 2 o 5", excluiría 391 filas frente a nuestras 436, y la regla se mantiene hasta que Experian confirme. El bloqueo **de cuenta** vive en `bestAccounts.blockSeverity = 1` y se filtra solo al servir productos: el datashare probablemente no lo trae aplicado. Se mide con C31 antes de tocar código · **2026-10-20, CORRECCIÓN (legado):** el `V_BLOQUEO` del AS-IS es bloqueo **de cuenta**, no de suscriptor: su catálogo `V_Razon_Bloqueo` habla de la historia de crédito (reclamos, fraude, prescripción, obligaciones cerradas; `catalogos/BDM_VISTA - V_Razon_Bloqueo.csv`) y excluye la RPU entera en Unificación (`P0021_UNIFICACION_111.BTQ:96`, `V_Insumo_Unificacion_Regla1.txt:34-37`), Novedades (`Novedad.sql:7590`) y Ordenamiento (`Prc_Ordenamiento2.sql:1122-1126`). Su equivalente en EDF es `bestAccounts.blockSeverity`, no el `blockReason` de `location`. ~~Propuesta: cuenta con `blockSeverity` ≠ 0, o suscriptor con estado 0 y razón 2 o 5~~ **Propuesta corregida tras leer Alpha (pendiente de OK):** (1) **suscriptor:** se mantiene la regla actual, estado 0 (= bloqueado, CONFIRMADO), 436 filas en DEV; la regla "razón 2 o 5" es para cálculos agregados del XPM, no para mostrar datos; (2) **cuenta:** `blockSeverity = 1` (indicador 1-7, las siete razones que el legado no muestra en la historia de crédito), que es lo que Experian quita de LOCATION a sus productos; la severidad 2 mezcla una razón que se oculta y otra que se muestra y se pregunta a Experian. Medir con C31 antes de tocar la vista · **IMPLEMENTADO (OK del usuario, 2026-10-20):** `bdm_tempo.v_xpm_cuenta_bloqueada` (una fila por llave) la leen `v_xpm_contacto_direccion` (bandera `bloqueado`) y `v_xpm_contacto_canal` (filtro). Probado en el banco con datos sintéticos: severidad 1 bloquea; severidad 2, sin cuenta y cuenta de otra persona no. C31 sigue pendiente para saber cuántas filas caen en DEV · **C31 (2026-10-21):** la severidad 1 oculta 35 reportes en DEV; la 2 deja pasar 22. La severidad 2 junta el indicador 8 (reclamo sin solución, el legado no lo muestra) y el 9 (cuenta sin validar, el legado sí lo muestra). Recomendación: separarla con `bestaccounts.blockreason` si trae el indicador (C34); si no lo trae, se queda como hoy y se pregunta a Experian · **C34 v2 (2026-10-21): no lo trae** (severidad 2: 25 cuentas, todas con razón `0`). Se queda la regla actual (solo severidad 1). Pregunta a Experian: en qué campo viene el indicador 8 o 9 de la severidad 2 · **C33 v2 (2026-10-21): la llave de 5 campos casa solo en 278 de 6.850 reportes de suscriptor (4 %), y el número de cuenta en 5.524 (81 %).** El bloqueo de cuenta ve hoy una fracción; C33b localiza el campo con otro formato antes de tocar la vista |
| D-EDF-02 | Código DANE | 8 dígitos, texto | `INTEGER` (pierde el cero) y hash de `cityname` cuando falta | — | **corregido en código** (local) | sin DANE: `citycode * 1000` y después Divipola por nombre (clave exacta y esqueleto de consonantes, con y sin departamento, solo si apunta a una cabecera). Catálogo `24_ddl_catalogo_divipola_cabecera.sql`. Nunca un hash · usuario (OK 2026-10-20) |
| D-EDF-03 | Número de entidades | `COUNT(DISTINCT suscriptor)` | `counterparties` a nivel persona y cubeta de hash | — | **corregido en código** (local) | tres niveles: reporte → contraparte única de la persona → NULL. El nivel 2 se revisa con C19 · usuario (OK 2026-10-20) |
| D-EDF-04 | `fecha_reporte` faltante | NULL | `CURRENT_DATE` | — | DECIDIDA → **defecto sin impacto hoy** | C16: `cutoffdate` en el 100 % de los reportes reales; la caída solo toca arreglos vacíos. NULL por higiene |
| D-EDF-05 | Contrato de respuesta GEO (georreferenciación) | layout P0006 (30 columnas: Status 28, latitud 12, longitud 13; las 26-27 son Mosaic) | antes: Status en col03 y latitud/longitud en col05/col06 (se rechazaba el 100 %) | — | **corregido en código** (local, 2026-10-20) | `Salida_Geo.pdf` (Experian): 32 columnas, latitud 12, longitud 13, Status 26. Su registro de ejemplo trae 33 campos con el Status en la 27, así que el cargador acepta las dos formas: staging de 33 columnas con `FILLRECORD` y Status en 26, o en 27 si la 26 no es M/U. **Pedir un archivo real** para fijar la posición · usuario (OK 2026-10-20) |
| D-GEO-01 | Rutas de ArcGIS en el wrapper | — | el slot 5 se lee como Lote y como ruta de distancias (`sp_geo_ciclo_lote_wrapper.sql:68,79`); el Framework manda un solo valor (`step_function_definition_builder.py:93`) | c | ABIERTA | depende de dónde deja ArcGIS los dos archivos (D-EDF-05); no es una corrección sin dependencias |
| D-GEO-02 | Lote de las parejas del reenganche | — | la R3 del reenganche sella con el Lote GEO (`MAX+1` propio, `sp_geo_exportar_insumo.sql:298`), que no es la numeración del Lote de Unificación | c | ABIERTA | pide `corrida_id` o el Lote de origen en `geo_lote_control` (DDL de F3) |
| D-GEO-03 | Contrato de respuesta GEO (distancias) | — | antes: Descripcion_Proceso en col03, tipo y host en col04/col05, coordenadas en col06-col09, distancia en col10 (se rechazaba el 100 %) | — | **corregido en código** (local, 2026-10-20) | posiciones de `Salida_Geo.pdf` §3: latitud y longitud 4-5, descripción 6, tipo 7, punto de interés 9-10, distancia 11, host 12. El nombre del punto de interés (col 8) no se guarda: `geo_distancias` no tiene columna y va con Novedades d7 · usuario (OK 2026-10-20) |
| D-GEO-04 | Rango de `cod_dw_ubic` en la carga GEO | — | antes: el cargador exigía que cupiera en INTEGER; desde D-EDF-07 la llave es `FNV_HASH` de 64 bits, con signo | — | **corregido en código** (local, 2026-10-20) | rango y cast a BIGINT; probado en el banco con llaves negativas de 19 dígitos. **Queda pedir** que ArcGIS conserve la llave como texto o BIGINT, con signo: el PDF la declara INTEGER en el archivo de georreferenciación y BIGINT en el de distancias |
| D-GEO-05 | Tope de 850.000 registros por envío | `Insumo_GEO.pdf`: máximo 850.000 por ejecución | **ya se cumplía**: `max_records = 850000` en `geo_config`, aplicado con `ROW_NUMBER` (`sp_geo_exportar_insumo.sql:250,280`). Esta fila decía antes que no había tope, y era falso | — | CERRADA | lo que pasa del tope no recibe Lote y sale en la corrida siguiente |
| D-GEO-06 | GEO bloqueaba Unificación | — | antes: un `RAISE` del envío (configuración ausente, cuenta AWS distinta, `maxfilesize` no numérico) abortaba la corrida entera (`16_sp_unificacion_ciclo.sql`, bloque único). Y nadie buscaba resultados: los cargadores esperaban un orquestador externo que no existe | b | **corregido en código** (local, 2026-10-20) | regla de negocio: **GEO no es restrictivo**. El envío y la búsqueda de resultados (`sp_rcn_geo_02_buscar_resultados`, nuevo) van cada uno en su bloque; un fallo deja la traza `geo` en `fallido` y la corrida sigue con la R3. La búsqueda hace COPY de `reconocer_output/geo_result_*` y `distancias_result_*`, y carga los Lotes en espera que tengan filas; sin archivo, los Lotes siguen en `exportado`. Probado en el banco: export con error, UNLOAD fallido y COPY fallido terminan con Unificación `completado` · usuario (OK 2026-10-20) |
| D-GEO-07 | Defectos del ciclo GEO encontrados al revisarlo | — | A: distancias exigía un estado que la georreferenciación ya había cambiado y no cargaba nunca; además pisaba `conteo_cargado`. D: un Lote no `cargado` (p. ej. un UNLOAD fallido) excluía sus candidatos para siempre. F: un `maxfilesize` no numérico abortaba antes del control. B: `sp_geo_ciclo_lote` declara éxito si el Lote sigue en `exportado`. E: el wrapper lee el slot 5 como Lote y como ruta | — | A, D y F **corregidos en código** (local, 2026-10-20); B y E ABIERTOS | D: solo se excluyen los Lotes en curso; `fallido`, `fallido definitivo` y `vencido` vuelven a exportarse, y un `exportado` sin respuesta en `dias_espera_arcgis` días (7) pasa a `vencido`. B y E son del camino asíncrono con orquestador, que hoy no se usa |
| D-EDF-07 | `cod_dw_ubic` | la ubicación (maestro de direcciones) | `loc.id`, el arreglo de la **persona** (`02_vistas…:19`) | — | **corregido en código** (local) | `cod_dw_persona_ubic` = `(ci.id, ci.index)`; `cod_dw_ubic` = texto + DANE; la ubicación queda en una fila por lugar; los canales apuntan a la dirección de su reporte. Probado en el banco con datos sintéticos (`banco/vistas_reales_sinteticas.sql`) · usuario (OK 2026-10-20) |
| D-EDF-08 | Tipo 8 en el canal TEL | — | TEL = `IN ('4','5','8')` (`04_vistas…:125`, `sp_ordenamiento_ubicaciones_edf.sql:248`) | — | **corregido en código** (local) | `IN ('4','5')` en la vista 04 y en `sp_ordenamiento_ubicaciones_edf.sql` · usuario (OK 2026-10-20) |
| D-EDF-09 | Tipos 6, 10 y 11 | — | 6 y 11 no se leen; 10 se lee como EMAIL sin verificar | c | **corregido en código** (local) | C18 en DEV y QA: el 10 es correo, el 6 es teléfono (lo lee la propuesta A) y el 11 viene vacío (no se lee). CONFIRMADO con el catálogo oficial (D-EDF-06) · usuario (OK 2026-10-20) |
| D-EDF-10 | Teléfonos rellenados con ceros | `Texto_Ubicacion` sin relleno (el catálogo de operadores usa 300-350) | valor crudo de 12 dígitos (`00` + número); el operador sale `'003'` | — | **corregido en código** (local) | teléfonos a solo dígitos y sin el relleno en `v_xpm_contacto_canal`; el SP sigue sacando el operador en crudo, como el legado. Probado en el banco: CEL pasa de 0 a 3 con score · usuario (OK 2026-10-20) |
| D-EDF-11 | Tipo 6 sin leer | — | no entra a ningún canal | — | **corregido en código** (local) | columna `canal` en `v_xpm_contacto_canal`; el 4, 5, 6 y 13 van a CEL si tienen forma de celular (10 dígitos que empiezan por 3) y a TEL si no. El 4 y el 5 se sumaron tras C23 (~1 de cada 10 es celular; 866 en DEV y 11.128 en QA). PROBABLE: el catálogo da el uso del número, no la tecnología; los seis filtros de Ordenamiento leen `canal` · usuario (OK 2026-10-20) |
| D-EDF-06 | Mapeo `contacttype` | surrogates con abreviaturas RES/LAB/CRR/CCL/JUD | el 8 (Business Address) contado como CRR y el 7 (Legal Address) como un `'DIR'` inventado; 13 y 14 sin leer | — | **corregido en código** (local) | catálogo oficial de `contactType` (Experian, 2026-10-20; `edf_views/RESULTADOS_CONSULTAS_EDF.md` §16): el 8 pasa a CCL y el 7 a JUD con los códigos que ya tiene `tipo_ubicacion_dir`, sin DDL (**CONFIRMADO por el usuario el 2026-10-20**); se leen el 13 (TEL o CEL por la forma) y el 14 (EMA). Abierto: el tipo de Reconocer del 12 (Notification Address). La C23 ya se corrió (D-EDF-11) · usuario (OK 2026-10-20) · Confluence (§18): el 12 solo sale del RNT (`typeOfData` 20) y sin `cityCode`; ninguna página lo mapea a RES/LAB/CRR/CCL/JUD. Sigue sin leerse · Alpha (§18): es la "Dirección Notificación" del prestador turístico, con departamento y municipio en texto. En DEV no hay filas de 7, 12, 13 ni 14 (C24): baja prioridad |
| D-EDF-12 | Score de la dirección estandarizada | `V_Gestion_Registro` `VALIDA` / `NO VALIDA` (HIPÓTESIS: es el mismo concepto) | no se lee | b | **corregido en código** (local, OK del usuario 2026-10-20) | negocio: debe ser mayor a 80 %. Confluence: escala 0-1, 0.80 = urbana sin geografía confiable, 0.65 = rural; no documenta umbral. `> 0.80` deja fuera la 0.80 y las rurales; `>= 0.80` mete la 0.80. Medir con C24/C24b y preguntar cuál de los dos. Sin código hasta tener las dos cosas · usuario (2026-10-20) · **DECIDIDO (usuario, 2026-10-20): `>= 0.80`.** C24 en DEV: solo el tipo 8 trae score; 90.104 pasan y 44.978 no (33 %); los tipos 1, 2 y 3 no traen score. Propuesta (pendiente de OK): `< 0.80` = NO VALIDA; sin score = NULL, que el Ordenamiento cuenta como válida, igual que el legado · Alpha (514819903): el score de los tipos 1, 2 y 3 se añadió en septiembre de 2026 y aún no llega a DEV; cuando llegue, el filtro les aplica solo · **IMPLEMENTADO:** `descripcion_gestion_registro` en `v_xpm_contacto_direccion` (por reporte) y `v_xpm_ubicacion_estandarizada` (por lugar: el mejor score). Lo usan el divisor de DIR010FI/DIR013OT (`cnt_reportes_validos`), el hash de F3 (posición del legado) y el filtro de Novedades Ubicación (`Novedad.sql:7679-7680`; sin score pasa, DIVERGENCIA DECIDIDA). Mock: NULL, tablero sin cambios. Probado en el banco con datos sintéticos |
| D-EDF-13 | Estado del documento | `V_TIPO_IDENTIFICACION` / estado de la Registraduría | no se lee | — | **IMPLEMENTADA** (2026-10-21, con Info Basica d4) | usar `businessidstatus` (el homologado, el que usan los productos), no `idstatus`, con `LPAD(…, 2, '0')`. CC: 00 vigente, 21 cancelada por muerte (CONFIRMADO, Confluence). NIT: `01` = matrícula activa en la DIAN (CONFIRMADO, Alpha). El `00` es ambiguo, porque también es el valor por defecto cuando no viene (31 filas en DEV): preguntar · CC (C32c, catálogo 124): `00` y `01` = vigente; 12 y 14 → 00; 51 → 21; 52 → 26; 88 y 99 en trámite; el resto, cancelada |
| D-EDF-14 | Género | `V_GENERO.COD_GENERO_FTE`, primera letra (`M` / `F`) | no se lee | b | **IMPLEMENTADO** (2026-10-21) | `xpm."bestpersonalinformation.gender"` con el catálogo `93_GENDER_HO` (C32c): 0 desconocido, 1 masculino, 2 femenino, 3 no binario, 4 indefinido, 9 no aplica. **Usuario, 2026-10-21: 1 → M, 2 → F, 3 → O; el resto (0, 4, 9 y NULL) → vacío.** El `O` es un valor nuevo frente al AS-IS, que solo conocía M y F; el 4 va vacío aunque Collibra lo homologue a `-`. Implementado en `v_xpm_persona_basica`. Medido en el banco: las cuatro ramas con 2.500 filas cada una |
| D-EDF-15 | **Llave de cuenta y cobertura de `bestaccounts`** | la Fase 2 une la ubicación a la cuenta por `Cod_DW_Cta` (`Caracteristicas.txt:226`) | `v_xpm_cuenta_bloqueada` une por el contenedor más los cinco campos de Data Provisioning (`02_vistas_insumo_edf_views.sql:31-42` y `:226-232`) | c | **DECIDIDA → la llave es correcta; el dato no está** | C33b: ni un solo `ceros` ni `nulo` en 5.977 pares y longitudes iguales, **no es formato**. C39 (productor): el contenedor **NO es compartido** — 98.586 contenedores, todos con exactamente UNA persona, así que la hipótesis del contenedor queda **descartada**. La causa real es otra: `xpm_bestaccounts` trae **7.759 filas en solo 146 contenedores distintos**, o sea que **146 de 98.586 personas (0,15 %) tienen alguna cuenta**. Los 278 reportes que casan salen de esas 146. Dentro de un contenedor de ~53 cuentas, el número de cuenta se repite entre suscriptores: por eso al unir solo por número suben a 5.802 y difieren `businesslinecode` y `personidnumber`. Es colisión esperada, no un defecto. **Decisión (usuario, 2026-10-21): la F2 real se queda parada** y `v_xpm_cuenta` sigue en stub de cero filas (`MAPEO_DESBLOQUEO_DATASHARE_ORDENAMIENTO.md:184-188`). Lo que se pide a Experian ya no es la llave: es **cuándo se puebla `bestaccounts`** |
| D-EDF-16 | **La gestión de registro: el legado tiene la rama `NO VALIDA` muerta y nosotros sí la producimos** | el divisor de `DIR010FI`/`DIR013OT` excluye `'NO VALIDA'` (`CAR` CR1791-1793) y Novedades filtra `'VALIDA'` (`NOV:7679-7680`) | **el predicado existe y es exactamente el nuestro**, pero la columna **nunca toma ese valor**: `Estandarizacion.sql:6740-6743` calcula `DIR_ESTADO` con **la misma condición en los dos `WHEN`** (`WHEN Est.Cod_DW_Reporte_Ubic_Original IS NOT NULL THEN 'VALIDA'` y otra vez la misma para `'NO VALIDA'`, `ELSE 'SV'`), de modo que la segunda rama es **inalcanzable**; y el `LEFT JOIN` a `tmp_Direcc_No_Validas` (`:6751`) -- la tabla que sí tiene las inválidas y sí se llena (`:1602`) -- **no se lee en ninguna parte**: el alias `NoVal` aparece una sola vez en 11.049 líneas. Resultado: la columna solo vale `VALIDA` o `SV`, y el divisor **no excluye nada** | **el divisor es un port LITERAL** (`sp_ordenamiento_scoring_dir_edf.sql:64-65` contra `CAR` CR1791-1793: mismo `CASE`, mismo `OR ... IS NULL`), y `descripcion_gestion_registro` **sí** toma `'NO VALIDA'` porque la derivamos del score de estandarización de EDF (D-EDF-12) | b | **APROBADA (usuario, 2026-10-21): se deja como está** | **No es un defecto de port: es una mejora sobre un defecto del legado.** El código del divisor coincide carácter por carácter; lo que cambia es el DATO, porque EDF distingue direcciones inválidas y Teradata no podía. Consecuencia asumida: somos más estrechos que el AS-IS en el divisor de DIR, y eso sube `DIR010FI` y `DIR013OT`. **Se descartó reproducir el bug**: haría que el filtro de Novedades dejara de excluir las direcciones inválidas, donde hoy funciona bien -- se arreglaría una cosa y se rompería otra. El mismo predicado está en el divisor de CEL (`CAR` CR1803-1805), así que la decisión vale para los dos canales. *(Una versión anterior de esta fila decía que el defecto era nuestro y que había que dejar de excluir en el divisor. Era falso: el divisor es fiel y el valor se fabrica aguas arriba.)* |

## Medido en el datashare: estrato, barrio y codigo postal (2026-10-21)

**Hallazgo: tres de las cuatro columnas que dabamos por bloqueadas por el
contrato GEO existen en el datashare y nunca las habiamos leido.** No contradice
la peticion del contrato GEO -- esas cuatro siguen sin pinar --: lo que aparece
es una **segunda fuente**, la que reportan los suscriptores, en `xpm_location` y
en `xpm_location_val_contactinformations`. Es el mismo patron que
`location.val.accounttype`, que desbloqueo `CEL019` y `EMA021`.

| Columna del legado | Columna del datashare | Tabla |
|---|---|---|
| `ESTRATO` | `location.val.stratum` | `xpm_location` |
| `BARRIO` | `...contactinformations.val.contactneighborhood` | `xpm_location_val_contactinformations` |
| `CODIGO_POSTAL` | `...contactinformations.val.contactzipcode` | idem |
| `LOCALIDAD` / comuna | **no existe** | buscado en el inventario de 1.072 columnas y en Confluence (`CCBR`, `EDCLMI`) |

**Y MEDIDO, QUE ES LO QUE CAMBIA LA DECISION.** Dos ambientes, consultas
corridas por el usuario el 2026-10-21:

| Columna | Ambiente A | Ambiente B |
|---|---|---|
| `contactneighborhood` | 90.481 de 568.657 (**15,9 %**) | 10.237 de 524.948 (1,9 %) |
| `contactzipcode` | 67.599 de 568.657 (11,9 %) | **26 de 524.948 (0,005 %)** |
| `stratum` | **113 de 146.724 (0,08 %)**, 7 valores distintos | **1.484 de 198.736 (0,75 %)**, 7 valores distintos |

**`stratum` ES EL PATRON `bestAccounts` EN ESTADO PURO.** La semantica es
correcta -- siete valores distintos en los dos ambientes, que es lo que se
espera de un estrato 1..6 mas centinela --, de modo que la columna no esta mal
mapeada: esta **vacia**. Con 0,08 % y 0,75 % de cobertura, comparar el estrato
de una persona antes y despues compara NULL con NULL en el 99 % de los casos.

**~~CONSECUENCIA: `CambioEstrato` de Movilidad (d6) NO se porta, porque el
indicador diria "no cambio de estrato" para todo el universo.~~ ESA CONCLUSION
ERA FALSA Y SE CORRIGE AQUI (2026-10-21, misma sesion).** Dos errores, y el
segundo es el que importa:

1. **La medicion es de DEV y QA, no de produccion.** Son ambientes con una
   tajada del dato y enmascarado; que una columna este vacia aqui no dice que lo
   este alla. No podemos medir produccion desde este lado, de modo que la
   cobertura real de `stratum` es **desconocida**, no cero.

2. **Y el argumento de que "mentiria" NO SE SOSTIENE, porque esta tabla es de
   EVENTOS y no de banderas.** `P0029_INDICADORES_MOVILIDAD_111.BTQ:62-68` son
   cuatro ramas `UNION ALL` y cada una filtra por SU propio cambio
   (`CambioDir = 1`, `... AND CambioEstrato = 1`, `... AND CambioCiudad = 1`,
   `... AND CambioComuna = 1`): **una fila existe solo cuando ese cambio se
   detecto**. No hay ninguna fila que diga "no cambio de estrato" y pueda ser
   falsa: la ausencia de fila es "no se detecto", que es exactamente lo que el
   legado emite cuando tampoco tiene el dato. Un estrato esparcido produce
   MENOS FILAS, no filas equivocadas.

**CONSECUENCIA CORREGIDA: `CambioEstrato` SI es portable, y Movilidad llega a
3 de 4 indicadores.** El unico hueco real es `CambioComuna`, porque
`LOCALIDAD` no existe en EDF por ninguna via.

**Y un detalle del legado que lo abarata: las CUATRO ramas exigen
`CambioDir = 1`.** Ningun indicador se dispara sin un cambio de direccion
previo, de modo que el disparador es siempre la senal que ya tenemos y ya esta
certificada -- la segunda fila en `ubicacion_atributo_hash` (ARQ 97 / 98). Los
otros tres indicadores son atributos que se comparan **sobre ese mismo evento**,
no deltas independientes.

**LO QUE SI VALE LA PENA CABLEAR: `contactneighborhood`.** 15,9 % en el
ambiente A es dato esparcido pero real, y hoy escribimos NULL en
`stg_nov_ubica_etapa_9.barrio` y en `mat_ubicacion_agregada.ubicacion_barrio`
dando por hecho que solo podia venir de GEO. Queda como trabajo, con la regla de
siempre: donde no hay dato va NULL y nunca un valor por defecto.

**ADVERTENCIA SOBRE LOS DOS AMBIENTES, que es un hallazgo aparte:** la misma
columna da 11,9 % en A y 0,005 % en B. Antes de usar cualquiera de las tres hay
que saber cual de los dos ambientes es el que va a produccion. Las 568.657 filas
de A coinciden con la cifra de DEV ya documentada (568.657 filas para 142.067
ids), de modo que A parece DEV; **no esta confirmado**.

## Lo que el mock de Movilidad (d6) NO ejercita, medido 2026-10-21

**Tres indicadores implementados, UNO ejercitado.** Medido en el banco con dos
pasadas de `fase dt`:

| Indicador | Eventos en el mock | Por que |
|---|---|---|
| `Cambio de Direccion` | **100** | es el ARQ 97, que cambia de texto antes del DELTA2 (paso 3b del e2e). El detector encuentra **exactamente** los 100 sembrados y ninguno mas |
| `Cambio de Ciudad` | **0** | ningun arquetipo cambia de ciudad |
| `Cambio de Estrato` | **0** | el mock no siembra estrato: `con_estrato = 0` en las 9.700 fotos |

**Y hay que decirlo con la misma regla que se aplico al ciclo GEO y a `NOV-AE`:
una rama que sale en cero no esta probada.** Las dos de ciudad y estrato estan
cableadas y compilan, pero no hay evidencia de que detecten nada. Lo que SI esta
probado, y es lo que sostiene el diseno entero, es el mecanismo:

- **la foto es insert-only y el grano es correcto**: 9.700 filas para 9.600
  ubicaciones, o sea 100 ubicaciones con DOS fotos -- de nuevo el ARQ 97 exacto;
- **la comparacion no produce falsos positivos**: 9.500 ubicaciones sin cambio
  no emitieron ningun evento;
- **y la segunda pasada no hereda**: los mismos 100 eventos, no 200. El reset
  borra la foto, que era el riesgo real de este dominio.

**Para ejercitar las otras dos ramas haria falta un arquetipo que cambie de
ciudad y otro con estrato sembrado**, y ninguno de los dos se anade a la ligera:
cambiar la ciudad de un arquetipo mueve el DANE y toca el insumo de la Regla 3 y
de DIR. Queda anotado como trabajo, no como defecto.

**UN DETALLE DE LA FECHA QUE NO ES UN DEFECTO:** las 9.700 fotos llevan UNA
sola `fecha_foto`, porque la bateria entera corre en un dia y la fecha sale de
`TRUNC(GETDATE())`. Es lo que hace el legado -- `PIM.FECHA_INICIO` es
`CURRENT_DATE` (`P0029_INDICADORES_MOVILIDAD_111.BTQ:40`) --, de modo que la
`FECHA` del evento es **la de la corrida que lo detecto**, no la del dia en que
la persona se mudo. En produccion, con corridas en dias distintos, las fechas se
separan solas.
