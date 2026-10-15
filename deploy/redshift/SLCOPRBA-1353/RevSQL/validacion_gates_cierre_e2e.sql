-- ============================================================
-- Gates de cierre E2E — Unificación + GEO + Ordenamiento
-- Esperados DEV (referencia 2026-09-04 / 09-16):
--   Unif: C03=0, C04=0, R2>0, R3 puede ser 0 (GEO N/A en DEV)
--   Ord:  scores DIR/TEL/EMA >0; hijas_con_orden_incorrecto = 0
--   Betas: 47 filas RITM5226589
--   Control: lotes E2E FULL=1356201 y DELTA=1356202 completados
-- ============================================================

-- ---- Control corridas E2E FULL luego DELTA ----
SELECT 'E2E_unif_control' AS gate,
       modo,
       lote,
       estado,
       watermark_anterior,
       watermark_nuevo,
       total_unificaciones
FROM bdm_datos.unif_control
WHERE lote IN (1356201, 1356202)
ORDER BY lote, modo;

SELECT 'E2E_ord_control' AS gate,
       modo,
       lote,
       estado
FROM bdm_datos.ord_control
WHERE lote IN (1356201, 1356202)
ORDER BY lote, modo;

-- ---- Unificación ----
SELECT 'U_por_regla' AS gate,
       unifica_atributos,
       COUNT(*)::BIGINT AS n
FROM bdm_datos.unificacion_direccion
GROUP BY 1, 2
ORDER BY 2;

SELECT 'U_C03_hijos_sin_padre' AS gate,
       SUM(CASE WHEN cod_dw_direccion_unificada IS NULL THEN 1 ELSE 0 END)::BIGINT AS n
FROM bdm_datos.unificacion_direccion;

SELECT 'U_C04_autoref' AS gate,
       SUM(CASE WHEN cod_dw_persona_ubic = cod_dw_direccion_unificada THEN 1 ELSE 0 END)::BIGINT AS n
FROM bdm_datos.unificacion_direccion;

SELECT 'U_R3_geo_cobertura' AS gate,
       SUM(CASE WHEN ubi.latitud IS NOT NULL THEN 1 ELSE 0 END)::BIGINT AS con_lat,
       COUNT(*)::BIGINT AS total_rpu
FROM bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
JOIN bdm_tempo.v_xpm_ubicacion_estandarizada ubi ON rpu.cod_dw_ubic = ubi.cod_dw_ubic;

-- ---- Ordenamiento ----
SELECT 'O_scores_por_canal' AS gate,
       canal,
       COUNT(*)::BIGINT AS scores
FROM bdm_datos.score_ordenamiento
GROUP BY 1, 2
ORDER BY 2;

SELECT 'O_betas_ritm' AS gate, COUNT(*)::BIGINT AS n
FROM bdm_datos.beta_ordenamiento;

SELECT 'O_hijas_con_orden_incorrecto' AS gate, COUNT(*)::BIGINT AS n
FROM bdm_tempo.v_rpu_post_unificacion rpu
INNER JOIN bdm_datos.rpu_orden_prioridad op
  ON op.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
WHERE COALESCE(rpu.ind_unificacion, 0) = 1;

SELECT 'O_rpu_con_orden' AS gate, COUNT(*)::BIGINT AS n
FROM bdm_datos.rpu_orden_prioridad;
