-- ============================================================
-- DRILL-DOWN DE LA VIA REAL: embudo completo con volumetria y tiempos
-- Referencia: job DEV/DATABASE #491, lote 1356301, pasada 1 de DPLY.
-- Cada bloque trae la columna "ref_491" con lo que dio esa corrida, para que
-- el resultado se lea contra algo y no en el vacio.
--
-- EL DISCRIMINADOR ES EL LOTE: 1356301 = real, 13566xx = mock.
-- En DBeaver, cambiar a la base del pipeline antes de ejecutar (no 'dba').
-- ============================================================


-- ============================================================
-- NIVEL 0 - QUE ENTRA, Y QUE SE CAE ANTES DE EMPEZAR
-- Fuente del filtro: sp_unificacion_r1_preparar_insumo.sql:52,104,105
--   JOIN v_xpm_ubicacion_estandarizada  (INNER; medido: no descarta nada)
--   AND rpu.ind_unificacion IS NULL
--   AND COALESCE(rpu.bloqueado, 0) = 0
--
-- ref_491:  299.575 relaciones ->  78.173 entran (26,1%)
--           221.383 caen por bloqueo (73,9%)  |  19 por ya unificada
--           La suma cuadra exacta: 78.173 + 19 + 221.383 = 299.575
-- ============================================================
SELECT COUNT(*)                                                AS filas_rpu,
       COUNT(DISTINCT cod_dw_persona_ubic)                     AS relaciones,
       COUNT(DISTINCT cod_dw_ubic)                             AS ubicaciones_fisicas,
       COUNT(DISTINCT id_buro_persona)                         AS personas,
       COUNT(DISTINCT CASE WHEN ind_unificacion IS NULL
                            AND COALESCE(bloqueado,0) = 0
                           THEN cod_dw_persona_ubic END)       AS entran,
       COUNT(DISTINCT CASE WHEN COALESCE(bloqueado,0) <> 0
                           THEN cod_dw_persona_ubic END)       AS caen_bloqueada,
       COUNT(DISTINCT CASE WHEN ind_unificacion IS NOT NULL
                           THEN cod_dw_persona_ubic END)       AS caen_ya_unificada
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion;

-- NIVEL 0b - DE DONDE SALE EL BLOQUEO, que son dos ramas distintas
-- (02_vistas_insumo_edf_views.sql:219-220). Saber cual aporta el 73,9% decide
-- si el filtro es correcto o demasiado ancho. SIN MEDIR TODAVIA.
SELECT COUNT(*) AS relaciones_bloqueadas,
       COUNT(DISTINCT id_buro_persona) AS personas_afectadas,
       COUNT(DISTINCT cod_dw_ubic)     AS ubicaciones_afectadas
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
 WHERE COALESCE(bloqueado, 0) <> 0;

-- NIVEL 0c - LA CONCENTRACION, que es lo que hay que descartar.
-- ref_491 (bloque 9a): solo 1.098 personas tienen alguna bloqueada. Si esas
-- 1.098 concentran las 221.383, salen a ~202 ubicaciones por persona y eso
-- es o una empresa con sedes o un colapso de llave. Las 20 de arriba lo dicen.
SELECT id_buro_persona, cod_pin_persona,
       COUNT(*)                        AS relaciones,
       COUNT(DISTINCT cod_dw_ubic)     AS ubicaciones_fisicas,
       SUM(CASE WHEN COALESCE(bloqueado,0) <> 0 THEN 1 ELSE 0 END) AS bloqueadas
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
 GROUP BY 1, 2
 ORDER BY relaciones DESC
 LIMIT 20;


-- ============================================================
-- NIVEL 1 - UNIFICACION: que resolvio cada regla
-- unifica_atributos SELLA LA REGLA: 1 = R1, 2 = R2, 3 = R3
-- (sp_unificacion_r{1,2,3}_*_persist.sql, literal del INSERT).
--
-- ref_491, y es el titular del drill-down:
--   R1 ->  0 unificaciones  en 21 s
--   R2 ->  2 unificaciones  en 73 s   <- 56% del tiempo, 2 filas
--   R3 -> 17 unificaciones  en 19 s
--   GEO -> 114.703 candidatos exportados en 8 s (murio en el UNLOAD, no bloquea)
-- ============================================================
SELECT CASE unifica_atributos WHEN 1 THEN 'R1 - misma direccion exacta'
                              WHEN 2 THEN 'R2 - cascada de complementos'
                              WHEN 3 THEN 'R3 - GEO misma via, puerta cercana'
                              ELSE 'otro (' || unifica_atributos || ')' END AS regla,
       COUNT(*)                                   AS unificaciones,
       COUNT(DISTINCT cod_dw_persona_ubic)        AS ubicaciones_selladas,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS direcciones_destino,
       MIN(fecha_unificacion) AS desde, MAX(fecha_unificacion) AS hasta
  FROM bdm_datos.unificacion_direccion
 WHERE lote = 1356301
 GROUP BY unifica_atributos
 ORDER BY unifica_atributos;

-- NIVEL 1b - EL DESGLOSE DE LA CASCADA DE LA R2, escenario por escenario.
-- Es la UNICA fuente del reparto: unif_control_etapa trae los conteos en 0
-- literal (16_sp_unificacion_ciclo.sql:302-308) y las seis regla2_esc* comparten
-- el mismo intervalo, de modo que sus 71-72 s NO son el tiempo de cada una.
-- n_id es el sello de la etapa que lo resolvio; NULL = no lo resolvio nadie.
SELECT n_id, escenario, ref_legado, direcciones, personas, fecha_hora
  FROM bdm_datos.unif_escenario_censo
 WHERE lote = 1356301
 ORDER BY fecha_hora, n_id NULLS LAST;

-- NIVEL 1c - TIEMPOS DE UNIFICACION. Las seis regla2_esc* se omiten a
-- proposito: son marcadores y repiten el intervalo de regla2.
SELECT etapa, estado,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos,
       candidatos_geo_exportados
  FROM bdm_datos.unif_control_etapa
 WHERE lote = 1356301 AND corrida_id = 1
   AND etapa NOT LIKE 'regla2\\_esc%'
 ORDER BY fecha_hora_inicio;


-- ============================================================
-- NIVEL 2 - ORDENAMIENTO: el reparto por canal
--
-- CUIDADO CON EL EMBUDO AQUI, PORQUE SE BIFURCA Y NO SE ESTRECHA:
-- DIR sale de la RPU (las 78.173 relaciones), pero TEL, CEL y EMAIL salen de
-- v_xpm_contacto_canal, que es OTRA tabla y OTRO grano -- una fila por canal,
-- no por ubicacion. Por eso los cuatro canales suman 185.242 y no 78.173.
--
-- ref_491 (pasada 1, 61 s en total):
--   DIR 64.393 filas / 58.642 personas / lugar_max 47
--   EMA 59.756 / 58.485 / 57
--   CEL 48.493 / 47.978 /  5
--   TEL 12.600 / 10.746 / 40
--   suma 185.242 = scores_generados de ord_control. Cuadra exacto.
-- ============================================================
SELECT canal,
       COUNT(*)                        AS filas_scoreadas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       ROUND(COUNT(*)::DECIMAL(18,4) / NULLIF(COUNT(DISTINCT id_buro_persona),0), 2)
                                       AS items_por_persona,
       MAX(lugar)                      AS lugar_max,
       MIN(score) AS score_min, MAX(score) AS score_max,
       ROUND(AVG(score), 2) AS score_medio
  FROM bdm_datos.score_ordenamiento
 WHERE id_buro_persona NOT BETWEEN 9000000 AND 9999999   -- fuera la banda mock
 GROUP BY canal
 ORDER BY filas_scoreadas DESC;

-- NIVEL 2b - TIEMPOS DEL ORDENAMIENTO, etapa por etapa.
SELECT etapa, estado,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.ord_control_etapa
 WHERE lote = 1356301 AND corrida_id = 1
 ORDER BY fecha_hora_inicio;

-- NIVEL 2c - EL ALCANCE QUE SE PROCESO, y por que rama entro cada persona.
SELECT corrida_id, modo, watermark_usado, watermark_origen,
       alcance_filas, alcance_personas,
       por_ubicacion, por_unificacion, por_cuenta,
       stg_residuales
  FROM bdm_datos.ord_alcance_censo
 WHERE lote = 1356301
 ORDER BY corrida_id;


-- ============================================================
-- NIVEL 3 - NOVEDADES: las siete tablas dominio
-- ref_491 (pasada 1, 70 s): 363.327 filas en total.
--   ubicacion     60.452 / 55.259 personas / 23 s
--   ubi_agregada  59.282 / 55.259         / 21 s
--   acteco       124.263 / 58.512         /  8 s
--   contactab.    60.452 / -              /  3 s
--   info_basica   58.878 / 58.878         /  5 s
--   movilidad y punto_interes: 0 filas, etapa en verde
-- ============================================================
SELECT e.etapa, e.estado,
       e.relaciones_entrada, e.personas_distintas,
       e.filas_altas, e.filas_cambios, e.filas_bajas,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin) AS segundos
  FROM bdm_datos.nov_control_etapa e
 WHERE e.lote = 1356301 AND e.corrida_id = 1
 ORDER BY segundos DESC;

-- NIVEL 3b - VOLUMETRIA FISICA de las siete, para dimensionar.
-- skew_rows muy por encima de 1 dice que el DISTKEY reparte mal; stats_off
-- alto, que el plan se elige a ciegas; unsorted alto, que el SORTKEY no sirve.
SELECT "table" AS tabla, tbl_rows AS filas, size AS bloques_1mb,
       pct_used, unsorted AS pct_sin_ordenar, stats_off AS pct_stats_viejas,
       skew_rows AS sesgo, diststyle, sortkey1, max_varchar
  FROM svv_table_info
 WHERE schema = 'bdm_datos'
   AND "table" IN ('mat_info_ubicacion','mat_info_actividad_economica',
                   'mat_ubicacion_agregada','mat_info_contactabilidad',
                   'mat_info_basica','mat_info_punto_interes','mat_info_movilidad',
                   'unificacion_direccion','score_ordenamiento',
                   'rpu_orden_prioridad','ubicacion_atributo_hash')
 ORDER BY size DESC;


-- ============================================================
-- NIVEL 4 - EL EMBUDO EN UNA SOLA FILA, que es lo que se lleva a una reunion
-- ============================================================
WITH e AS (
  SELECT COUNT(DISTINCT cod_dw_persona_ubic) AS rel_total,
         COUNT(DISTINCT CASE WHEN ind_unificacion IS NULL
                              AND COALESCE(bloqueado,0) = 0
                             THEN cod_dw_persona_ubic END) AS rel_entran,
         COUNT(DISTINCT id_buro_persona) AS personas
    FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
), u AS (
  SELECT COUNT(*) AS unificaciones FROM bdm_datos.unificacion_direccion WHERE lote = 1356301
), o AS (
  SELECT COUNT(*) AS scores FROM bdm_datos.score_ordenamiento
   WHERE id_buro_persona NOT BETWEEN 9000000 AND 9999999
), n AS (
  SELECT (SELECT COUNT(*) FROM bdm_datos.mat_info_ubicacion)
       + (SELECT COUNT(*) FROM bdm_datos.mat_info_actividad_economica)
       + (SELECT COUNT(*) FROM bdm_datos.mat_ubicacion_agregada)
       + (SELECT COUNT(*) FROM bdm_datos.mat_info_contactabilidad)
       + (SELECT COUNT(*) FROM bdm_datos.mat_info_basica)
       + (SELECT COUNT(*) FROM bdm_datos.mat_info_punto_interes)
       + (SELECT COUNT(*) FROM bdm_datos.mat_info_movilidad) AS filas_mat
), t AS (
  SELECT SUM(DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)) AS seg
    FROM ( SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.unif_control
            WHERE lote = 1356301 AND corrida_id = 1
           UNION ALL
           SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.ord_control
            WHERE lote = 1356301 AND corrida_id = 1
           UNION ALL
           SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.nov_control
            WHERE lote = 1356301 AND corrida_id = 1 ) z
)
SELECT e.personas, e.rel_total AS relaciones_rpu, e.rel_entran AS entran_al_proceso,
       ROUND(100.0 * e.rel_entran / NULLIF(e.rel_total,0), 1) AS pct_entra,
       u.unificaciones, o.scores, n.filas_mat, t.seg AS segundos_cadena
  FROM e CROSS JOIN u CROSS JOIN o CROSS JOIN n CROSS JOIN t;
