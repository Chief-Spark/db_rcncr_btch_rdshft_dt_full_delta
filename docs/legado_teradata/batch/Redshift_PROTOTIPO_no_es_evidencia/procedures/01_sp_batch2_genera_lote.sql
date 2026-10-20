-- ============================================================================
-- Procedure:   rec_mtdat.sp_batch2_genera_lote
-- Equivalente: funGenerateLote() en P0033_PROCESO_BATCH2.BTQ
-- Objetivo:    Generar un correlativo de lote (LOTE) usado para trazabilidad
--              de toda la ejecucion del pipeline BATCH2.
--
-- FIDELIDAD: ALTA. La logica original es un simple UPDATE+SELECT bajo lock
-- exclusivo sobre una tabla de una fila; se traduce de forma directa.
-- Redshift no tiene "LOCKING ... FOR EXCLUSIVE" explicito de Teradata, pero
-- el UPDATE dentro de una transaccion ya adquiere el lock de fila necesario
-- para serializar incrementos concurrentes.
--
-- NOTA DE SINTAXIS: se usa INOUT (no OUT) porque este procedure se invoca
-- desde dentro de otro procedure (sp_batch2_proceso_batch2, llamada
-- anidada). Redshift exige INOUT para parametros de salida en llamadas
-- anidadas: "If you call a nested procedure that has output parameters,
-- the inner procedure must define INOUT arguments. OUT arguments aren't
-- allowed" (ver docs.aws.amazon.com/redshift/latest/dg/r_CALL_procedure.html).
-- El llamador debe pasar una variable ya declarada (puede estar sin
-- inicializar) en lugar de una constante.
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_mtdat.sp_batch2_genera_lote(
    INOUT p_lote      BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Asegura que exista la fila semilla (idempotente, igual que el INSERT
    -- de 05_tablas_control.sql, por si la tabla fue truncada).
    INSERT INTO rec_mtdat.lote_id (lote)
    SELECT 0
    WHERE NOT EXISTS (SELECT 1 FROM rec_mtdat.lote_id);

    UPDATE rec_mtdat.lote_id
    SET lote = COALESCE(lote, 0) + 1;

    SELECT lote INTO p_lote
    FROM rec_mtdat.lote_id;

    RAISE INFO 'sp_batch2_genera_lote: lote generado = %', p_lote;
END;
$$;
