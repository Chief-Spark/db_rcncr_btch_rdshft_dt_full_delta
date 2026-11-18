-- =====================================================================
-- VISUAL DE UNA CORRIDA: los TRES niveles de la capa de observabilidad
-- =====================================================================
-- Se lee en tres preguntas y EN ESTE ORDEN:
--   1. Reviento?            -> estado del nivel 1 (*_control).
--                              'completado' dice que no hubo excepcion.
--                              NADA MAS QUE ESO.
--   2. Se quedo a medias?   -> todas las etapas del nivel 2 en 'completado'.
--   3. Hizo algo?           -> los conteos. Es la unica pregunta que importa
--                              y la unica que el verde NO contesta.
--
-- CONTEOS QUE NO SON REALES, y conviene no leerlos como tales:
--   unif_control_etapa y ord_control_etapa traen los conteos en 0 LITERAL.
--   Son marcadores: valen por estado y por tiempos. Los de nov_control_etapa
--   (altas / cambios / bajas) SI son reales y son el mejor detector de
--   cambio que hay.
--
-- NULL NO ES 0 en los censos: NULL dice "no hay senal con la que medir",
--   0 diria "la busque y no habia". Por eso la consulta imprime 'NULL'.
--
-- CERO FILAS NO ES "SALIO BIEN": es que ese lote no existe en esa tabla.
--
-- UNICO PARAMETRO: el lote, en la primera linea.
-- =====================================================================

WITH par AS (
  SELECT CAST(20261112 AS INTEGER) AS p_lote
)

-- ---------- NIVEL 1: la corrida ----------
SELECT
  CAST(1 AS INTEGER)                        AS orden,
  CAST('1 CORRIDA'   AS VARCHAR(20))        AS nivel,
  CAST('UNIFICACION' AS VARCHAR(20))        AS proceso,
  CAST('corrida ' || CAST(c.corrida_id AS VARCHAR) || ' | modo ' || c.modo ||
       CASE WHEN c.bootstrap THEN ' (BOOTSTRAP)' ELSE '' END
       AS VARCHAR(300))                     AS detalle,
  CAST(c.estado AS VARCHAR(16))             AS estado,
  c.fecha_hora_inicio                       AS inicio,
  c.fecha_hora_fin                          AS fin,
  CAST(DATEDIFF(second, c.fecha_hora_inicio, c.fecha_hora_fin) AS INTEGER) AS seg,
  CAST('watermark ' || COALESCE(CAST(c.watermark_anterior AS VARCHAR), 'NULL') ||
       ' -> '           || COALESCE(CAST(c.watermark_nuevo AS VARCHAR), 'NULL') ||
       ' | relaciones ' || COALESCE(CAST(c.relaciones_entrada AS VARCHAR), 'NULL') ||
       ' | personas '   || COALESCE(CAST(c.personas_distintas AS VARCHAR), 'NULL') ||
       ' | unificaciones ' || COALESCE(CAST(c.total_unificaciones AS VARCHAR), 'NULL')
       AS VARCHAR(1000))                    AS metricas
FROM bdm_datos.unif_control c CROSS JOIN par
WHERE c.lote = par.p_lote

UNION ALL
SELECT 2, '1 CORRIDA', 'ORDENAMIENTO',
       'corrida ' || CAST(c.corrida_id AS VARCHAR) || ' | modo ' || c.modo ||
       CASE WHEN c.bootstrap THEN ' (BOOTSTRAP)' ELSE '' END ||
       ' | betas ' || COALESCE(c.version_betas, 'NULL'),
       c.estado, c.fecha_hora_inicio, c.fecha_hora_fin,
       DATEDIFF(second, c.fecha_hora_inicio, c.fecha_hora_fin),
       'watermark ' || COALESCE(CAST(c.watermark_anterior AS VARCHAR), 'NULL') ||
       ' -> '          || COALESCE(CAST(c.watermark_nuevo AS VARCHAR), 'NULL') ||
       ' | personas '  || COALESCE(CAST(c.personas_entrada AS VARCHAR), 'NULL') ||
       ' | contactos ' || COALESCE(CAST(c.contactos_entrada AS VARCHAR), 'NULL') ||
       ' | scores '    || COALESCE(CAST(c.scores_generados AS VARCHAR), 'NULL')
FROM bdm_datos.ord_control c CROSS JOIN par
WHERE c.lote = par.p_lote

UNION ALL
SELECT 3, '1 CORRIDA', 'NOVEDADES',
       'corrida ' || CAST(c.corrida_id AS VARCHAR) || ' | modo ' || c.modo ||
       CASE WHEN c.bootstrap THEN ' (BOOTSTRAP)' ELSE '' END,
       c.estado, c.fecha_hora_inicio, c.fecha_hora_fin,
       DATEDIFF(second, c.fecha_hora_inicio, c.fecha_hora_fin),
       'watermark ' || COALESCE(CAST(c.watermark_anterior AS VARCHAR), 'NULL') ||
       ' -> '           || COALESCE(CAST(c.watermark_nuevo AS VARCHAR), 'NULL') ||
       ' | relaciones ' || COALESCE(CAST(c.relaciones_entrada AS VARCHAR), 'NULL') ||
       ' | personas '   || COALESCE(CAST(c.personas_distintas AS VARCHAR), 'NULL') ||
       ' | filas MAT '  || COALESCE(CAST(c.filas_mat_escritas AS VARCHAR), 'NULL')
FROM bdm_datos.nov_control c CROSS JOIN par
WHERE c.lote = par.p_lote

-- ---------- NIVEL 2: las etapas ----------
UNION ALL
SELECT 11, '2 ETAPA', 'UNIFICACION', e.etapa,
       e.estado, e.fecha_hora_inicio, e.fecha_hora_fin,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin),
       'MARCADOR (0 literal)' ||
       CASE WHEN e.etapa = 'geo'
            THEN ' | geo exportados ' || COALESCE(CAST(e.candidatos_geo_exportados AS VARCHAR), 'NULL') ||
                 ' | geo cargados '   || COALESCE(CAST(e.candidatos_geo_cargados AS VARCHAR), 'NULL')
            ELSE '' END
FROM bdm_datos.unif_control_etapa e CROSS JOIN par
WHERE e.lote = par.p_lote

UNION ALL
SELECT 12, '2 ETAPA', 'ORDENAMIENTO', e.etapa,
       e.estado, e.fecha_hora_inicio, e.fecha_hora_fin,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin),
       'MARCADOR (0 literal): entrada ' || COALESCE(CAST(e.filas_entrada AS VARCHAR), 'NULL') ||
       ' | salida ' || COALESCE(CAST(e.filas_salida AS VARCHAR), 'NULL')
FROM bdm_datos.ord_control_etapa e CROSS JOIN par
WHERE e.lote = par.p_lote

UNION ALL
SELECT 13, '2 ETAPA', 'NOVEDADES', e.etapa,
       e.estado, e.fecha_hora_inicio, e.fecha_hora_fin,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin),
       'REAL: entrada ' || COALESCE(CAST(e.relaciones_entrada AS VARCHAR), 'NULL') ||
       ' | personas '   || COALESCE(CAST(e.personas_distintas AS VARCHAR), 'NULL') ||
       ' | altas '      || COALESCE(CAST(e.filas_altas AS VARCHAR), 'NULL') ||
       ' | cambios '    || COALESCE(CAST(e.filas_cambios AS VARCHAR), 'NULL') ||
       ' | bajas '      || COALESCE(CAST(e.filas_bajas AS VARCHAR), 'NULL')
FROM bdm_datos.nov_control_etapa e CROSS JOIN par
WHERE e.lote = par.p_lote

-- ---------- NIVEL 3: los censos (aqui si hay conteos de verdad) ----------
UNION ALL
SELECT 21, '3 CENSO', 'UNIFICACION',
       'alcance | watermark ' || COALESCE(CAST(a.watermark_usado AS VARCHAR), 'NULL') ||
       ' (' || COALESCE(a.watermark_origen, 'NULL') || ')',
       CASE WHEN a.modo = 'FULL'                              THEN 'FULL'
            WHEN a.ventana_por_fecha IS NULL                  THEN 'SIN DATO'
            WHEN a.ventana_por_fecha = a.ventana_en_la_frontera THEN 'SIN NOVEDAD'
            ELSE 'CON NOVEDAD' END,
       a.fecha_hora, a.fecha_hora, 0,
       'por fecha '      || COALESCE(CAST(a.ventana_por_fecha AS VARCHAR), 'NULL') ||
       ' | EN LA FRONTERA ' || COALESCE(CAST(a.ventana_en_la_frontera AS VARCHAR), 'NULL') ||
       ' | fecha nula '  || COALESCE(CAST(a.ventana_por_fecha_nula AS VARCHAR), 'NULL') ||
       ' | ventana personas ' || COALESCE(CAST(a.ventana_personas AS VARCHAR), 'NULL') ||
       ' | universo '    || COALESCE(CAST(a.universo_relaciones AS VARCHAR), 'NULL') ||
       ' rel / '         || COALESCE(CAST(a.universo_personas AS VARCHAR), 'NULL') || ' pers'
FROM bdm_datos.unif_alcance_censo a CROSS JOIN par
WHERE a.lote = par.p_lote

UNION ALL
SELECT 22, '3 CENSO', 'ORDENAMIENTO',
       'alcance | watermark ' || COALESCE(CAST(a.watermark_usado AS VARCHAR), 'NULL') ||
       ' (' || COALESCE(a.watermark_origen, 'NULL') || ')',
       CASE WHEN COALESCE(a.stg_residuales, 0) > 0 THEN 'RESIDUALES'
            WHEN COALESCE(a.fuera_ventana_dentro, 0) > 0 THEN 'FUGA VENTANA'
            ELSE 'OK' END,
       a.fecha_hora, a.fecha_hora, 0,
       'alcance ' || COALESCE(CAST(a.alcance_filas AS VARCHAR), 'NULL') ||
       ' filas / ' || COALESCE(CAST(a.alcance_personas AS VARCHAR), 'NULL') || ' pers' ||
       ' | por ubicacion ' || COALESCE(CAST(a.por_ubicacion AS VARCHAR), 'NULL') ||
       ' | por unificacion ' || COALESCE(CAST(a.por_unificacion AS VARCHAR), 'NULL') ||
       ' | por cuenta ' || COALESCE(CAST(a.por_cuenta AS VARCHAR), 'NULL') ||
       ' | fuera ventana ' || COALESCE(CAST(a.fuera_ventana_total AS VARCHAR), 'NULL') ||
       ' (entraron ' || COALESCE(CAST(a.fuera_ventana_dentro AS VARCHAR), 'NULL') || ')' ||
       ' | residuales ' || COALESCE(CAST(a.stg_residuales AS VARCHAR), 'NULL')
FROM bdm_datos.ord_alcance_censo a CROSS JOIN par
WHERE a.lote = par.p_lote

-- ---------- NIVEL 3 bis: el reparto de la Regla 2 ----------
UNION ALL
SELECT 31, '3 CENSO', 'UNIF R2',
       COALESCE(e.n_id, 'SIN SELLO') || ' | ' || e.escenario,
       CASE WHEN e.n_id IS NULL AND e.direcciones > 0 THEN 'REVISAR' ELSE 'OK' END,
       e.fecha_hora, e.fecha_hora, 0,
       'direcciones ' || CAST(e.direcciones AS VARCHAR) ||
       ' | personas ' || CAST(e.personas AS VARCHAR) ||
       ' | legado ' || e.ref_legado
FROM bdm_datos.unif_escenario_censo e CROSS JOIN par
WHERE e.lote = par.p_lote

ORDER BY orden, inicio NULLS LAST, detalle;
