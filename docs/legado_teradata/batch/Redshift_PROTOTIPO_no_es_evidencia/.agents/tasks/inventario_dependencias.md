# Inventario de dependencias y hechos verificados — prueba del producto Esencial en Redshift

Fecha de la investigación: 2026-10-15 (estado del repositorio al leerlo).
Alcance: SOLO lectura y verificación. No se modificó ningún SQL, procedure, DDL ni la guía.
Insumo para: el escritor de `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\GUIA_PRUEBA_PRODUCTO_ESENCIAL.md`.

Convenciones de este documento:
- `RS` = `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift`.
- `archivo:NN` = número de línea aproximado (±2) dentro del archivo.
- **[VERIFICADO]** = comprobado leyendo el archivo real o ejecutando algo local. **[AWS]** = comprobado en documentación oficial de AWS (URL citada). **[SUPUESTO]** = no se pudo confirmar sin un cluster Redshift real; está repetido en la sección 14.
- Nada de lo migrado se ha ejecutado jamás en Redshift (`RS\VERIFICACION.md`). Todo lo que sigue sobre comportamiento en el cluster es lectura de código, no observación.

---

## 0. Resumen ejecutivo (lo que más cambia la guía)

1. **El orquestador `CALL rec_stage.sp_batch2_proceso_batch2(...)` NO puede terminar hoy.** Antes ya se detiene en FILTRO_E (punto 3) y FILTRO_F (punto 4) si no se resuelven esos dos bloqueos. Resueltos esos, falla (aborta) en el paso 9 (`sp_batch2_completitud_canal`), porque ese SP crea una vista sobre `rec_stage.vstg_batch2_pnpj/_pj/_pn` y lee `rec_stage.v_ba2_campos_salida`, objetos que no existen en ningún DDL. Aunque se arreglara el paso 9, fallarían después el 10 (`batch_cubo_persona11`, `vu_persona`, `v_tipo_persona`), el 11 (`vstg_inconsis_pnpj`) y el 12 (`rec_vista.v_evento_entrega_dato`, `rec_vista.v_cod_entrega_dato`). Los 3 CSV (`CON_DATOS`, `SIN_DATOS`, `INCONSISTENCIA`) SÍ quedan en S3 porque se generan en los pasos 6-7, antes de la falla. [VERIFICADO: secciones 4 y 6]
2. **Un error dentro de cualquier `sp_execstring_des` aborta todo el `CALL` y deshace la transacción** (el handler registra el error en `rec_mtdat.log_td_detalle` y relanza). El comentario del código lo dice y la documentación AWS lo confirma para procedimientos no `NONATOMIC` (`stored-procedure-trapping-errors.html`). No hay "el pipeline sigue y avisa": se detiene en el primer error. [VERIFICADO + AWS]
3. **Hay un bloqueo ANTES del export que la guía actual no ve: FILTRO_E** (paso 4 del orquestador) lee `rec_vista.vu_persona` y `rec_vista.v_tipo_persona`, que no existen. La guía dice que esto "afecta calidad pero no bloquea"; es falso: aborta el pipeline antes de `cubo_export` y `exportplano`. [VERIFICADO: `RS\procedures\08_sp_batch2_procesacubos.sql:731-732`]. Solución derivada del código (no existe en el repo): dos vistas sobre las tablas `rec_vista.persona` y `rec_vista.tipo_persona` que sí existen (sección 6.2).
4. **FILTRO_F exige que las 4 funciones Lambda existan** (`rec_vista.f_bach_similitud_dir_mz`, `f_porc_similitud`, `f_bach_similitud_tel`, `f_bach_similitud_email`) porque las referencia en un `CREATE TABLE ... AS SELECT` (error de "función no existe" en tiempo de análisis aunque no haya filas). La Lambda real solo se invoca si hay filas en `rec_stage.stg_insumo_batch_validacion` (vacía en la prueba) [SUPUESTO: que Redshift no invoque la Lambda con 0 filas]. [VERIFICADO: `08_sp_batch2_procesacubos.sql:1100-1113, 1188, 1243, 1297`]
5. **`exportplano` hace `INNER JOIN rec_vista.persona PNPJ ON CBPER.tipo_id = PNPJ.cod_tipo_ident_fte`** (`04_sp_batch2_exportplano.sql:107`). `rec_vista.persona` se crea VACÍA (`ddl/06_vistas_dimension.sql:31`). Con la tabla vacía los CSV salen con 0 filas de datos. Y como el join es solo por tipo, hay que cargar EXACTAMENTE UNA fila por tipo de identificación (1, 4 = natural; 2, 3 = jurídica) o se duplican filas. La guía no menciona esta tabla. [VERIFICADO]
6. **`BATCH_SOLICITUD_BATCH.PRUEBA = 'S'` (la guía lo usa) activa el enmascaramiento** de teléfonos, celulares, direcciones, correos y nombres (`sp_batch2_homologaciones`, bloque L2, `08_sp_batch2_procesacubos.sql:2154-2270`: se enmascara si `COALESCE(prueba,'SV') <> 'SV'`). Para ver datos reales en los CSV hay que usar `NULL` o `'SV'`. [VERIFICADO]
7. **El truncamiento a 3/3/2/2 lo hace FILTRO_G (en PROCESACUBOS), no `exportplano`**, y solo si (a) `batch_salidas_campos.codigo_campo` usa los códigos reales `DT_NUM`, `DD_DIR`, `DC_NUMERO`, `CE_CORREO` (la guía usa `TEL`, `DIR`, `CEL`, `MAI`: no coinciden) y (b) `rec_stage.batch2_homologacion` tiene filas que mapeen esos códigos a su cubo/columna; esa tabla **no tiene script de carga en el workspace**. [VERIFICADO: `08_sp_batch2_procesacubos.sql:1538-1680`]
8. **Los gaps 3.1 y 3.2 de la guía siguen vigentes** (sección 3). Los 4 SP de F2-4 son lógica real, no placeholders, pero 3 de ellos no pueden ejecutarse por objetos faltantes (sección 3.3).
9. **Errores de la guía actual** detectados: consulta de catálogo inválida (sección 12); "10 sp_batch2_*" (son 34 procedures: 31 `sp_batch2_*` + 3 auxiliares); `CALL` con notación nombrada `=>` que la sintaxis documentada de AWS no incluye; `vstg_inconsis_pnpj` atribuido a `CUBOEXPORT_111.BTQ` cuando está en `EXPORTPLANO_111.BTQ`; secciones desactualizadas ("placeholder", "ddl/01..08", "WARNING de los placeholders").

---

## 1. Inventario de artefactos (rutas absolutas)

Todo cuelga de `RS` = `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift`.

| Ruta absoluta | Para qué sirve (lenguaje simple) |
|---|---|
| `RS\README.md` | Explica qué se migró, el orden de despliegue y cómo llamar al proceso. |
| `RS\VERIFICACION.md` | Lista lo que se revisó "a mano" (no hay cluster) y lo que no se pudo verificar. |
| `RS\GUIA_PRUEBA_PRODUCTO_ESENCIAL.md` | La guía a reescribir. 25 138 bytes. |
| `RS\ddl\00_README.md` | Orden de los scripts DDL y diferencias de diseño frente a Teradata. |
| `RS\ddl\01_schemas.sql` | Crea los 4 esquemas (`rec_stage`, `rec_mtdat`, `rec_datos`, `rec_vista`). |
| `RS\ddl\02_tablas_configuracion.sql` | Tablas que describen la solicitud y la plantilla (qué se pide y cómo se entrega). |
| `RS\ddl\03_tablas_cubos.sql` | Tablas "cubo" con los datos de contacto de entrada (persona, dirección, teléfono, celular, correo, CIIU, punto de interés). |
| `RS\ddl\04_tablas_pivote.sql` | Tablas `w_cubo_*` donde N filas por persona se vuelven columnas `_001`, `_002`... |
| `RS\ddl\05_tablas_control.sql` | Contador de lote, bitácora (`log_td`), catálogo de homologación, inconsistencias, historia, estadísticas. |
| `RS\ddl\06_vistas_dimension.sql` | Tablas `rec_vista.persona` / `tipo_persona` (clasifican natural vs jurídica) y `vstg_buropers_tmp`. |
| `RS\ddl\07_tablas_dependencias_sps.sql` | Motores de "SQL guardado como datos", plan de ejecución, insumo de validación, secuencia 1..100, catálogos. |
| `RS\ddl\08_funciones_udf.sql` | 1 UDF SQL de conversión, 4 UDF Lambda de similitud, 3 UDF SQL de enmascaramiento. Tiene marcadores a reemplazar. |
| `RS\ddl\09_vistas_dependencias_sps.sql` | Vista `vstgbatchcargaubicestandarizada` + bloque opcional comentado (tablas vacías de P0034). |
| `RS\ddl\10_tablas_trabajo_f2_4.sql` | `w_borrar_002`, `w_ejecutor` y una lista (en comentarios) de objetos que la migración aún no construye. |
| `RS\procedures\01_sp_batch2_genera_lote.sql` | Procedure que entrega el número de lote (correlativo). |
| `RS\procedures\02_sp_batch2_log_helpers.sql` | Auxiliares: registrar inicio/fin, ejecutar SQL con bitácora (`sp_execstring_des`), borrar tablas. |
| `RS\procedures\03_sp_batch2_cubo_export.sql` | Pivota los cubos a `w_cubo_*`. |
| `RS\procedures\04_sp_batch2_exportplano.sql` | Arma y descarga a S3 los CSV (`UNLOAD`). |
| `RS\procedures\05_sp_batch2_exportlog.sql` | Arma y descarga el archivo de log (`BATCH_SOLICITUD_BATCH.ARCHIVO_LOG_W`). |
| `RS\procedures\06_sp_batch2_actualiza_historia.sql` | Cierra la solicitud (`estado='GENERADO'`) y llena la historia si aplica. |
| `RS\procedures\07_sp_batch2_valida_archivos.sql` | Cuenta los campos configurados de la plantilla (solo informa). |
| `RS\procedures\08_sp_batch2_procesacubos.sql` | 13 SP de filtros A..J, homologaciones, porcentajes e inconsistencias (la mayor parte de la lógica de negocio). |
| `RS\procedures\09b_sp_batch2_motores_sql.sql` | Motores `sp_batch2_estadisticas_cfg` y `sp_batch2_plan_ejecucion_shell`. |
| `RS\procedures\09_sp_batch2_otros.sql` | `transpuesta`, `completitud_canal`, `cantrepcanal_con`, `estadisticas`, `estadisticas_export`. |
| `RS\procedures\10_sp_batch2_proceso_batch2.sql` | Orquestador: llama a todos en orden. |
| `RS\datos\01_catalogos_motor.sql` | Filas de catálogos: 18 de `batch_archivo_log`, 18 `LOG` de `batch_motor_log`, 12 `ITERADOR` de `pro_plan_ejecucion`. |
| `RS\lambda\udf_similitud\lambda_function.py` | Código de la Lambda que atiende las 4 UDF de similitud. |
| `RS\lambda\udf_similitud\test_lambda_function.py` | 36 pruebas unitarias de esa Lambda. |
| `RS\lambda\udf_similitud\casos_validacion_teradata.sql` / `casos_validacion_redshift.sql` | Casos para comparar la distancia de edición en Teradata vs Redshift. |
| `RS\.agents\tasks\inventario_dependencias.md` | Este archivo. |

No existe `lambda\udf_similitud\README.md` (los datos de despliegue están en la cabecera de `ddl/08_funciones_udf.sql:50-70`). No existe ningún script `COPY` ni de carga de insumo en `RS`. No existe `Redshift\datos\` más allá de `01_catalogos_motor.sql`.

Muestras de referencia de Teradata (fuera de `RS`): `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\`: `CON_DATOS_4421_20240902100353.CSV/.ESQUEMA`, `SIN_DATOS_...`, `INCONSISTENCIA_...`, `ALERTAS-4421_...`, `BATCH_SOLICITUD_BATCH.ARCHIVO_LOG`. [VERIFICADO] Los `.CSV` de muestra contienen **solo la cabecera** (CON_DATOS: 659 bytes, 1 salto de línea; SIN_DATOS: 266 bytes; INCONSISTENCIA: 158 bytes), sin filas de datos. La muestra CON_DATOS tiene 34 columnas (config 4421: 1 teléfono, 1 dirección, 1 correo, 1 "Numero"); **no existe en el workspace ninguna muestra con la configuración 3/3/2/2**.

---

## 2. Afirmaciones de la guía actual y su veredicto

| # | Afirmación de la guía | Veredicto |
|---|---|---|
| G1 | Esencial = 3 direcciones, 3 teléfonos fijos, 2 celulares, 2 correos "según disponibilidad" | Definición de negocio; no verificable en código. **Conservar.** |
| G2 | Los límites se configuran en `batch_salidas_campos.cantidad_max_campo` | Cierto (`ddl/02:115`), pero el código solo lo usa para códigos concretos: `DT_NUM`, `CE_CORREO`, `DD_DIR`, `DC_NUMERO`, `DB_CIIU`, `DECB_NOM` (FILTRO_G `08:1656`; ADD_PORC_INSUMO `08:2900-3170`). Los códigos `DIR/TEL/CEL/MAI` del ejemplo 4.3 no coinciden. |
| G3 | 3.1: falta el bloque `_003` en `w_cubo_direccion` | **Vigente.** `ddl/04:53-63` solo tiene `_001` y `_002`; `procedures/03:102` tiene `WHERE rn <= 2`. |
| G4 | 3.1: telefono llega a `_005`; celular y correo a `_002` | Cierto (`ddl/04:26-35` 5 bloques×9 cols; `:41-47` celular 2 bloques; `:65-70` correo 2 bloques). |
| G5 | 3.2: `exportplano` usa layout fijo, sin celular, sin leer `batch_salidas_campos` | **Vigente.** Ver sección 3.2. |
| G6 | Las 5 SP de F2-4 son lógica real, no placeholders | Cierto como código. Pero `transpuesta`, `completitud_canal`, `estadisticas`, `cantrepcanal_con` no ejecutan por objetos faltantes (sección 3.3). `plan_ejecucion_shell` y `estadisticas_cfg` son lógica real que, sin filas, no hacen nada. |
| G7 | 4.1 / 4.2 / 4.3: columnas de los INSERT | Las listas de columnas y su cantidad (11 / 17 / 17) coinciden con los `CREATE TABLE` (sección 9.1). Hay problemas de valores: `prueba='S'`, códigos de campo, `requerido_campo='N'`, columnas de `batch_datos_generales` que ningún SP lee. |
| G8 | "ddl/01..08 ... nunca ejecutado" | Desactualizado: hoy son `ddl/01..10`. |
| G9 | "10 `sp_batch2_*` esperados" en el Paso 3 | Incorrecto: 34 procedures (31 `sp_batch2_*` + `sp_execstring_des`, `sp_drop_si_existe`, `sp_drop_tabla_por_nombre`). |
| G10 | Consulta con `schemaname, procedurename` sobre `pg_proc` | Inválida (sección 12). |
| G11 | `CALL ... (p_id_solicitud => 90001, ...)` | La sintaxis documentada de `CALL` solo muestra argumentos posicionales [AWS: `r_CALL_procedure.html`]. No confirmé que la notación nombrada esté soportada → usar posicional. |
| G12 | "Los CREATE EXTERNAL FUNCTION se crean sin error aunque la Lambda no exista" | [SUPUESTO] La documentación AWS (`r_CREATE_EXTERNAL_FUNCTION.html`) no dice que valide la existencia de la Lambda en el `CREATE`, pero tampoco lo niega. Además el script trae marcadores literales `<LAMBDA_UDF_SIMILITUD>` e `<IAM_ROLE_LAMBDA_ARN>` que hay que reemplazar. |
| G13 | "Comentar llamadas a UDF en `08_sp_batch2_procesacubos.sql` para humo" | Innecesario y desaconsejable (cambia código). Basta con que las 4 funciones existan; la Lambda no se invoca con el insumo vacío [SUPUESTO]. |
| G14 | "descomentar el bloque opcional de P0034 para que ADD_PORC_INSUMO no falle" | Solo hace falta si la plantilla tiene una subsección que contenga "Validacion". Si no, `sp_batch2_add_porc_insumo` hace `RETURN` al inicio (`08:2847-2850`). Con las subsecciones del ejemplo 4.3 (`Direcciones`, `Telefonos`, `Celulares`, `Correos`) no se toca la vista ni las tablas P0034. |
| G15 | "`rec_vista.vu_persona` y `v_tipo_persona` las usa FILTRO_E" y "no bloquea" | Primera parte cierta; segunda falsa: bloquea (sección 6). También las usa `sp_batch2_cantrepcanal_con` (`09:713-714`). |
| G16 | `pro_plan_ejecucion` (12 `ITERADOR`) y `batch_motor_log` (18 `LOG`) | Conteos **verificados** leyendo `datos/01_catalogos_motor.sql` (IDs 1..12 y 1..18; más 18 filas de `batch_archivo_log`). |
| G17 | Filas `FILTRO-C` siguen sin llegar | Cierto: `datos/` no carga `tipo='FILTRO-C'`; `sp_batch2_filtro_c` itera 0 filas (no-op). |
| G18 | 3.4 requisitos AWS (bucket, IAM, collation) | Cierto. Detalle y matices en secciones 10 y 8.3. |
| G19 | 3.4 "la carga masiva del CSV de insumo ... no está escrita aún" | Cierto: no hay `COPY` en `RS`. |
| G20 | 3.5 tabla de objetos faltantes | Cierta salvo un error de atribución: `vstg_inconsis_pnpj` está en `P0033_BATCH2_EXPORTPLANO_111.BTQ` líneas 1134 y 1225, NO en `CUBOEXPORT_111.BTQ` (error replicado en `ddl/10_tablas_trabajo_f2_4.sql:72-77` y en `procedures/09_sp_batch2_otros.sql:129`). Falta añadir a la lista `rec_vista.vu_persona`, `rec_vista.v_tipo_persona`, `rec_vista.v_evento_entrega_dato`, `rec_vista.v_cod_entrega_dato`. |
| G21 | §7 "los 13 SP ... canal de contacto/cantidad por canal (placeholder)" y "WARNING `PLACEHOLDER NO IMPLEMENTADO`" | Desactualizado: no existe ese texto en `procedures/` (solo comentarios históricos). |
| G22 | §7 nombres de archivo en S3 | Cierto en lo esencial, pero el sufijo real es `000` (UNLOAD `PARALLEL OFF`), no `0000_part_00`; ver sección 10. Y se generan 7 prefijos de datos, no 3. |
| G23 | §9 "lógica real de ... (hoy placeholder)", "ESTADISTICAS_CFG sin código fuente" | Desactualizado: ya migrados. |
| G24 | "Supuesto sin confirmar: editdistance_u = Damerau-Levenshtein OSA" | **Sigue sin confirmar** (requiere `casos_validacion_teradata.sql` en Teradata). |
| G25 | "`DB COLLATE CASE_INSENSITIVE` ... no se puede cambiar después" | Cierto en lo documentado por el código (`08:~58`) y por AWS; ver 8.3. |

---

## 3. Gaps conocidos, verificados contra el código

### 3.1 `w_cubo_direccion` sin bloque `_003` — VIGENTE

- `RS\ddl\04_tablas_pivote.sql:53-63`: `w_cubo_direccion` tiene `id_buro_persona`, `filtro_h` y solo los bloques `_001` y `_002` (11 columnas cada uno: `ciudad, departamento, codigo_dane_ciudad, codigo_dane_departamento, direccion, tipo, zona, estrato, fecha_ultima_actualizacion, numero_entidades_reporta, por_sim_dir`). Total 24 columnas.
- `RS\procedures\03_sp_batch2_cubo_export.sql:85-104`: el `INSERT INTO rec_stage.w_cubo_direccion SELECT ...` es posicional (sin lista de columnas), con `MAX(CASE WHEN rn = 1 ...)`, `rn = 2` y `WHERE rn <= 2` (línea 102). Si se añade `_003` hay que cambiar a la vez el DDL y el `INSERT` (mismo número de columnas).
- Teléfono: `WHERE rn <= 5` (línea 56). Celular: `rn <= 2` (79). Correo: `rn <= 2` (125). CIIU: `rn = 1` (línea 147).
- **Hallazgo adicional:** todo el DDL usa `CREATE TABLE IF NOT EXISTS`. Si `w_cubo_direccion` ya existe (de un despliegue previo), editar el script NO le añade `_003`: hay que `DROP TABLE`/recrear o `ALTER TABLE ... ADD COLUMN` (idempotencia, sección 8.2).
- **Hallazgo adicional (límites de longitud):** las `w_cubo_*` tienen columnas más cortas que los cubos origen; un dato más largo hace fallar el `INSERT ... SELECT` de `cubo_export` ("value too long"): `ciudad`/`departamento` 100→30, `tipo` 30→15, `direccion` 200→100, `zona` 30→10, `estrato` 10→5, `correo` 200→61, `numero` 30→30. Los datos de prueba deben respetar el límite más corto (sección 9.3).

### 3.2 `sp_batch2_exportplano` con layout fijo — VIGENTE

Verificado en `RS\procedures\04_sp_batch2_exportplano.sql`:
- El código **no referencia** `batch_salidas_campos` ni `batch2_homologacion` (solo los menciona en comentarios de cabecera, líneas 16-26, que afirman lo contrario de lo que hace el código). Tampoco referencia `w_cubo_celular` (no hay `LEFT JOIN` a celular).
- Layout construido (líneas 87-106): 12 columnas de persona + `CIIU 001` + `Actividad economica 001` (14) + si es "CON DATOS": 8 de teléfono `_001` + 10 de dirección `_001` + `Correo 001` + `Numero 001b` (tomado de `w_cubo_correo.numero_001`). Total 34 columnas (coincide con la muestra Teradata 4421) / 14 columnas para "SIN DATOS".
- Aliases con sufijo `b` para evitar duplicados (`"Ciudad 001b"`, `"Tipo 001b"`, ...): no coinciden con la cabecera de la muestra Teradata (que repite `Ciudad 001`, `Tipo 001`, etc.).
- **Posible error de mapeo (hallazgo):** en la muestra Teradata (`CON_DATOS_4421_...ESQUEMA`) la última columna es `DC_NUMERO` ("Numero 001") y, según `08_...` (FILTRO_G, ADD_PORC_INSUMO) y `datos/01` (LOG 14), `DC_NUMERO` es el número del **celular**. En Redshift esa columna se llena con `w_cubo_correo.numero_001`, que es una columna "compat" de `batch_cubo_correo`. Es decir, el CSV Redshift probablemente no entrega el celular en esa posición. [SUPUESTO sobre el mapeo de Teradata; el hecho de que el código lea de `w_cubo_correo` es VERIFICADO]
- Filtro de sección: "CON DATOS" → `filtro_h = 0`; "SIN DATOS" → `filtro_h > 0` (líneas 70-77, 108-115).
- Cada llamada ejecuta **4 `UNLOAD`** (PNPJ, PN, PJ, INCONSISTENCIA), no uno (líneas 124, 135, 140, 165). Como el orquestador llama dos veces (CON y SIN), `INCONSISTENCIA_*` se descarga dos veces con el mismo nombre (`ALLOWOVERWRITE`).
- Opciones de `UNLOAD`: `DELIMITER AS ';' PARALLEL OFF ALLOWOVERWRITE HEADER` (línea 78). Los nombres de archivo (`CON_DATOS_`, `SIN_DATOS_`, `INCONSISTENCIA_`) y el separador `;` están escritos en el código: **ninguna columna de `batch_datos_generales` los gobierna** (sección 9.1).

### 3.3 SP de F2-4: lógica real vs. placeholder

Todos son lógica real (no hay ningún `RAISE`/stub tipo placeholder; `grep -i placeholder RS\procedures` solo da comentarios históricos). Estado por SP:

| SP | Archivo:línea | ¿Lógica real? | ¿Puede ejecutarse hoy? | Qué le falta |
|---|---|---|---|---|
| `rec_stage.sp_batch2_transpuesta` | `09:164` | Sí (~170 líneas, SQL dinámico de 3 niveles) | **No** | `rec_stage.v_ba2_campos_salida`, `rec_stage.vstg_batch2_pn/_pj/_pnpj`. Solo la invoca el orquestador si `orientacion = 'OE_VERTICA'` (`10:151`). Con `OE_HORIZON` no se llama. |
| `rec_stage.sp_batch2_completitud_canal` | `09:364` | Sí (replica los bugs B-04) | **No** | `vstg_batch2_pnpj/_pj/_pn` y `v_ba2_campos_salida`: el paso 1 hace `CREATE OR REPLACE VIEW rec_stage.v_datos_tmp1 AS SELECT * FROM rec_stage.vstg_batch2_pnpj UNION ...` (no late-binding) y falla. **Es la primera falla del orquestador.** |
| `rec_stage.sp_batch2_cantrepcanal_con` | `09:687` | Sí (motor + 2 tablas de trabajo) | **No** | `rec_vista.vu_persona`, `rec_vista.v_tipo_persona` (paso 1), `rec_stage.batch_cubo_persona11` (paso 2). Aun con esos objetos, sin filas `tipo='CANT_REP_CANAL_CONTACTO'` en `batch_motor_log` solo crea 2 tablas y no hace más. |
| `rec_stage.sp_batch2_estadisticas` | `09:810` | Sí (~650 líneas) | **No** | `rec_stage.vstg_inconsis_pnpj` (paso inicial: `CREATE TABLE ... AS SELECT * FROM rec_stage.vstg_inconsis_pnpj`), filas de `rec_datos.pro_batch2_filtros_estadisticas`, tablas `batch_cubo_temp_*_total`. |
| `rec_stage.sp_batch2_estadisticas_export` | `09:1461` | Sí, parcial: exporta solo `identificador='GENERALES'` con `valor1 IN ('INCO','SIN_UBI','CON_UBI')`, no la vista completa | Sí (SQL) pero produciría un archivo vacío sin las filas de `batch_estadisticas_pro` | Filas de `batch_estadisticas_pro`. |
| `rec_stage.sp_batch2_estadisticas_cfg` | `09b:55` | Sí (motor) | Sí; sin filas en `pro_batch2_filtros_estadisticas` no hace nada | Filas del catálogo. |
| `rec_stage.sp_batch2_plan_ejecucion_shell` | `09b:130` | Sí (motor) | Sí; sin filas en `pro_plan_ejecucion` no hace nada; con las 12 filas de `datos/01` ejecuta SQL (crea vistas/tablas) [SUPUESTO: nunca corrió en Redshift] | Nada para el caso vacío. |

Comentario obsoleto detectado: `09b_sp_batch2_motores_sql.sql:52-54` todavía dice que `ESTADISTICAS` "sigue como placeholder (tarea F2-4)".

---

## 4. Cadena completa del orquestador y qué toca cada paso

`rec_stage.sp_batch2_proceso_batch2` (`RS\procedures\10_sp_batch2_proceso_batch2.sql:47-250`). Orden y líneas de los `CALL`:

| Paso | Línea | Llamada | Lee | Escribe / crea | Puede fallar hoy por |
|---|---|---|---|---|---|
| 1 | 72 | `rec_mtdat.sp_batch2_genera_lote(v_lote)` | `rec_mtdat.lote_id` | `lote_id` (+1) | — |
| (pre) | 84-92 | `SELECT ... FROM batch_datos_generales WHERE id_solicitud = p LIMIT 1` | `batch_datos_generales` | — | Falta la fila → `RAISE EXCEPTION` ("no existe configuracion..."). |
| 2 | 98 | `sp_batch2_plan_ejecucion_shell(lote,'ITERADOR',sol,'ITERADOR')` | `pro_plan_ejecucion` | si hay filas: `batch2_shells_config`, `stg_insumo_batch_validacion`, `integrador_tmp`, `orden_shell`, `temp1`, `batch2_shells_planejecucion` | Sin filas: no-op. Con las 12 filas: [SUPUESTO] vistas late-binding con `TOP 200 ... ORDER BY` y vista sobre vista nunca probadas en Redshift. |
| 3 | 104 | `sp_batch2_valida_archivos(sol, pla, INOUT, INOUT)` | `batch_salidas_campos` | — | Solo `RAISE WARNING` si no hay campos. |
| 4a | 114 | `filtro_a` | `batch_direccion_filtros`, `batch_cubo_direccion` | `pro_batch2_filtro_a1`, `batch_cubo_direccion.filtro_a` | — |
| 4b | 115 | `filtro_b` | `batch_datos_generales`, 4 cubos | `pro_batch2_filtro_b`, `filtro_b` | Falla si hay >1 fila de `batch_datos_generales` para (sol, pla). |
| 4c | 116 | `filtro_c` | `batch_motor_log` (`tipo='FILTRO-C'`) | — | Sin filas: no-op. |
| 4d | 117 | `filtro_d` | `batch_salidas_campos` ⋈ `batch2_homologacion` (`requerido_campo='SI'`) | `bacth_fd_*`, `<cubo>fd`, `filtro_d` | Sin join: no-op. |
| 4e | 118-119 | `filtro_e(...,'N')`, `filtro_e(...,'J')` | `batch_cubo_persona`, **`rec_vista.vu_persona`**, **`rec_vista.v_tipo_persona`**, `batch_porcentajes_filtros`, 4 cubos | `batch_cubo_persona_filtro_tp`, `batch2_tipo_persona`, `_f`, `_porc`, `pro_batch2_filtro_e`, `filtro_e` | **FALLA: `vu_persona`/`v_tipo_persona` no existen** (`08:731-732`). |
| 4f | 120 | `filtro_f` | `stg_insumo_batch_validacion`, `batch_cubo_persona`, `batch_porcentajes_filtros`, 4 cubos, **4 funciones `rec_vista.f_*`** | `filtro_*_2`, `filtro_3_*`, `filtro_4_res`, `filtro_f`, `por_sim_*` | **FALLA si las 4 funciones no existen** (se referencian en `CREATE TABLE ... AS` sin importar las filas). Con insumo vacío la Lambda no debería invocarse [SUPUESTO]. |
| 4g | 121 | `filtro_g` | `batch_salidas_campos` ⋈ `batch2_homologacion` | `bacth_fg_*`, `filtro_g` en 6 cubos | Sin `batch2_homologacion`: no-op (nada se trunca a 3/3/2/2). |
| 4h | 122 | `homologaciones` | `batch_homologaciones` ⋈ `batch2_homologacion`, `batch_solicitud_batch` | `batch_cubo_persona.numero_id` (BIGINT→texto), `bacth_homg_*`, `<cubo>ho/ho1`; si `prueba<>'SV'`: enmascara cubos y `batch_cubo_*_mask` | `numero_id`/`tipo_id` no numéricos → error de `CAST`. |
| 4i | 123 | `filtro_i` | 4 cubos | `bacth_fi_1`, `filtro_i` (1 si `orden_prioridad IS NULL`) | — |
| 4j | 124 | `filtro_h` | 6 cubos, `batch_salidas_campos` ⋈ `batch2_homologacion` | `filtro_h` en cubos y persona; **DELETE** de filas | — |
| 4k | 125 | `filtro_j` | `batch_cubo_correo`, `batch_cubo_celular` | `dup_*`, `detallevalores`; DELETE de duplicados | Depende de COLLATE CASE_INSENSITIVE (compara `'Correo'` con `'correo'`). |
| 4l | 126 | `add_porc_insumo` | `batch_salidas_campos` (subsección `%Validacion%`) | solo si existe esa subsección: `tmp_batch_porpos_*`, `stg_insumo_batch_validacion`; lee `vstgbatchcargaubicestandarizada` | Sin "Validacion": `RETURN` inmediato. |
| 4m | 127 | `adicionar_incon` | `batch_identificaciones_validas`, `batch_cubo_persona`, `_incons` | `batch2_tabla_inconsis_ad_tmp`, INSERT en `_incons` (estado `06`, causal `04`), DELETE de `_validas` | `numero_id` no numérico en `_validas` → error. |
| 5 | 134 | `cubo_export(sol, pla)` | 6 cubos + `batch_cubo_persona` | `TRUNCATE`+`INSERT` en 5 `w_cubo_*` | "value too long" por límites de `w_cubo_*` (3.1). `TRUNCATE` hace COMMIT implícito. |
| 6 | 141 | `exportplano(sol, pla, 'CON DATOS DE UBICACION', bucket, rol, fch)` | `batch_cubo_persona`, `rec_vista.persona`, `w_cubo_ciiu/telefono/direccion/correo`, `batch_identificaciones_incons` | 4 `UNLOAD` a S3 | `rec_vista.persona` vacía → CSV vacíos; IAM/S3. |
| 7 | 142 | `exportplano(..., 'SIN DATOS DE UBICACION', ...)` | ídem | 4 `UNLOAD` a S3 | ídem |
| 8 | 154-157 | `transpuesta` ×1 o ×2 (solo `OE_VERTICA`) | `v_ba2_campos_salida`, `vstg_batch2_*` | `tb_vstg_batch2_*` | No se ejecuta con `OE_HORIZON`. |
| **9** | **168** | `completitud_canal(lote,proc,pla,sol)` | `v_ba2_campos_salida`, `vstg_batch2_*`, `secuencia`, `w_borrar_002`, `w_ejecutor` | `v_datos_tmp1`, `v_telefono_tmp1`, `v_direccion_tmp1`, `tabla_w1`, `tabla_w2` | **FALLA: `vstg_batch2_pnpj` no existe.** Primera falla del orquestador. |
| 10 | 183-189 | `cantrepcanal_con(...,'0')`, `(...,'1')` | `vu_persona`, `v_tipo_persona`, `batch_cubo_persona11`, `batch_motor_log` | `batch2tipodoc`, `batch2personadoc` | **FALLA** (objetos faltantes). |
| 11 | 195-196 | `estadisticas(...)` + `estadisticas_export(...)` | `vstg_inconsis_pnpj`, `pro_batch2_filtros_estadisticas`, `batch_cubo_temp_*_total`, ... | `batch_estadisticas_pro`, `vstg_batch_estadisticas_exp`, archivo `ALERTAS-...` | **FALLA** (`vstg_inconsis_pnpj`). |
| 12 | 220 | `exportlog(...)` | `batch_motor_log` (18 `LOG`), `batch_archivo_log`, `rec_vista.v_evento_entrega_dato`, `v_cod_entrega_dato`, `vstg_buropers_tmp`, `tipo_identificacion` | `batch_archivo_log.valor`; `UNLOAD` de `BATCH_SOLICITUD_BATCH.ARCHIVO_LOG_W` | **FALLA** en LOG ID 6 y 13 (vistas del DW inexistentes). |
| 13 | 234 | `actualiza_historia(sol, pla)` | `batch_datos_generales`, `batch_solicitud_batch`, 4 cubos, `vstg_buropers_tmp` | `batch_historia_resultados` (solo si `no_entregado_x_meses > 0`); `batch_solicitud_batch.estado='GENERADO'` | Solo actualiza si `estado IS NULL AND fecha_generacion IS NULL`. |
| fin | 241 | `fallo_en_lote(lote, INOUT v_fallo)` | `log_td_detalle` | — | — |

**Conclusión verificada:** con las 4 funciones creadas y las 2 vistas del §6.2, el orquestador llega a generar los CSV (pasos 6-7) y cae en el paso 9. Para la prueba hoy lo realista es: (A) ejecutar los SP en secuencia (sección 7.3), o (B) llamar al orquestador sabiendo que terminará con error en el paso 9 y que los CSV ya estarán en S3.

### 4.1 Clasificación (i) / (ii) / (iii)

**(i) MÍNIMO INDISPENSABLE para generar los 3 CSV** (pasos 1, 3-7, ejecutados a mano o vía orquestador hasta el paso 7):
- Esquemas, `rec_mtdat.lote_id/log_td/log_td_detalle`, los 7 cubos, los 5 `w_cubo_*`, `batch_identificaciones_validas/_incons`, `batch_solicitud_batch`, `batch_datos_generales`, `batch_salidas_campos`, `batch_direccion_filtros`, `batch_homologaciones`, `batch_porcentajes_filtros`, `batch2_homologacion`, `batch_motor_log`, `pro_plan_ejecucion`, `stg_insumo_batch_validacion`, `rec_vista.persona` (con filas), `rec_vista.tipo_persona`.
- Funciones: `rec_vista.f_td_to_number`, las 4 `f_*similitud*` (para que compile FILTRO_F), y las 3 de enmascaramiento si `prueba <> 'SV'`.
- No-DDL: `rec_vista.vu_persona` y `rec_vista.v_tipo_persona` (§6.2).
- Todos los 34 procedures (los auxiliares y de PROCESACUBOS, `cubo_export`, `exportplano`, `valida_archivos`, `genera_lote`).

**(ii) Opcionales que NO bloquean los 3 CSV:** `rec_stage.secuencia` (la lee `completitud_canal`), `batch_valform_st2/st4`, `rec_datos.pro_batch2_filtros_estadisticas`, `rec_vista.tipo_identificacion`, `batch_estadisticas_pro`, `batch_historia_resultados`, `batch_archivo_log`, `batch2_cantidad_reporte_canal` (ningún SP actual la referencia), `batch2_shells_config`, `batch2_shells_planejecucion`, `w_borrar_002`, `w_ejecutor`, `vstg_buropers_tmp`, `vstgbatchcargaubicestandarizada`, `datos/01_catalogos_motor.sql` completo (solo lo necesitan el paso 2 —no-op sin filas— y el paso 12), la Lambda real (solo se invoca con insumo no vacío).

**(iii) Objetos que la migración AÚN NO construye** (verificado: no hay `CREATE` en `RS\ddl`, `RS\datos` ni `RS\procedures`; solo `vstg_buropers_tmp` y `tipo_identificacion` existen como tablas vacías):

| Objeto faltante | Quién lo necesita | Paso que bloquea | Origen/DDL original |
|---|---|---|---|
| `rec_vista.vu_persona`, `rec_vista.v_tipo_persona` | FILTRO_E (`08:731-732`), `cantrepcanal_con` (`09:713-714`) | **4e** (bloquea los 3 CSV) y 10 | Vistas del DW (Teradata `BTTPRUVI`/`BDM_VISTA`); no hay DDL en el workspace. Existen `rec_vista.persona` y `rec_vista.tipo_persona` con las mismas columnas que usa el código. |
| `rec_stage.v_ba2_campos_salida` | `transpuesta`, `completitud_canal` | 9 (y 8 si vertical) | `RS` no la crea. `P0033_BATCH2_CUBOEXPORT_111.BTQ`: `vstg_BA2_CAMPOS` línea 43, `v_BA2_CamposBase` 177 y 754, `v_ba2_Campos_Salida` 1339. [VERIFICADO] |
| `rec_stage.vstg_batch2_pn/_pj/_pnpj` | `transpuesta`, `completitud_canal` | **9** | `P0033_BATCH2_EXPORTPLANO_111.BTQ` líneas ≈202-226 (se generan como texto dinámico) y `_120.BTQ`. [VERIFICADO] |
| `rec_stage.vstg_inconsis_pnpj` | `estadisticas` | 11 | `P0033_BATCH2_EXPORTPLANO_111.BTQ` líneas 1134 (ancho fijo) y 1225 (variable). **No** está en `CUBOEXPORT_111.BTQ`. [VERIFICADO] |
| `rec_stage.batch_cubo_persona11` | `cantrepcanal_con` | 10 | Solo aparece en `Sps_Batch.sql:9121`; sin DDL en el workspace. [VERIFICADO] |
| `rec_stage.batch_cubo_temp_dir_total` y `_telefono_total`, `_celular_total`, `_correo_total` | `estadisticas` | 11 | Las crearía `estadisticas_cfg` (`parte='TMP_ESTADISTICAS'`) a partir de filas de `pro_batch2_filtros_estadisticas`, que no existen. [VERIFICADO] |
| `rec_vista.v_evento_entrega_dato`, `rec_vista.v_cod_entrega_dato` | `batch_motor_log` LOG ID 6 y 13 (`datos/01:112-125` y `:183-200`) | 12 | Vistas del DW. Declaradas como dependencia externa en `ddl/07:217-221`. |
| Filas: `batch_motor_log` `tipo='FILTRO-C'`; `tipo='CANT_REP_CANAL_CONTACTO'`; `rec_datos.pro_batch2_filtros_estadisticas`; `batch2_shells_config`; `batch2_homologacion`; `batch_porcentajes_filtros`/`batch_homologaciones`/`batch_direccion_filtros` (config por solicitud) | Varios | 2, 4c, 4g/4d/4h/4j, 10, 11 | Insumos pendientes del equipo Teradata (ver `Bitacora_Batch_Teradata.md`). |

---

## 5. Tablas que ya deben existir en Redshift para la prueba, y dónde está su DDL

Total tras ejecutar `ddl/01..10`: **43 tablas** (rec_datos 3, rec_mtdat 3, rec_stage 34, rec_vista 3) + **1 vista** (`rec_stage.vstgbatchcargaubicestandarizada`) + **8 funciones** (`rec_vista.f_*`) + **4 esquemas**. Los 34 procedures los crea `RS\procedures\`. [VERIFICADO contando los `CREATE` no comentados]

Leyenda "Nec.": **M** = mínimo indispensable para los 3 CSV; **O** = opcional (no bloquea los 3 CSV); **P** = pivote/resultado. "Filas" indica qué datos hay que cargar para la prueba.

### 5.1 Esquemas
| Objeto | DDL | Nec. |
|---|---|---|
| `rec_stage`, `rec_mtdat`, `rec_datos`, `rec_vista` | `RS\ddl\01_schemas.sql:17-20` | M |

### 5.2 Configuración / solicitud
| Tabla | DDL | Nec. | Filas necesarias / observaciones |
|---|---|---|---|
| `rec_stage.batch_solicitud_batch` | `ddl/02_tablas_configuracion.sql:143` | M | 1 fila por `id_solicitud`. `prueba` NULL o `'SV'` = sin enmascarar. `estado` y `fecha_generacion` en NULL para que `actualiza_historia` la cierre. |
| `rec_stage.batch_datos_generales` | `ddl/02:26` | M | **Exactamente 1 fila** por (`id_solicitud`, `id_plantilla`): >1 provoca error de subconsulta escalar. El código solo lee `id_plantilla`, `orientacion`, `archivos_pn_pj`, `no_entregado_x_meses`. |
| `rec_stage.batch_salidas_campos` | `ddl/02:115` | M | Filas con `codigo_campo` reales (§9.2). Una fila por `codigo_campo` por (solicitud, plantilla). |
| `rec_stage.batch_direccion_filtros` | `ddl/02:55` | M | Puede estar vacía (FILTRO_A no marca nada). |
| `rec_stage.batch_homologaciones` | `ddl/02:72` | M | Puede estar vacía. |
| `rec_stage.batch_porcentajes_filtros` | `ddl/02:90` | M | Vacía = FILTRO_E/F no hacen nada; si hay filas, 1 por (solicitud, plantilla). |
| `rec_stage.batch2_homologacion` | `ddl/05_tablas_control.sql:101` | M | **Sin script de carga en el workspace.** Vacía = FILTRO_D/G/H(4)/HOMOLOGACIONES inactivos (el truncamiento 3/3/2/2 no ocurre). Para activar FILTRO_G ver §9.2. |
| `rec_stage.batch_motor_log` | `ddl/07_tablas_dependencias_sps.sql:30` | M | Puede estar vacía para los 3 CSV; `datos/01` carga 18 `LOG` (solo paso 12). |
| `rec_stage.pro_plan_ejecucion` | `ddl/07:52` | M | Vacía = paso 2 no-op. `datos/01` carga 12 `ITERADOR`. |
| `rec_stage.batch2_shells_config` | `ddl/07:74` | O | Sin filas. Solo la tocan las 12 filas `ITERADOR`. |
| `rec_stage.batch2_shells_planejecucion` | `ddl/05:68` | O | La borra/recrea el motor en cada corrida. |
| `rec_stage.stg_insumo_batch_validacion` | `ddl/07:95` | M | Vacía (la lee FILTRO_F y, solo con "Validacion", ADD_PORC). |

### 5.3 Cubos con datos de entrada
Todas con `DISTKEY(id_buro_persona)`. Las 7 deben existir (los SP actualizan/borran en todas); a las 6 primeras hay que cargarles datos.

| Tabla | DDL | Nec. | Observaciones |
|---|---|---|---|
| `rec_stage.batch_cubo_persona` | `ddl/03_tablas_cubos.sql:30` | M | `id_solicitud` e `id_plantilla` ("compat") **obligatorios en la práctica**: `cubo_export` y `exportplano` filtran por ellos. `tipo_id` y `numero_id` numéricos como texto. |
| `rec_stage.batch_cubo_direccion` | `ddl/03:60` | M | `orden_prioridad` no nulo (FILTRO_I). |
| `rec_stage.batch_cubo_telefono` | `ddl/03:104` | M | ídem |
| `rec_stage.batch_cubo_celular` | `ddl/03:144` | M | ídem |
| `rec_stage.batch_cubo_correo` | `ddl/03:184` | M | ídem |
| `rec_stage.batch_cubo_ciiu` | `ddl/03:219` | M | Opcional con datos (el export hace LEFT JOIN), pero la tabla debe existir. |
| `rec_stage.batch_cubo_punto_interes_dir` | `ddl/03:241` | M | Puede estar vacía. |

### 5.4 Pivote
| Tabla | DDL | Nec. |
|---|---|---|
| `rec_stage.w_cubo_telefono` | `ddl/04_tablas_pivote.sql:26` | P (5 bloques `_001.._005`) |
| `rec_stage.w_cubo_celular` | `ddl/04:41` | P (2 bloques; no la lee `exportplano`) |
| `rec_stage.w_cubo_direccion` | `ddl/04:53` | P (2 bloques; falta `_003`) |
| `rec_stage.w_cubo_correo` | `ddl/04:65` | P (2 bloques) |
| `rec_stage.w_cubo_ciiu` | `ddl/04:77` | P (1 bloque) |

### 5.5 Control, log, resultados
| Tabla | DDL | Nec. | Observaciones |
|---|---|---|---|
| `rec_mtdat.lote_id` | `ddl/05:14` | M | Siembra una fila `lote=0` (idempotente). |
| `rec_mtdat.log_td` | `ddl/05:30` | M | Solo el orquestador escribe aquí. |
| `rec_mtdat.log_td_detalle` | `ddl/05:46` | M | Bitácora paso a paso: `lote, fecha_hora, nombre_proceso, cadena, paso, descripcion_teradata_error`. |
| `rec_stage.batch_identificaciones_validas` | `ddl/05:166` | M | `numero_id` numérico. |
| `rec_stage.batch_identificaciones_incons` | `ddl/05:177` | M | Fuente del CSV `INCONSISTENCIA`. |
| `rec_stage.batch_archivo_log` | `ddl/05:206` | O | Paso 12. `datos/01` carga 18 filas. |
| `rec_datos.batch_historia_resultados` | `ddl/05:121` | O | Paso 13 solo si `no_entregado_x_meses > 0`. |
| `rec_datos.batch_estadisticas_pro` | `ddl/05:139` | O | Paso 11. |
| `rec_stage.batch2_cantidad_reporte_canal` | `ddl/05:219` | O | Ningún SP actual la referencia. |

### 5.6 Dimensión, dependencias y auxiliares
| Objeto | DDL | Nec. | Observaciones |
|---|---|---|---|
| `rec_vista.persona` | `ddl/06_vistas_dimension.sql:31` | **M (con filas)** | La lee `exportplano` (join por tipo) y es la base propuesta para `vu_persona`. **No trae filas.** Necesita 4: tipos 1, 4 (→ `cod_dw_tipo_persona=1`) y 2, 3 (→ 2). |
| `rec_vista.tipo_persona` | `ddl/06:17` | M | Trae 2 filas sembradas (1 `NATURALES`, 2 `JURIDICAS`). |
| `rec_stage.vstg_buropers_tmp` | `ddl/06:45` | O | Pasos 12-13. |
| `rec_vista.tipo_identificacion` | `ddl/07:146` | O | Paso 12 (LOG 7) y 11. |
| `rec_stage.secuencia` | `ddl/07:157` | O | Siembra 1..100 (idempotente). La lee `completitud_canal`. |
| `rec_stage.batch_valform_st2`, `batch_valform_st4` | `ddl/07:181`, `:188` | O | Propiedad de P0037; las lee `estadisticas`. |
| `rec_datos.pro_batch2_filtros_estadisticas` | `ddl/07:131` | O | Paso 11; sin filas. |
| `rec_stage.w_borrar_002`, `rec_stage.w_ejecutor` | `ddl/10:26`, `:39` | O | `completitud_canal` las borra y recrea al inicio. |
| `rec_stage.vstgbatchcargaubicestandarizada` (vista late-binding) | `ddl/09_vistas_dependencias_sps.sql:57` | O | Solo ADD_PORC_INSUMO con subsección "Validacion". Lee tablas P0034 que no existen (bloque opcional comentado en `ddl/09:156-180`). |

### 5.7 Funciones (UDF)
| Función | DDL | Tipo | Nec. |
|---|---|---|---|
| `rec_vista.f_td_to_number(VARCHAR)` | `ddl/08_funciones_udf.sql:77` | SQL UDF | M (la usan FILTRO_B/E/F/G, HOMOLOGACIONES, ADICIONAR_INCON, `completitud_canal`) |
| `rec_vista.f_bach_similitud_dir_mz` | `ddl/08:98` | Lambda UDF | M (existir) |
| `rec_vista.f_porc_similitud` | `ddl/08:110` | Lambda UDF | M (existir) |
| `rec_vista.f_bach_similitud_tel` | `ddl/08:119` | Lambda UDF | M (existir) |
| `rec_vista.f_bach_similitud_email` | `ddl/08:131` | Lambda UDF | M (existir) |
| `rec_vista.f_datamasking` | `ddl/08:152` | SQL UDF | M si `prueba<>'SV'`, si no O |
| `rec_vista.f_dirdatamasking` | `ddl/08:164` | SQL UDF | ídem |
| `rec_vista.f_razondatamasking` | `ddl/08:178` | SQL UDF | ídem |

---

## 6. Qué bloquea hoy y cómo se resuelve (propuestas derivadas del código)

### 6.1 Bloqueos por orden de aparición
1. **FILTRO_F** → faltan las 4 funciones Lambda (hasta que se ejecute `ddl/08` con los marcadores reemplazados).
2. **FILTRO_E** → faltan `rec_vista.vu_persona` y `rec_vista.v_tipo_persona`.
3. **exportplano** → `rec_vista.persona` vacía = CSV sin filas.
4. **Paso 9 del orquestador** → faltan `vstg_batch2_*` / `v_ba2_campos_salida`.
5. Pasos 10, 11 y 12 → objetos de la sección 4.1 (iii).

### 6.2 Solución para FILTRO_E (propuesta, NO existe en el repo)
Las columnas que lee el código son `vu_persona(cod_tipo_ident_fte, cod_dw_tipo_persona)` y `v_tipo_persona(cod_dw_tipo_persona, nombre_tipo_persona)` (`08:730-735`; `09:712-717`). Las tablas `rec_vista.persona` y `rec_vista.tipo_persona` las tienen. Vistas puente:

```sql
CREATE OR REPLACE VIEW rec_vista.vu_persona AS
SELECT cod_tipo_ident_fte, cod_dw_tipo_persona, num_ident FROM rec_vista.persona;

CREATE OR REPLACE VIEW rec_vista.v_tipo_persona AS
SELECT cod_dw_tipo_persona, nombre_tipo_persona FROM rec_vista.tipo_persona;

-- Una fila por tipo (exportplano hace JOIN solo por tipo; filas repetidas duplican resultados)
INSERT INTO rec_vista.persona (cod_tipo_ident_fte, cod_dw_tipo_persona, num_ident)
SELECT 1, 1, NULL WHERE NOT EXISTS (SELECT 1 FROM rec_vista.persona WHERE cod_tipo_ident_fte = 1)
UNION ALL SELECT 4, 1, NULL WHERE NOT EXISTS (SELECT 1 FROM rec_vista.persona WHERE cod_tipo_ident_fte = 4)
UNION ALL SELECT 2, 2, NULL WHERE NOT EXISTS (SELECT 1 FROM rec_vista.persona WHERE cod_tipo_ident_fte = 2)
UNION ALL SELECT 3, 2, NULL WHERE NOT EXISTS (SELECT 1 FROM rec_vista.persona WHERE cod_tipo_ident_fte = 3);
```
Con eso FILTRO_E obtiene `N`→{1,4} y `J`→{2,3} (toma la 1ª letra de `UPPER(nombre_tipo_persona)`: `NATURALES`/`JURIDICAS`) y `exportplano` separa PN (`IN (1,4)`) y PJ (`IN (2,3)`). [Lectura de código; el SQL propuesto no se ejecutó.] Documentar que son vistas de prueba, que en producción deben apuntar a las vistas reales del DW.

### 6.3 Funciones Lambda sin Lambda real (prueba de humo)
Reemplazar en `ddl/08_funciones_udf.sql` (8 apariciones en sentencias, líneas 102-103, 114-115, 123-124, 137-138; además los comentarios 61-62):
- `<LAMBDA_UDF_SIMILITUD>` → nombre o ARN de la Lambda (p. ej. `udf_similitud`).
- `<IAM_ROLE_LAMBDA_ARN>` → ARN del rol de Redshift con `lambda:InvokeFunction`, o la palabra `default`.
Sintaxis válida [AWS: `r_CREATE_EXTERNAL_FUNCTION.html`]: `IAM_ROLE { default | 'arn:aws:iam::<cuenta>:role/<rol>' }`. [SUPUESTO] El `CREATE` no valida que la Lambda exista. Alternativa más segura: desplegar la Lambda real (sección 11); el código ya está probado en local.
La documentación AWS también indica que `OR REPLACE` en una función externa requiere superusuario; el `CREATE EXTERNAL FUNCTION` requiere superusuario o el privilegio correspondiente.

---

## 7. Firmas exactas, orden de parámetros y ejemplos de `CALL`

Todas las firmas verificadas (`RS\procedures\*`, obtenidas por script sobre los 34 `CREATE OR REPLACE PROCEDURE`).

### 7.1 Orquestador
```
rec_stage.sp_batch2_proceso_batch2(
    p_id_solicitud     BIGINT,
    p_s3_bucket_salida VARCHAR(500),
    p_iam_role         VARCHAR(500))
```
Sin `OUT`/`INOUT`: **el lote no se devuelve**. Se ve en el mensaje `RAISE INFO 'PROCESO_BATCH2: lote=% ...'` (cliente / `SVL_STORED_PROC_MESSAGES` [AWS]) y en tablas (§7.4).

Ejemplo posicional (la guía actual usa `=>`):
```sql
CALL rec_stage.sp_batch2_proceso_batch2(
    90001,
    's3://<mi-bucket>/batch2/esencial/',          -- DEBE terminar en '/'
    'arn:aws:iam::<cuenta>:role/<RolUnloadRedshift>');
```
`p_s3_bucket_salida` se concatena directamente con el nombre de archivo (`04:126`: `p_s3_bucket_salida || v_prefijo_archivo || ...`); sin `/` final el nombre queda pegado al último segmento.

### 7.2 Firmas de los SP invocados
| SP | Firma exacta (orden) |
|---|---|
| `rec_mtdat.sp_batch2_genera_lote` | `(INOUT p_lote BIGINT)` |
| `rec_mtdat.sp_batch2_log_inicio` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_tabla_origen_stage VARCHAR(100), p_tabla_destino_prod VARCHAR(100))` |
| `rec_mtdat.sp_batch2_log_resultado` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_exitoso BOOLEAN, p_mensaje VARCHAR(500))` |
| `rec_mtdat.sp_batch2_fallo_en_lote` | `(p_lote BIGINT, INOUT p_fallo BOOLEAN)` |
| `rec_mtdat.sp_execstring_des` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_sql VARCHAR(65535), p_paso VARCHAR(500))` |
| `rec_mtdat.sp_drop_si_existe` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_tabla VARCHAR(200))` |
| `rec_mtdat.sp_drop_tabla_por_nombre` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_tabla VARCHAR(200))` |
| `rec_stage.sp_batch2_valida_archivos` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT, INOUT p_numero_separadores INTEGER, INOUT p_ancho_fijo INTEGER)` |
| `rec_stage.sp_batch2_filtro_a/_b/_c/_d/_f/_g/_h`, `sp_batch2_homologaciones`, `sp_batch2_add_porc_insumo`, `sp_batch2_adicionar_incon` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_id_plantilla BIGINT, p_id_solicitud BIGINT)` — **plantilla ANTES que solicitud** |
| `rec_stage.sp_batch2_filtro_e` | `(p_lote, p_nombre_proceso, p_id_plantilla, p_id_solicitud, p_tipo_persona VARCHAR(1))` ('N' o 'J') |
| `rec_stage.sp_batch2_filtro_i`, `sp_batch2_filtro_j` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100))` |
| `rec_stage.sp_batch2_cubo_export` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT)` — **solicitud ANTES que plantilla** |
| `rec_stage.sp_batch2_exportplano` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT, p_nombre_seccion VARCHAR(100), p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500), p_fch_archivo VARCHAR(20))` |
| `rec_stage.sp_batch2_archivo_log` | `(p_lote, p_nombre_proceso, p_start_timestamp TIMESTAMP, p_id_plantilla, p_id_solicitud, p_archivoprn VARCHAR(1000), p_maquina VARCHAR(200), p_ruta VARCHAR(200), p_feinicio VARCHAR(32), p_nombre_seccion VARCHAR(32))` |
| `rec_stage.sp_batch2_exportlog` | las 10 de `archivo_log` + `(p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500), p_filename VARCHAR(200), p_delimitador VARCHAR(5))` = 14 |
| `rec_stage.sp_batch2_actualiza_historia` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT)` — solicitud primero |
| `rec_stage.sp_batch2_estadisticas_cfg` | `(p_lote, p_nombre_proceso, p_start_timestamp TIMESTAMP, p_id_plantilla, p_id_solicitud, p_parte VARCHAR(100))` |
| `rec_stage.sp_batch2_plan_ejecucion_shell` | `(p_lote, p_nombre_proceso, p_id_solicitud, p_parte VARCHAR(100))` |
| `rec_stage.sp_batch2_transpuesta` | `(p_lote, p_nombre_proceso, p_batch2_pnpj VARCHAR(30))` |
| `rec_stage.sp_batch2_completitud_canal` | `(p_lote, p_nombre_proceso, p_id_plantilla, p_id_solicitud)` |
| `rec_stage.sp_batch2_cantrepcanal_con` | `(p_lote, p_nombre_proceso, p_start_timestamp TIMESTAMP, p_id_solicitud, p_id_plantilla, p_cdatos_sdatos VARCHAR(2))` — el orquestador cruza solicitud/plantilla a propósito (B-08) |
| `rec_stage.sp_batch2_estadisticas` | `(p_lote, p_nombre_proceso, p_start_timestamp TIMESTAMP, p_id_plantilla, p_id_solicitud)` |
| `rec_stage.sp_batch2_estadisticas_export` | `(p_id_plantilla BIGINT, p_id_solicitud BIGINT, p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500), p_archivo_alertas VARCHAR(200))` |

Cuidado con el orden: los filtros reciben **(plantilla, solicitud)** y `cubo_export`, `exportplano`, `actualiza_historia`, `valida_archivos` reciben **(solicitud, plantilla)**.

### 7.3 Ejecución por pasos (alternativa A, derivada del orquestador)
Cada `CALL` de nivel superior es su propia transacción: un error no deshace pasos anteriores. Sirve para producir los 3 CSV sin pasar por los pasos 9-13 que hoy fallan. Sustituir `<LOTE>`.
```sql
-- 1) Lote. INOUT en una llamada de nivel superior: se pasa un literal y devuelve una fila con el valor
CALL rec_mtdat.sp_batch2_genera_lote(0);
SELECT lote FROM rec_mtdat.lote_id;                        -- = <LOTE>

-- 3) Validar (informativo): INOUT x2 -> literales
CALL rec_stage.sp_batch2_valida_archivos(90001, 9001, 0, 0);

-- 4) PROCESACUBOS: (lote, proceso, PLANTILLA, SOLICITUD). Orden real del BTQ
CALL rec_stage.sp_batch2_filtro_a(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_b(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_c(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_d(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_e(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001, 'N');
CALL rec_stage.sp_batch2_filtro_e(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001, 'J');
CALL rec_stage.sp_batch2_filtro_f(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_g(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_homologaciones(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_i(<LOTE>, 'PRUEBA_ESENCIAL');
CALL rec_stage.sp_batch2_filtro_h(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_filtro_j(<LOTE>, 'PRUEBA_ESENCIAL');
CALL rec_stage.sp_batch2_add_porc_insumo(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);
CALL rec_stage.sp_batch2_adicionar_incon(<LOTE>, 'PRUEBA_ESENCIAL', 9001, 90001);

-- 5) CUBOEXPORT: (SOLICITUD, PLANTILLA)
CALL rec_stage.sp_batch2_cubo_export(90001, 9001);

-- 6-7) EXPORTPLANO: mismo p_fch_archivo en ambas llamadas ('_' + AAAAMMDDHHMISS)
CALL rec_stage.sp_batch2_exportplano(90001, 9001, 'CON DATOS DE UBICACION',
     's3://<mi-bucket>/batch2/esencial/', 'arn:aws:iam::<cuenta>:role/<Rol>', '_20261015120000');
CALL rec_stage.sp_batch2_exportplano(90001, 9001, 'SIN DATOS DE UBICACION',
     's3://<mi-bucket>/batch2/esencial/', 'arn:aws:iam::<cuenta>:role/<Rol>', '_20261015120000');

-- 13) Opcional: cierre de la solicitud (estado='GENERADO')
CALL rec_stage.sp_batch2_actualiza_historia(90001, 9001);
```
[SUPUESTO] Que un `CALL` de nivel superior con `INOUT` acepte literal y devuelva una fila: la documentación de `CALL` dice que los parámetros de salida se devuelven como un resultado de una fila (`r_CALL_procedure.html`) y los ejemplos usan literales; no se ejecutó.

### 7.4 Cómo leer el lote y el resultado
```sql
SELECT lote FROM rec_mtdat.lote_id;                                    -- último lote asignado
SELECT lote, fecha_hora, nombre_proceso, paso, descripcion_teradata_error
FROM rec_mtdat.log_td_detalle
WHERE lote = <LOTE> ORDER BY fecha_hora;                               -- bitácora
SELECT * FROM rec_mtdat.log_td WHERE lote = <LOTE> ORDER BY fecha_hora_inicio;   -- solo si se usó el orquestador
```
- `descripcion_teradata_error = 'Finalizo Exitosamente'` es OK; cualquier otro valor (p. ej. `ERROR: ...`) es fallo (`02_sp_batch2_log_helpers.sql:113-135`).
- Tras una falla del orquestador, la fila `ERROR: ...` SÍ persiste (el handler corre en transacción nueva) [AWS], pero las filas de `log_td` del paso fallido y los cambios posteriores al último `TRUNCATE` se deshacen. El `TRUNCATE` de `cubo_export` confirma (COMMIT implícito) todo lo anterior [AWS: `stored-procedure-transaction-management.html`].
- `RAISE INFO`/`RAISE WARNING` se ven en el cliente y en `SVL_STORED_PROC_MESSAGES` [AWS].

---

## 8. Orden de despliegue e idempotencia

### 8.1 Orden (dependencias reales)
1. `ddl/01_schemas.sql` (todo lo demás cuelga de los esquemas).
2. `ddl/02..07` (solo `CREATE TABLE IF NOT EXISTS`; entre sí independientes).
3. `ddl/08_funciones_udf.sql` (necesita `rec_vista` y los 2 marcadores reemplazados; la Lambda NO tiene que existir para crear [SUPUESTO]).
4. `ddl/09_vistas_dependencias_sps.sql` (late-binding: se crea aunque no existan las tablas de P0034).
5. `ddl/10_tablas_trabajo_f2_4.sql` (independiente; el README lo pone después de 09).
6. `procedures/01, 02, 03, 04, 05, 06, 07, 08, 09b, 10`: `02` antes que cualquier procedure que llame a `sp_execstring_des` (todos los de 05, 08, 09, 09b); **`09b` antes de `09`** (`sp_batch2_estadisticas` llama a `sp_batch2_estadisticas_cfg`); `10` al final (llama a todos). Ejecutar `09b_sp_batch2_motores_sql.sql` ANTES de `09_sp_batch2_otros.sql` aunque el orden alfabético del explorador de archivos pueda sugerir lo contrario (es el orden del README y de la guía actual).
7. `datos/01_catalogos_motor.sql` (solo depende de `ddl/05` y `ddl/07`; UTF-8 por las tildes: `client_encoding UTF8`).
8. Datos de prueba y vistas puente (§6.2).

Dependencias de datos entre scripts: `ddl/09` no requiere tablas de P0034 para crearse; el bloque opcional comentado (líneas 156-180) las crea vacías con `IF NOT EXISTS` y **solo** sirve para consultar la vista (que solo lee ADD_PORC_INSUMO con "Validacion"). `10_tablas_trabajo_f2_4.sql` no tiene dependencias de creación.

[SUPUESTO] Redshift permite `CREATE PROCEDURE` que referencia tablas/procedures aún no creados (varios procedures consultan objetos que solo existen en tiempo de ejecución, p. ej. `rec_stage.v_telefono_tmp1`, `rec_stage.detallevalores`). El README y las cabeceras piden orden por si acaso.

Clientes: los scripts usan `\i` (meta-comando de `psql`). `\i` NO existe en Query Editor v2 (hay que pegar cada archivo). El README usa rutas relativas `ddl/...` (cwd = `RS`); la guía actual usa `Redshift/ddl/...` (cwd = raíz del workspace): unificar. [VERIFICADO el texto; el soporte de `\i` en RSQL no lo verifiqué]

### 8.2 Idempotencia por archivo [VERIFICADO leyendo cada archivo]
| Archivo | Mecanismo | ¿Re-ejecutable? | Matiz |
|---|---|---|---|
| `ddl/01_schemas.sql` | `CREATE SCHEMA IF NOT EXISTS` | Sí | — |
| `ddl/02, 03, 04, 07, 10` | `CREATE TABLE IF NOT EXISTS` | Sí | **No modifica tablas existentes**: añadir `_003` a `w_cubo_direccion` exige `DROP`/`ALTER`. `07` siembra `secuencia` con `WHERE NOT EXISTS`. |
| `ddl/05` | `CREATE TABLE IF NOT EXISTS`; siembra `lote_id` con `WHERE NOT EXISTS` | Sí | `batch2_shells_planejecucion` la borra/recrea el motor. |
| `ddl/06` | `CREATE TABLE IF NOT EXISTS`; siembra `tipo_persona` (2 filas) con `WHERE NOT EXISTS` | Sí | `persona` no se siembra. |
| `ddl/08` | `CREATE OR REPLACE FUNCTION` / `CREATE OR REPLACE EXTERNAL FUNCTION` | Sí | Reemplazar una función externa requiere superusuario y misma firma [AWS]. |
| `ddl/09` | `CREATE OR REPLACE VIEW` (+ bloque comentado `IF NOT EXISTS`) | Sí | — |
| `procedures/*.sql` | `CREATE OR REPLACE PROCEDURE` (34) | Sí | Cambiar la lista de parámetros crea una sobrecarga en vez de reemplazar [SUPUESTO: comportamiento estándar de Redshift]. |
| `datos/01_catalogos_motor.sql` | `DELETE` (+ `WHERE tipo='LOG'` / `parte='ITERADOR'`) y `INSERT` | Sí | Borra TODO `batch_archivo_log` y recarga. |

**El pipeline NO es repetible sobre los mismos datos**: muta los cubos en sitio. HOMOLOGACIONES reescribe `numero_id` (quita ceros a la izquierda); FILTRO_H y FILTRO_J **borran filas**; con `prueba <> 'SV'` el bloque L2 intercambia apellidos y nombres cada vez (`primer_apellido1 := segundo_apellido`, `segundo_apellido1 := primer_apellido`) y vuelve a enmascarar; `actualiza_historia` solo cierra si `estado IS NULL`. Para repetir la prueba hay que recargar los cubos y poner `batch_solicitud_batch.estado = NULL, fecha_generacion = NULL`.

### 8.3 Collation
- Requisito de despliegue declarado en `08_sp_batch2_procesacubos.sql:46-51` y en `README.md`: base de datos creada con `COLLATE CASE_INSENSITIVE` (equivalente a `NOT CASESPECIFIC`). Se define al crear la base (`CREATE DATABASE <nombre> COLLATE CASE_INSENSITIVE;`) y no se cambia después. [VERIFICADO el requisito; la sintaxis `CREATE DATABASE ... COLLATE` es la documentada por AWS, no la ejecuté]
- Dónde importa de forma concreta: FILTRO_J compara `detalle = 'Correo'` contra el valor `'correo'` que él mismo guardó (sin la collation, **nunca** borra duplicados); comparaciones `'Celular'/'Telefono'/'Mail'` en la vista `vstgbatchcargaubicestandarizada`; `b2h.cubo = 'Telefono'` vs valores cargados en cualquier capitalización.
- Para conectar a la base nueva hay que abrir una conexión nueva a esa base (Redshift no cambia de base dentro de la sesión).
- Prueba de comportamiento propuesta antes de empezar: `SELECT 'a' = 'A';` debe devolver `true` en una base CASE_INSENSITIVE. [SUPUESTO]

---

## 9. Datos: catálogos y columnas reales

### 9.1 Columnas reales vs. los INSERT de la guía [VERIFICADO contra `ddl/02`]
- **4.1 `batch_solicitud_batch`** — guía: 11 columnas / 11 valores. DDL (11): `id_solicitud BIGINT NOT NULL, tipo_id_suscriptor VARCHAR(10), num_id_suscriptor VARCHAR(20), nombre_plantilla VARCHAR(100), prueba VARCHAR(100), archivo_control VARCHAR(100), fecha_solicitud TIMESTAMP, archivo_log VARCHAR(100), estado VARCHAR(100), id_planilla BIGINT, fecha_generacion TIMESTAMP`. Coincide. **Cambio necesario:** `prueba` en `'S'` activa enmascaramiento (`COALESCE(prueba,'SV') <> 'SV'`); usar `'SV'` o `NULL`.
- **4.2 `batch_datos_generales`** — guía: 17 columnas / 17 valores. DDL (16 columnas de datos + `id_solicitud`): coincide. Todas VARCHAR(100) salvo `id_solicitud BIGINT NOT NULL` e `id_plantilla BIGINT`. Solo cuatro son leídas por SP: `id_plantilla`, `orientacion` (`OE_HORIZON`/`OE_VERTICA`), `archivos_pn_pj` (`'1'` ⇒ el orquestador espera PN/PJ separados en el log; `exportplano` los genera SIEMPRE), `no_entregado_x_meses` (`'0'` ⇒ FILTRO_B y la historia no actúan). **Ningún SP lee** `formato_salida`, `separador`, `ancho_fijo`, `incluir_cabecera`, `sector`, `no_reportado_suscriptor`, `fecha_recogida`, `archivo_condatos`, `sindatos`, `archivo_inconsistencia`, `archivo_tablas`, `archivo_alertas`: los nombres (`CON_DATOS_`, `SIN_DATOS_`, `INCONSISTENCIA_`, `ALERTAS-`) y el `;` están en el código. La nota de la guía "ajustar separador/formato al archivo de insumo" no tiene efecto sobre la salida.
- **4.3 `batch_salidas_campos`** — guía: 17 columnas / 17 valores por fila. DDL (17): `id_solicitud BIGINT NOT NULL, id_plantilla BIGINT, nombre_seccion VARCHAR(100), codigo_seccion VARCHAR(10), nombre_subseccion VARCHAR(100), codigo_subseccion VARCHAR(10), orden_subseccion INTEGER, grupo_campo VARCHAR(100), nombre_campo VARCHAR(100), codigo_campo VARCHAR(10) NOT NULL, orden_campo INTEGER, cantidad_max_campo INTEGER, af_ancho_campo INTEGER, af_relleno_campo VARCHAR(10), af_orientacion_campo VARCHAR(10), requerido_campo VARCHAR(2), minimo_requerido_campo VARCHAR(10)`. Coincide en forma. **Cambios necesarios:** `codigo_campo` reales (§9.2); `requerido_campo` solo actúa con `'SI'` (usar `'NO'`); evitar subsecciones cuyo nombre contenga "Validacion" salvo que se quiera activar ADD_PORC_INSUMO + P0034.
- **Cubos** — NOT NULL: `id_auto` e `id_buro_persona` en todos. `filtro_h` default 0. Longitudes en §9.3.

### 9.2 `batch_salidas_campos` / `batch2_homologacion` para activar el truncamiento
Códigos reales usados por el código (FILTRO_G `08:1655`, ADD_PORC_INSUMO, `datos/01` LOG 14-16) y por la muestra `Salidas\CON_DATOS_4421_...ESQUEMA`:

| Canal | `codigo_campo` | `grupo_campo` (requerido por FILTRO_G, `08:1621-1626`) | `cubo` en `batch2_homologacion` | `homologado` (columna física) |
|---|---|---|---|---|
| Teléfono fijo | `DT_NUM` (más `DT_CIUDAD`, `DT_DEPARTA`, `DT_DAN_CIU`, `DT_DAN_DEP`, `DT_TIPO`, `DT_ULT_ACT`, `DT_ND_ENT_`, `DT_INDICAT`) | `CUBO_TEL` | `Telefono` | `numero` |
| Dirección | `DD_DIR` (más `DD_CIUDAD`, `DD_DEPARTA`, `DD_DAN_CIU`, `DD_DAN_DEP`, `DD_TIPO`, `DD_ZONA`, `DD_ESTRATO`, `DD_ULT_ACT`, `DD_ND_ENT_`) | `CUBO_DIR` | `Direccion` | `direccion` |
| Celular | `DC_NUMERO` | `CUBO_CEL` | `Celular` | `numero` |
| Correo | `CE_CORREO` | `CUBO_EMAIL` | `Correo` | `correo` |
| CIIU | `DB_CIIU` (más `DB_ACT_ECO`) | `CUBO_CIIU` | `Ciiu` | `ciiu` |
| Persona | `DB_TIP_ID`, `DB_NUM_ID`, `DP_PRI_APE`, ... | `CUBO_PERS` | `Persona` | — |

Subsecciones de la muestra real: `Datos de identificacion`/`AGSB_DI`, `Telefonos`/`AGSB_TEL`, `Direcciones`/`AGSB_DIR`, `Datos adicionales`/`AGSB_DAD` (correo y celular). `nombre_seccion` debe contener `CON DATOS` (FILTRO_G filtra `LIKE '%CON DATOS%'`).

Cómo opera FILTRO_G [VERIFICADO leyendo `08:1538-1790`]: para cada código de la lista que tenga fila en `batch_salidas_campos` Y en `batch2_homologacion` genera `CREATE TABLE bacth_fg_2` con `c_update = 0` si `cant_campo BETWEEN <minimo_requerido> AND <cantidad_max>` (posición del registro dentro de la persona según `orden_prioridad`), y `1` en otro caso. `cantidad_max_campo = 0/NULL` ⇒ tope 1 000 000. Condiciones que el escritor debe respetar:
- Una sola fila por `codigo_campo` en (solicitud, plantilla), o `DISTINCT` las colapsa; dos filas distintas para el mismo cubo ⇒ `RAISE EXCEPTION` ("SELECT-INTO returned more than one row").
- Si un canal NO tiene `grupo_campo` en la plantilla (sección CON DATOS), **todas** las filas de ese cubo reciben `filtro_g=1` y se excluyen (esa es la forma en que "Esencial" omite canales).
- `minimo_requerido_campo` actúa como cota inferior de la posición (con 3 se excluyen las 2 primeras filas), no como "mínimo de datos": usar `0`.
- **Bug replicado:** el UPDATE de `filtro_g` se aplica a los 6 cubos con el `id_auto` de `bacth_fg_2`. Si `id_auto` coincide entre cubos, se contaminan. **Usar `id_auto` únicos entre todas las tablas cubo** (p. ej. persona 1-99, dirección 1000+, teléfono 2000+, celular 3000+, correo 4000+, ciiu 5000+).
- Filas mínimas de `batch2_homologacion` derivadas del código (suposición del investigador sobre el contenido real del catálogo, que no está en el workspace): `(id_sequencia, codigo_campo, homologado, grupo_campo, cubo)` = `(1,'DT_NUM','numero','CUBO_TEL','Telefono')`, `(2,'DD_DIR','direccion','CUBO_DIR','Direccion')`, `(3,'DC_NUMERO','numero','CUBO_CEL','Celular')`, `(4,'CE_CORREO','correo','CUBO_EMAIL','Correo')`, `(5,'DB_CIIU','ciiu','CUBO_CIIU','Ciiu')`. Columnas de la tabla: `id_sequencia INTEGER, codigo_campo VARCHAR(10), homologado VARCHAR(100), grupo_campo VARCHAR(100), cubo VARCHAR(50), xalias VARCHAR(10), valor_ini, campo_nuevo, ordenamiento, descripcion_campo` (`ddl/05:101-112`). `xalias`/`campo_nuevo`/`ordenamiento` no los lee ningún SP actual (sí los leería la futura `v_ba2_campos_salida`).

### 9.3 Restricciones que deben cumplir los datos de prueba [VERIFICADO]
- `batch_cubo_persona`: `id_solicitud=90001`, `id_plantilla=9001`; `tipo_id` numérico en texto (`'1'`, `'2'`, `'3'`, `'4'`; HOMOLOGACIONES hace `CAST(TRIM(tipo_id) AS INTEGER)` si hay enmascaramiento) y `numero_id` numérico (`CAST(... AS BIGINT)` en HOMOLOGACIONES, FILTRO_F, ADICIONAR_INCON); `cod_pin_persona` informado; `id_buro_persona` único por persona.
- Cubos de contacto: **`orden_prioridad` no nulo y distinto por persona** (si es NULL, FILTRO_I pone `filtro_i=1` y FILTRO_H excluye la fila); `fecha_ultima_actualizacion` tipo `DATE`; `numero_de_entidades_reporta` INTEGER.
- Longitudes máximas (por el `INSERT ... SELECT` a `w_cubo_*`): ciudad/departamento ≤ 30, `cod_dane_*` ≤ 20, tipo ≤ 15, dirección ≤ 100, zona ≤ 10, estrato ≤ 5, correo ≤ 61, número ≤ 30.
- INCONSISTENCIA: o bien filas directas en `batch_identificaciones_incons`, o filas en `batch_identificaciones_validas` (numérico) cuya identificación NO esté en `batch_cubo_persona`: ADICIONAR_INCON las mueve a `_incons` con `estado='06'`, `causal='04'` (`08:3241-3320`).
- SIN_DATOS: una persona sin filas de contacto con `filtro_h=0` (FILTRO_H paso 3 la pasa a `filtro_h=1`).
- CIIU: una persona con solo CIIU cuenta como "con datos" (FILTRO_H paso 3 incluye `batch_cubo_ciiu`).

### 9.4 Conteos de catálogos [VERIFICADO leyendo `datos/01_catalogos_motor.sql`]
- `rec_stage.batch_archivo_log`: 18 filas (ids 1..18).
- `rec_stage.batch_motor_log` (`tipo='LOG'`): **18** filas (ids 1..18). Las filas `FILTRO-C` y `CANT_REP_CANAL_CONTACTO` no existen.
- `rec_stage.pro_plan_ejecucion` (`parte='ITERADOR'`): **12** filas (ids 1..12).
- Otros sembrados por DDL: `rec_mtdat.lote_id` 1 fila (`lote=0`), `rec_stage.secuencia` 100 filas, `rec_vista.tipo_persona` 2 filas.

---

## 10. Archivos de salida en S3, parámetros y permisos

Nombres con `p_fch_archivo = '_20261015120000'` (el orquestador usa `'_' || TO_CHAR(GETDATE(),'YYYYMMDDHH24MISS')`, `10:75`) y prefijo `<bucket>` = `p_s3_bucket_salida`:

| Producido por | Prefijo pedido a `UNLOAD` | Objeto real en S3 [AWS: PARALLEL OFF añade `000`] |
|---|---|---|
| `exportplano` CON (4 UNLOAD) | `<bucket>CON_DATOS_90001_20261015120000.CSV` | `...CSV000` |
| | `<bucket>CON_DATOS_90001_PN_20261015120000.CSV` | `...CSV000` |
| | `<bucket>CON_DATOS_90001_PJ_20261015120000.CSV` | `...CSV000` |
| | `<bucket>INCONSISTENCIA_90001_20261015120000.CSV` | `...CSV000` |
| `exportplano` SIN (4 UNLOAD) | `<bucket>SIN_DATOS_90001_20261015120000.CSV` (+ `_PN`, `_PJ`) | `...CSV000` |
| | `INCONSISTENCIA_90001_...CSV` (repetido, `ALLOWOVERWRITE`) | `...CSV000` |
| `estadisticas_export` (paso 11, hoy no se alcanza) | `<bucket>ALERTAS-90001_20261015120000_estadisticas_` | `..._estadisticas_000` |
| `exportlog` (paso 12, hoy no se alcanza) | `<bucket>BATCH_SOLICITUD_BATCH.ARCHIVO_LOG_W` | `...ARCHIVO_LOG_W000` |

- El sufijo es `000` (y `001`, ... si un archivo supera 6.2 GB), **no** `0000_part_00` (eso lo da `PARALLEL ON`). La guía y `VERIFICACION.md` mencionan `0000_part_00`. [AWS: https://docs.aws.amazon.com/redshift/latest/dg/t_Unloading_tables.html (UNLOAD serie con `PARALLEL OFF`) y la respuesta de AWS re:Post "How can I use UNLOAD with PARALLEL OFF and not have 000 appended to the filename?"; no se ejecutó en un cluster]
- En una corrida "solo hasta exportplano" se generan **8 invocaciones UNLOAD → 7 prefijos de datos** (INCONSISTENCIA se repite). Los `_PN`/`_PJ` se generan siempre, aunque `archivos_pn_pj='0'`.
- Cabecera: `HEADER` activo en los CSV de datos y de inconsistencia (nombres de columna en el `SELECT`); `exportlog` y `ALERTAS` sin cabecera; separador `;` en CSV de datos, `,` en ALERTAS y log.
- Codificación: `UNLOAD` escribe UTF-8.
- Permisos del `p_iam_role`: escritura (`s3:PutObject`, y `s3:ListBucket`) en el bucket; el rol debe estar asociado al cluster. El código no usa la cláusula `REGION`: [AWS, `r_UNLOAD.html`] el bucket debe estar en la misma región que el cluster. [SUPUESTO: no re-leí esa página en esta sesión; es conocimiento de la documentación]
- `p_iam_role` y `p_s3_bucket_salida` son `VARCHAR(500)`; `p_ruta` del log es `VARCHAR(200)` (el orquestador le pasa `p_s3_bucket_salida`: una ruta >200 caracteres trunca/falla).

---

## 11. Lambda de similitud (`RS\lambda\udf_similitud\`)

[VERIFICADO leyendo `lambda_function.py` y la cabecera `ddl/08_funciones_udf.sql:50-70`; 36 pruebas unitarias ejecutadas localmente: `python -m unittest test_lambda_function` → `Ran 36 tests ... OK`]
- Runtime sugerido: **Python 3.12**; handler: `lambda_function.lambda_handler` (`lambda_function.py:279`); sin dependencias externas (solo `json`, `math`, `os`, `re`); paquete = el único archivo `lambda_function.py` (no hace falta incluir `test_lambda_function.py` ni los `.sql`); timeout sugerido 5 min; memoria no especificada (la distancia de edición es O(n·m) en Python: subir memoria/ajustar `MAX_BATCH_ROWS` para volumen).
- Una sola función atiende las 4 UDF: elige por `event["external_function"]` (último segmento, minúsculas). La variable de entorno opcional `UDF_NOMBRE` fuerza una UDF fija.
- Contrato: entrada `{"external_function", "num_records", "arguments": [[...]]}`; salida `{"success": true, "num_records": n, "results": [...]}` o `{"success": false, "error_msg": "..."}`.
- Permisos: el rol IAM de Redshift (`IAM_ROLE` de cada `CREATE EXTERNAL FUNCTION`) necesita `lambda:InvokeFunction` sobre la función (cabecera `ddl/08:61-65`). El rol de ejecución de la Lambda: no documentado en el repo (lo normal es el rol básico de logs de CloudWatch) [SUPUESTO].
- Marcadores a reemplazar en `ddl/08_funciones_udf.sql`: `<LAMBDA_UDF_SIMILITUD>` (4 veces, líneas 102, 114, 123, 137) e `<IAM_ROLE_LAMBDA_ARN>` (4 veces, líneas 103, 115, 124, 138). Ejemplo para PowerShell:
  `(Get-Content ddl\08_funciones_udf.sql -Raw -Encoding UTF8) -replace '<LAMBDA_UDF_SIMILITUD>','udf_similitud' -replace '<IAM_ROLE_LAMBDA_ARN>','arn:aws:iam::<cuenta>:role/<rol>' | Set-Content ddl\08_funciones_udf_desplegar.sql -Encoding UTF8` (generar una copia; no editar el original del repo).
- Limitaciones: las Lambda UDF de Redshift no soportan `IMMUTABLE` (por eso son `STABLE`) [AWS]. Pendiente: confirmar en Teradata que `editdistance_u` equivale a Damerau-Levenshtein OSA (`casos_validacion_teradata.sql`).
- Las 3 UDF de enmascaramiento son SQL UDF puras (no necesitan Lambda). `f_td_to_number` también.

---

## 12. Catálogos de Redshift: consulta correcta para listar procedures

La consulta de la guía (Paso 3) usa `schemaname, procedurename`, columnas que **no existen** en `pg_proc` (ni en `pg_proc_info`). La vista documentada para procedimientos es `PG_PROC_INFO` (sobre `PG_PROC` + `PG_PROC_EXTENDED`), con la columna `prokind` (`'p'` = procedimiento, `'f'` = función, `'a'` = agregada), `proargmodes`, `proargnames` [AWS: `r_PG_PROC_INFO.html`].

Consulta recomendada (esperado: **34 filas**; 7 en `rec_mtdat`, 27 en `rec_stage`):
```sql
SELECT n.nspname AS esquema, p.proname AS procedimiento
FROM pg_catalog.pg_proc_info p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE p.prokind = 'p'
  AND n.nspname IN ('rec_stage','rec_mtdat')
ORDER BY 1, 2;
```
Solo los `sp_batch2_*`: añadir `AND p.proname LIKE 'sp\_batch2\_%'` (esperado **31**). Conteo rápido: `SELECT n.nspname, COUNT(*) FROM pg_catalog.pg_proc_info p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace WHERE p.prokind='p' AND n.nspname IN ('rec_stage','rec_mtdat') GROUP BY 1;` → `rec_mtdat 7`, `rec_stage 27`.

Alternativa documentada [AWS: `r_SVV_REDSHIFT_FUNCTIONS.html`]; sus columnas son `database_name, schema_name, function_name, function_type, argument_type, result_type` y `function_type` distingue funciones regulares, agregadas y procedimientos (texto exacto no documentado → comparar con `ILIKE '%PROCEDURE%'`):
```sql
SELECT schema_name, function_name, argument_type
FROM svv_redshift_functions
WHERE schema_name IN ('rec_stage','rec_mtdat') AND function_type ILIKE '%PROCEDURE%'
ORDER BY 1, 2;
```
Para ver la firma y el código de uno: `SHOW PROCEDURE rec_stage.sp_batch2_proceso_batch2(bigint, varchar, varchar);` [AWS: `r_SHOW_PROCEDURE.html`] (los argumentos son opcionales si el nombre no está sobrecargado).

Otras comprobaciones útiles tras el DDL (conteos esperados tras ejecutar solo `ddl/01..10`, antes de correr el pipeline —el pipeline crea tablas de trabajo—):
```sql
SELECT schemaname, COUNT(*) FROM pg_tables
WHERE schemaname IN ('rec_stage','rec_mtdat','rec_datos','rec_vista') GROUP BY 1 ORDER BY 1;
-- rec_datos 3 | rec_mtdat 3 | rec_stage 34 | rec_vista 3   (43 en total)
SELECT schema_name, function_name FROM svv_redshift_functions WHERE schema_name = 'rec_vista' ORDER BY 2;   -- 8 funciones
SELECT COUNT(*) FROM rec_stage.secuencia;          -- 100
SELECT COUNT(*) FROM rec_vista.tipo_persona;       -- 2
SELECT COUNT(*) FROM rec_stage.batch_motor_log WHERE tipo = 'LOG';             -- 18 (tras datos/01)
SELECT COUNT(*) FROM rec_stage.pro_plan_ejecucion WHERE parte = 'ITERADOR';    -- 12 (tras datos/01)
SELECT COUNT(*) FROM rec_stage.batch_archivo_log;  -- 18 (tras datos/01)
```
(La vista `rec_stage.vstgbatchcargaubicestandarizada` no aparece en `pg_tables`; consultar `pg_views`/`SVV_TABLES`.)

---

## 13. Hallazgos de código y de documentación (no se corrigió nada)

| # | Hallazgo | Dónde |
|---|---|---|
| H1 | El orquestador cae en el paso 9 (y luego 10, 11, 12). La cabecera del orquestador (`10:34-45`) dice que "esos pasos fallan o no hacen nada"; en realidad **fallan y abortan todo el `CALL`**. | `10_sp_batch2_proceso_batch2.sql` |
| H2 | FILTRO_E exige `vu_persona`/`v_tipo_persona` (aborta antes del export); la guía lo clasifica como "no bloquea". | `08:731-732`; `ddl/07:203-209` |
| H3 | `exportplano` hace JOIN con `rec_vista.persona` (tabla sin filas y join solo por tipo). Ni la guía ni el README lo mencionan. | `04:107`; `ddl/06:31` |
| H4 | Comentario de cabecera de `exportplano` (líneas 16-26) afirma que arma el SELECT desde `batch_salidas_campos`; el código no lo hace. | `04:16-26` |
| H5 | La columna final "Numero 001b" del CSV sale de `w_cubo_correo.numero_001` ("compat"), mientras `DC_NUMERO` es el celular en las demás piezas. | `04:105`; `ddl/03:206` |
| H6 | `vstg_inconsis_pnpj` se atribuye a `CUBOEXPORT_111.BTQ`; está en `EXPORTPLANO_111.BTQ:1134,1225`. | `ddl/10:72-77`; `09:129`; GUIA §3.5 |
| H7 | Comentario obsoleto: `estadisticas` "sigue como placeholder". | `09b:52-54` |
| H8 | `rec_stage.batch2_cantidad_reporte_canal` no la usa ningún SP actual. | `ddl/05:219` |
| H9 | Los nombres de archivo y el `;` están fijos en el código; las columnas `archivo_condatos`, `sindatos`, `archivo_inconsistencia`, `archivo_alertas`, `separador`, `formato_salida`, `incluir_cabecera` de `batch_datos_generales` son decorativas. | `04`, `10`; `ddl/02:26-45` |
| H10 | `exportplano` genera PN/PJ siempre, e `INCONSISTENCIA` dos veces. | `04:135-168`; `10:141-142` |
| H11 | Las `w_cubo_*` tienen longitudes menores que los cubos origen (riesgo de error en `INSERT ... SELECT`). | `ddl/04` vs `ddl/03` |
| H12 | `CREATE TABLE IF NOT EXISTS` no actualiza tablas ya creadas (relevante para `_003`). | `ddl/04` |
| H13 | Bloque L2 (enmascaramiento) se dispara con cualquier `prueba <> 'SV'` (incluye `'S'`), y no es idempotente (reordena apellidos/nombres en cada corrida). | `08:2154-2270` |
| H14 | El pipeline modifica/borra los cubos en sitio: no se puede relanzar sin recargar. | `08` (FILTRO_H, FILTRO_J, HOMOLOGACIONES) |
| H15 | `sp_batch2_filtro_g` contamina `filtro_g` entre cubos si `id_auto` coincide (bug original replicado). | `08:1744-1790` |
| H16 | `VERIFICACION.md` (punto 3) y la cabecera de `exportplano` mencionan el sufijo `0000_part_00`, que corresponde a `PARALLEL ON`; con `PARALLEL OFF` (lo que usa el código) es `000`. | `VERIFICACION.md` §3; `04:~42`; `05:22-24` ya dice `000` (correcto) |
| H17 | La guía 4.3 usa `requerido_campo='N'`; solo `'SI'` tiene efecto (`'N'` es inocuo pero no es el valor del catálogo). | GUIA §4.3 |

---

## 14. Supuestos sin confirmar (requieren un cluster real o AWS)

1. Que `CREATE EXTERNAL FUNCTION` no valide la existencia de la Lambda ni el formato del rol más allá de la sintaxis (con `IAM_ROLE default` y un nombre cualquiera). No lo dice la documentación leída.
2. Que Redshift no invoque la Lambda cuando la consulta no tiene filas (FILTRO_F con `stg_insumo_batch_validacion` vacía).
3. Que un `CALL` de nivel superior con `INOUT` acepte literales (`CALL rec_mtdat.sp_batch2_genera_lote(0)`).
4. Que `CALL` acepte notación nombrada `=>` (no aparece en la sintaxis de AWS; por eso se recomienda posicional).
5. Que `CALL` anidado acepte expresiones como argumento (`'ALERTAS-' || p_id_solicitud || v_fch_archivo`, `GETDATE()` en `10:183-196`) y que `||` convierta `BIGINT` a texto de forma implícita (muchas sentencias dependen de esto).
6. Que `rec_stage.batch_cubo_persona.tipo_id VARCHAR(5) = rec_vista.persona.cod_tipo_ident_fte INTEGER` compare con conversión implícita (join de `exportplano`, línea 107). Pre-chequeo propuesto: `SELECT CAST('1' AS VARCHAR(5)) = 1;`.
7. Que `CREATE PROCEDURE` no exija que existan los objetos que referencia (varios procedures consultan objetos creados en ejecución).
8. Que las vistas late-binding con `TOP 200 ... ORDER BY` y vista-sobre-vista de las filas `ITERADOR` (IDs 7 y 8) se acepten en Redshift.
9. Que `ANALYZE` y `QUALIFY` funcionen dentro de los SP (señalado en `VERIFICACION.md` como no verificado).
10. Que el mapeo de `DC_NUMERO` a celular sea el de Teradata (inferencia de `Sps_Batch.sql` y `datos/01`).
11. El contenido real de `rec_stage.batch2_homologacion` (las 5 filas propuestas en §9.2 son derivadas, no un catálogo real).
12. Que el bucket esté en la misma región del cluster (no se usa `REGION`).
13. Que `editdistance_u` sea Damerau-Levenshtein OSA (pendiente de `casos_validacion_teradata.sql`).
14. Soporte de `\i` en RSQL (en psql sí; en Query Editor v2 no).
15. Efectos de transacción de `TRUNCATE`/handler en llamadas anidadas tal como se describen en §7.4 (basado en documentación AWS de procedimientos, no observado).
16. Que `SELECT 'a' = 'A'` devuelva `true` en una base `CASE_INSENSITIVE`.
17. El texto exacto de `function_type` para procedimientos en `SVV_REDSHIFT_FUNCTIONS`.

---

## 15. Recomendaciones para el escritor de la guía

1. **Cambiar el objetivo realista de la prueba**: producir y validar `CON_DATOS`, `SIN_DATOS` e `INCONSISTENCIA` (pasos 1-7). Decir con claridad que el orquestador completo falla hoy en el paso 9 por objetos aún no construidos (§4.1 iii), y ofrecer la ejecución por pasos (§7.3) como camino principal, con el `CALL` del orquestador como camino secundario ("espere el error del paso 9; los CSV ya están en S3").
2. **Incluir los prerrequisitos que faltan**: las 2 vistas puente y las 4 filas de `rec_vista.persona` (§6.2); las 4 funciones Lambda (desplegar la Lambda o crear las funciones con un nombre/rol válido); `batch2_homologacion` (5 filas, §9.2) si se quiere ver el truncamiento 3/3/2/2.
3. **Corregir los datos de ejemplo**: `prueba` = `'SV'`; `codigo_campo` = `DT_NUM`/`DD_DIR`/`DC_NUMERO`/`CE_CORREO`; `requerido_campo = 'NO'`; `minimo_requerido_campo = '0'`; `id_auto` únicos; `orden_prioridad` no nulo; longitudes (§9.3); `numero_id`/`tipo_id` numéricos.
4. **Qué esperar en los CSV con el código actual**: layout fijo de 34 columnas ("CON") y 14 ("SIN"), solo 1 teléfono/1 dirección/1 correo y ninguna columna de celular verdadera; con `w_cubo_direccion` solo se pivotan 2 direcciones. Esencial 3/3/2/2 completo exige el trabajo de F2-5 (layout dinámico + `_003`).
5. **Nombres de archivo**: prefijo + sufijo `000`; son 7 objetos de datos, no 3; `ALERTAS` y `ARCHIVO_LOG_W` solo existen si el orquestador llega a los pasos 11-12.
6. **Verificaciones**: usar la consulta de §12 (34 procedures), los conteos de §12, y la bitácora de §7.4. Quitar las referencias a "placeholders".
7. **Re-ejecución**: avisar que hay que recargar los cubos y reiniciar `estado`/`fecha_generacion` antes de repetir (§8.2).
8. **Tono para el público (niño de 10 años)**: conservar la definición de Esencial, los datos 90001/9001 y la checklist; todo término técnico (esquema, DDL, UNLOAD, IAM, collation, Lambda, `CALL`) necesita una explicación de una línea.
