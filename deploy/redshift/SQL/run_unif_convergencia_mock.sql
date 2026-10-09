-- ============================================================
-- run_unif_convergencia_mock.sql
-- SLCOPRBA-1356 (M5): prueba de convergencia del ciclo de Unificacion mock.
-- Secuencia FULL -> DELTA1 -> DELTA2 -> FULL2, con una huella del estado tras
-- cada corrida, y el veredicto por criterio en bdm_stage.mock_unif_ca_result.
--
-- Requiere: strct 12 DDL (mock_unif_convergencia, mock_unif_ca_result),
--           pgm sp_unif_gate_convergencia_snapshot / _evaluar,
--           semilla mock cargada (seed_mock_matriz.sql + seed_mock_matriz_r2.sql).
--
-- QUE MIDE Y POR QUE
--   El motor persiste la direccion generada con ind_unificacion NULL y las
--   vistas de insumo la exponen con UNION ALL, de modo que vuelve a entrar al
--   insumo de la corrida siguiente. El legado lo tolera porque marca los hijos
--   con IND_UNIFICACION = 1 sobre la tabla real
--   (P0020_UNIFICACION_DIRECCION_130.TPT, lineas 281-292) y el filtro de estado
--   los saca para siempre. En Redshift no se puede: el datashare es de solo
--   lectura y las vistas exponen ind_unificacion como CAST(NULL AS INTEGER).
--
--   La cuarta corrida es un FULL de REPROCESO a proposito: es la unica que
--   detecta si el FULL parte de un insumo limpio. El borrado del historico de
--   direcciones generadas se movio al paso 6 del orquestador justamente por
--   esto; cuando vivia dentro del motor (que corre al final), el insumo del
--   propio FULL alcanzaba a ver las generadas de la corrida anterior.
--
-- ORDEN EN LA MALLA: va al FINAL, despues de validacion_gates_cierre_e2e.sql.
-- Este script ejecuta CUATRO ciclos completos y deja el mock en el estado de
-- la cuarta corrida (FULL2). Si corriera antes, cambiaria el insumo de las
-- validaciones de Ordenamiento y del cierre e2e.
--
-- UTF-8 sin BOM.
-- ============================================================

TRUNCATE TABLE bdm_stage.mock_unif_convergencia;
TRUNCATE TABLE bdm_stage.mock_unif_ca_result;

-- (1) FULL: borra historico y reconstruye.
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356501' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unif_gate_convergencia_snapshot(CAST('FULL' AS VARCHAR(32)), 1, 1356501);

-- (2) DELTA1: primera ventana incremental sobre el estado del FULL.
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356502' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unif_gate_convergencia_snapshot(CAST('DELTA1' AS VARCHAR(32)), 2, 1356502);

-- (3) DELTA2: si el ciclo converge, esta corrida no debe cambiar nada.
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356503' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unif_gate_convergencia_snapshot(CAST('DELTA2' AS VARCHAR(32)), 3, 1356503);

-- (4) FULL2: reproceso. Debe reconstruir el mismo estado que (1).
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356504' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unif_gate_convergencia_snapshot(CAST('FULL2' AS VARCHAR(32)), 4, 1356504);

CALL bdm_datos.sp_unif_gate_convergencia_evaluar();

-- Veredicto.
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
ORDER  BY criterio_ca;

-- Huellas, para leer la evolucion corrida a corrida.
SELECT secuencia, etiqueta, objeto, filas, checksum, lote
FROM   bdm_stage.mock_unif_convergencia
ORDER  BY secuencia, objeto;
