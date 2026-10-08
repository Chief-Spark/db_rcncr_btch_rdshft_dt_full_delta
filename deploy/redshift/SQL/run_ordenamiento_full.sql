-- ============================================================
-- run_ordenamiento_full.sql
-- CALL FULL Ordenamiento via sp_ordenamiento_ciclo (6 VARCHAR).
-- UTF-8 sin BOM. Tokens :LOTE / :FECHA sustituidos por orquestacion.
-- ============================================================

CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356001' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
