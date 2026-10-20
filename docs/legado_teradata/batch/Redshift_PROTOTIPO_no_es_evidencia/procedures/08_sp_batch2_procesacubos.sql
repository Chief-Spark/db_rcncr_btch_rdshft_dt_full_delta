-- ============================================================================
-- Script:      08_sp_batch2_procesacubos.sql
-- Objetivo:    Migracion a Redshift de los 13 stored procedures Teradata que
--              ejecuta P0033_BATCH2_PROCESACUBOS_111.BTQ (paso PROCESACUBOS):
--                PRO_BATCH2_FILTRO_A .. PRO_BATCH2_FILTRO_J
--                PRO_BATCH2_HOMOLOGACIONES
--                PRO_BATCH_ADD_PORC_INSUMO
--                PRO_BATCH2_ADICIONAR_INCON
--              Reemplaza a 08_sp_batch2_filtros_placeholder.sql.
-- Fuente:      Sps_Batch.sql (codigo fuente Teradata, lineas 1-6160).
--
-- ORDEN DE EJECUCION REAL (P0033_BATCH2_PROCESACUBOS_111.BTQ):
--   A -> B -> C -> D -> E('N') -> E('J') -> F -> G -> HOMOLOGACIONES
--     -> I -> H -> J -> ADD_PORC_INSUMO -> ADICIONAR_INCON
--
-- CONVENCIONES DE LA MIGRACION (aplican a todos los SP de este archivo):
--
-- 1. Firma. Se eliminan los parametros de nombre de base de datos
--    (P_BDVISTA, P_BDSTAGE, P_BDMTDAT, P_BDDATOS, P_BTTVISTA): en Redshift
--    los esquemas son fijos (rec_stage, rec_mtdat, rec_datos, rec_vista).
--    Se elimina OUT P_ERROR: un error se propaga como excepcion (ver 3).
--    P_StartTimeStampPadre no se usa (sp_execstring_des registra GETDATE()).
--    Firma estandar:
--      (p_lote BIGINT, p_nombre_proceso VARCHAR(100),
--       p_id_plantilla BIGINT, p_id_solicitud BIGINT [, otros])
--    p_nombre_proceso = P_Nombre_Proceso_Padre (variable ${process} del BTQ).
--
-- 2. SQL dinamico. Igual que el original, cada sentencia se arma como texto
--    y se ejecuta con rec_mtdat.sp_execstring_des(lote, proceso, sql, paso),
--    que registra en rec_mtdat.log_td_detalle 'Finalizo Exitosamente' o el
--    error. Asi el log conserva el mismo rastro paso a paso que Teradata.
--
-- 3. Errores. En Teradata, si V_ERROR no venia vacio se hacia LEAVE L1 y el
--    BTQ terminaba con .EXIT 104 al ver el error en LOG_TD_DETALLE. En
--    Redshift, sp_execstring_des registra el error y la excepcion se
--    relanza, deteniendo el SP y el pipeline en el mismo punto.
--
-- 4. Tablas de trabajo. Las tablas que el original creaba en P_BDSTAGE
--    (CREATE MULTISET TABLE ... WITH DATA PRIMARY INDEX(x)) se crean en
--    rec_stage con el mismo nombre en minusculas
--    (CREATE TABLE ... DISTKEY(x) AS SELECT ...). El patron
--    "SELECT ... FROM dbc.tables + DROP TABLE" se reemplaza por
--    rec_mtdat.sp_drop_si_existe (DROP TABLE IF EXISTS).
--
-- 5. Mayusculas/minusculas. Las columnas Teradata son NOT CASESPECIFIC, por
--    lo que sus comparaciones (=, LIKE, IN, GROUP BY) ignoran mayusculas.
--    REQUISITO DE DESPLIEGUE: crear la base de datos Redshift con
--    COLLATE CASE_INSENSITIVE, que hace insensibles a mayusculas las
--    comparaciones, ordenamientos y LIKE. Con esa collation la traduccion
--    es literal; sin ella, varios filtros dejarian de coincidir.
--
-- 6. Traducciones de sintaxis Teradata -> Redshift usadas:
--    SEL -> SELECT; x LIKE ANY (subconsulta) -> EXISTS (... AND x LIKE ...);
--    UPDATE t FROM (...) b SET ... -> UPDATE t SET ... FROM (...) b
--    (sin alias en la tabla destino); DEL t FROM ... -> DELETE FROM t USING;
--    ZEROIFNULL(x) -> COALESCE(x,0); NULLIFZERO(x) -> NULLIF(x,0);
--    INDEX(a,b) -> STRPOS(a,b); OREPLACE -> REPLACE; OTRANSLATE -> TRANSLATE;
--    CHARACTER_LENGTH -> LEN; eListGetValByIdx -> SPLIT_PART;
--    hash_md5 -> MD5; TO_NUMBER(x) -> rec_vista.f_td_to_number(x);
--    COLLECT STATISTICS -> ANALYZE; cursores FOR ... DO -> FOR rec IN ... LOOP;
--    ACTIVITY_COUNT -> GET DIAGNOSTICS ... = ROW_COUNT / FOUND;
--    conversiones implicitas numero<->texto -> CAST explicito;
--    CHAR(x) / CHARS(x) (largo de cadena en Teradata) -> LEN(x);
--    MERGE solo con WHEN MATCHED -> UPDATE ... FROM (Redshift exige
--    WHEN NOT MATCHED en MERGE).
--
-- 7. Diferencias de semantica que se replican de forma explicita:
--    - CAST(decimal AS INTEGER): Teradata trunca; Redshift redondea o trunca
--      segun el parametro enable_numeric_rounding. Se usa
--      CAST(TRUNC(x) AS INTEGER).
--    - Orden de NULL: Teradata ordena NULL como el valor mas bajo (primero
--      en ASC, ultimo en DESC); Redshift por defecto hace lo contrario. En
--      los ORDER BY de ventana sobre columnas que pueden ser NULL se escribe
--      NULLS FIRST / NULLS LAST.
--    - Alias del SELECT: Teradata permite usarlos en el mismo SELECT, WHERE
--      y QUALIFY, pero si el alias coincide con una columna de las tablas del
--      FROM, gana la columna. Se reescriben con subconsultas respetando esa
--      regla.
--    - Tablas SET (CREATE TABLE sin MULTISET): eliminan filas duplicadas en
--      Teradata; se replica con SELECT DISTINCT donde aplica.
--
-- 8. Errores: Teradata confirmaba cada sentencia; en Redshift, si un paso
--    falla se revierte todo lo hecho en el CALL en curso (salvo lo que haya
--    confirmado un TRUNCATE). El registro del error en log_td_detalle si
--    persiste.
-- ============================================================================


-- ============================================================================
-- PRO_BATCH2_FILTRO_A -> rec_stage.sp_batch2_filtro_a
-- Fuente: Sps_Batch.sql lineas 2-191.
-- Marca BATCH_CUBO_DIRECCION.FILTRO_A = 1 en las direcciones que contienen
-- alguna particula configurada en BATCH_DIRECCION_FILTROS para la
-- solicitud/plantilla (3 reglas: CODIGO_CAMPO; CODIGO_TIPO + VALOR_PARTICULA;
-- CODIGO_TIPO sin VALOR_PARTICULA). El resto queda en 0.
-- Traduccion: cada LIKE ANY (subconsulta) pasa a EXISTS con LIKE.
-- Diferencia menor: el paso de log del UPDATE inicial dice "FILTRO_H = 0"
-- en el original (copia de otro SP); se conserva el texto.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_a(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_sol  VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla  VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
BEGIN
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.pro_batch2_filtro_a1');

    v_sql := 'CREATE TABLE rec_stage.pro_batch2_filtro_a1 DISTKEY(id_auto) AS
SELECT d.id_auto
FROM rec_stage.batch_cubo_direccion d
WHERE EXISTS (SELECT 1 FROM rec_stage.batch_direccion_filtros f
              WHERE f.codigo_campo IS NOT NULL
                AND f.id_solicitud = ' || v_sol || '
                AND f.id_plantilla = ' || v_pla || '
                AND d.direccion LIKE (''%'' || TRIM(f.codigo_campo) || ''%''))
UNION
SELECT d.id_auto
FROM rec_stage.batch_cubo_direccion d
WHERE EXISTS (SELECT 1 FROM rec_stage.batch_direccion_filtros f
              WHERE f.codigo_tipo IS NOT NULL
                AND f.valor_particula IS NOT NULL
                AND f.id_solicitud = ' || v_sol || '
                AND f.id_plantilla = ' || v_pla || '
                AND TRIM(d.direccion) LIKE (''%'' || UPPER(TRIM(f.codigo_tipo)) || ''_%''
                                            || UPPER(TRIM(f.valor_particula)) || ''_%''))
UNION
SELECT d.id_auto
FROM rec_stage.batch_cubo_direccion d
WHERE EXISTS (SELECT 1 FROM rec_stage.batch_direccion_filtros f
              WHERE f.valor_particula IS NULL
                AND f.id_solicitud = ' || v_sol || '
                AND f.id_plantilla = ' || v_pla || '
                AND TRIM(d.direccion) LIKE (''%'' || UPPER(TRIM(f.codigo_tipo)) || ''%''))';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla PRO_BATCH2_FILTRO_A1');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion SET filtro_a = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_H = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET filtro_a = 1
FROM (SELECT id_auto AS id_auto_up
      FROM rec_stage.pro_batch2_filtro_a1
      GROUP BY 1) b
WHERE batch_cubo_direccion.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_DIRECCION Campo FILTRO_A');
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_B -> rec_stage.sp_batch2_filtro_b
-- Fuente: Sps_Batch.sql lineas 193-549.
-- Marca FILTRO_B = 1 en BATCH_CUBO_TELEFONO, BATCH_CUBO_CELULAR,
-- BATCH_CUBO_DIRECCION y BATCH_CUBO_CORREO para los registros cuyo
-- MESES_DESDE_EL_ULTIMO_REPORTE supera el valor NO_ENTREGADO_X_MESES
-- configurado en BATCH_DATOS_GENERALES para la solicitud/plantilla (solo si
-- ese valor es > 0, ajuste #2). Arma una tabla de trabajo
-- PRO_BATCH2_FILTRO_B (ID_AUTO, TIPO = cubo de origen), pone FILTRO_B = 0 en
-- cada cubo, marca 1 por cruce con la tabla de trabajo y la borra al final.
-- Traduccion:
--   - PRIMARY INDEX(ID_AUTO) INDEX(TIPO) -> DISTKEY(id_auto) SORTKEY(tipo)
--     (Redshift no tiene indices secundarios; el SORTKEY cumple el rol de
--     acceso por TIPO). Se conserva UNION (con eliminacion de duplicados).
--   - NO_ENTREGADO_X_MESES es VARCHAR(100) en el DDL Redshift. En Teradata
--     "NO_ENTREGADO_X_MESES > 0" convertia el texto a numero implicitamente
--     (blanco -> 0; texto no numerico -> error). En Redshift se usa
--     rec_vista.f_td_to_number(...) > 0: mismo resultado para valores
--     numericos y blancos; un texto no numerico se descarta (NULL) en vez de
--     abortar. El CAST(TRIM(...) AS INTEGER) del valor se conserva literal.
--   - Si la subconsulta escalar devuelve mas de una fila (configuracion
--     duplicada para solicitud/plantilla) ambos motores abortan con error.
--   - El DROP inicial (condicionado a dbc.tables) usa sp_drop_si_existe; el
--     DROP final del original es incondicional y se conserva igual, con el
--     mismo texto de paso.
-- Bugs replicados: ninguno identificado.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_b(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_sol  VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla  VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
BEGIN
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.pro_batch2_filtro_b');

    -- ------------------------------------------------------------------
    -- Tabla de trabajo: registros de los 4 cubos que superan el umbral
    -- NO_ENTREGADO_X_MESES (#2: solo si el umbral es > 0).
    -- ------------------------------------------------------------------
    v_sql := 'CREATE TABLE rec_stage.pro_batch2_filtro_b DISTKEY(id_auto) SORTKEY(tipo) AS
SELECT id_auto, CAST(''CUBO_TELEFONO'' AS VARCHAR(30)) AS tipo  /*#1*/
FROM rec_stage.batch_cubo_telefono
WHERE meses_desde_el_ultimo_reporte > (SELECT CAST(TRIM(no_entregado_x_meses) AS INTEGER)
                                       FROM rec_stage.batch_datos_generales
                                       WHERE id_solicitud = ' || v_sol || '
                                         AND id_plantilla = ' || v_pla || '
                                         AND no_entregado_x_meses IS NOT NULL
                                         AND rec_vista.f_td_to_number(no_entregado_x_meses) > 0 /*#2*/
                                      )
  AND meses_desde_el_ultimo_reporte IS NOT NULL

UNION
SELECT id_auto, ''CUBO_CELULAR'' AS tipo
FROM rec_stage.batch_cubo_celular
WHERE meses_desde_el_ultimo_reporte > (SELECT CAST(TRIM(no_entregado_x_meses) AS INTEGER)
                                       FROM rec_stage.batch_datos_generales
                                       WHERE id_solicitud = ' || v_sol || '
                                         AND id_plantilla = ' || v_pla || '
                                         AND no_entregado_x_meses IS NOT NULL
                                         AND rec_vista.f_td_to_number(no_entregado_x_meses) > 0 /*#2*/
                                      )
  AND meses_desde_el_ultimo_reporte IS NOT NULL

UNION
SELECT id_auto, ''CUBO_DIRECCION'' AS tipo
FROM rec_stage.batch_cubo_direccion
WHERE meses_desde_el_ultimo_reporte > (SELECT CAST(TRIM(no_entregado_x_meses) AS INTEGER)
                                       FROM rec_stage.batch_datos_generales
                                       WHERE id_solicitud = ' || v_sol || '
                                         AND id_plantilla = ' || v_pla || '
                                         AND no_entregado_x_meses IS NOT NULL
                                         AND rec_vista.f_td_to_number(no_entregado_x_meses) > 0 /*#2*/
                                      )
  AND meses_desde_el_ultimo_reporte IS NOT NULL

UNION
SELECT id_auto, ''CUBO_CORREO'' AS tipo
FROM rec_stage.batch_cubo_correo
WHERE meses_desde_el_ultimo_reporte > (SELECT CAST(TRIM(no_entregado_x_meses) AS INTEGER)
                                       FROM rec_stage.batch_datos_generales
                                       WHERE id_solicitud = ' || v_sol || '
                                         AND id_plantilla = ' || v_pla || '
                                         AND no_entregado_x_meses IS NOT NULL
                                         AND rec_vista.f_td_to_number(no_entregado_x_meses) > 0 /*#2*/
                                      )
  AND meses_desde_el_ultimo_reporte IS NOT NULL';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla PRO_BATCH2_FILTRO_B');

    -- ------------------------------------------------------------------
    -- CUBO TELEFONO
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_telefono SET filtro_b = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_TELEFONO FILTRO_B = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET filtro_b = 1
FROM (SELECT id_auto AS id_auto_up
      FROM rec_stage.pro_batch2_filtro_b
      WHERE tipo = ''CUBO_TELEFONO''
      GROUP BY 1) b
WHERE batch_cubo_telefono.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_TELEFONO Campo FILTRO_B');

    -- ------------------------------------------------------------------
    -- CUBO CELULAR
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_celular SET filtro_b = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CELULAR FILTRO_B = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET filtro_b = 1
FROM (SELECT id_auto AS id_auto_up
      FROM rec_stage.pro_batch2_filtro_b
      WHERE tipo = ''CUBO_CELULAR''
      GROUP BY 1) b
WHERE batch_cubo_celular.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CELULAR Campo FILTRO_B');

    -- ------------------------------------------------------------------
    -- CUBO DIRECCION
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_direccion SET filtro_b = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_B = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET filtro_b = 1
FROM (SELECT id_auto AS id_auto_up
      FROM rec_stage.pro_batch2_filtro_b
      WHERE tipo = ''CUBO_DIRECCION''
      GROUP BY 1) b
WHERE batch_cubo_direccion.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_DIRECCION Campo FILTRO_B');

    -- ------------------------------------------------------------------
    -- CUBO CORREO
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_correo SET filtro_b = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CORREO FILTRO_B = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET filtro_b = 1
FROM (SELECT id_auto AS id_auto_up
      FROM rec_stage.pro_batch2_filtro_b
      WHERE tipo = ''CUBO_CORREO''
      GROUP BY 1) b
WHERE batch_cubo_correo.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CORREO Campo FILTRO_B');

    -- ------------------------------------------------------------------
    -- Borrar tabla de trabajo (incondicional, igual que el original)
    -- ------------------------------------------------------------------
    v_sql := 'DROP TABLE rec_stage.pro_batch2_filtro_b';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'DROP TABLE PRO_BATCH2_FILTRO_B');
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_C -> rec_stage.sp_batch2_filtro_c
-- Fuente: Sps_Batch.sql lineas 550-674.
-- "Motor" de SQL guardado como datos: recorre BATCH_MOTOR_LOG con
-- TIPO = 'FILTRO-C' y SQL_STRING no nulo, en orden de ID; en cada fila
-- reemplaza los marcadores P_BDSTAGE, P_ID_SOLICITUD y P_ID_PLANTILLA del
-- texto SQL_STRING y lo ejecuta via sp_execstring_des. Segun la cabecera del
-- original, esas sentencias marcan FILTRO_C en BATCH_CUBO_DIRECCION,
-- BATCH_CUBO_TELEFONO, BATCH_CUBO_CORREO y BATCH_CUBO_CELULAR; la logica
-- real (incluido cualquier reseteo FILTRO_C = 0) esta en las filas, no en
-- el SP.
--
-- ACCION REQUERIDA (dependencia de datos):
--   Las filas de rec_stage.batch_motor_log con TIPO = 'FILTRO-C' deben
--   migrarse desde Teradata (P_BDSTAGE.BATCH_MOTOR_LOG) y cada SQL_STRING
--   debe REESCRIBIRSE a sintaxis Redshift siguiendo las mismas reglas de
--   esta migracion (SEL -> SELECT; UPDATE t FROM (...) b SET ... ->
--   UPDATE t SET ... FROM (...) b sin alias en destino; DEL -> DELETE ...
--   USING; funciones Teradata -> Redshift; conversiones implicitas -> CAST;
--   nombres de tablas en minusculas). El contenido de esas filas NO esta en
--   el workspace, por lo que no fue revisado ni traducido.
--   Reglas para reescribir las filas:
--     * Los marcadores se reemplazan con REGEXP_REPLACE, que en Redshift es
--       sensible a mayusculas (igual que el default de Teradata): escribirlos
--       EXACTAMENTE en mayusculas: P_BDSTAGE, P_ID_SOLICITUD, P_ID_PLANTILLA.
--     * P_BDSTAGE se reemplaza por 'rec_stage' (antes: nombre de la BD stage).
--     * Solo esos 3 marcadores se reemplazan; cualquier otro (P_BDVISTA,
--       P_BDDATOS, ...) quedaria literal y la sentencia fallaria, igual que
--       en Teradata.
--     * Cada fila debe ser UNA sentencia ejecutable con EXECUTE (sin ';'
--       final multiple ni bloques BT/ET).
--     * Conservar el mismo ID (orden de ejecucion) y DATO (texto del paso).
--
-- Traduccion:
--   - PREPARE + cursor dinamico (necesario en Teradata solo porque el nombre
--     de la BD era parametro) -> FOR r IN SELECT ... LOOP estatico sobre
--     rec_stage.batch_motor_log, mismo filtro y mismo ORDER BY id.
--     "FETCH ... IF SQLCODE <> 0 THEN LEAVE CUR2" -> fin natural del FOR.
--   - REGEXP_REPLACE anidado en el mismo orden (P_BDSTAGE, P_ID_SOLICITUD,
--     P_ID_PLANTILLA); en ambos motores reemplaza todas las ocurrencias.
--   - "SET P_ERROR = V_CADENA" (traza del SQL armado en el OUT P_ERROR,
--     sobrescrita enseguida por V_ERROR) se elimina junto con P_ERROR; el
--     SQL ejecutado queda en rec_mtdat.log_td_detalle.cadena.
--   - Teradata leia SQL_STRING en V_QSQL VARCHAR(32000); en Redshift
--     sql_string y v_sql son VARCHAR(65535) (sin truncamiento a 32000).
--   - Si DATO es NULL, el texto de paso queda NULL en ambos motores
--     (concatenacion con NULL).
-- BUG ORIGINAL REPLICADO: el texto de paso es 'Se realiza update al campo'
--   || DATO || ';' sin espacio antes de DATO; se conserva para que el log
--   sea identico.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_c(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_paso  VARCHAR(500);
    v_sol   VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    v_pla   VARCHAR(20) := CAST(p_id_plantilla AS VARCHAR(20));
    r       RECORD;
BEGIN
    -- ------------------------------------------------------------------
    -- Cursor sobre el motor BATCH_MOTOR_LOG (TIPO = 'FILTRO-C'), en orden
    -- de ID. La tabla se carga con un script inicial (ver cabecera).
    -- ------------------------------------------------------------------
    FOR r IN
        SELECT dato, sql_string
        FROM rec_stage.batch_motor_log
        WHERE sql_string IS NOT NULL
          AND tipo = 'FILTRO-C'
        ORDER BY id
    LOOP
        -- Reemplazo de marcadores (mismo orden que el original)
        v_sql := REGEXP_REPLACE(
                   REGEXP_REPLACE(
                     REGEXP_REPLACE(r.sql_string, 'P_BDSTAGE', 'rec_stage'),
                     'P_ID_SOLICITUD', v_sol),
                   'P_ID_PLANTILLA', v_pla);

        -- BUG ORIGINAL REPLICADO: sin espacio entre 'campo' y DATO
        v_paso := 'Se realiza update al campo' || r.dato || ';';

        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, v_paso);
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_D -> rec_stage.sp_batch2_filtro_d
-- Fuente: Sps_Batch.sql lineas 675-1059.
-- Filtro D "Datos minimos de inclusion": marca FILTRO_D = 1 en los registros
-- de cada cubo que tienen NULL en alguno de los campos configurados como
-- requeridos (BATCH_SALIDAS_CAMPOS.REQUERIDO_CAMPO = 'SI') para la
-- solicitud/plantilla; el resto queda en 0. El campo fisico de cada codigo
-- sale de BATCH2_HOMOLOGACION.HOMOLOGADO y el cubo de BATCH2_HOMOLOGACION.CUBO.
-- Pasos: BACTH_FD_1 (un fragmento "<col> IS NULL [OR]" por campo/cubo),
-- BACTH_FD_2 (consulta recursiva que encadena los fragmentos y genera el
-- CREATE TABLE <Cubo>FD por cubo), y un cursor que crea cada <Cubo>FD y
-- actualiza FILTRO_D (0 a todo el cubo, 1 a los ID_AUTO de <Cubo>FD).
--
-- Decisiones de traduccion:
-- - BACTH_FD_1, BACTH_FD_2 y las tablas <Cubo>FD se crean en el original
--   con CREATE TABLE sin MULTISET (tabla SET en modo Teradata, elimina filas
--   duplicadas). Se replica con SELECT DISTINCT en BACTH_FD_1 y en el SQL
--   generado para <Cubo>FD (los duplicados de BACTH_FD_1 aparecen si un
--   CODIGO_CAMPO requerido figura en varias secciones de BATCH_SALIDAS_CAMPOS).
--   BACTH_FD_2 no puede tener duplicados (QUALIFY deja 1 fila por cubo).
-- - En BACTH_FD_1 el original referencia el alias MAX_ID (ventana) dentro
--   del CASE del mismo SELECT; se calcula en una subconsulta.
-- - '0A'XC (salto de linea hexadecimal) -> CHR(10).
-- - Columna recursiva FILTRO_SQL: en Teradata su tipo lo fija la semilla
--   (VARCHAR(1000)) y en modo Teradata la concatenacion se trunca en
--   silencio a 1000. Se replica con CAST(... AS VARCHAR(1000)) en el termino
--   recursivo (Redshift trunca en silencio al hacer CAST a VARCHAR menor).
-- - Cursor dinamico (PREPARE ... OPEN) -> FOR r IN EXECUTE ... LOOP.
-- - OREPLACE(V_SQL,'REC_STAGE',P_BDSTAGE) y 'REC_VISTA' -> P_BDVISTA se
--   eliminan (en Redshift los esquemas son fijos y el SQL generado ya usa
--   rec_stage). Se conserva REPLACE(v_sql,'P_LOTE',lote) aunque el SQL
--   generado no contiene ese texto (solo afectaria si un HOMOLOGADO lo
--   contuviera).
-- - "WITH DATA" del SQL generado se elimina; la tabla <Cubo>FD no tenia
--   PRIMARY INDEX explicito (PI por defecto = ID_AUTO) -> DISTKEY(id_auto).
-- - Los nombres de tabla generados (p. ej. 'DireccionFD') se usan sin
--   comillas, por lo que en Redshift quedan en minusculas (direccionfd).
-- - El texto de paso de los DROP lo genera sp_drop_si_existe
--   ('DROP TABLE rec_stage.<tabla>' en vez de 'DROP TABLE <tabla>').
--
-- Comportamientos del original que se conservan:
-- - Un cubo sin campos requeridos no entra al cursor: su FILTRO_D no se
--   toca (queda con el valor que traia, normalmente NULL).
-- - BUG ORIGINAL REPLICADO: si BATCH2_HOMOLOGACION.CUBO no es uno de los 6
--   mapeados (p. ej. 'PuntoInteres') o HOMOLOGADO es NULL, NOMBRE_CUBO o
--   FILTRO_SQL quedan NULL, Q_SQL resulta NULL y el paso 'Crea tabla' falla
--   (EXECUTE de un texto NULL). Ademas QUALIFY agrupa por NOMBRE_CUBO, por
--   lo que todos los cubos no mapeados comparten una sola fila.
-- - BUG ORIGINAL REPLICADO: si la concatenacion de filtros de un cubo supera
--   1000 caracteres se trunca y el CREATE TABLE <Cubo>FD generado queda
--   sintacticamente invalido.
-- - Si un cubo tiene dos filas con el mismo ID_SEQUENCIA, la cadena mas
--   larga no es unica y QUALIFY elige una de forma no determinista (igual
--   que el original).
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_d(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_sol   VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla   VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    v_lote  VARCHAR(30) := CAST(p_lote AS VARCHAR(30));
    r       RECORD;
BEGIN
    -- ------------------------------------------------------------------
    -- BACTH_FD_1: un fragmento de filtro por campo requerido y cubo
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fd_1');

    -- SELECT DISTINCT: el original crea tabla SET (CREATE TABLE sin MULTISET)
    v_sql := 'CREATE TABLE rec_stage.bacth_fd_1 DISTKEY(id) AS
SELECT DISTINCT
    x.id
   ,x.max_id
   ,CAST(CASE WHEN x.id = x.max_id THEN x.homologado || '' IS NULL ''
              ELSE x.homologado || '' IS NULL  OR'' END
         AS VARCHAR(1000)) AS filtro_sql
   ,x.nombre_cubo
   ,x.cubo
FROM (
    SELECT
        b2h.id_sequencia AS id
       ,CAST(MAX(b2h.id_sequencia) OVER (PARTITION BY b2h.cubo) AS INTEGER) AS max_id
       ,b2h.homologado
       ,CASE WHEN b2h.cubo = ''Celular''   THEN ''BATCH_CUBO_CELULAR''
             WHEN b2h.cubo = ''Ciiu''      THEN ''BATCH_CUBO_CIIU''
             WHEN b2h.cubo = ''Correo''    THEN ''BATCH_CUBO_CORREO''
             WHEN b2h.cubo = ''Direccion'' THEN ''BATCH_CUBO_DIRECCION''
             WHEN b2h.cubo = ''Persona''   THEN ''BATCH_CUBO_PERSONA''
             WHEN b2h.cubo = ''Telefono''  THEN ''BATCH_CUBO_TELEFONO''
        END AS nombre_cubo
       ,b2h.cubo
    FROM rec_stage.batch_salidas_campos bsc
    INNER JOIN rec_stage.batch2_homologacion b2h
       ON bsc.codigo_campo = b2h.codigo_campo
      AND bsc.id_solicitud = ' || v_sol || '
      AND bsc.id_plantilla = ' || v_pla || '
    WHERE bsc.requerido_campo = ''SI''
) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_FD_1');

    -- ------------------------------------------------------------------
    -- BACTH_FD_2: consulta recursiva que encadena los filtros por cubo y
    -- genera el CREATE TABLE <Cubo>FD de cada cubo
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fd_2');

    -- CAST a VARCHAR(1000) en el termino recursivo: replica el tipo fijado
    -- por la semilla en Teradata (trunca en silencio).
    -- El SQL generado usa SELECT DISTINCT porque el original crea <Cubo>FD
    -- como tabla SET.
    v_sql := 'CREATE TABLE rec_stage.bacth_fd_2 DISTSTYLE ALL AS
WITH RECURSIVE concat_list (id, max_id, filtro_sql, nombre_cubo, cubo, auto_id) AS
(
  SELECT
      id
     ,max_id
     ,filtro_sql
     ,nombre_cubo
     ,cubo
     ,1 AS auto_id
  FROM rec_stage.bacth_fd_1

  UNION ALL

  SELECT
      t1.id
     ,t1.max_id
     ,CAST(t1.filtro_sql || CHR(10) || t2.filtro_sql AS VARCHAR(1000))
     ,t1.nombre_cubo
     ,t1.cubo
     ,t2.auto_id + 1
  FROM rec_stage.bacth_fd_1 t1
  INNER JOIN concat_list t2
     ON t1.cubo = t2.cubo
  WHERE t1.id < t2.id
)
SELECT
    ''CREATE TABLE rec_stage.'' || cl.cubo || ''FD DISTKEY(id_auto) AS
SELECT DISTINCT id_auto
FROM rec_stage.'' || cl.nombre_cubo || CHR(10) || '' WHERE ('' || cl.filtro_sql || '')'' AS q_sql
   ,cl.nombre_cubo
   ,cl.cubo
   ,cl.cubo || ''FD'' AS tabla_filtro
FROM concat_list cl
QUALIFY (SUM(1) OVER (PARTITION BY cl.nombre_cubo ORDER BY cl.auto_id DESC ROWS UNBOUNDED PRECEDING)) = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_FD_2');

    -- ------------------------------------------------------------------
    -- Cursor de actualizacion de FILTRO_D (cursor dinamico en el original)
    -- ------------------------------------------------------------------
    FOR r IN EXECUTE 'SELECT tabla_filtro, q_sql, nombre_cubo
                      FROM rec_stage.bacth_fd_2
                      ORDER BY 1, 2' LOOP

        -- Borrado de la tabla <Cubo>FD si existe
        CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.' || r.tabla_filtro);

        -- Creacion de la tabla con los ID_AUTO que cumplen el filtro.
        -- Si q_sql es NULL (cubo no mapeado) el paso falla igual que el original.
        v_sql := REPLACE(r.q_sql, 'P_LOTE', v_lote);
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Crea tabla rec_stage.' || r.tabla_filtro || ';');

        -- UPDATE FILTRO_D = 0
        v_sql := 'UPDATE rec_stage.' || r.nombre_cubo || ' SET filtro_d = 0';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE 0 tabla rec_stage.' || r.nombre_cubo || ';');

        -- UPDATE FILTRO_D = 1 (el CASE del original siempre da 1 por el join)
        v_sql := 'UPDATE rec_stage.' || r.nombre_cubo || '
SET filtro_d = CASE WHEN b.id_auto IS NOT NULL THEN 1 ELSE 0 END
FROM rec_stage.' || r.tabla_filtro || ' b
WHERE ' || r.nombre_cubo || '.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE 1 tabla rec_stage.' || r.nombre_cubo || ';');
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_E -> rec_stage.sp_batch2_filtro_e
-- Fuente: Sps_Batch.sql lineas 1060-1792.
-- Filtro E "datos de contacto compartidos": para el tipo de persona
-- P_TIPOPERSONA ('N' natural / 'J' juridica), numera las filas de cada cubo
-- que comparten el mismo dato (numero / direccion / correo) entre personas
-- de ese tipo y marca FILTRO_E = 1 en las repeticiones que superan el
-- porcentaje configurado en BATCH_PORCENTAJES_FILTROS (PRC_<canal>_P<N|J>).
-- Pasos: BATCH_CUBO_PERSONA_FILTRO_TP (tipo_id por cod_pin), BATCH2_TIPO_PERSONA
-- (tipos de identificacion por tipo de persona, desde VU_PERSONA y
-- V_TIPO_PERSONA), BATCH2_TIPO_PERSONA_F (lista concatenada por recursion),
-- BATCH2_TIPO_PERSONA_PORC (porcentajes del tipo de persona),
-- PRO_BATCH2_FILTRO_E (calculo por fila) y UPDATE de FILTRO_E en los cubos.
-- El BTQ lo llama dos veces: E('N') y luego E('J').
--
-- Calculo por fila (por cubo, sobre las filas de personas del tipo):
--   NUM        = ROW_NUMBER() OVER (PARTITION BY dato, tipo_id de la persona)
--   MAX_NUM    = MAX(NUM) OVER (PARTITION BY dato, PORCE.TIPO_ID)
--   PORCENTAJE_CALCULADO = CAST(PORC_PARAM * MAX_NUM / 100 AS INTEGER)
--   FILTRO     = 1 si NUM <= PORCENTAJE_CALCULADO
--   FLAG       = 1 si PORCENTAJE_CALCULADO > 0 y FILTRO = 0; 0 en los demas
--                casos con PORCENTAJE_CALCULADO >= 0; NULL si es NULL.
--
-- Decisiones de traduccion:
-- - El original referencia alias del mismo SELECT (ID, CANT, MAX_NUM,
--   PORC_PARAM, PORCENTAJE_CALCULADO, FILTRO, TIPO_PERSONA, TIPO_ID): se
--   calculan en subconsultas anidadas (n1..n3).
-- - Las particiones se escriben con expresiones explicitas: en el bloque
--   interno "NUMERO" es el alias del dato (DIRECCION / CORREO) y "TIPO_ID" es
--   TP.TIPO_ID; en el bloque externo "TIPO_ID" solo existe en PORCE
--   (BATCH2_TIPO_PERSONA_PORC.TIPO_ID). Ademas batch_cubo_correo tiene en
--   Redshift una columna (compat) NUMERO que no existe en Teradata: con
--   "PARTITION BY numero" Redshift tomaria esa columna en vez del correo.
-- - CAST(x AS INTEGER) de un decimal: Teradata TRUNCA la parte decimal;
--   Redshift redondea o trunca segun el parametro enable_numeric_rounding
--   (por defecto redondea). Se usa CAST(TRUNC(x) AS INTEGER) para replicar
--   Teradata sin depender de la configuracion del cluster.
-- - TO_NUMBER(PRC_*) -> rec_vista.f_td_to_number(...). El nombre de columna
--   se arma con P_TIPOPERSONA (prc_tel_p || 'N' -> prc_tel_pn), igual que el
--   original.
-- - BATCH2_TIPO_PERSONA y BATCH2_TIPO_PERSONA_F son CREATE TABLE sin
--   MULTISET (tabla SET): ambas salen de un GROUP BY, por lo que sus filas ya
--   son unicas y no se agrega DISTINCT.
-- - CAST(a.Cod_Tipo_Ident_Fte AS VARCHAR(1)): en modo Teradata el CAST a un
--   VARCHAR menor trunca; se escribe LEFT(..., 1) explicito.
-- - Consulta recursiva: el tipo de TIPO_ID lo fija la semilla
--   (VARCHAR(200)); se repite el CAST en el termino recursivo.
-- - PRIMARY INDEX -> DISTKEY de la primera columna del indice; los INDEX
--   secundarios se omiten.
-- - P_BDVISTA.VU_PERSONA -> rec_vista.vu_persona y BDM_VISTA.V_TIPO_PERSONA
--   -> rec_vista.v_tipo_persona. AMBAS SON DEPENDENCIAS EXTERNAS que no
--   existen en el DDL Redshift (ver 07_tablas_dependencias_sps.sql).
-- - El bloque "VALIDA QUE EXISTAN PARAMETROS CONFIGURADOS" esta comentado en
--   el original; no se migra.
-- - En el UNION ALL Teradata toma los tipos de la primera rama (NUMERO
--   VARCHAR(30) trunca direcciones/correos); no tiene efecto porque las
--   ventanas se calculan dentro de cada rama y solo se usan ID_AUTO, FLAG y
--   TIPO. Redshift usa el tipo comun.
-- - Los DROP finales son incondicionales en el original; se conservan igual.
--
-- BUG ORIGINAL REPLICADO (confirmado en el codigo):
-- - La tabla PRO_BATCH2_FILTRO_E se llena con TIPO = 'CUBO_DIRECCIONES' y
--   'CUBO_CELULARES', pero los UPDATE filtran TIPO = 'CUBO_DIRECCION' y
--   'CUBO_CELULAR': en BATCH_CUBO_DIRECCION y BATCH_CUBO_CELULAR FILTRO_E
--   queda SIEMPRE en 0.
-- - Cada llamada pone FILTRO_E = 0 en TODO el cubo antes de marcar las filas
--   de su tipo de persona. Como el BTQ llama E('N') y luego E('J'), la
--   segunda llamada borra las marcas de la primera: al final FILTRO_E solo
--   refleja el calculo de personas juridicas.
-- - Los textos de paso 'Crea Tabla PRO_BATCH2_FILTRO_E' (al crear
--   BATCH_CUBO_PERSONA_FILTRO_TP) y 'Crea Tabla BATCH2_TIPO_PERSONA' (al
--   crear BATCH2_TIPO_PERSONA_F) estan copiados de otro paso; se conservan.
-- - Si un ID_AUTO tiene en PRO_BATCH2_FILTRO_E mas de un FLAG distinto (la
--   persona tiene varios TIPO_ID en el cubo persona), el UPDATE toma uno de
--   forma no determinista en ambos motores.
-- - BATCH2_TIPO_PERSONA y BATCH2_TIPO_PERSONA_F no se borran al final.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_e(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT,
    p_tipo_persona    VARCHAR(1)        -- P_TIPOPERSONA: 'N' | 'J'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql     VARCHAR(65535);
    v_bloque  VARCHAR(65535);
    v_sol     VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla     VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    v_tp      VARCHAR(1)  := p_tipo_persona;
BEGIN
    -- ------------------------------------------------------------------
    -- BATCH_CUBO_PERSONA_FILTRO_TP: tipo de identificacion por cod_pin
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch_cubo_persona_filtro_tp');

    v_sql := 'CREATE TABLE rec_stage.batch_cubo_persona_filtro_tp DISTKEY(cod_pin_persona) AS
SELECT tipo_id, cod_pin_persona
FROM rec_stage.batch_cubo_persona
GROUP BY 1, 2';
    -- Texto de paso del original (copiado de otro paso)
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla PRO_BATCH2_FILTRO_E');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.pro_batch2_filtro_e');

    -- ------------------------------------------------------------------
    -- BATCH2_TIPO_PERSONA: tipos de identificacion de cada tipo de persona
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2_tipo_persona');

    v_sql := 'CREATE TABLE rec_stage.batch2_tipo_persona DISTKEY(cons) AS
SELECT ROW_NUMBER() OVER (PARTITION BY x.tipo_persona ORDER BY x.tipo_persona) AS cons
      ,x.tipo_persona
      ,x.tipo_id
      ,x.tipo_id AS tipo_id_x
FROM (SELECT SUBSTRING(UPPER(b.nombre_tipo_persona), 1, 1) AS tipo_persona
            ,CAST(LEFT(CAST(a.cod_tipo_ident_fte AS VARCHAR(30)), 1) AS VARCHAR(1)) AS tipo_id
      FROM rec_vista.vu_persona a
      LEFT JOIN rec_vista.v_tipo_persona b
        ON a.cod_dw_tipo_persona = b.cod_dw_tipo_persona
      GROUP BY 1, 2) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BATCH2_TIPO_PERSONA');

    -- ------------------------------------------------------------------
    -- BATCH2_TIPO_PERSONA_F: lista concatenada de tipos de identificacion
    -- ('1,3,4') por tipo de persona (consulta recursiva)
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2_tipo_persona_f');

    v_sql := 'CREATE TABLE rec_stage.batch2_tipo_persona_f DISTKEY(tipo_persona) AS
WITH RECURSIVE tipo_personas (tipo_persona, tipo_id, cons) AS
(
  SELECT tipo_persona
        ,CAST(tipo_id AS VARCHAR(200))
        ,cons
  FROM rec_stage.batch2_tipo_persona
  WHERE cons IN (SELECT orden
                 FROM (SELECT tipo_persona, MIN(cons) AS orden
                       FROM rec_stage.batch2_tipo_persona
                       GROUP BY 1) x)
  UNION ALL
  SELECT a.tipo_persona
        ,CAST(b.tipo_id || '','' || TRIM(a.tipo_id) AS VARCHAR(200))
        ,a.cons
  FROM rec_stage.batch2_tipo_persona a
  INNER JOIN tipo_personas b
     ON a.tipo_persona = b.tipo_persona
    AND a.cons = b.cons + 1
)
SELECT tipo_persona
      ,MAX(tipo_id) AS tipo_id
FROM tipo_personas
GROUP BY 1';
    -- Texto de paso del original (repite el del paso anterior)
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BATCH2_TIPO_PERSONA');

    -- ------------------------------------------------------------------
    -- BATCH2_TIPO_PERSONA_PORC: porcentajes del tipo de persona
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2_tipo_persona_porc');

    v_sql := 'CREATE TABLE rec_stage.batch2_tipo_persona_porc DISTKEY(tipo_id) AS
SELECT tp.tipo_persona
      ,tp.tipo_id
      ,rec_vista.f_td_to_number(porc.prc_tel_p'  || v_tp || ') AS tel
      ,rec_vista.f_td_to_number(porc.prc_dir_p'  || v_tp || ') AS dir
      ,rec_vista.f_td_to_number(porc.prc_cel_p'  || v_tp || ') AS cel
      ,rec_vista.f_td_to_number(porc.prc_mail_p' || v_tp || ') AS mail
FROM rec_stage.batch2_tipo_persona_f tp
CROSS JOIN rec_stage.batch_porcentajes_filtros porc
WHERE porc.id_solicitud = ' || v_sol || '
  AND porc.id_plantilla = ' || v_pla || '
  AND tp.tipo_persona = ''' || v_tp || '''';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BATCH2_TIPO_PERSONA_PORC');

    -- ------------------------------------------------------------------
    -- PRO_BATCH2_FILTRO_E: 4 ramas iguales (telefono, direccion, correo,
    -- celular). Plantilla con marcadores #DATO#, #CUBO#, #PORC#, #TIPO#.
    -- n0: bloque interno del original (alias A)
    -- n1: ID, CANT, MAX_NUM, PORC_PARAM (alias del mismo SELECT)
    -- n2: PORCENTAJE, PORCENTAJE_CALCULADO
    -- n3: FILTRO; el SELECT externo calcula FLAG
    -- ------------------------------------------------------------------
    v_bloque := '
SELECT n3.id_auto, n3.numero, n3.cod_pin_persona, n3.tipo_ids, n3.num
      ,n3.id, n3.cant, n3.max_num, n3.porcentaje, n3.porc_param
      ,n3.porcentaje_calculado, n3.filtro
      ,CASE WHEN n3.porcentaje_calculado = 0 AND n3.filtro = 0 THEN 0
            WHEN n3.porcentaje_calculado > 0 AND n3.filtro > 0 THEN 0
            WHEN n3.porcentaje_calculado > 0 AND n3.filtro = 0 THEN 1 END AS flag
      ,CAST(''#TIPO#'' AS CHAR(20)) AS tipo
FROM (
  SELECT n2.*
        ,CASE WHEN n2.num <= n2.porcentaje_calculado THEN 1 ELSE 0 END AS filtro
  FROM (
    SELECT n1.*
          ,n1.cant * 1.0 / n1.max_num * 1.0 * 100.0 AS porcentaje
          ,CAST(TRUNC(n1.porc_param * n1.max_num * 1.0 / 100.0) AS INTEGER) AS porcentaje_calculado
    FROM (
      SELECT a.id_auto, a.numero, a.cod_pin_persona, a.tipo_ids, a.num
            ,CASE WHEN a.num > 1 THEN 2 ELSE NULL END AS id
            ,COUNT(CASE WHEN a.num > 1 THEN 2 ELSE NULL END) OVER (PARTITION BY a.numero, porce.tipo_id) AS cant
            ,MAX(a.num) OVER (PARTITION BY a.numero, porce.tipo_id) AS max_num
            ,porce.#PORC# AS porc_param
      FROM (
        SELECT te.id_auto
              ,te.#DATO# AS numero
              ,te.cod_pin_persona
              ,CAST(tp.tipo_id AS CHAR(1)) AS tipo_ids
              ,ROW_NUMBER() OVER (PARTITION BY te.#DATO#, tp.tipo_id ORDER BY te.#DATO#) AS num
        FROM rec_stage.#CUBO# te
        LEFT JOIN rec_stage.batch_cubo_persona_filtro_tp tp
          ON te.cod_pin_persona = tp.cod_pin_persona
        WHERE te.#DATO# IS NOT NULL
          AND tp.tipo_id IN (SELECT tipo_id_x
                             FROM rec_stage.batch2_tipo_persona
                             WHERE tipo_persona = ''' || v_tp || ''')
      ) a
      CROSS JOIN rec_stage.batch2_tipo_persona_porc porce
    ) n1
  ) n2
) n3';

    -- BUG ORIGINAL REPLICADO: TIPO 'CUBO_DIRECCIONES' y 'CUBO_CELULARES'
    -- no coinciden con los UPDATE de mas abajo.
    v_sql := 'CREATE TABLE rec_stage.pro_batch2_filtro_e DISTKEY(id_auto) AS'
        || REPLACE(REPLACE(REPLACE(REPLACE(v_bloque, '#DATO#', 'numero'),    '#CUBO#', 'batch_cubo_telefono'),  '#PORC#', 'tel'),  '#TIPO#', 'CUBO_TELEFONO')
        || CHR(10) || 'UNION ALL'
        || REPLACE(REPLACE(REPLACE(REPLACE(v_bloque, '#DATO#', 'direccion'), '#CUBO#', 'batch_cubo_direccion'), '#PORC#', 'dir'),  '#TIPO#', 'CUBO_DIRECCIONES')
        || CHR(10) || 'UNION ALL'
        || REPLACE(REPLACE(REPLACE(REPLACE(v_bloque, '#DATO#', 'correo'),    '#CUBO#', 'batch_cubo_correo'),    '#PORC#', 'mail'), '#TIPO#', 'CUBO_CORREO')
        || CHR(10) || 'UNION ALL'
        || REPLACE(REPLACE(REPLACE(REPLACE(v_bloque, '#DATO#', 'numero'),    '#CUBO#', 'batch_cubo_celular'),   '#PORC#', 'cel'),  '#TIPO#', 'CUBO_CELULARES');
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla PRO_BATCH2_FILTRO_E');

    -- ------------------------------------------------------------------
    -- CUBO TELEFONO
    -- BUG ORIGINAL REPLICADO: el reseteo a 0 de todo el cubo borra lo que
    -- marco la llamada anterior (E('N') antes de E('J')).
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_telefono SET filtro_e = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_TELEFONO FILTRO_E = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET filtro_e = b.flag
FROM (SELECT id_auto AS id_auto_up, flag
      FROM rec_stage.pro_batch2_filtro_e
      WHERE tipo = ''CUBO_TELEFONO''
      GROUP BY 1, 2) b
WHERE batch_cubo_telefono.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         v_tp || ' Act.  CUBO_TELEFONO Campo FILTRO_E');

    -- ------------------------------------------------------------------
    -- CUBO CELULAR (BUG ORIGINAL REPLICADO: ninguna fila tiene TIPO = 'CUBO_CELULAR')
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_celular SET filtro_e = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CELULAR FILTRO_E = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET filtro_e = b.flag
FROM (SELECT id_auto AS id_auto_up, flag
      FROM rec_stage.pro_batch2_filtro_e
      WHERE tipo = ''CUBO_CELULAR''
      GROUP BY 1, 2) b
WHERE batch_cubo_celular.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         v_tp || ' Act.  CUBO_CELULAR Campo FILTRO_E');

    -- ------------------------------------------------------------------
    -- CUBO DIRECCION (BUG ORIGINAL REPLICADO: ninguna fila tiene TIPO = 'CUBO_DIRECCION')
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_direccion SET filtro_e = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_E = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET filtro_e = b.flag
FROM (SELECT id_auto AS id_auto_up, flag
      FROM rec_stage.pro_batch2_filtro_e
      WHERE tipo = ''CUBO_DIRECCION''
      GROUP BY 1, 2) b
WHERE batch_cubo_direccion.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         v_tp || ' Act.  CUBO_DIRECCION Campo FILTRO_E');

    -- ------------------------------------------------------------------
    -- CUBO CORREO
    -- ------------------------------------------------------------------
    v_sql := 'UPDATE rec_stage.batch_cubo_correo SET filtro_e = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Actualizando  Tabla BATCH_CUBO_CORREO FILTRO_E = 0');

    v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET filtro_e = b.flag
FROM (SELECT id_auto AS id_auto_up, flag
      FROM rec_stage.pro_batch2_filtro_e
      WHERE tipo = ''CUBO_CORREO''
      GROUP BY 1, 2) b
WHERE batch_cubo_correo.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         v_tp || ' Act.  CUBO_CORREO Campo FILTRO_E');

    -- ------------------------------------------------------------------
    -- Borrar tablas temporales (incondicional, igual que el original)
    -- ------------------------------------------------------------------
    v_sql := 'DROP TABLE rec_stage.pro_batch2_filtro_e';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE PRO_BATCH2_FILTRO_E');

    v_sql := 'DROP TABLE rec_stage.batch_cubo_persona_filtro_tp';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE BATCH_CUBO_PERSONA_FILTRO_TP');

    v_sql := 'DROP TABLE rec_stage.batch2_tipo_persona_porc';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE BATCH2_TIPO_PERSONA_PORC');
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_F -> rec_stage.sp_batch2_filtro_f
-- Fuente: Sps_Batch.sql lineas 1793-2907.
-- Filtro F "similitud con el insumo del suscriptor": compara cada dato de
-- contacto de los cubos (direccion, telefono, celular, correo) con el dato
-- que envio el suscriptor en STG_INSUMO_BATCH_VALIDACION para la misma
-- persona (TIPO_ID + NUMERO_ID -> COD_PIN_PERSONA), toma la mejor similitud
-- por registro del cubo y marca FILTRO_F = 0 si la similitud alcanza el
-- minimo PMD_<canal> de BATCH_PORCENTAJES_FILTROS, 1 si no. Tambien guarda la
-- similitud en POR_SIM_DIR / POR_SIM_TEL / POR_SIM_CEL / POR_SIM_MAIL.
-- Pasos: FILTRO_CLIENTE_1 (personas del cubo), FILTRO_<canal>_2 (insumo por
-- persona), FILTRO_3_<canal> (similitud por par cubo-insumo y ranking),
-- FILTRO_4_RES (mejor par y FLAG, los 4 canales) y UPDATE de cada cubo.
--
-- Similitud por canal (UDF Teradata -> Lambda UDF de 08_funciones_udf.sql):
--   Direccion: Bach_Similitud_Dir_MZ (10 args) y PorcSimilitud (cadena mas
--              larga, cadena mas corta), combinadas con el CASE original.
--   Telefono / celular: Bach_Similitud_Tel(numero_cubo, numero_insumo).
--   Correo: Bach_Similitud_email (14 args: buzon/dominio y su SOUNDEX de
--           insumo y bodega + 6 pesos), tope 100.
--   Las firmas declaradas en 08_funciones_udf.sql coinciden con las llamadas
--   originales (numero y tipo de argumentos). La logica de las 4 UDF se
--   porto del C (FuncionesUDF/) a una Lambda (Redshift/lambda/udf_similitud).
--   PorcSimilitud declara VARCHAR(20) en Teradata: aunque aqui recibe
--   direcciones completas, solo compara sus 20 primeros caracteres (la
--   Lambda replica ese truncamiento).
--
-- Decisiones de traduccion:
-- - El original encadena alias del mismo SELECT (DirInsumoIn, VALTAM, SIMIL,
--   PORCSIMIL, SIMILITUD, CADENA_BOD, arroba_bod, BuzonBod, ...): se calculan
--   en subconsultas anidadas. Cada UDF se evalua una vez por fila.
-- - CHAR(x) en Teradata es CHARACTER_LENGTH (no el tipo CHAR) -> LEN.
--   CHARS(x) -> LEN.
-- - CAST(PorcSimilitud(...) AS INTEGER): Teradata trunca la parte decimal;
--   Redshift redondea o trunca segun enable_numeric_rounding. Se usa
--   CAST(TRUNC(...) AS INTEGER).
-- - ORDER BY SIMILITUD DESC: Teradata ordena NULL como el valor mas bajo
--   (ultimo en DESC); Redshift por defecto pone NULL primero en DESC. Se
--   agrega NULLS LAST.
-- - TRANSLATE(x USING UNICODE_TO_LATIN) es conversion de juego de caracteres
--   de Teradata; en Redshift (UTF-8) no aplica y se omite. SOUNDEX y
--   REGEXP_REPLACE existen en Redshift. El REGEXP_REPLACE deja solo letras
--   a-z/A-Z, por lo que SOUNDEX recibe solo ASCII en ambos motores.
-- - eListGetValByIdx(x,'@',2) -> NULLIF(SPLIT_PART(x,'@',2),''): se asume que
--   la UDF Teradata devolvia NULL si no hay segundo elemento (mismo criterio
--   que 07_homologaciones.sql).
-- - TO_NUMBER(PMD_*) -> rec_vista.f_td_to_number(...).
-- - CAST(NUMERO_ID AS BIGINT) -> CAST(TRIM(numero_id) AS BIGINT).
-- - Las tablas de trabajo son MULTISET en el original: sin DISTINCT. Los
--   GROUP BY 1,2,3 del original se conservan.
-- - PRIMARY INDEX -> DISTKEY de la primera columna; INDEX secundarios se
--   omiten.
-- - Validacion inicial: si STG_INSUMO_BATCH_VALIDACION esta vacia, el
--   original ejecuta 'DELETE ... STG_INSUMO_BATCH_VALIDACION' (sin efecto)
--   solo para dejar el paso 'NO HAY DATOS FILTRO #F' en el log, y CONTINUA
--   (el LEAVE L1 esta comentado). Se replica igual.
-- - Alias igual a columna: en FILTRO_4_RES el original define el alias
--   SIMILITUD (CASE WHEN SIMILITUD >= 0 ...) y luego compara
--   "SIMILITUD >= PMD". Teradata resuelve primero nombres de columna y solo
--   busca en los alias si la columna no existe, asi que se usa la columna de
--   FILTRO_3_* (valor sin acotar a 0), igual que el original.
--
-- Comportamientos / bugs del original que se conservan:
-- - FILTRO_F NO se pone en 0 antes de actualizar: los registros sin insumo
--   comparable (persona sin dato del suscriptor) conservan el FILTRO_F y
--   POR_SIM_* que traian (normalmente NULL). FILTRO_H usa COALESCE(...,0).
-- - Si no hay fila en BATCH_PORCENTAJES_FILTROS para la solicitud/plantilla,
--   el producto cartesiano con FIL no genera filas y no se actualiza nada.
--   Si hay mas de una, se duplican filas y el UPDATE toma una de forma no
--   determinista.
-- - Si PMD_<canal> es NULL o no numerico, "SIMILITUD >= NULL" es
--   desconocido y FLAG = 1 (el dato queda filtrado).
-- - SUBSTR(CADENA,1,arroba-1) con un correo del cubo sin '@' falla en ambos
--   motores (Teradata error 2663; Redshift largo negativo).
-- - CAST(NUMERO_ID AS BIGINT) sin proteccion: un NUMERO_ID no numerico en el
--   cubo persona o en el insumo hace fallar el paso, igual que el original.
-- - Los DROP finales son incondicionales.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_f(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql      VARCHAR(65535);
    v_sol      VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla      VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    v_cuantos  BIGINT;
BEGIN
    -- ------------------------------------------------------------------
    -- Validacion: insumo vacio -> deja constancia en el log y continua
    -- ------------------------------------------------------------------
    SELECT COUNT(*) INTO v_cuantos
    FROM rec_stage.stg_insumo_batch_validacion;

    IF v_cuantos = 0 THEN
        v_sql := 'DELETE FROM rec_stage.stg_insumo_batch_validacion';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'NO HAY DATOS FILTRO #F');
    END IF;

    -- ------------------------------------------------------------------
    -- FILTRO_CLIENTE_1: personas del cubo
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_cliente_1');

    v_sql := 'CREATE TABLE rec_stage.filtro_cliente_1 DISTKEY(cod_pin_persona) AS
SELECT tipo_id
      ,CAST(TRIM(numero_id) AS BIGINT) AS numero_id   /*#3 casteo a bigint*/
      ,cod_pin_persona
FROM rec_stage.batch_cubo_persona
GROUP BY 1, 2, 3';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_CLIENTE_1 F');

    -- ==================================================================
    -- CUBO DIRECCION
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_dir_2');

    v_sql := 'CREATE TABLE rec_stage.filtro_dir_2 DISTKEY(cod_pin_persona) AS
SELECT bo.cod_pin_persona
      ,cl.dir_insumo_std_000 AS dir_insumo_std
      ,cl.numero_id
FROM rec_stage.filtro_cliente_1 bo
LEFT JOIN rec_stage.stg_insumo_batch_validacion cl
  ON cl.tipo_id = bo.tipo_id
 AND CAST(TRIM(cl.numero_id) AS BIGINT) = bo.numero_id   /*#3 casteo a bigint*/
WHERE cl.dir_insumo_std_000 IS NOT NULL
GROUP BY 1, 2, 3';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_DIR_2 F');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_3_calc');

    -- t: datos base y pesos; u: UDF (SIMIL, PORCSIMIL); s: SIMILITUD; externo: ranking
    v_sql := 'CREATE TABLE rec_stage.filtro_3_calc DISTKEY(id_auto) AS
SELECT s.id_auto
      ,s.cod_pin_persona
      ,s.direccion
      ,s.dir_insumo_std
      ,s.dirinsumoin
      ,s.dirbodegain
      ,s.porhitmz0in
      ,s.pordismz0in
      ,s.porhitmz1in
      ,s.pordismz1in
      ,s.porhitmz2in
      ,s.pordismz2in
      ,s.porhitmz3in
      ,s.pordismz3in
      ,s.similitud
      ,ROW_NUMBER() OVER (PARTITION BY s.id_auto ORDER BY s.similitud DESC NULLS LAST) AS id
FROM (
  SELECT u.*
        ,CASE WHEN u.dirinsumoin = u.dirbodegain THEN 100
              WHEN u.simil BETWEEN 55 AND 100 THEN u.simil
              WHEN u.simil BETWEEN 101 AND 160 AND u.dirinsumoin <> u.dirbodegain AND u.porcsimil > 50 THEN u.porcsimil
              WHEN u.simil BETWEEN 101 AND 160 AND u.dirinsumoin <> u.dirbodegain AND u.porcsimil <= 50 THEN u.simil - 62
              WHEN u.simil > 160 THEN u.porcsimil
              WHEN u.porcsimil > u.simil AND u.porcsimil > 75 AND u.simil BETWEEN 0 AND 54 THEN u.porcsimil
              WHEN u.simil < 0 THEN 0
              ELSE u.simil
         END AS similitud
  FROM (
    SELECT t.*
          ,rec_vista.f_bach_similitud_dir_mz(t.dirinsumoin
                                            ,t.dirbodegain
                                            ,t.porhitmz0in
                                            ,t.pordismz0in
                                            ,t.porhitmz1in
                                            ,t.pordismz1in
                                            ,t.porhitmz2in
                                            ,t.pordismz2in
                                            ,t.porhitmz3in
                                            ,t.pordismz3in) AS simil
          ,CAST(TRUNC(rec_vista.f_porc_similitud(
                   CASE WHEN t.valtam = 1 THEN t.dirbodegain ELSE t.dirinsumoin END
                  ,CASE WHEN t.valtam = 1 THEN t.dirinsumoin ELSE t.dirbodegain END)) AS INTEGER) AS porcsimil
    FROM (
      SELECT dir.id_auto
            ,dir.cod_pin_persona
            ,dir.direccion
            ,cj.dir_insumo_std
            ,TRIM(cj.dir_insumo_std) AS dirinsumoin
            ,TRIM(dir.direccion) AS dirbodegain
            ,CASE WHEN LEN(TRIM(cj.dir_insumo_std)) <= LEN(TRIM(dir.direccion)) THEN 1 ELSE 2 END AS valtam
            ,0   AS porhitmz0in
            ,100 AS pordismz0in
            ,20  AS porhitmz1in
            ,80  AS pordismz1in
            ,50  AS porhitmz2in
            ,50  AS pordismz2in
            ,70  AS porhitmz3in
            ,30  AS pordismz3in
      FROM rec_stage.batch_cubo_direccion dir
      CROSS JOIN rec_stage.filtro_dir_2 cj
      WHERE dir.cod_pin_persona = cj.cod_pin_persona
        AND dir.direccion IS NOT NULL
        /*AND DIR.TIPO= ''LAB'' #3 Se elimina filtro por solicitud de Mauricio Marin*/
    ) t
  ) u
) s';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_3_CALC F');

    -- FILTRO_4_RES: tabla de resultados de los 4 canales
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_4_res');

    v_sql := 'CREATE TABLE rec_stage.filtro_4_res DISTKEY(id_auto) AS
SELECT c.id_auto
      ,c.cod_pin_persona
      ,c.direccion AS texto_cubo
      ,c.dir_insumo_std AS texto_cliente
      ,CASE WHEN c.similitud >= 0 THEN c.similitud ELSE 0 END AS similitud
      ,CASE WHEN c.similitud >= fil.pmd_dir THEN 0 ELSE 1 END AS flag
      ,CAST(''CUBO_DIRECCION'' AS CHAR(30)) AS cubo
FROM rec_stage.filtro_3_calc c
CROSS JOIN (SELECT rec_vista.f_td_to_number(pmd_dir) AS pmd_dir
            FROM rec_stage.batch_porcentajes_filtros
            WHERE id_solicitud = ' || v_sol || '
              AND id_plantilla = ' || v_pla || ') fil
WHERE c.id = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_4_RES F');

    -- ==================================================================
    -- CUBO TELEFONO
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_tel_2');

    v_sql := 'CREATE TABLE rec_stage.filtro_tel_2 DISTKEY(cod_pin_persona) AS
SELECT bo.cod_pin_persona
      ,cl.tel_insumo_std_000 AS telefono
      ,cl.numero_id
FROM rec_stage.filtro_cliente_1 bo
LEFT JOIN rec_stage.stg_insumo_batch_validacion cl
  ON cl.tipo_id = bo.tipo_id
 AND CAST(TRIM(cl.numero_id) AS BIGINT) = bo.numero_id   /*#3 casteo a bigint*/
WHERE cl.tel_insumo_std_000 IS NOT NULL
GROUP BY 1, 2, 3';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_TEL_2 F');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_3_calt');

    v_sql := 'CREATE TABLE rec_stage.filtro_3_calt DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.numero
      ,x.telefono
      ,x.similitud
      ,ROW_NUMBER() OVER (PARTITION BY x.id_auto ORDER BY x.similitud DESC NULLS LAST) AS id
FROM (SELECT dir.id_auto
            ,dir.cod_pin_persona
            ,dir.numero
            ,cj.telefono
            ,rec_vista.f_bach_similitud_tel(dir.numero, cj.telefono) AS similitud
      FROM rec_stage.batch_cubo_telefono dir
      CROSS JOIN rec_stage.filtro_tel_2 cj
      WHERE dir.cod_pin_persona = cj.cod_pin_persona
        AND dir.numero IS NOT NULL
        /*AND DIR.TIPO =''TELEFONO'' #3 se elimina filtro por solicitud de Mauricio Marin*/
     ) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_3_CALT F');

    v_sql := 'INSERT INTO rec_stage.filtro_4_res
SELECT c.id_auto
      ,c.cod_pin_persona
      ,c.numero AS texto_cubo
      ,c.telefono AS texto_cliente
      ,CASE WHEN c.similitud >= 0 THEN c.similitud ELSE 0 END AS similitud
      ,CASE WHEN c.similitud >= fil.pmd_tel THEN 0 ELSE 1 END AS flag
      ,CAST(''CUBO_TELEFONO'' AS CHAR(30)) AS cubo
FROM rec_stage.filtro_3_calt c
CROSS JOIN (SELECT rec_vista.f_td_to_number(pmd_tel) AS pmd_tel
            FROM rec_stage.batch_porcentajes_filtros
            WHERE id_solicitud = ' || v_sol || '
              AND id_plantilla = ' || v_pla || ') fil
WHERE c.id = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Inserta  FILTRO_4_RES F');

    -- ==================================================================
    -- CUBO CELULAR
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_cel_2');

    v_sql := 'CREATE TABLE rec_stage.filtro_cel_2 DISTKEY(cod_pin_persona) AS
SELECT bo.cod_pin_persona
      ,cl.cel_insumo_std_000 AS celular
      ,cl.numero_id
FROM rec_stage.filtro_cliente_1 bo
LEFT JOIN rec_stage.stg_insumo_batch_validacion cl
  ON cl.tipo_id = bo.tipo_id
 AND CAST(TRIM(cl.numero_id) AS BIGINT) = bo.numero_id   /*#3 casteo a bigint*/
WHERE cl.cel_insumo_std_000 IS NOT NULL
GROUP BY 1, 2, 3';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_CEL_2 F');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_3_calcel');

    v_sql := 'CREATE TABLE rec_stage.filtro_3_calcel DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.numero
      ,x.celular
      ,x.similitud
      ,ROW_NUMBER() OVER (PARTITION BY x.id_auto ORDER BY x.similitud DESC NULLS LAST) AS id
FROM (SELECT dir.id_auto
            ,dir.cod_pin_persona
            ,dir.numero
            ,cj.celular
            ,rec_vista.f_bach_similitud_tel(dir.numero, cj.celular) AS similitud
      FROM rec_stage.batch_cubo_celular dir
      CROSS JOIN rec_stage.filtro_cel_2 cj
      WHERE dir.cod_pin_persona = cj.cod_pin_persona
        AND dir.numero IS NOT NULL
     ) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_3_CALCEL F');

    v_sql := 'INSERT INTO rec_stage.filtro_4_res
SELECT c.id_auto
      ,c.cod_pin_persona
      ,c.numero AS texto_cubo
      ,c.celular AS texto_cliente
      ,CASE WHEN c.similitud >= 0 THEN c.similitud ELSE 0 END AS similitud
      ,CASE WHEN c.similitud >= fil.pmd_cel THEN 0 ELSE 1 END AS flag
      ,CAST(''CUBO_CELULAR'' AS CHAR(30)) AS cubo
FROM rec_stage.filtro_3_calcel c
CROSS JOIN (SELECT rec_vista.f_td_to_number(pmd_cel) AS pmd_cel
            FROM rec_stage.batch_porcentajes_filtros
            WHERE id_solicitud = ' || v_sol || '
              AND id_plantilla = ' || v_pla || ') fil
WHERE c.id = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Inserta  FILTRO_4_RES F');

    -- ==================================================================
    -- CUBO CORREO
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_mail_2');

    v_sql := 'CREATE TABLE rec_stage.filtro_mail_2 DISTKEY(cod_pin_persona) AS
SELECT bo.cod_pin_persona
      ,cl.email_insumo_std_000 AS mail
      ,cl.numero_id
FROM rec_stage.filtro_cliente_1 bo
LEFT JOIN rec_stage.stg_insumo_batch_validacion cl
  ON cl.tipo_id = bo.tipo_id
 AND CAST(TRIM(cl.numero_id) AS BIGINT) = bo.numero_id   /*#3 casteo a bigint*/
WHERE cl.email_insumo_std_000 IS NOT NULL
  AND cl.email_insumo_std_000 LIKE ''%@%''
GROUP BY 1, 2, 3';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_MAIL_2 F');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.filtro_3_cal_mail');

    -- w0: cadenas; x: largo y posicion de @; y: buzon/dominio;
    -- z: parametros de la UDF; w: UDF; v: tope 100; externo: ranking
    v_sql := 'CREATE TABLE rec_stage.filtro_3_cal_mail DISTKEY(id_auto) AS
SELECT v.*
      ,ROW_NUMBER() OVER (PARTITION BY v.id_auto ORDER BY v.similitudx DESC NULLS LAST) AS id
FROM (
 SELECT w.*
       ,CASE WHEN w.similitud > 100 THEN 100 ELSE w.similitud END AS similitudx
 FROM (
  SELECT z.*
        ,rec_vista.f_bach_similitud_email(z.buzoninsumoin
                                         ,z.dominioinsumoin
                                         ,z.sounbuzinsin
                                         ,z.soundominsin
                                         ,z.buzonbodegain
                                         ,z.dominiobodegain
                                         ,z.sounbuzbodin
                                         ,z.soundombodin
                                         ,z.porbzin
                                         ,z.porbzsounin
                                         ,z.porbzdistin
                                         ,z.pordomin
                                         ,z.pordomsounin
                                         ,z.pordomdistin) AS similitud
  FROM (
   SELECT y.*
         ,y.buzonins   AS buzoninsumoin
         ,y.dominioins AS dominioinsumoin
         ,SOUNDEX(REGEXP_REPLACE(y.buzonins,   ''[^a-zA-Z]'', '''')) AS sounbuzinsin
         ,SOUNDEX(REGEXP_REPLACE(y.dominioins, ''[^a-zA-Z]'', '''')) AS soundominsin
         ,y.buzonbod   AS buzonbodegain
         ,y.dominiobod AS dominiobodegain
         ,SOUNDEX(REGEXP_REPLACE(y.buzonbod,   ''[^a-zA-Z]'', '''')) AS sounbuzbodin
         ,SOUNDEX(REGEXP_REPLACE(y.dominiobod, ''[^a-zA-Z]'', '''')) AS soundombodin
         ,70 AS porbzin
         ,50 AS porbzsounin
         ,50 AS porbzdistin
         ,30 AS pordomin
         ,50 AS pordomsounin
         ,50 AS pordomdistin
   FROM (
    SELECT x.*
          ,POSITION(''.'' IN SUBSTRING(x.cadena_bod, x.arroba_bod + 1, x.ancho_bod)) AS pospunto_bod
          ,SUBSTRING(x.cadena_bod, 1, x.arroba_bod - 1) AS buzonbod
          ,NULLIF(SPLIT_PART(x.cadena_bod, ''@'', 2), '''') AS dominiobod
          ,POSITION(''.'' IN SUBSTRING(x.cadena_ins, x.arroba_ins + 1, x.ancho_ins)) AS pospunto_ins
          ,SUBSTRING(x.cadena_ins, 1, x.arroba_ins - 1) AS buzonins
          ,NULLIF(SPLIT_PART(x.cadena_ins, ''@'', 2), '''') AS dominioins
    FROM (
     SELECT w0.*
           ,LEN(w0.cadena_bod) AS ancho_bod
           ,POSITION(''@'' IN w0.cadena_bod) AS arroba_bod
           ,LEN(w0.cadena_ins) AS ancho_ins
           ,POSITION(''@'' IN w0.cadena_ins) AS arroba_ins
     FROM (SELECT dir.id_auto
                 ,dir.cod_pin_persona
                 ,dir.correo
                 ,cj.mail
                 ,UPPER(TRIM(dir.correo)) AS cadena_bod
                 ,UPPER(TRIM(cj.mail))    AS cadena_ins
           FROM rec_stage.batch_cubo_correo dir
           CROSS JOIN rec_stage.filtro_mail_2 cj
           WHERE dir.cod_pin_persona = cj.cod_pin_persona
             AND dir.correo IS NOT NULL) w0
    ) x
   ) y
  ) z
 ) w
) v';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea FILTRO_3_CAL_MAIL F');

    v_sql := 'INSERT INTO rec_stage.filtro_4_res
SELECT c.id_auto
      ,c.cod_pin_persona
      ,c.correo AS texto_cubo
      ,c.mail AS texto_cliente
      ,CASE WHEN c.similitudx >= 0 THEN c.similitudx ELSE 0 END AS similitudx
      ,CASE WHEN c.similitudx >= fil.pmd_mail THEN 0 ELSE 1 END AS flag
      ,CAST(''CUBO_CORREO'' AS CHAR(30)) AS cubo
FROM rec_stage.filtro_3_cal_mail c
CROSS JOIN (SELECT rec_vista.f_td_to_number(pmd_mail) AS pmd_mail
            FROM rec_stage.batch_porcentajes_filtros
            WHERE id_solicitud = ' || v_sol || '
              AND id_plantilla = ' || v_pla || ') fil
WHERE c.id = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Inserta  FILTRO_4_RES F');

    -- ==================================================================
    -- UPDATE de los cubos (sin reseteo previo de FILTRO_F, igual que el original)
    -- ==================================================================
    v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET filtro_f    = b.flag
   ,por_sim_tel = b.similitud
FROM (SELECT id_auto AS id_auto_up, similitud, flag
      FROM rec_stage.filtro_4_res
      WHERE cubo = ''CUBO_TELEFONO''
      GROUP BY 1, 2, 3) b
WHERE batch_cubo_telefono.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, ' Act.  CUBO_TELEFONO Campo FILTRO_F');

    v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET filtro_f    = b.flag
   ,por_sim_cel = b.similitud
FROM (SELECT id_auto AS id_auto_up, similitud, flag
      FROM rec_stage.filtro_4_res
      WHERE cubo = ''CUBO_CELULAR''
      GROUP BY 1, 2, 3) b
WHERE batch_cubo_celular.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, ' Act.  CUBO_CELULAR Campo FILTRO_F');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET filtro_f    = b.flag
   ,por_sim_dir = b.similitud
FROM (SELECT id_auto AS id_auto_up, similitud, flag
      FROM rec_stage.filtro_4_res
      WHERE cubo = ''CUBO_DIRECCION''
      GROUP BY 1, 2, 3) b
WHERE batch_cubo_direccion.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, ' Act.  CUBO_DIRECCION Campo FILTRO_F');

    v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET filtro_f     = b.flag
   ,por_sim_mail = b.similitud
FROM (SELECT id_auto AS id_auto_up, similitud, flag
      FROM rec_stage.filtro_4_res
      WHERE cubo = ''CUBO_CORREO''
      GROUP BY 1, 2, 3) b
WHERE batch_cubo_correo.id_auto = b.id_auto_up';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, ' Act.  CUBO_CORREO Campo FILTRO_F');

    -- ==================================================================
    -- Borrar tablas temporales (incondicional, igual que el original)
    -- ==================================================================
    v_sql := 'DROP TABLE rec_stage.filtro_cliente_1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_CLIENTE_1');
    v_sql := 'DROP TABLE rec_stage.filtro_dir_2';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_DIR_2');
    v_sql := 'DROP TABLE rec_stage.filtro_3_calc';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_3_CALC');
    v_sql := 'DROP TABLE rec_stage.filtro_4_res';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_4_RES');
    v_sql := 'DROP TABLE rec_stage.filtro_tel_2';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_TEL_2');
    v_sql := 'DROP TABLE rec_stage.filtro_3_calt';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_3_CALT');
    v_sql := 'DROP TABLE rec_stage.filtro_cel_2';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_CEL_2');
    v_sql := 'DROP TABLE rec_stage.filtro_3_calcel';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_3_CALCEL');
    v_sql := 'DROP TABLE rec_stage.filtro_mail_2';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_MAIL_2');
    v_sql := 'DROP TABLE rec_stage.filtro_3_cal_mail';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'DROP TABLE FILTRO_3_CAL_MAIL');
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_G -> rec_stage.sp_batch2_filtro_g
-- Fuente: Sps_Batch.sql lineas 2908-3529.
-- Filtro G "Datos activos a exportar": limita la cantidad de registros por
-- persona en cada canal (telefono, celular, correo, direccion, ciiu, punto de
-- interes) segun BATCH_SALIDAS_CAMPOS.MINIMO_REQUERIDO_CAMPO y
-- CANTIDAD_MAX_CAMPO de la solicitud/plantilla.
-- Pasos: BACTH_FG_1 (una fila por campo/cubo con el CREATE TABLE BACTH_FG_2
-- generado a partir de BATCH2_HOMOLOGACION.HOMOLOGADO), FILTRO_G = 1 en los
-- cubos presentes en BACTH_FG_1, y un cursor (ORDER BY ID) que por cada fila
-- crea BACTH_FG_2 (ID_AUTO, ID_BURO_PERSONA, CANT_CAMPO, C_UPDATE) y copia
-- C_UPDATE a FILTRO_G. C_UPDATE = 0 (se conserva) si la posicion CANT_CAMPO
-- del registro dentro de la persona esta entre el minimo y el maximo, 1 si
-- no, y 1 siempre si el cubo no tiene campos en la seccion '%CON DATOS%'.
--
-- Decisiones de traduccion:
-- - Se conserva el mecanismo dinamico: el nombre de la columna (HOMOLOGADO),
--   el cubo y los limites min/max se concatenan en el texto SQL_STRING de
--   BACTH_FG_1 y el cursor lo ejecuta (FOR r IN EXECUTE ... LOOP).
-- - BACTH_FG_1 y BACTH_FG_2 se crean en el original con CREATE TABLE sin
--   MULTISET (tabla SET, elimina duplicados): se usa SELECT DISTINCT en
--   ambas. Sin PRIMARY INDEX explicito (PI = primera columna) ->
--   DISTKEY(id) / DISTKEY(id_auto).
-- - En BACTH_FG_1 el original usa el alias NOMBRE_CUBO dentro del mismo
--   SELECT y en el ON del join; se calcula en una subconsulta (x) y el
--   filtro "NOMBRE_CUBO <> 'BATCH_CUBO_PERSONA'" pasa al WHERE externo
--   (equivalente en INNER JOIN; tambien excluye NOMBRE_CUBO NULL).
-- - SQL generado: el original referencia el alias CANT_CAMPO (funcion de
--   ventana) dentro del DECODE del mismo SELECT; se calcula en una
--   subconsulta (z). DECODE(Y.NOMBRE_CUBO,NULL,1,...) -> CASE WHEN ... IS
--   NULL (DECODE trata NULL = NULL). EQ/NE -> = / <>. NVL se conserva.
-- - Cubo Ciiu: el original usa SUM(1) OVER (PARTITION BY ID_BURO_PERSONA
--   ROWS UNBOUNDED PRECEDING) SIN ORDER BY (conteo acumulado en orden no
--   determinista). Se traduce a ROW_NUMBER() OVER (PARTITION BY
--   id_buro_persona), mismo resultado y mismo no determinismo; Redshift no
--   garantiza aceptar el marco ROWS sin ORDER BY.
-- - Orden de NULL: Teradata ordena NULL como el valor mas bajo (ASC: primero,
--   DESC: ultimo); Redshift por defecto hace lo contrario. En los ORDER BY
--   de las ventanas sobre columnas que pueden ser NULL se agrega
--   NULLS FIRST (ASC) / NULLS LAST (DESC) para replicar Teradata. Las
--   columnas envueltas en NVL no lo necesitan.
-- - Ramas muertas omitidas en el SQL generado: dentro de la rama CUBO='Ciiu'
--   el original evalua CASE NOMBRE_CUBO con ramas PUNTO_INTERES/ELSE que
--   nunca se cumplen (NOMBRE_CUBO siempre es BATCH_CUBO_CIIU); y en la rama
--   ELSE el QUALIFY tiene una rama CIIU inalcanzable. Se omiten.
-- - TRIM(ZEROIFNULL(TO_NUMBER(MINIMO_REQUERIDO_CAMPO))) ->
--   TRIM(CAST(COALESCE(rec_vista.f_td_to_number(...),0) AS VARCHAR(50)));
--   el literal queda con decimales (p. ej. '3.0000000000'), mismo valor
--   numerico en el BETWEEN. TRIM(CANTIDAD_MAX_CAMPO) -> CAST explicito.
-- - SELECT NOMBRE_CUBO INTO :V_CADENA FROM BACTH_FG_1 WHERE NOMBRE_CUBO=...:
--   en Teradata 0 filas deja V_CADENA = '' (no actualiza) y mas de 1 fila
--   aborta el SP (error 7627 "SELECT-INTO returned more than one row", el
--   BTQ sale por Errorcode <> 0). Se replica con COUNT(*) estatico:
--   0 -> no actualiza, 1 -> actualiza, >1 -> RAISE EXCEPTION (sin log en
--   LOG_TD_DETALLE, igual que el original). Ocurre si un CODIGO_CAMPO del
--   cubo aparece en varias filas de BATCH_SALIDAS_CAMPOS (p. ej. en varias
--   secciones) con distinto MIN/MAX, o hay varias homologaciones del codigo.
-- - REGEXP_REPLACE de 'REC_STAGE' -> P_BDSTAGE y 'REC_VISTA' -> P_BDVISTA
--   se eliminan (esquemas fijos, el SQL generado ya usa rec_stage). Se
--   conserva REPLACE(...,'P_LOTE',lote) aunque el texto no lo contiene.
-- - El paso de log de 'Crea tabla' contiene todo el SQL generado (igual que
--   el original); se pasa con LEFT(...,500) porque es el ancho de
--   log_td_detalle.paso (sp_execstring_des ya trunca a 500).
-- - Los ';' finales de las sentencias del original se eliminan.
-- - SET P_ERROR = V_CADENA (sin efecto) se elimina.
--
-- Comportamientos / bugs del original que se conservan:
-- - BUG ORIGINAL REPLICADO: en cada iteracion del cursor el UPDATE de
--   FILTRO_G desde BACTH_FG_2 se ejecuta sobre los 6 cubos (TELEFONO,
--   DIRECCION, CELULAR, CORREO, CIIU, PUNTO_INTERES_DIR) con nombres fijos,
--   no solo sobre V_NOMBRE_CUBO (que solo se usa en el texto del paso).
--   BACTH_FG_2 tiene los ID_AUTO del cubo de la fila actual; si ID_AUTO
--   coincide entre cubos, el FILTRO_G de otros cubos se sobrescribe con el
--   C_UPDATE de un registro ajeno. Gana la ultima iteracion (ORDER BY ID)
--   cuyo BACTH_FG_2 contenga ese ID_AUTO. Afecta incluso a cubos sin campo
--   configurado (su FILTRO_G puede pasar de NULL a 0/1). FILTRO_H usa
--   COALESCE(filtro_g,0), asi que la contaminacion puede excluir o incluir
--   registros en la salida.
-- - BUG ORIGINAL REPLICADO: los 6 pasos de log del UPDATE dicen todos
--   'UPDATE FILTRO G TABLA <stage>.<V_NOMBRE_CUBO> CAMPO BACTH_FG_2;' aunque
--   cada uno actualiza otra tabla.
-- - El paso del UPDATE inicial de direccion dice 'UPDATE FILTRO G=0
--   BATCH_CUBO_DIRECCION' aunque asigna 1; se conserva el texto.
-- - Registros que no entran a BACTH_FG_2 (duplicados eliminados por el
--   QUALIFY, o direcciones con algun filtro A..F marcado) conservan
--   FILTRO_G = 1 del UPDATE inicial (salvo contaminacion por el bug).
-- - MINIMO_REQUERIDO_CAMPO se aplica como limite inferior de la posicion
--   CANT_CAMPO (CANT_CAMPO BETWEEN min AND max): con min = 3 se excluyen
--   las 2 primeras filas de cada persona, no las personas con menos de 3
--   registros como dice el comentario del original. Se replica tal cual.
-- - Si HOMOLOGADO es NULL, SQL_STRING es NULL y el paso 'Crea tabla' falla
--   (EXECUTE de texto NULL), igual que el original.
-- - Nombre de tabla 'BACTH' (typo de BATCH) se conserva.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_g(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql          VARCHAR(65535);
    v_sql_gen      VARCHAR(65535);
    v_nombre_cubo  VARCHAR(30);
    v_n            BIGINT;
    v_sol          VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla          VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    v_lote         VARCHAR(30) := CAST(p_lote AS VARCHAR(30));
    r              RECORD;
BEGIN
    ---------------------------------------------------------------------------
    -- BACTH_FG_1: una fila por campo/cubo con el SQL que crea BACTH_FG_2
    ---------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fg_1');

    -- SELECT DISTINCT externo: el original crea tabla SET (sin MULTISET).
    -- El SQL generado tambien usa SELECT DISTINCT (BACTH_FG_2 es tabla SET).
    v_sql := 'CREATE TABLE rec_stage.bacth_fg_1 DISTKEY(id) AS
SELECT DISTINCT
    x.id
   ,x.nombre_cubo
   ,x.cubo
   ,''CREATE TABLE rec_stage.bacth_fg_2 DISTKEY(id_auto) AS
SELECT DISTINCT
 z.id_auto
,z.id_buro_persona
,z.cant_campo
,CASE WHEN z.nombre_cubo_y IS NULL THEN 1
      ELSE CASE WHEN z.cant_campo BETWEEN '' || x.min_txt || '' AND '' || x.max_txt || '' THEN 0 ELSE 1 END
 END AS c_update
FROM ('' ||
    CASE WHEN x.cubo = ''Ciiu'' THEN ''
SELECT
 id_auto
,id_buro_persona
,ROW_NUMBER() OVER (PARTITION BY id_buro_persona) AS cant_campo
,Y.nombre_cubo AS nombre_cubo_y
FROM (SELECT
       id_auto
      ,'' || x.homologado || ''
      ,id_buro_persona
      ,'''''' || x.nombre_cubo || '''''' AS nombre_cubo
      FROM rec_stage.'' || x.nombre_cubo || ''
      QUALIFY (ROW_NUMBER() OVER (PARTITION BY id_buro_persona,'' || x.homologado || '' ORDER BY fecha_reporte NULLS FIRST)) = 1
     ) A''
    ELSE ''
SELECT
 B.id_auto
,B.id_buro_persona
,'' || CASE WHEN x.nombre_cubo = ''BATCH_CUBO_PUNTO_INTERES_DIR''
             THEN ''SUM(1) OVER (PARTITION BY B.id_buro_persona,cod_dw_ubic ORDER BY NVL(distancia,999) ROWS UNBOUNDED PRECEDING)''
             WHEN (x.nombre_cubo = ''BATCH_CUBO_DIRECCION'' OR x.nombre_cubo = ''BATCH_CUBO_TELEFONO'')
             THEN ''SUM(1) OVER (PARTITION BY B.id_buro_persona ORDER BY NVL(B.orden_prioridad,999),fecha_ultima_actualizacion DESC NULLS LAST,ciudad NULLS FIRST,departamento NULLS FIRST ROWS UNBOUNDED PRECEDING)''
             ELSE ''SUM(1) OVER (PARTITION BY B.id_buro_persona ORDER BY NVL(B.orden_prioridad,999),fecha_ultima_actualizacion DESC NULLS LAST ROWS UNBOUNDED PRECEDING)''
        END || '' AS cant_campo
,Y.nombre_cubo AS nombre_cubo_y
FROM (SELECT
       id_auto
      ,'' || x.homologado || ''
      ,id_buro_persona
      ,'''''' || x.nombre_cubo || '''''' AS nombre_cubo
      FROM rec_stage.'' || x.nombre_cubo || ''
      '' || CASE WHEN x.nombre_cubo = ''BATCH_CUBO_DIRECCION''
                  THEN ''WHERE (COALESCE(filtro_a,0)+COALESCE(filtro_b,0)+COALESCE(filtro_c,0)+COALESCE(filtro_d,0)+COALESCE(filtro_e,0)+COALESCE(filtro_f,0)) = 0''
                  ELSE '''' END || ''
      '' || CASE WHEN x.nombre_cubo = ''BATCH_CUBO_PUNTO_INTERES_DIR''
                  THEN ''QUALIFY (ROW_NUMBER() OVER (PARTITION BY id_buro_persona,cod_dw_ubic,cod_dw_ubic_punto_interes ORDER BY NVL(distancia,999))) = 1''
                  WHEN (x.nombre_cubo = ''BATCH_CUBO_DIRECCION'' OR x.nombre_cubo = ''BATCH_CUBO_TELEFONO'')
                  THEN ''QUALIFY (ROW_NUMBER() OVER (PARTITION BY id_buro_persona,'' || x.homologado || '',ciudad ORDER BY NVL(orden_prioridad,999),fecha_ultima_actualizacion DESC NULLS LAST,ciudad NULLS FIRST,departamento NULLS FIRST)) = 1''
                  ELSE ''QUALIFY (ROW_NUMBER() OVER (PARTITION BY id_buro_persona,'' || x.homologado || '' ORDER BY NVL(orden_prioridad,999),fecha_ultima_actualizacion DESC NULLS LAST)) = 1''
             END || ''
     ) A
INNER JOIN rec_stage.'' || x.nombre_cubo || '' B ON A.id_auto = B.id_auto''
    END || ''
LEFT JOIN (SELECT
            CASE WHEN grupo_campo = ''''CUBO_CEL''''    THEN ''''BATCH_CUBO_CELULAR''''
                 WHEN grupo_campo = ''''CUBO_CIIU''''   THEN ''''BATCH_CUBO_CIIU''''
                 WHEN grupo_campo = ''''CUBO_EMAIL''''  THEN ''''BATCH_CUBO_CORREO''''
                 WHEN grupo_campo = ''''CUBO_DIR''''    THEN ''''BATCH_CUBO_DIRECCION''''
                 WHEN grupo_campo = ''''CUBO_TEL''''    THEN ''''BATCH_CUBO_TELEFONO''''
                 WHEN grupo_campo = ''''CUBO_PT_INT'''' THEN ''''BATCH_CUBO_PUNTO_INTERES_DIR''''
            END AS nombre_cubo
           FROM rec_stage.batch_salidas_campos
           WHERE grupo_campo <> ''''CUBO_PERS''''
             AND nombre_seccion LIKE ''''%CON DATOS%''''
             AND id_solicitud = ' || v_sol || '
             AND id_plantilla = ' || v_pla || '
           GROUP BY grupo_campo) Y
  ON A.nombre_cubo = Y.nombre_cubo
) z'' AS sql_string
FROM (
    SELECT
        CAST(b2h.id_sequencia AS INTEGER) AS id
       ,CASE WHEN b2h.cubo = ''Celular''      THEN ''BATCH_CUBO_CELULAR''
             WHEN b2h.cubo = ''Ciiu''         THEN ''BATCH_CUBO_CIIU''
             WHEN b2h.cubo = ''Correo''       THEN ''BATCH_CUBO_CORREO''
             WHEN b2h.cubo = ''Direccion''    THEN ''BATCH_CUBO_DIRECCION''
             WHEN b2h.cubo = ''Persona''      THEN ''BATCH_CUBO_PERSONA''
             WHEN b2h.cubo = ''Telefono''     THEN ''BATCH_CUBO_TELEFONO''
             WHEN b2h.cubo = ''PuntoInteres'' THEN ''BATCH_CUBO_PUNTO_INTERES_DIR''
        END AS nombre_cubo
       ,b2h.cubo
       ,b2h.homologado
       ,TRIM(CAST(COALESCE(rec_vista.f_td_to_number(bsc.minimo_requerido_campo), 0) AS VARCHAR(50))) AS min_txt
       ,CASE WHEN COALESCE(bsc.cantidad_max_campo, 0) = 0 THEN ''1000000''
             ELSE TRIM(CAST(bsc.cantidad_max_campo AS VARCHAR(30))) END AS max_txt
    FROM rec_stage.batch_salidas_campos bsc
    INNER JOIN rec_stage.batch2_homologacion b2h
       ON bsc.codigo_campo = b2h.codigo_campo
      AND bsc.codigo_campo IN (''DT_NUM'',''CE_CORREO'',''DD_DIR'',''DC_NUMERO'',''DB_CIIU'',''DECB_NOM'')
      AND bsc.id_solicitud = ' || v_sol || '
      AND bsc.id_plantilla = ' || v_pla || '
) x
WHERE x.nombre_cubo <> ''BATCH_CUBO_PERSONA''';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_FG_1');

    ---------------------------------------------------------------------------
    -- FILTRO_G = 1 en los cubos que tienen fila en BACTH_FG_1.
    -- SELECT ... INTO del original: 0 filas -> no actualiza; >1 fila -> error
    -- 7627 que aborta el SP (se replica con RAISE EXCEPTION).
    ---------------------------------------------------------------------------
    v_nombre_cubo := 'BATCH_CUBO_CELULAR';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_CELULAR';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_celular SET filtro_g = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=1 BATCH_CUBO_CELULAR');
    END IF;

    v_nombre_cubo := 'BATCH_CUBO_CIIU';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_CIIU';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_ciiu SET filtro_g = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=1 BATCH_CUBO_CIIU');
    END IF;

    v_nombre_cubo := 'BATCH_CUBO_CORREO';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_CORREO';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_correo SET filtro_g = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=1 BATCH_CUBO_CORREO');
    END IF;

    v_nombre_cubo := 'BATCH_CUBO_DIRECCION';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_DIRECCION';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_direccion SET filtro_g = 1';
        -- Texto de paso del original ('G=0' aunque asigna 1)
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=0 BATCH_CUBO_DIRECCION');
    END IF;

    v_nombre_cubo := 'BATCH_CUBO_TELEFONO';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_TELEFONO';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_telefono SET filtro_g = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=1 BATCH_CUBO_TELEFONO');
    END IF;

    -- #2 punto de interes
    v_nombre_cubo := 'BATCH_CUBO_PUNTO_INTERES_DIR';
    SELECT COUNT(*) INTO v_n FROM rec_stage.bacth_fg_1 WHERE nombre_cubo = 'BATCH_CUBO_PUNTO_INTERES_DIR';
    IF v_n > 1 THEN
        RAISE EXCEPTION 'SELECT-INTO returned more than one row (BACTH_FG_1, %)', v_nombre_cubo;
    END IF;
    IF v_n = 1 THEN
        v_sql := 'UPDATE rec_stage.batch_cubo_punto_interes_dir SET filtro_g = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE FILTRO G=1 BATCH_CUBO_PUNTO_INTERES_DIR');
    END IF;

    ---------------------------------------------------------------------------
    -- Cursor de actualizacion de FILTRO_G (cursor dinamico en el original)
    ---------------------------------------------------------------------------
    FOR r IN EXECUTE 'SELECT nombre_cubo, sql_string
                      FROM rec_stage.bacth_fg_1
                      ORDER BY id' LOOP
        v_nombre_cubo := r.nombre_cubo;
        v_sql_gen     := r.sql_string;

        -- Borrado de la tabla temporal BACTH_FG_2 si existe
        CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fg_2');

        -- Creacion de BACTH_FG_2 con los filtros calculados.
        -- Si sql_string es NULL (HOMOLOGADO NULL) el paso falla igual que el original.
        v_sql := REPLACE(v_sql_gen, 'P_LOTE', v_lote);
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             LEFT('Crea tabla rec_stage.' || v_sql_gen || ';', 500));

        -- BUG ORIGINAL REPLICADO: BACTH_FG_2 solo tiene ID_AUTO del cubo
        -- v_nombre_cubo, pero se aplica a los 6 cubos (nombres fijos). Si
        -- ID_AUTO coincide entre cubos, contamina FILTRO_G de otros cubos.
        -- BUG ORIGINAL REPLICADO: el paso de log de los 6 UPDATE nombra
        -- v_nombre_cubo, no la tabla que realmente se actualiza.
        v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_telefono.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');

        v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_direccion.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');

        v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_celular.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');

        v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_correo.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');

        v_sql := 'UPDATE rec_stage.batch_cubo_ciiu
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_ciiu.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');

        -- #7 punto de interes ("pruebas JB" en el original)
        v_sql := 'UPDATE rec_stage.batch_cubo_punto_interes_dir
SET filtro_g = b.c_update
FROM rec_stage.bacth_fg_2 b
WHERE batch_cubo_punto_interes_dir.id_auto = b.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE FILTRO G TABLA rec_stage.' || v_nombre_cubo || ' CAMPO BACTH_FG_2;');
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_HOMOLOGACIONES -> rec_stage.sp_batch2_homologaciones
-- Fuente: Sps_Batch.sql lineas 4592-5311.
-- 1) (#1) Normaliza BATCH_CUBO_PERSONA.NUMERO_ID a TRIM(CAST(.. AS BIGINT)) y
--    (#3) lo mismo en BATCH_IDENTIFICACIONES_INCONS de la solicitud (solo
--    valores numericos > 0).
-- 2) Homologa valores de campos de los cubos segun BATCH_HOMOLOGACIONES
--    (VALOR_DEFECTO -> VALOR_HOMOLOGADO) de la solicitud/plantilla. El campo
--    fisico sale de BATCH2_HOMOLOGACION.HOMOLOGADO y el cubo de .CUBO. Arma
--    SQL dinamico: BACTH_HOMG_1 (valores), BACTH_HOMG_2 (fragmentos por
--    campo), BACTH_HOMG_3 (consulta recursiva que encadena fragmentos y genera
--    por cubo: CREATE <Cubo>HO, CREATE <Cubo>HO1 y el UPDATE del cubo). Un
--    cursor ejecuta las 3 sentencias de cada cubo.
-- 3) Si la solicitud es de PRUEBA (BATCH_SOLICITUD_BATCH.PRUEBA <> 'SV'),
--    enmascara celulares, telefonos, direcciones, correos y nombres.
--
-- Decisiones de traduccion:
-- - BATCH_HOMOLOGACIONES -> rec_stage.batch_homologaciones (DDL 02, columnas
--   id_solicitud, id_plantilla, codigo_campo, valor_defecto,
--   valor_homologado). BATCH2_HOMOLOGACION -> rec_stage.batch2_homologacion
--   (DDL 05, columnas id_sequencia, codigo_campo, homologado, cubo).
-- - BACTH_HOMG_1/2/3 y las tablas generadas <Cubo>HO / <Cubo>HO1 se crean en
--   el original con CREATE TABLE sin MULTISET (tabla SET). BACTH_HOMG_1 no
--   puede tener duplicados (ID es un contador unico), BACTH_HOMG_2 tampoco
--   (ID unico) ni BACTH_HOMG_3 (1 fila por cubo), por lo que no se agrega
--   DISTINCT. En el SQL generado para <Cubo>HO y <Cubo>HO1 si se usa
--   SELECT DISTINCT: <Cubo>HO se arma con TODAS las filas de BACTH_HOMG_1
--   (filas todo NULL de otros cubos y pares repetidos) y la tabla SET los
--   colapsaba; sin DISTINCT el LEFT JOIN de <Cubo>HO1 multiplicaria filas.
-- - BACTH_HOMG_2: el original referencia alias del mismo SELECT (MIN_ID,
--   FILTRO_SQL1, FILTRO_SQLB, FILTRO_SQL0, FILTRO_SQLX, FILTRO_SQLD) y usa
--   QUALIFY ROW_NUMBER(). Se calcula en subconsultas: MIN_ID y ROW_NUMBER
--   sobre TODAS las filas de BACTH_HOMG_1 (igual que en Teradata, donde las
--   ventanas se evaluan antes del QUALIFY) y luego WHERE rn = 1. Se conservan
--   todas las columnas del original (A.* + las calculadas) y sus CAST.
--   FILTRO_SQL (VARCHAR(1000)||VARCHAR(1000)) se fija en VARCHAR(2000), el
--   tipo que Teradata le asignaba.
-- - BACTH_HOMG_3: '0A'XC -> CHR(10). Las columnas recursivas toman en
--   Teradata el tipo de la semilla (FILTRO_SQL 2000, FILTRO_SQLA 5000,
--   FILTRO_SQLC 5000, SQL_UP 1000) y la concatenacion se trunca en silencio;
--   se replica con CAST al mismo VARCHAR en semilla y termino recursivo
--   (Redshift trunca en silencio al hacer CAST a VARCHAR menor).
--   AUTO_ID+1 sin calificar -> t2.auto_id + 1 (unica columna con ese nombre).
-- - SQL generado (texto de Q_SQL/Q_SQL2/SQL_UP) en sintaxis Redshift:
--   "CREATE TABLE x AS (SELECT ...) WITH DATA;" -> "CREATE TABLE x AS
--   SELECT DISTINCT ..."; <Cubo>HO1 con DISTKEY(id_auto) (PI por defecto
--   del original = ID_AUTO); "UPDATE T1 FROM cubo T1, <Cubo>HO1 HO SET ..
--   WHERE T1.ID_AUTO=HO.ID_AUTO;" -> "UPDATE rec_stage.cubo SET .. FROM
--   rec_stage.<Cubo>HO1 HO WHERE cubo.id_auto = HO.id_auto" (sin alias en
--   destino). Se quita el ';' final. Nombres sin comillas: en Redshift
--   quedan en minusculas (p. ej. personaho, personaho1).
-- - TRIM(ID) (numero) -> TRIM(CAST(id AS VARCHAR(20))).
-- - Cursor dinamico (PREPARE ... OPEN ... FETCH) -> FOR r IN EXECUTE ... LOOP.
-- - El texto de paso 'Crea tabla <bd>.<sql completo>;' se conserva con
--   'rec_stage' y se recorta con LEFT(.., 500) (largo de la columna paso).
-- - Los DROP condicionados a dbc.tables usan sp_drop_si_existe (su texto de
--   paso es 'DROP TABLE rec_stage.<tabla>', no 'DROP TABLE <tabla>' ni
--   'PRO_BATCH2_HOMOLOGACIONES(021)/(051):Borrando ...'). En el cursor el
--   DROP solo se hace si TABLA_FILTRO no es NULL (en el original un nombre
--   NULL no encontraba fila en dbc.tables y no se borraba nada).
-- - #1 y #3: TRIM(CAST(x AS BIGINT)) -> CAST(CAST(TRIM(x) AS BIGINT) AS
--   VARCHAR(20)); TO_NUMBER -> rec_vista.f_td_to_number. En #3 el CAST se
--   envuelve en CASE WHEN <mismo filtro> (Redshift no garantiza el orden de
--   evaluacion de predicados); mismas filas afectadas. Igual que en
--   12_adicionar_incon.sql.
-- - Enmascaramiento: DataMasking / DirDataMasking / RazonDataMasking ->
--   SQL UDF rec_vista.f_datamasking / f_dirdatamasking /
--   f_razondatamasking (ddl/08, port del C de FuncionesUDF/DataMasking;
--   un buzon de 3 caracteres o menos queda sin cambios, ver ddl/08);
--   eListGetValByIdx -> SPLIT_PART; Substr -> SUBSTRING;
--   Position -> POSITION; character_length -> LEN. Las referencias a alias
--   del mismo SELECT (ext, buzonMask, extNew, Primer_Apellido1, ...) se
--   resuelven con subconsultas. COLLECT STAT .. INDEX (ID_AUTO) ->
--   ANALYZE tabla (id_auto). PRIMARY INDEX(ID_Auto) -> DISTKEY(id_auto).
-- - eListGetValByIdx(correo,'@',2) se traduce como
--   NULLIF(SPLIT_PART(..,'@',2),''): SPLIT_PART devuelve '' cuando no hay
--   segundo elemento y SUBSTRING('',1,-1) fallaria por largo negativo; se
--   asume que la UDF Teradata devolvia NULL (correo enmascarado NULL).
-- - Tipo_ID = 2 (texto vs numero, conversion implicita en Teradata) ->
--   CAST(TRIM(tipo_id) AS INTEGER) = 2: un TIPO_ID no numerico hace fallar
--   el paso en ambos motores.
-- - Truncamiento: los valores enmascarados (UDF RETURNS VARCHAR(500)) se
--   recortan con LEFT al largo de la columna destino del DDL Redshift
--   (numero 30, direccion 200, correo 200, nombre_completo 200), replicando
--   el truncamiento silencioso de Teradata. Los demas nombres (<= 50 o
--   'XXXX') no exceden su columna.
-- - El bloque L2 (enmascaramiento) se ejecuta al final, igual que el
--   original; el conteo de solicitud de prueba es SQL estatico.
--
-- Diferencias de comportamiento por manejo de errores:
-- - El original NO verifica V_ERROR tras #1, #3 ni tras ninguna sentencia
--   del bloque L2 (continua con la siguiente), y un LEAVE L1 por error en la
--   homologacion igual ejecuta el bloque L2 (enmascaramiento). En Redshift
--   el primer error detiene el SP. El resultado del pipeline es el mismo (el
--   BTQ falla al encontrar el error en LOG_TD_DETALLE), pero en Teradata
--   quedaban aplicados los pasos posteriores al error.
--
-- BUG ORIGINAL REPLICADO:
-- - #1 castea NUMERO_ID de BATCH_CUBO_PERSONA a BIGINT sin proteccion: un
--   NUMERO_ID no numerico (pasaporte alfanumerico) hace fallar el paso.
-- - MIN_ID se calcula sobre todas las filas del cubo, pero el QUALIFY deja
--   solo la ULTIMA fila (ID mayor) de cada campo. Si el primer campo de un
--   cubo (menor ID_SEQUENCIA) tiene mas de un valor a homologar, ninguna fila
--   conservada tiene ID = MIN_ID, todos los fragmentos empiezan con ',' y el
--   SQL generado queda invalido ("SELECT ,CASE ..."): el paso 'Crea tabla'
--   falla, igual que en Teradata.
-- - Si BATCH2_HOMOLOGACION.CUBO no es uno de los 6 mapeados (p. ej.
--   'PuntoInteres'), NOMBRE_CUBO es NULL: Q_SQL2 y SQL_UP quedan NULL y el
--   paso falla (EXECUTE de texto NULL). El QUALIFY de BACTH_HOMG_3 agrupa por
--   NOMBRE_CUBO, por lo que todos los cubos no mapeados comparten una fila.
-- - Si la concatenacion de fragmentos de un cubo supera el largo de la
--   columna recursiva se trunca y el SQL generado queda invalido.
-- - La consulta recursiva genera todas las subsecuencias crecientes de
--   campos por cubo (2^n - 1 filas para n campos); solo se usa la mas larga.
-- - El ultimo paso (UPDATE de BATCH_CUBO_PERSONA con los nombres
--   enmascarados) repite el texto de paso del ANALYZE anterior
--   '(07):Enmascarando Emails, Ejec Estadisticas ...'; se conserva.
-- - Empates de ID_SEQUENCIA: el orden del contador ID (y por tanto que fila
--   conserva el QUALIFY y el orden de los campos) no es determinista, igual
--   que en el original.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_homologaciones(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_sol  VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla  VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    v_cnt  INTEGER;
    r      RECORD;
BEGIN
    -- ==================================================================
    -- L1: HOMOLOGACIONES
    -- ==================================================================

    -- #1: homologacion de numero_id como BIGINT en el cubo persona
    -- BUG ORIGINAL REPLICADO: CAST sin proteccion (falla si no es numerico)
    v_sql := 'UPDATE rec_stage.batch_cubo_persona
SET numero_id = CAST(CAST(TRIM(numero_id) AS BIGINT) AS VARCHAR(20))';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Homologacion Numero_Id as Bigint');

    -- #3: homologacion de numero_id como BIGINT en inconsistencias (solo > 0)
    v_sql := 'UPDATE rec_stage.batch_identificaciones_incons
SET numero_id = CAST(CASE WHEN COALESCE(rec_vista.f_td_to_number(numero_id), 0) > 0
                          THEN CAST(TRIM(numero_id) AS BIGINT)
                     END AS VARCHAR(20))
WHERE id_solicitud = ' || v_sol || '
  AND COALESCE(rec_vista.f_td_to_number(numero_id), 0) > 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Homologacion Numero_Id as Bigint Incons');

    -- ------------------------------------------------------------------
    -- BACTH_HOMG_1: valores a homologar de la solicitud/plantilla
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_homg_1');

    v_sql := 'CREATE TABLE rec_stage.bacth_homg_1 DISTKEY(id) AS
SELECT
    SUM(1) OVER (ORDER BY b2h.id_sequencia ROWS UNBOUNDED PRECEDING) AS id
   ,bsc.codigo_campo
   ,b2h.homologado
   ,bsc.valor_defecto
   ,bsc.valor_homologado
   ,CASE WHEN b2h.cubo = ''Celular''   THEN ''BATCH_CUBO_CELULAR''
         WHEN b2h.cubo = ''Ciiu''      THEN ''BATCH_CUBO_CIIU''
         WHEN b2h.cubo = ''Correo''    THEN ''BATCH_CUBO_CORREO''
         WHEN b2h.cubo = ''Direccion'' THEN ''BATCH_CUBO_DIRECCION''
         WHEN b2h.cubo = ''Persona''   THEN ''BATCH_CUBO_PERSONA''
         WHEN b2h.cubo = ''Telefono''  THEN ''BATCH_CUBO_TELEFONO''
    END AS nombre_cubo
   ,b2h.cubo
FROM rec_stage.batch_homologaciones bsc
INNER JOIN rec_stage.batch2_homologacion b2h
   ON bsc.codigo_campo = b2h.codigo_campo
WHERE bsc.id_solicitud = ' || v_sol || '
  AND bsc.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_HOMG_1');

    -- ------------------------------------------------------------------
    -- BACTH_HOMG_2: fragmentos de SQL por campo (1 fila por cubo/campo)
    -- x: ventanas sobre todas las filas (MIN_ID, ROW_NUMBER del QUALIFY)
    -- y: columnas que en el original referencian alias del mismo SELECT
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_homg_2');

    v_sql := 'CREATE TABLE rec_stage.bacth_homg_2 DISTKEY(id) AS
SELECT
    y.id
   ,y.codigo_campo
   ,y.homologado
   ,y.valor_defecto
   ,y.valor_homologado
   ,y.nombre_cubo
   ,y.cubo
   ,y.min_id
   ,y.filtro_sql1
   ,y.filtro_sqlx
   ,y.filtro_sqla
   ,y.filtro_sqlb
   ,y.filtro_sqlc
   ,y.sql_up
   ,y.filtro_sql0
   ,y.filtro_sqld
   ,CAST(y.filtro_sqlx || y.filtro_sqld AS VARCHAR(2000)) AS filtro_sql
FROM (
    SELECT
        x.id
       ,x.codigo_campo
       ,x.homologado
       ,x.valor_defecto
       ,x.valor_homologado
       ,x.nombre_cubo
       ,x.cubo
       ,x.min_id
       ,x.filtro_sql1
       ,CAST(CASE WHEN x.id = x.min_id THEN x.filtro_sql1 ELSE '','' || x.filtro_sql1 END AS VARCHAR(1000)) AS filtro_sqlx
       ,x.filtro_sqla
       ,x.filtro_sqlb
       ,CAST(CASE WHEN x.id = x.min_id THEN x.filtro_sqlb ELSE '','' || x.filtro_sqlb END AS VARCHAR(5000)) AS filtro_sqlc
       ,CAST(CASE WHEN x.id = x.min_id THEN x.homologado || ''=HO.'' || x.homologado
                  ELSE '','' || x.homologado || ''=HO.'' || x.homologado
             END AS VARCHAR(1000)) AS sql_up
       ,x.filtro_sql0
       ,CAST('','' || x.filtro_sql0 AS VARCHAR(1000)) AS filtro_sqld
    FROM (
        SELECT
            a.id
           ,a.codigo_campo
           ,a.homologado
           ,a.valor_defecto
           ,a.valor_homologado
           ,a.nombre_cubo
           ,a.cubo
           ,CAST(MIN(a.id) OVER (PARTITION BY a.cubo) AS INTEGER) AS min_id
           ,'' CASE WHEN HOMOLOGADO='''''' || a.homologado || '''''' THEN VALOR_HOMOLOGADO END AS '' || a.homologado AS filtro_sql1
           ,CAST('' LEFT JOIN rec_stage.'' || a.cubo || ''HO AS H'' || TRIM(CAST(a.id AS VARCHAR(20)))
                 || '' ON  H'' || TRIM(CAST(a.id AS VARCHAR(20))) || ''.'' || a.homologado
                 || ''1= T1.'' || a.homologado AS VARCHAR(5000)) AS filtro_sqla
           ,''CASE WHEN H'' || TRIM(CAST(a.id AS VARCHAR(20))) || ''.'' || a.homologado
                || '' IS NULL THEN T1.'' || a.homologado
                || '' ELSE H'' || TRIM(CAST(a.id AS VARCHAR(20))) || ''.'' || a.homologado
                || '' END AS '' || a.homologado AS filtro_sqlb
           ,'' CASE WHEN HOMOLOGADO='''''' || a.homologado || '''''' THEN VALOR_DEFECTO END AS '' || a.homologado || ''1'' AS filtro_sql0
           ,ROW_NUMBER() OVER (PARTITION BY a.nombre_cubo, a.codigo_campo ORDER BY a.id DESC) AS rn
        FROM rec_stage.bacth_homg_1 a
    ) x
    WHERE x.rn = 1
) y';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_HOMG_2');

    -- ------------------------------------------------------------------
    -- BACTH_HOMG_3: consulta recursiva que encadena los fragmentos por cubo
    -- y genera las 3 sentencias de cada cubo (1 fila por cubo)
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_homg_3');

    -- CAST en semilla y termino recursivo: replica el tipo fijado por la
    -- semilla en Teradata (trunca en silencio).
    v_sql := 'CREATE TABLE rec_stage.bacth_homg_3 DISTSTYLE ALL AS
WITH RECURSIVE concat_list
( id
 ,filtro_sql
 ,filtro_sqla
 ,filtro_sqlc
 ,sql_up
 ,nombre_cubo
 ,cubo
 ,auto_id
) AS
(
  SELECT
      id
     ,CAST(filtro_sql  AS VARCHAR(2000))
     ,CAST(filtro_sqla AS VARCHAR(5000))
     ,CAST(filtro_sqlc AS VARCHAR(5000))
     ,CAST(sql_up      AS VARCHAR(1000))
     ,nombre_cubo
     ,cubo
     ,1 AS auto_id
  FROM rec_stage.bacth_homg_2

  UNION ALL

  SELECT
      t1.id
     ,CAST(t1.filtro_sql  || CHR(10) || t2.filtro_sql  AS VARCHAR(2000))
     ,CAST(t1.filtro_sqla || CHR(10) || t2.filtro_sqla AS VARCHAR(5000))
     ,CAST(t1.filtro_sqlc || CHR(10) || t2.filtro_sqlc AS VARCHAR(5000))
     ,CAST(t1.sql_up      || CHR(10) || t2.sql_up      AS VARCHAR(1000))
     ,t1.nombre_cubo
     ,t1.cubo
     ,t2.auto_id + 1
  FROM rec_stage.bacth_homg_2 t1
  INNER JOIN concat_list t2
     ON t1.cubo = t2.cubo
  WHERE t1.id < t2.id
)
SELECT
    ''CREATE TABLE rec_stage.'' || cl.cubo || ''HO AS'' || CHR(10)
    || ''  SELECT DISTINCT '' || cl.filtro_sql || CHR(10)
    || ''  FROM rec_stage.bacth_homg_1'' AS q_sql
   ,''CREATE TABLE rec_stage.'' || cl.cubo || ''HO1 DISTKEY(id_auto) AS'' || CHR(10)
    || ''  SELECT DISTINCT id_auto,'' || cl.filtro_sqlc || CHR(10)
    || ''  FROM rec_stage.'' || cl.nombre_cubo || '' AS T1'' || CHR(10)
    || ''  '' || cl.filtro_sqla AS q_sql2
   ,''UPDATE rec_stage.'' || cl.nombre_cubo || CHR(10)
    || ''SET '' || cl.sql_up || CHR(10)
    || ''FROM rec_stage.'' || cl.cubo || ''HO1 HO'' || CHR(10)
    || ''WHERE '' || cl.nombre_cubo || ''.id_auto = HO.id_auto'' AS sql_up
   ,cl.nombre_cubo
   ,cl.cubo
   ,cl.cubo || ''HO'' AS tabla_filtro
FROM concat_list cl
QUALIFY (SUM(1) OVER (PARTITION BY cl.nombre_cubo ORDER BY cl.auto_id DESC ROWS UNBOUNDED PRECEDING)) = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_HOMG_3');

    -- ------------------------------------------------------------------
    -- Cursor de actualizacion de HOMOLOGACIONES (cursor dinamico en el original)
    -- ------------------------------------------------------------------
    FOR r IN EXECUTE 'SELECT q_sql, q_sql2, sql_up, nombre_cubo, tabla_filtro
                      FROM rec_stage.bacth_homg_3
                      ORDER BY 1, 2' LOOP

        -- Borrado de <Cubo>HO si existe
        IF r.tabla_filtro IS NOT NULL THEN
            CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.' || r.tabla_filtro);
        END IF;

        -- Creacion de <Cubo>HO (pares valor homologado / valor por defecto)
        v_sql := r.q_sql;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             LEFT('Crea tabla rec_stage.' || v_sql || ';', 500));

        -- Borrado de <Cubo>HO1 si existe
        IF r.tabla_filtro IS NOT NULL THEN
            CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.' || r.tabla_filtro || '1');
        END IF;

        -- Creacion de <Cubo>HO1 (valores finales por id_auto)
        -- Si q_sql2 es NULL (cubo no mapeado) el paso falla igual que el original.
        v_sql := r.q_sql2;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             LEFT('Crea tabla rec_stage.' || v_sql || ';', 500));

        -- UPDATE HOMOLOGACIONES del cubo
        v_sql := r.sql_up;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'UPDATE HOMOLOGACIONES tabla rec_stage.' || r.nombre_cubo || ';');
    END LOOP;

    -- ==================================================================
    -- L2: enmascaramiento de datos para solicitudes de PRUEBA
    -- ==================================================================
    v_cnt := 0;
    SELECT COUNT(1) INTO v_cnt
    FROM rec_stage.batch_solicitud_batch
    WHERE COALESCE(prueba, 'SV') <> 'SV'
      AND id_solicitud = p_id_solicitud;

    IF v_cnt > 0 THEN

        -- LEFT(.., n): replica el truncamiento silencioso de Teradata
        v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET numero = LEFT(rec_vista.f_datamasking(numero), 30)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(01):Enmascarando celulares');

        v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET numero = LEFT(rec_vista.f_datamasking(numero), 30)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(02):Enmascarando telefonos');

        v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET direccion = LEFT(rec_vista.f_dirdatamasking(direccion), 200)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(02):Enmascarando Direcciones');

        -- (021) Borrando BATCH_CUBO_CORREO_MASK
        CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch_cubo_correo_mask');

        -- Original MULTISET: sin DISTINCT
        v_sql := 'CREATE TABLE rec_stage.batch_cubo_correo_mask DISTKEY(id_auto) AS
SELECT b.id_auto
      ,b.buzonmask
      ,b.ext
      ,b.extnew
      ,b.correo
      ,b.buzonmask || ''@XXXX.'' || b.extnew AS mailmask
FROM (
    SELECT a.id_auto
          ,a.buzonmask
          ,a.ext
          ,SUBSTRING(a.ext, POSITION(''.'' IN a.ext) + 1, LEN(a.ext) - 1) AS extnew
          ,a.correo
    FROM (
        SELECT id_auto
              ,rec_vista.f_datamasking(SPLIT_PART(TRIM(correo), ''@'', 1)) AS buzonmask
              ,NULLIF(SPLIT_PART(TRIM(correo), ''@'', 2), '''') AS ext
              ,correo
        FROM rec_stage.batch_cubo_correo
    ) a
) b';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(03):Enmascarando Emails, Creando BATCH_CUBO_CORREO_MASK');

        v_sql := 'ANALYZE rec_stage.batch_cubo_correo_mask (id_auto)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(04):Enmascarando Emails, Ejecutando Estadisticas BATCH_CUBO_CORREO_MASK');

        v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET correo = LEFT(batch_cubo_correo_mask.mailmask, 200)
FROM rec_stage.batch_cubo_correo_mask
WHERE batch_cubo_correo.id_auto = batch_cubo_correo_mask.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(05):Enmascarando Emails');

        -- (051) Borrando BATCH_CUBO_PERSONA_MASK
        CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch_cubo_persona_mask');

        -- Original MULTISET: sin DISTINCT. Tipo_ID = 2 (texto vs numero) ->
        -- CAST(TRIM(tipo_id) AS INTEGER) = 2.
        v_sql := 'CREATE TABLE rec_stage.batch_cubo_persona_mask DISTKEY(id_auto) AS
SELECT m.id_auto
      ,m.numero_id
      ,m.nombre_completo
      ,CASE WHEN CAST(TRIM(m.tipo_id) AS INTEGER) = 2 THEN
                 rec_vista.f_razondatamasking(COALESCE(m.nombre_completo, ''''))
            ELSE
                 m.primer_apellido1 || '' '' || m.segundo_apellido1 || '' '' || m.primer_nombre1 || '' '' || m.segundo_nombre1
       END AS nombre_completo1
      ,m.primer_apellido1
      ,m.segundo_apellido1
      ,m.primer_nombre1
      ,m.segundo_nombre1
FROM (
    SELECT a.id_auto
          ,a.numero_id
          ,a.nombre_completo
          ,a.tipo_id
          ,CASE WHEN CAST(TRIM(a.tipo_id) AS INTEGER) <> 2 THEN COALESCE(a.segundo_apellido, ''XXXX'') ELSE NULL END AS primer_apellido1
          ,a.primer_apellido AS segundo_apellido1
          ,CASE WHEN CAST(TRIM(a.tipo_id) AS INTEGER) <> 2 THEN COALESCE(a.segundo_nombre, ''XXXX'') ELSE NULL END AS primer_nombre1
          ,a.primer_nombre AS segundo_nombre1
    FROM rec_stage.batch_cubo_persona a
) m';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(06):Enmascarando nombres, Creando BATCH_CUBO_PERSONA_MASK');

        v_sql := 'ANALYZE rec_stage.batch_cubo_persona_mask (id_auto)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(07):Enmascarando Emails, Ejec Estadisticas en BATCH_CUBO_PERSONA_MASK');

        -- BUG ORIGINAL REPLICADO: texto de paso copiado del ANALYZE anterior
        v_sql := 'UPDATE rec_stage.batch_cubo_persona
SET nombre_completo  = LEFT(batch_cubo_persona_mask.nombre_completo1, 200)
   ,primer_nombre    = batch_cubo_persona_mask.primer_nombre1
   ,segundo_nombre   = batch_cubo_persona_mask.segundo_nombre1
   ,primer_apellido  = batch_cubo_persona_mask.primer_apellido1
   ,segundo_apellido = batch_cubo_persona_mask.segundo_apellido1
FROM rec_stage.batch_cubo_persona_mask
WHERE batch_cubo_persona.id_auto = batch_cubo_persona_mask.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'PRO_BATCH2_HOMOLOGACIONES(07):Enmascarando Emails, Ejec Estadisticas en BATCH_CUBO_PERSONA_MASK');
    END IF;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_I -> rec_stage.sp_batch2_filtro_i
-- Fuente: Sps_Batch.sql lineas 3995-4153.
-- Marca FILTRO_I = 1 cuando ORDEN_PRIORIDAD es NULL y 0 en otro caso, en los
-- cubos BATCH_CUBO_DIRECCION, BATCH_CUBO_TELEFONO, BATCH_CUBO_CELULAR y
-- BATCH_CUBO_CORREO. La lista de cubos se materializa en BACTH_FI_1 y se
-- recorre con un cursor; por cada cubo se ejecuta un MERGE de la tabla
-- consigo misma por ID_AUTO.
-- El original no recibe plantilla ni solicitud (no filtra por ellas).
--
-- Decisiones de traduccion:
-- - DECODE(ORDEN_PRIORIDAD, NULL, 1, 0): en Teradata DECODE trata NULL como
--   igual a NULL, por lo que devuelve 1 si ORDEN_PRIORIDAD es NULL y 0 en
--   otro caso (confirmado con el codigo). Se escribe como
--   CASE WHEN orden_prioridad IS NULL THEN 1 ELSE 0 END.
-- - MERGE ... WHEN MATCHED THEN UPDATE (sin WHEN NOT MATCHED) de la tabla
--   consigo misma -> UPDATE ... FROM (subconsulta sobre la misma tabla)
--   WHERE id_auto = id_auto. Con ID_AUTO unico el resultado es identico.
--   Diferencia: si hubiera ID_AUTO duplicados, Teradata fallaria (una fila
--   destino con varias filas origen) y Redshift actualizaria sin error con
--   un valor no determinista.
-- - 'x' (VARCHAR(30)) -> CAST('x' AS VARCHAR(30)).
-- - CREATE MULTISET TABLE sin PRIMARY INDEX -> DISTSTYLE ALL (4 filas).
-- - Cursor dinamico (PREPARE ... OPEN, sin ORDER BY) -> FOR r IN EXECUTE.
--   El orden de los cubos no afecta el resultado.
-- - Los nombres de cubo vienen en mayusculas y se usan sin comillas, por lo
--   que Redshift los resuelve en minusculas (rec_stage.batch_cubo_...).
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_i(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    r      RECORD;
BEGIN
    -- ------------------------------------------------------------------
    -- Busca y borra si existe la tabla BACTH_FI_1
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fi_1');

    -- ------------------------------------------------------------------
    -- Crea tabla BACTH_FI_1 con la lista de cubos
    -- ------------------------------------------------------------------
    v_sql := 'CREATE TABLE rec_stage.bacth_fi_1 DISTSTYLE ALL AS
SELECT * FROM (SELECT CAST(''BATCH_CUBO_DIRECCION'' AS VARCHAR(30)) AS cubo) x UNION ALL
SELECT * FROM (SELECT CAST(''BATCH_CUBO_TELEFONO'' AS VARCHAR(30)) AS cubo) x UNION ALL
SELECT * FROM (SELECT CAST(''BATCH_CUBO_CELULAR'' AS VARCHAR(30)) AS cubo) x UNION ALL
SELECT * FROM (SELECT CAST(''BATCH_CUBO_CORREO'' AS VARCHAR(30)) AS cubo) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea BACTH_FI_1');

    -- ------------------------------------------------------------------
    -- Filtro_I por cubo: 1 si orden_prioridad es NULL, 0 en otro caso
    -- (MERGE del original reescrito como UPDATE ... FROM subconsulta)
    -- ------------------------------------------------------------------
    FOR r IN EXECUTE 'SELECT cubo FROM rec_stage.bacth_fi_1' LOOP
        v_sql := 'UPDATE rec_stage.' || r.cubo || '
SET filtro_i = y.new_filtro_i
FROM (SELECT s.id_auto
            ,CASE WHEN s.orden_prioridad IS NULL THEN 1 ELSE 0 END AS new_filtro_i
      FROM rec_stage.' || r.cubo || ' s) y
WHERE ' || r.cubo || '.id_auto = y.id_auto';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Filtro_I ' || r.cubo);
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_H -> rec_stage.sp_batch2_filtro_h
-- Fuente: Sps_Batch.sql lineas 3530-3994.
-- Clasifica cada fila de los cubos como "con datos" (FILTRO_H = 0) o
-- "sin datos" (FILTRO_H = 1) y depura:
--   1. FILTRO_H = 1 si la fila tiene algun filtro previo (A..G, I) marcado
--      (cubo persona: solo FILTRO_D; ciiu: D + G).
--   2. En cada cubo borra las filas FILTRO_H = 1 de las personas que tienen
--      a la vez filas con FILTRO_H = 0 y = 1 (clasificadas en ambos grupos).
--   3. Marca FILTRO_H = 1 en BATCH_CUBO_PERSONA para las personas sin
--      ninguna fila FILTRO_H = 0 en direccion/telefono/celular/correo/ciiu.
--   4. (#1/#2 requerido = si) Por cada cubo con algun campo REQUERIDO_CAMPO
--      = 'SI' en la plantilla, marca FILTRO_H = 1 en BATCH_CUBO_PERSONA para
--      las personas sin ninguna fila FILTRO_H = 0 en ese cubo.
-- Traduccion:
--   - Los dos cursores dinamicos (PREPARE the_statement / FETCH) pasan a
--     FOR r IN EXECUTE ... LOOP sobre las mismas tablas de trabajo
--     (rec_stage.bacth_fh_1 / bacth_fh_2). Igual que el original, el orden
--     de recorrido no esta definido (no hay ORDER BY); cada sentencia es
--     independiente del orden.
--   - Las sentencias guardadas como datos en BACTH_FH_1 / BACTH_FH_2 se
--     reescriben a Redshift (minusculas, EQ -> =) y sin el ';' final.
--   - BACTH_FH_1 y BACTH_FH_2 son CREATE TABLE sin MULTISET (tabla SET en
--     Teradata): se usa SELECT DISTINCT. No cambia el resultado (las filas
--     ya son unicas) pero replica la semantica.
--   - TMP_NEW_FILTRO_H es MULTISET: sin DISTINCT.
--   - El DROP de TMP_NEW_FILTRO_H el original lo hace con DBC.SysExecSQL
--     (sin pasar por SP_EXECSTRING_DES, sin log): se replica con un
--     DROP TABLE IF EXISTS estatico, que tampoco deja log.
--   - Los nombres de cubo se guardan en mayusculas como en el original
--     ('BATCH_CUBO_PERSONA', ...) y se concatenan sin comillas al SQL
--     dinamico; Redshift pasa a minusculas los identificadores sin comillas.
--   - HAVING CANTIDAD GT 1 (alias) -> HAVING COUNT(filtro_h) > 1.
--   - El REGEXP_REPLACE('REC_STAGE' -> P_BDSTAGE, 'P_LOTE' -> lote) del
--     segundo cursor se conserva; en la practica no cambia el texto (el
--     esquema ya viene resuelto y no hay marcador P_LOTE).
-- BUG ORIGINAL REPLICADO / diferencias de log:
--   - Los pasos de log del original dicen 'DROP TABLE BACTH_FG_1',
--     'DROP TABLE BACTH_FG_2' y 'CREATE TABLE BACTH_FG_2' (copiados de
--     FILTRO_G) aunque la tabla es BACTH_FH_*. El texto de CREATE se
--     conserva; los DROP usan sp_drop_si_existe, cuyo paso es
--     'DROP TABLE rec_stage.bacth_fh_1' / '..._2'.
--   - El nombre de tabla 'BACTH' (typo de BATCH) se conserva.
--   - En BACTH_FH_2, el CASE de NOMBRE_CUBO no tiene ELSE: si un campo
--     requerido pertenece a un CUBO no listado, CAMPO queda NULL y la
--     ejecucion de esa sentencia NULL falla (sp_execstring_des registra el
--     error y se detiene el SP).
--   - BATCH_CUBO_PUNTO_INTERES_DIR no esta en la lista de recalculo de
--     FILTRO_H (paso 1) ni en la depuracion (paso 2) ni en el paso 3, pero
--     si en el paso 4 (requerido = si): usa el FILTRO_H que traiga el cubo
--     (DEFAULT 0 si nadie lo actualiza).
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_h(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_sql2  VARCHAR(65535);
    v_cubo  VARCHAR(30);
    v_sol   VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla   VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
    r       RECORD;
BEGIN
    ---------------------------------------------------------------------------
    -- Paso 1: tabla de sentencias de actualizacion de FILTRO_H por cubo
    ---------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fh_1');

    -- Tabla SET en Teradata (CREATE TABLE sin MULTISET) -> SELECT DISTINCT
    v_sql := 'CREATE TABLE rec_stage.bacth_fh_1 AS
SELECT DISTINCT nombre_cubo, sql_string
FROM (
SELECT CAST(''BATCH_CUBO_PERSONA'' AS VARCHAR(30)) AS nombre_cubo,
       CAST(''UPDATE rec_stage.batch_cubo_persona SET filtro_h = CASE WHEN COALESCE(filtro_d,0) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000)) AS sql_string
UNION ALL
SELECT CAST(''BATCH_CUBO_DIRECCION'' AS VARCHAR(30)),
       CAST(''UPDATE rec_stage.batch_cubo_direccion SET filtro_h = CASE WHEN (COALESCE(filtro_a,0) + COALESCE(filtro_b,0) + COALESCE(filtro_c,0) + COALESCE(filtro_d,0) + COALESCE(filtro_e,0) + COALESCE(filtro_f,0) + COALESCE(filtro_g,0) + COALESCE(filtro_i,0)) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000))
UNION ALL
SELECT CAST(''BATCH_CUBO_TELEFONO'' AS VARCHAR(30)),
       CAST(''UPDATE rec_stage.batch_cubo_telefono SET filtro_h = CASE WHEN (COALESCE(filtro_b,0) + COALESCE(filtro_c,0) + COALESCE(filtro_d,0) + COALESCE(filtro_e,0) + COALESCE(filtro_f,0) + COALESCE(filtro_g,0) + COALESCE(filtro_i,0)) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000))
UNION ALL
SELECT CAST(''BATCH_CUBO_CELULAR'' AS VARCHAR(30)),
       CAST(''UPDATE rec_stage.batch_cubo_celular SET filtro_h = CASE WHEN (COALESCE(filtro_b,0) + COALESCE(filtro_c,0) + COALESCE(filtro_d,0) + COALESCE(filtro_e,0) + COALESCE(filtro_f,0) + COALESCE(filtro_g,0) + COALESCE(filtro_i,0)) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000))
UNION ALL
SELECT CAST(''BATCH_CUBO_CORREO'' AS VARCHAR(30)),
       CAST(''UPDATE rec_stage.batch_cubo_correo SET filtro_h = CASE WHEN (COALESCE(filtro_b,0) + COALESCE(filtro_c,0) + COALESCE(filtro_d,0) + COALESCE(filtro_e,0) + COALESCE(filtro_f,0) + COALESCE(filtro_g,0) + COALESCE(filtro_i,0)) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000))
UNION ALL
SELECT CAST(''Batch_Cubo_Ciiu'' AS VARCHAR(30)),
       CAST(''UPDATE rec_stage.batch_cubo_ciiu SET filtro_h = CASE WHEN (COALESCE(filtro_d,0) + COALESCE(filtro_g,0)) > 0 THEN 1 ELSE 0 END'' AS VARCHAR(1000))
) a';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'CREA TMP_FILTRO_H');

    -- Cursor 1: ejecuta cada UPDATE de FILTRO_H
    FOR r IN EXECUTE 'SELECT nombre_cubo, sql_string FROM rec_stage.bacth_fh_1' LOOP
        v_cubo := r.nombre_cubo;
        v_sql2 := r.sql_string;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql2,
             'UPDT FH ' || v_cubo || ';');
    END LOOP;

    ---------------------------------------------------------------------------
    -- Paso 2: borra filas FILTRO_H = 1 de personas con filas 0 y 1 en el cubo
    ---------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fh_1');

    -- Tabla SET en Teradata -> SELECT DISTINCT
    v_sql := 'CREATE TABLE rec_stage.bacth_fh_1 AS
SELECT DISTINCT cubo
FROM (
SELECT CAST(''BATCH_CUBO_PERSONA'' AS VARCHAR(30)) AS cubo UNION ALL
SELECT CAST(''BATCH_CUBO_DIRECCION'' AS VARCHAR(30)) UNION ALL
SELECT CAST(''BATCH_CUBO_TELEFONO'' AS VARCHAR(30)) UNION ALL
SELECT CAST(''BATCH_CUBO_CELULAR'' AS VARCHAR(30)) UNION ALL
SELECT CAST(''BATCH_CUBO_CORREO'' AS VARCHAR(30)) UNION ALL
SELECT CAST(''BATCH_CUBO_CIIU'' AS VARCHAR(30))
) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea BACTH_FH_1');

    -- Cursor 2: DELETE por cubo.
    -- Se eliminan las personas que estan marcadas con filtro 1, que se
    -- encuentran ya clasificadas como con datos (comentario original).
    -- COUNT(filtro_h) ignora NULL, igual que en Teradata.
    FOR r IN EXECUTE 'SELECT cubo FROM rec_stage.bacth_fh_1' LOOP
        v_cubo := r.cubo;
        v_sql2 := 'DELETE FROM rec_stage.' || v_cubo || '
WHERE filtro_h = 1
  AND id_buro_persona IN (SELECT id_buro_persona
                          FROM (SELECT id_buro_persona, COUNT(filtro_h) AS cantidad
                                FROM (SELECT id_buro_persona, filtro_h
                                      FROM rec_stage.' || v_cubo || '
                                      GROUP BY id_buro_persona, filtro_h) x
                                GROUP BY id_buro_persona
                                HAVING COUNT(filtro_h) > 1) y)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql2,
             'Filtro_H ' || v_cubo);
    END LOOP;

    ---------------------------------------------------------------------------
    -- Paso 3: personas sin ninguna fila FILTRO_H = 0 en los cubos de ubicacion
    ---------------------------------------------------------------------------
    -- Original: DBC.SysExecSQL directo (sin SP_EXECSTRING_DES, sin log)
    DROP TABLE IF EXISTS rec_stage.tmp_new_filtro_h;

    -- MULTISET en Teradata: sin DISTINCT
    v_sql := 'CREATE TABLE rec_stage.tmp_new_filtro_h DISTKEY(id_auto) AS
SELECT id_auto
FROM (SELECT bcp.id_auto,
             CASE WHEN COALESCE(bcd.id_auto, bct.id_auto, bcc.id_auto, bco.id_auto, bci.id_auto) IS NULL THEN 1 ELSE 0 END AS new_filtro_h
      FROM rec_stage.batch_cubo_persona bcp
      LEFT JOIN rec_stage.batch_cubo_direccion bcd ON bcp.id_buro_persona = bcd.id_buro_persona AND bcd.filtro_h = 0
      LEFT JOIN rec_stage.batch_cubo_telefono  bct ON bcp.id_buro_persona = bct.id_buro_persona AND bct.filtro_h = 0
      LEFT JOIN rec_stage.batch_cubo_celular   bcc ON bcp.id_buro_persona = bcc.id_buro_persona AND bcc.filtro_h = 0
      LEFT JOIN rec_stage.batch_cubo_correo    bco ON bcp.id_buro_persona = bco.id_buro_persona AND bco.filtro_h = 0
      LEFT JOIN rec_stage.batch_cubo_ciiu      bci ON bcp.id_buro_persona = bci.id_buro_persona AND bci.filtro_h = 0) x
WHERE new_filtro_h = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea TMP_NEW_FILTRO_H');

    v_sql := 'UPDATE rec_stage.batch_cubo_persona
SET filtro_h = 1
WHERE id_auto IN (SELECT id_auto FROM rec_stage.tmp_new_filtro_h)
  AND filtro_h = 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'new Filtro_H BATCH_CUBO_PERSONA');

    ---------------------------------------------------------------------------
    -- Paso 4 (#1/#2): requerido = si -> persona sin datos en el cubo requerido
    ---------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_fh_2');

    -- Tabla SET en Teradata -> SELECT DISTINCT
    -- BUG ORIGINAL REPLICADO: CASE sin ELSE -> CAMPO NULL para cubos no listados
    v_sql := 'CREATE TABLE rec_stage.bacth_fh_2 AS
SELECT DISTINCT
       ''UPDATE rec_stage.batch_cubo_persona
SET filtro_h = 1
WHERE id_auto NOT IN (SELECT bcp.id_auto
                      FROM rec_stage.batch_cubo_persona bcp
                      INNER JOIN rec_stage.'' || nombre_cubo || '' bcd
                        ON bcp.id_buro_persona = bcd.id_buro_persona
                      WHERE bcd.filtro_h = 0
                      GROUP BY 1)
  AND NVL(filtro_h, 0) = 0'' AS campo
FROM (SELECT CASE WHEN cubo = ''Celular''      THEN ''BATCH_CUBO_CELULAR''
                  WHEN cubo = ''Ciiu''         THEN ''BATCH_CUBO_CIIU''
                  WHEN cubo = ''Correo''       THEN ''BATCH_CUBO_CORREO''
                  WHEN cubo = ''Direccion''    THEN ''BATCH_CUBO_DIRECCION''
                  WHEN cubo = ''Persona''      THEN ''BATCH_CUBO_PERSONA''
                  WHEN cubo = ''Telefono''     THEN ''BATCH_CUBO_TELEFONO''
                  WHEN cubo = ''PuntoInteres'' THEN ''BATCH_CUBO_PUNTO_INTERES_DIR''
             END AS nombre_cubo
      FROM rec_stage.batch_salidas_campos bsc
      INNER JOIN rec_stage.batch2_homologacion b2h
         ON bsc.codigo_campo = b2h.codigo_campo
        AND b2h.grupo_campo = bsc.grupo_campo
        AND bsc.id_solicitud = ' || v_sol || '
        AND bsc.id_plantilla = ' || v_pla || '
      WHERE bsc.requerido_campo = ''SI''
        AND bsc.grupo_campo <> ''CUBO_PERS''
      GROUP BY 1) a';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'CREATE TABLE BACTH_FG_2');

    -- Cursor 3: ejecuta cada UPDATE de requerido = si sobre el cubo persona
    FOR r IN EXECUTE 'SELECT campo FROM rec_stage.bacth_fh_2' LOOP
        v_sql2 := r.campo;
        -- Reemplazo de marcadores del original (sin efecto practico, ver cabecera)
        v_sql := REGEXP_REPLACE(REGEXP_REPLACE(v_sql2, 'REC_STAGE', 'rec_stage'),
                                'P_LOTE', CAST(p_lote AS VARCHAR(12)));
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDT FH CUBO_PERSONA;');
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_FILTRO_J -> rec_stage.sp_batch2_filtro_j
-- Fuente: Sps_Batch.sql lineas 4154-4591.
-- Elimina de BATCH_CUBO_CORREO / BATCH_CUBO_CELULAR los correos / numeros
-- repetidos segun el tamano de la base de salida de cada cubo:
--   conteo 1..1000      y algun valor con mas de 3 repeticiones  -> borra > 3
--   conteo 1001..10000  y algun valor con mas de 5 repeticiones  -> borra > 5
--   conteo > 10000      y algun valor con mas de 10 repeticiones -> borra > 10
-- Se borran TODAS las filas del valor repetido (no se conserva ninguna).
-- Tablas de trabajo: DUP_CORREO, DUP_CELULAR (valores con COUNT > 1) y
-- DETALLEVALORES (conteo del cubo y maximo de duplicados, por cubo).
-- No recibe plantilla ni solicitud: opera sobre todo el contenido del cubo.
--
-- Traduccion:
--   - Los DELETE del original no usan alias ni self-join
--     (DELETE FROM t WHERE col IN (SELECT ...)): se traducen literal.
--     Se quita el ';' final que el original dejaba dentro de V_CADENA.
--   - Las 6 comprobaciones "SELECT detalle INTO :Temp ... IF ACTIVITY_COUNT
--     > 0" son estaticas en el original: se traducen a SELECT ... INTO
--     v_temp + IF FOUND. DETALLEVALORES tiene una fila por detalle, por lo
--     que el SELECT INTO nunca devuelve mas de una fila.
--   - Las comprobaciones comparan detalle = 'Correo' / 'Celular' contra los
--     valores 'correo' / 'celular' guardados en DETALLEVALORES. En Teradata
--     coinciden porque la columna es NOT CASESPECIFIC; en Redshift depende
--     de COLLATE CASE_INSENSITIVE (convencion 5). Sin esa collation NUNCA
--     se borraria nada. Se traduce literal, sin UPPER/LOWER.
--
-- Bugs / particularidades del original replicados:
--   - BUG ORIGINAL REPLICADO: las tablas de trabajo se crean en P_BDSTAGE,
--     pero las comprobaciones leen REC_STAGE.detalleValores fijo. En
--     Redshift ambos son rec_stage, asi que no hay diferencia efectiva.
--   - DUP_CORREO / DUP_CELULAR incluyen el grupo NULL si hay correos /
--     numeros nulos repetidos; ese grupo cuenta para el maximo de
--     DETALLEVALORES pero nunca se borra (NULL IN (...) no coincide).
--     Igual en ambos motores.
--   - DETALLEVALORES se calcula una sola vez antes de los DELETE; como los
--     rangos de conteo son excluyentes, a lo sumo se ejecuta un DELETE por
--     cubo.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_filtro_j(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_temp  VARCHAR(30);
BEGIN
    -- ------------------------------------------------------------------
    -- Duplicados existentes en el cubo correo
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.dup_correo');

    v_sql := 'CREATE TABLE rec_stage.dup_correo DISTKEY(correo) AS
SELECT correo
      ,COUNT(*) AS duplicados
FROM rec_stage.batch_cubo_correo
GROUP BY 1
HAVING COUNT(*) > 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla dup_correo');

    -- ------------------------------------------------------------------
    -- Duplicados existentes en el cubo celular
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.dup_celular');

    v_sql := 'CREATE TABLE rec_stage.dup_celular DISTKEY(numero) AS
SELECT numero
      ,COUNT(*) AS duplicados
FROM rec_stage.batch_cubo_celular
GROUP BY 1
HAVING COUNT(*) > 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla dup_celular');

    -- ------------------------------------------------------------------
    -- Conteo final de registros de salida de cada cubo y maximo de
    -- duplicados por dato de contacto (CORREO - CELULAR)
    -- ------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.detallevalores');

    v_sql := 'CREATE TABLE rec_stage.detallevalores DISTKEY(detalle) AS
SELECT CAST(''correo'' AS VARCHAR(30)) AS detalle
      ,COUNT(*) AS conteo
      ,(SELECT COALESCE(MAX(duplicados), 0) FROM rec_stage.dup_correo) AS duplicado
FROM rec_stage.batch_cubo_correo
UNION ALL
SELECT CAST(''celular'' AS VARCHAR(30)) AS detalle
      ,COUNT(*) AS conteo
      ,(SELECT COALESCE(MAX(duplicados), 0) FROM rec_stage.dup_celular) AS duplicado
FROM rec_stage.batch_cubo_celular';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla detalleValores');

    -- ------------------------------------------------------------------
    -- Eliminacion por cantidad de duplicados vs registros de salida CORREO
    -- ------------------------------------------------------------------
    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Correo'
      AND duplicado > 3
      AND conteo > 0 AND conteo <= 1000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_correo
WHERE correo IN (SELECT correo
                 FROM rec_stage.dup_correo
                 WHERE duplicados > 3)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar correos duplicados condicion: Mas de 3 duplicados en base de salida de 1 a 1.000 registros');
    END IF;

    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Correo'
      AND duplicado > 5
      AND conteo > 1000 AND conteo <= 10000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_correo
WHERE correo IN (SELECT correo
                 FROM rec_stage.dup_correo
                 WHERE duplicados > 5)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar correos duplicados condicion: Mas de 5 duplicados en base de salida de 1.000 a 10.000 registros');
    END IF;

    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Correo'
      AND duplicado > 10
      AND conteo > 10000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_correo
WHERE correo IN (SELECT correo
                 FROM rec_stage.dup_correo
                 WHERE duplicados > 10)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar correos duplicados condicion: Mas de 10 duplicados en base de salida de mas de 10.000 registros');
    END IF;

    -- ------------------------------------------------------------------
    -- Eliminacion por cantidad de duplicados vs registros de salida CELULAR
    -- ------------------------------------------------------------------
    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Celular'
      AND duplicado > 3
      AND conteo > 0 AND conteo <= 1000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_celular
WHERE numero IN (SELECT numero
                 FROM rec_stage.dup_celular
                 WHERE duplicados > 3)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar celulares duplicados condicion: Mas de 3 duplicados en base de salida de 1 a 1.000 registros');
    END IF;

    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Celular'
      AND duplicado > 5
      AND conteo > 1000 AND conteo <= 10000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_celular
WHERE numero IN (SELECT numero
                 FROM rec_stage.dup_celular
                 WHERE duplicados > 5)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar celulares duplicados condicion: Mas de 5 duplicados en base de salida de 1.000 a 10.000 registros');
    END IF;

    SELECT detalle INTO v_temp
    FROM rec_stage.detallevalores
    WHERE detalle = 'Celular'
      AND duplicado > 10
      AND conteo > 10000;

    IF FOUND THEN
        v_sql := 'DELETE FROM rec_stage.batch_cubo_celular
WHERE numero IN (SELECT numero
                 FROM rec_stage.dup_celular
                 WHERE duplicados > 10)';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Eliminar celulares duplicados condicion: Mas de 10 duplicados en base de salida de mas de 10.000 registros');
    END IF;
END;
$$;


-- ============================================================================
-- PRO_BATCH_ADD_PORC_INSUMO -> rec_stage.sp_batch2_add_porc_insumo
-- Fuente: Sps_Batch.sql lineas 5312-5976.
-- Solo actua si la plantilla tiene una subseccion de salida '%Validacion%'
-- (BATCH_SALIDAS_CAMPOS.NOMBRE_SUBSECCION); si no, termina sin hacer nada.
-- 1) Por cada cubo (direccion, telefono, celular, correo) recalcula
--    ORDEN_PRIORIDAD (ROW_NUMBER por persona sobre las filas con FILTRO_H = 0)
--    y anula POR_SIM_* en las filas cuyo nuevo orden supera
--    CANTIDAD_MAX_CAMPO del campo (DD_DIR, DT_NUM, DC_NUMERO, CE_CORREO).
--    Tablas de trabajo TMP_BATCH_PORPOS_DIR / _TEL / _CEL / _COR.
-- 2) Copia a STG_INSUMO_BATCH_VALIDACION (POR_SIM_*_000 y
--    ORDEN_PRIORIDAD_*_000) la mejor similitud y su orden por persona y canal,
--    solo entre los registros dentro del maximo de cada campo.
--
-- Parametros: el original recibe (..., P_ID_SOLICITUD, P_ID_PLANTILLA) en ese
-- orden y el BTQ los pasa en ese orden. En Redshift la firma se estandariza a
-- (p_id_plantilla, p_id_solicitud). Dentro del SP:
--   - P_ID_SOLICITUD y P_ID_PLANTILLA se usan juntos solo en la validacion
--     de la subseccion '%Validacion%'.
--   - Los CANTIDAD_MAX_CAMPO filtran SOLO por ID_SOLICITUD (sin plantilla),
--     igual que el original.
--
-- Decisiones de traduccion:
-- - Validacion: SELECT ... INTO con QUALIFY ROW_NUMBER() OVER (ORDER BY
--   NOMBRE_SUBSECCION) = 1 -> SELECT ... ORDER BY ... LIMIT 1 (misma fila).
-- - El alias ORDEN (ROW_NUMBER) usado en el CASE del mismo SELECT se calcula
--   en una subconsulta.
-- - CHAR(x) es CHARACTER_LENGTH en Teradata -> LEN(x).
-- - REC_VISTA.hash_md5(x) -> MD5(x). Diferencia posible: si la UDF Teradata
--   calculaba el hash sobre bytes LATIN y Redshift lo hace sobre UTF-8, los
--   textos con tildes o enie dan otro hash. Solo afecta el desempate final
--   del ORDER BY (ultimo criterio).
-- - Orden de NULL: Teradata ordena NULL como el valor mas bajo (ASC primero,
--   DESC ultimo); Redshift por defecto hace lo contrario. Se escribe
--   NULLS FIRST / NULLS LAST explicito en todos los ORDER BY de ventana.
-- - COLLECT STAT INDEX(ID_AUTO) -> ANALYZE tabla (id_auto).
-- - UPDATE ... FROM tmp SET ... -> UPDATE ... SET ... FROM tmp (sin alias).
-- - MERGE ... WHEN MATCHED THEN UPDATE (sin WHEN NOT MATCHED) ->
--   UPDATE ... FROM (subconsulta) y. Redshift exige WHEN NOT MATCHED en
--   MERGE; el UPDATE ... FROM es equivalente para un MERGE solo de
--   actualizacion. Diferencia: si una fila de STG_INSUMO_BATCH_VALIDACION
--   coincide con varias filas de la vista (varias filas por ID_BURO_PERSONA),
--   Teradata falla (error 7547) y Redshift actualiza con una de ellas.
-- - La subconsulta Y del MERGE selecciona ~40 columnas de la vista que no se
--   usan ni en el ON ni en el SET. Solo se conserva ID_BURO_PERSONA: mismo
--   resultado y la dependencia con la vista externa se reduce a esa columna.
-- - En las subconsultas BCD/BCT/BCC/BCO el alias ORDEN_PRIORIDAD (CASE WHEN
--   FILTRO_F IS NULL ...) coincide con el nombre de una columna. Teradata
--   resuelve primero la columna, asi que el WHERE "ORDEN_PRIORIDAD <= ..." y
--   el ORDER BY del QUALIFY usan la columna del cubo; el alias solo es el
--   valor devuelto. Se escribe asi de forma explicita.
-- - Se quitan los ';' finales del SQL dinamico.
--
-- Comportamientos del original que se conservan:
-- - Si BATCH_SALIDAS_CAMPOS tiene mas de una fila para el CODIGO_CAMPO en la
--   solicitud (varias plantillas o secciones), el CROSS JOIN duplica filas
--   en TMP_BATCH_PORPOS_* (y el ROW_NUMBER numera los duplicados), y la
--   subconsulta escalar del paso 2 falla por devolver mas de una fila.
-- - Las filas con FILTRO_H <> 0 (o NULL) no se actualizan: conservan su
--   ORDEN_PRIORIDAD y POR_SIM_* anteriores.
-- - Los pasos de log de telefono/celular/correo dicen 'UPDATE POR_SIM_DIR'
--   y el de estadisticas de telefono repite el numero (6); se conservan.
-- - Las tablas TMP_BATCH_PORPOS_* no se borran al final.
--
-- DEPENDENCIA: rec_stage.vstgbatchcargaubicestandarizada
-- (REC_STAGE.VstgBATCHCargaUbicEstandarizada). Migrada el 2026-10-14 en
-- ddl/09_vistas_dependencias_sps.sql (vista late-binding sobre las tablas
-- del proceso P0034). La vista devuelve una sola fila por ID_BURO_PERSONA
-- (QUALIFY ROW_NUMBER() = 1), asi que el caso de varias filas por persona
-- descrito arriba (error 7547 en Teradata) no se da con la vista real.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_add_porc_insumo(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql         VARCHAR(65535);
    v_sol         VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_validacion  VARCHAR(100);
BEGIN
    -- ------------------------------------------------------------------
    -- V1: la plantilla debe tener una subseccion de Validacion
    -- ------------------------------------------------------------------
    v_validacion := NULL;
    SELECT nombre_subseccion INTO v_validacion
    FROM rec_stage.batch_salidas_campos
    WHERE nombre_subseccion LIKE '%Validacion%'
      AND id_solicitud = p_id_solicitud
      AND id_plantilla = p_id_plantilla
    GROUP BY nombre_subseccion
    ORDER BY nombre_subseccion
    LIMIT 1;

    IF v_validacion IS NULL THEN
        RETURN;
    END IF;

    -- ==================================================================
    -- Ajuste ordenamiento DIRECCION
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tmp_batch_porpos_dir');

    v_sql := 'CREATE TABLE rec_stage.tmp_batch_porpos_dir DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.cod_dw_agenda_batch
      ,x.cod_dw_persona_ubic
      ,x.direccion
      ,x.ciudad
      ,x.departamento
      ,x.cod_dane_ciudad
      ,x.cod_dane_departamento
      ,x.tipo
      ,x.localidad
      ,x.barrio
      ,x.zona
      ,x.estrato
      ,x.fecha_ultima_actualizacion
      ,x.numero_de_entidades_reporta
      ,x.fuente
      ,x.contactabilidad
      ,x.medio_acceso
      ,x.mejor_dia_para_gestion
      ,x.mejor_hora_para_gestion
      ,x.mejor_resultado_3meses
      ,x.mejor_resultado_6meses
      ,x.reportado_por
      ,x.reportado_por_el_suscriptor
      ,x.meses_desde_el_ultimo_reporte
      ,CASE WHEN x.orden <= x.cantidad_max_campo THEN x.por_sim_dir ELSE NULL END AS por_sim_dir
      ,x.filtro_a
      ,x.filtro_b
      ,x.filtro_c
      ,x.filtro_d
      ,x.filtro_e
      ,x.filtro_f
      ,x.filtro_g
      ,x.filtro_h
      ,x.filtro_i
      ,x.id_buro_persona
      ,x.orden
FROM (SELECT a.*
            ,b.cantidad_max_campo
            ,ROW_NUMBER() OVER (PARTITION BY a.id_buro_persona
                                ORDER BY a.orden_prioridad ASC NULLS FIRST
                                        ,a.fecha_ultima_actualizacion DESC NULLS LAST
                                        ,LEN(a.tipo) DESC NULLS LAST
                                        ,LEN(a.direccion) DESC NULLS LAST
                                        ,a.cod_dane_ciudad DESC NULLS LAST
                                        ,a.ciudad DESC NULLS LAST
                                        ,a.departamento DESC NULLS LAST
                                        ,MD5(a.direccion) ASC NULLS FIRST) AS orden
      FROM rec_stage.batch_cubo_direccion a
      CROSS JOIN (SELECT cantidad_max_campo
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = ' || v_sol || '
                    AND codigo_campo = ''DD_DIR'') b
      WHERE a.filtro_h = 0) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(2):TMP_BATCH_PORPOS_DIR');

    v_sql := 'ANALYZE rec_stage.tmp_batch_porpos_dir (id_auto)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(3):Etadisticas en TMP_BATCH_PORPOS_DIR');

    v_sql := 'UPDATE rec_stage.batch_cubo_direccion
SET por_sim_dir     = tmp_batch_porpos_dir.por_sim_dir
   ,orden_prioridad = tmp_batch_porpos_dir.orden
FROM rec_stage.tmp_batch_porpos_dir
WHERE batch_cubo_direccion.id_auto = tmp_batch_porpos_dir.id_auto';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(4):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_DIRECCION');

    -- ==================================================================
    -- Ajuste ordenamiento TELEFONO
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tmp_batch_porpos_tel');

    -- Orden original: ..., CHAR(TIPO) (ASC), CHAR(Numero) DESC, ...
    v_sql := 'CREATE TABLE rec_stage.tmp_batch_porpos_tel DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.cod_dw_agenda_batch
      ,x.cod_dw_persona_ubic
      ,x.numero
      ,x.ciudad
      ,x.departamento
      ,x.cod_dane_ciudad
      ,x.cod_dane_departamento
      ,x.indicativo
      ,x.tipo
      ,x.fecha_ultima_actualizacion
      ,x.numero_de_entidades_reporta
      ,x.fuente
      ,x.reportado_por_el_suscriptor
      ,x.meses_desde_el_ultimo_reporte
      ,x.contactabilidad
      ,x.medio_acceso
      ,x.mejor_dia_para_gestion
      ,x.mejor_hora_para_gestion
      ,x.mejor_resultado_3meses
      ,x.mejor_resultado_6meses
      ,x.reportado_por
      ,CASE WHEN x.orden <= x.cantidad_max_campo THEN x.por_sim_tel ELSE NULL END AS por_sim_tel
      ,x.filtro_b
      ,x.filtro_c
      ,x.filtro_d
      ,x.filtro_e
      ,x.filtro_f
      ,x.filtro_g
      ,x.filtro_h
      ,x.filtro_i
      ,x.id_buro_persona
      ,x.orden
FROM (SELECT a.*
            ,b.cantidad_max_campo
            ,ROW_NUMBER() OVER (PARTITION BY a.id_buro_persona
                                ORDER BY a.orden_prioridad ASC NULLS FIRST
                                        ,a.fecha_ultima_actualizacion DESC NULLS LAST
                                        ,LEN(a.tipo) ASC NULLS FIRST
                                        ,LEN(a.numero) DESC NULLS LAST
                                        ,a.cod_dane_ciudad DESC NULLS LAST
                                        ,a.ciudad DESC NULLS LAST
                                        ,a.departamento DESC NULLS LAST
                                        ,MD5(a.numero) ASC NULLS FIRST) AS orden
      FROM rec_stage.batch_cubo_telefono a
      CROSS JOIN (SELECT cantidad_max_campo
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = ' || v_sol || '
                    AND codigo_campo = ''DT_NUM'') b
      WHERE a.filtro_h = 0) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(6):TMP_BATCH_PORPOS_TEL');

    v_sql := 'ANALYZE rec_stage.tmp_batch_porpos_tel (id_auto)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(6):Etadisticas en TMP_BATCH_PORPOS_TEL');

    v_sql := 'UPDATE rec_stage.batch_cubo_telefono
SET por_sim_tel     = tmp_batch_porpos_tel.por_sim_tel
   ,orden_prioridad = tmp_batch_porpos_tel.orden
FROM rec_stage.tmp_batch_porpos_tel
WHERE batch_cubo_telefono.id_auto = tmp_batch_porpos_tel.id_auto';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(7):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_TELEFONO');

    -- ==================================================================
    -- Ajuste ordenamiento CELULAR
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tmp_batch_porpos_cel');

    v_sql := 'CREATE TABLE rec_stage.tmp_batch_porpos_cel DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.cod_dw_agenda_batch
      ,x.cod_dw_persona_ubic
      ,x.numero
      ,x.fecha_ultima_actualizacion
      ,x.numero_de_entidades_reporta
      ,x.fuente
      ,x.reportado_por_el_suscriptor
      ,x.meses_desde_el_ultimo_reporte
      ,x.contactabilidad
      ,x.medio_acceso
      ,x.mejor_dia_para_gestion
      ,x.mejor_hora_para_gestion
      ,x.mejor_resultado_3meses
      ,x.mejor_resultado_6meses
      ,x.reportado_por
      ,CASE WHEN x.orden <= x.cantidad_max_campo THEN x.por_sim_cel ELSE NULL END AS por_sim_cel
      ,x.filtro_b
      ,x.filtro_c
      ,x.filtro_d
      ,x.filtro_e
      ,x.filtro_f
      ,x.filtro_g
      ,x.filtro_h
      ,x.filtro_i
      ,x.id_buro_persona
      ,x.orden
FROM (SELECT a.*
            ,b.cantidad_max_campo
            ,ROW_NUMBER() OVER (PARTITION BY a.id_buro_persona
                                ORDER BY a.orden_prioridad ASC NULLS FIRST
                                        ,a.fecha_ultima_actualizacion DESC NULLS LAST
                                        ,LEN(a.numero) DESC NULLS LAST
                                        ,MD5(a.numero) ASC NULLS FIRST) AS orden
      FROM rec_stage.batch_cubo_celular a
      CROSS JOIN (SELECT cantidad_max_campo
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = ' || v_sol || '
                    AND codigo_campo = ''DC_NUMERO'') b
      WHERE a.filtro_h = 0) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(9):TMP_BATCH_PORPOS_CEL');

    v_sql := 'ANALYZE rec_stage.tmp_batch_porpos_cel (id_auto)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(10):Etadisticas en TMP_BATCH_PORPOS_CEL');

    v_sql := 'UPDATE rec_stage.batch_cubo_celular
SET por_sim_cel     = tmp_batch_porpos_cel.por_sim_cel
   ,orden_prioridad = tmp_batch_porpos_cel.orden
FROM rec_stage.tmp_batch_porpos_cel
WHERE batch_cubo_celular.id_auto = tmp_batch_porpos_cel.id_auto';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(11):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_CELULAR');

    -- ==================================================================
    -- Ajuste ordenamiento CORREO
    -- ==================================================================
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tmp_batch_porpos_cor');

    v_sql := 'CREATE TABLE rec_stage.tmp_batch_porpos_cor DISTKEY(id_auto) AS
SELECT x.id_auto
      ,x.cod_pin_persona
      ,x.cod_dw_agenda_batch
      ,x.cod_dw_persona_ubic
      ,x.correo
      ,x.fecha_ultima_actualizacion
      ,x.numero_de_entidades_reporta
      ,x.fuente
      ,x.reportado_por_el_suscriptor
      ,x.meses_desde_el_ultimo_reporte
      ,x.contactabilidad
      ,x.medio_acceso
      ,x.mejor_dia_para_gestion
      ,x.mejor_hora_para_gestion
      ,x.mejor_resultado_3meses
      ,x.mejor_resultado_6meses
      ,x.reportado_por
      ,CASE WHEN x.orden <= x.cantidad_max_campo THEN x.por_sim_mail ELSE NULL END AS por_sim_mail
      ,x.filtro_b
      ,x.filtro_c
      ,x.filtro_d
      ,x.filtro_e
      ,x.filtro_f
      ,x.filtro_g
      ,x.filtro_h
      ,x.filtro_i
      ,x.id_buro_persona
      ,x.orden
FROM (SELECT a.*
            ,b.cantidad_max_campo
            ,ROW_NUMBER() OVER (PARTITION BY a.id_buro_persona
                                ORDER BY a.orden_prioridad ASC NULLS FIRST
                                        ,a.fecha_ultima_actualizacion DESC NULLS LAST
                                        ,LEN(a.correo) DESC NULLS LAST
                                        ,MD5(a.correo) ASC NULLS FIRST) AS orden
      FROM rec_stage.batch_cubo_correo a
      CROSS JOIN (SELECT cantidad_max_campo
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = ' || v_sol || '
                    AND codigo_campo = ''CE_CORREO'') b
      WHERE a.filtro_h = 0) x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(13):TMP_BATCH_PORPOS_COR');

    v_sql := 'ANALYZE rec_stage.tmp_batch_porpos_cor (id_auto)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(14):Etadisticas en TMP_BATCH_PORPOS_COR');

    v_sql := 'UPDATE rec_stage.batch_cubo_correo
SET por_sim_mail    = tmp_batch_porpos_cor.por_sim_mail
   ,orden_prioridad = tmp_batch_porpos_cor.orden
FROM rec_stage.tmp_batch_porpos_cor
WHERE batch_cubo_correo.id_auto = tmp_batch_porpos_cor.id_auto';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(15):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_CORREO');

    -- ==================================================================
    -- Porcentajes de similitud en STG_INSUMO_BATCH_VALIDACION
    -- (MERGE solo de actualizacion -> UPDATE ... FROM)
    -- ==================================================================
    v_sql := 'UPDATE rec_stage.stg_insumo_batch_validacion
SET por_sim_dir_000          = y.por_sim_dir
   ,orden_prioridad_dir_000  = y.orden_prioridad_dir
   ,por_sim_tel_000          = y.por_sim_tel
   ,orden_prioridad_tel_000  = y.orden_prioridad_tel
   ,por_sim_cel_000          = y.por_sim_cel
   ,orden_prioridad_cel_000  = y.orden_prioridad_cel
   ,por_sim_mail_000         = y.por_sim_mail
   ,orden_prioridad_mail_000 = y.orden_prioridad_mail
FROM (SELECT vue.id_buro_persona
            ,bcd.por_sim_dir
            ,bcd.orden_prioridad_sal AS orden_prioridad_dir
            ,bct.por_sim_tel
            ,bct.orden_prioridad_sal AS orden_prioridad_tel
            ,bcc.por_sim_cel
            ,bcc.orden_prioridad_sal AS orden_prioridad_cel
            ,bco.por_sim_mail
            ,bco.orden_prioridad_sal AS orden_prioridad_mail
      FROM rec_stage.vstgbatchcargaubicestandarizada vue
      LEFT JOIN (SELECT id_buro_persona
                       ,por_sim_dir
                       ,CASE WHEN filtro_f IS NULL THEN NULL ELSE orden_prioridad END AS orden_prioridad_sal
                 FROM rec_stage.batch_cubo_direccion
                 WHERE filtro_h = 0
                   AND orden_prioridad <= (SELECT cantidad_max_campo
                                           FROM rec_stage.batch_salidas_campos
                                           WHERE id_solicitud = ' || v_sol || '
                                             AND codigo_campo = ''DD_DIR'')
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY id_buro_persona
                                            ORDER BY por_sim_dir DESC NULLS LAST, orden_prioridad ASC NULLS FIRST) = 1) bcd
        ON vue.id_buro_persona = bcd.id_buro_persona
      LEFT JOIN (SELECT id_buro_persona
                       ,por_sim_tel
                       ,CASE WHEN filtro_f IS NULL THEN NULL ELSE orden_prioridad END AS orden_prioridad_sal
                 FROM rec_stage.batch_cubo_telefono
                 WHERE filtro_h = 0
                   AND orden_prioridad <= (SELECT cantidad_max_campo
                                           FROM rec_stage.batch_salidas_campos
                                           WHERE id_solicitud = ' || v_sol || '
                                             AND codigo_campo = ''DT_NUM'')
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY id_buro_persona
                                            ORDER BY por_sim_tel DESC NULLS LAST, orden_prioridad ASC NULLS FIRST) = 1) bct
        ON vue.id_buro_persona = bct.id_buro_persona
      LEFT JOIN (SELECT id_buro_persona
                       ,por_sim_cel
                       ,CASE WHEN filtro_f IS NULL THEN NULL ELSE orden_prioridad END AS orden_prioridad_sal
                 FROM rec_stage.batch_cubo_celular
                 WHERE filtro_h = 0
                   AND orden_prioridad <= (SELECT cantidad_max_campo
                                           FROM rec_stage.batch_salidas_campos
                                           WHERE id_solicitud = ' || v_sol || '
                                             AND codigo_campo = ''DC_NUMERO'')
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY id_buro_persona
                                            ORDER BY por_sim_cel DESC NULLS LAST, orden_prioridad ASC NULLS FIRST) = 1) bcc
        ON vue.id_buro_persona = bcc.id_buro_persona
      LEFT JOIN (SELECT id_buro_persona
                       ,por_sim_mail
                       ,CASE WHEN filtro_f IS NULL THEN NULL ELSE orden_prioridad END AS orden_prioridad_sal
                 FROM rec_stage.batch_cubo_correo
                 WHERE filtro_h = 0
                   AND orden_prioridad <= (SELECT cantidad_max_campo
                                           FROM rec_stage.batch_salidas_campos
                                           WHERE id_solicitud = ' || v_sol || '
                                             AND codigo_campo = ''CE_CORREO'')
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY id_buro_persona
                                            ORDER BY por_sim_mail DESC NULLS LAST, orden_prioridad ASC NULLS FIRST) = 1) bco
        ON vue.id_buro_persona = bco.id_buro_persona
     ) y
WHERE stg_insumo_batch_validacion.id_buro_persona = y.id_buro_persona';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'PRO_BATCH_ADD_PORC_INSUMO(16): Add PORC_SIMILITUD');
END;
$$;


-- ============================================================================
-- PRO_BATCH2_ADICIONAR_INCON -> rec_stage.sp_batch2_adicionar_incon
-- Fuente: Sps_Batch.sql lineas 5977-6160.
-- Pasa a inconsistencias (ESTADO '06', CAUSAL '04') las identificaciones
-- validas de la solicitud/plantilla que no quedaron en BATCH_CUBO_PERSONA
-- (comparando NUMERO_ID normalizado a BIGINT + TIPO_ID) y que aun no estan
-- en BATCH_IDENTIFICACIONES_INCONS para la solicitud. Luego (#3) las borra de
-- BATCH_IDENTIFICACIONES_VALIDAS y (#1) normaliza NUMERO_ID de las
-- inconsistencias de la solicitud a TRIM(CAST(NUMERO_ID AS BIGINT)).
-- Traduccion:
--   - BATCH2_TABLA_INCONSIS_AD_TMP es CREATE TABLE sin MULTISET (SET): el
--     GROUP BY del original ya deja filas unicas; se agrupa por las 4
--     columnas reales (las columnas 5 y 6 son constantes '06'/'04').
--     PRIMARY INDEX(NUMERO_ID, TIPO_ID) -> DISTKEY(numero_id) (Redshift
--     admite una sola columna de distribucion).
--   - TRIM(CAST(x AS BIGINT)) -> CAST(CAST(TRIM(x) AS BIGINT) AS VARCHAR(20))
--     (Redshift no convierte numero -> texto implicitamente).
--   - DELETE ... WHERE (TIPO_ID, CAST(NUMERO_ID AS BIGINT)) IN (SELECT ...)
--     -> DELETE ... USING (subconsulta) b WHERE ... (mismo resultado: semi
--     join; las filas repetidas en b no cambian que filas se borran).
--   - TO_NUMBER(x) -> rec_vista.f_td_to_number(x) (NULL si no es numerico).
--   - Proteccion #4: en Teradata el filtro COALESCE(TO_NUMBER(..),0) > 0
--     evita el error de CAST. Redshift no garantiza el orden de evaluacion
--     de los predicados, por lo que el CAST de la tabla destino se envuelve
--     en CASE WHEN <mismo filtro> THEN CAST(...) END. Las filas afectadas son
--     las mismas.
-- BUG ORIGINAL REPLICADO:
--   - El paso 'Crea Tabla TMP Inconsist' castea BS.NUMERO_ID a BIGINT sin la
--     proteccion #4: si una identificacion valida de la solicitud/plantilla
--     tiene NUMERO_ID no numerico (p. ej. pasaporte alfanumerico) el paso
--     falla, igual que en Teradata.
--   - El CAST a BIGINT de NUMERO_ID de BATCH_IDENTIFICACIONES_INCONS dentro
--     de la subconsulta del DELETE tampoco esta protegido.
--   - El paso de log del DELETE dice 'BATCH_CUBO_PERSONA: ...' aunque borra
--     de BATCH_IDENTIFICACIONES_VALIDAS; se conserva el texto.
--   - El original no verifica V_ERROR tras el UPDATE final (#1); al ser la
--     ultima sentencia no cambia el flujo. En Redshift el error se propaga.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_adicionar_incon(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_sol  VARCHAR(30) := CAST(p_id_solicitud AS VARCHAR(30));
    v_pla  VARCHAR(30) := CAST(p_id_plantilla AS VARCHAR(30));
BEGIN
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2_tabla_inconsis_ad_tmp');

    -- Identificaciones validas que no estan en el cubo persona ni ya en inconsistencias
    -- BUG ORIGINAL REPLICADO: CAST(bs.numero_id AS BIGINT) sin proteccion #4
    v_sql := 'CREATE TABLE rec_stage.batch2_tabla_inconsis_ad_tmp DISTKEY(numero_id) AS
SELECT bs.id_solicitud,
       bs.id_plantilla,
       bs.tipo_id,
       bs.numero_id,
       CAST(''06'' AS VARCHAR(2)) AS estado,
       CAST(''04'' AS VARCHAR(2)) AS causal
FROM rec_stage.batch_identificaciones_validas bs
WHERE bs.id_solicitud = ' || v_sol || '
  AND bs.id_plantilla = ' || v_pla || '
  AND NOT EXISTS (SELECT ''X''
                  FROM rec_stage.batch_cubo_persona cp
                  WHERE CAST(CAST(TRIM(bs.numero_id) AS BIGINT) AS VARCHAR(20)) = TRIM(cp.numero_id)
                    AND bs.tipo_id = cp.tipo_id)
  AND NOT EXISTS (SELECT ''X''
                  FROM rec_stage.batch_identificaciones_incons ver
                  WHERE CAST(CAST(TRIM(bs.numero_id) AS BIGINT) AS VARCHAR(20)) = TRIM(ver.numero_id)
                    AND bs.tipo_id = ver.tipo_id
                    AND ver.id_solicitud = bs.id_solicitud)
GROUP BY bs.id_solicitud, bs.id_plantilla, bs.tipo_id, bs.numero_id';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla TMP Inconsist');

    -- Actualizacion inconsistencias
    v_sql := 'INSERT INTO rec_stage.batch_identificaciones_incons
(id_solicitud, id_plantilla, tipo_id, numero_id, estado, causal)
SELECT id_solicitud,
       id_plantilla,
       tipo_id,
       numero_id,
       estado,
       causal
FROM rec_stage.batch2_tabla_inconsis_ad_tmp';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Insertando En Inconsist');

    -- #3 / #4: borra de validas las enviadas a inconsistencias con estado 06 y causal 04
    v_sql := 'DELETE FROM rec_stage.batch_identificaciones_validas
USING (SELECT tipo_id,
              CAST(TRIM(numero_id) AS BIGINT) AS numero_id_big
       FROM rec_stage.batch_identificaciones_incons
       WHERE estado = ''06''
         AND causal = ''04''
         AND id_solicitud = ' || v_sol || ') b
WHERE batch_identificaciones_validas.tipo_id = b.tipo_id
  AND (CASE WHEN COALESCE(rec_vista.f_td_to_number(batch_identificaciones_validas.numero_id), 0) > 0
            THEN CAST(TRIM(batch_identificaciones_validas.numero_id) AS BIGINT)
       END) = b.numero_id_big
  AND batch_identificaciones_validas.id_solicitud = ' || v_sol || '
  AND COALESCE(rec_vista.f_td_to_number(batch_identificaciones_validas.numero_id), 0) > 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'BATCH_CUBO_PERSONA: DELETE ESTADO VALIDAS=''estado 06 y causal 04'' ');

    -- #1: homologacion de numero_id como BIGINT en inconsistencias
    v_sql := 'UPDATE rec_stage.batch_identificaciones_incons
SET numero_id = CAST(CASE WHEN COALESCE(rec_vista.f_td_to_number(numero_id), 0) > 0
                          THEN CAST(TRIM(numero_id) AS BIGINT)
                     END AS VARCHAR(20))
WHERE id_solicitud = ' || v_sol || '
  AND COALESCE(rec_vista.f_td_to_number(numero_id), 0) > 0';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Homologacion Numero_Id as Bigint Incons');
END;
$$;
