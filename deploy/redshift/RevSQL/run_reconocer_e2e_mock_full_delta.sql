-- Rollback 1:1 run_reconocer_e2e_mock_full_delta.sql
-- El script hace tres cosas que dejan rastro: corre los ciclos (salidas y
-- control del mock), escribe la evidencia de los gates, y SIEMBRA las
-- direcciones del paso de mutacion.
--
-- La mutacion es lo unico que agrega INSUMO: la k = 3 de los ARQ 21 y 22 para
-- las primeras 100 replicas. Se borra con la misma formula con que se inserto.
-- Cae dentro del rango que ya limpia el rollback de seed_mock_matriz_r2
-- (9210000..9560999), pero se repite aqui para que el rollback sea 1:1 con lo
-- que este script crea.
DELETE FROM bdm_stage.direccion_fisica
 WHERE cod_dw_direccion_fisica IN (
   SELECT (9000000 + a.arq * 10000 + n.i) * 10 + 3
   FROM (SELECT 21 AS arq UNION ALL SELECT 22) a
   CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 100);

DELETE FROM bdm_stage.relacion_persona_ubicacion
 WHERE cod_dw_persona_ubic IN (
   SELECT (9000000 + a.arq * 10000 + n.i) * 10 + 3
   FROM (SELECT 21 AS arq UNION ALL SELECT 22) a
   CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 100);

-- Evidencia de los gates y salidas del ciclo. Las tablas las elimina strct.
TRUNCATE TABLE bdm_stage.mock_unif_ca_result;
TRUNCATE TABLE bdm_stage.mock_unif_convergencia;
TRUNCATE TABLE bdm_datos.unificacion_direccion_mock;
TRUNCATE TABLE bdm_datos.rpu_generada_mock;
TRUNCATE TABLE bdm_datos.direccion_fisica_generada_mock;
TRUNCATE TABLE bdm_datos.unif_control_etapa_mock;
TRUNCATE TABLE bdm_datos.unif_control_mock;
