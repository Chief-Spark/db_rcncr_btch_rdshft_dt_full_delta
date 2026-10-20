-- ============================================================================
-- Procedure:   rec_stage.sp_batch2_actualiza_historia
-- Equivalente: P0033_BATCH2_ACTUALIZA_HISTORIA_111.BTQ / _130.TPT
-- Objetivo:    Paso de cierre de la solicitud:
--              1) Si NO_ENTREGADO_X_MESES > 0 (regla de exclusion de
--                 reincidentes activa), inserta en BATCH_HISTORIA_RESULTADOS
--                 el UNION de personas con datos de ubicacion encontrados
--                 en los 4 cubos (direccion/telefono/celular/correo).
--              2) Cierra la solicitud: BATCH_SOLICITUD_BATCH.ESTADO='GENERADO'.
--
-- FIDELIDAD: ALTA. El SQL de este paso esta completo en el workspace
-- (111.BTQ + 130.TPT), se traduce de forma directa sin inferencias.
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_actualiza_historia(
    p_id_solicitud   BIGINT,
    p_id_plantilla   BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_no_entregado_x_meses   INTEGER;
BEGIN
    -- #1 (ACTUALIZA_HISTORIA_111.BTQ): solo ejecuta si hay regla de exclusion
    -- de reincidentes activa (NO_ENTREGADO_X_MESES > 0).
    SELECT CAST(no_entregado_x_meses AS INTEGER) INTO v_no_entregado_x_meses
    FROM rec_stage.batch_datos_generales
    WHERE id_solicitud = p_id_solicitud
      AND id_plantilla = p_id_plantilla
      AND no_entregado_x_meses IS NOT NULL
      AND TRIM(no_entregado_x_meses) <> ''
      AND CAST(no_entregado_x_meses AS INTEGER) > 0
    LIMIT 1;

    IF v_no_entregado_x_meses IS NULL OR v_no_entregado_x_meses <= 0 THEN
        RAISE INFO 'sp_batch2_actualiza_historia: NO_ENTREGADO_X_MESES no activo, se omite actualizacion de historia para id_solicitud=%', p_id_solicitud;
    ELSE
        -- ACTUALIZA_HISTORIA_130.TPT: DELETE + INSERT en BATCH_HISTORIA_RESULTADOS
        DELETE FROM rec_datos.batch_historia_resultados
        WHERE id_solicitud = p_id_solicitud;

        INSERT INTO rec_datos.batch_historia_resultados
            (id_solicitud, id_plantilla, cod_dw_persona_ubic, fecha_ejecucion, id_buro_suscriptor)
        SELECT DISTINCT
            p_id_solicitud,
            p_id_plantilla,
            cubos.cod_dw_persona_ubic,
            CAST(GETDATE() AS DATE),
            pers.id_buro_suscriptor
        FROM (
            SELECT cod_pin_persona, cod_dw_persona_ubic FROM rec_stage.batch_cubo_direccion
            UNION
            SELECT cod_pin_persona, cod_dw_persona_ubic FROM rec_stage.batch_cubo_telefono
            UNION
            SELECT cod_pin_persona, cod_dw_persona_ubic FROM rec_stage.batch_cubo_celular
            UNION
            SELECT cod_pin_persona, cod_dw_persona_ubic FROM rec_stage.batch_cubo_correo
        ) cubos
        LEFT JOIN rec_stage.batch_cubo_persona per
               ON per.cod_pin_persona = cubos.cod_pin_persona
        LEFT JOIN (
            SELECT
                vbt.id_buro_persona AS id_buro_suscriptor,
                vbt.cod_tipo_ident_fte,
                vbt.num_ident
            FROM rec_stage.batch_solicitud_batch bsb
            INNER JOIN rec_stage.vstg_buropers_tmp vbt
                    ON bsb.tipo_id_suscriptor = CAST(vbt.cod_tipo_ident_fte AS VARCHAR(10))
                   AND bsb.num_id_suscriptor = vbt.num_ident
            WHERE bsb.id_solicitud = p_id_solicitud
        ) pers
               ON per.numero_id = pers.num_ident;

        RAISE INFO 'sp_batch2_actualiza_historia: historia actualizada para id_solicitud=%', p_id_solicitud;
    END IF;

    -- Cierre de la solicitud (equivalente al UPDATE del 130.TPT, STEP Bteq_Act_solicitud)
    UPDATE rec_stage.batch_solicitud_batch
    SET estado = 'GENERADO',
        fecha_generacion = GETDATE()
    WHERE id_solicitud = p_id_solicitud
      AND estado IS NULL
      AND fecha_generacion IS NULL;

    RAISE INFO 'sp_batch2_actualiza_historia: solicitud % marcada como GENERADO', p_id_solicitud;
END;
$$;
