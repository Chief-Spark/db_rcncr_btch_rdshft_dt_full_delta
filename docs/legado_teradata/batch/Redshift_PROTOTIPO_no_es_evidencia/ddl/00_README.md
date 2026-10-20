# DDL Redshift — Migración BATCH2 (Teradata → Redshift)

Orden de ejecución recomendado de estos scripts (son idempotentes, usan `CREATE ... IF NOT EXISTS`):

1. `01_schemas.sql` — esquemas `rec_stage`, `rec_mtdat`, `rec_datos`, `rec_vista` (equivalentes a las bases de datos Teradata `REC_STAGE`, `REC_MTDAT`, `BDDATOS`, `BTTPRUVI`).
2. `02_tablas_configuracion.sql` — traducción directa de las 6 tablas de `DDL.sql` original.
3. `03_tablas_cubos.sql` — tablas cubo de datos de contacto (persona, teléfono, celular, dirección, correo, CIIU). **Estructura inferida**, no documentada en el DDL original.
4. `04_tablas_pivote.sql` — tablas de trabajo horizontales `w_cubo_*` (pivote de N registros por persona a columnas `_001`..`_00N`). Ver nota de diseño sobre el límite fijo de repeticiones.
5. `05_tablas_control.sql` — tablas de control, plan de ejecución, logging y resultados (lote, log_td, plan de ejecución, homologación, historia, estadísticas, inconsistencias, archivo_log).
6. `06_vistas_dimension.sql` — dimensión persona natural/jurídica usada para segmentar PN/PJ.
7. `07_tablas_dependencias_sps.sql` — tablas que usan los SP migrados de `Sps_Batch.sql` (motores `batch_motor_log` y `pro_plan_ejecucion`, `batch2_shells_config`, catálogo de estadísticas, insumo de validación, secuencia). Lista también las dependencias externas que no se crean.
8. `08_funciones_udf.sql` — UDF: 4 Lambda UDF de similitud, 3 SQL UDF de enmascaramiento y `f_td_to_number`. Requiere desplegar antes la Lambda de `../lambda/udf_similitud/`.
9. `09_vistas_dependencias_sps.sql` — vista `vstgbatchcargaubicestandarizada` (late-binding). Después de este DDL se cargan las filas de `../datos/01_catalogos_motor.sql`.

Nota: la numeración 03 ya no es solo "estructura inferida": desde el 2026-10-13 los cubos siguen el layout real de `PRO_BATCH_ADD_PORC_INSUMO`.

## Diferencias de diseño respecto a Teradata

- **Bases de datos → esquemas**: Redshift no separa bases de datos como Teradata; se usan esquemas dentro de la misma base.
- **PRIMARY INDEX → DISTKEY**: se usa `DISTSTYLE KEY` + `DISTKEY` sobre la misma columna que era `PRIMARY INDEX` en Teradata (concepto análogo de distribución de filas entre nodos).
- **FALLBACK / JOURNAL**: no tienen equivalente ni son necesarios en Redshift (gestión de durabilidad a nivel de cluster/snapshot).
- **NOT CASESPECIFIC**: no se emula a nivel de columna; si se requiere, comparar explícitamente con `UPPER()`/`LOWER()` en el SQL de los stored procedures.
- **Tablas "cubo" y de control**: no estaban en el `DDL.sql` original. Su estructura se **infirió** a partir del uso real observado en los `.BTQ`/`.TPT` del workspace. Si los stored procedures reales de Teradata (`PRO_BATCH2_FILTRO_*`, etc., no disponibles como código fuente) usan columnas adicionales, hay que ampliarlas antes de producción.
- **Pivote dinámico (`w_Borrar_001` como "SQL ensamblado como datos")**: Teradata genera el número de columnas dinámicamente en cada ejecución. Redshift fija un máximo de repeticiones por cubo (10, igual al patrón `_001`..`_010` observado en las muestras reales de `Salidas/`). Ampliar si una plantilla de cliente lo requiere.
