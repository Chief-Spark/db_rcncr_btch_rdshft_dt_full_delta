-- ============================================================
-- validacion_ordenamiento_conteos.sql
-- Conteos post-corrida Ordenamiento (DPLY Jenkins).
-- Sin checks sobre staging (stg_insumo_*) — el ciclo los DROP al final (#253).
-- UTF-8 sin BOM.
-- ============================================================

SELECT canal, COUNT(*)::BIGINT AS scores,
       ROUND(MIN(score::FLOAT), 4) AS min_score,
       ROUND(MAX(score::FLOAT), 4) AS max_score
FROM bdm_datos.score_ordenamiento
GROUP BY 1 ORDER BY 1;

SELECT 'total_scores' AS paso, COUNT(*)::BIGINT AS total FROM bdm_datos.score_ordenamiento
UNION ALL
SELECT 'rpu_con_orden_prioridad', COUNT(*) FROM bdm_datos.rpu_orden_prioridad
UNION ALL
SELECT 'rpu_ganadoras_con_orden', COUNT(*)
FROM bdm_datos.rpu_orden_prioridad op
INNER JOIN bdm_tempo.v_rpu_post_unificacion rpu
  ON rpu.cod_dw_persona_ubic = op.cod_dw_persona_ubic
WHERE COALESCE(rpu.ind_unificacion, 0) <> 1
UNION ALL
SELECT 'rpu_hijas_sin_orden', COUNT(*)
FROM bdm_tempo.v_rpu_post_unificacion
WHERE COALESCE(ind_unificacion, 0) = 1
UNION ALL
SELECT 'rpu_hijas_con_orden_incorrecto', COUNT(*)
FROM bdm_tempo.v_rpu_post_unificacion rpu
INNER JOIN bdm_datos.rpu_orden_prioridad op
  ON op.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
WHERE COALESCE(rpu.ind_unificacion, 0) = 1;
