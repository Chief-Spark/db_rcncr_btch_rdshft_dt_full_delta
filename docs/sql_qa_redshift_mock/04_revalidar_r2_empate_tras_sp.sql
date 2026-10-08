-- ============================================================
-- 04_revalidar_r2_empate_tras_sp.sql
-- Usar SOLO después de desplegar SP R2 con e04_ganador (HAVING COUNT(*)=1)
-- y re-ejecutar Regla 2 sobre el mock.
-- ============================================================

-- 1) Confirmar que el escenario sigue en meta
SELECT scenario_code, COUNT(*) AS personas
FROM bdm_stage.perf_persona_meta
WHERE scenario_code = 'R2_EMPATE'
GROUP BY 1;

-- 2) Gate TC-R2-14 (debe PASSED = 0 violaciones)
SELECT
  'TC-R2-14' AS caso,
  COUNT(*) AS violaciones,
  CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED — revisar SP e04_ganador' END AS estado
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_EMPATE'
  AND EXISTS (
    SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
    JOIN bdm_stage.unificacion_direccion u
      ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
    WHERE r.id_buro_persona = m.id_buro_persona
  );

-- 3) Si FAILED: el SP en QA no excluye empates. Desplegar:
--    sql/qa_ifr_data/06_sp_regla2.sql
--    (bloque stg_regla2_e04_ganador ... HAVING COUNT(*) = 1)
