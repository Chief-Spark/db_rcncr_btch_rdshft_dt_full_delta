-- ============================================================
-- validacion_unificacion_mock_ca.sql
-- SLCOPRBA-1356 (Fase 5): evidencia de los gates por ARQUETIPO tras
-- run_reconocer_e2e_mock_full_delta.sql.
-- UTF-8 sin BOM.
-- ============================================================

SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
ORDER  BY 1;

SELECT
  'mock_unif_ca_count'                                       AS gate,
  COUNT(*)::BIGINT                                           AS criterios,
  SUM(CASE WHEN estado = 'PASSED' THEN 1 ELSE 0 END)::BIGINT AS passed,
  SUM(CASE WHEN estado = 'FAILED' THEN 1 ELSE 0 END)::BIGINT AS failed
FROM bdm_stage.mock_unif_ca_result;

-- Conteo por arquetipo, para leer a mano donde se desvia si algo falla.
SELECT
  CAST((u.cod_dw_persona_ubic / 10 - 9000000) / 10000 AS INTEGER) AS arq,
  COUNT(*)                                                        AS filas,
  COUNT(DISTINCT u.cod_dw_persona_ubic / 10)                      AS personas,
  MIN(u.lote)                                                     AS lote_min,
  MAX(u.lote)                                                     AS lote_max
FROM bdm_datos.unificacion_direccion_mock u
WHERE u.cod_dw_persona_ubic BETWEEN 90100000 AND 95609999
GROUP BY 1
ORDER BY 1;
