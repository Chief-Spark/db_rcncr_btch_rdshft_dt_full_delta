-- ============================================================
-- validacion_ordenamiento_gates_full_delta.sql
-- Gates post-corrida Ordenamiento (FULL/DELTA):
--   * 0 hijas mal ordenadas (orden_prioridad inconsistente con score.lugar)
--   * ultima corrida ord_control en estado completado
--   * volumenes basicos score / prioridad
-- ============================================================

-- Gate A: ultima corrida completada
SELECT
  'ord_control_completado' AS gate,
  CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'FAIL' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.ord_control c
WHERE c.corrida_id = (SELECT MAX(corrida_id) FROM bdm_datos.ord_control)
  AND c.estado = 'completado';

-- Gate B: hijas mal ordenadas = 0
-- Una RPU ganadora no unificada debe tener orden_prioridad = MIN(lugar) de sus scores
SELECT
  'hijas_mal_ordenadas' AS gate,
  CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.rpu_orden_prioridad op
INNER JOIN (
  SELECT id_buro_persona, cod_dw_persona_ubic, MIN(lugar) AS lugar_min
  FROM bdm_datos.score_ordenamiento
  GROUP BY 1, 2
) s
  ON s.cod_dw_persona_ubic = op.cod_dw_persona_ubic
 AND s.id_buro_persona = op.id_buro_persona
WHERE op.orden_prioridad <> s.lugar_min;

-- Gate C: volumenes
SELECT
  'volumen_score' AS gate,
  CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARN' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.score_ordenamiento;

SELECT
  'volumen_prioridad' AS gate,
  CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARN' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.rpu_orden_prioridad;
