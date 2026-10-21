-- ============================================================
-- E2E Reconocer VIA REAL COMPLETA: Unificacion + GEO + Ordenamiento + NOVEDADES
--
-- POR QUE EXISTE ESTE ARCHIVO, Y ES EL PUNTO: hasta el 2026-10-21 NADIE HABIA
-- CORRIDO NUNCA LA VIA REAL DE NOVEDADES. El runner que habia,
-- run_reconocer_e2e_unificacion_ordenamiento.sql:17-20, llama a Unificacion y
-- Ordenamiento y para ahi; no habia un solo run_* que invocara
-- sp_novedades_ciclo_edf. De modo que las tres tablas dominio que damos por
-- portadas solo se habian visto en MOCK, y no sabiamos si contra el datashare
-- producen una sola fila.
--
-- LA META DEL PROYECTO SON LAS 7 TABLAS DOMINIO POBLADAS CON DATOS REALES
-- (usuario, 2026-10-21), que es lo que explota el Batch. Este archivo es el
-- que convierte "portado" en "entrega filas", y por eso termina midiendo.
--
-- Ambiente: consumidor dba_rncr_batch, esquemas bdm_datos / bdm_tempo.
-- Precondicion: STRCT y PGM desplegados, Data Sharing OK.
-- NO mezclar la via mock (bdm_stage) en esta corrida.
--
-- EL ORDEN NO ES NEGOCIABLE: Novedades va DESPUES del Ordenamiento porque su
-- etapa 1 filtra por orden de prioridad no nulo (Novedad.sql:7593), que es lo
-- que escribe sp_ordenamiento_consolidacion_edf. Al reves saldria vacio por un
-- efecto de secuencia y no por un defecto -- la misma leccion que el ciclo GEO.
--
-- Lote dedicado 1356301. UTF-8 sin BOM. CALL de 6 VARCHAR del Framework Batch.
-- ============================================================

-- 1) Unificacion FULL. GEO va dentro del ciclo y no es bloqueante (D-GEO-07).
CALL bdm_datos.sp_unificacion_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356301' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- 2) Ordenamiento FULL sobre la salida de Unificacion.
CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356301' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- 3) Novedades FULL. Corre los tres dominios portados -- ubicacion,
--    actividad economica y ubicacion agregada --, cada uno con su calcular y
--    su cargar.
CALL bdm_datos.sp_novedades_ciclo_edf(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356301' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));

-- ============================================================
-- LA MEDIDA. Es el numero que dice si avanzamos contra la meta: cuantas filas
-- tiene cada tabla dominio despues de una corrida real.
--
-- Las SIETE del legado salen del DELETE ... ALL de
-- P0035_Extractor_Novedades_111.BTQ:817-836. Hoy tenemos TRES; las otras
-- cuatro no estan portadas y se listan en cero a proposito, para que el
-- informe no deje duda de en que punto estamos.
-- ============================================================
SELECT 'mat_info_ubicacion'            AS tabla_dominio, 1 AS n, COUNT(*) AS filas FROM bdm_datos.mat_info_ubicacion
UNION ALL
SELECT 'mat_info_actividad_economica',       2, COUNT(*) FROM bdm_datos.mat_info_actividad_economica
UNION ALL
SELECT 'mat_ubicacion_agregada',             3, COUNT(*) FROM bdm_datos.mat_ubicacion_agregada
UNION ALL
SELECT 'mat_info_basica (SIN PORTAR)',       4, 0
UNION ALL
SELECT 'mat_info_contactabilidad (SIN PORTAR)', 5, 0
UNION ALL
SELECT 'mat_info_movilidad (SIN PORTAR)',    6, 0
UNION ALL
SELECT 'mat_info_punto_interes (SIN PORTAR)', 7, 0
ORDER BY 2;

-- La traza de la corrida: en que estado quedo cada etapa y con cuantas filas.
-- Si una etapa sale en cero, aqui se ve CUAL y no hay que deducirlo.
SELECT c.corrida_id, c.lote, c.modo, c.estado,
       c.relaciones_entrada, c.personas_distintas, c.filas_mat_escritas,
       c.watermark_anterior, c.watermark_nuevo,
       c.fecha_hora_inicio, c.fecha_hora_fin
FROM   bdm_datos.nov_control c
WHERE  c.lote = 1356301
ORDER BY c.corrida_id;

-- Por dominio. Si uno sale en cero, aqui se ve CUAL y por que rama: el
-- desglose de altas, cambios y bajas distingue "no habia nada que recoger"
-- de "no miro". Es la leccion de NOV-UB-12: un DELTA en cero no prueba que no
-- haya cambios.
SELECT e.corrida_id, e.etapa, e.estado,
       e.relaciones_entrada, e.personas_distintas,
       e.filas_altas, e.filas_cambios, e.filas_bajas,
       e.fecha_hora_inicio, e.fecha_hora_fin
FROM   bdm_datos.nov_control_etapa e
WHERE  e.lote = 1356301
ORDER BY e.corrida_id, e.etapa;
