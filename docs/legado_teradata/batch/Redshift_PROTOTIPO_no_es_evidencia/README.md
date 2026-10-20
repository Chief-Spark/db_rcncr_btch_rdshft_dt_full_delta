# Migración BATCH2 (Teradata → Redshift)

Esta carpeta contiene la migración del proceso batch **BATCH2** (prefijo `P0033`, archivos `.BTQ`/`.TPT` en la raíz del workspace) a procedimientos almacenados de Amazon Redshift.

## Contenido

- `ddl/` — DDL de tablas y esquemas Redshift (ver `ddl/00_README.md` para el orden de ejecución y las notas de traducción Teradata → Redshift).
- `procedures/` — Stored procedures Redshift, numerados en el orden en que deben crearse (las dependencias de un procedure sobre otro requieren que el referenciado ya exista).
- `VERIFICACION.md` — Resultado de la revisión manual de sintaxis (no hay cluster Redshift disponible para probar ejecución real).

## Qué se migró con fidelidad alta (SQL completo disponible en los `.BTQ`/`.TPT` originales)

- Generación de lote de ejecución (`sp_batch2_genera_lote`).
- Pivote de cubos de contacto a tablas horizontales (`sp_batch2_cubo_export`).
- Generación de los 3 CSV finales — `CON_DATOS`, `SIN_DATOS`, `INCONSISTENCIA` (`sp_batch2_exportplano`).
- Cierre de la solicitud e historia de resultados (`sp_batch2_actualiza_historia`).
- Exportación de estadísticas ya calculadas al archivo de alertas (`sp_batch2_estadisticas_export`).

## Lógica de negocio de PROCESACUBOS (migrada desde `Sps_Batch.sql`)

`procedures/08_sp_batch2_procesacubos.sql` contiene los 13 SPs con la lógica real: `sp_batch2_filtro_a` .. `sp_batch2_filtro_j`, `sp_batch2_homologaciones`, `sp_batch2_add_porc_insumo` y `sp_batch2_adicionar_incon`. Las convenciones de traducción están en la cabecera de ese archivo.

**Requisito de despliegue:** crear la base de datos Redshift con `COLLATE CASE_INSENSITIVE` (equivalente a `NOT CASESPECIFIC` de Teradata).

## UDF, motores de SQL y catálogos (migrado el 2026-10-14)

- **UDF de similitud** (`Bach_Similitud_Dir_MZ`, `PorcSimilitud`, `Bach_Similitud_Tel`, `Bach_Similitud_email`): portadas del C de `FuncionesUDF/` a una sola Lambda Python en `lambda/udf_similitud/` (36 pruebas unitarias). Se declaran en `ddl/08_funciones_udf.sql`. Despliegue y validación contra Teradata: ver la cabecera de ese script y `lambda/udf_similitud/casos_validacion_*.sql`.
- **UDF de enmascaramiento** (`DataMasking`, `DirDataMasking`, `RazonDataMasking`): SQL UDF en `ddl/08_funciones_udf.sql`, sin Lambda.
- **Vista `VstgBATCHCargaUbicEstandarizada`**: `ddl/09_vistas_dependencias_sps.sql` (late-binding; necesita las tablas del proceso P0034).
- **Motores**: `sp_batch2_estadisticas_cfg` y `sp_batch2_plan_ejecucion_shell` (`procedures/09b`), `sp_batch2_archivo_log` y `sp_batch2_exportlog` (`procedures/05`).
- **Filas de catálogos y motores**: `datos/01_catalogos_motor.sql` (18 filas `LOG` de `batch_motor_log`, 12 filas `ITERADOR` de `pro_plan_ejecucion` y el catálogo `batch_archivo_log`), ya reescritas a Redshift.

## Tarea F2-4: completada (2026-10-15). Ya no hay placeholders

Los 4 SP que faltaban se migraron en `procedures/09_sp_batch2_otros.sql`, que reemplaza a `09_sp_batch2_otros_placeholder.sql` (eliminado):

| SP Teradata | Procedure Redshift | Qué le falta para ejecutar |
|---|---|---|
| `PRO_BATCH2_TRANSPUESTA` | `sp_batch2_transpuesta` | `v_ba2_campos_salida`, `vstg_batch2_*` |
| `PRO_Batch2_Completitud_Canal` | `sp_batch2_completitud_canal` | `v_ba2_campos_salida`, `vstg_batch2_*` |
| `PRO_BATCH2_ESTADISTICAS` | `sp_batch2_estadisticas` | filas de `pro_batch2_filtros_estadisticas`, `vstg_inconsis_pnpj` |
| `PRO_BATCH2_CANTREPCANAL_CON` | `sp_batch2_cantrepcanal_con` | filas `CANT_REP_CANAL_CONTACTO` de `batch_motor_log`, DDL de `batch_cubo_persona11` |

Con esto, **los 19 SP de `Sps_Batch.sql` están migrados**. Lo que falta para una corrida completa son datos y objetos, no código.

### Objetos que la migración todavía no construye

`sp_batch2_transpuesta` y `sp_batch2_completitud_canal` leen `rec_stage.v_ba2_campos_salida` y `rec_stage.vstg_batch2_pn/_pj/_pnpj`. En Teradata esas vistas las crean los pasos BTEQ de CUBOEXPORT y EXPORTPLANO; el `sp_batch2_exportplano` de Redshift va directo de las tablas pivote al `UNLOAD` con un `SELECT` fijo, así que no existen. Es el mismo vacío de layout descrito en `GUIA_PRUEBA_PRODUCTO_ESENCIAL.md` sección 3.2, y construirlas es trabajo de F2-5. Las definiciones originales están en `P0033_BATCH2_CUBOEXPORT_111.BTQ` (líneas 43, 177, 1339) y `P0033_BATCH2_EXPORTPLANO_111/120.BTQ`. Inventario completo en la cabecera de `ddl/10_tablas_trabajo_f2_4.sql`.

## Bugs del original: se replican, no se corrigen

La fase 1 debe entregar **los mismos resultados que Teradata, incluso los erróneos**. Los 31 defectos encontrados en el código original están inventariados en `../Bugs_Encontrados.md`, con su severidad, el archivo donde se replica cada uno y las 4 desviaciones deliberadas (donde replicar era imposible o impedía desplegar). No modificar este código para "arreglar" ninguno de ellos sin pasar por esa lista.

## Insumos que siguen pendientes

Ver la lista actualizada al final de la sesión 2026-10-14 en `Bitacora_Batch_Teradata.md`.

## Cómo desplegar (orden)

```sql
-- 1. DDL
\i ddl/01_schemas.sql
\i ddl/02_tablas_configuracion.sql
\i ddl/03_tablas_cubos.sql
\i ddl/04_tablas_pivote.sql
\i ddl/05_tablas_control.sql
\i ddl/06_vistas_dimension.sql
\i ddl/07_tablas_dependencias_sps.sql
\i ddl/08_funciones_udf.sql      -- antes: desplegar la Lambda y reemplazar <LAMBDA_UDF_SIMILITUD> e <IAM_ROLE_LAMBDA_ARN>
\i ddl/09_vistas_dependencias_sps.sql
\i ddl/10_tablas_trabajo_f2_4.sql

-- 2. Procedures
\i procedures/01_sp_batch2_genera_lote.sql
\i procedures/02_sp_batch2_log_helpers.sql
\i procedures/03_sp_batch2_cubo_export.sql
\i procedures/04_sp_batch2_exportplano.sql
\i procedures/05_sp_batch2_exportlog.sql
\i procedures/06_sp_batch2_actualiza_historia.sql
\i procedures/07_sp_batch2_valida_archivos.sql
\i procedures/08_sp_batch2_procesacubos.sql
\i procedures/09b_sp_batch2_motores_sql.sql
\i procedures/09_sp_batch2_otros.sql   -- despues de 09b: sp_batch2_estadisticas llama a sp_batch2_estadisticas_cfg
\i procedures/10_sp_batch2_proceso_batch2.sql

-- 3. Datos de catalogos y motores (UTF-8)
\i datos/01_catalogos_motor.sql
```

## Cómo ejecutar el pipeline completo para una solicitud

```sql
CALL rec_stage.sp_batch2_proceso_batch2(
    p_id_solicitud     => 4421,
    p_s3_bucket_salida  => 's3://mi-bucket/batch2/salidas/',
    p_iam_role         => 'arn:aws:iam::123456789012:role/RedshiftUnloadRole'
);
```

Requiere que `rec_stage.batch_datos_generales`, `rec_stage.batch_solicitud_batch` y las tablas cubo (`rec_stage.batch_cubo_*`) ya tengan datos cargados para `p_id_solicitud` (esa carga de insumo está fuera del alcance de BATCH2 — corresponde a procesos previos del pipeline mayor Reconocer).

## Diferencias de comportamiento frente a Teradata (ver detalle en cada archivo)

1. **Nombres de archivo en S3**: `UNLOAD` siempre genera un sufijo automático sobre el prefijo indicado; no replica el nombre exacto sin sufijo que generaba TPT. Ver `VERIFICACION.md`.
2. **Esquema fijo para columnas pivotadas**: el límite de repeticiones por cubo (teléfono, dirección, etc.) está fijo en Redshift (10), mientras Teradata lo generaba dinámicamente. Ver `ddl/04_tablas_pivote.sql`.
3. **Atomicidad**: `TRUNCATE TABLE` dentro de un stored procedure hace commit implícito; el pipeline no es 100% atómico de punta a punta.
