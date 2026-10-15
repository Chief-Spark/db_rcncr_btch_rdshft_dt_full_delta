-- ============================================================
-- E2E Reconocer — Unificacion FULL + GEO + Ordenamiento FULL
-- Ambiente: consumidor dba_rncr_batch · schemas bdm_datos / bdm_tempo
-- Precondicion: deploy STRCT + PGM ya aplicados; Data Sharing OK
-- NO mezclar path mock (bdm_stage) en esta corrida
--
-- Cadena extremo a extremo (modo FULL):
--   1) sp_unificacion_ciclo FULL  -> R1/R2 + GEO export (DEV: 0 candidatos,
--      no restringe R3) + R3
--   2) sp_ordenamiento_ciclo FULL -> scores/orden sobre salida unif
--
-- Lote dedicado 1356201 para evidencia de esta prueba FULL.
-- UTF-8 sin BOM. CALL 6 VARCHAR Framework_Batch.
-- ============================================================

-- 1) Unificacion FULL (GEO va dentro del ciclo; en DEV no restringe)
CALL bdm_datos.sp_unificacion_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356201' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- 2) Ordenamiento FULL sobre salida unif
CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356201' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
