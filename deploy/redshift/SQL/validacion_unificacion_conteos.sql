-- ============================================================
-- validacion_unificacion_conteos.sql
-- Conteos post-corrida Unificacion para DPLY Jenkins (solo agregados).
-- Evita drill-down detallado (Q-R1-DIR-DETALLE etc.) que en #252
-- excedio el limite de 12000 celdas del pipeline HTML.
-- UTF-8 sin BOM.
-- ============================================================

-- Universo RPU (vista EDF)
SELECT
  'univ_rpu' AS metrica,
  COUNT(*)::BIGINT AS rpus,
  COUNT(DISTINCT id_buro_persona)::BIGINT AS personas,
  COUNT(DISTINCT cod_dw_ubic)::BIGINT AS ubicaciones
FROM bdm_tempo.v_xpm_relacion_persona_ubicacion;

-- Salida unificacion por regla
SELECT
  unifica_atributos AS regla,
  COUNT(*)::BIGINT AS filas,
  COUNT(DISTINCT cod_dw_persona_ubic)::BIGINT AS personas_ubic,
  COUNT(DISTINCT cod_dw_direccion_unificada)::BIGINT AS dir_unif
FROM bdm_datos.unificacion_direccion
GROUP BY 1
ORDER BY 1;

-- Totales
SELECT
  'total_unificacion' AS metrica,
  COUNT(*)::BIGINT AS filas,
  COUNT(DISTINCT lote)::BIGINT AS lotes
FROM bdm_datos.unificacion_direccion;

-- Ultima corrida control
SELECT
  corrida_id,
  modo,
  lote,
  estado,
  watermark_anterior,
  watermark_nuevo,
  relaciones_entrada,
  personas_distintas,
  total_unificaciones
FROM bdm_datos.unif_control
WHERE corrida_id = (SELECT MAX(corrida_id) FROM bdm_datos.unif_control);
