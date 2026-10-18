-- ============================================================
-- reset_mock.sql
-- SLCOPRBA-1356 (Fase 5): deja el mock en estado virgen para poder repetir la
-- bateria desde cero.
-- SLCOPRBA-1399: el bloque de Novedades del final, que falto hasta el #412.
--
-- Borra SALIDAS y CONTROL, no las tablas de insumo. Las de insumo las re-siembran
-- seed_mock_matriz.sql y seed_mock_matriz_r2.sql, que ya hacen su propio DELETE
-- idempotente por rango de ARQ -- y ese rango cubre tambien las direcciones que
-- agrega el paso de mutacion, asi que la mutacion se limpia sola al re-sembrar.
--
-- IMPORTANTE: se borran unif_control_mock Y nov_control_mock. Ahi vive el
-- Watermark, y los dos ciclos lo leen con MAX(watermark_nuevo) de las corridas
-- 'completado' (16_sp_unificacion_ciclo.sql:162, sp_novedades_ciclo_edf.sql:57).
-- Sin borrarlo, la primera corrida de la bateria heredaria el Watermark de la
-- anterior y un 'FULL' no partiria de cero. Con la tabla vacia el ciclo detecta
-- Bootstrap y fuerza FULL, que es lo que queremos.
--
-- ESO ES EXACTAMENTE LO QUE TUMBO EL JOB DEV/DATABASE #412, y conviene saberlo
-- antes de anadir aqui la siguiente tabla de control. El pipeline corre DPLY
-- DOS VECES; este archivo es el numero 1 de deploy.par, de modo que todo lo que
-- NO esta en esta lista sobrevive de una pasada a la otra. Novedades no estaba:
-- su FULL de la segunda pasada salio con bootstrap=f, los DELTA siguientes
-- leyeron el watermark 2026-06-15 que habia dejado la primera, la ventana por
-- fecha se quedo vacia y NOV-UB-12 lo cazo. La regla que queda: LO QUE UNA
-- CORRIDA ESCRIBE, EL RESET LO BORRA, y una tabla de control nueva entra aqui
-- en el mismo commit que su DDL.
--
-- NO toca bdm_stage.nomenclatura ni bdm_stage.tipo_ubicacion_dir: son catalogos,
-- los siembra el DDL y no son estado de corrida.
--
-- UTF-8 sin BOM.
-- ============================================================

-- Salidas de Unificacion
TRUNCATE TABLE bdm_datos.unificacion_direccion_mock;
TRUNCATE TABLE bdm_datos.rpu_generada_mock;
TRUNCATE TABLE bdm_datos.direccion_fisica_generada_mock;

-- El diccionario lo reconstruye el SP en cada corrida; se vacia para que un
-- fallo a mitad de camino no deje filas de una corrida anterior.
TRUNCATE TABLE bdm_stage.diccionario_complementos;
-- SLCOPRBA-1355: el Diccionario de Via, por la misma razon. Lo
-- reconstruye sp_unificacion_mock_r3_esc1 en cada Regla 3, de modo que
-- vaciarlo aqui solo evita que un residuo de otra bateria se cuele en el
-- desempate del subcaso de las dos coordenadas.
TRUNCATE TABLE bdm_stage.diccionario_via;

-- Control y traza de Unificacion (aqui vive el Watermark)
TRUNCATE TABLE bdm_datos.unif_control_etapa_mock;
TRUNCATE TABLE bdm_datos.unif_control_mock;
TRUNCATE TABLE bdm_datos.unif_escenario_censo_mock;

-- Ciclo GEO mock
TRUNCATE TABLE bdm_datos.geo_atributos_mock;
TRUNCATE TABLE bdm_datos.geo_lote_control_mock;

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
TRUNCATE TABLE bdm_stage.mock_ord_ca_result;


-- ------------------------------------------------------------
-- Novedades (P0035). Ver la nota del encabezado: esta seccion falto hasta el
-- job #412 y es la unica causa de que la segunda pasada del pipeline no
-- reprodujera a la primera.
-- ------------------------------------------------------------

-- Control y traza de Novedades (aqui vive el Watermark del P0035)
TRUNCATE TABLE bdm_datos.nov_control_etapa_mock;
TRUNCATE TABLE bdm_datos.nov_control_mock;

-- Tablas finales de los dominios portados.
--   mat_info_ubicacion_mock: el cargador solo retira las llaves que VUELVEN a
--     entrar (sp_novedades_cargar_mat_ubicacion_edf.sql:29-39); lo que deja de
--     entrar se queda, y el ciclo lo cuenta en v_escritas.
--   mat_info_actividad_economica_mock: es INSERT-ONLY por diseno del legado
--     (sp_novedades_cargar_mat_acteco_edf.sql:40-46). Sin truncar, la segunda
--     pasada la duplicaria y la Severidad daria -1 en toda la etapa.
--   mat_ubicacion_agregada_mock: el cargador borra por las SIETE columnas de
--     la llave y vuelve a insertar (130.TPT:1060-1066); lo que deja de entrar
--     se queda, igual que en mat_info_ubicacion_mock.
TRUNCATE TABLE bdm_datos.mat_info_ubicacion_mock;
TRUNCATE TABLE bdm_datos.mat_info_actividad_economica_mock;
TRUNCATE TABLE bdm_datos.mat_ubicacion_agregada_mock;

-- Contratos de etapa. Los SP los truncan al empezar, igual que el diccionario
-- de complementos; se vacian aqui por el mismo motivo que aquel: un fallo a
-- mitad de camino no debe dejar filas de otra corrida a la vista.
TRUNCATE TABLE bdm_tempo.stg_nov_ubica_etapa_9_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_ubica_etapa_2_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_acteco_etapa_1_mock;
TRUNCATE TABLE bdm_tempo.stg_nov_ubiagr_etapa_final_mock;

-- ------------------------------------------------------------
-- Tableros de certificacion. Los dos evaluadores ya son idempotentes por
-- (lote, modo) -- el de Novedades en
-- sp_cert_evaluar_criterios_nov_mock.sql:64 --, pero la bateria debe arrancar
-- sin veredictos de corridas anteriores: un PASSED viejo junto a un lote nuevo
-- se lee mal.
-- ------------------------------------------------------------
TRUNCATE TABLE bdm_datos.cert_resultado;
TRUNCATE TABLE bdm_datos.cert_resultado_nov;
