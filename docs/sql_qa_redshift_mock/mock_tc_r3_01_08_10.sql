-- ============================================================
-- mock_tc_r3_01_08_10.sql
-- Mocks DEV para TC-R3-01, TC-R3-08, TC-R3-10
-- Ejecutar ANTES de Regla 3; validar con validar_tc_r3_01_08_10.sql
-- ============================================================

-- TC-R3-01 (930001): Manzana — NO debe unificar en R3
-- TC-R3-08 (930008): CL 205 12 33 N vs 35 N — SÍ debe unificar (puerta ±2)
-- TC-R3-10 (930010): empate diccionario vía — NO debe unificar

-- ------------------------------------------------------------
-- A. TC-R3-01 — id_buro_persona 930001
-- ------------------------------------------------------------
INSERT INTO bdm_stage.ubicacion_estandarizada
  (cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, latitud, longitud)
SELECT 930001001, 'MZ 10 20 30 MOCK TC-R3-01', 1, 4.6097000, -74.0817000
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ubicacion_estandarizada WHERE cod_dw_ubic = 930001001);

INSERT INTO bdm_stage.direccion_fisica
  (cod_dw_direccion_fisica, complemento, cod_dw_ubic, tipo_via_principal,
   via_principal, via_generadora, numero_puerta, generada_enriquecida)
SELECT 930001101, '', 930001001, 'MZ', '10', '20', '30', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930001101)
UNION ALL
SELECT 930001102, '', 930001001, 'MZ', '10', '22', '30', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930001102);

INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT 930001, '10'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ciiu_persona WHERE id_buro_persona = 930001);

INSERT INTO bdm_stage.relacion_persona_ubicacion
  (cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
   cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
   orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte)
SELECT 930001001, 930001, 1930001, 930001001, 930001101, 1, CAST(NULL AS INTEGER), 1, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930001001)
UNION ALL
SELECT 930001002, 930001, 1930001, 930001001, 930001102, 1, CAST(NULL AS INTEGER), 2, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930001002);

INSERT INTO bdm_stage.reporte_relacion_persona_ubica
  (cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte, lote)
SELECT 930001001, 930011, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930001001 AND id_buro_suscriptor = 930011
)
UNION ALL
SELECT 930001002, 930012, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930001002 AND id_buro_suscriptor = 930012
);

INSERT INTO bdm_stage.perf_persona_meta (id_buro_persona, persona_seq, scenario_code)
SELECT 930001, 930001, 'MOCK_TC_R3_01'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.perf_persona_meta WHERE id_buro_persona = 930001);

-- ------------------------------------------------------------
-- B. TC-R3-08 — id_buro_persona 930008
-- ------------------------------------------------------------
INSERT INTO bdm_stage.ubicacion_estandarizada
  (cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, latitud, longitud)
SELECT 930008001, 'CL 205 12 33 N MOCK TC-R3-08', 1, 4.6100000, -74.0820000
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ubicacion_estandarizada WHERE cod_dw_ubic = 930008001)
UNION ALL
SELECT 930008002, 'CL 205 12 35 N MOCK TC-R3-08', 1, 4.6101000, -74.0821000
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ubicacion_estandarizada WHERE cod_dw_ubic = 930008002);

INSERT INTO bdm_stage.direccion_fisica
  (cod_dw_direccion_fisica, complemento, cod_dw_ubic, tipo_via_principal,
   via_principal, via_generadora, numero_puerta, generada_enriquecida)
SELECT 930008101, '', 930008001, 'CL', '205', '12', '33', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930008101)
UNION ALL
SELECT 930008102, '', 930008002, 'CL', '205', '12', '35', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930008102);

INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT 930008, '10'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ciiu_persona WHERE id_buro_persona = 930008);

INSERT INTO bdm_stage.relacion_persona_ubicacion
  (cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
   cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
   orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte)
SELECT 930008001, 930008, 1930008, 930008001, 930008101, 1, CAST(NULL AS INTEGER), 1, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930008001)
UNION ALL
SELECT 930008002, 930008, 1930008, 930008002, 930008102, 1, CAST(NULL AS INTEGER), 2, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930008002);

INSERT INTO bdm_stage.reporte_relacion_persona_ubica
  (cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte, lote)
SELECT 930008001, 930081, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930008001 AND id_buro_suscriptor = 930081
)
UNION ALL
SELECT 930008001, 930082, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930008001 AND id_buro_suscriptor = 930082
)
UNION ALL
SELECT 930008002, 930083, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930008002 AND id_buro_suscriptor = 930083
)
UNION ALL
SELECT 930008002, 930084, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930008002 AND id_buro_suscriptor = 930084
)
UNION ALL
SELECT 930008002, 930085, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930008002 AND id_buro_suscriptor = 930085
);

INSERT INTO bdm_stage.perf_persona_meta (id_buro_persona, persona_seq, scenario_code)
SELECT 930008, 930008, 'MOCK_TC_R3_08'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.perf_persona_meta WHERE id_buro_persona = 930008);

-- ------------------------------------------------------------
-- C. TC-R3-10 — id_buro_persona 930010 (empate diccionario)
-- ------------------------------------------------------------
INSERT INTO bdm_stage.ubicacion_estandarizada
  (cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, latitud, longitud)
SELECT 930010001, 'CL 100 50 40 MOCK TC-R3-10-A', 1, 4.6200000, -74.0900000
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ubicacion_estandarizada WHERE cod_dw_ubic = 930010001)
UNION ALL
SELECT 930010002, 'CL 100 52 40 MOCK TC-R3-10-B', 1, 4.6201000, -74.0901000
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ubicacion_estandarizada WHERE cod_dw_ubic = 930010002);

INSERT INTO bdm_stage.direccion_fisica
  (cod_dw_direccion_fisica, complemento, cod_dw_ubic, tipo_via_principal,
   via_principal, via_generadora, numero_puerta, generada_enriquecida)
SELECT 930010101, '', 930010001, 'CL', '100', '50', '40', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930010101)
UNION ALL
SELECT 930010102, '', 930010002, 'CL', '100', '52', '40', CAST(NULL AS INTEGER)
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.direccion_fisica WHERE cod_dw_direccion_fisica = 930010102);

INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT 930010, '10'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.ciiu_persona WHERE id_buro_persona = 930010);

INSERT INTO bdm_stage.relacion_persona_ubicacion
  (cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
   cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
   orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte)
SELECT 930010001, 930010, 1930010, 930010001, 930010101, 1, CAST(NULL AS INTEGER), 1, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930010001)
UNION ALL
SELECT 930010002, 930010, 1930010, 930010002, 930010102, 1, CAST(NULL AS INTEGER), 2, DATE '2025-06-01', 99, 1
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.relacion_persona_ubicacion WHERE cod_dw_persona_ubic = 930010002);

INSERT INTO bdm_stage.reporte_relacion_persona_ubica
  (cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte, lote)
SELECT 930010001, 930101, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010001 AND id_buro_suscriptor = 930101
)
UNION ALL
SELECT 930010001, 930102, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010001 AND id_buro_suscriptor = 930102
)
UNION ALL
SELECT 930010001, 930103, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010001 AND id_buro_suscriptor = 930103
)
UNION ALL
SELECT 930010002, 930104, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010002 AND id_buro_suscriptor = 930104
)
UNION ALL
SELECT 930010002, 930105, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010002 AND id_buro_suscriptor = 930105
)
UNION ALL
SELECT 930010002, 930106, DATE '2025-05-01', 99
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_stage.reporte_relacion_persona_ubica
  WHERE cod_dw_persona_ubic = 930010002 AND id_buro_suscriptor = 930106
);

INSERT INTO bdm_stage.perf_persona_meta (id_buro_persona, persona_seq, scenario_code)
SELECT 930010, 930010, 'MOCK_TC_R3_10'
WHERE NOT EXISTS (SELECT 1 FROM bdm_stage.perf_persona_meta WHERE id_buro_persona = 930010);

SELECT 'mock_r3_loaded' AS chk,
  SUM(CASE WHEN id_buro_persona = 930001 THEN 1 ELSE 0 END) AS p930001,
  SUM(CASE WHEN id_buro_persona = 930008 THEN 1 ELSE 0 END) AS p930008,
  SUM(CASE WHEN id_buro_persona = 930010 THEN 1 ELSE 0 END) AS p930010
FROM bdm_stage.relacion_persona_ubicacion
WHERE id_buro_persona IN (930001, 930008, 930010);
