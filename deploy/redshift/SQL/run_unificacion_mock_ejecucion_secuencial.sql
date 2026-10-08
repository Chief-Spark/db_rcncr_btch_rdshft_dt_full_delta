-- ============================================================
-- run_unificacion_mock_ejecucion_secuencial.sql
-- Orquestador mock — sp_unificacion_mock_regla* (v_mock_*/bdm_stage).
-- Requiere strct 02a DDL stage. Seed opcional: tablas pueden estar vacias
-- (CALL completa sin traza). Firma: (modo VARCHAR, lote INTEGER, wm DATE).
-- UTF-8 sin BOM.
-- ============================================================

TRUNCATE TABLE bdm_datos.unificacion_direccion_mock;

CALL bdm_datos.sp_unificacion_mock_regla1(CAST('FULL' AS VARCHAR(256)), 1356001, CAST(NULL AS DATE));
CALL bdm_datos.sp_unificacion_mock_regla2(CAST('FULL' AS VARCHAR(256)), 1356001, CAST(NULL AS DATE));
CALL bdm_datos.sp_unificacion_mock_regla3(CAST('FULL' AS VARCHAR(256)), 1356001, CAST(NULL AS DATE));
