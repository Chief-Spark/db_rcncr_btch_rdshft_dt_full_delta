-- =====================================================================
-- LA COLUMNA MOCK DE LA TABLA DE LAS TRES VERTIENTES
--
-- Mismas etapas que captura_qa_real.sql, contra las tablas del mock. El
-- destino es la tabla "Entrada, proceso y entrega" de la pagina del
-- artefacto y la del guion.
--
-- OJO AL AMBIENTE, QUE ES LO QUE MAS CUESTA: la bateria mock la corre el
-- DPLY de Jenkins, NO el Framework Batch. En QA solo han corrido las vias
-- reales (lotes 1356301 y 20261029), asi que estas tablas ahi pueden
-- estar vacias. Hay que lanzarlo contra el ambiente donde corrio la
-- bateria -- hoy DEV --, y decir en la presentacion de donde sale.
--
-- Y OJO A LA CORRIDA: el mock corre CUATRO ciclos seguidos
-- (FULL / DELTA1 / mutacion / DELTA2). Para la tabla se usa la del
-- FULL -- bootstrap = true, o el corrida_id mas bajo del lote --, que es
-- la comparable con el FULL de las dos columnas reales. Los otros tres
-- ciclos son el material de la fila "4 ciclos".
--
-- Base dba_rncr_batch, no dba.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. EL EMBUDO DE ENTRADA DEL MOCK
--    Da las filas "Relaciones de entrada", "No entran" y "Entran".
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                   AS relaciones_total,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 1 THEN 1 ELSE 0 END) AS caen_por_bloqueada,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 0 THEN 1 ELSE 0 END) AS entran,
       COUNT(DISTINCT id_buro_persona)                            AS personas
FROM   bdm_tempo.v_mock_relacion_persona_ubicacion;


-- ---------------------------------------------------------------------
-- 2. UNIFICACION: una fila por ciclo, con sus tiempos
--    La del FULL (bootstrap = true) es la que va a la tabla.
--    total_unificaciones da la fila "Direcciones unificadas".
-- ---------------------------------------------------------------------
SELECT corrida_id, lote, modo, bootstrap, estado,
       relaciones_entrada, personas_distintas, total_unificaciones,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
FROM   bdm_datos.unif_control_mock
ORDER  BY corrida_id;

-- Desglose por regla, para cuadrar con total_unificaciones.
SELECT unifica_atributos AS regla, COUNT(*) AS filas
FROM   bdm_datos.unificacion_direccion_mock
GROUP  BY 1
ORDER  BY 1;


-- ---------------------------------------------------------------------
-- 3. ORDENAMIENTO: da la fila "Datos puntuados"
--
--    NO HAY ord_control_mock NI score_ordenamiento_mock, y conviene
--    saberlo antes de buscarlos: el mock REUTILIZA los SP reales de
--    scoring y consolidacion, de modo que sus scores caen en la tabla
--    REAL bdm_datos.score_ordenamiento. Lo que los separa es la banda de
--    id del mock: id_buro_persona = 9000000 + ARQ * 10000 + i.
-- ---------------------------------------------------------------------
SELECT canal,
       COUNT(*)                        AS filas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       MAX(lugar)                      AS lugar_max
FROM   bdm_datos.score_ordenamiento
WHERE  id_buro_persona BETWEEN 9000000 AND 9999999
GROUP  BY 1
ORDER  BY filas DESC;

SELECT COUNT(*)                        AS scores_total,
       COUNT(DISTINCT id_buro_persona) AS personas_total
FROM   bdm_datos.score_ordenamiento
WHERE  id_buro_persona BETWEEN 9000000 AND 9999999;


-- ---------------------------------------------------------------------
-- 4. NOVEDADES: da la fila "Filas entregadas"
-- ---------------------------------------------------------------------
SELECT corrida_id, lote, modo, bootstrap, estado,
       relaciones_entrada, personas_distintas, filas_mat_escritas,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
FROM   bdm_datos.nov_control_mock
ORDER  BY corrida_id;


-- ---------------------------------------------------------------------
-- 5. ORDENAMIENTO DEL MOCK: sus TIEMPOS
--    Los scores salen del bloque 3, pero el tiempo no: hay que ir a
--    ord_control, la tabla REAL, acotada a la banda de lote del mock.
--    (Si sale vacia, el ciclo mock no escribe traza de ordenamiento y la
--    cadena del bloque 6 se queda sin ese sumando: hay que decirlo en vez
--    de estimarlo.)
-- ---------------------------------------------------------------------
SELECT corrida_id, lote, modo, bootstrap, estado,
       personas_entrada, contactos_entrada, scores_generados,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
FROM   bdm_datos.ord_control
WHERE  lote BETWEEN 1356500 AND 1356699
ORDER  BY corrida_id;


-- ---------------------------------------------------------------------
-- 6. LA CADENA DEL CICLO FULL, que es la fila de tiempo
--
--    SE UNE POR LOTE Y NO POR corrida_id: cada proceso lleva su PROPIA
--    secuencia de corrida_id -- en la corrida medida, Unificacion iba por
--    la 22 y Novedades por la 10 --, de modo que unir por el par
--    (lote, corrida_id) no casa NUNCA y la consulta sale vacia. Ya se
--    pago una vez.
--
--    Acotada a UNA corrida: sumar los cuatro ciclos daria un numero que
--    no compara con nada. (Es el error del bloque 7 de
--    captura_qa_real.sql, donde MIN..MAX sobre todas las corridas dio
--    tres dias.)
-- ---------------------------------------------------------------------
SELECT u.lote,
       DATEDIFF(second, u.fecha_hora_inicio, u.fecha_hora_fin) AS unificacion_s,
       DATEDIFF(second, o.fecha_hora_inicio, o.fecha_hora_fin) AS ordenamiento_s,
       DATEDIFF(second, n.fecha_hora_inicio, n.fecha_hora_fin) AS novedades_s,
       DATEDIFF(second, u.fecha_hora_inicio, n.fecha_hora_fin) AS cadena_s
FROM       bdm_datos.unif_control_mock u
LEFT JOIN  bdm_datos.ord_control       o ON o.lote = u.lote
JOIN       bdm_datos.nov_control_mock  n ON n.lote = u.lote
WHERE  u.bootstrap = TRUE
ORDER  BY u.lote;
