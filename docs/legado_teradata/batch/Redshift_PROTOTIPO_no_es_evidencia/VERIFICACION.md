# Verificación de sintaxis — migración BATCH2 a Redshift

No se dispone de un cluster Redshift para ejecutar este código, por lo que la verificación fue manual: revisión línea por línea contra la documentación oficial de AWS Redshift (CREATE PROCEDURE, CALL, UNLOAD, PL/pgSQL) y corrección de los problemas encontrados.

## Problemas encontrados y corregidos

1. **`OUT` no permitido en llamadas anidadas** — Redshift exige `INOUT` (no `OUT`) para parámetros de salida de un stored procedure cuando ese procedure es invocado desde dentro de otro procedure (ver [CALL — Nested calls](https://docs.aws.amazon.com/redshift/latest/dg/r_CALL_procedure.html)). Se corrigió en:
   - `sp_batch2_genera_lote` (`p_lote`)
   - `sp_batch2_fallo_en_lote` (`p_fallo`)
   - `sp_batch2_valida_archivos` (`p_numero_separadores`, `p_ancho_fijo`)

   El orquestador (`10_sp_batch2_proceso_batch2.sql`) pasa variables ya declaradas en su bloque `DECLARE` a estos parámetros, como exige la sintaxis.

2. **Nombres de archivo UNLOAD con sufijo sobrante (`'.CSV_'`)** — error de tecleo propio, corregido a `'.CSV'` en `04_sp_batch2_exportplano.sql`.

3. **Comportamiento UNLOAD vs TPT (diferencia de diseño, no bug)** — Redshift `UNLOAD ... TO 's3://.../prefijo'` siempre trata la ruta como **prefijo** y añade su propio sufijo al archivo físico generado (p. ej. `0000_part_00`). Teradata TPT, en cambio, escribía el archivo con el nombre exacto configurado. No existe forma de que `UNLOAD` produzca un nombre de archivo exacto sin sufijo. Esto se documentó explícitamente en los comentarios de `04_sp_batch2_exportplano.sql` y `05_sp_batch2_exportlog.sql`. **Si el consumidor final requiere el nombre exacto sin sufijo, se necesita un paso adicional fuera de Redshift** (Lambda/Glue que copie/renombre el objeto en S3) antes de considerar el archivo listo para entrega.

## Puntos verificados contra documentación oficial y confirmados correctos

- `CREATE OR REPLACE PROCEDURE nombre(args) LANGUAGE plpgsql AS $$ ... $$;` — orden de cláusulas correcto.
- `VARCHAR(MAX)` es válido tanto en columnas de tabla (hasta 65 535 bytes) como en variables en memoria de PL/pgSQL (hasta 16 MB) — usado en las variables de SQL dinámico de `sp_batch2_exportplano`.
- `EXECUTE 'UNLOAD (...) TO ... IAM_ROLE ...'` como SQL dinámico dentro de un procedure — soportado (`COPY`, `UNLOAD` e `INSERT` son DML válidos dentro de PL/pgSQL en Redshift).
- `TRUNCATE TABLE` dentro de un stored procedure — soportado, pero **hace COMMIT implícito** (inicia una nueva transacción automáticamente). Se documentó esta falta de atomicidad en `sp_batch2_cubo_export`.
- `GETDATE()`, `TO_CHAR(timestamp, formato)` — funciones nativas de Redshift, uso correcto.
- `IDENTITY(1,1)` como tipo de columna — sintaxis válida en Redshift (`rec_stage.batch_archivo_log.id`).
- `DISTSTYLE KEY` + `DISTKEY (columna)` + `SORTKEY (...)` — sintaxis estándar de `CREATE TABLE` en Redshift.
- Redshift **no soporta `EXECUTE ... USING`** (a diferencia de PostgreSQL estándar); por eso todo el SQL dinámico se construye por concatenación de strings con `||` y se escapan las comillas simples con `REPLACE(..., '''', '''''')` antes de envolver en `EXECUTE 'UNLOAD (''...'')...'`.

## Verificación del 2026-10-14 (UDF, motores y catálogos)

Hecho en el equipo local, sin cluster:

- **Lambda de similitud**: 36 pruebas unitarias con `python -m unittest` (`lambda/udf_similitud/test_lambda_function.py`). Cubren los casos de los `.BTQ`, la semántica de C (truncamiento a entero, división por cero, desborde de 32 bits), NULL, el contrato JSON de Redshift y la distancia de edición contra una implementación independiente (3 000 pares aleatorios).
- **SQL UDF de enmascaramiento**: las fórmulas SQL de `ddl/08` se emularon en Python y se compararon con un port literal del C sobre 5 000 cadenas aleatorias: iguales.
- **Estructura de los SQL nuevos o modificados**: comillas, paréntesis y bloques `$$` balanceados en los 12 archivos tocados; mismo número de `CREATE PROCEDURE` y de cierres `$$;`.
- **Sintaxis Redshift de las sentencias guardadas como datos**: las 30 sentencias de `datos/01_catalogos_motor.sql` (18 `LOG` + 12 `ITERADOR`) y la vista de `ddl/09` pasan el parser `sqlglot` 30.23.0 en dialecto Redshift. `sqlglot` no valida nombres de tablas ni de funciones, solo la forma de la sentencia.

No verificado: nada de lo anterior se ejecutó en Redshift. Queda pendiente `casos_validacion_teradata.sql` en Teradata (confirma el supuesto OSA de `editdistance_u`) y `casos_validacion_redshift.sql` en el cluster.

## Verificación del 2026-10-15 (tarea F2-4)

Archivos cubiertos: `ddl/10_tablas_trabajo_f2_4.sql`, `procedures/09_sp_batch2_otros.sql`, `procedures/10_sp_batch2_proceso_batch2.sql`.

**Chequeo estructural** (script temporal, ya eliminado): `$$` balanceados y un par por `CREATE PROCEDURE`, comillas simples pareadas, paréntesis balanceados fuera de literales, ausencia de caracteres no ASCII, y que cada `CREATE PROCEDURE` cierre con `$$;`. Además se verificó que **los 33 nombres invocados con `CALL` en todo `procedures/` resuelven** a uno de los 34 `CREATE PROCEDURE` definidos (el único no invocado es el punto de entrada `sp_batch2_proceso_batch2`).

**Parseo del SQL dinámico con `sqlglot` 30.23.0, dialecto Redshift.** Estos SP construyen SQL que a su vez genera más SQL, así que se verificaron los dos niveles:

- **Nivel 1** — las 67 sentencias que los procedures envían a Redshift: se reconstruyeron evaluando las concatenaciones `v_sql := '...' || var || '...'` con valores de ejemplo. Las 67 parsean.
- **Nivel 2** — las 5 sentencias que el nivel 1 genera a su vez (el `CREATE TABLE bacth_campos_temp` de TRANSPUESTA, su `INSERT` a la tabla vertical, el `CREATE TABLE tabla_w1` y el `INSERT` ensamblado de Completitud_Canal, y el cuerpo del `UNLOAD` de alertas): se reconstruyeron a mano a partir de los fragmentos. Las 5 parsean.

**Dos defectos propios encontrados y corregidos por esta verificación:**

1. Un literal sin cerrar en el armado de `sql_1` de `sp_batch2_transpuesta` (desbalance de una comilla). Se reescribió usando `CHR(39)` en vez de apilar comillas, igual que en `sp_batch2_completitud_canal`, para que el anidamiento de 3 niveles sea auditable.

2. **El separador de `XMLAGG` es un espacio, y el código original depende de eso.** La primera versión tradujo `XMLAGG(x ORDER BY y)` como `LISTAGG(x, '')`. El parseo de nivel 2 lo detectó: el SQL generado salía con `THEN T.tipo_idWHEN T.id=7...` y `A.CIUDAD_TEL_001FROM rec_stage...`, es decir, fragmentos pegados sin separador. En dos lugares independientes (TRANSPUESTA y Completitud_Canal) el original cuenta con que `XMLAGG` intercale un espacio. Confirmado de forma independiente en `P0033_BATCH2_EXPORTPLANO_120.BTQ` línea 141, donde el propio original hace `OREPLACE(XMLAGG(...), ' ', '')` para **quitar** esos espacios cuando no los quiere. Corregido a `LISTAGG(x, ' ')` en las 5 apariciones; coincide con lo que ya se había concluido el 14-oct en `datos/01_catalogos_motor.sql`.

   Diferencia residual: `XMLAGG` escapa `&`, `<` y `>` como entidades XML y `LISTAGG` no. No afecta a estos SP (los fragmentos son SQL y no contienen esos caracteres).

**No verificado en esta tanda:** ejecución real en Redshift; `ANALYZE` dentro de un stored procedure; `QUALIFY` en cada rama de la vista `vstg_batch_estadisticas_exp` (documentado como soportado desde 2023, pero sin probar); `CREATE OR REPLACE VIEW` sobre vistas cuyo número de columnas cambie entre corridas; y el resultado funcional frente a Teradata, que depende de insumos todavía no recibidos.

## Lo que NO se pudo verificar (requiere un cluster Redshift real)

- Ejecución end-to-end del procedimiento maestro `sp_batch2_proceso_batch2`.
- Que el plan de ejecución de Redshift resuelva correctamente los `JOIN` dinámicos construidos como texto en `sp_batch2_exportplano` (la sintaxis se revisó manualmente pero no se corrió `EXPLAIN`).
- Permisos de IAM Role / acceso a S3 para `UNLOAD`.
- Que el formato exacto de salida (headers, comillas, saltos de línea) coincida byte a byte con los `.CSV` originales de Teradata — se recomienda una prueba de comparación con un archivo real de referencia antes de dar por cerrada la migración de `sp_batch2_exportplano`.
