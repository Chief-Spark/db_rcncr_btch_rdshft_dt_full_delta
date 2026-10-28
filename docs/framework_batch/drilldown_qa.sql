-- ============================================================
-- DRILL-DOWN DE LA VIA REAL EN QA (cuenta 667397050561)
-- Extracto de dt/docs/DRILLDOWN_VIA_REAL.sql con SOLO lo que el log del
-- job QA/DATABASE #196 no imprime: Niveles 0, 1 y 2. El Nivel 3 (Novedades)
-- ya salio completo en ese log y no hace falta volver a pedirlo.
--
-- EL LOTE DE QA ES EL MISMO QUE EL DE DEV: 1356301 (real). 13566xx = mock.
-- corrida_id = 1 es el FULL bootstrap, el comparable con la pasada 1 de DEV.
-- En DBeaver: cambiar a la base del pipeline ANTES de ejecutar (abre en 'dba',
-- donde no existen bdm_datos / bdm_tempo / bdm_stage).
--
-- Cada bloque trae ref_dev con lo que dio el job DEV/DATABASE #491, para que
-- el numero de QA se lea contra algo y no en el vacio.
-- ============================================================


-- ============================================================
-- NIVEL 0 - EL EMBUDO DE ENTRADA
-- Filtro: sp_unificacion_r1_preparar_insumo.sql:52,104,105
-- ref_dev: 299.575 relaciones -> 78.192 entran (26,1%); 221.383 por bloqueo
-- OJO: 'ya unificada' da cero al ARRANCAR de un FULL, porque el paso 6 trunca
-- unificacion_direccion antes de preparar el insumo
-- (16_sp_unificacion_ciclo.sql:204-214). Medido DESPUES del build da otra cosa.
-- ============================================================
SELECT COUNT(*)                                                  AS filas_rpu,
       COUNT(DISTINCT cod_dw_persona_ubic)                       AS ubicaciones,
       COUNT(DISTINCT id_buro_persona)                           AS personas,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 1 THEN 1 ELSE 0 END) AS caen_bloqueada,
       SUM(CASE WHEN ind_unificacion IS NOT NULL THEN 1 ELSE 0 END) AS caen_ya_unificada,
       SUM(CASE WHEN ind_unificacion IS NULL
                 AND COALESCE(bloqueado,0) = 0 THEN 1 ELSE 0 END) AS entran
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion;


-- NIVEL 0b - LA CONCENTRACION DEL BLOQUEO: en DEV son personas juridicas.
-- ref_dev: 106 NIT con 134.357 relaciones (44,9% de la RPU) y 8 CC con 7.257.
SELECT id_buro_persona, cod_pin_persona,
       COUNT(*)                            AS relaciones,
       COUNT(DISTINCT cod_dw_persona_ubic) AS ubicaciones,
       MAX(COALESCE(bloqueado,0))          AS alguna_bloqueada
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
 GROUP BY id_buro_persona, cod_pin_persona
HAVING COUNT(*) > 500
 ORDER BY relaciones DESC
 LIMIT 30;


-- ============================================================
-- NIVEL 1 - UNIFICACION: que resolvio cada regla
-- unifica_atributos SELLA LA REGLA: 1 = R1, 2 = R2, 3 = R3
-- ref_dev: R1 = 0, R2 = 2, R3 = 17. Total 19 sobre 78.192 que entraron.
-- ============================================================
SELECT CASE unifica_atributos WHEN 1 THEN 'R1 - misma direccion exacta'
                              WHEN 2 THEN 'R2 - cascada de complementos'
                              WHEN 3 THEN 'R3 - GEO via y puerta'
                              ELSE 'sin sello' END AS regla,
       COUNT(*)                                     AS unificaciones,
       COUNT(DISTINCT cod_dw_direccion_unificada)   AS padres,
       COUNT(DISTINCT cod_dw_persona_ubic)          AS hijas
  FROM bdm_datos.unificacion_direccion
 WHERE lote = 1356301
 GROUP BY unifica_atributos
 ORDER BY unifica_atributos;


-- NIVEL 1b - EL CENSO DE ESCENARIOS DE LA R2. Es la UNICA fuente del reparto:
-- unif_control_etapa trae los conteos en 0 literal (16_sp_unificacion_ciclo:302-308).
-- LA FILA QUE IMPORTA es la BRECHA: 'sin resolver, tenia pareja posible'.
-- ref_dev: BRECHA = 0, 'sin pareja posible' = 78.188. Si la brecha sale > 0,
-- hay casos que el port no cubre y eso SI es trabajo.
SELECT n_id, escenario, ref_legado, direcciones, personas
  FROM bdm_datos.unif_escenario_censo
 WHERE lote = 1356301
 ORDER BY direcciones DESC;


-- NIVEL 1c - TIEMPOS DE UNIFICACION. Las seis regla2_esc* se omiten a
-- proposito: son marcadores y repiten el intervalo de regla2.
-- ref_dev: regla1 21 s, regla2 73 s (56% del total), geo 8 s, regla3 19 s.
SELECT etapa, estado,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.unif_control_etapa
 WHERE lote = 1356301 AND corrida_id = 1
   AND etapa NOT LIKE 'regla2_esc%'
 ORDER BY fecha_hora_inicio;


-- NIVEL 1d - EL LOTE GEO: cuantos candidatos salieron y en que estado quedo.
-- En QA el UNLOAD muere con el rol viejo (rcncr-batch-redshift-geo) hasta que
-- se despliegue strct a3b88e5, de modo que se espera estado 'fallido'.
-- ref_dev: 114.703 candidatos (= ubicaciones fisicas), fallido en el UNLOAD.
SELECT lote, estado, fase_fallo, conteo_esperado,
       LEFT(COALESCE(ultimo_error,''), 120) AS error_recortado,
       fecha_hora_inicio
  FROM bdm_datos.geo_lote_control
 ORDER BY lote DESC
 LIMIT 10;


-- ============================================================
-- NIVEL 2 - ORDENAMIENTO: el reparto por canal
-- CUIDADO: AQUI EL EMBUDO SE BIFURCA Y NO SE ESTRECHA. DIR sale de la RPU,
-- pero TEL, CEL y EMAIL salen de v_xpm_contacto_canal, que es otra tabla y
-- otro grano (una fila por canal, no por ubicacion).
-- ref_dev (61 s): DIR 64.393 / 58.642 / lugar_max 47 | EMA 59.756 / 58.485 / 57
--                 CEL 48.493 / 47.978 / 5 | TEL 12.600 / 10.746 / 40
--                 suma 185.242 = scores_generados de ord_control
-- ============================================================
SELECT canal,
       COUNT(*)                        AS filas_scoreadas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       MAX(lugar)                      AS lugar_max,
       MIN(score) AS score_min, MAX(score) AS score_max,
       ROUND(AVG(score), 2) AS score_medio
  FROM bdm_datos.score_ordenamiento
 WHERE id_buro_persona NOT BETWEEN 9000000 AND 9999999   -- fuera la banda mock
 GROUP BY canal
 ORDER BY filas_scoreadas DESC;


-- NIVEL 2b - TIEMPOS DEL ORDENAMIENTO, etapa por etapa.
-- ref_dev: preparar 24 s de los 61 s del proceso.
SELECT etapa, estado,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.ord_control_etapa
 WHERE lote = 1356301 AND corrida_id = 1
 ORDER BY fecha_hora_inicio;


-- NIVEL 2c - EL ALCANCE, y por que rama entro cada persona.
-- Las cuatro columnas por_* en NULL dicen 'no hay senal con la que medir',
-- que es distinto de 0. En FULL la rama de cuenta no se evalua.
SELECT corrida_id, modo, watermark_usado, watermark_origen,
       alcance_filas, alcance_personas,
       por_ubicacion, por_unificacion, por_cuenta, stg_residuales
  FROM bdm_datos.ord_alcance_censo
 WHERE lote = 1356301
 ORDER BY corrida_id;


-- ============================================================
-- NIVEL 4 - EL EMBUDO EN UNA SOLA FILA (lo que se lleva a una reunion)
-- ref_dev: 58.878 personas | 299.575 relaciones | 78.192 entran (26,1%)
--          19 unificaciones | 185.242 scores | 363.327 filas MAT | 263 s
-- ============================================================
WITH e AS (
  SELECT COUNT(*) AS rel_total,
         COUNT(DISTINCT CASE WHEN ind_unificacion IS NULL
                              AND COALESCE(bloqueado,0) = 0
                             THEN cod_dw_persona_ubic END) AS rel_entran,
         COUNT(DISTINCT id_buro_persona) AS personas
    FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
), u AS (
  SELECT COUNT(*) AS unificaciones
    FROM bdm_datos.unificacion_direccion WHERE lote = 1356301
), o AS (
  SELECT COUNT(*) AS scores FROM bdm_datos.score_ordenamiento
   WHERE id_buro_persona NOT BETWEEN 9000000 AND 9999999
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
       u.unificaciones, o.scores, t.seg AS segundos_cadena
  FROM e CROSS JOIN u CROSS JOIN o CROSS JOIN t;
