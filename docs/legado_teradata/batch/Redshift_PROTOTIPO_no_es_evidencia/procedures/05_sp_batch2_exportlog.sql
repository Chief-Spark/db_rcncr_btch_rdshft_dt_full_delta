-- ============================================================================
-- Archivo:     05_sp_batch2_exportlog.sql
-- Contenido:   rec_stage.sp_batch2_archivo_log  (PRO_BATCH2_ARCHIVO_LOG)
--              rec_stage.sp_batch2_exportlog    (P0033_BATCH2_EXPORTLOG_111/130/140)
-- Reescrito:   2026-10-14, con el codigo fuente de PRO_BATCH2_ARCHIVO_LOG
--              (Sps_Batch.sql lineas 9230-9383) y las filas TIPO='LOG' de
--              BATCH_MOTOR_LOG (Dlls-Batch/Dll_Btach.csv), reescritas en
--              Redshift/datos/01_catalogos_motor.sql.
--
-- Flujo original:
--   111.BTQ: arma la lista de archivos generados (ARCHIVOPRN), la fecha de
--            inicio (FEINICIO, del parametro HOY) y llama a
--            PRO_BATCH2_ARCHIVO_LOG, que pone VALOR = NULL en el catalogo
--            BATCH_ARCHIVO_LOG y ejecuta las 18 sentencias del motor.
--   130.TPT: exporta "DATO<delim>TRIM(VALOR)" con una fila de cabecera
--            ('DATO','VALOR', ID -1), ordenado por ID, al archivo <FileName>_W.
--   140.BTQ: agrega dos lineas en blanco + el contenido de <FileName>_W al
--            FINAL del archivo historico <FileName> y borra <FileName>_W.
--            Por eso Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG acumula corridas.
--
-- Diferencias con Teradata:
--   - UNLOAD no puede agregar a un archivo existente ni fijar el nombre
--     exacto (agrega sufijo, p. ej. 000). Se deja el equivalente de
--     <FileName>_W en S3; la concatenacion al historico (paso 140) queda para
--     el mismo proceso externo que renombra los CSV (ver VERIFICACION.md).
--   - Codificacion: UNLOAD escribe UTF-8; el TPT escribia LATIN1 (las tildes
--     de 'ELECTRÓNICOS', 'MÍNIMOS', 'TELÉFONO' ocupan 2 bytes en UTF-8).
--   - El separador sale del parametro DELIMITADOR de P0033_BATCH2_EXPORTLOG.par
--     (no esta en el workspace); las muestras usan ','. Se recibe como
--     parametro.
-- ============================================================================

-- ============================================================================
-- PRO_BATCH2_ARCHIVO_LOG -> rec_stage.sp_batch2_archivo_log
--
-- Traduccion:
--   - Firma con la convencion de procedures/08 (p_lote, p_nombre_proceso,
--     p_id_plantilla, p_id_solicitud, ...). Se quitan P_BDDATOS/P_BDVISTA/
--     P_BDSTAGE (esquemas fijos: rec_datos/rec_vista/rec_stage) y OUT P_ERROR
--     (el error se propaga como excepcion desde sp_execstring_des).
--   - P_StartTimeStampPadre (VARCHAR en Teradata, convertido a TIMESTAMP(6))
--     -> p_start_timestamp TIMESTAMP. Su reemplazo en el SQL es
--     CAST(ts AS VARCHAR(20)) en Teradata: 'YYYY-MM-DD HH:MI:SS.' (20
--     caracteres, con el punto final). Se arma igual con TO_CHAR || '.'.
--     Es el valor de 'FECHA FIN' en el archivo.
--   - PREPARE + cursor dinamico -> FOR r IN SELECT ... ORDER BY id.
--   - 11 REGEXP_REPLACE anidados en el mismo orden; parametro 'c' para que
--     la sustitucion sea sensible a mayusculas aunque la base use
--     COLLATE CASE_INSENSITIVE (default de Teradata: sensible).
--   - Un parametro de texto NULL dejaria todo el SQL en NULL (REGEXP_REPLACE
--     con reemplazo NULL devuelve NULL). El BTQ siempre pasaba textos (a lo
--     sumo vacios), por lo que se usa COALESCE(..., '').
-- BUG ORIGINAL REPLICADO: el texto de paso es 'Se realiza update al campo'
--   || DATO || ';' (sin espacio), igual que en FILTRO_C.
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_archivo_log(
    p_lote             BIGINT,
    p_nombre_proceso   VARCHAR(100),
    p_start_timestamp  TIMESTAMP,
    p_id_plantilla     BIGINT,
    p_id_solicitud     BIGINT,
    p_archivoprn       VARCHAR(1000),
    p_maquina          VARCHAR(200),
    p_ruta             VARCHAR(200),
    p_feinicio         VARCHAR(32),
    p_nombre_seccion   VARCHAR(32)
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
    -- 1. Limpia los valores del catalogo
    v_sql := 'UPDATE rec_stage.batch_archivo_log SET valor = NULL';
    CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql, 'Actualiza a NULL campo Valor');

    -- 2. Motor BATCH_MOTOR_LOG (TIPO = 'LOG'), en orden de ID
    FOR r IN
        SELECT sql_string, dato
        FROM rec_stage.batch_motor_log
        WHERE sql_string IS NOT NULL
          AND tipo = 'LOG'
        ORDER BY id
    LOOP
        v_sql := REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                 REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                     r.sql_string
                    ,'P_StartTimeStampPadre', COALESCE(v_ts, ''), 1, 'c')
                    ,'P_BDDATOS', 'rec_datos', 1, 'c')
                    ,'P_BDVISTA', 'rec_vista', 1, 'c')
                    ,'P_BDSTAGE', 'rec_stage', 1, 'c')
                    ,'P_ID_SOLICITUD', v_sol, 1, 'c')
                    ,'P_ID_PLANTILLA', v_pla, 1, 'c')
                    ,'P_ARCHIVOPRN', COALESCE(p_archivoprn, ''), 1, 'c')
                    ,'P_MAQUINA', COALESCE(p_maquina, ''), 1, 'c')
                    ,'P_RUTA', COALESCE(p_ruta, ''), 1, 'c')
                    ,'P_FEINICIO', COALESCE(p_feinicio, ''), 1, 'c')
                    ,'P_NOMBRE_SECCION', COALESCE(p_nombre_seccion, ''), 1, 'c');

        -- BUG ORIGINAL REPLICADO: sin espacio entre 'campo' y DATO
        CALL rec_mtdat.sp_execstring_des(p_lote, p_nombre_proceso, v_sql,
             'Se realiza update al campo' || r.dato || ';');
    END LOOP;
END;
$$;


-- ============================================================================
-- P0033_BATCH2_EXPORTLOG_111 / _130 / _140 -> rec_stage.sp_batch2_exportlog
--
-- p_archivoprn: lista de archivos generados en la corrida, cada uno seguido
-- del delimitador (equivalente a "ls ... | tr '\n' $DELIMITADOR" del 111):
-- 'CON_DATOS_4421_20240902100353.CSV,SIN_DATOS_4421_20240902100353.CSV,INCONSISTENCIA_4421_20240902100353.CSV,'.
-- La arma el orquestador.
-- p_feinicio: fecha de inicio del batch con el formato del 111
-- ('YYYY-MM-DD HH:MI:SS.', con punto final).
-- ============================================================================
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_exportlog(
    p_lote              BIGINT,
    p_nombre_proceso    VARCHAR(100),
    p_start_timestamp   TIMESTAMP,
    p_id_plantilla      BIGINT,
    p_id_solicitud      BIGINT,
    p_archivoprn        VARCHAR(1000),
    p_maquina           VARCHAR(200),
    p_ruta              VARCHAR(200),
    p_feinicio          VARCHAR(32),
    p_nombre_seccion    VARCHAR(32),
    p_s3_bucket_salida  VARCHAR(500),
    p_iam_role          VARCHAR(500),
    p_filename          VARCHAR(200),   -- FileName de P0033_BATCH2_EXPORTLOG.par, ej. 'BATCH_SOLICITUD_BATCH.ARCHIVO_LOG'
    p_delimitador       VARCHAR(5)      -- DELIMITADOR de P0033_BATCH2_EXPORTLOG.par (muestras: ',')
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql  VARCHAR(65535);
BEGIN
    -- 111: llena el catalogo DATO/VALOR
    CALL rec_stage.sp_batch2_archivo_log(p_lote, p_nombre_proceso, p_start_timestamp,
         p_id_plantilla, p_id_solicitud, p_archivoprn, p_maquina, p_ruta,
         p_feinicio, p_nombre_seccion);

    -- 130: misma consulta del TPT (cabecera como fila ID -1, VALOR con TRIM).
    -- Sin opcion HEADER: los nombres de columna de Redshift salen en
    -- minusculas y el original escribe 'DATO','VALOR' en mayusculas.
    v_sql := 'SELECT dato, TRIM(valor)
FROM (SELECT CAST(-1 AS INTEGER) AS id, CAST(''DATO'' AS VARCHAR(100)) AS dato, CAST(''VALOR'' AS VARCHAR(1000)) AS valor
      UNION ALL
      SELECT id, dato, valor
      FROM rec_stage.batch_archivo_log) a
ORDER BY id';

    -- NULL se escribe como cadena vacia (default de UNLOAD en texto
    -- delimitado), igual que el DataConnector del TPT.
    EXECUTE 'UNLOAD (''' || REPLACE(v_sql, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || p_filename || '_W'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            'DELIMITER AS ''' || p_delimitador || ''' PARALLEL OFF ALLOWOVERWRITE';

    -- 140 (dos lineas en blanco + append al historico p_filename): fuera de
    -- Redshift, ver cabecera.
    RAISE INFO 'sp_batch2_exportlog: log exportado para id_solicitud=%', p_id_solicitud;
END;
$$;
