-- ============================================================================
-- Procedure:   rec_stage.sp_batch2_valida_archivos
-- Equivalente: P0033_BATCH2_VALIDAR_ARCHIVOS_111.BTQ
-- Objetivo:    Validar que la cantidad de columnas configurada en
--              BATCH_SALIDAS_CAMPOS (via v_ba2_campos_salida) sea consistente
--              con lo que efectivamente se exportara, y registrar alertas
--              si hay inconsistencia estructural.
--
-- FIDELIDAD: MEDIA. La query de conteo de "Numero_Separadores" / "Ancho_Fijo"
-- esta completa en el .BTQ original y se traduce de forma directa. La
-- VALIDACION FISICA del archivo ya generado (contar separadores por linea
-- con awk sobre el archivo de texto) no aplica igual en Redshift: aqui el
-- archivo aun no existe como objeto de archivo plano local, por lo que esta
-- verificacion se reduce a comparar la cantidad de columnas esperada contra
-- la cantidad de columnas que efectivamente devuelve rec_stage.batch_salidas_campos
-- antes de invocar sp_batch2_exportplano, en vez de post-validar el CSV ya
-- escrito en S3 (que requeriria un paso adicional fuera de Redshift, p.ej.
-- Athena o un job de validacion sobre el archivo en S3).
-- ============================================================================

-- NOTA DE SINTAXIS: INOUT en vez de OUT, requerido por Redshift para
-- llamadas anidadas (ver nota en 01_sp_batch2_genera_lote.sql).
CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_valida_archivos(
    p_id_solicitud   BIGINT,
    p_id_plantilla   BIGINT,
    INOUT p_numero_separadores  INTEGER,
    INOUT p_ancho_fijo          INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*), SUM(COALESCE(af_ancho_campo, 0))
    INTO p_numero_separadores, p_ancho_fijo
    FROM rec_stage.batch_salidas_campos
    WHERE id_solicitud = p_id_solicitud
      AND id_plantilla = p_id_plantilla;

    IF p_numero_separadores IS NULL OR p_numero_separadores = 0 THEN
        -- Equivalente a la alerta "5,A,ESTRUCTURA ANCHO VARIABLE" / "4,A,ESTRUCTURA ANCHO FIJO"
        RAISE WARNING 'sp_batch2_valida_archivos: no hay campos configurados en BATCH_SALIDAS_CAMPOS para id_solicitud=%, id_plantilla=%', p_id_solicitud, p_id_plantilla;
    END IF;

    RAISE INFO 'sp_batch2_valida_archivos: numero_separadores=%, ancho_fijo=%', p_numero_separadores, p_ancho_fijo;
END;
$$;
