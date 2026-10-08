-- ============================================================
-- 03_validar_gates_mock_qa.sql
-- Gates de calidad MOCK para lo que reportó Julian
-- Ejecutar DESPUÉS de: 01 (mock R3) + 02 (patch R2) + CALL R3
-- ============================================================

-- G1) TC-R2-14 — debe ser 0
SELECT
  'TC-R2-14' AS caso,
  COUNT(*) AS violaciones,
  CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS estado
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_EMPATE'
  AND EXISTS (
    SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
    JOIN bdm_stage.unificacion_direccion u
      ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
    WHERE r.id_buro_persona = m.id_buro_persona
  );

-- G2) R3 mocks con geo cargados
SELECT
  'R3_MOCKS_GEO' AS caso,
  COUNT(DISTINCT m.id_buro_persona) AS personas_mock,
  SUM(CASE WHEN ubi.latitud IS NOT NULL THEN 1 ELSE 0 END) AS filas_con_lat,
  CASE
    WHEN COUNT(DISTINCT m.id_buro_persona) >= 3
     AND SUM(CASE WHEN ubi.latitud IS NOT NULL THEN 1 ELSE 0 END) > 0
    THEN 'PASSED' ELSE 'FAILED'
  END AS estado
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = r.cod_dw_ubic
WHERE m.scenario_code IN ('MOCK_TC_R3_01','MOCK_TC_R3_08','MOCK_TC_R3_10');

-- G3) Resultados R3 esperados (tras CALL regla3)
SELECT
  exp.caso,
  exp.persona,
  COALESCE(act.unif_real, 0) AS unif_real,
  exp.exp_unif,
  CASE WHEN COALESCE(act.unif_real, 0) = exp.exp_unif THEN 'PASSED' ELSE 'FAILED' END AS estado
FROM (
  SELECT 'TC-R3-01' AS caso, 930001 AS persona, 0 AS exp_unif
  UNION ALL SELECT 'TC-R3-08', 930008, 1
  UNION ALL SELECT 'TC-R3-10', 930010, 0
) exp
LEFT JOIN (
  SELECT r.id_buro_persona, COUNT(*) AS unif_real
  FROM bdm_stage.unificacion_direccion u
  JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_persona_ubic = u.cod_dw_persona_ubic
  WHERE u.unifica_atributos = 3
    AND r.id_buro_persona IN (930001, 930008, 930010)
  GROUP BY 1
) act ON act.id_buro_persona = exp.persona
ORDER BY exp.caso;

-- G4) Resumen PASSED/FAILED
SELECT estado, COUNT(*) AS n
FROM (
  SELECT CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS estado
  FROM bdm_stage.perf_persona_meta m
  WHERE m.scenario_code = 'R2_EMPATE'
    AND EXISTS (
      SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
      JOIN bdm_stage.unificacion_direccion u
        ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
      WHERE r.id_buro_persona = m.id_buro_persona
    )
) t
GROUP BY 1;
