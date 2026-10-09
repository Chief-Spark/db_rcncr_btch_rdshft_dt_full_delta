-- ============================================================
-- reset_mock.sql
-- SLCOPRBA-1356 (Fase 5): deja el mock en estado virgen para poder repetir la
-- bateria desde cero.
--
-- Borra SALIDAS y CONTROL, no las tablas de insumo. Las de insumo las re-siembran
-- seed_mock_matriz.sql y seed_mock_matriz_r2.sql, que ya hacen su propio DELETE
-- idempotente por rango de ARQ -- y ese rango cubre tambien las direcciones que
-- agrega el paso de mutacion, asi que la mutacion se limpia sola al re-sembrar.
--
-- IMPORTANTE: se borra unif_control_mock. Ahi vive el Watermark, y el ciclo lo
-- lee con MAX(watermark_nuevo) de las corridas 'completado'. Sin borrarlo, la
-- primera corrida de la bateria heredaria el Watermark de la anterior y un
-- 'FULL' no partiria de cero. Con la tabla vacia el ciclo detecta Bootstrap y
-- fuerza FULL, que es lo que queremos.
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

-- Control y traza de Unificacion (aqui vive el Watermark)
TRUNCATE TABLE bdm_datos.unif_control_etapa_mock;
TRUNCATE TABLE bdm_datos.unif_control_mock;

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
