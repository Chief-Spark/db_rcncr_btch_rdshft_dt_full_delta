-- ============================================================================
-- Procedures:  rec_mtdat.sp_batch2_log_inicio / sp_batch2_log_resultado
-- Equivalente: patron repetido en casi todos los .BTQ del pipeline:
--              INSERT INTO ${BDMTDAT}.log_td (...) ... 'Ejecutando SP'
--              CALL PRO_BATCH2_XXX(...)
--              SEL Descripcion_Teradata_Error FROM LOG_TD_DETALLE
--                WHERE Descripcion_Teradata_Error <> 'Finalizo Exitosamente'
--                AND Lote = ${lote}
--              .IF ACTIVITYCOUNT > 0 THEN .Goto ERRORFOUND
--
-- Objetivo:    Centralizar en dos procedures auxiliares el registro de
--              inicio/fin de cada paso del pipeline y la verificacion de
--              fallo, para no repetir el patron en cada stored procedure
--              de paso (cuboexport, exportplano, exportlog, etc.).
--
-- FIDELIDAD: ALTA en estructura (misma tabla, mismas columnas, misma
-- semantica de "Finalizo Exitosamente" como marcador de OK). La diferencia
-- es de forma: en Teradata esto se repite inline en cada BTQ; aqui se
-- factoriza en procedures reutilizables.
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_mtdat.sp_batch2_log_inicio(
    p_lote                  BIGINT,
    p_nombre_proceso          VARCHAR(100),
    p_tabla_origen_stage       VARCHAR(100),
    p_tabla_destino_prod       VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO rec_mtdat.log_td
        (lote, fecha_hora_inicio, nombre_proceso, tabla_origen_stage, tabla_destino_prod, usuario_bd, estado_ejecucion)
    SELECT p_lote, GETDATE(), p_nombre_proceso, p_tabla_origen_stage, p_tabla_destino_prod, CURRENT_USER, 'Ejecutando SP';
END;
$$;


CREATE OR REPLACE PROCEDURE rec_mtdat.sp_batch2_log_resultado(
    p_lote              BIGINT,
    p_nombre_proceso      VARCHAR(100),
    p_exitoso            BOOLEAN,
    p_mensaje            VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO rec_mtdat.log_td_detalle
        (lote, fecha_hora, nombre_proceso, cadena, paso, descripcion_teradata_error)
    SELECT p_lote, GETDATE(), p_nombre_proceso, NULL, NULL,
           CASE WHEN p_exitoso THEN 'Finalizo Exitosamente' ELSE COALESCE(p_mensaje, 'Fallo sin descripcion') END;

    UPDATE rec_mtdat.log_td
    SET estado_ejecucion = CASE WHEN p_exitoso THEN 'Finalizado OK' ELSE 'Fallo Proceso' END,
        fecha_hora_fin = GETDATE()
    WHERE lote = p_lote
      AND nombre_proceso = p_nombre_proceso;
END;
$$;


-- Equivalente a la verificacion ".IF ACTIVITYCOUNT > 0 THEN .Goto ERRORFOUND"
-- Devuelve TRUE si el lote tiene algun registro de fallo (cualquier
-- descripcion distinta de 'Finalizo Exitosamente').
-- NOTA DE SINTAXIS: INOUT en vez de OUT, requerido por Redshift para
-- llamadas anidadas (ver nota en 01_sp_batch2_genera_lote.sql).
CREATE OR REPLACE PROCEDURE rec_mtdat.sp_batch2_fallo_en_lote(
    p_lote      BIGINT,
    INOUT p_fallo  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cuenta
    FROM rec_mtdat.log_td_detalle
    WHERE lote = p_lote
      AND descripcion_teradata_error <> 'Finalizo Exitosamente';

    p_fallo := (v_cuenta > 0);
END;
$$;


-- ============================================================================
-- Procedure:   rec_mtdat.sp_execstring_des
-- Equivalente: REC_DATOS.SP_EXECSTRING_DES (Teradata), invocado por TODOS los
--              SP de Sps_Batch.sql para ejecutar cada sentencia dinamica:
--                CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote, V_StartTimeStampPadre,
--                     :P_Nombre_Proceso_Padre, :V_CADENA, '<descripcion>', V_ERROR);
--                IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;
--
-- Comportamiento Redshift:
--   - Ejecuta p_sql con EXECUTE.
--   - Exito: registra 'Finalizo Exitosamente' en rec_mtdat.log_td_detalle
--     (mismo marcador que verifican los BTQ: "<> 'Finalizo Exitosamente'").
--   - Error: el bloque EXCEPTION registra el error en log_td_detalle y la
--     excepcion se RELANZA automaticamente (modo atomico de Redshift: al
--     entrar al handler se hace rollback, el handler corre en transaccion
--     nueva que se confirma, y luego se relanza). Efecto equivalente a
--     "LEAVE L1" + ".EXIT 104" del BTQ: el proceso se detiene en el primer
--     error y el detalle queda en el log.
--
-- DIFERENCIA vs Teradata: Teradata confirmaba cada sentencia (modo BTET por
-- sentencia); en Redshift, al fallar, se revierte TODO lo hecho en la
-- transaccion del CALL en curso (excepto lo ya confirmado por TRUNCATE).
-- El log del error SI persiste.
--
-- El codigo original de SP_EXECSTRING_DES no esta en el workspace; este
-- comportamiento se deduce de su uso (V_ERROR vacio = OK) y del patron de
-- verificacion de LOG_TD_DETALLE en los BTQ.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_mtdat.sp_execstring_des(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_sql             VARCHAR(65535),
    p_paso            VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE p_sql;

    INSERT INTO rec_mtdat.log_td_detalle
        (lote, fecha_hora, nombre_proceso, cadena, paso, descripcion_teradata_error)
    VALUES
        (p_lote, GETDATE(), p_nombre_proceso, p_sql, LEFT(p_paso, 500), 'Finalizo Exitosamente');
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO rec_mtdat.log_td_detalle
            (lote, fecha_hora, nombre_proceso, cadena, paso, descripcion_teradata_error)
        VALUES
            (p_lote, GETDATE(), p_nombre_proceso, p_sql, LEFT(p_paso, 500), LEFT('ERROR: ' || SQLERRM, 1000));
        RAISE INFO 'sp_execstring_des: fallo el paso %', p_paso;
END;
$$;

-- ----------------------------------------------------------------------------
-- Helper: DROP TABLE condicional (reemplaza el patron Teradata
--   SELECT TABLENAME INTO :Temp FROM dbc.tables WHERE ...;
--   IF ACTIVITY_COUNT > 0 THEN DROP TABLE ...)
-- Redshift soporta DROP TABLE IF EXISTS, por lo que no se consulta catalogo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE rec_mtdat.sp_drop_si_existe(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_tabla           VARCHAR(200)       -- esquema.tabla
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'DROP TABLE IF EXISTS ' || p_tabla, 'DROP TABLE ' || p_tabla);
END;
$$;

-- ----------------------------------------------------------------------------
-- Helper: DROP de una tabla buscada por NOMBRE en el catalogo (2026-10-14).
-- Reemplaza el patron de los motores PRO_BATCH2_ESTADISTICAS_CFG y
-- PRO_BATCH2_PLAN_EJECUCION_SHELL, donde solo se conoce el nombre de la
-- tabla (columna CAMPO de la fila) y no su base:
--   SEL DatabaseName INTO :V_BD FROM DBC.Tables WHERE TableName = V_DATO;
--   SELECT TableName INTO :Temp FROM dbc.tables
--    WHERE databasename = V_BD AND TableName = V_DATO;
--   IF ACTIVITY_COUNT > 0 THEN DROP TABLE V_BD.V_DATO  (via SP_EXECSTRING_DES)
-- Diferencias:
--   - Se busca solo en los esquemas del proceso (rec_stage, rec_mtdat,
--     rec_datos, rec_vista) y solo tablas (pg_tables). DBC.Tables de
--     Teradata tambien lista vistas, pero en las filas reales el DROP nunca
--     llega a una vista.
--   - Si el nombre existe en mas de un esquema, Teradata falla en el
--     SELECT INTO (mas de una fila); aqui se lanza una excepcion.
--   - Texto de paso del log igual al original: 'DROP TABLE ' || nombre.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE rec_mtdat.sp_drop_tabla_por_nombre(
    p_lote            BIGINT,
    p_nombre_proceso  VARCHAR(100),
    p_tabla           VARCHAR(200)       -- nombre sin esquema (CAMPO de la fila del motor)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tabla   VARCHAR(200) := LOWER(TRIM(p_tabla));
    v_cuenta  INTEGER;
    v_esquema VARCHAR(128);
BEGIN
    IF v_tabla IS NULL OR v_tabla = '' THEN
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_cuenta
    FROM pg_catalog.pg_tables
    WHERE tablename = v_tabla
      AND schemaname IN ('rec_stage', 'rec_mtdat', 'rec_datos', 'rec_vista');

    IF v_cuenta = 0 THEN
        RETURN;
    END IF;
    IF v_cuenta > 1 THEN
        RAISE EXCEPTION 'sp_drop_tabla_por_nombre: la tabla % existe en % esquemas', v_tabla, v_cuenta;
    END IF;

    SELECT schemaname INTO v_esquema
    FROM pg_catalog.pg_tables
    WHERE tablename = v_tabla
      AND schemaname IN ('rec_stage', 'rec_mtdat', 'rec_datos', 'rec_vista');

    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso,
         'DROP TABLE ' || v_esquema || '.' || v_tabla, 'DROP TABLE ' || p_tabla);
END;
$$;
