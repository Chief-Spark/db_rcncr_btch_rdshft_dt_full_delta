-- ============================================================
-- 00_RUNBOOK_ORDENAMIENTO_MOCK.sql
-- Post-deploy: CALL bdm_stage.sp_ordenamiento_ejecucion_mock();
-- Alternativa scripts: 01_ddl → 02_seed → 03_validar
-- ============================================================

CALL bdm_stage.sp_ordenamiento_ejecucion_mock();

SELECT criterio_ca, estado, detalle
FROM bdm_stage.mock_ord_ca_result
ORDER BY criterio_ca;

SELECT
  CASE WHEN SUM(CASE WHEN estado = 'FAILED' THEN 1 ELSE 0 END) = 0
       THEN 'PASSED_ALL' ELSE 'FAILED_SOME' END AS veredicto_mock
FROM bdm_stage.mock_ord_ca_result;
