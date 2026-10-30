-- =====================================================================
-- LAS CELDAS QUE SIGUEN EN "POR MEDIR", Y LA CONSULTA DE CADA UNA
--
-- Una seccion por celda de la pagina. Dos de las cinco NO son consultas
-- y conviene saberlo antes de buscarlas aqui.
--
-- Base dba_rncr_batch, no dba (DBeaver abre en dba).
-- =====================================================================


-- ---------------------------------------------------------------------
-- (1) y (2)  PERSONAS DISTINTAS -- columnas DEV y QA
--
-- Es la MISMA consulta en los dos ambientes: el bloque 1 de
-- captura_qa_real.sql, ya corregido. Se repite aqui para no tener que
-- abrir el otro archivo.
--
-- Mock ya esta: 92.800, del bloque 1 de captura_mock.sql.
--
-- OJO A ubicaciones_fisicas, que es la correccion que lleva dentro:
-- antes contaba cod_dw_persona_ubic -- la llave del CONTACTO
-- (02_vistas_insumo_edf_views.sql:77) -- y por eso en QA daba 302.112,
-- identico al total de filas. La ubicacion fisica es cod_dw_ubic (:76).
-- Si vuelve a salir igual al total, ESO es un hallazgo.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                   AS relaciones_total,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 1 THEN 1 ELSE 0 END) AS caen_por_bloqueada,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 0 THEN 1 ELSE 0 END) AS entran,
       COUNT(DISTINCT id_buro_persona)                            AS personas,
       COUNT(DISTINCT cod_dw_ubic)                                AS ubicaciones_fisicas
FROM   bdm_tempo.v_xpm_relacion_persona_ubicacion;


-- ---------------------------------------------------------------------
-- (3)  LA CADENA COMPLETA -- columna MOCK
--
-- Contra DEV, que es donde corre la bateria mock (en QA solo han corrido
-- las vias reales). Son los bloques 5 y 6 de captura_mock.sql.
--
-- DOS COSAS QUE YA COSTARON UNA VUELTA:
--   - se une por LOTE y no por corrida_id: cada proceso lleva su propia
--     secuencia -- en la corrida medida Unificacion iba por la 22 y
--     Novedades por la 10 --, de modo que unir por el par no casa nunca.
--   - el tiempo del Ordenamiento del mock NO esta en una tabla _mock: no
--     existe ord_control_mock. Esta en ord_control, la real, acotada a la
--     banda de lote del mock.
-- ---------------------------------------------------------------------
SELECT corrida_id, lote, modo, bootstrap, estado,
       personas_entrada, contactos_entrada, scores_generados,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
FROM   bdm_datos.ord_control
WHERE  lote BETWEEN 1356500 AND 1356699
ORDER  BY corrida_id;

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


-- ---------------------------------------------------------------------
-- (4)  INCREMENTAL CONTRA CARGA COMPLETA -- FUERA DE ALCANCE POR DECISION
--
-- DECISION DEL USUARIO (2026-10-30): "para datos reales solo tenemos datos de
-- FULL y eso esta bien". Deja de ser un pendiente: con dato real el alcance es
-- la carga completa, y el modo incremental queda certificado con el mock, que
-- es donde se pueden provocar los cambios que lo prueban.
--
-- LO QUE SIGUE AQUI NO ES TRABAJO ABIERTO: es lo que ahorra la vuelta entera
-- el dia que se retome. Seria una corrida, no una consulta -- disparar el .val
-- de DELTA detras del de FULL:
--   reconocerdeltaval1-20261028-2610.val
--
-- Los tiempos salen solos del bloque 7 de captura_qa_real.sql, que ya
-- trae una fila por corrida con su modo y sus segundos. Esta aqui para
-- no tener que abrirlo.
--
-- Y LA ADVERTENCIA, que es lo que evita presentar la cifra al reves: un
-- DELTA lanzado detras del FULL sobre dato que no se movio mide EL SUELO
-- -- lo que cuesta confirmar que no hay cambios --, no la eficiencia de
-- una incremental real. Son DOS cifras con etiqueta distinta, nunca una.
-- ---------------------------------------------------------------------
SELECT 'unificacion' AS proceso, corrida_id, lote, modo,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.unif_control
UNION ALL
SELECT 'ordenamiento', corrida_id, lote, modo,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.ord_control
UNION ALL
SELECT 'novedades',    corrida_id, lote, modo,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.nov_control
ORDER  BY lote, proceso;


-- =====================================================================
-- (5)  TIEMPO DE LA MALLA EN TERADATA -- NO SALE DE AQUI
--
-- No hay consulta que lo de: es el AS-IS, en el otro motor. Lo consigue
-- el presentador. Mientras no llegue, la pagina lo deja marcado como
-- pendiente en vez de poner una estimacion, que es lo unico que no se
-- puede hacer con una cifra que va a Negocio.
--
--
-- UNA QUE YA NO ESTA PENDIENTE, por si alguien la busca: el "Veredicto"
-- de la columna QA. Sale de nov_control_etapa y ya se midio -- las siete
-- etapas de la corrida 5 (lote 20261029) en 'completado' --, de modo que
-- la celda ya esta puesta. Es el bloque 8 de captura_qa_real.sql.
-- =====================================================================
