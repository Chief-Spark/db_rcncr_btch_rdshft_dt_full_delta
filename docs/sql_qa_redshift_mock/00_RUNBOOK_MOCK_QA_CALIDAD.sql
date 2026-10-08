-- ============================================================
-- 00_RUNBOOK_MOCK_QA_CALIDAD.sql
-- QA mock: que pasen TC-R2-14 y TCs R3 (con geo)
-- Ambiente: QA / dba_batch / bdm_stage (sandbox autorizado)
-- ============================================================
-- ORDEN:
--  1) Este archivo es solo guía. Ejecutar scripts 01 → 02 → 03 → 04.
--  2) Si R2 se vuelve a correr con SP VIEJO (sin e04_ganador), TC-R2-14
--     volverá a fallar → desplegar SP R2 del repo con stg_regla2_e04_ganador.
-- ============================================================

-- Paso 0 — Preflight
SELECT 'perf_persona_meta' AS obj, COUNT(*) AS n
FROM information_schema.tables
WHERE table_schema='bdm_stage' AND table_name='perf_persona_meta'
UNION ALL
SELECT 'r2_empate_personas', COUNT(DISTINCT id_buro_persona)
FROM bdm_stage.perf_persona_meta WHERE scenario_code='R2_EMPATE'
UNION ALL
SELECT 'rpu_con_geo', COUNT(*)
FROM bdm_stage.ubicacion_estandarizada
WHERE latitud IS NOT NULL AND longitud IS NOT NULL;

-- Luego ejecutar en este orden:
--   01_cargar_mock_r3_geo.sql
--   02_patch_r2_empate_limpiar_absorciones.sql
--   CALL bdm_stage.sp_unificacion_regla3();   -- o el SP R3 del paquete QA
--   03_validar_gates_mock_qa.sql
--
-- Opcional (re-certificar R2_EMPATE tras redeploy SP):
--   04_revalidar_r2_empate_tras_sp.sql
