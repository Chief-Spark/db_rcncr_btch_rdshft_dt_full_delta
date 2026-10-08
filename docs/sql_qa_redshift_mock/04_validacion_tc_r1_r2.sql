-- ============================================================
-- 04_validacion_tc_r1_r2.sql  [LEGACY — NO USAR EN QA ACTUAL]
-- Esquema obsoleto db_redshift (id_padre, regla_aplicada, motivo_empate).
-- Usar en su lugar:
--   sql/qa_redshift/04_validacion_tc_r1_r2_bdm_stage.sql
--   tools/qa_readonly_validation.py  (host QA, solo SELECT)
-- Alineado con SPs: sql/05_sp_regla1.sql, sql/06_sp_regla2.sql
-- ============================================================

-- 0. Smoke test conectividad / conteos base
SELECT 'SMOKE_direccion' AS chk, COUNT(*) AS total FROM db_redshift.direccion;
SELECT 'SMOKE_unificacion_direccion' AS chk, COUNT(*) AS total FROM db_redshift.unificacion_direccion;
SELECT 'SMOKE_persona_ubicacion' AS chk, COUNT(*) AS total FROM db_redshift.persona_ubicacion;

-- ============================================================
-- REGLA 1
-- ============================================================

-- TC-R1-01: CIIU 10 -> padre LAB/CRR con max entidades; hijas ind_unificacion=1; RES excluida
SELECT 'TC-R1-01_violaciones' AS caso,
       COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d_padre ON d_padre.id_direccion = ud.id_padre
JOIN db_redshift.direccion d_hijo  ON d_hijo.id_direccion  = ud.id_hijo
JOIN db_redshift.persona_ubicacion pu_p ON pu_p.id_direccion = ud.id_padre
JOIN db_redshift.persona_ubicacion pu_h ON pu_h.id_direccion = ud.id_hijo
JOIN db_redshift.ciiu_persona c ON c.id_buro_persona = pu_p.id_buro_persona
LEFT JOIN db_redshift.tipo_ubicacion_dir tp ON tp.cod_dw_tipo_ubicacion_dir = pu_p.cod_dw_tipo_ubicacion_dir
LEFT JOIN db_redshift.tipo_ubicacion_dir th ON th.cod_dw_tipo_ubicacion_dir = pu_h.cod_dw_tipo_ubicacion_dir
WHERE ud.regla_aplicada = 'R1'
  AND c.cod_act_econo_ciiu_fte = '10'
  AND (
    tp.descripcion_tipo_ubicacion_dir NOT IN ('LAB','CRR')
    OR d_hijo.ind_unificacion <> 1
    OR th.descripcion_tipo_ubicacion_dir = 'RES'
  );

-- TC-R1-02: CIIU 81/82/90 -> padre RES/CRR; excluye LAB
SELECT 'TC-R1-02_violaciones' AS caso,
       COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d_hijo ON d_hijo.id_direccion = ud.id_hijo
JOIN db_redshift.persona_ubicacion pu_p ON pu_p.id_direccion = ud.id_padre
JOIN db_redshift.persona_ubicacion pu_h ON pu_h.id_direccion = ud.id_hijo
JOIN db_redshift.ciiu_persona c ON c.id_buro_persona = pu_p.id_buro_persona
LEFT JOIN db_redshift.tipo_ubicacion_dir tp ON tp.cod_dw_tipo_ubicacion_dir = pu_p.cod_dw_tipo_ubicacion_dir
WHERE ud.regla_aplicada = 'R1'
  AND c.cod_act_econo_ciiu_fte IN ('81','82','90')
  AND (
    tp.descripcion_tipo_ubicacion_dir NOT IN ('RES','CRR')
    OR d_hijo.ind_unificacion <> 1
  );

-- TC-R1-03: Otros CIIU -> padre con max entidades sin preferencia tipo
SELECT 'TC-R1-03_violaciones' AS caso,
       COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.persona_ubicacion pu_p ON pu_p.id_direccion = ud.id_padre
JOIN db_redshift.ciiu_persona c ON c.id_buro_persona = pu_p.id_buro_persona
WHERE ud.regla_aplicada = 'R1'
  AND c.cod_act_econo_ciiu_fte NOT IN ('10','81','82','90')
  AND ud.id_padre IS NULL;

-- TC-R1-04: Toda hija en unificacion_direccion tiene ind_unificacion=1
SELECT 'TC-R1-04_hijas_sin_flag' AS caso,
       COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_hijo
WHERE ud.regla_aplicada = 'R1'
  AND COALESCE(d.ind_unificacion, 0) <> 1;

-- TC-R1-05: Trazabilidad R1
SELECT 'TC-R1-05_sin_trazabilidad' AS caso,
       COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R1'
  AND (ud.id_padre IS NULL OR ud.id_hijo IS NULL OR ud.fecha_ejecucion IS NULL);

-- TC-R1-06: Bloqueadas / previas hijas no participan
SELECT 'TC-R1-06_bloqueadas_en_r1' AS caso,
       COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_hijo
WHERE ud.regla_aplicada = 'R1'
  AND (COALESCE(d.ind_bloqueo, 0) = 1);

-- TC-R1-07: Segmentación CIIU sin solapamiento (misma persona+ubic, distintos segmentos)
SELECT 'TC-R1-07_solapamiento_ciiu' AS caso,
       COUNT(*) AS anomalias
FROM (
  SELECT pu.id_buro_persona, d.texto_ubicacion, COUNT(DISTINCT c.cod_act_econo_ciiu_fte) AS ciiu_cnt
  FROM db_redshift.unificacion_direccion ud
  JOIN db_redshift.persona_ubicacion pu ON pu.id_direccion = ud.id_hijo
  JOIN db_redshift.direccion d ON d.id_direccion = ud.id_hijo
  JOIN db_redshift.ciiu_persona c ON c.id_buro_persona = pu.id_buro_persona
  WHERE ud.regla_aplicada = 'R1'
  GROUP BY 1, 2
  HAVING COUNT(DISTINCT c.cod_act_econo_ciiu_fte) > 1
) t;

-- TC-R1-08: Empate persistente -> sin unificación
SELECT 'TC-R1-08_empates_unificados' AS caso,
       COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R1'
  AND ud.motivo_empate = 'PERSISTENTE';

-- ============================================================
-- REGLA 2
-- ============================================================

-- TC-R2-01: Complemento vacío vs informado -> gana informado
SELECT 'TC-R2-01_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d_padre ON d_padre.id_direccion = ud.id_padre
JOIN db_redshift.direccion d_hijo  ON d_hijo.id_direccion  = ud.id_hijo
WHERE ud.regla_aplicada = 'R2'
  AND ud.escenario = 'ESC1'
  AND (TRIM(COALESCE(d_padre.complemento,'')) = '' AND TRIM(COALESCE(d_hijo.complemento,'')) <> '');

-- TC-R2-02: Inclusión total -> gana complemento más completo
SELECT 'TC-R2-02_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R2' AND ud.escenario = 'ESC2' AND ud.id_padre IS NULL;

-- TC-R2-03: Esc3 sin NIT -> gana mayor entidades, no crea dirección nueva
SELECT 'TC-R2-03_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_padre
WHERE ud.regla_aplicada = 'R2'
  AND ud.escenario = 'ESC3_SIN_NIT'
  AND COALESCE(d.ind_generada, 0) = 1;

-- TC-R2-04: Esc3 con NIT -> crea dirección combinada ind_generada=1 + persona_ubicacion
SELECT 'TC-R2-04_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_padre
LEFT JOIN db_redshift.persona_ubicacion pu ON pu.id_direccion = ud.id_padre
WHERE ud.regla_aplicada = 'R2'
  AND ud.escenario = 'ESC3_NIT'
  AND (COALESCE(d.ind_generada, 0) <> 1 OR pu.id_direccion IS NULL);

-- TC-R2-05: Esc4 nomenclaturas distintas mismo nivel -> diccionario frecuencias
SELECT 'TC-R2-05_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R2' AND ud.escenario = 'ESC4' AND ud.id_padre IS NULL;

-- TC-R2-06: Esc5 distinto nivel -> dirección combinada ind_generada=1
SELECT 'TC-R2-06_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_padre
WHERE ud.regla_aplicada = 'R2'
  AND ud.escenario = 'ESC5'
  AND COALESCE(d.ind_generada, 0) <> 1;

-- TC-R2-07: Esc6 complementos complejos
SELECT 'TC-R2-07_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R2' AND ud.escenario = 'ESC6' AND ud.id_padre IS NULL;

-- TC-R2-08: Toda dirección creada en R2 tiene ind_generada=1
SELECT 'TC-R2-08_sin_ind_generada' AS caso, COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_padre
WHERE ud.regla_aplicada = 'R2'
  AND ud.ind_direccion_nueva = 1
  AND COALESCE(d.ind_generada, 0) <> 1;

-- TC-R2-09: 0 huérfanas ind_generada=1 sin persona_ubicacion
SELECT 'TC-R2-09_huerfanas' AS caso, COUNT(*) AS anomalias
FROM db_redshift.direccion d
LEFT JOIN db_redshift.persona_ubicacion pu ON pu.id_direccion = d.id_direccion
WHERE COALESCE(d.ind_generada, 0) = 1
  AND pu.id_direccion IS NULL;

-- TC-R2-10: Padre nunca hijo en mismo ciclo R2
SELECT 'TC-R2-10_padre_es_hijo' AS caso, COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.direccion d ON d.id_direccion = ud.id_padre
WHERE ud.regla_aplicada = 'R2'
  AND COALESCE(d.ind_unificacion, 0) = 1;

-- TC-R2-11: Cada hija tiene exactamente 1 padre
SELECT 'TC-R2-11_multiples_padres' AS caso, COUNT(*) AS anomalias
FROM (
  SELECT id_hijo, COUNT(DISTINCT id_padre) AS padres
  FROM db_redshift.unificacion_direccion
  WHERE regla_aplicada = 'R2'
  GROUP BY 1
  HAVING COUNT(DISTINCT id_padre) <> 1
) t;

-- TC-R2-12: Formateo complementos (tokens duplicados / dobles espacios)
SELECT 'TC-R2-12_formato_invalido' AS caso, COUNT(*) AS anomalias
FROM db_redshift.direccion d
WHERE COALESCE(d.ind_generada, 0) = 1
  AND (
    d.complemento LIKE '%  %'
    OR d.complemento ~ '(\m\w+\M)(\s+\1)+'
  );

-- TC-R2-13: Desempate diccionario en nomenclatura coincidente
SELECT 'TC-R2-13_violaciones' AS caso, COUNT(*) AS violaciones
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R2'
  AND ud.escenario = 'ESC4_DIC'
  AND ud.peso_diccionario_padre < ud.peso_diccionario_hijo;

-- TC-R2-14: Empate persistente R2 -> sin unificación
SELECT 'TC-R2-14_empates_unificados' AS caso, COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
WHERE ud.regla_aplicada = 'R2'
  AND ud.motivo_empate = 'PERSISTENTE';

-- ============================================================
-- Integridad transversal
-- ============================================================

-- TC-G-07: Aislamiento intra-persona (0 unificaciones inter-persona)
SELECT 'TC-G-07_inter_persona' AS caso, COUNT(*) AS anomalias
FROM db_redshift.unificacion_direccion ud
JOIN db_redshift.persona_ubicacion pu_h ON pu_h.id_direccion = ud.id_hijo
JOIN db_redshift.persona_ubicacion pu_p ON pu_p.id_direccion = ud.id_padre
WHERE pu_h.id_buro_persona <> pu_p.id_buro_persona;
