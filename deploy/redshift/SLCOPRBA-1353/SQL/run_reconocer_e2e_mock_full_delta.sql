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
-- sea auto-contenido y se pueda correr suelto. Se borran unif_control_mock y
-- nov_control_mock porque ahi vive el Watermark: sin eso un 'FULL' heredaria el
-- de la corrida anterior y no partiria de cero.
--
-- ESTA COPIA SE HABIA QUEDADO ATRAS, y esa es la leccion de mantenerla al dia.
-- Le faltaban el diccionario de via, el censo de escenarios, los siete
-- mock_ord_* y cert_resultado, ademas de Novedades entera. En el pipeline no se
-- notaba porque reset_mock.sql es el archivo 1 de deploy.par y ya habia hecho
-- el trabajo; se notaba corriendo la bateria suelta -- que es como la corre el
-- banco --, de modo que el banco no reproducia a Jenkins. Si se anade una tabla
-- a reset_mock.sql, se anade tambien aqui, y al reves.
-- ------------------------------------------------------------
-- Salidas de Unificacion
TRUNCATE TABLE bdm_datos.unificacion_direccion_mock;
TRUNCATE TABLE bdm_datos.rpu_generada_mock;
TRUNCATE TABLE bdm_datos.direccion_fisica_generada_mock;
TRUNCATE TABLE bdm_stage.diccionario_complementos;
TRUNCATE TABLE bdm_stage.diccionario_via;

-- Control y traza de Unificacion (aqui vive el Watermark)
TRUNCATE TABLE bdm_datos.unif_control_etapa_mock;
TRUNCATE TABLE bdm_datos.unif_control_mock;
TRUNCATE TABLE bdm_datos.unif_escenario_censo_mock;

-- Ciclo GEO mock
TRUNCATE TABLE bdm_datos.geo_atributos_mock;
TRUNCATE TABLE bdm_datos.geo_lote_control_mock;
-- 2026-10-20: el archivo de vuelta del simulador de ArcGIS. Lo escribe
-- sp_geo_simular_arcgis_mock y sobrevivia al segundo DPLY: la busqueda de
-- resultados del ciclo (sp_rcn_geo_02_buscar_resultados_mock) lo encontraria
-- en el e2e de la segunda pasada y moveria el Lote a 'cargado' (CA-01).
TRUNCATE TABLE bdm_stage.mock_geo_respuesta;

-- Evidencia de gates
TRUNCATE TABLE bdm_stage.mock_unif_ca_result;
TRUNCATE TABLE bdm_stage.mock_unif_convergencia;

-- Salidas de Ordenamiento mock
TRUNCATE TABLE bdm_stage.mock_ord_score;
TRUNCATE TABLE bdm_stage.mock_ord_prioridad;
TRUNCATE TABLE bdm_stage.mock_ord_rpu;
TRUNCATE TABLE bdm_stage.mock_ord_escenario;
TRUNCATE TABLE bdm_stage.mock_ord_control_etapa;
TRUNCATE TABLE bdm_stage.mock_ord_control;
-- SLCOPRBA-1355: el censo de alcance de la Fase 1. Entra aqui en el MISMO
-- commit que su DDL, que es la regla que dejo el job #412.
TRUNCATE TABLE bdm_stage.mock_ord_alcance_censo;
-- SLCOPRBA-1355: el hash de atributos de la Fase 3. Sin truncarlo, la segunda
-- pasada del pipeline encontraria los hash de la primera, el anti-join no
-- veria ninguna direccion como nueva y F3-05 saldria en cero. Misma regla del
-- job #412.
TRUNCATE TABLE bdm_datos.ubicacion_atributo_hash_mock;
-- SLCOPRBA-1355: el hash de atributos de cuenta, Fase 2. Mismo motivo que el
-- de ubicaciones: sin truncarlo, la segunda pasada no veria ninguna cuenta
-- como nueva y F2-07 saldria en cero.
TRUNCATE TABLE bdm_datos.cuenta_atributo_hash_mock;
TRUNCATE TABLE bdm_stage.mock_ord_ca_result;

-- Novedades (P0035): control, tablas finales, contratos de etapa y tablero.
-- Lo que falto hasta el job #412. mat_info_actividad_economica_mock es
-- insert-only por diseno del legado y sin truncar se duplica entre pasadas.
TRUNCATE TABLE bdm_datos.nov_control_etapa_mock;
TRUNCATE TABLE bdm_datos.nov_control_mock;
TRUNCATE TABLE bdm_datos.mat_info_ubicacion_mock;
TRUNCATE TABLE bdm_datos.mat_info_actividad_economica_mock;
TRUNCATE TABLE bdm_datos.mat_ubicacion_agregada_mock;
TRUNCATE TABLE bdm_datos.mat_info_contactabilidad_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_ubica_etapa_9_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_ubica_etapa_2_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_acteco_etapa_1_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_ubiagr_etapa_final_mock;

-- Tableros de certificacion
TRUNCATE TABLE bdm_datos.cert_resultado;
TRUNCATE TABLE bdm_datos.cert_resultado_nov;

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
-- Tablero de certificacion: los 51 criterios de los documentos, con el ID del
-- documento como clave. Corre despues del gate por arquetipo porque consolida
-- su veredicto y el del gate de convergencia.
CALL bdm_datos.sp_cert_evaluar_criterios_mock(CAST('FULL' AS VARCHAR(16)), 1356601);

-- Ordenamiento FULL de la MISMA corrida: una ejecucion e2e es una unidad
-- (unificacion -> GEO -> ordenamiento), no componentes sueltos. GEO ya va
-- dentro de sp_unificacion_mock_ciclo (R1 -> R2 -> GEO -> R3).
CALL bdm_datos.sp_ordenamiento_ejecucion_mock(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356601' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- Tablero de certificacion del ORDENAMIENTO. Corre JUSTO DESPUES del
-- Ordenamiento de esta fase y no al final, porque varios criterios miran
-- tablas de staging y de control que son de la corrida: CA-T03 comprueba que
-- las intermedias ya no existen y CA-T05 compara las personas de entrada de
-- este lote. Evaluado mas tarde mediria otra corrida.
CALL bdm_datos.sp_cert_evaluar_criterios_ord_mock(CAST('FULL' AS VARCHAR(16)), 1356601);

-- NOVEDADES de la MISMA corrida. Corre DESPUES del Ordenamiento porque lee su
-- salida: la etapa 1 del dominio Ubicacion filtra por orden de prioridad no
-- nulo (Novedad.sql:7593) y ese orden lo escribe sp_ordenamiento_consolidacion
-- en bdm_datos.rpu_orden_prioridad. Invertido el orden, Novedades saldria
-- vacio por un efecto de secuencia y no por un defecto.
CALL bdm_datos.sp_novedades_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356601' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_cert_evaluar_criterios_nov_mock(CAST('FULL' AS VARCHAR(16)), 1356601);


-- ------------------------------------------------------------
-- (2) DELTA sobre datos SIN MUTAR. Debe dar CERO filas nuevas: es la prueba de
-- idempotencia, y la que demuestra que el filtro de estado funciona. Antes de
-- M7 esta corrida re-procesaba las 51 000.
-- ------------------------------------------------------------
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356602' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unificacion_mock_gate_arq(CAST('DELTA1' AS VARCHAR(16)), 1356602);
-- Tablero de certificacion: los 51 criterios de los documentos, con el ID del
-- documento como clave. Corre despues del gate por arquetipo porque consolida
-- su veredicto y el del gate de convergencia.
CALL bdm_datos.sp_cert_evaluar_criterios_mock(CAST('DELTA1' AS VARCHAR(16)), 1356602);

-- Ordenamiento DELTA de la misma corrida. Sin mutacion, su alcance tambien
-- debe ser vacio: es la prueba de idempotencia del ordenamiento.
CALL bdm_datos.sp_ordenamiento_ejecucion_mock(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356602' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- Tablero de certificacion del ORDENAMIENTO. Corre JUSTO DESPUES del
-- Ordenamiento de esta fase y no al final, porque varios criterios miran
-- tablas de staging y de control que son de la corrida: CA-T03 comprueba que
-- las intermedias ya no existen y CA-T05 compara las personas de entrada de
-- este lote. Evaluado mas tarde mediria otra corrida.
CALL bdm_datos.sp_cert_evaluar_criterios_ord_mock(CAST('DELTA1' AS VARCHAR(16)), 1356602);

-- NOVEDADES de la MISMA corrida. Corre DESPUES del Ordenamiento porque lee su
-- salida: la etapa 1 del dominio Ubicacion filtra por orden de prioridad no
-- nulo (Novedad.sql:7593) y ese orden lo escribe sp_ordenamiento_consolidacion
-- en bdm_datos.rpu_orden_prioridad. Invertido el orden, Novedades saldria
-- vacio por un efecto de secuencia y no por un defecto.
CALL bdm_datos.sp_novedades_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356602' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_cert_evaluar_criterios_nov_mock(CAST('DELTA1' AS VARCHAR(16)), 1356602);


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
--
-- Y ESA OMISION ES, AHORA, LO MAS VALIOSO DE ESTE PASO. El insumo de las
-- Reglas 1 y 2 unia el reporte con INNER JOIN, de modo que una direccion sin
-- entidad reportante quedaba fuera y no podia unificarse NUNCA. Por eso el
-- DELTA2 daba 0 filas en vez de 200 en los jobs #302 a #307: la persona si
-- entraba al driver -- que lee la vista sin ese join, y de ahi que
-- personas_distintas subiera 100 y relaciones_entrada 300 -- pero la direccion
-- nueva no llegaba a ningun escenario. SLCOPRBA-1355 lo paso a LEFT JOIN.
-- Dejar estas 200 direcciones sin reporte es lo que convierte a CA-U08/U09/U10
-- en la prueba de regresion de ese defecto: si alguien vuelve a poner INNER,
-- los tres criterios caen.
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
-- (3b) MUTACION DE LA FASE 3. Al ARQ 97 le cambia el TEXTO de su direccion;
-- al ARQ 98 no le cambia nada. El hash del 97 tiene que moverse y dejar una
-- SEGUNDA fila en ubicacion_atributo_hash_mock; el del 98, quedarse en una.
-- Sin estas dos lineas, F3-06 no tendria con que distinguir "registro el
-- cambio" de "reinserta en cada corrida".
--
-- SE CAMBIA EL TEXTO Y NO LA FECHA a proposito: la fecha decide si la persona
-- entra a la ventana, que es lo que mide F1-04; aqui lo que se mide es que el
-- hash reaccione a un ATRIBUTO. Los dos arquetipos estan sembrados en el
-- Watermark, de modo que entran en todas las corridas pase lo que pase.
--
-- WHERE explicito y acotado a la banda [REDSHIFT:232].
-- ------------------------------------------------------------
UPDATE bdm_stage.ubicacion_estandarizada
   SET texto_ubicacion = REPLACE(texto_ubicacion, 'TEXTO ORIGINAL', 'TEXTO MUTADO')
 WHERE cod_dw_ubic BETWEEN 99700000 AND 99709999;

-- ------------------------------------------------------------
-- (3c) MUTACION DE LA FASE 2. Al tramo 600..799 del ARQ 99 le cambia el
-- SALDO de su cuenta. El hash tiene que moverse y dejar una SEGUNDA fila en
-- cuenta_atributo_hash_mock; el resto de la banda, quedarse en una.
--
-- Se cambia el saldo y no el portafolio a proposito: mover una de las nueve
-- columnas del clasificador cambiaria TAMBIEN el portafolio, y entonces el
-- criterio no sabria si el hash se movio por el atributo o por la
-- clasificacion. El saldo entra en el concatena y no en el CASE.
--
-- WHERE explicito y acotado al tramo [REDSHIFT:232].
-- ------------------------------------------------------------
UPDATE bdm_stage.mock_cuenta
   SET valor_saldo = valor_saldo + 777777.00
 WHERE id_buro_persona BETWEEN 9990600 AND 9990799;

-- ------------------------------------------------------------
-- (4) DELTA sobre datos MUTADOS. Debe producir exactamente 200 filas nuevas,
-- 100 del ARQ 21 y 100 del ARQ 22, sin re-escribir ninguna del FULL.
-- ------------------------------------------------------------
CALL bdm_datos.sp_unificacion_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356604' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_unificacion_mock_gate_arq(CAST('DELTA2' AS VARCHAR(16)), 1356604);
-- Tablero de certificacion: los 51 criterios de los documentos, con el ID del
-- documento como clave. Corre despues del gate por arquetipo porque consolida
-- su veredicto y el del gate de convergencia.
CALL bdm_datos.sp_cert_evaluar_criterios_mock(CAST('DELTA2' AS VARCHAR(16)), 1356604);

-- Ordenamiento DELTA de la misma corrida, ahora con ventana real: debe
-- re-puntuar y re-ordenar las 200 personas que mutaron, y solo esas.
CALL bdm_datos.sp_ordenamiento_ejecucion_mock(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356604' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- Tablero de certificacion del ORDENAMIENTO. Corre JUSTO DESPUES del
-- Ordenamiento de esta fase y no al final, porque varios criterios miran
-- tablas de staging y de control que son de la corrida: CA-T03 comprueba que
-- las intermedias ya no existen y CA-T05 compara las personas de entrada de
-- este lote. Evaluado mas tarde mediria otra corrida.
CALL bdm_datos.sp_cert_evaluar_criterios_ord_mock(CAST('DELTA2' AS VARCHAR(16)), 1356604);

-- NOVEDADES de la MISMA corrida. Corre DESPUES del Ordenamiento porque lee su
-- salida: la etapa 1 del dominio Ubicacion filtra por orden de prioridad no
-- nulo (Novedad.sql:7593) y ese orden lo escribe sp_ordenamiento_consolidacion
-- en bdm_datos.rpu_orden_prioridad. Invertido el orden, Novedades saldria
-- vacio por un efecto de secuencia y no por un defecto.
CALL bdm_datos.sp_novedades_mock_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('DELTA' AS VARCHAR(256)), CAST('1356604' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
CALL bdm_datos.sp_cert_evaluar_criterios_nov_mock(CAST('DELTA2' AS VARCHAR(16)), 1356604);


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
