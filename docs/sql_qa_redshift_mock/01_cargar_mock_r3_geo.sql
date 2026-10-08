-- ============================================================
-- 01_cargar_mock_r3_geo.sql
-- Añade registros R3 CON lat/long para que no fallen por falta de geo.
-- Personas: 930001 (NO unifica), 930008 (SÍ), 930010 (NO empate vía)
-- Idempotente (WHERE NOT EXISTS).
-- Después: CALL sp_unificacion_regla3 (o equivalente) y validar con 03.
-- ============================================================

-- Reutiliza el mock canónico del paquete
\i mock_tc_r3_01_08_10.sql
-- Si DBeaver no soporta \i, abrir y ejecutar:
--   sql/qa_redshift/mock_tc_r3_01_08_10.sql

-- Check inmediato: mocks con geo
SELECT
  m.id_buro_persona,
  m.scenario_code,
  COUNT(*) AS n_rpu,
  SUM(CASE WHEN ubi.latitud IS NOT NULL THEN 1 ELSE 0 END) AS con_lat
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = r.cod_dw_ubic
WHERE m.scenario_code IN ('MOCK_TC_R3_01','MOCK_TC_R3_08','MOCK_TC_R3_10')
GROUP BY 1, 2
ORDER BY 1;

-- Esperado: 3 personas, cada una con latitud poblada (con_lat = n_rpu)
