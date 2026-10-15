-- ============================================================
-- Criterios de aceptacion Ordenamiento — Modo A REAL (DPLY)
-- Par: docs/CRITERIOS_ACEPTACION_ORDENAMIENTO_REAL_Y_MOCK.md
-- beta_ordenamiento: (canal, cod_caracteristica, valor_beta)
-- UTF-8 sin BOM.
-- ============================================================

-- CA-O01 scores por canal
SELECT 'CA-O01' AS criterio_ca, canal, COUNT(*)::BIGINT AS scores
FROM bdm_datos.score_ordenamiento
GROUP BY 1, 2 ORDER BY 2;

-- CA-O02 betas 47
SELECT 'CA-O02' AS criterio_ca, COUNT(*)::BIGINT AS n_betas
FROM bdm_datos.beta_ordenamiento;

-- CA-O03 hijas con orden = 0
SELECT 'CA-O03' AS criterio_ca, COUNT(*)::BIGINT AS hijas_con_orden_incorrecto
FROM bdm_tempo.v_rpu_post_unificacion rpu
INNER JOIN bdm_datos.rpu_orden_prioridad op
  ON op.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
WHERE COALESCE(rpu.ind_unificacion, 0) = 1;

-- CA-O04 RANK-01 (Caso B si existe)
SELECT 'CA-O04' AS criterio_ca, cod_dw_persona_ubic AS rpu, score, lugar
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 2848501447849812647 AND canal = 'DIR'
ORDER BY lugar;

-- CA-O05 F3-02 (Caso A hija 3)
SELECT 'CA-O05' AS criterio_ca, COUNT(*)::BIGINT AS scores_hija
FROM bdm_datos.score_ordenamiento
WHERE cod_dw_persona_ubic = 3;

-- CA-O06 canales Caso A
SELECT 'CA-O06' AS criterio_ca, canal, score, lugar
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 3228096126421495389
ORDER BY canal, lugar;

-- CA-O07 orden = lugar DIR Caso B
SELECT 'CA-O07' AS criterio_ca, o.cod_dw_persona_ubic AS rpu,
       o.orden_prioridad, s.lugar, s.score
FROM bdm_datos.rpu_orden_prioridad o
JOIN bdm_datos.score_ordenamiento s
  ON s.cod_dw_persona_ubic = o.cod_dw_persona_ubic
 AND s.id_buro_persona = o.id_buro_persona
 AND s.canal = 'DIR'
WHERE o.id_buro_persona = 2848501447849812647
ORDER BY o.orden_prioridad;

-- CA-O08 empate DIR (0 filas en REAL = N/A)
SELECT 'CA-O08' AS criterio_ca, id_buro_persona, score, COUNT(*) AS n
FROM bdm_datos.score_ordenamiento
WHERE canal = 'DIR'
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
LIMIT 20;

-- CA-O09 / CA-O10 betas (columna real: cod_caracteristica)
SELECT 'CA-O09' AS criterio_ca, cod_caracteristica, valor_beta
FROM bdm_datos.beta_ordenamiento
WHERE canal = 'TEL' AND cod_caracteristica ILIKE '%TEL020%';

SELECT 'CA-O10' AS criterio_ca, cod_caracteristica, valor_beta
FROM bdm_datos.beta_ordenamiento
WHERE canal = 'EMA'
  AND (cod_caracteristica ILIKE '%EMA003%' OR cod_caracteristica ILIKE '%EMA007%'
       OR cod_caracteristica ILIKE '%EMA018%' OR cod_caracteristica ILIKE '%EMA025%');

-- CA-O11 CEL cobertura A/B
SELECT 'CA-O11' AS criterio_ca, id_buro_persona, score, lugar
FROM bdm_datos.score_ordenamiento
WHERE canal = 'CEL'
  AND id_buro_persona IN (3228096126421495389, 2848501447849812647);

-- CA-O12 multi-DIR
SELECT 'CA-O12' AS criterio_ca, COUNT(*)::BIGINT AS n_dir
FROM bdm_datos.score_ordenamiento
WHERE id_buro_persona = 2848501447849812647 AND canal = 'DIR';
