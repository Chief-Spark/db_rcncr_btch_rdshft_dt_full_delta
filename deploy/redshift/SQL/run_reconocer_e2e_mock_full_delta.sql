-- ============================================================
-- run_reconocer_e2e_mock_full_delta.sql
-- SLCOPRBA-1356 (Fase 5): bateria FULL -> DELTA -> MUTACION -> DELTA del ciclo
-- de Unificacion mock, con el gate por arquetipo tras cada corrida.
--
-- Requiere, en este orden: strct (DDL + vistas), pgm (SPs) y las semillas
-- seed_mock_matriz.sql + seed_mock_matriz_r2.sql, que van antes en la malla.
-- Este script NO siembra: resetea salidas y control, y asume el insumo sembrado.
--
-- POR QUE HAY UN PASO DE MUTACION
--   Desde M7 la vista de insumo deriva ind_unificacion de
--   unificacion_direccion_mock, de modo que el filtro de estado del legado
--   (ind_unificacion IS NULL) vuelve a funcionar. Consecuencia: un DELTA sobre
--   datos SIN CAMBIOS no tiene nada que unificar -- las hijas quedan excluidas y
--   los padres se quedan sin pareja -- y da CERO filas nuevas.
--
--   Eso por si mismo vale certificarlo (corrida 2: idempotencia), pero no es
--   incrementalidad. Para probar que el DELTA SI procesa lo que llega nuevo hace
--   falta mutar el insumo entre las dos corridas, y es lo que hace el paso (3).
--
-- UTF-8 sin BOM.
-- ============================================================

-- ------------------------------------------------------------
-- (0) RESET. Mismo contenido que reset_mock.sql, en linea para que este script
-- sea auto-contenido y se pueda correr suelto. Se borra unif_control_mock
-- porque ahi vive el Watermark: sin eso un 'FULL' heredaria el de la corrida
-- anterior y no partiria de cero.
-- ------------------------------------------------------------
TRUNCATE TABLE bdm_datos.unificacion_direccion_mock;
TRUNCATE TABLE bdm_datos.rpu_generada_mock;
TRUNCATE TABLE bdm_datos.direccion_fisica_generada_mock;
TRUNCATE TABLE bdm_stage.diccionario_complementos;
TRUNCATE TABLE bdm_datos.unif_control_etapa_mock;
TRUNCATE TABLE bdm_datos.unif_control_mock;
TRUNCATE TABLE bdm_datos.geo_atributos_mock;
TRUNCATE TABLE bdm_datos.geo_lote_control_mock;
TRUNCATE TABLE bdm_stage.mock_unif_ca_result;
TRUNCATE TABLE bdm_stage.mock_unif_convergencia;

-- Las direcciones que agrego una mutacion anterior (k = 3 de los ARQ 21 y 22).
-- Se borran aqui y no en el reset generico porque son INSUMO, no salida.
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

-- ------------------------------------------------------------
-- (1) FULL. Borra historico y reconstruye. Watermark resultante = 2026-03-01,
-- que es el MAX(fecha_relacion) de la semilla.
-- ------------------------------------------------------------
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356601' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unificacion_mock_gate_arq(CAST('FULL' AS VARCHAR(16)), 1356601);

-- ------------------------------------------------------------
-- (2) DELTA sobre datos SIN MUTAR. Debe dar CERO filas nuevas: es la prueba de
-- idempotencia, y la que demuestra que el filtro de estado funciona. Antes de
-- M7 esta corrida re-procesaba las 55 000.
-- ------------------------------------------------------------
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356602' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unificacion_mock_gate_arq(CAST('DELTA1' AS VARCHAR(16)), 1356602);

-- ------------------------------------------------------------
-- (3) MUTACION. A 100 personas del ARQ 21 y a 100 del ARQ 22 les LLEGA una
-- direccion nueva (k = 3) con complemento vacio y fecha 2026-06-15, posterior
-- al Watermark que dejo el FULL.
--
-- Complemento vacio porque dispara el escenario 1, que es el primero de la
-- cascada: el resultado esperado no depende de ningun otro escenario. Cada una
-- se unifica contra el padre de su grupo -- la k = 1, 'AP 301', que el FULL
-- dejo sin unificar -- de modo que el DELTA debe producir 100 + 100 filas.
--
-- POR QUE EL ARQ 22, Y NO SOLO EL 21
--   El ARQ 21 es la posicion DENTRO: su fecha original ya cae en la ventana.
--   El ARQ 22 es FUERA (2024-01-15): queda fuera de la ventana y solo entra
--   PORQUE le llego algo nuevo. Al entrar arrastra consigo al padre, que sigue
--   con la fecha vieja. Con una ventana por FILA el padre no entraria, la
--   direccion nueva se quedaria sin pareja y el ARQ 22 daria 0. Que de 100 es
--   el contrafactual que prueba que el driver es por PERSONA (Diseno 2).
--
-- No se siembran reporte_relacion_persona_ubica ni ciiu_persona para estas
-- direcciones: el escenario 1 no mira numero de entidades ni CIIU.
-- ------------------------------------------------------------
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + 3,
   9000000 + a.arq * 10000 + n.i,
   9000000 + a.arq * 10000 + n.i,
  (9000000 + a.arq * 10000 + n.i) * 10 + 1,
  (9000000 + a.arq * 10000 + n.i) * 10 + 3,
  1,
  CAST(NULL AS INTEGER),
  3,
  CAST('2026-06-15' AS DATE),
  1356603,
  '1'
FROM (SELECT 21 AS arq UNION ALL SELECT 22) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 100;

INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, cod_dw_ubic, generada_enriquecida
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + 3,
  '',
  (9000000 + a.arq * 10000 + n.i) * 10 + 1,
  0
FROM (SELECT 21 AS arq UNION ALL SELECT 22) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 100;

-- ------------------------------------------------------------
-- (4) DELTA sobre datos MUTADOS. Debe producir exactamente 200 filas nuevas,
-- 100 del ARQ 21 y 100 del ARQ 22, sin re-escribir ninguna del FULL.
-- ------------------------------------------------------------
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356604' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unificacion_mock_gate_arq(CAST('DELTA2' AS VARCHAR(16)), 1356604);

-- ------------------------------------------------------------
-- (5) VEREDICTO
-- ------------------------------------------------------------
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
ORDER  BY 1;

SELECT
  'e2e_mock_full_delta'                                      AS gate,
  COUNT(*)::BIGINT                                           AS criterios,
  SUM(CASE WHEN estado = 'PASSED' THEN 1 ELSE 0 END)::BIGINT AS passed,
  SUM(CASE WHEN estado = 'FAILED' THEN 1 ELSE 0 END)::BIGINT AS failed
FROM bdm_stage.mock_unif_ca_result;

-- Control de las cuatro corridas: modo efectivo, watermark y metricas.
SELECT corrida_id, lote, modo, bootstrap, estado,
       watermark_anterior, watermark_nuevo,
       relaciones_entrada, personas_distintas, total_unificaciones
FROM   bdm_datos.unif_control_mock
ORDER  BY corrida_id;
