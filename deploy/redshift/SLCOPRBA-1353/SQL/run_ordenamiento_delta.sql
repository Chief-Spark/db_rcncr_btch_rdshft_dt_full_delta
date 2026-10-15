-- ============================================================
-- run_ordenamiento_delta.sql
-- CALL DELTA Ordenamiento via sp_ordenamiento_ciclo (6 VARCHAR).
-- Bootstrap a FULL si no hay watermark completado en ord_control.
-- UTF-8 sin BOM.
-- ============================================================

CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356001' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
