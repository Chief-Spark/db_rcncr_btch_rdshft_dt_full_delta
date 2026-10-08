-- ============================================================
-- validacion_ordenamiento_mock_ca.sql
-- Evidencia CA-O01..CA-O12 tras run_ordenamiento_ejecucion_mock.
-- UTF-8 sin BOM.
-- ============================================================

SELECT criterio_ca, estado, detalle
FROM bdm_stage.mock_ord_ca_result
ORDER BY 1;

SELECT
  'mock_ord_ca_count' AS gate,
  COUNT(*)::BIGINT AS filas,
  SUM(CASE WHEN estado = 'PASSED' THEN 1 ELSE 0 END)::BIGINT AS passed
FROM bdm_stage.mock_ord_ca_result;
