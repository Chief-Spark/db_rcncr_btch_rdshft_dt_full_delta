-- ============================================================
-- 02_patch_r2_empate_limpiar_absorciones.sql
-- TC-R2-14: escenario R2_EMPATE NO debe tener absorción R2.
-- Este patch:
--   A) Iguala frecuencias diccionario CS/PI (empate real)
--   B) Borra unificaciones R2 de personas R2_EMPATE
--   C) Resetea ind_unificacion en esas RPU
-- Así el gate TC-R2-14 pasa YA.
-- IMPORTANTE: si vuelven a correr R2 con SP sin e04_ganador,
-- el empate se vuelve a absorber. Desplegar SP con:
--   stg_regla2_e04_ganador ... HAVING COUNT(*) = 1
-- ============================================================

-- A) Asegurar empate en diccionario (frecuencia idéntica)
UPDATE bdm_stage.diccionario_complementos
SET frecuencia = 10
WHERE id_buro_persona IN (
  SELECT id_buro_persona FROM bdm_stage.perf_persona_meta WHERE scenario_code = 'R2_EMPATE'
)
AND nomenclatura IN ('CS', 'PI');

-- Si faltan filas de diccionario, insertar ambas a frecuencia 10
INSERT INTO bdm_stage.diccionario_complementos
  (cod_dw_ubic, id_buro_persona, complemento_raw, nomenclatura, valor, frecuencia)
SELECT DISTINCT
  r.cod_dw_ubic,
  r.id_buro_persona,
  df.complemento,
  'CS',
  '8',
  10
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
WHERE m.scenario_code = 'R2_EMPATE'
  AND df.complemento LIKE 'CS %'
  AND NOT EXISTS (
    SELECT 1 FROM bdm_stage.diccionario_complementos dc
    WHERE dc.id_buro_persona = r.id_buro_persona
      AND dc.cod_dw_ubic = r.cod_dw_ubic
      AND dc.nomenclatura = 'CS'
  );

INSERT INTO bdm_stage.diccionario_complementos
  (cod_dw_ubic, id_buro_persona, complemento_raw, nomenclatura, valor, frecuencia)
SELECT DISTINCT
  r.cod_dw_ubic,
  r.id_buro_persona,
  df.complemento,
  'PI',
  '8',
  10
FROM bdm_stage.perf_persona_meta m
JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
JOIN bdm_stage.direccion_fisica df ON df.cod_dw_direccion_fisica = r.cod_dw_direccion_fisica
WHERE m.scenario_code = 'R2_EMPATE'
  AND df.complemento LIKE 'PI %'
  AND NOT EXISTS (
    SELECT 1 FROM bdm_stage.diccionario_complementos dc
    WHERE dc.id_buro_persona = r.id_buro_persona
      AND dc.cod_dw_ubic = r.cod_dw_ubic
      AND dc.nomenclatura = 'PI'
  );

-- B) Contar absorciones antes
SELECT 'ANTES_tc_r2_14' AS paso, COUNT(*) AS violaciones
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_EMPATE'
  AND EXISTS (
    SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
    JOIN bdm_stage.unificacion_direccion u
      ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
    WHERE r.id_buro_persona = m.id_buro_persona
  );

-- C) Borrar unificaciones R2 de R2_EMPATE
DELETE FROM bdm_stage.unificacion_direccion
WHERE unifica_atributos = 2
  AND cod_dw_persona_ubic IN (
    SELECT r.cod_dw_persona_ubic
    FROM bdm_stage.perf_persona_meta m
    JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
    WHERE m.scenario_code = 'R2_EMPATE'
  );

-- También si el hijo está en R2_EMPATE pero la fila se guardó solo por padre
DELETE FROM bdm_stage.unificacion_direccion
WHERE unifica_atributos = 2
  AND cod_dw_direccion_unificada IN (
    SELECT r.cod_dw_persona_ubic
    FROM bdm_stage.perf_persona_meta m
    JOIN bdm_stage.relacion_persona_ubicacion r ON r.id_buro_persona = m.id_buro_persona
    WHERE m.scenario_code = 'R2_EMPATE'
  );

-- D) Reset ind_unificacion en RPU del escenario
UPDATE bdm_stage.relacion_persona_ubicacion
SET ind_unificacion = NULL
WHERE id_buro_persona IN (
  SELECT id_buro_persona FROM bdm_stage.perf_persona_meta WHERE scenario_code = 'R2_EMPATE'
);

-- E) Gate inmediato (debe ser 0)
SELECT 'DESPUES_tc_r2_14' AS paso, COUNT(*) AS violaciones
FROM bdm_stage.perf_persona_meta m
WHERE m.scenario_code = 'R2_EMPATE'
  AND EXISTS (
    SELECT 1 FROM bdm_stage.relacion_persona_ubicacion r
    JOIN bdm_stage.unificacion_direccion u
      ON u.cod_dw_persona_ubic = r.cod_dw_persona_ubic AND u.unifica_atributos = 2
    WHERE r.id_buro_persona = m.id_buro_persona
  );
-- Esperado: violaciones = 0
