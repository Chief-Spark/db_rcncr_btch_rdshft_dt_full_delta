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

**Responsable:** quien tomó la decisión. "Usuario (sesión)" es una decisión tomada por el líder técnico durante la sesión de trabajo. **Ninguna fila está APROBADA todavía**: la aprobación funcional está pendiente para todas.

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
| D-ORD-15 | `sector_financiero` | sector por cuenta en `{CO,CC,RE,FI,OT}` | bandera 0/1 a partir de una cubeta de hash | c | ABIERTA | conectar `economicsector` o `businesslinecode` de EDF tras la consulta C14 |
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
| D-UNI-06 | `Cod_DW_Municipio` frente a ciudad | ciudad de 8 dígitos (centro poblado) ≠ municipio de 5 | el mismo valor | — | ABIERTA → **defecto** | C6c: el DANE de EDF siempre trae 8 dígitos (94.143 contactos, 16,6 %). Municipio = `cod_dw_ciudad / 1000` · pide OK a la vista |

## Novedades

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-NOV-01 | Contrato de carga | `DELETE … ALL` de las 7 `MAT_*` y recarga; delta contra `BK_*` (`111.BTQ:817-836`, `120.TPT:455-602`) | UPSERT incremental, nunca borra | b | DECIDIDA | **foto completa + delta, como el AS-IS** · usuario (sesión) · 2026-10-20 |
| D-NOV-02 | Cinco columnas de Ubicación en NULL/0 | literales (`NOV:8358-8363`) | iguales | a | DECIDIDA | se reproduce el legado · equipo (SLCOPRBA-1355) |
| D-NOV-03 | Fuente | `V_FUENTE` o `'CAM'` (`NOV:8635`) | `'CAM'` literal siempre | — | ABIERTA → **defecto** | portar el join a `V_FUENTE` (F6) |
| D-NOV-04 | `INFO_BASICA` | `Id_Buro_Persona` | `CAST` a INTEGER de un hash de 64 bits: **probablemente aborta con datos reales** | — | DECIDIDA → **defecto, pide DDL** | la columna es INTEGER en `stg_nov_ubica_etapa_9` y `mat_info_ubicacion` (`strct/30_ddl_novedades.sql:95,197`): hay que pasarlas a BIGINT antes de quitar el CAST. Pendiente de OK al DDL |
| D-NOV-05 | CIUDAD y DEPARTAMENTO | `COALESCE(…,'')` (`NOV:8354-8355`) | NULL | — | ABIERTA → **defecto** | corregir (F6) |
| D-NOV-06 | Universo de Actividad Económica | todas las actividades de Info Básica (`NOV:1288-1291`) | solo el CIIU principal | — | ABIERTA → **defecto** | F6, con `personalinformation` y `chamberofcommerce` |
| D-NOV-07 | Mosaic | dominio de Info Básica; `140.BTQ:515-527` lo exige para exportar | excluido por decisión legal | b | DECIDIDA | excluido · decisión legal · hay que rehacer la validación de extractos |
| D-NOV-08 | Contactabilidad (d5) | `V_CONTACTABILIDAD` y gestión | no está en `edf_views` (verificado) | c | ABIERTA | pedir al productor; mientras tanto NULL explícito |

## Transversales y datos de EDF

| ID | Tema | AS-IS | Redshift hoy | Tipo | Estado | Decisión / responsable / fecha |
|---|---|---|---|---|---|---|
| D-EDF-01 | Bloqueo | registro en `V_BLOQUEO`, cualquier razón | `bloqueado = 0` literal | b | DECIDIDA (provisional, **PROBABLE** tras C13: estado 1 ⇔ razón 0 en location y en cuentas) | `blockreason` distinto de vacío y de `'0'`; `subscriberblockstatus = 1` se trata como activo hasta que el productor lo explique · usuario (sesión) · 2026-10-20 |
| D-EDF-02 | Código DANE | 8 dígitos, texto | `INTEGER` (pierde el cero) y hash de `cityname` cuando falta | — | DECIDIDA → **defecto** | texto con relleno de ceros; NULL si falta, nunca un hash (F2) |
| D-EDF-03 | Número de entidades | `COUNT(DISTINCT suscriptor)` | `counterparties` a nivel persona y cubeta de hash | — | DECIDIDA → **defecto, confirmado** | C15/C16: solo el 4,9 % de los reportes trae su suscriptor; la contraparte es por persona y 95 personas multiplican sus reportes hasta ×57. Propuesta: reporte → contraparte única de la persona → NULL, sin hash ni fan-out. Pide C19 y OK a la vista |
| D-EDF-04 | `fecha_reporte` faltante | NULL | `CURRENT_DATE` | — | DECIDIDA → **defecto sin impacto hoy** | C16: `cutoffdate` en el 100 % de los reportes reales; la caída solo toca arreglos vacíos. NULL por higiene |
| D-EDF-05 | Contrato de respuesta GEO | layout P0006 (30 columnas: Status col28, latitud 12, longitud 13) | Status col03, latitud 05, longitud 06 | c | ABIERTA | confirmar el layout real de ArcGIS antes de tocar |
| D-GEO-01 | Rutas de ArcGIS en el wrapper | — | el slot 5 se lee como Lote y como ruta de distancias (`sp_geo_ciclo_lote_wrapper.sql:68,79`); el Framework manda un solo valor (`step_function_definition_builder.py:93`) | c | ABIERTA | depende de dónde deja ArcGIS los dos archivos (D-EDF-05); no es una corrección sin dependencias |
| D-GEO-02 | Lote de las parejas del reenganche | — | la R3 del reenganche sella con el Lote GEO (`MAX+1` propio, `sp_geo_exportar_insumo.sql:298`), que no es la numeración del Lote de Unificación | c | ABIERTA | pide `corrida_id` o el Lote de origen en `geo_lote_control` (DDL de F3) |
| D-EDF-07 | `cod_dw_ubic` | la ubicación (maestro de direcciones) | `loc.id`, el arreglo de la **persona** (`02_vistas…:19`) | — | ABIERTA → **defecto** | C4c: un `id` por persona. R1/R2/R3 unen por él y cruzan las direcciones de la persona. Propuesta: hash del texto normalizado + DANE. Pide C17 y OK a la vista |
| D-EDF-08 | Tipo 8 en el canal TEL | — | TEL = `IN ('4','5','8')` (`04_vistas…:125`, `sp_ordenamiento_ubicaciones_edf.sql:248`) | — | ABIERTA → **defecto** | C6b: el 8 es dirección (VIA, RURAL, MANZANA…). 135.084 direcciones entran como teléfonos. Quitarlo de TEL · pide OK a la vista |
| D-EDF-09 | Tipos 6, 10 y 11 | — | 6 y 11 no se leen; 10 se lee como EMAIL sin verificar | c | ABIERTA | 72 % de los contactos sin canal verificado. C18 y catálogo `contacttype` |
| D-EDF-06 | Mapeo `contacttype` | surrogates con abreviaturas RES/LAB/CRR/CCL/JUD | tabla inventada 1..7, con el `'8'` en dos canales | c | ABIERTA | pedir el catálogo de `contacttype` |
