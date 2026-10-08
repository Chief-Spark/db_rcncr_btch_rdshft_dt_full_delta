-- ============================================================
-- validacion_unificacion_gates_full_delta.sql
-- Gates post-corrida Unificacion FULL/DELTA (control + volumen).
-- ============================================================

SELECT
  'unif_control_completado' AS gate,
  CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'FAIL' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.unif_control c
WHERE c.corrida_id = (SELECT MAX(corrida_id) FROM bdm_datos.unif_control)
  AND c.estado = 'completado';

SELECT
  'volumen_unificacion' AS gate,
  CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARN' END AS resultado,
  COUNT(*) AS filas
FROM bdm_datos.unificacion_direccion;

SELECT
  'unicidad_clave_unificacion' AS gate,
  CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
  COUNT(*) AS filas
FROM (
  SELECT cod_dw_persona_ubic, cod_dw_direccion_unificada, COUNT(*) AS n
  FROM bdm_datos.unificacion_direccion
  GROUP BY 1, 2
  HAVING COUNT(*) > 1
) dups;
