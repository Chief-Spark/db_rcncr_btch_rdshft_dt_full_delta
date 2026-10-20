-- ============================================================================
-- Archivo:     09b_sp_batch2_motores_sql.sql   (2026-10-14)
-- Contenido:   motores de "SQL guardado como datos" cuyo codigo llego con
--              Sps_Batch.sql y Dlls-Batch/:
--   PRO_BATCH2_ESTADISTICAS_CFG     -> rec_stage.sp_batch2_estadisticas_cfg
--   PRO_BATCH2_PLAN_EJECUCION_SHELL -> rec_stage.sp_batch2_plan_ejecucion_shell
-- (PRO_BATCH2_ARCHIVO_LOG, el tercer motor, esta en 05_sp_batch2_exportlog.sql
--  junto a la exportacion que lo usa.)
--
-- Los dos tienen la misma forma: recorren las filas de una PARTE en una
-- tabla de catalogo, reemplazan marcadores en el texto, hacen DROP previo si
-- la sentencia crea una tabla y ejecutan el texto via sp_execstring_des.
--
-- Traduccion comun (misma convencion que procedures/08):
--   - Sin parametros de nombre de base (P_BDVISTA/P_BDSTAGE/P_BDDATOS) ni
--     OUT P_ERROR. Los marcadores P_BDSTAGE/P_BDVISTA/P_BDDATOS se
--     reemplazan por rec_stage/rec_vista/rec_datos.
--   - PREPARE + cursor dinamico -> FOR r IN SELECT ... LOOP con el mismo
--     filtro y ORDER BY.
--   - REGEXP_REPLACE con parametro 'c' (sensible a mayusculas, como el
--     default de Teradata) aunque la base sea CASE_INSENSITIVE.
--   - Busqueda de la base en DBC.Tables + DROP -> rec_mtdat.sp_drop_tabla_por_nombre
--     (02_sp_batch2_log_helpers.sql).
--   - "SET P_ERROR = V_CADENA" (traza en el OUT) se elimina; el SQL ejecutado
--     queda en rec_mtdat.log_td_detalle.cadena.
-- ============================================================================


-- ============================================================================
-- PRO_BATCH2_ESTADISTICAS_CFG -> rec_stage.sp_batch2_estadisticas_cfg
-- Fuente: Dlls-Batch/Dll_Btach.csv (el texto exportado perdio los saltos de
-- linea; la logica se leyo sin ambiguedad).
-- Lo llama PRO_BATCH2_ESTADISTICAS ~20 veces, una por PARTE ('SQL-PARAM',
-- 'ESTADISTICAS', 'TMP_ESTADISTICAS', 'GENERO', 'CIIU', ...). Recorre
-- REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS WHERE PARTE = TRIM(P_PARTE)
-- ORDER BY ORDEN; CRITERIO es la sentencia y CAMPO el nombre de la tabla
-- que crea.
--
-- Traduccion:
--   - Marcadores, en el orden original: P_StartTimeStampPadre ('YYYY-MM-DD
--     HH:MI:SS.', igual que CAST(TIMESTAMP(6) AS VARCHAR(20)) de Teradata),
--     P_BDDATOS, P_BDVISTA, P_BDSTAGE, P_ID_PLANTILLA, P_ID_SOLICITUD.
--   - "STRTOK(TRIM(UPPER(V_QSQL)),' ',1) = 'CREATE'" -> SPLIT_PART(BTRIM(UPPER(criterio)),
--     ' ', 1) = 'CREATE': la primera palabra hasta el primer espacio (un
--     salto de linea pegado a CREATE no cuenta como separador en ninguno de
--     los dos motores).
--   - ORDER BY ORDEN: Teradata pone NULL primero -> NULLS FIRST.
--   - P_StartTimeStampPadre: VARCHAR en Teradata -> TIMESTAMP aqui.
--
-- DEPENDENCIA DE DATOS: las filas de rec_datos.pro_batch2_filtros_estadisticas
-- (ver ddl/07) no se han recibido. Sin filas el procedure no hace nada.
-- Todavia no lo llama ningun SP Redshift: PRO_BATCH2_ESTADISTICAS sigue como
-- placeholder (tarea F2-4).
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_estadisticas_cfg(
    p_lote             BIGINT,
    p_nombre_proceso   VARCHAR(100),
    p_start_timestamp  TIMESTAMP,
    p_id_plantilla     BIGINT,
    p_id_solicitud     BIGINT,
    p_parte            VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_ts    VARCHAR(20) := TO_CHAR(p_start_timestamp, 'YYYY-MM-DD HH24:MI:SS') || '.';
    v_sol   VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    v_pla   VARCHAR(20) := CAST(p_id_plantilla AS VARCHAR(20));
    r       RECORD;
BEGIN
    FOR r IN
        SELECT campo, criterio
        FROM rec_datos.pro_batch2_filtros_estadisticas
        WHERE parte = TRIM(p_parte)
        ORDER BY orden NULLS FIRST
    LOOP
        v_sql := REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                     r.criterio
                    ,'P_StartTimeStampPadre', COALESCE(v_ts, ''), 1, 'c')
                    ,'P_BDDATOS', 'rec_datos', 1, 'c')
                    ,'P_BDVISTA', 'rec_vista', 1, 'c')
                    ,'P_BDSTAGE', 'rec_stage', 1, 'c')
                    ,'P_ID_PLANTILLA', v_pla, 1, 'c')
                    ,'P_ID_SOLICITUD', v_sol, 1, 'c');

        -- Si la sentencia empieza con CREATE, borra antes la tabla CAMPO
        IF SPLIT_PART(BTRIM(UPPER(r.criterio)), ' ', 1) = 'CREATE' THEN
            CALL rec_mtdat.sp_drop_tabla_por_nombre(p_lote, p_nombre_proceso, r.campo);
        END IF;

        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Ejecuta:' || p_parte || ';');
    END LOOP;
END;
$$;


-- ============================================================================
-- PRO_BATCH2_PLAN_EJECUCION_SHELL -> rec_stage.sp_batch2_plan_ejecucion_shell
-- Fuente: Sps_Batch.sql lineas 9384 en adelante; filas en
-- Redshift/datos/01_catalogos_motor.sql (PARTE = 'ITERADOR').
-- Arma rec_stage.batch2_shells_planejecucion (plan de pasos de la
-- solicitud) a partir de rec_stage.batch2_shells_config y de las secciones
-- de BATCH_SALIDAS_CAMPOS.
--
-- Llamada original (P0033_PROCESO_BATCH2.BTQ):
--   CALL PRO_BATCH2_PLAN_EJECUCION_SHELL(${lote}, '${process}', ${IDSOLICITUD},
--        '${process}', P_ERROR);
--   P_PARTE = ${process} del .par P0033_PROCESO_BATCH2.par (no esta en el
--   workspace). Como las unicas filas son PARTE = 'ITERADOR', se infiere
--   process = 'ITERADOR'; el orquestador Redshift lo pasa asi.
--
-- Traduccion:
--   - Marcadores: P_StartTimeStampPadre (hora actual, 'YYYY-MM-DD HH:MI:SS.')
--     y P_ID_SOLICITUD. Las filas no usan el primero.
--   - "IF TRIM(V_QSQL) LIKE '%CREATE%'" (Teradata: sin distinguir
--     mayusculas) -> UPPER(...) LIKE '%CREATE%'. Las filas 7 y 8 (vistas)
--     tambien contienen CREATE; como sp_drop_tabla_por_nombre solo busca
--     tablas, no borra nada para ellas (en Teradata eran REPLACE VIEW y no
--     entraban a este bloque).
--   - La sentencia SEL STRTOK(...) INTO :V_CREATE del original no se usa
--     (comentario del propio codigo: "Esta sentencia no funciona"); se omite.
--
-- Uso del plan: el orquestador Redshift (10_sp_batch2_proceso_batch2.sql)
-- arma el plan con este procedure, pero sigue ejecutando los pasos en orden
-- fijo (no hay shells en Redshift). Mientras rec_stage.batch2_shells_config
-- este vacia, el plan queda vacio.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_plan_ejecucion_shell(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_id_solicitud    BIGINT,
    p_parte           VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   VARCHAR(65535);
    v_ts    VARCHAR(20) := TO_CHAR(GETDATE(), 'YYYY-MM-DD HH24:MI:SS') || '.';
    v_sol   VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    r       RECORD;
BEGIN
    FOR r IN
        SELECT campo, sql_valor
        FROM rec_stage.pro_plan_ejecucion
        WHERE parte = TRIM(p_parte)
        ORDER BY id
    LOOP
        v_sql := REGEXP_REPLACE(REGEXP_REPLACE(
                     r.sql_valor
                    ,'P_StartTimeStampPadre', v_ts, 1, 'c')
                    ,'P_ID_SOLICITUD', v_sol, 1, 'c');

        IF UPPER(TRIM(r.sql_valor)) LIKE '%CREATE%' THEN
            CALL rec_mtdat.sp_drop_tabla_por_nombre(p_lote, p_nombre_proceso, TRIM(r.campo));
        END IF;

        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Ejecuta:' || p_parte || ';');
    END LOOP;
END;
$$;
