-- ============================================================
-- E2E Reconocer — Unificacion DELTA + GEO + Ordenamiento DELTA
-- Ambiente: consumidor dba_rncr_batch · schemas bdm_datos / bdm_tempo
-- Precondicion: corrida E2E FULL previa (watermark completado en unif/ord)
-- NO mezclar path mock (bdm_stage) en esta corrida
--
-- Cadena extremo a extremo (modo DELTA), inmediatamente despues de FULL:
--   1) sp_unificacion_ciclo DELTA -> ventana watermark + GEO (DEV: 0 candidatos)
--   2) sp_ordenamiento_ciclo DELTA -> UPSERT por alcance sobre salida unif
--
-- Lote dedicado 1356202 para evidencia de esta prueba DELTA.
-- Si no hay watermark completado, el orquestador fuerza bootstrap FULL.
-- UTF-8 sin BOM. CALL 6 VARCHAR Framework_Batch.
-- ============================================================

-- 1) Unificacion DELTA (GEO va dentro del ciclo; en DEV no restringe)
CALL bdm_datos.sp_unificacion_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356202' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- 2) Ordenamiento DELTA sobre salida unif
CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356202' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
