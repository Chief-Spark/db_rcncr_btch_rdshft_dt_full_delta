# Análisis AS-IS → Redshift: homologación para el Batch

Fecha: 2026-10-20 · Rama: `codex/ajustes-sp-reales-batch-en-linea`
Fuente: el legado versionado en `docs/legado_teradata/` (ver su `MANIFIESTO.md`).

**Para qué existe.** Este documento guarda lo que se encontró al leer por primera vez el legado completo (`Novedad.sql`, `Unificacion.sql`, `Ordenamiento.sql`, `Caracteristicas.txt`, GEO, catálogos, Batch P0033) y una salida real de Batch. Así no hay que volver a hacer el análisis.

**Grados.**
- **CONFIRMADO:** el código lo muestra.
- **PROBABLE:** misma semántica, mismo nombre o mismo formato.
- **HIPÓTESIS:** sin rastro directo.

Que dos columnas se llamen igual no prueba nada.

**Prefijos de las citas.** Todas las rutas son relativas a `docs/legado_teradata/`.

| Prefijo | Archivo |
|---|---|
| `NOV:` | `reconocer/novedades/DB/Novedad.sql` |
| `UNI:` | `reconocer/unificacion/DB/Unificacion.sql` |
| `CAR:` | `reconocer/ordenamiento/Caracteristicas.txt` |
| `SPS:` | `batch/Sps_Batch.sql` |
| `CE120:` | `batch/P0033_BATCH2_CUBOEXPORT_120.BTQ` |
| `INFO:` | `batch/InfoAdicional.txt` |
| `T120` / `T130` / `B111` / `B140` | `reconocer/novedades/P0035_Extractor_Novedades_{120,130,111,140}` |

> **Ojo con `Caracteristicas.txt`.** Mezcla finales de línea `CR` y `LF`, así que su numeración depende de la herramienta: 261 líneas contando solo `LF` y 3.170 contando `CR` y `LF`. El repo lo cita con **las dos numeraciones** bajo el mismo nombre (`:72`, `:105` son LF; `:1213`, `:2450` son CR+LF). Toda cita nueva debe decir cuál usa.

---

## 1. El hallazgo que ordena todo

**El Batch no lee nada de Unificación, Ordenamiento ni Novedades directamente.** Lee 7 cubos `REC_STAGE.BATCH_CUBO_*` (PERSONA, DIRECCION, TELEFONO, CELULAR, CORREO, CIIU, PUNTO_INTERES_DIR), y esos cubos los arma `P0032_BATCH_GENERACUBO`, **que no está en el material**. Una búsqueda de `MAT_INFO`, `NOVEDAD`, `UNIFICA` y `SCORE` en todo el Batch solo encuentra comentarios.

Consecuencia: **ninguna columna de los cubos queda CONFIRMADA de punta a punta.** El origen de cada una se infiere comparando nombre, semántica y formato con el AS-IS de Reconocer. Lo que lo cierra es el contenido de `BATCH2_HOMOLOGACION`, cuya columna `HOMOLOGADO` dice qué columna del cubo alimenta cada campo de la plantilla.

**Hipótesis fuerte (PROBABLE).** Los cubos de ubicación tienen la forma de `MAT_UBICACION_AGREGADA` de Novedades. La salida real lo respalda:
- el tipo es multivalor (`RES - LAB - CRR`), con el orden R, L, C de `NOV:5972-5977`;
- el DANE es de 8 dígitos;
- trae número de entidades, fecha de último reporte y una posición por canal (`UBICACION_ORDEN`).

Si se confirma, **Ubicación Agregada pasa a ser camino crítico del Batch**, y hoy sale vacía en Redshift.

## 2. Qué muestra una salida real ("Reconocer Esencial")

Perfil completo en `legado_teradata/salida_real_esencial/`. El original tiene datos personales y no se versiona.

| Hoja | Columnas | Qué confirma |
|---|---|---|
| Con datos ubicación | 72 | Plantilla Esencial = 14 de persona + **Tel ×3** (8 c/u) + **Dir ×3** (10 c/u) + **Correo ×2** + **Celular ×2**. Posiciones por canal y máximo por plantilla |
| Sin datos de ubicación | 14 | Solo los datos de persona |
| Inconsistencias | 11 | Mismo layout que el `.ESQUEMA` de la muestra 4421 |
| Estadísticas | — | Conteos por tipo de documento, con o sin datos, por canal e inconsistencias por causal. Glosario: tipos de teléfono LAB/RES/CCL; tipos de dirección CRR/LAB/RES/CCL/PPL/AGN/SUC/EST; zona URB/RUR; fuente SUS/CIU/CAM |

**Formatos de salida observados:**
- `Fecha ultima actualizacion`: `dd/mm/aaaa`.
- `Fecha expedicion`: `dd/mm/aa`.
- `Rango edad`: `36-45` con relleno a la derecha.
- `Genero`: `M`.
- `Tipo`: multivalor, unido con `' - '`.
- `Codigo DANE ciudad`: 8 dígitos; `Codigo DANE departamento`: 2 dígitos.
- `Estrato`: `0`-`6` o vacío.
- `Numero de entidades reporta`: entero.

## 3. Cómo decide el Batch (CONFIRMADO en `SPS:`)

| Regla | Dónde |
|---|---|
| Posición `00n` por canal: `ROW_NUMBER() OVER (PARTITION BY ID_BURO_PERSONA ORDER BY ORDEN_PRIORIDAD, Fecha_ultima_actualizacion DESC, …, hash_md5(valor))` | `CE120:134` (TEL), `:391` (CEL), `:637` (DIR), `:894` (CORREO) |
| `ORDEN_PRIORIDAD` nulo → se descarta la fila (FILTRO_I) | `SPS:4124` |
| Top-N entre `MINIMO_REQUERIDO_CAMPO` y `CANTIDAD_MAX_CAMPO` de la plantilla (FILTRO_G) | `SPS:3042-3096` |
| CON_DATOS si `Filtro_H = 0`. **Un CIIU válido basta** | `SPS:3812-3849` |
| Campo obligatorio de la plantilla nulo → se marca (FILTRO_D) | `SPS:782-803` |
| INCONSISTENCIA sale de `PRO_BATCH_VALNOMBRE` (no viene) y de `ADICIONAR_INCON` (estado 06, causal 04) | `SPS:6066-6140` |
| `Tipo_Id` se trunca a `VARCHAR(1)`: el código NH `10` (RC) colisiona con `1` (CC) | `SPS:1272, 1445` |

## 4. `ORDEN_PRIORIDAD` en el AS-IS (CONFIRMADO)

- **Es un valor por RPU, rankeado dentro de su canal.** No hay ranking global.
- Cada canal hace `ROW_NUMBER() OVER (PARTITION BY Id_Buro_Persona, Cod_Pin_Persona ORDER BY Score DESC)` (`CAR` LF72 EMA, LF79 CEL, LF105 TEL, LF159 DIR).
- `P0027_UBI_ORDENAMIENTO_130.TPT:136-145` escribe `RPU.Orden_Prioridad = Lugar` y guarda además `Orden_Prioridad_Anterior` y `Fecha_Ult_Ordenamiento` (`:117-126`).
- Granos distintos por canal:
  - **CEL y EMA rankean por RPU.** Dos RPU con el mismo celular reciben lugar 1 y 2.
  - **TEL y DIR rankean por valor** y copian el lugar a todas las RPU de ese valor.
- El score solo vive en `TablaResultCaract_TUbic`, que se recrea en cada corrida.

**En Redshift:**
- `rpu_orden_prioridad` guarda `MIN(lugar)` **mezclando canales** (`sp_ordenamiento_consolidacion_edf.sql:12-24`).
- Los 4 scoring asignan el lugar a **una sola** RPU, `MIN(cod_dw_persona_ubic)`. Las RPU hermanas quedan sin orden y Novedades las descarta.
- **Hay dos columnas llamadas `orden_prioridad`:**
  - `v_xpm_relacion_persona_ubicacion.orden_prioridad` es un rango por recencia (`02_vistas_insumo_edf_views.sql:163-166`): mismo nombre que la del legado, otro significado;
  - `bdm_datos.rpu_orden_prioridad` es la del scoring.

## 5. Hallazgos críticos AS-IS frente a Redshift

| # | Qué | Dónde (repo) | Evidencia AS-IS |
|---|---|---|---|
| 1 | `contactinformations.id` es el id del **arreglo** y no el del contacto (~4 filas por id). Se usa como `cod_dw_persona_ubic` y `cod_dw_direccion_fisica` | `strct/02_vistas_insumo_edf_views.sql:20-21` | La RPU del legado es 1:1 con su teléfono, correo o dirección física (`P0020_UNIFICACION_DIRECCION_130.TPT:253-256`) |
| 2 | Lugar mezclado entre canales y asignado a una sola RPU | consolidación y scoring | §4 |
| 3 | **`INFO_BASICA` castea a `INTEGER` un `FNV_HASH` de 64 bits: con datos reales probablemente aborta** (el mock no lo ve porque sus ids son pequeños) | `pgm/sp_novedades_ubicacion_edf.sql:391` | `RPU.Id_Buro_Persona` (`NOV:8373`) |
| 4 | El contrato de respuesta GEO no coincide con el layout del legado. Se rechazaría el 100 % de las filas | `pgm/sp_geo_cargar_georreferenciacion.sql:138-169` | `P0006_STAGEGEOREFERENCIA_100.TPT:29-58`: Status col28, latitud 12, longitud 13; **barrio 7, localidad 8, estrato 9, código postal 22** |
| 5 | NIT cableado como `'3'`. En ID Type NH el **2 es NIT** y el 3 es Persona Jurídica del Extranjero | `pgm/sp_unificacion_r2_esc3_…:27`, `…motor_nit…:194` | `UNI:2208-2210` usa `V_Tipo_Identificacion LIKE '%Nit%'` |
| 6 | `standardizeddanecode` pasa a `INTEGER` (pierde el cero inicial) y cae a `MOD(FNV_HASH(cityname))` cuando falta: aparecen "DANE" falsos | `02_vistas…:52-58` | DANE de 8 dígitos de `V_GEOGRAFIA` (`NOV:7665`) |
| 7 | `fecha_reporte` cae a `CURRENT_DATE`; `id_buro_suscriptor` cae a una cubeta de hash; el join a `counterparties` es a nivel persona | `02_vistas…:319-353` | `COUNT(DISTINCT Id_Buro_Suscriptor)` (`NOV:8505`) |
| 8 | `bloqueado` es el literal `0`: el anti-join de bloqueo no hace nada en la vía real | `02_vistas…:195,209` | `V_BLOQUEO` (`NOV:7590-7594`) |
| 9 | Mapeo `contacttype` → tipo **inventado** (1=RES…7=DIR); JUD y CCL invertidos; el `'8'` entra como dirección y como teléfono | `strct/01_ddl_unificacion_direccion.sql:119-128`, `04_vistas…:125` | Surrogates reales 21478, 21426, 21461, 21417, 40164 (`catalogos/REC_VISTA - V_Tipo_Ubicacion_Direccion.csv`) |
| 10 | `catalogo_operador_ord_cel` **inventado** (16 valores). El real tiene 20 filas y faltan 304, 305, 322 y 323. Con el falso, CEL018 nunca da las categorías 1 ni 4 | `strct/02_catalogos_ordenamiento.sql:44-50` | `catalogos/REC_VISTA - V_Operador_Ord_Cel.csv` |
| 11 | Novedades es incremental y nunca borra. **El AS-IS vacía y recarga las 7 `MAT_*` en cada corrida**; las novedades reales salen de vistas `*_Delta` contra copias `BK_*` | `pgm/sp_novedades_cargar_mat_*_edf.sql` | `B111:817-836`, `T120:455-602` |
| 12 | Novedades Ubicación: CIUDAD y DEPARTAMENTO NULL en vez de `''` (rompe el join de la etapa 2); FUENTE `'CAM'` literal; sin filtro `VALIDA`; `NUMERO_IDENTIFICACION` = PIN; CIUDAD = municipio (el legado usa centro poblado) | `pgm/sp_novedades_ubicacion_edf.sql:363,372-373,481`; `02_vistas…:63-66` | `NOV:8345, 8354-8355, 8635, 7679-7680, 7673` |
| 13 | Unificación no escribe `REPORTE_UNIFICACION_DIRECCION` (histórico diario); severidad siempre 1 (el legado usa 1 o 3 con `COD_RECHAZO`); `rpu_generada` sin `orden_prioridad`, `cod_dw_telefono` ni `cod_dw_direccion_electronica` | `strct/01*_ddl_*` | `P0019_UNIFICACION_130.TPT:147-185`; `P0020_…_130.TPT:244-278` |
| 14 | `Cod_DW_Municipio` = `cod_dw_ciudad`: el legado separa ciudad (8 dígitos, centro poblado) y municipio (5) | `02_vistas…:251` | `catalogos/REC_VISTA - V_Geografia.csv` |
| 15 | Al insumo de Unificación le faltan `Cod_DW_Doc_Ident` y 14 de las 17 columnas de `VM_Reporte_Relacion_Pers_Ubi` (`Cod_DW_Cta`, `Fecha_Nov`, `Flag_Bloqueo`…) | `02_vistas…:316-362` | `unificacion/V_Insumo_Unificacion_Regla2.txt:32-63`, `VM_Reporte_Relacion_Pers_Ubi.txt:37-74` |

**Lo que sí cuadra (verificado por script):**
- Betas: 47 de 47 iguales a `V_Beta_Ordenamiento_*`.
- `V_Tipo_Cuenta_Ord`: 44 de 44.
- `V_Fuente` y `V_Gestion_Registro`: iguales, **pero ningún SP los usa**.

## 6. Novedades: los 7 dominios

| | `MAT_*` (columnas) | SP legado | En Redshift | Lo que el legado muestra |
|---|---|---|---|---|
| d1 | `MAT_INFO_UBICACION` (42) | `_Ubicacion` (`NOV:7303-8887`) | portado | Universo: sin bloqueo, sin unificar, con orden, gestión `VALIDA`, en `VU_PERSONA`. `REPORTADO_DESDE`, `ULTIMO_REPORTE`, `FUENTE`, `NUMERO_*` son NULL o 0 literales (`NOV:8358-8363`): sus valores reales están en la etapa 2, que solo alimenta Agregada |
| d2 | `MAT_INFO_ACTIVIDAD_ECONOMICA` (8) | `_Historial` (el nombre está cruzado) | portado | Universo = **todas** las actividades de la población de Info Básica (`NOV:1288-1291`), no solo la principal. `FECHA_REPORTE` = inicio de relación o matrícula. Severidad por (info, CIIU, fecha) (`T120:200-202`) |
| d3 | `MAT_UBICACION_AGREGADA` (29) | `_Ubi_Agregada` | portado, **vacío** | Los joins `a5`, `a6` y `a7` cruzan por `TIPO_IDENTIFICACION` (`NOV:5430-5436`): si es NULL, sale vacío. Cadenas TIPO (R, L, C) y FUENTE (SUS, CAM, CONT). `COD_PAIS` constante. Las columnas de vía **sí** salen, en el delta (`T120:547-551`) |
| d4 | `MAT_INFO_BASICA` (22) | `_Info_Basica` | no | Registro "más confiable" vía `Vstg_BUROPERS_TMP`. Rango de edad, género, lugar de expedición. RUT = fuente DIAN. Mosaic |
| d5 | `MAT_INFO_CONTACTABILIDAD` (12) | `_Contact` | no | `CONTACTABILIDAD` siempre `'SI'` (INNER JOIN, `NOV:617`). Bugs en las franjas horarias (`NOV:588-597`) |
| d6 | `MAT_INFO_MOVILIDAD` (8) | `_Indic_Movilidad` | no | Universo = todo `V_PERSONA_INDICADOR_MOVILIDAD`. Lo produce P0029 (`MTCalcularIndicadoresMovilidad`, que no viene) |
| d7 | `MAT_INFO_PUNTO_INTERES` (10) | `_Punto_Interes` | no | `UBICACION_ID` = `COD_DW_UBIC` (la ubicación, no la RPU). Nombre y NIT de entidad desde `RELACION_PUNTO_INTERES_X_PERS` |

**Además:**
- `PRO_Novedad_Linea_PICalculados_Ctls` produce `Novedades_CTLS`, que son **los conteos con los que `B140:517-647` valida cada extracto**. Sin Agregada, queda vacío.
- **`B140:515-527` exige que cuadre `MOSAIC.txt` antes de exportar.** Excluir Mosaic obliga a rehacer esa validación.

## 7. Homologación de códigos

| Dominio | Teradata | EDF / NH | Coincidencia | Puente |
|---|---|---|---|---|
| Tipo de identificación | `Cod_Tipo_Ident_Fte` (el Batch asume 1=CC, 2=NIT, 3=NIT extranjería, 4=CE; `INFO:484-487`) | `personidtype` (¿NH 0-10?) | sin verificar | ID Type NH + equivalencias (PJE ↔ NIT_EXT) |
| Tipo de ubicación | surrogates / abreviaturas RES, LAB, CRR, CCL, JUD | `contacttype` | 4/5 por abreviatura con Information Recognizer (sin JUD; NH agrega AGN, CDI, EST, PPL, SUC) | **falta el catálogo de `contacttype`** |
| DANE | 8 dígitos, centro poblado | `standardizeddanecode` | Divipola 974/1000 contra el `V_Geografia` truncado; 77 nombres difieren (Ñ→N, puntuación) | Divipola Villages (7.978) + DANE State Code (33) |
| Razón de bloqueo | `V_Razon_Bloqueo` (18) | NH (20) | 18/18 por código, **solo 9 por significado: del 1 al 9 cambian** | **no se puede homologar por código**; hay que definir la regla |
| Tipo de cuenta | `V_Tipo_Cuenta` (52) / `_Ord` (44, sin cero a la izquierda) | Subscriber Account Type (50 de 2 dígitos + 152 de 4) | 50/50 y 44/44 con relleno; los de 4 dígitos parecen `subaccounttype` | por código |

## 8. Catálogos

**Recibidos** (en `legado_teradata/reconocer/catalogos/`):
- `V_Tipo_Cuenta_Ord`, `V_Gestion_Registro`, `V_Beta_Ordenamiento_{Tel,Cel,Dir,Email}`, `NOMENCLATURA_SINTETICO` (58, contra 12 en el repo), `V_Operador_Ord_Cel` (real), `V_Fuente`, BDM `V_Tipo_Cuenta`, BDM `V_Fuente_Dato`, BDM `V_Razon_Bloqueo`, `V_Tipo_Ubicacion_Direccion`.
- Truncados a 1000 filas: **`V_Geografia`** (11 de 33 departamentos) y **`V_Cod_Entrega_Dato`**.
- NH convertidos: ID Type, DANE State Code, Divipola Villages, Subscriber Account Type, Subscriber Blocking Reasons, Information Recognizer.

**Faltan**, por prioridad:

| Prio | Catálogo | Bloquea |
|---|---|---|
| 1 | Catálogo de `contacttype` (EDF) → tipo y clase | tipo, clase, llave de canal |
| 1 | `V_Hom_Tip_Ident_Linea` (o equivalencias NH ↔ Teradata) | Agregada vacía; tipo de identificación en 5 dominios |
| 1 | `V_ACTIVIDAD_ECONO_CIIU` | descripción y versión del CIIU |
| 1 | Layout real de respuesta de ArcGIS | carga GEO; barrio, localidad, estrato, código postal |
| 1 | Regla de bloqueo sobre `blockreason` / `subscriberblockstatus` | exclusión de bloqueadas |
| 2 | `V_Hom_TipoUbic_Dir_Linea`, `V_TIPO_UBICACION`, `V_ZONA_UBICACION` + `V_Hom_Zona_Linea`, `V_ESTRATO_DIRECCION`, `V_TELEFONO_FIJO`, `V_TIPO_CORREO` + `V_DIRECCION_ELECTRONICA` | tipo, zona, estrato, indicativo, tipo de correo |
| 2 | `V_RANGO_EDAD`, `V_GENERO`, `V_JERARQUIA_GEOGRAFICA`, `VU_PERSONA` (o su equivalente EDF) | Info Básica, cubo PERSONA |
| 3 | Contactabilidad: `V_CONTACTABILIDAD`, `V_CONTACTO_EFECTIVO`, `V_PRIORIDAD_GESTION_*`, clase buró, `V_Ind_Efectiv_Orden_Peso_Email` | d5, columnas de gestión, EMA020 |
| 3 | Movilidad y punto de interés: `V_PERSONA_INDICADOR_MOVILIDAD`, `V_INDICADOR_MOVILIDAD`, `V_Hom_Ind_Mov_Linea`, `V_PUNTO_DE_INTERES_GEO`, `V_TIPO_PUNTO_INTERES`, `V_Hom_Tipo_Pto_Int_Linea` | d6, d7 |
| 3 | Batch: `BATCH2_HOMOLOGACION`, `V_CATEGORIA_INGRESO` / `EGRESO`, `V_TIPO_IDENTIFICACION`, definición de `Vstg_BUROPERS_TMP` | contrato del Batch |

## 9. Lo que NO está verificado en EDF

**Que la contactabilidad "no existe en EDF" es una afirmación sin verificar.** Viene de documentos que solo revisaron las 4 tablas que leemos. El volcado de `svv_all_columns` del 15-oct se usó en una sesión anterior y **no se guardó**.

Antes de decidir hay que correr, solo lectura:
1. `svv_all_tables` y `svv_all_columns` sobre `ds_dba_rncr_batch.edf_views`.
2. Una búsqueda por nombre de columna: `%contact%`, `%gestion%`, `%effect%`, `%result%`, `%call%`, `%attempt%`.
3. Cardinalidad de `(id, index)` en `xpm_location_val_contactinformations`.
4. Dominios de `personidtype`, `contacttype`, largo del DANE, `blockreason` y `subscriberblockstatus`.

Su resultado (metadatos y conteos) se guarda en este repo.

## 10. Afirmaciones del repo que el legado desmiente

Están en `CLAUDE.md` o en `docs/`. Se corrigen cuando se apruebe el plan; aquí quedan anotadas:

| Afirmación | Realidad | Evidencia |
|---|---|---|
| "El AS-IS solo inserta y actualiza `MAT_INFO_UBICACION`" | vacía y recarga las 7 | `B111:817-836` |
| "`MAT_INFO_ACTIVIDAD_ECONOMICA` solo crece" | se vacía; su ID se renumera en cada corrida | `B111:823`, `T120:181` |
| "Catalogo (`:288`), Historial (`:1721`), PICalculados (`:4808`) leen la etapa 9" | esas líneas son de Contact, Indic_Movilidad y Punto_Interes; Catalogo no la lee | `NOV:` |
| "Todo sale `'CAM'`" | solo cuando no hay coincidencia en `V_FUENTE` | `NOV:8635` |
| "Los centinelas inconsistentes rompen el join de la etapa 2" (en el legado) | la etapa 9 ya hace `COALESCE`; solo rompe un `DATO` NULL. **En Redshift sí lo rompe**, porque no hay `COALESCE` | `NOV:8354-8355` |
| "El universo de ACTECO es `V_PERSONA_ACT_ECONOMICA_CIIU`" | `TMP_INBAS_ETAPA_10` × `VU_PERSONA_ACTIVIDAD_ECONOMICA` | `NOV:1288-1291` |
| "Las columnas de vía de Agregada no van a ninguna parte" | se exportan en el delta | `T120:547-551`, `B140:653-654` |
| "Latitud y longitud `VARCHAR(40)` es contractual" | la tabla final es `DECIMAL(38,8)` | `T130:603` |
| "`V_Geografia` se corta en Santander; Colombia tiene ~1100" | el archivo no está ordenado y el grano es centro poblado (~7.978) | Divipola |
| "`INDICATIVO` viene de `V_Geografia`" | viene de `V_TELEFONO_FIJO.COD_AREA` | `NOV:7966` |
| "`ORDEN_PRIORIDAD` = MIN entre canales" (implícito en la consolidación) | lugar por canal | §4 |

## 11. Infraestructura del clúster consumidor (DBA, 2026-10-14)

| Aspecto | Configuración |
|---|---|
| Nodos | 2 × RA3.xlplus, us-east-1, sin Multi-AZ |
| Capacidad entre trabajos | Auto WLM, más Concurrency Scaling automático (máximo 2 clústeres adicionales) |
| Límites de tiempo | `statement_timeout = 0`, `max_execution_time = 0`, sin QMR: ningún corte automático de consultas |
| Mantenimiento | `auto_analyze` y `auto_mv` activos; VACUUM automático (VacuumBG) observado en `bdm_datos` y `bdm_stage` |
| VACUUM manual | no hay permiso; hay que sustentarlo si se necesita |
| Vistas de diagnóstico | `SYS_QUERY_HISTORY`, `SVL_QUERY_REPORT`, `STL_ALERT_EVENT_LOG`: hay que pedir un usuario de monitoreo con rol |

**Volumen esperado en producción:** 65 a 70 millones de contactos. Nunca se ha ejecutado con volumen real.
