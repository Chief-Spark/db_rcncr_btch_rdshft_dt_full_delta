-- ============================================================
-- run_geo_ciclo_lote.sql
-- Malla GEO diferida (carga + reenganche). En Framework_Batch se invocan:
--   CALL bdm_stage.sp_geo_ciclo_lote('', '', '<S3_GEOREF>', '<LOTE>', '<S3_DIST>', '');
--   CALL bdm_stage.sp_geo_reenganchar_r3('', '', '', '<LOTE>', '', '');
-- En DPLY Jenkins no hay rutas S3; no-op para no fallar el deploy.
-- UTF-8 sin BOM.
-- ============================================================

SELECT 1 AS geo_ciclo_lote_dply_noop;
