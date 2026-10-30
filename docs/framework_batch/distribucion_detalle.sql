-- =====================================================================
-- LA DISTRIBUCION POR DENTRO: cada regla, cada canal, cada tabla
--
-- Para las tres vertientes -- mock, real DEV y real QA -- y en el mismo
-- formato, que es lo que permite ponerlas una al lado de la otra.
--
-- DE DEV REAL YA ESTA TODO MEDIDO (job #491) y esta en
-- REPORTE_DRILLDOWN_VIA_REAL.md. Lo que falta es el MOCK (se corre en DEV)
-- y QA REAL (se corre en QA).
--
-- Base dba_rncr_batch, no dba. Cursor DENTRO de la consulta + Ctrl+Enter.
--
-- UNA TRAMPA QUE VALE PARA TODO EL ARCHIVO: de las cuatro familias, TRES
-- tienen gemelo _mock y se consultan por separado -- unificacion_direccion,
-- unif_escenario_censo y las siete mat_* --. LA CUARTA NO:
-- score_ordenamiento es UNA SOLA TABLA donde conviven los scores reales y
-- los del mock, porque el mock reutiliza los SP reales de scoring. En DEV
-- hay que separarlos por la banda de id del mock
-- (9000000..9999999) en los DOS sentidos, y por eso los bloques C1 y C2
-- llevan el filtro invertido. Sin el, el conteo "real" de DEV sale inflado
-- con el mock encima.
-- =====================================================================


-- =====================================================================
-- A. UNIFICACION: cuantas resolvio CADA REGLA
--
-- unifica_atributos sella la regla en el INSERT de cada _persist:
-- 1 = Regla 1, 2 = Regla 2, 3 = Regla 3.
-- =====================================================================

-- A1 - REAL (correr en DEV y en QA)
SELECT CASE unifica_atributos WHEN 1 THEN '1 - Regla 1'
                              WHEN 2 THEN '2 - Regla 2'
                              WHEN 3 THEN '3 - Regla 3'
                              ELSE '? - ' || COALESCE(CAST(unifica_atributos AS VARCHAR), 'NULL')
       END                                   AS regla,
       COUNT(*)                              AS direcciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS padres,
       MIN(lote) AS lote_min, MAX(lote) AS lote_max
FROM   bdm_datos.unificacion_direccion
GROUP  BY 1
ORDER  BY 1;

-- A2 - MOCK (correr en DEV)
SELECT CASE unifica_atributos WHEN 1 THEN '1 - Regla 1'
                              WHEN 2 THEN '2 - Regla 2'
                              WHEN 3 THEN '3 - Regla 3'
                              ELSE '? - ' || COALESCE(CAST(unifica_atributos AS VARCHAR), 'NULL')
       END                                   AS regla,
       COUNT(*)                              AS direcciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS padres,
       MIN(lote) AS lote_min, MAX(lote) AS lote_max
FROM   bdm_datos.unificacion_direccion_mock
GROUP  BY 1
ORDER  BY 1;


-- =====================================================================
-- B. LA CASCADA DE LA REGLA 2, ESCENARIO POR ESCENARIO
--
-- ACOTADO A UNA CORRIDA, Y NO ES OPCIONAL: en la via real el censo NO se
-- trunca nunca, de modo que un GROUP BY sin filtro suma todas las corridas
-- que ha habido. Ya paso: en QA la fila BRECHA dio 175 y eran ~5 corridas
-- acumuladas; una sola traia 35.
-- =====================================================================

-- B1 - REAL (correr en DEV y en QA) -- ultimo FULL completado
SELECT c.n_id, c.escenario, c.ref_legado, c.direcciones, c.personas
FROM   bdm_datos.unif_escenario_censo c
WHERE  c.lote = (SELECT MAX(lote) FROM bdm_datos.unif_control
                 WHERE modo = 'FULL' AND estado = 'completado')
ORDER  BY c.direcciones DESC, c.escenario;

-- B2 - MOCK (correr en DEV) -- el ciclo FULL de la bateria
SELECT c.n_id, c.escenario, c.ref_legado, c.direcciones, c.personas
FROM   bdm_datos.unif_escenario_censo_mock c
WHERE  c.lote = (SELECT MAX(lote) FROM bdm_datos.unif_control_mock
                 WHERE modo = 'FULL' AND estado = 'completado')
ORDER  BY c.direcciones DESC, c.escenario;


-- =====================================================================
-- C. ORDENAMIENTO: el reparto por CANAL
--
-- lugar_max es la columna que dice si el canal RANKEA de verdad o solo
-- pone a todos en el lugar 1. En DEV real llega a 57 (EMA) y a 47 (DIR);
-- en mock se queda en 2 por construccion, y eso NO es un defecto: el mock
-- siembra dos filas por persona para medir el DELTA de score.
-- =====================================================================

-- C1 - REAL (correr en DEV y en QA)
--      El NOT BETWEEN saca los scores del mock, que viven en esta misma
--      tabla cuando la bateria ha corrido en el cluster.
SELECT canal,
       COUNT(*)                        AS filas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       ROUND(COUNT(*)::DECIMAL / NULLIF(COUNT(DISTINCT id_buro_persona),0), 2) AS items_persona,
       MAX(lugar)                      AS lugar_max
FROM   bdm_datos.score_ordenamiento
WHERE  id_buro_persona NOT BETWEEN 9000000 AND 9999999
GROUP  BY 1
ORDER  BY filas DESC;

-- C2 - MOCK (correr en DEV)
SELECT canal,
       COUNT(*)                        AS filas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       ROUND(COUNT(*)::DECIMAL / NULLIF(COUNT(DISTINCT id_buro_persona),0), 2) AS items_persona,
       MAX(lugar)                      AS lugar_max
FROM   bdm_datos.score_ordenamiento
WHERE  id_buro_persona BETWEEN 9000000 AND 9999999
GROUP  BY 1
ORDER  BY filas DESC;


-- =====================================================================
-- D. LAS SIETE TABLAS DE ENTREGA, UNA POR UNA
--
-- En DEV real dos salen en 0 y NO es codigo que falte:
--   punto_interes  -> arranca FROM geo_distancias, que solo escribe el
--                     COPY de la respuesta de ArcGIS.
--   movilidad      -> es un delta contra una foto anterior, y en la
--                     primera corrida no hay foto.
--
-- LA LLAVE DE PERSONA DE ESTAS SIETE NO ES id_buro_persona: es el PAR
-- (tipo_identificacion, numero_identificacion), que es el contrato del
-- legado. Y DOS DE LAS SIETE NO CUENTAN PERSONAS -- contactabilidad y punto
-- de interes van al grano de UBICACION (ubicacion_id) --, de modo que su
-- columna personas sale NULL a proposito: un 0 ahi diria "no hay personas"
-- cuando lo cierto es "esta tabla no cuenta personas".
--
-- Los NULL van CASTEADOS en la primera rama del UNION ALL: el CAST de esa
-- rama fija el tipo del nodo entero.
-- =====================================================================

-- D1 - REAL (correr en DEV y en QA)
SELECT 1 AS orden, 'actividad economica' AS tabla,
       CAST(COUNT(*) AS BIGINT)            AS filas,
       CAST(COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)) AS BIGINT) AS personas,
       CAST(NULL AS BIGINT)                AS ubicaciones
FROM   bdm_datos.mat_info_actividad_economica
UNION ALL
SELECT 2, 'ubicacion',          COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), COUNT(DISTINCT cod_dw_ubic)
FROM   bdm_datos.mat_info_ubicacion
UNION ALL
SELECT 3, 'contactabilidad',    COUNT(*), NULL, COUNT(DISTINCT ubicacion_id)
FROM   bdm_datos.mat_info_contactabilidad
UNION ALL
SELECT 4, 'ubicacion agregada', COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_ubicacion_agregada
UNION ALL
SELECT 5, 'info basica',        COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_info_basica
UNION ALL
SELECT 6, 'punto de interes',   COUNT(*), NULL, COUNT(DISTINCT ubicacion_id)
FROM   bdm_datos.mat_info_punto_interes
UNION ALL
SELECT 7, 'movilidad',          COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_info_movilidad
ORDER  BY 1;


-- D2 - MOCK (correr en DEV)
SELECT 1 AS orden, 'actividad economica' AS tabla,
       CAST(COUNT(*) AS BIGINT)            AS filas,
       CAST(COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)) AS BIGINT) AS personas,
       CAST(NULL AS BIGINT)                AS ubicaciones
FROM   bdm_datos.mat_info_actividad_economica_mock
UNION ALL
SELECT 2, 'ubicacion',          COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), COUNT(DISTINCT cod_dw_ubic)
FROM   bdm_datos.mat_info_ubicacion_mock
UNION ALL
SELECT 3, 'contactabilidad',    COUNT(*), NULL, COUNT(DISTINCT ubicacion_id)
FROM   bdm_datos.mat_info_contactabilidad_mock
UNION ALL
SELECT 4, 'ubicacion agregada', COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_ubicacion_agregada_mock
UNION ALL
SELECT 5, 'info basica',        COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_info_basica_mock
UNION ALL
SELECT 6, 'punto de interes',   COUNT(*), NULL, COUNT(DISTINCT ubicacion_id)
FROM   bdm_datos.mat_info_punto_interes_mock
UNION ALL
SELECT 7, 'movilidad',          COUNT(*), COUNT(DISTINCT CAST(tipo_identificacion AS VARCHAR) || '-' || CAST(numero_identificacion AS VARCHAR)), NULL
FROM   bdm_datos.mat_info_movilidad_mock
ORDER  BY 1;
