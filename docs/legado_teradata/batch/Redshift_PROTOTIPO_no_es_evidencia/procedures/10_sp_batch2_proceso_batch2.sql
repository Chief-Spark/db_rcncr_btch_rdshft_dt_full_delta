-- ============================================================================
-- Procedure:   rec_stage.sp_batch2_proceso_batch2
-- Equivalente: P0033_PROCESO_BATCH2.BTQ (orquestador maestro)
-- Objetivo:    Ejecutar el pipeline BATCH2 completo para una solicitud,
--              en el mismo orden logico documentado en el analisis:
--
--   1. Generar LOTE
--   2. Plan de ejecucion (PRO_BATCH2_PLAN_EJECUCION_SHELL, logica real desde
--      2026-10-14): arma rec_stage.batch2_shells_planejecucion, pero los
--      pasos se siguen ejecutando en el orden FIJO de abajo (en Redshift no
--      hay shells que lanzar)
--   3. VALIDAR_ARCHIVOS
--   4. PROCESACUBOS (filtros A..J + homologaciones + porcentajes + inconsistencias)
--   5. CUBOEXPORT (pivote de cubos a tablas horizontales)
--   6. EXPORTPLANO para 'CON DATOS DE UBICACION' -> CON_DATOS_*.CSV + INCONSISTENCIA
--   7. EXPORTPLANO para 'SIN DATOS DE UBICACION' -> SIN_DATOS_*.CSV
--   8. (si ORIENTACION = OE_VERTICA) EXPORTVERTPLANO
--   9. CANALCONTACTO -> archivo ALERTAS
--   10. CANTREPCANAL
--   11. ESTADISTICAS (calculo + export a ALERTAS)
--   12. EXPORTLOG -> BATCH_ARCHIVO_LOG
--   13. ACTUALIZA_HISTORIA -> cierre de la solicitud (ESTADO='GENERADO')
--
-- FIDELIDAD: la SECUENCIA es fiel al pipeline documentado.
--
-- Estado al 2026-10-15: YA NO HAY PLACEHOLDERS. Los 19 SP de Sps_Batch.sql
-- estan migrados con logica real: PROCESACUBOS (08), los 4 de F2-4
-- (09_sp_batch2_otros.sql), los motores de SQL-como-datos (09b) y EXPORTLOG
-- con ARCHIVO_LOG (05).
--
-- Lo que falta para una corrida completa son DATOS y OBJETOS, no codigo:
--   - filas de rec_datos.pro_batch2_filtros_estadisticas  -> ESTADISTICAS
--   - filas TIPO='CANT_REP_CANAL_CONTACTO' de batch_motor_log -> CANTREPCANAL
--   - rec_stage.v_ba2_campos_salida y vstg_batch2_*         -> TRANSPUESTA,
--     CANALCONTACTO (las construye el paso BTEQ de CUBOEXPORT/EXPORTPLANO,
--     pendiente en F2-5; ver ddl/10_tablas_trabajo_f2_4.sql)
--   - rec_stage.batch_cubo_persona11                        -> CANTREPCANAL
-- Sin ellos, esos pasos fallan o no hacen nada, pero CON_DATOS / SIN_DATOS /
-- INCONSISTENCIA se siguen generando.
--
-- PARAMETROS DE INFRAESTRUCTURA (sin equivalente en Teradata, requeridos por
-- Redshift para UNLOAD a S3):
--   p_s3_bucket_salida : ruta S3 destino de los CSV, ej 's3://mi-bucket/batch2/salidas/'
--   p_iam_role         : ARN del rol IAM con permiso de escritura en el bucket
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_proceso_batch2(
    p_id_solicitud       BIGINT,
    p_s3_bucket_salida    VARCHAR(500),
    p_iam_role           VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lote               BIGINT;
    v_id_plantilla        BIGINT;
    v_orientacion         VARCHAR(100);
    v_fch_archivo         VARCHAR(20);
    v_fallo              BOOLEAN;
    v_dummy_separadores    INTEGER;
    v_dummy_ancho          INTEGER;
    v_archivos_pn_pj      VARCHAR(100);
    v_feinicio            VARCHAR(32);
    v_archivoprn          VARCHAR(1000);
    v_sol                 VARCHAR(20) := CAST(p_id_solicitud AS VARCHAR(20));
    v_delim_log           VARCHAR(5)  := ',';   -- DELIMITADOR de P0033_BATCH2_EXPORTLOG.par (muestras de Salidas/)
    v_inicio_paso         TIMESTAMP;
BEGIN
    ------------------------------------------------------------------
    -- 1. Generar LOTE
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_genera_lote(v_lote);
    RAISE INFO 'PROCESO_BATCH2: lote=% para id_solicitud=%', v_lote, p_id_solicitud;

    v_fch_archivo := '_' || TO_CHAR(GETDATE(), 'YYYYMMDDHH24MISS');
    -- FEINICIO del EXPORTLOG_111: 'YYYY-MM-DD HH:MI:SS.' (con punto final)
    v_feinicio := TO_CHAR(GETDATE(), 'YYYY-MM-DD HH24:MI:SS') || '.';

    ------------------------------------------------------------------
    -- Resolver id_plantilla y orientacion desde la configuracion de la
    -- solicitud (equivalente a lo que el .par traia precomputado).
    ------------------------------------------------------------------
    SELECT id_plantilla, orientacion, archivos_pn_pj
    INTO v_id_plantilla, v_orientacion, v_archivos_pn_pj
    FROM rec_stage.batch_datos_generales
    WHERE id_solicitud = p_id_solicitud
    LIMIT 1;

    IF v_id_plantilla IS NULL THEN
        RAISE EXCEPTION 'PROCESO_BATCH2: no existe configuracion en BATCH_DATOS_GENERALES para id_solicitud=%', p_id_solicitud;
    END IF;

    ------------------------------------------------------------------
    -- 2. Plan de ejecucion (09b_sp_batch2_motores_sql.sql). El original
    --    pasa '${process}' como nombre de proceso y como PARTE; se infiere
    --    process = 'ITERADOR' (unica PARTE con filas en PRO_PLAN_EJECUCION).
    ------------------------------------------------------------------
    CALL rec_stage.sp_batch2_plan_ejecucion_shell(v_lote, 'ITERADOR', p_id_solicitud, 'ITERADOR');

    ------------------------------------------------------------------
    -- 3. VALIDAR_ARCHIVOS
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_VALIDAR_ARCHIVOS', 'BATCH_SALIDAS_CAMPOS', NULL);
    CALL rec_stage.sp_batch2_valida_archivos(p_id_solicitud, v_id_plantilla, v_dummy_separadores, v_dummy_ancho);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_VALIDAR_ARCHIVOS', TRUE, NULL);

    ------------------------------------------------------------------
    -- 4. PROCESACUBOS (08_sp_batch2_procesacubos.sql). Orden y llamadas
    --    reales de P0033_BATCH2_PROCESACUBOS_111.BTQ: E se llama dos veces
    --    ('N' y 'J') e I se ejecuta antes que H. I y J no reciben
    --    plantilla/solicitud.
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_PROCESACUBOS', 'BATCH_CUBO_*', NULL);
    CALL rec_stage.sp_batch2_filtro_a(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_b(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_c(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_d(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_e(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud, 'N');
    CALL rec_stage.sp_batch2_filtro_e(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud, 'J');
    CALL rec_stage.sp_batch2_filtro_f(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_g(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_homologaciones(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_i(v_lote, 'P0033_BATCH2_PROCESACUBOS');
    CALL rec_stage.sp_batch2_filtro_h(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_filtro_j(v_lote, 'P0033_BATCH2_PROCESACUBOS');
    CALL rec_stage.sp_batch2_add_porc_insumo(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_adicionar_incon(v_lote, 'P0033_BATCH2_PROCESACUBOS', v_id_plantilla, p_id_solicitud);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_PROCESACUBOS', TRUE, NULL);

    ------------------------------------------------------------------
    -- 5. CUBOEXPORT: pivote de cubos a tablas horizontales w_cubo_*
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_CUBOEXPORT', 'BATCH_CUBO_*', 'w_cubo_*');
    CALL rec_stage.sp_batch2_cubo_export(p_id_solicitud, v_id_plantilla);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_CUBOEXPORT', TRUE, NULL);

    ------------------------------------------------------------------
    -- 6-7. EXPORTPLANO: genera CON_DATOS / SIN_DATOS / INCONSISTENCIA
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_EXPORTPLANO', 'w_cubo_*', 'CON_DATOS/SIN_DATOS/INCONSISTENCIA');
    CALL rec_stage.sp_batch2_exportplano(p_id_solicitud, v_id_plantilla, 'CON DATOS DE UBICACION', p_s3_bucket_salida, p_iam_role, v_fch_archivo);
    CALL rec_stage.sp_batch2_exportplano(p_id_solicitud, v_id_plantilla, 'SIN DATOS DE UBICACION', p_s3_bucket_salida, p_iam_role, v_fch_archivo);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_EXPORTPLANO', TRUE, NULL);

    ------------------------------------------------------------------
    -- 8. EXPORTVERTPLANO -> PRO_BATCH2_TRANSPUESTA (09_sp_batch2_otros.sql)
    --    P0033_BATCH2_EXPORTVERTPLANO_111.BTQ: solo si varOrienta =
    --    'OE_VERTICA'. Si varARCHIVOS_PN_PJ = 1 llama dos veces (PN y luego
    --    PJ); si no, una sola vez con PNPJ.
    ------------------------------------------------------------------
    IF UPPER(COALESCE(v_orientacion, 'OE_HORIZON')) = 'OE_VERTICA' THEN
        CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_EXPORTVERTPLANO', 'vstg_batch2_*', 'tb_vstg_batch2_*');
        IF COALESCE(TRIM(v_archivos_pn_pj), '') = '1' THEN
            CALL rec_stage.sp_batch2_transpuesta(v_lote, 'P0033_BATCH2_EXPORTVERTPLANO', 'vstg_batch2_pn');
            CALL rec_stage.sp_batch2_transpuesta(v_lote, 'P0033_BATCH2_EXPORTVERTPLANO', 'vstg_batch2_pj');
        ELSE
            CALL rec_stage.sp_batch2_transpuesta(v_lote, 'P0033_BATCH2_EXPORTVERTPLANO', 'vstg_batch2_pnpj');
        END IF;
        CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_EXPORTVERTPLANO', TRUE, NULL);
    END IF;

    ------------------------------------------------------------------
    -- 9. CANALCONTACTO -> PRO_Batch2_Completitud_Canal
    --    P0033_BATCH2_CANALCONTACTO_111.BTQ pasa (varPLANTILLA, varSOLICITUD)
    --    a la firma (P_PLANTILLA, P_SOLICITUD): aqui SI coinciden.
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_CANALCONTACTO', 'vstg_batch2_*', 'tabla_w1/tabla_w2');
    CALL rec_stage.sp_batch2_completitud_canal(v_lote, 'P0033_BATCH2_CANALCONTACTO', v_id_plantilla, p_id_solicitud);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_CANALCONTACTO', TRUE, NULL);

    ------------------------------------------------------------------
    -- 10. CANTREPCANAL -> PRO_BATCH2_CANTREPCANAL_CON (CON y SIN datos)
    --
    --    B-08 REPLICADO: la firma Teradata es
    --      (..., P_ID_SOLICITUD, P_ID_PLANTILLA, P_CDATOS_SDATOS, ...)
    --    pero P0033_BATCH2_CANTREPCANAL_111.BTQ pasa en esas posiciones
    --      ${varPLANTILLA}, ${varSOLICITUD}
    --    es decir, cruzados. Se reproduce el cruce aqui: al parametro
    --    p_id_solicitud se le pasa v_id_plantilla y viceversa.
    --    NO ES UN ERROR DE ESTA MIGRACION. Ver Bugs_Encontrados.md.
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_CANTREPCANAL', 'batch_motor_log', 'batch_estadisticas_pro');
    CALL rec_stage.sp_batch2_cantrepcanal_con(v_lote, 'P0033_BATCH2_CANTREPCANAL', GETDATE(),
         v_id_plantilla,   -- -> p_id_solicitud  (cruce del BTQ, B-08)
         p_id_solicitud,   -- -> p_id_plantilla  (cruce del BTQ, B-08)
         '0');
    CALL rec_stage.sp_batch2_cantrepcanal_con(v_lote, 'P0033_BATCH2_CANTREPCANAL', GETDATE(),
         v_id_plantilla, p_id_solicitud, '1');
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_CANTREPCANAL', TRUE, NULL);

    ------------------------------------------------------------------
    -- 11. ESTADISTICAS: calculo real (09_sp_batch2_otros.sql) + export
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_ESTADISTICAS', 'batch_cubo_*', 'batch_estadisticas_pro');
    CALL rec_stage.sp_batch2_estadisticas(v_lote, 'P0033_BATCH2_ESTADISTICAS', GETDATE(), v_id_plantilla, p_id_solicitud);
    CALL rec_stage.sp_batch2_estadisticas_export(v_id_plantilla, p_id_solicitud, p_s3_bucket_salida, p_iam_role, 'ALERTAS-' || p_id_solicitud || v_fch_archivo);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_ESTADISTICAS', TRUE, NULL);

    ------------------------------------------------------------------
    -- 12. EXPORTLOG
    ------------------------------------------------------------------
    -- ARCHIVOPRN como en EXPORTLOG_111: archivos de datos (PN/PJ si
    -- ARCHIVOS_PN_PJ = 1, si no el unico por seccion) en orden alfabetico
    -- (ls), luego INCONSISTENCIA; cada uno seguido del delimitador.
    IF COALESCE(TRIM(v_archivos_pn_pj), '') = '1' THEN
        v_archivoprn := 'CON_DATOS_' || v_sol || '_PJ' || v_fch_archivo || '.CSV' || v_delim_log
                     || 'CON_DATOS_' || v_sol || '_PN' || v_fch_archivo || '.CSV' || v_delim_log
                     || 'SIN_DATOS_' || v_sol || '_PJ' || v_fch_archivo || '.CSV' || v_delim_log
                     || 'SIN_DATOS_' || v_sol || '_PN' || v_fch_archivo || '.CSV' || v_delim_log;
    ELSE
        v_archivoprn := 'CON_DATOS_' || v_sol || v_fch_archivo || '.CSV' || v_delim_log
                     || 'SIN_DATOS_' || v_sol || v_fch_archivo || '.CSV' || v_delim_log;
    END IF;
    v_archivoprn := v_archivoprn || 'INCONSISTENCIA_' || v_sol || v_fch_archivo || '.CSV' || v_delim_log;

    -- Hora de inicio del paso = 'FECHA FIN' del archivo de log (dateTimeStartPro del BTQ)
    v_inicio_paso := GETDATE();

    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_EXPORTLOG', 'rec_stage.batch_archivo_log', NULL);
    CALL rec_stage.sp_batch2_exportlog(
        v_lote, 'P0033_BATCH2_EXPORTLOG', v_inicio_paso,
        v_id_plantilla, p_id_solicitud,
        v_archivoprn, 'redshift-cluster', p_s3_bucket_salida, v_feinicio,
        'CON DATOS DE UBICACION',
        p_s3_bucket_salida, p_iam_role,
        'BATCH_SOLICITUD_BATCH.ARCHIVO_LOG', v_delim_log
    );
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_EXPORTLOG', TRUE, NULL);

    ------------------------------------------------------------------
    -- 13. ACTUALIZA_HISTORIA (cierre de la solicitud)
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_log_inicio(v_lote, 'P0033_BATCH2_ACTUALIZA_HISTORIA', 'BATCH_CUBO_*', 'BATCH_HISTORIA_RESULTADOS');
    CALL rec_stage.sp_batch2_actualiza_historia(p_id_solicitud, v_id_plantilla);
    CALL rec_mtdat.sp_batch2_log_resultado(v_lote, 'P0033_BATCH2_ACTUALIZA_HISTORIA', TRUE, NULL);

    ------------------------------------------------------------------
    -- Verificacion final de fallos acumulados en el lote (equivalente al
    -- patron ".IF ACTIVITYCOUNT > 0 THEN .Goto ERRORFOUND" repetido)
    ------------------------------------------------------------------
    CALL rec_mtdat.sp_batch2_fallo_en_lote(v_lote, v_fallo);
    IF v_fallo THEN
        RAISE WARNING 'PROCESO_BATCH2: el lote % registro al menos un paso con fallo; revisar rec_mtdat.log_td_detalle', v_lote;
    ELSE
        RAISE INFO 'PROCESO_BATCH2: lote % finalizado sin fallos registrados para id_solicitud=%', v_lote, p_id_solicitud;
    END IF;
END;
$$;
