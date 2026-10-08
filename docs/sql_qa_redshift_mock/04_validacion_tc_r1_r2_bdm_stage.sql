-- ============================================================
-- 04_validacion_tc_r1_r2_bdm_stage.sql
-- Validación TC-R1/R2 sobre esquema bdm_stage (datos reales QA/DEV)
-- Solo SELECT — no requiere CALL ni INSERT.
-- Esperado: columna v / violaciones = 0 (PASSED)
-- Alineado con fixes en sql/05_sp_regla1.sql y sql/06_sp_regla2.sql
-- ============================================================

-- 0. Preflight: conteos y SPs desplegados
SELECT 'PREFLIGHT_R1' AS chk, COUNT(*) AS total
FROM bdm_stage.unificacion_direccion WHERE unifica_atributos = 1;

SELECT 'PREFLIGHT_R2' AS chk, COUNT(*) AS total
FROM bdm_stage.unificacion_direccion WHERE unifica_atributos = 2;

SELECT 'PREFLIGHT_generada_enriquecida' AS chk, COUNT(*) AS total
FROM bdm_stage.direccion_fisica WHERE COALESCE(generada_enriquecida, 0) = 1;

SELECT 'PREFLIGHT_sp_regla1' AS chk, COUNT(*) AS deployed
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'bdm_stage' AND p.proname = 'sp_unificacion_regla1';

SELECT 'PREFLIGHT_sp_regla2' AS chk, COUNT(*) AS deployed
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'bdm_stage' AND p.proname = 'sp_unificacion_regla2';

-- ============================================================
-- REGLA 1
-- ============================================================

-- TC-R1-01 (oficial): CIIU 10 + escenario R1_ESC1 — padre LAB/CRR
SELECT 'TC-R1-01' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN bdm_stage.relacion_persona_ubicacion rp ON rp.cod_dw_persona_ubic = u.cod_dw_direccion_unificada
JOIN bdm_stage.ciiu_persona c ON c.id_buro_persona = rh.id_buro_persona
JOIN bdm_stage.tipo_ubicacion_dir tp ON tp.cod_dw_tipo_ubicacion_dir = rp.cod_dw_tipo_ubicacion_dir
JOIN bdm_stage.perf_persona_meta m ON m.id_buro_persona = rh.id_buro_persona
WHERE u.unifica_atributos = 1 AND c.cod_act_econo_ciiu_fte = '10'
  AND tp.descripcion_tipo_ubicacion_dir NOT IN ('LAB','CRR')
  AND m.scenario_code = 'R1_ESC1';

-- TC-R1-02: CIIU 81/82/90 -> padre RES/CRR
SELECT 'TC-R1-02' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN bdm_stage.relacion_persona_ubicacion rp ON rp.cod_dw_persona_ubic = u.cod_dw_direccion_unificada
JOIN bdm_stage.ciiu_persona c ON c.id_buro_persona = rh.id_buro_persona
JOIN bdm_stage.tipo_ubicacion_dir tp ON tp.cod_dw_tipo_ubicacion_dir = rp.cod_dw_tipo_ubicacion_dir
WHERE u.unifica_atributos = 1 AND c.cod_act_econo_ciiu_fte IN ('81','82','90')
  AND tp.descripcion_tipo_ubicacion_dir NOT IN ('RES','CRR');

-- TC-R1-03: Otros CIIU -> padre con max entidades
WITH scored AS (
  SELECT rpu.id_buro_persona, ubi.texto_ubicacion, rpu.cod_dw_persona_ubic,
         COALESCE(COUNT(DISTINCT rep.id_buro_suscriptor),0) AS ents
  FROM bdm_stage.relacion_persona_ubicacion rpu
  JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = rpu.cod_dw_ubic
  JOIN bdm_stage.ciiu_persona c ON c.id_buro_persona = rpu.id_buro_persona
  LEFT JOIN bdm_stage.reporte_relacion_persona_ubica rep ON rep.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
  WHERE c.cod_act_econo_ciiu_fte NOT IN ('10','81','82','90')
  GROUP BY 1,2,3
), winners AS (
  SELECT id_buro_persona, texto_ubicacion, cod_dw_persona_ubic,
         ROW_NUMBER() OVER (PARTITION BY id_buro_persona, texto_ubicacion ORDER BY ents DESC, cod_dw_persona_ubic DESC) rn
  FROM scored
)
SELECT 'TC-R1-03' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = rh.cod_dw_ubic
JOIN bdm_stage.ciiu_persona c ON c.id_buro_persona = rh.id_buro_persona
LEFT JOIN winners w ON w.id_buro_persona = rh.id_buro_persona AND w.texto_ubicacion = ubi.texto_ubicacion
  AND w.cod_dw_persona_ubic = u.cod_dw_direccion_unificada AND w.rn = 1
WHERE u.unifica_atributos = 1 AND c.cod_act_econo_ciiu_fte NOT IN ('10','81','82','90')
  AND w.cod_dw_persona_ubic IS NULL;

-- TC-R1-04: Hijas R1 con ind_unificacion = 1 (fix UPDATE en sp_regla1)
SELECT 'TC-R1-04' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_persona_ubic = u.cod_dw_persona_ubic
WHERE u.unifica_atributos = 1 AND COALESCE(r.ind_unificacion, 0) <> 1;

-- TC-R1-05: Trazabilidad R1
SELECT 'TC-R1-05' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion
WHERE unifica_atributos = 1
  AND (cod_dw_persona_ubic IS NULL OR cod_dw_direccion_unificada IS NULL OR fecha_unificacion IS NULL);

-- TC-R1-06: Bloqueadas excluidas
SELECT 'TC-R1-06' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN bdm_stage.bloqueo b ON b.id_buro_persona = r.id_buro_persona
WHERE u.unifica_atributos = 1;

-- TC-R1-07: Segmentación CIIU sin solapamiento
SELECT 'TC-R1-07' AS caso, COUNT(*) AS v FROM (
  SELECT rh.id_buro_persona, ubi.texto_ubicacion
  FROM bdm_stage.unificacion_direccion u
  JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
  JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = rh.cod_dw_ubic
  JOIN bdm_stage.ciiu_persona c ON c.id_buro_persona = rh.id_buro_persona
  WHERE u.unifica_atributos = 1
  GROUP BY 1,2 HAVING COUNT(DISTINCT c.cod_act_econo_ciiu_fte) > 1
) t;

-- TC-R1-08: R1_EMPATE sin unificación (fix stg_regla1_ganador HAVING COUNT(*)=1)
SELECT 'TC-R1-08' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.unificacion_direccion u ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic
WHERE m.scenario_code = 'R1_EMPATE' AND u.unifica_atributos = 1;

-- ============================================================
-- REGLA 2
-- ============================================================

-- TC-R2-01: Esc1 complemento informado gana
WITH winner AS (
  SELECT m.id_buro_persona,
         MAX(CASE WHEN TRIM(COALESCE(df.complemento,'')) <> '' THEN r.cod_dw_persona_ubic END) AS padre
  FROM bdm_stage.perf_persona_meta m
  JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
  JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
  WHERE m.scenario_code = 'R2_ESC1' GROUP BY 1
)
SELECT 'TC-R2-01' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN winner w ON w.id_buro_persona = rh.id_buro_persona
WHERE u.unifica_atributos = 2 AND u.cod_dw_direccion_unificada <> w.padre
  AND rh.id_buro_persona IN (SELECT id_buro_persona FROM bdm_stage.perf_persona_meta WHERE scenario_code = 'R2_ESC1');

-- TC-R2-02: Esc2 complemento más completo
WITH winner AS (
  SELECT m.id_buro_persona, r.cod_dw_persona_ubic AS padre,
         ROW_NUMBER() OVER (PARTITION BY m.id_buro_persona ORDER BY LENGTH(COALESCE(df.complemento,'')) DESC, r.cod_dw_persona_ubic DESC) rn
  FROM bdm_stage.perf_persona_meta m
  JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
  JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
  WHERE m.scenario_code = 'R2_ESC2'
)
SELECT 'TC-R2-02' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion rh ON rh.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN winner w ON w.id_buro_persona = rh.id_buro_persona AND w.rn = 1
WHERE u.unifica_atributos = 2 AND u.cod_dw_direccion_unificada <> w.padre;

-- TC-R2-03: Esc3 sin NIT — no crea generada_enriquecida
SELECT 'TC-R2-03' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
WHERE m.scenario_code = 'R2_ESC3_SIN_NIT' AND COALESCE(df.generada_enriquecida, 0) = 1;

-- TC-R2-04: Esc3 NIT — motor crea generada_enriquecida=1
SELECT 'TC-R2-04' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_ESC3_NIT' AND NOT EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
  WHERE r.id_buro_persona = m.id_buro_persona AND COALESCE(df.generada_enriquecida, 0) = 1
);

-- TC-R2-05: Esc4 — nivel persona sin R2
SELECT 'TC-R2-05' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code IN ('R2_ESC4','R2_ESC4_DIC') AND NOT EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.unificacion_direccion u ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
  WHERE r.id_buro_persona = m.id_buro_persona
);

-- TC-R2-06: Esc5 motor
SELECT 'TC-R2-06' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_ESC5_MOTOR' AND NOT EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
  WHERE r.id_buro_persona = m.id_buro_persona AND COALESCE(df.generada_enriquecida, 0) = 1
);

-- TC-R2-07: Esc6 motor
SELECT 'TC-R2-07' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_ESC6_MOTOR' AND NOT EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
  WHERE r.id_buro_persona = m.id_buro_persona AND COALESCE(df.generada_enriquecida, 0) = 1
);

-- TC-R2-08: RPU motor con generada_enriquecida=1
SELECT 'TC-R2-08' AS caso, COUNT(*) AS v
FROM bdm_stage.direccion_fisica df
JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
JOIN bdm_stage.perf_persona_meta m ON m.id_buro_persona = r.id_buro_persona
WHERE m.scenario_code IN ('R2_ESC3_NIT','R2_ESC5_MOTOR','R2_ESC6_MOTOR')
  AND r.cod_dw_persona_ubic > m.id_buro_persona * 1000 + 2
  AND COALESCE(df.generada_enriquecida, 0) <> 1;

-- TC-R2-09: Sin huérfanas generada_enriquecida=1
SELECT 'TC-R2-09' AS caso, COUNT(*) AS v
FROM bdm_stage.direccion_fisica df
LEFT JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
WHERE COALESCE(df.generada_enriquecida, 0) = 1 AND r.cod_dw_persona_ubic IS NULL;

-- TC-R2-10: Padre nunca hijo en R2
SELECT 'TC-R2-10' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion r ON r.cod_dw_persona_ubic = u.cod_dw_direccion_unificada
WHERE u.unifica_atributos = 2 AND COALESCE(r.ind_unificacion, 0) = 1;

-- TC-R2-11: 1 padre por hija R2
SELECT 'TC-R2-11' AS caso, COUNT(*) AS v FROM (
  SELECT cod_dw_persona_ubic FROM bdm_stage.unificacion_direccion
  WHERE unifica_atributos = 2 GROUP BY 1 HAVING COUNT(DISTINCT cod_dw_direccion_unificada) <> 1
) t;

-- TC-R2-12: Complementos sin dobles espacios
SELECT 'TC-R2-12' AS caso, COUNT(*) AS v
FROM bdm_stage.direccion_fisica
WHERE COALESCE(generada_enriquecida, 0) = 1 AND complemento LIKE '%  %';

-- TC-R2-13: R2_ESC4_DIC nivel persona
SELECT 'TC-R2-13' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_ESC4_DIC' AND NOT EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.unificacion_direccion u ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
  WHERE r.id_buro_persona = m.id_buro_persona
);

-- TC-R2-14: R2_EMPATE sin absorción R2 (fix stg_regla2_e04_ganador)
SELECT 'TC-R2-14' AS caso, COUNT(*) AS v
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_EMPATE' AND EXISTS (
  SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
  JOIN bdm_stage.unificacion_direccion u ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
  WHERE r.id_buro_persona = m.id_buro_persona
);

-- TC-G-07: Aislamiento intra-persona
SELECT 'TC-G-07' AS caso, COUNT(*) AS v
FROM bdm_stage.unificacion_direccion u
JOIN bdm_stage.relacion_persona_ubicacion h ON h.cod_dw_persona_ubic = u.cod_dw_persona_ubic
JOIN bdm_stage.relacion_persona_ubicacion p ON p.cod_dw_persona_ubic = u.cod_dw_direccion_unificada
WHERE h.id_buro_persona <> p.id_buro_persona;
