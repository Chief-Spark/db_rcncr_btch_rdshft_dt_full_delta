-- ============================================================================
-- Script:   09_sp_batch2_otros.sql                 (2026-10-15, tarea F2-4)
-- Objetivo: Migracion a Redshift de los 4 stored procedures Teradata que
--           quedaban como placeholder en 09_sp_batch2_otros_placeholder.sql:
--
--   PRO_BATCH2_TRANSPUESTA        -> rec_stage.sp_batch2_transpuesta
--   PRO_Batch2_Completitud_Canal  -> rec_stage.sp_batch2_completitud_canal
--   PRO_BATCH2_ESTADISTICAS       -> rec_stage.sp_batch2_estadisticas
--   PRO_BATCH2_CANTREPCANAL_CON   -> rec_stage.sp_batch2_cantrepcanal_con
--
-- Mas rec_stage.sp_batch2_estadisticas_export, que ya estaba migrado con
-- fidelidad alta y se conserva sin cambios de logica.
--
-- Reemplaza a 09_sp_batch2_otros_placeholder.sql (eliminado). El helper
-- sp_batch2_filtro_placeholder desaparece: ya no hay placeholders que lo usen.
--
-- Fuente: Sps_Batch.sql
--   PRO_BATCH2_ESTADISTICAS       lineas 6161-7796  (~1 636)
--   PRO_BATCH2_TRANSPUESTA        lineas 7797-8331  (~  535)
--   PRO_Batch2_Completitud_Canal  lineas 8332-8958  (~  627)
--   PRO_BATCH2_CANTREPCANAL_CON   lineas 8959-9229  (~  271)
--
-- Llamadas originales (parametros reales):
--   P0033_BATCH2_EXPORTVERTPLANO_111.BTQ -> TRANSPUESTA x3 ('Vstg_Batch2_PN',
--     'Vstg_Batch2_PJ' si varARCHIVOS_PN_PJ = 1; si no 'Vstg_Batch2_PNPJ'),
--     solo cuando varOrienta = 'OE_VERTICA'.
--   P0033_BATCH2_CANALCONTACTO_111.BTQ   -> Completitud_Canal (plantilla, solicitud)
--   P0033_BATCH2_ESTADISTICAS_111.BTQ    -> ESTADISTICAS (IDPLANTILLA, IDSOLICITUD)
--   P0033_BATCH2_CANTREPCANAL_111.BTQ    -> CANTREPCANAL_CON (ver B-08)
--
-- ============================================================================
-- CONVENCIONES
-- ============================================================================
-- Se aplican las mismas 7 convenciones documentadas en la cabecera de
-- 08_sp_batch2_procesacubos.sql (firma sin parametros de base ni OUT
-- P_ERROR, SQL dinamico via rec_mtdat.sp_execstring_des, errores por
-- excepcion, tablas de trabajo en rec_stage, requisito COLLATE
-- CASE_INSENSITIVE, traducciones de sintaxis y de semantica).
--
-- Traducciones adicionales que aparecen por primera vez en este archivo:
--
--   XMLAGG(x ORDER BY y)                -> LISTAGG(x, '') WITHIN GROUP (ORDER BY y)
--   SELECT TOP n ...                    -> ... LIMIT n   (al final de la sentencia)
--   REPLACE VIEW                        -> CREATE OR REPLACE VIEW
--   COLLECT STATISTICS COLUMN (c) ON t  -> ANALYZE t (c)
--   CREATE TABLE ... WITH DATA
--     PRIMARY INDEX (a, b)              -> CREATE TABLE ... DISTKEY (a) SORTKEY (a, b) AS ...
--   INSERT INTO t (v1, v2, ...)         -> INSERT INTO t VALUES (v1, v2, ...)
--     (forma posicional de Teradata; en Redshift ese parentesis seria una
--      lista de columnas)
--   HAVING <alias>                      -> HAVING <expresion>  (Redshift no
--     resuelve alias del SELECT en HAVING)
--   CASE que referencia un alias del
--     mismo SELECT                      -> subconsulta anidada
--   REGEXP_REPLACE(s, p, r, 1, 0, 'i')  -> REGEXP_REPLACE(s, p, r, 1, 'i')
--     (Teradata: posicion 1, ocurrencia 0 = todas; Redshift reemplaza todas
--      por defecto y no tiene parametro de ocurrencia)
--
-- SUM(1) OVER (ROWS UNBOUNDED PRECEDING)  -- sin ORDER BY
--   Teradata permite un marco de ventana sin ORDER BY: devuelve un
--   correlativo en el orden fisico de lectura, que no esta definido.
--   Redshift exige ORDER BY para usar un marco. Se reemplaza por
--   ROW_NUMBER() OVER (ORDER BY <llave>) eligiendo la llave que hace que el
--   resultado sea el unico valido:
--     - TRANSPUESTA: ORDER BY id, columnid. El correlativo AUTO_ID se usa
--       despues en LISTAGG(... ORDER BY auto_id) dentro de cada ID, asi que
--       debe coincidir con ID_C = ROW_NUMBER() OVER (PARTITION BY id ORDER BY
--       id, columnid). Con cualquier otro orden el SQL generado sale mal
--       armado.
--     - Completitud_Canal: ORDER BY a.id (es el correlativo de la tabla
--       destino tabla_w1/tabla_w2, cuya unica restriccion es ser unico).
--   DESVIACION DECLARADA: el original es no determinista en este punto; la
--   version Redshift fija un orden. No cambia el resultado funcional.
--
-- COMILLAS ANIDADAS EN Completitud_Canal
--   El fragmento 5 del original anida 3 niveles de comillas y el volcado CSV
--   de Sps_Batch.sql no permite reconstruir el conteo exacto de comillas con
--   certeza. Se implementa el texto OBJETIVO, que es inequivoco por dos vias
--   (la version comentada inmediatamente anterior en el fuente, y el hecho
--   de que la sentencia ensamblada debe ser SQL valido):
--     CASE WHEN TRIM(COALESCE(<campo>, ' '))='' THEN 1 ELSE 0 END  +
--   Para que sea auditable se usa CHR(39) en vez de apilar comillas.
--
-- COMPARACION serie = 1
--   El original compara serie (VARCHAR, de RIGHT(camponuevo,3), p.ej. '001')
--   contra el entero 1; Teradata convierte implicitamente. Se traduce como
--   rec_vista.f_td_to_number(serie) = 1 (misma UDF que ya replica el
--   TO_NUMBER de un argumento).
--
-- ============================================================================
-- BUGS DEL ORIGINAL QUE SE REPLICAN (ver Bugs_Encontrados.md)
-- ============================================================================
--   B-04  Completitud_Canal: el bloque de DIRECCION nunca se ejecuta
--   B-05  ESTADISTICAS: producto cartesiano en el conteo ID_NE
--   B-08  CANTREPCANAL_CON: solicitud y plantilla llegan invertidas
--   B-10  ESTADISTICAS: PARTE_12 repite CIUDAD_DIR_TOTAL
--   B-19  ESTADISTICAS: REC_STAGE hardcodeado junto a P_BDSTAGE (no aplica)
--   B-25  TRANSPUESTA: particion de una sola fila -> SQL sin cerrar
--   B-26  ESTADISTICAS: BATCH2_ESTADISTICAS_TMP se borra y nunca se crea
--   B-27  TRANSPUESTA: BACTH_CAMPOS_2 se crea dos veces
--   B-28  ESTADISTICAS: descripciones de paso copiadas (el log miente)
--   B-30  Completitud_Canal/TRANSPUESTA: rec_stage hardcodeado (no aplica)
-- Ninguno se corrige: la fase 1 debe entregar los mismos resultados.
--
-- ============================================================================
-- DEPENDENCIAS NO SATISFECHAS (ver ddl/10_tablas_trabajo_f2_4.sql)
-- ============================================================================
--   rec_stage.v_ba2_campos_salida          TRANSPUESTA, Completitud_Canal
--   rec_stage.vstg_batch2_pn/_pj/_pnpj     TRANSPUESTA, Completitud_Canal
--   rec_stage.vstg_inconsis_pnpj           ESTADISTICAS
--   rec_stage.batch_cubo_persona11         CANTREPCANAL_CON  (sin DDL conocido)
--   rec_vista.vu_persona / v_tipo_persona  CANTREPCANAL_CON
--   rec_stage.batch_cubo_temp_*_total      ESTADISTICAS (las crea
--                                          estadisticas_cfg desde filas que
--                                          no se han recibido)
--   filas de rec_datos.pro_batch2_filtros_estadisticas    ESTADISTICAS
--   filas TIPO='CANT_REP_CANAL_CONTACTO' de batch_motor_log  CANTREPCANAL_CON
--
-- El codigo esta completo y referencia cada objeto con el mismo nombre que el
-- original. Falta que esos objetos existan para poder ejecutar.
-- ============================================================================


-- ############################################################################
-- PRO_BATCH2_TRANSPUESTA  ->  rec_stage.sp_batch2_transpuesta
-- ############################################################################
-- Objetivo (cabecera del original): transponer los campos del archivo de
-- salida de formato ancho a formato vertical.
--   Entradas: Vstg_Batch2_PNPJ | Vstg_Batch2_PN | Vstg_Batch2_PJ
--   Salidas:  TB_Vstg_Batch2_PNPJ | TB_Vstg_Batch2_PN | TB_Vstg_Batch2_PJ
--             (columnid, columna, valores, tipo_id, numero_id)
--
-- Como lo hace: genera, por cada fila del archivo (ID), una sentencia
-- CREATE TABLE bacth_campos_temp que pivota esa fila a una columna C<ID>
-- mediante un MAX(CASE WHEN ...) armado campo por campo; ejecuta esa
-- sentencia y vuelca el resultado a la tabla TB_* en formato vertical.
--
-- Firma original:
--   (P_Lote, P_StartTimeStampPadre, P_Nombre_Proceso_Padre, P_BDDATOS,
--    P_BDVISTA, P_BDSTAGE, P_Batch2_PNPJ, OUT P_ERROR)
--
-- SEGURIDAD: p_batch2_pnpj se interpola en SQL dinamico. El original acepta
-- cualquier texto; aqui se valida contra la lista de los 3 valores que el
-- BTQ puede pasar. Para esos 3 valores el comportamiento es identico.
-- ############################################################################
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_transpuesta(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_batch2_pnpj     VARCHAR(30)     -- 'vstg_batch2_pn' | 'vstg_batch2_pj' | 'vstg_batch2_pnpj'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql     VARCHAR(65535);
    v_vista   VARCHAR(100) := LOWER(BTRIM(p_batch2_pnpj));
    v_tb      VARCHAR(100);
    v_prefijo VARCHAR(1000);
    v_sufijo  VARCHAR(1000);
    r         RECORD;
BEGIN
    IF v_vista NOT IN ('vstg_batch2_pn', 'vstg_batch2_pj', 'vstg_batch2_pnpj') THEN
        RAISE EXCEPTION 'sp_batch2_transpuesta: vista no permitida: %', v_vista;
    END IF;
    v_tb := 'rec_stage.tb_' || v_vista;

    ------------------------------------------------------------------------
    -- 1. bacth_campos: lista de columnas a transponer, tomada del catalogo
    --    de campos de la plantilla.
    --    Original: rec_stage.v_ba2_Campos_Salida hardcodeado en minusculas,
    --    ignorando P_BDSTAGE (B-30).
    --    Sin PRIMARY INDEX explicito -> Teradata usa la primera columna.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos');

    v_sql := 'CREATE TABLE rec_stage.bacth_campos DISTKEY (columnid) AS '
          || '(SELECT ordenamiento AS columnid '
          || '       ,CASE WHEN xalias = ''CBPER'' THEN valor_ini ELSE camponuevo END AS campos '
          || ' FROM rec_stage.v_ba2_campos_salida)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_CAMPOS');

    ------------------------------------------------------------------------
    -- 2. tb_<vista>: tabla destino en formato vertical.
    --    Original: PRIMARY INDEX(NUMERO_ID, COLUMNID). Redshift admite una
    --    sola columna de distribucion -> DISTKEY(numero_id) + SORTKEY de las dos.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, v_tb);

    v_sql := 'CREATE TABLE ' || v_tb || ' ('
          || '  columnid   INTEGER'
          || ' ,columna    VARCHAR(30)'
          || ' ,valores    VARCHAR(1000)'
          || ' ,tipo_id    VARCHAR(10)'
          || ' ,numero_id  VARCHAR(20)'
          || ') DISTKEY (numero_id) SORTKEY (numero_id, columnid)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla .TB_' || p_batch2_pnpj);

    ------------------------------------------------------------------------
    -- 3. bacth_campos_1: una fila por (fila del archivo x campo), con el
    --    fragmento de SQL correspondiente. La primera fila de cada ID lleva
    --    el prefijo (CREATE TABLE ... MAX(CASE) y la ultima el sufijo
    --    (END) AS C<id> FROM ... GROUP BY 1,2).
    --
    --    B-25: el CASE evalua primero ID_C = MIN_ID. Si la particion tiene
    --    una sola fila (MIN_ID = MAX_ID), gana el prefijo y el sufijo nunca
    --    se agrega -> sentencia sin cerrar. Se replica.
    --
    --    MIN_ID/MAX_ID son alias del mismo SELECT: Teradata los resuelve,
    --    Redshift no -> se anida una subconsulta mas (solo sintaxis).
    ------------------------------------------------------------------------
    v_prefijo := 'CREATE TABLE rec_stage.bacth_campos_temp DISTKEY (columnid) AS '
              || '(SELECT columnid, campos, MAX(CASE ';
    v_sufijo  := ' END) AS c';

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos_1');

    v_sql := 'CREATE TABLE rec_stage.bacth_campos_1 DISTKEY (id) SORTKEY (id, columnid) AS ('
          || ' SELECT auto_id, id, columnid, max_id, min_id, max_table'
          || '      , CASE WHEN id_c = min_id'
          || '             THEN ' || QUOTE_LITERAL(v_prefijo) || ' || sql_1'
          || '             WHEN id_c = max_id'
          || '             THEN sql_1 || ' || QUOTE_LITERAL(v_sufijo)
          || '                  || BTRIM(CAST(id AS VARCHAR(20)))'
          || '                  || '' FROM rec_stage.bacth_campos BC'
          || '                      CROSS JOIN rec_stage.' || v_vista || ' T GROUP BY 1,2)'''
          || '             ELSE sql_1 END AS sql_2'
          || ' FROM ('
          || '   SELECT auto_id, id, columnid, id_c, sql_1'
          || '        , MAX(id_c)   OVER (PARTITION BY id) AS max_id'
          || '        , MIN(id_c)   OVER (PARTITION BY id) AS min_id'
          || '        , MAX(auto_id) OVER ()               AS max_table'
          || '   FROM ('
          || '     SELECT ROW_NUMBER() OVER (ORDER BY T.id, BC.columnid)              AS auto_id'
          || '          , T.id'
          || '          , BC.columnid'
          || '          , ROW_NUMBER() OVER (PARTITION BY T.id ORDER BY T.id, BC.columnid) AS id_c'
          -- CHR(39) = comilla simple, para que el anidamiento sea auditable.
          -- Produce:  WHEN T.id=<id> AND TRIM(campos) ='<campos>' THEN T.<campos>
          || '          , ''WHEN T.id='' || BTRIM(CAST(T.id AS VARCHAR(20)))'
          || '            || '' AND TRIM(campos) ='' || CHR(39) || BTRIM(BC.campos) || CHR(39)'
          || '            || '' THEN T.'' || BC.campos                               AS sql_1'
          || '     FROM rec_stage.bacth_campos BC'
          || '     CROSS JOIN rec_stage.' || v_vista || ' T'
          || '   ) A'
          || ' ) B)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_CAMPOS_1');

    ------------------------------------------------------------------------
    -- 4. bacth_campos_2: concatena los fragmentos de cada ID.
    --    XMLAGG(SQL_2 ORDER BY AUTO_ID) -> LISTAGG.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos_2');

    v_sql := 'CREATE TABLE rec_stage.bacth_campos_2 DISTKEY (id) AS ('
          || ' SELECT id, LISTAGG(sql_2, '' '') WITHIN GROUP (ORDER BY auto_id) AS sql_trans'
          || ' FROM rec_stage.bacth_campos_1'
          || ' GROUP BY id)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_CAMPOS_2');

    ------------------------------------------------------------------------
    -- 5. B-27: el original borra y recrea bacth_campos_2 con el MISMO DDL.
    --    El bloque lleva el comentario '-- Borrado de tabla temporal
    --    BACTH_HOMG_3' pero opera sobre BACTH_CAMPOS_2. Trabajo
    --    desperdiciado; se replica para conservar el mismo rastro en el log.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos_2');
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_CAMPOS_2');

    ------------------------------------------------------------------------
    -- 6. bacth_campos_3: tabla tipada (no CTAS) + INSERT desde _2.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos_3');

    v_sql := 'CREATE TABLE rec_stage.bacth_campos_3 (id INTEGER, sql_trans VARCHAR(64000))';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BACTH_CAMPOS_3');

    v_sql := 'INSERT INTO rec_stage.bacth_campos_3 SELECT id, sql_trans FROM rec_stage.bacth_campos_2';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'INSERT Tabla BACTH_CAMPOS_3');

    ------------------------------------------------------------------------
    -- 7. Cursor: por cada fila del archivo, ejecutar el CREATE generado y
    --    volcar el pivote a la tabla vertical.
    --    Original: PREPARE + NO SCROLL CURSOR sobre BACTH_CAMPOS_3 ORDER BY ID.
    ------------------------------------------------------------------------
    FOR r IN
        SELECT BTRIM(CAST(id AS VARCHAR(20))) AS id_txt, sql_trans
        FROM rec_stage.bacth_campos_3
        ORDER BY id
    LOOP
        CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.bacth_campos_temp');

        -- La sentencia viene armada en bacth_campos_3
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, r.sql_trans,
             'Crea tabla rec_stage.' || r.sql_trans || ';');

        v_sql := 'INSERT INTO ' || v_tb
              || ' SELECT T1.columnid'
              || '      , T1.campos'
              || '      , T2.c' || r.id_txt
              || '      , MAX(CASE WHEN T1.campos = ''Tipo_Id''   THEN T2.c' || r.id_txt || ' END) OVER ()'
              || '      , MAX(CASE WHEN T1.campos = ''Numero_Id'' THEN T2.c' || r.id_txt || ' END) OVER ()'
              || ' FROM rec_stage.bacth_campos T1'
              || ' LEFT JOIN rec_stage.bacth_campos_temp T2 ON T1.columnid = T2.columnid';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'INSERT TABLA ' || p_batch2_pnpj);
    END LOOP;
END;
$$;


-- ############################################################################
-- PRO_Batch2_Completitud_Canal  ->  rec_stage.sp_batch2_completitud_canal
-- ############################################################################
-- Objetivo (cabecera del original): "Batch2 - Determinar Inconsistentes
-- Completitud x Canal". Alimenta el archivo de ALERTAS.
--
-- Como lo hace: por cada canal (telefono, direccion) arma dinamicamente
--   (a) un CREATE TABLE tabla_w1 / tabla_w2 con una columna por campo del
--       canal, y
--   (b) un INSERT ... SELECT que se queda con las personas en las que al
--       menos uno de esos campos viene vacio
--       (SUM de CASE WHEN TRIM(COALESCE(campo,' '))='' THEN 1 ELSE 0 END > 0).
-- El SQL se ensambla por fragmentos en w_borrar_002, se consolida con
-- XMLAGG en w_ejecutor y se ejecuta.
--
-- Firma original:
--   (P_Lote, P_StartTimeStampPadre, P_Nombre_Proceso_Padre, P_BDVISTA,
--    P_BDSTAGE, P_BDDATOS, P_PLANTILLA, P_SOLICITUD, OUT P_ERROR)
-- p_id_plantilla y p_id_solicitud se conservan en la firma aunque el cuerpo
-- del original NO los usa en ninguna sentencia (el universo sale de las
-- vistas Vstg_Batch2_*, que ya vienen filtradas por la solicitud activa).
--
-- PREAMBULO INCORPORADO: en Teradata, w_Borrar_002 y w_Ejecutor las borra y
-- recrea el paso BTEQ P0033_BATCH2_CANALCONTACTO_111.BTQ (labels CREA2 y
-- CREA3), que tambien borra tabla_w1 y tabla_w2, antes de llamar al SP. En
-- Redshift no hay un paso BTEQ, asi que ese preambulo se ejecuta al inicio
-- de este procedure. El DDL es el mismo (ver ddl/10_tablas_trabajo_f2_4.sql).
--
-- B-04 (REPLICADO): los dos bucles tienen la condicion original
--   "WHILE (V_ITERA <= V_INDICE)" comentada y reemplazada por una fija:
--     TELEFONO  : SET V_ITERA = 1 ... WHILE (V_ITERA = 1)  -> 1 iteracion
--     DIRECCION : SET V_ITERA = 1 ... WHILE (V_ITERA = 2)  -> 0 iteraciones
--   Es decir: solo se evalua la serie 1 del telefono, y el canal direccion
--   no se evalua nunca (tabla_w2 queda creada y vacia). NO SE CORRIGE.
-- ############################################################################
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_completitud_canal(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_plantilla    BIGINT,
    p_id_solicitud    BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql     VARCHAR(65535);
    v_cadena  VARCHAR(65535);
    v_indice  INTEGER;
    v_itera   INTEGER;
BEGIN
    ------------------------------------------------------------------------
    -- 0. Preambulo del BTQ P0033_BATCH2_CANALCONTACTO_111 (labels CREA2/CREA3)
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.w_borrar_002');
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'CREATE TABLE rec_stage.w_borrar_002 (secuencia INTEGER, detalle VARCHAR(10000)) '
      || 'DISTKEY (secuencia) SORTKEY (secuencia)',
         'Crea Tabla w_Borrar_002');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.w_ejecutor');
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'CREATE TABLE rec_stage.w_ejecutor (secuencia INTEGER, campo VARCHAR(10000)) '
      || 'DISTKEY (secuencia) SORTKEY (secuencia)',
         'Crea Tabla w_Ejecutor');

    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tabla_w1');
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.tabla_w2');

    ------------------------------------------------------------------------
    -- 1. v_datos_tmp1: universo de filas del archivo de salida.
    --    B-30: el original crea la vista en P_BDSTAGE pero une
    --    rec_stage.Vstg_Batch2_* hardcodeado. En Redshift es lo mismo.
    --    UNION (no UNION ALL): desduplica, igual que el original.
    ------------------------------------------------------------------------
    v_sql := 'CREATE OR REPLACE VIEW rec_stage.v_datos_tmp1 AS '
          || 'SELECT * FROM rec_stage.vstg_batch2_pnpj '
          || 'UNION SELECT * FROM rec_stage.vstg_batch2_pj '
          || 'UNION SELECT * FROM rec_stage.vstg_batch2_pn';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea vista en STAGE v_Datos_tmp1');

    ------------------------------------------------------------------------
    -- 2. v_telefono_tmp1: campos del canal telefono, con su numero de serie
    --    (las 3 ultimas posiciones de camponuevo: '001', '002', ...) y un
    --    orden dentro de la serie (0 = el numero, 1 = los complementarios).
    --    Se acota a las series que realmente existen (count de DT_NUM).
    ------------------------------------------------------------------------
    v_sql := 'CREATE OR REPLACE VIEW rec_stage.v_telefono_tmp1 AS '
          || 'SELECT Y.*, ROW_NUMBER() OVER (ORDER BY serie, orden, codigo_campo) AS q '
          || 'FROM ( '
          || '  SELECT X.* FROM (SELECT xalias, codigo_campo, camponuevo, RIGHT(camponuevo,3) AS serie, 0 AS orden '
          || '                   FROM rec_stage.v_ba2_campos_salida) AS X '
          || '  WHERE codigo_campo IN (''DT_NUM'') '
          || '  UNION '
          || '  SELECT X.* FROM (SELECT xalias, codigo_campo, camponuevo, RIGHT(camponuevo,3) AS serie, 1 AS orden '
          || '                   FROM rec_stage.v_ba2_campos_salida) AS X '
          || '  WHERE codigo_campo IN (''DT_CIUDAD'',''DT_DEPARTA'',''DT_DAN_CIU'',''DT_DAN_DEP'',''DT_INDICAT'',''DT_TIPO'') '
          || ') AS Y '
          || 'WHERE rec_vista.f_td_to_number(serie) <= '
          || '      (SELECT COUNT(*) AS cont FROM rec_stage.v_ba2_campos_salida WHERE codigo_campo IN (''DT_NUM''))';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea vista en STAGE v_Telefono_tmp1');

    ------------------------------------------------------------------------
    -- 3. v_direccion_tmp1: lo mismo para el canal direccion.
    --    NOTA: el original pone "group by 1,2,3" solo en la segunda rama de
    --    esta vista (no en la de telefono). Asimetria del original; se
    --    replica literalmente.
    ------------------------------------------------------------------------
    v_sql := 'CREATE OR REPLACE VIEW rec_stage.v_direccion_tmp1 AS '
          || 'SELECT Y.*, ROW_NUMBER() OVER (ORDER BY serie, orden, codigo_campo) AS q '
          || 'FROM ( '
          || '  SELECT X.* FROM (SELECT xalias, codigo_campo, camponuevo, RIGHT(camponuevo,3) AS serie, 0 AS orden '
          || '                   FROM rec_stage.v_ba2_campos_salida) AS X '
          || '  WHERE codigo_campo IN (''DD_DIR'') '
          || '  UNION '
          || '  SELECT X.* FROM (SELECT xalias, codigo_campo, camponuevo, RIGHT(camponuevo,3) AS serie, 1 AS orden '
          || '                   FROM rec_stage.v_ba2_campos_salida GROUP BY 1,2,3) AS X '
          || '  WHERE codigo_campo IN (''DD_CIUDAD'',''DD_DEPARTA'',''DD_DAN_CIU'',''DD_DAN_DEP'',''DD_TIPO'') '
          || ') AS Y '
          || 'WHERE rec_vista.f_td_to_number(serie) <= '
          || '      (SELECT COUNT(*) AS cont FROM rec_stage.v_ba2_campos_salida WHERE codigo_campo IN (''DD_DIR''))';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea vista en STAGE v_Direccion_tmp1');

    ------------------------------------------------------------------------
    -- 4. TELEFONO: armar y ejecutar el CREATE TABLE tabla_w1 dinamico.
    ------------------------------------------------------------------------
    v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
          || 'SELECT 1, '' CREATE TABLE rec_stage.tabla_w1 ( secuencia INTEGER,  id INTEGER '' '
          || 'FROM rec_stage.secuencia A WHERE secuencia = 1 '
          || 'UNION '
          || 'SELECT CAST((1 + alfa) AS INTEGER), '','' || A.codigo_campo || ''  varchar(100)    '' '
          || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
          || '      FROM rec_stage.v_telefono_tmp1 B '
          || '      WHERE rec_vista.f_td_to_number(serie) = 1) A '
          || 'UNION '
          || 'SELECT 99, '' )  DISTKEY (secuencia)  '' '
          || 'FROM rec_stage.secuencia C WHERE secuencia = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea Sentencia en STAGE w_borrar_002');

    v_sql := 'INSERT INTO rec_stage.w_ejecutor '
          || 'SELECT 1, LISTAGG(detalle, '' '') WITHIN GROUP (ORDER BY secuencia) FROM rec_stage.w_borrar_002';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea vista en STAGE Dinamico 2');

    -- Original: Select campo into :V_CADENA from REC_STAGE.w_Ejecutor ;
    SELECT campo INTO v_cadena FROM rec_stage.w_ejecutor;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_cadena,
         'Crea Tabla en STAGE tabla_w1');

    ------------------------------------------------------------------------
    -- 5. Bucle TELEFONO. v_indice se calcula igual que el original y queda
    --    SIN USAR (B-04): la condicion es "v_itera = 1", no "<= v_indice".
    ------------------------------------------------------------------------
    v_itera := 1;
    SELECT COUNT(*) INTO v_indice FROM rec_stage.v_telefono_tmp1 WHERE codigo_campo = 'DT_NUM';

    WHILE v_itera = 1 LOOP
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
             'DELETE FROM rec_stage.w_borrar_002', 'Delete REC_STAGE.w_borrar_002 TT');
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
             'DELETE FROM rec_stage.w_ejecutor', 'Delete REC_STAGE.w_borrar_002 TT');

        -- fragmento 1: cabecera del INSERT (TOP 100 -> LIMIT 100 al final)
        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT 1, '' INSERT INTO rec_stage.tabla_w1 SELECT ROW_NUMBER() OVER (ORDER BY A.id) '
              || '+ B.secuencia AS auto_id, A.id '' '
              || 'FROM rec_stage.secuencia A WHERE secuencia = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-1 TT');

        -- fragmento 3: una columna por campo del canal (el original no tiene
        -- fragmento 2: quedo comentado en el fuente)
        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT (1 + alfa), '', A.'' || camponuevo '
              || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
              || '      FROM rec_stage.v_telefono_tmp1 '
              || '      WHERE rec_vista.f_td_to_number(serie) = 1) A';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-3 TT');

        -- fragmento 4: FROM + apertura del predicado
        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT ROW_NUMBER() OVER (ORDER BY B.secuencia) + B.secuencia AS auto_id '
              || '     , ''FROM rec_stage.v_datos_tmp1 A , (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.tabla_w1) B '
              || '        WHERE A.id IN ( SELECT id FROM rec_stage.v_datos_tmp1 WHERE ( '' '
              || 'FROM (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.w_borrar_002) B';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-4 TT');

        -- fragmento 5: un sumando por campo. CHR(39) = comilla simple, para
        -- que el anidamiento sea auditable (ver nota de la cabecera).
        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT ROW_NUMBER() OVER (ORDER BY A.alfa) + B.secuencia AS auto_id '
              || '     , ''CASE WHEN TRIM(COALESCE('' || A.camponuevo || '', '' || CHR(39) || '' '' || CHR(39) '
              || '       || ''))='' || CHR(39) || CHR(39) || '' THEN 1 ELSE 0 END  + '' '
              || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
              || '      FROM rec_stage.v_telefono_tmp1 '
              || '      WHERE rec_vista.f_td_to_number(serie) = 1) A '
              || '   , (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.w_borrar_002) B';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-5 TT');

        -- fragmento 6: cierre. El 0 final absorbe el ultimo '+'.
        v_sql := 'INSERT INTO rec_stage.w_borrar_002 SELECT 99, '' 0 ) > 0 ) LIMIT 100''';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-6 TT');

        v_sql := 'INSERT INTO rec_stage.w_ejecutor '
              || 'SELECT 2, LISTAGG(detalle, '' '') WITHIN GROUP (ORDER BY secuencia) FROM rec_stage.w_borrar_002';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_Ejecutor-1 TT');

        SELECT campo INTO v_cadena FROM rec_stage.w_ejecutor WHERE secuencia = 2;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_cadena,
             'Insert REC_STAGE.w_Ejecutor-2 TT');

        v_itera := v_itera + 1;
    END LOOP;

    ------------------------------------------------------------------------
    -- 6. Limpieza entre canales
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'DELETE FROM rec_stage.w_borrar_002', 'Delete REC_STAGE.w_borrar_002 DD');
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'DELETE FROM rec_stage.w_ejecutor', 'Delete REC_STAGE.w_borrar_002 DD');

    ------------------------------------------------------------------------
    -- 7. DIRECCION: armar y ejecutar el CREATE TABLE tabla_w2 dinamico.
    --    Este bloque SI se ejecuta; lo que no se ejecuta es el bucle (paso 8).
    ------------------------------------------------------------------------
    v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
          || 'SELECT 1, '' CREATE TABLE rec_stage.tabla_w2 ( secuencia INTEGER,  id INTEGER '' '
          || 'FROM rec_stage.secuencia A WHERE secuencia = 1 '
          || 'UNION '
          || 'SELECT CAST((1 + alfa) AS INTEGER), '','' || A.codigo_campo || ''  varchar(100)    '' '
          || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
          || '      FROM rec_stage.v_direccion_tmp1 B '
          || '      WHERE rec_vista.f_td_to_number(serie) = 1) A '
          || 'UNION '
          || 'SELECT 99, '' )  DISTKEY (secuencia)  '' '
          || 'FROM rec_stage.secuencia C WHERE secuencia = 1';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea Sentencia en STAGE w_borrar_002 DD');

    v_sql := 'INSERT INTO rec_stage.w_ejecutor '
          || 'SELECT 1, LISTAGG(detalle, '' '') WITHIN GROUP (ORDER BY secuencia) FROM rec_stage.w_borrar_002';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea vista en STAGE Dinamico 2 DD');

    SELECT campo INTO v_cadena FROM rec_stage.w_ejecutor;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_cadena,
         'Crea Tabla en STAGE tabla_w2 DD');

    ------------------------------------------------------------------------
    -- 8. Bucle DIRECCION. B-04: v_itera se reinicia en 1 y la condicion es
    --    "= 2", asi que el cuerpo NO se ejecuta nunca. tabla_w2 queda
    --    creada y vacia. Se deja escrito el bucle, igual que el original,
    --    para que la correccion futura sea un cambio de una linea.
    ------------------------------------------------------------------------
    v_itera := 1;
    SELECT COUNT(*) INTO v_indice FROM rec_stage.v_direccion_tmp1 WHERE codigo_campo = 'DD_DIR';

    WHILE v_itera = 2 LOOP
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
             'DELETE FROM rec_stage.w_borrar_002', 'Delete REC_STAGE.w_borrar_002 DD');
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
             'DELETE FROM rec_stage.w_ejecutor', 'Delete REC_STAGE.w_borrar_002 DD');

        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT 1, '' INSERT INTO rec_stage.tabla_w2 SELECT ROW_NUMBER() OVER (ORDER BY A.id) '
              || '+ B.secuencia AS auto_id, A.id '' '
              || 'FROM rec_stage.secuencia A WHERE secuencia = 1';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-1 DD');

        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT (1 + alfa), '', A.'' || camponuevo '
              || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
              || '      FROM rec_stage.v_direccion_tmp1 '
              || '      WHERE rec_vista.f_td_to_number(serie) = 1) A';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-3 DD');

        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT ROW_NUMBER() OVER (ORDER BY B.secuencia) + B.secuencia AS auto_id '
              || '     , ''FROM rec_stage.v_datos_tmp1 A , (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.tabla_w2) B '
              || '        WHERE A.id IN ( SELECT id FROM rec_stage.v_datos_tmp1 WHERE ( '' '
              || 'FROM (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.w_borrar_002) B';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-4 DD');

        v_sql := 'INSERT INTO rec_stage.w_borrar_002 '
              || 'SELECT ROW_NUMBER() OVER (ORDER BY A.alfa) + B.secuencia AS auto_id '
              || '     , ''CASE WHEN TRIM(COALESCE('' || A.camponuevo || '', '' || CHR(39) || '' '' || CHR(39) '
              || '       || ''))='' || CHR(39) || CHR(39) || '' THEN 1 ELSE 0 END  + '' '
              || 'FROM (SELECT codigo_campo, camponuevo, orden, q AS alfa '
              || '      FROM rec_stage.v_direccion_tmp1 '
              || '      WHERE rec_vista.f_td_to_number(serie) = 1) A '
              || '   , (SELECT COALESCE(MAX(secuencia),0) secuencia FROM rec_stage.w_borrar_002) B';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-5 DD');

        v_sql := 'INSERT INTO rec_stage.w_borrar_002 SELECT 99, '' 0 ) > 0 ) LIMIT 100''';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_borrar_002-6 DD');

        v_sql := 'INSERT INTO rec_stage.w_ejecutor '
              || 'SELECT 2, LISTAGG(detalle, '' '') WITHIN GROUP (ORDER BY secuencia) FROM rec_stage.w_borrar_002';
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Insert REC_STAGE.w_Ejecutor-1 DD');

        SELECT campo INTO v_cadena FROM rec_stage.w_ejecutor WHERE secuencia = 2;
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_cadena,
             'Insert REC_STAGE.w_Ejecutor-2 DD');

        v_itera := v_itera + 1;
    END LOOP;
END;
$$;


-- ############################################################################
-- PRO_BATCH2_CANTREPCANAL_CON  ->  rec_stage.sp_batch2_cantrepcanal_con
-- ############################################################################
-- Objetivo (cabecera del original): "Insertar en la tabla
-- BATCH_ESTADISTICAS_PRO el top 100 de registros repetidos por canal de
-- contacto".
--
-- Estructura: 2 tablas de trabajo + un motor de SQL guardado como datos
-- (mismo patron que ARCHIVO_LOG y ESTADISTICAS_CFG): recorre
-- BATCH_MOTOR_LOG WHERE TIPO = 'CANT_REP_CANAL_CONTACTO' ORDER BY ID,
-- reemplaza marcadores, borra la tabla DATO si existe y ejecuta SQL_STRING.
--
-- Firma original:
--   (P_Lote, P_StartTimeStampPadre, P_Nombre_Proceso_Padre, P_BDDATOS,
--    P_BTTVISTA, P_BDSTAGE, P_ID_SOLICITUD, P_ID_PLANTILLA,
--    P_CDATOS_SDATOS, OUT P_ERROR)
--
-- Marcadores que sustituye (orden del original): P_StartTimeStampPadre,
-- P_BDDATOS, P_BTTVISTA, P_BDSTAGE, P_ID_SOLICITUD, P_ID_PLANTILLA,
-- P_CDATOS_SDATOS. Notese que aqui el 3er marcador es P_BTTVISTA (no
-- P_BDVISTA como en ESTADISTICAS_CFG).
--
-- B-08 (REPLICADO): P0033_BATCH2_CANTREPCANAL_111.BTQ pasa
--   ${varPLANTILLA} al parametro P_ID_SOLICITUD y ${varSOLICITUD} al
--   parametro P_ID_PLANTILLA. El cruce se mantiene en el ORQUESTADOR
--   (10_sp_batch2_proceso_batch2.sql), no aqui: este procedure respeta su
--   propia firma, igual que el SP de Teradata.
--
-- DEPENDENCIA DE DATOS: las filas TIPO='CANT_REP_CANAL_CONTACTO' de
-- rec_stage.batch_motor_log NO se han recibido (Dlls-Batch/Dll_Btach.csv
-- solo trae las 18 filas TIPO='LOG'). Sin esas filas el bucle no itera y el
-- procedure no hace nada mas que crear las dos tablas de trabajo.
-- Es el insumo #1 de la lista del 14-oct.
-- ############################################################################
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_cantrepcanal_con(
    p_lote             BIGINT,
    p_nombre_proceso   VARCHAR(100),
    p_start_timestamp  TIMESTAMP,
    p_id_solicitud     BIGINT,
    p_id_plantilla     BIGINT,
    p_cdatos_sdatos    VARCHAR(2)     -- '${P_CDATOS_SDATOS}' del .par
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_ts   VARCHAR(20) := TO_CHAR(p_start_timestamp, 'YYYY-MM-DD HH24:MI:SS') || '.';
    v_sol  VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    v_pla  VARCHAR(20) := CAST(p_id_plantilla AS VARCHAR(20));
    r      RECORD;
BEGIN
    ------------------------------------------------------------------------
    -- 1. batch2tipodoc: tipo de persona (natural/juridica) por tipo de
    --    identificacion, desde las vistas del DW.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2tipodoc');

    v_sql := 'CREATE TABLE rec_stage.batch2tipodoc DISTSTYLE ALL AS '
          || '(SELECT a.cod_tipo_ident_fte'
          || '      , UPPER(BTRIM(b.nombre_tipo_persona)) AS nombre_tipo_persona '
          || ' FROM rec_vista.vu_persona a '
          || ' LEFT JOIN rec_vista.v_tipo_persona b '
          || '        ON a.cod_dw_tipo_persona = b.cod_dw_tipo_persona '
          || ' GROUP BY 1,2)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BATCH2TIPODOC');

    ------------------------------------------------------------------------
    -- 2. batch2personadoc: tipo de persona por PIN, quedandose con el
    --    primer id_auto de cada PIN.
    --    QUALIFY ROW_NUMBER() -> subconsulta (Redshift soporta QUALIFY, pero
    --    aqui se deja explicito por legibilidad del filtro = 1).
    --    Lee rec_stage.batch_cubo_persona11, cuyo DDL NO esta en el workspace.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2personadoc');

    v_sql := 'CREATE TABLE rec_stage.batch2personadoc DISTKEY (cod_pin_persona) AS '
          || '(SELECT cod_pin_persona, nombre_tipo_persona FROM ('
          || '   SELECT bcp.cod_pin_persona'
          || '        , btd.nombre_tipo_persona'
          || '        , ROW_NUMBER() OVER (PARTITION BY bcp.cod_pin_persona ORDER BY bcp.id_auto) AS rn'
          || '   FROM rec_stage.batch_cubo_persona11 bcp'
          || '   INNER JOIN rec_stage.batch2tipodoc btd'
          || '           ON bcp.tipo_id = btd.cod_tipo_ident_fte'
          || ' ) q WHERE rn = 1)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Crea Tabla BATCH2PERSONADOC');

    ------------------------------------------------------------------------
    -- 3. Motor: recorrer las filas CANT_REP_CANAL_CONTACTO y ejecutarlas.
    ------------------------------------------------------------------------
    FOR r IN
        SELECT dato, sql_string
        FROM rec_stage.batch_motor_log
        WHERE sql_string IS NOT NULL
          AND tipo = 'CANT_REP_CANAL_CONTACTO'
        ORDER BY id
    LOOP
        -- El original borra la tabla cuyo nombre esta en DATO, siempre (no
        -- solo cuando la sentencia es un CREATE, a diferencia de
        -- ESTADISTICAS_CFG).
        CALL rec_mtdat.sp_drop_tabla_por_nombre(p_lote, p_nombre_proceso, r.dato);

        v_sql := REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                 REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                     r.sql_string
                    ,'P_StartTimeStampPadre', COALESCE(v_ts, ''), 1, 'c')
                    ,'P_BDDATOS',  'rec_datos', 1, 'c')
                    ,'P_BTTVISTA', 'rec_vista', 1, 'c')
                    ,'P_BDSTAGE',  'rec_stage', 1, 'c')
                    ,'P_ID_SOLICITUD', v_sol, 1, 'c')
                    ,'P_ID_PLANTILLA', v_pla, 1, 'c')
                    ,'P_CDATOS_SDATOS', COALESCE(p_cdatos_sdatos, ''), 1, 'c');

        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Se realiza ' || r.dato || ';');
    END LOOP;
END;
$$;


-- ############################################################################
-- PRO_BATCH2_ESTADISTICAS  ->  rec_stage.sp_batch2_estadisticas
-- ############################################################################
-- Objetivo: poblar rec_datos.batch_estadisticas_pro con todos los contadores
-- del archivo de ALERTAS, y dejar creada la vista
-- rec_stage.vstg_batch_estadisticas_exp que ese archivo exporta.
--
-- Estructura: secuencia lineal de ~25 bloques "armar SQL ->
-- sp_execstring_des", intercalada con 16 delegaciones al motor
-- sp_batch2_estadisticas_cfg (una por PARTE). No tiene cursores.
--
-- Firma original:
--   (P_Lote, P_StartTimeStampPadre, P_Nombre_Proceso_Padre, P_BDVISTA,
--    P_BDSTAGE, P_BDDATOS, P_PLANTILLA, P_SOLICITUD, OUT P_ERROR)
--
-- Las 16 PARTE que delega (la 17a, 'CONTEO_TIPO_DOC', esta comentada en el
-- original desde 2022-01-27 y aqui tambien):
--   SQL-PARAM, ESTADISTICAS, TMP_ESTADISTICAS, ESTADIS_EDAD, CIUDAD_DIR,
--   TELEFONO_DIR, GENERO, DIR_POR_IDENT, TEL_POR_IDENT, ESTADIS_DIR,
--   ESTADIS_TEL, ESTAD_ESTRATO, CIIU, DISTRIB_INGRESOS, DISTRIB_EGRESOS,
--   CANT_INGRESOS, CANT_EGRESOS
--
-- DEPENDENCIA DE DATOS CRITICA: tanto las 16 delegaciones como 4 de los
-- UPDATE inline leen rec_datos.pro_batch2_filtros_estadisticas, cuyas filas
-- NO se han recibido (insumo #2 de la lista del 14-oct). Sin ellas:
--   - las 16 PARTE no ejecutan nada,
--   - los UPDATE de CAUSAL/ESTADO/ubicaciones no encuentran criterios,
--   - batch_cubo_temp_*_total no existe y el bloque CON_DIR/CON_TEL/
--     CON_CEL/CON_EMAIL falla.
-- El codigo esta completo; el resultado funcional depende de ese insumo.
--
-- BUGS REPLICADOS: B-05 (cartesiano ID_NE), B-10 (PARTE_12 repetida),
-- B-19 (REC_STAGE hardcodeado), B-26 (tabla que se borra y nunca se crea),
-- B-28 (descripciones de paso copiadas).
--
-- RIESGO NO VERIFICADO: ANALYZE dentro de un stored procedure. Mismo riesgo
-- ya anotado para procedures/08 (ver VERIFICACION.md).
-- ############################################################################
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_estadisticas(
    p_lote             BIGINT,
    p_nombre_proceso   VARCHAR(100),
    p_start_timestamp  TIMESTAMP,
    p_id_plantilla     BIGINT,
    p_id_solicitud     BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
    v_sol  VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    v_pla  VARCHAR(20) := CAST(p_id_plantilla AS VARCHAR(20));
BEGIN
    ------------------------------------------------------------------------
    -- B-26: el original borra batch2_estadisticas_tmp, que NUNCA se crea en
    -- este SP. Codigo muerto; se conserva para mantener el rastro del log.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch2_estadisticas_tmp');

    -- GENERA CONTADORES
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp,
         p_id_plantilla, p_id_solicitud, 'SQL-PARAM');

    ------------------------------------------------------------------------
    -- Materializacion de la vista de inconsistencias.
    -- B-28: el original etiqueta este paso 'Crea Tabla BATCH2_ESTADISTICAS_TMP'.
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.vstg_inconsis_pnpj_tabla');

    v_sql := 'CREATE TABLE rec_stage.vstg_inconsis_pnpj_tabla AS '
          || '(SELECT * FROM rec_stage.vstg_inconsis_pnpj)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea Tabla BATCH2_ESTADISTICAS_TMP');

    ------------------------------------------------------------------------
    -- GENERALES PROC: universo de PIN unicos. B-28 otra vez (misma etiqueta).
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch_cubo_persona_unico');

    v_sql := 'CREATE TABLE rec_stage.batch_cubo_persona_unico DISTKEY (cod_pin_persona) AS '
          || '(SELECT cod_pin_persona FROM rec_stage.batch_cubo_persona GROUP BY 1)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Crea Tabla BATCH2_ESTADISTICAS_TMP');

    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp,
         p_id_plantilla, p_id_solicitud, 'ESTADISTICAS');

    -- CUBOS TEMPORALES (crea batch_cubo_temp_dir_total / _telefono_total /
    -- _celular_total / _correo_total)
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp,
         p_id_plantilla, p_id_solicitud, 'TMP_ESTADISTICAS');

    ------------------------------------------------------------------------
    -- PROC GENERALES: reset de contadores
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro SET conteo = 0 '
          || 'WHERE id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Tabla CONTEO');

    ------------------------------------------------------------------------
    -- batch_tmp_calculo_con_datos: una fila por persona que tiene al menos
    -- un canal con dato, con el ORIGEN del primer canal encontrado. El
    -- orden de prelacion es el del original: DIRECCION, CELULAR, CORREO,
    -- TELEFONO (cada INSERT excluye las personas ya presentes).
    ------------------------------------------------------------------------
    CALL rec_mtdat.sp_drop_si_existe(p_lote, p_nombre_proceso, 'rec_stage.batch_tmp_calculo_con_datos');

    v_sql := 'CREATE TABLE rec_stage.batch_tmp_calculo_con_datos DISTKEY (origen) AS '
          || '(SELECT ''DIRECCION'' AS origen, id_buro_persona '
          || ' FROM rec_stage.batch_cubo_direccion '
          || ' WHERE COALESCE(filtro_h,0) = 0 '
          || ' GROUP BY id_buro_persona)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Creado tabla BATCH_TMP_CALCULO_CON_DATOS');

    v_sql := 'INSERT INTO rec_stage.batch_tmp_calculo_con_datos '
          || 'SELECT ''CELULAR'', id_buro_persona FROM rec_stage.batch_cubo_celular '
          || 'WHERE id_buro_persona NOT IN (SELECT id_buro_persona FROM rec_stage.batch_tmp_calculo_con_datos) '
          || '  AND COALESCE(filtro_h,0) = 0 '
          || 'GROUP BY id_buro_persona';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Insertando celulares en BATCH_TMP_CALCULO_CON_DATOS');

    v_sql := 'INSERT INTO rec_stage.batch_tmp_calculo_con_datos '
          || 'SELECT ''CORREO'', id_buro_persona FROM rec_stage.batch_cubo_correo '
          || 'WHERE id_buro_persona NOT IN (SELECT id_buro_persona FROM rec_stage.batch_tmp_calculo_con_datos) '
          || '  AND COALESCE(filtro_h,0) = 0 '
          || 'GROUP BY id_buro_persona';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Insertando CORREO en BATCH_TMP_CALCULO_CON_DATOS');

    v_sql := 'INSERT INTO rec_stage.batch_tmp_calculo_con_datos '
          || 'SELECT ''TELEFONO'', id_buro_persona FROM rec_stage.batch_cubo_telefono '
          || 'WHERE id_buro_persona NOT IN (SELECT id_buro_persona FROM rec_stage.batch_tmp_calculo_con_datos) '
          || '  AND COALESCE(filtro_h,0) = 0 '
          || 'GROUP BY id_buro_persona';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Insertando TELEFONO en BATCH_TMP_CALCULO_CON_DATOS');

    ------------------------------------------------------------------------
    -- 'PROC' = registros procesados (validas + inconsistentes).
    -- El original tiene ademas una version alternativa comentada que cuenta
    -- sobre batch_tmp_calculo_con_datos; se omite igual que en el fuente.
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp_final.conteox '
          || 'FROM (SELECT ''PROC'' AS tipo, SUM(total) AS conteox FROM ('
          || '        SELECT CASE WHEN i.nombre_tipo_ident = ''Cedula de Ciudadania''  THEN ''ID_CC_CON_DATOS'''
          || '                    WHEN i.nombre_tipo_ident = ''Nit Juridicos''         THEN ''ID_NIT_CON_DATOS'''
          || '                    WHEN i.nombre_tipo_ident = ''Nit de Extranjeria''    THEN ''ID_NITE_CON_DATOS'''
          || '                    WHEN i.nombre_tipo_ident = ''Cedula de Extranjeria'' THEN ''ID_CE_CON_DATOS'''
          || '               END AS tipo'
          || '             , COUNT(*) AS total'
          || '        FROM (SELECT tipo_id FROM rec_stage.batch_identificaciones_validas WHERE id_solicitud = ' || v_sol
          || '              UNION ALL'
          || '              SELECT tipo_id FROM rec_stage.batch_identificaciones_incons  WHERE id_solicitud = ' || v_sol || ') cp'
          || '        LEFT JOIN rec_vista.tipo_identificacion i ON cp.tipo_id = i.cod_tipo_ident_fte'
          || '        GROUP BY 1) temp'
          || '      GROUP BY 1) tmp_final '
          || 'WHERE TRIM(rec_datos.batch_estadisticas_pro.identificador) = ''GENERALES'' '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = tmp_final.tipo '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'UPDATE Tabla PRO-Registro Procesados');

    ------------------------------------------------------------------------
    -- 'BASE_EN' = total de la base de entrada (tabla de P0037)
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp_final.conteox '
          || 'FROM (SELECT ''BASE_EN'' AS tipo, total AS conteox '
          || '      FROM (SELECT COUNT(1) AS total FROM rec_stage.batch_valform_st2) temp) tmp_final '
          || 'WHERE TRIM(rec_datos.batch_estadisticas_pro.identificador) = ''GENERALES'' '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = tmp_final.tipo '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Tabla PRO-BASE_EN');

    ------------------------------------------------------------------------
    -- 'BASE_DUP' = duplicados detectados por P0037
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp_final.conteox '
          || 'FROM (SELECT ''BASE_DUP'' AS tipo, total AS conteox '
          || '      FROM (SELECT COUNT(1) AS total FROM rec_stage.batch_valform_st4 '
          || '            WHERE val_dupe = 0 AND id_solicitud = ' || v_sol
          || '              AND id_plantilla = ' || v_pla || ') temp) tmp_final '
          || 'WHERE TRIM(rec_datos.batch_estadisticas_pro.identificador) = ''GENERALES'' '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = tmp_final.tipo '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Tabla PRO-BASE_DUP');

    ------------------------------------------------------------------------
    -- 'INCO' = total de inconsistencias
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = (SELECT COUNT(*) FROM rec_stage.vstg_inconsis_pnpj_tabla '
          || '              WHERE id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla || ') '
          || 'WHERE identificador = ''GENERALES'' AND valor1 = ''INCO'' '
          || '  AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDTE. Inconsistencias');

    -- COLLECT STATISTICS COLUMN (CAUSAL) -> ANALYZE
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'ANALYZE rec_stage.vstg_inconsis_pnpj_tabla (causal)', 'Estadisticas Causal');

    ------------------------------------------------------------------------
    -- CAUSAL distinto de ID_NV
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp.cuantos '
          || 'FROM (SELECT cr.identificador AS identificadorx, cr.valor1 AS valor1x, COUNT(*) AS cuantos '
          || '      FROM rec_stage.vstg_inconsis_pnpj_tabla tw '
          || '      INNER JOIN rec_datos.pro_batch2_filtros_estadisticas cr '
          || '              ON TRIM(tw.causal) = TRIM(cr.criterio) '
          || '      WHERE cr.campo = ''CAUSAL'' AND cr.identificador = ''GENERALES'' AND cr.valor1 <> ''ID_NV'' '
          || '      GROUP BY 1,2) tmp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = tmp.identificadorx '
          || '  AND rec_datos.batch_estadisticas_pro.valor1 = tmp.valor1x '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Causal <> ID_NV');

    ------------------------------------------------------------------------
    -- CAUSAL = ID_NV (identificaciones no validas).
    -- B-19: el segundo brazo del UNION ALL usa REC_STAGE hardcodeado
    -- mientras el primero usa P_BDSTAGE. En Redshift ambos son rec_stage.
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp.cuantos '
          || 'FROM (SELECT identificador AS identificadorx, valor1 AS valor1x, COUNT(*) AS cuantos FROM ('
          || '        SELECT tw.causal, tw.estado, cr.identificador, cr.valor1 '
          || '        FROM rec_stage.vstg_inconsis_pnpj_tabla tw '
          || '        INNER JOIN rec_datos.pro_batch2_filtros_estadisticas cr '
          || '                ON TRIM(tw.causal) = TRIM(cr.criterio) '
          || '               AND TRIM(tw.estado) = '''' '
          || '        WHERE cr.campo = ''CAUSAL'' AND cr.identificador = ''GENERALES'' AND cr.valor1 = ''ID_NV'' '
          || '        UNION ALL '
          || '        SELECT tw.causal, tw.estado '
          || '             , CAST(''GENERALES'' AS VARCHAR(100)) AS identificador '
          || '             , CAST(''ID_NV''     AS VARCHAR(100)) AS valor1 '
          || '        FROM rec_stage.vstg_inconsis_pnpj_tabla tw '
          || '        WHERE TRIM(tw.estado) NOT IN ('''',''21'') '
          || '          AND (TRIM(tw.causal) IS NULL OR TRIM(tw.causal) <> ''06'') '
          || '      ) t1 GROUP BY 1,2) tmp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = tmp.identificadorx '
          || '  AND rec_datos.batch_estadisticas_pro.valor1 = tmp.valor1x '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Causal = ID_NV');

    ------------------------------------------------------------------------
    -- CAUSAL = ID_NE.
    -- B-05 (REPLICADO): el INNER JOIN contra el catalogo NO tiene predicado
    -- de union (solo la condicion TRIM(tw.causal) = '05' sobre tw), asi que
    -- es un producto cartesiano y COUNT(*) queda multiplicado por el numero
    -- de filas del catalogo que cumplan el WHERE. Ademas este bloque ACUMULA
    -- (COALESCE(conteo,0) + ...) en vez de asignar. NO SE CORRIGE.
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = COALESCE(rec_datos.batch_estadisticas_pro.conteo,0) + tmp.cuantos '
          || 'FROM (SELECT cr.identificador AS identificadorx, cr.valor1 AS valor1x, COUNT(*) AS cuantos '
          || '      FROM rec_stage.vstg_inconsis_pnpj_tabla tw '
          || '      INNER JOIN rec_datos.pro_batch2_filtros_estadisticas cr '
          || '              ON TRIM(tw.causal) = ''05'' '
          || '      WHERE cr.campo = ''CAUSAL'' AND cr.identificador = ''GENERALES'' AND cr.valor1 = ''ID_NE'' '
          || '      GROUP BY 1,2) tmp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = tmp.identificadorx '
          || '  AND rec_datos.batch_estadisticas_pro.valor1 = tmp.valor1x '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Causal = ID_NE');

    ------------------------------------------------------------------------
    -- ESTADO
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp.cuantos '
          || 'FROM (SELECT cr.identificador AS identificadorx, cr.valor1 AS valor1x, COUNT(*) AS cuantos '
          || '      FROM rec_stage.vstg_inconsis_pnpj_tabla tw '
          || '      INNER JOIN rec_datos.pro_batch2_filtros_estadisticas cr '
          || '              ON TRIM(tw.estado) = TRIM(cr.criterio) '
          || '      WHERE cr.campo = ''ESTADO'' AND cr.identificador = ''GENERALES'' '
          || '      GROUP BY 1,2) tmp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = tmp.identificadorx '
          || '  AND rec_datos.batch_estadisticas_pro.valor1 = tmp.valor1x '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE Estado');

    ------------------------------------------------------------------------
    -- UBICACIONES: CON_UBI / SIN_UBI
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp_final.total '
          || 'FROM (SELECT SUM(totales) AS total, ''CON_UBI'' AS tipo FROM ('
          || '        SELECT CASE WHEN b.tipo_id = ''1'' THEN ''ID_CC_CON_DATOS'''
          || '                    WHEN b.tipo_id = ''2'' THEN ''ID_NIT_CON_DATOS'''
          || '                    WHEN b.tipo_id = ''3'' THEN ''ID_NITE_CON_DATOS'''
          || '                    WHEN b.tipo_id = ''4'' THEN ''ID_CE_CON_DATOS'''
          || '               END AS tipo, COUNT(*) AS totales '
          || '        FROM rec_stage.batch_tmp_calculo_con_datos a '
          || '        INNER JOIN (SELECT id_buro_persona, tipo_id FROM rec_stage.batch_cubo_persona GROUP BY 1,2) b '
          || '                ON a.id_buro_persona = b.id_buro_persona '
          || '        GROUP BY 1) a '
          || '      UNION ALL '
          || '      SELECT COUNT(DISTINCT id_buro_persona), ''SIN_UBI'' AS tipo '
          || '      FROM rec_stage.batch_cubo_persona '
          || '      WHERE id_buro_persona NOT IN (SELECT id_buro_persona FROM rec_stage.batch_tmp_calculo_con_datos)'
          || '     ) tmp_final '
          || 'WHERE TRIM(rec_datos.batch_estadisticas_pro.identificador) = ''GENERALES'' '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = TRIM(tmp_final.tipo) '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE. Ubicaciones');

    ------------------------------------------------------------------------
    -- CON_DIR / CON_TEL / CON_CEL / CON_EMAIL, contra las tablas
    -- batch_cubo_temp_*_total que crea estadisticas_cfg ('TMP_ESTADISTICAS').
    -- Nota del original: cuenta las personas cuyo TOTAL_* es 0 (es decir,
    -- SIN dato en ese canal) pero las etiqueta CON_*. Se replica.
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = tmp.conteox '
          || 'FROM (SELECT cr.identificador AS identificadorx, cr.valor1 AS valor1x, conteo.total AS conteox FROM ('
          || '        SELECT CAST(''CON_DIR'' AS VARCHAR(50)) AS tipo, COUNT(DISTINCT id_buro_persona) AS total '
          || '        FROM rec_stage.batch_cubo_persona ce '
          || '        WHERE EXISTS (SELECT 1 FROM rec_stage.batch_cubo_temp_dir_total bp '
          || '                      WHERE ce.id_buro_persona = bp.id_buro_persona AND total_dir = 0) '
          || '          AND COALESCE(ce.filtro_h,0) = 0 '
          || '        UNION '
          || '        SELECT CAST(''CON_TEL'' AS VARCHAR(50)), COUNT(DISTINCT id_buro_persona) '
          || '        FROM rec_stage.batch_cubo_persona ce '
          || '        WHERE EXISTS (SELECT 1 FROM rec_stage.batch_cubo_temp_telefono_total bp '
          || '                      WHERE ce.id_buro_persona = bp.id_buro_persona AND total_tel = 0) '
          || '          AND COALESCE(ce.filtro_h,0) = 0 '
          || '        UNION '
          || '        SELECT CAST(''CON_CEL'' AS VARCHAR(50)), COUNT(DISTINCT id_buro_persona) '
          || '        FROM rec_stage.batch_cubo_persona ce '
          || '        WHERE EXISTS (SELECT 1 FROM rec_stage.batch_cubo_temp_celular_total bp '
          || '                      WHERE ce.id_buro_persona = bp.id_buro_persona AND total_cel = 0) '
          || '          AND COALESCE(ce.filtro_h,0) = 0 '
          || '        UNION '
          || '        SELECT CAST(''CON_EMAIL'' AS VARCHAR(50)), COUNT(DISTINCT id_buro_persona) '
          || '        FROM rec_stage.batch_cubo_persona ce '
          || '        WHERE EXISTS (SELECT 1 FROM rec_stage.batch_cubo_temp_correo_total bp '
          || '                      WHERE ce.id_buro_persona = bp.id_buro_persona AND total_correo = 0) '
          || '          AND COALESCE(ce.filtro_h,0) = 0 '
          || '      ) conteo '
          || '      INNER JOIN rec_datos.pro_batch2_filtros_estadisticas cr ON cr.valor1 = conteo.tipo '
          || '      WHERE cr.identificador = ''GENERALES'') tmp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = tmp.identificadorx '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = TRIM(tmp.valor1x) '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE. Ubicaciones');

    ------------------------------------------------------------------------
    -- CONTEO_TIPO_DOC (ajuste 2023-05-30: amplia de 4 a 9 tipos de
    -- identificacion). La delegacion a la PARTE 'CONTEO_TIPO_DOC' que hacia
    -- esto antes quedo COMENTADA en el original el 2022-01-27; se omite
    -- igual, y se conserva solo este UPDATE inline.
    ------------------------------------------------------------------------
    v_sql := 'UPDATE rec_datos.batch_estadisticas_pro '
          || 'SET conteo = temp.total '
          || 'FROM (SELECT CASE WHEN b.tipo_id = ''1'' THEN ''ID_CC_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''2'' THEN ''ID_NIT_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''3'' THEN ''ID_NITE_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''4'' THEN ''ID_CE_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''5'' THEN ''ID_PAS_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''6'' THEN ''ID_PPT_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''7'' THEN ''ID_TI_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''8'' THEN ''ID_DNI_CON_DATOS'''
          || '                  WHEN b.tipo_id = ''9'' THEN ''ID_PEP_CON_DATOS'''
          || '             END AS tipo, COUNT(*) AS total '
          || '      FROM rec_stage.batch_tmp_calculo_con_datos a '
          || '      INNER JOIN (SELECT id_buro_persona, tipo_id FROM rec_stage.batch_cubo_persona GROUP BY 1,2) b '
          || '              ON a.id_buro_persona = b.id_buro_persona '
          || '      GROUP BY 1) temp '
          || 'WHERE rec_datos.batch_estadisticas_pro.identificador = ''GENERALES'' '
          || '  AND TRIM(rec_datos.batch_estadisticas_pro.valor1) = TRIM(temp.tipo) '
          || '  AND rec_datos.batch_estadisticas_pro.id_solicitud = ' || v_sol
          || '  AND rec_datos.batch_estadisticas_pro.id_plantilla = ' || v_pla;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'UPDATE. CONTEO_TIPO_DOC');

    ------------------------------------------------------------------------
    -- Delegaciones restantes al motor, en el orden del original.
    ------------------------------------------------------------------------
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'ESTADIS_EDAD');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'CIUDAD_DIR');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'TELEFONO_DIR');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'GENERO');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'DIR_POR_IDENT');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'TEL_POR_IDENT');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'ESTADIS_DIR');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'ESTADIS_TEL');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'ESTAD_ESTRATO');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'CIIU');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'DISTRIB_INGRESOS');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'DISTRIB_EGRESOS');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'CANT_INGRESOS');
    CALL rec_stage.sp_batch2_estadisticas_cfg(p_lote, p_nombre_proceso, p_start_timestamp, p_id_plantilla, p_id_solicitud, 'CANT_EGRESOS');

    ------------------------------------------------------------------------
    -- REP_*_100: top 100 de valores repetidos por canal.
    -- Cada bloque inserta primero una fila "titulo" y luego los datos.
    -- Traducciones: INSERT posicional -> VALUES; HAVING <alias> -> HAVING
    -- COUNT(*); QUALIFY ROW_NUMBER() <= 100 -> subconsulta con ROW_NUMBER.
    ------------------------------------------------------------------------
    v_sql := 'DELETE FROM rec_datos.batch_estadisticas_pro '
          || 'WHERE identificador IN (''REP_DIR_100'',''REP_TEL_100'',''REP_CEL_100'',''REP_MAIL_100'') '
          || '  AND id_plantilla = ' || v_pla || ' AND id_solicitud = ' || v_sol;
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Borrando. REP_DIR_100');

    -- REP_DIR_100
    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || 'VALUES (' || v_sol || ',' || v_pla || ',''REP_DIR_100'',''IDENTIFICADOR'','' '',0)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. TIT REP_DIR_100');

    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || '(id_solicitud, id_plantilla, identificador, valor1, valor2, conteo) '
          || 'SELECT id_solicitud, id_plantilla, identificador, valor1, valor2, contador FROM ('
          || '  SELECT ' || v_sol || ' AS id_solicitud, ' || v_pla || ' AS id_plantilla'
          || '       , CAST(''REP_DIR_100'' AS CHAR(20)) AS identificador'
          || '       , ciudad AS valor1, direccion AS valor2, COUNT(*) AS contador'
          || '       , ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn'
          || '  FROM rec_stage.batch_cubo_direccion'
          || '  WHERE direccion IS NOT NULL AND filtro_h = 0'
          || '  GROUP BY 1,2,3,4,5'
          || '  HAVING COUNT(*) > 1) q WHERE rn <= 100';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. DAT REP_DIR_100');

    -- REP_TEL_100
    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || 'VALUES (' || v_sol || ',' || v_pla || ',''REP_TEL_100'',''IDENTIFICADOR'','' '',0)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. TIT REP_TEL_100');

    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || '(id_solicitud, id_plantilla, identificador, valor1, valor2, conteo) '
          || 'SELECT id_solicitud, id_plantilla, identificador, valor1, valor2, contador FROM ('
          || '  SELECT ' || v_sol || ' AS id_solicitud, ' || v_pla || ' AS id_plantilla'
          || '       , CAST(''REP_TEL_100'' AS CHAR(20)) AS identificador'
          || '       , ciudad AS valor1, numero AS valor2, COUNT(*) AS contador'
          || '       , ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn'
          || '  FROM rec_stage.batch_cubo_telefono'
          || '  WHERE numero IS NOT NULL AND filtro_h = 0'
          || '  GROUP BY 1,2,3,4,5'
          || '  HAVING COUNT(*) > 1) q WHERE rn <= 100';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. DAT REP_TEL_100');

    -- REP_CEL_100 (sin valor2, igual que el original)
    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || 'VALUES (' || v_sol || ',' || v_pla || ',''REP_CEL_100'',''IDENTIFICADOR'','' '',0)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. TIT REP_CEL_100');

    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || '(id_solicitud, id_plantilla, identificador, valor1, conteo) '
          || 'SELECT id_solicitud, id_plantilla, identificador, valor1, contador FROM ('
          || '  SELECT ' || v_sol || ' AS id_solicitud, ' || v_pla || ' AS id_plantilla'
          || '       , CAST(''REP_CEL_100'' AS CHAR(20)) AS identificador'
          || '       , numero AS valor1, COUNT(*) AS contador'
          || '       , ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn'
          || '  FROM rec_stage.batch_cubo_celular'
          || '  WHERE numero IS NOT NULL AND filtro_h = 0'
          || '  GROUP BY 1,2,3,4'
          || '  HAVING COUNT(*) > 1) q WHERE rn <= 100';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. DAT REP_CEL_100');

    -- REP_MAIL_100 (el original etiqueta este titulo 'TIT REP_CEL_100': B-28)
    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || 'VALUES (' || v_sol || ',' || v_pla || ',''REP_MAIL_100'',''IDENTIFICADOR'','' '',0)';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. TIT REP_CEL_100');

    v_sql := 'INSERT INTO rec_datos.batch_estadisticas_pro '
          || '(id_solicitud, id_plantilla, identificador, valor1, conteo) '
          || 'SELECT id_solicitud, id_plantilla, identificador, valor1, contador FROM ('
          || '  SELECT ' || v_sol || ' AS id_solicitud, ' || v_pla || ' AS id_plantilla'
          || '       , CAST(''REP_MAIL_100'' AS CHAR(20)) AS identificador'
          || '       , correo AS valor1, COUNT(*) AS contador'
          || '       , ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn'
          || '  FROM rec_stage.batch_cubo_correo'
          || '  WHERE correo IS NOT NULL AND filtro_h = 0'
          || '  GROUP BY 1,2,3,4'
          || '  HAVING COUNT(*) > 1) q WHERE rn <= 100';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Poblando. DAT REP_MAIL_100');

    ------------------------------------------------------------------------
    -- VISTAS DE REPORTE: top 10 de ciudades por direccion y por telefono.
    -- SELECT TOP 10 -> LIMIT 10.
    ------------------------------------------------------------------------
    v_sql := 'CREATE OR REPLACE VIEW rec_stage.v_stg_dirtop10 AS '
          || 'SELECT 6 AS id, TRIM(valor2) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20))) AS campo '
          || 'FROM rec_datos.batch_estadisticas_pro '
          || 'WHERE identificador = ''CIUDAD_DIR1'' '
          || '  AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '  AND conteo > 0 '
          || 'ORDER BY conteo DESC LIMIT 10';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Creando Vista V_STG_DIRTOP10 ');

    v_sql := 'CREATE OR REPLACE VIEW rec_stage.v_stg_teltop10 AS '
          || 'SELECT 8 AS id, TRIM(valor2) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20))) AS campo '
          || 'FROM rec_datos.batch_estadisticas_pro '
          || 'WHERE identificador = ''CIUDAD_TEL1'' '
          || '  AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '  AND conteo > 0 '
          || 'ORDER BY conteo DESC LIMIT 10';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Creando Vista V_STG_TELTOP10 ');

    ------------------------------------------------------------------------
    -- vstg_batch_estadisticas_exp: el contenido del archivo de ALERTAS, una
    -- fila por linea, ordenado por (id, id2, campo).
    --
    -- B-10 (REPLICADO): PARTE_11 (id 22) y PARTE_12 (id 24) leen las dos el
    -- identificador CIUDAD_DIR_TOTAL. Por simetria, PARTE_12 deberia leer
    -- CIUDAD_TEL_TOTAL. NO SE CORRIGE.
    --
    -- Los "QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0" del
    -- original son tautologias (row_number siempre es >= 1); se conservan.
    ------------------------------------------------------------------------
    v_sql := 'CREATE OR REPLACE VIEW rec_stage.vstg_batch_estadisticas_exp AS '
          || 'SELECT SUM(1) OVER (ORDER BY id, id2, campo ROWS UNBOUNDED PRECEDING) AS id, campo FROM ('
          -- PARTE_1
          || ' SELECT CAST(1 AS INTEGER) AS id, CAST(1 AS INTEGER) AS id2, CAST(''PARTE_1'' || '';'' AS VARCHAR(250)) AS campo'
          || ' UNION ALL SELECT 2, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''GENERALES'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 2, 110 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''GENERO'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 2, 220 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , ''REG_ING;'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''CANT_INGRESOS'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 2, 330 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , ''REG_EGR;'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''CANT_EGRESOS'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 2, 440 + ROW_NUMBER() OVER (ORDER BY CAST(valor AS INTEGER) DESC)'
          || '       , CAST(''REGISTROS_LEIDOS'' AS VARCHAR(250)) || '';'' || TRIM(CAST(CAST(valor AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_stage.batch_archivo_log WHERE id IN (7)'
          || ' UNION ALL SELECT 2, 550 + ROW_NUMBER() OVER (ORDER BY CAST(COUNT(tipo_id || numero_id) - COUNT(DISTINCT tipo_id || numero_id) AS INTEGER) DESC)'
          || '       , CAST(''DIR'' AS VARCHAR(4)) || '';'' || TRIM(CAST(CAST(COUNT(tipo_id || numero_id) - COUNT(DISTINCT tipo_id || numero_id) AS INTEGER) AS VARCHAR(20)))'
          || '   FROM (SELECT tipo_id, numero_id FROM rec_stage.batch_identificaciones_validas'
          || '          WHERE id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '         UNION ALL'
          || '         SELECT tipo_id, numero_id FROM rec_stage.batch_identificaciones_incons'
          || '          WHERE id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla || ') a'
          || ' UNION ALL SELECT 2, 660 + ROW_NUMBER() OVER (ORDER BY CAST(valor AS INTEGER) DESC)'
          || '       , CAST(''REGISTROS_GRABADOS'' AS VARCHAR(250)) || '';'' || TRIM(CAST(CAST(valor AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_stage.batch_archivo_log WHERE id IN (8)'
          -- PARTE_2
          || ' UNION ALL SELECT 3, 2, CAST(''PARTE_2'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 4, 20 + ROW_NUMBER() OVER (ORDER BY CAST(conteo AS INTEGER) DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''RANGO_EDAD'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          -- PARTE_3 / PARTE_4: tops de ciudad
          || ' UNION ALL SELECT 5, 3, CAST(''PARTE_3'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT id, 20 + ROW_NUMBER() OVER (ORDER BY CAST(REGEXP_REPLACE(REGEXP_REPLACE(campo, ''[^;0-9]+'', '' '', 1, ''i''), '';'', '' '') AS INTEGER) DESC), campo'
          || '   FROM rec_stage.v_stg_dirtop10'
          || ' UNION ALL SELECT 7, 4, CAST(''PARTE_4'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT id, 20 + ROW_NUMBER() OVER (ORDER BY CAST(REGEXP_REPLACE(REGEXP_REPLACE(campo, ''[^;0-9]+'', '' '', 1, ''i''), '';'', '' '') AS INTEGER) DESC), campo'
          || '   FROM rec_stage.v_stg_teltop10'
          -- PARTE_5 .. PARTE_10
          || ' UNION ALL SELECT 9, 5, CAST(''PARTE_5'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 10, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''GENERO'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 11, 6, CAST(''PARTE_6'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 12, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''DIR_POR_IDENT'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 13, 7, CAST(''PARTE_7'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 14, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''TEL_POR_IDENT'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 15, 8, CAST(''PARTE_8'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 16, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''TIPO_DIR'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 17, 9, CAST(''PARTE_9'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 18, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''TIPO_TEL'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 19, 10, CAST(''PARTE_10'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 20, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''ESTRATO'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          -- PARTE_11 y PARTE_12 (B-10: las dos leen CIUDAD_DIR_TOTAL)
          || ' UNION ALL SELECT 21, 11, CAST(''PARTE_11'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 22, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(valor2) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''CIUDAD_DIR_TOTAL'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla || ' AND conteo > 0'
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 23, 12, CAST(''PARTE_12'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 24, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(valor1) || '';'' || TRIM(valor2) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''CIUDAD_DIR_TOTAL'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla || ' AND conteo > 0'
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          -- PARTE_13: repetidos por canal
          || ' UNION ALL SELECT 25, 13, CAST(''PARTE_13'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 26, 13, CAST(''1'' || '';'' || ''A'' || '';'' || ''REPETIDOS TELEFONO'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 27, 13, CAST(''1'' || '';'' || ''E'' || '';'' || ''CIUDAD'' || '';'' || '' TELEFONO'' || '';'' || '' REPETIDOS'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 28, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(CAST(1 AS VARCHAR(20))) || '';'' || TRIM(''D'') || '';'' || TRIM(COALESCE(valor1,'''')) || '';'' || TRIM(COALESCE(valor2,'''')) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''REP_TEL_100'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 29, 13, CAST(''2'' || '';'' || ''A'' || '';'' || ''REPETIDOS DIRECCION'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 30, 13, CAST(''2'' || '';'' || ''E'' || '';'' || ''CIUDAD'' || '';'' || '' DIRECCION'' || '';'' || '' REPETIDOS'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 31, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(CAST(2 AS VARCHAR(20))) || '';'' || TRIM(''D'') || '';'' || TRIM(COALESCE(valor1,'''')) || '';'' || TRIM(COALESCE(valor2,'''')) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''REP_DIR_100'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || ' UNION ALL SELECT 32, 13, CAST(''3'' || '';'' || ''A'' || '';'' || ''REPETIDOS CELULAR'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 33, 13, CAST(''3'' || '';'' || ''E'' || '';'' || '' CELULAR'' || '';'' || '' REPETIDOS'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 34, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(CAST(3 AS VARCHAR(20))) || '';'' || TRIM(''D'') || '';'' || TRIM(COALESCE(valor1,'''')) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''REP_CEL_100'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || ' UNION ALL SELECT 35, 13, CAST(''7'' || '';'' || ''A'' || '';'' || ''REPETIDOS MAIL'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 36, 13, CAST(''7'' || '';'' || ''E'' || '';'' || '' MAIL'' || '';'' || '' REPETIDOS'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 37, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(CAST(7 AS VARCHAR(20))) || '';'' || TRIM(''D'') || '';'' || TRIM(COALESCE(valor1,'''')) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''REP_MAIL_100'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || ' UNION ALL SELECT 38, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , CASE WHEN conteo = 0 THEN CAST(''FIN_PARTE_13'' || '';'' AS VARCHAR(250))'
          || '              ELSE TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20))) END'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''CIIU'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          -- PARTE_14 / PARTE_15
          || ' UNION ALL SELECT 39, 14, CAST(''PARTE_14'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 40, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(identificador) || '';'' || TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''DISTRIB_INGRESOS'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 41, 15, CAST(''PARTE_15'' || '';'' AS VARCHAR(250))'
          || ' UNION ALL SELECT 42, 20 + ROW_NUMBER() OVER (ORDER BY conteo DESC)'
          || '       , TRIM(identificador) || '';'' || TRIM(valor1) || '';'' || TRIM(CAST(CAST(conteo AS INTEGER) AS VARCHAR(20)))'
          || '   FROM rec_datos.batch_estadisticas_pro WHERE identificador = ''DISTRIB_EGRESOS'''
          || '     AND id_solicitud = ' || v_sol || ' AND id_plantilla = ' || v_pla
          || '   QUALIFY ROW_NUMBER() OVER (ORDER BY conteo DESC) > 0'
          || ' UNION ALL SELECT 43, 200, CAST(''FIN_PARTE_15'' || '';'' AS VARCHAR(250))'
          || ') x';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
         'Creando Vista VSTG_BATCH_ESTADISTICAS_EXP ');
END;
$$;


-- ############################################################################
-- Exportacion de las estadisticas al archivo de ALERTAS
-- ############################################################################
-- Sin cambios de logica respecto a la version del 2026-10-09: esta parte
-- siempre tuvo el SQL completo en P0033_BATCH2_ESTADISTICAS_111.BTQ.
-- Formato observado en Salidas/ALERTAS-4421_*: "NOMBRE_DEL_VALOR,CANTIDAD"
-- (separador ',', distinto del ';' de los CSV de datos).
--
-- NOTA: el original exporta rec_stage.vstg_batch_estadisticas_exp completa
-- (las 15 PARTE). Este procedure exporta el subconjunto GENERALES
-- (CON_UBI/SIN_UBI/INCO), que es lo que se pudo confirmar contra las
-- muestras. Ampliarlo a la vista completa es trabajo de F2-5, ahora que
-- sp_batch2_estadisticas si crea la vista.
-- ############################################################################
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_estadisticas_export(
    p_id_plantilla      BIGINT,
    p_id_solicitud      BIGINT,
    p_s3_bucket_salida  VARCHAR(500),
    p_iam_role          VARCHAR(500),
    p_archivo_alertas   VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql VARCHAR(MAX);
BEGIN
    v_sql := 'SELECT valor1 AS "NOMBRE_DEL_VALOR", CAST(conteo AS VARCHAR(10)) AS "CANTIDAD" ' ||
             'FROM rec_datos.batch_estadisticas_pro ' ||
             'WHERE identificador = ''GENERALES'' ' ||
             '  AND id_solicitud = ' || p_id_solicitud ||
             '  AND id_plantilla = ' || p_id_plantilla ||
             '  AND valor1 IN (''INCO'',''SIN_UBI'',''CON_UBI'')';

    EXECUTE 'UNLOAD (''' || REPLACE(v_sql, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || p_archivo_alertas || '_estadisticas_'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            'DELIMITER AS '','' PARALLEL OFF ALLOWOVERWRITE';
            -- UNLOAD no soporta "append" a un archivo existente: en el
            -- original este bloque se concatena (cat >>) al archivo de
            -- alertas consolidado. Ese paso queda para el mismo proceso
            -- externo (Glue/Lambda) que renombra los CSV.

    RAISE INFO 'sp_batch2_estadisticas_export: estadisticas exportadas para id_solicitud=%', p_id_solicitud;
END;
$$;
