-- =====================================================================
-- EL ESTADO DE LOS 189 CRITERIOS DE ACEPTACION
--
-- Para la seccion "Criterios de aceptacion" de la pagina de Negocio, y
-- para responder en la sesion si alguien pregunta cuales no cumplen.
--
-- Base dba_rncr_batch, no dba. Cursor DENTRO de la consulta + Ctrl+Enter.
-- Se corre en DEV, que es donde corre la bateria mock. En QA solo han
-- corrido las vias reales, y la certificacion es SOLO con mock (regla 5).
--
-- EL CATALOGO SON 189 Y ESTO NO ES UNA ESTIMACION: 51 en cert_criterio
-- (13_ddl_cert_criterios.sql:101), 90 en cert_criterio_ord
-- (20_ddl_cert_criterios_ord.sql:120) y 48 en cert_criterio_nov
-- (33_ddl_cert_criterios_nov.sql:91).
--
-- LO QUE TUMBA EL BUILD ES **SOLO** FAILED (sp_cert_asercion_final.sql:92-133).
-- No tumban BLOQUEADO, SIN_DATO, NO_IMPLEMENTADO, REVISION_MANUAL,
-- FUERA_DE_ALCANCE ni NO_APLICA, y eso esta enumerado en :20-29 de ese SP.
-- De modo que **un build verde ya es la prueba de que no falla ninguno**;
-- estas consultas sirven para PONERLE NUMERO, no para descubrirlo.
--
-- =====================================================================
-- DOS LECTURAS, Y NO DAN LO MISMO. CONVIENE SABER CUAL SE ESTA MIRANDO.
--
--   (A) LA DEL GATE: las vistas v_cert_ultimo / v_cert_ord_ultimo /
--       v_cert_nov_ultimo se quedan con la ULTIMA fila de cada criterio
--       por fecha_hora (13_ddl_cert_criterios.sql:90-96 y sus gemelas).
--       Es una fila por criterio, y es exactamente lo que lee el gate.
--       PERO un criterio que salio PASSED en el FULL y NO_APLICA en el
--       DELTA2 se lee aqui como NO_APLICA, que no es lo que uno quiere
--       contar en una sesion.
--
--   (B) LA DE LA SESION: agregar TODAS las fases con precedencia --
--       FAILED manda sobre todo, luego PASSED, luego el resto --. Un
--       criterio que paso en alguna fase cuenta como cumplido.
--
-- La consulta 1 da la (B), que es la que va a la pagina. La 1b da la (A)
-- al lado, para que se vea que ninguna de las dos trae FAILED.
-- =====================================================================


-- ---------------------------------------------------------------------
-- (1) RESUMEN POR PROCESO -- la tabla de la pagina
--
-- La columna que importa es `fallan`: tiene que salir 0 en los tres. Si
-- no sale 0, el problema NO es de la pagina -- el gate estaria rojo y el
-- build no habria pasado.
-- ---------------------------------------------------------------------
WITH cat AS (
  SELECT 'Unificacion'  AS proceso, criterio, bloque FROM bdm_datos.cert_criterio
  UNION ALL
  SELECT 'Ordenamiento',          criterio, bloque FROM bdm_datos.cert_criterio_ord
  UNION ALL
  SELECT 'Novedades',             criterio, bloque FROM bdm_datos.cert_criterio_nov
),
res AS (
  SELECT 'Unificacion'  AS proceso, criterio, estado FROM bdm_datos.cert_resultado
  UNION ALL
  SELECT 'Ordenamiento',          criterio, estado FROM bdm_datos.cert_resultado_ord
  UNION ALL
  SELECT 'Novedades',             criterio, estado FROM bdm_datos.cert_resultado_nov
),
agg AS (
  SELECT c.proceso,
         c.criterio,
         MAX(CASE WHEN r.estado = 'FAILED'           THEN 1 ELSE 0 END) AS f,
         MAX(CASE WHEN r.estado = 'PASSED'           THEN 1 ELSE 0 END) AS p,
         MAX(CASE WHEN r.estado = 'BLOQUEADO'        THEN 1 ELSE 0 END) AS b,
         MAX(CASE WHEN r.estado = 'SIN_DATO'         THEN 1 ELSE 0 END) AS s,
         MAX(CASE WHEN r.estado = 'REVISION_MANUAL'  THEN 1 ELSE 0 END) AS m,
         MAX(CASE WHEN r.estado = 'NO_IMPLEMENTADO'  THEN 1 ELSE 0 END) AS n,
         MAX(CASE WHEN r.estado = 'FUERA_DE_ALCANCE' THEN 1 ELSE 0 END) AS x,
         COUNT(r.estado)                                                AS filas
  FROM       cat c
  LEFT  JOIN res r ON r.proceso = c.proceso AND r.criterio = c.criterio
  GROUP BY 1, 2
),
est AS (
  SELECT proceso, criterio,
         CASE WHEN f = 1     THEN 'FALLA'
              WHEN p = 1     THEN 'CUMPLE'
              WHEN b = 1     THEN 'ESPERA UN CATALOGO EXTERNO'
              WHEN s = 1     THEN 'EL MOCK NO SIEMBRA EL CASO'
              WHEN m = 1     THEN 'DECISION FUNCIONAL ABIERTA'
              WHEN n = 1     THEN 'DOMINIO O FASE NO PORTADA'
              WHEN x = 1     THEN 'FUERA DE ALCANCE POR ACTA'
              WHEN filas = 0 THEN 'SIN EVALUAR'
              ELSE                'NO APLICA EN NINGUNA FASE'
         END AS situacion
  FROM agg
)
SELECT proceso,
       COUNT(*)                                                      AS criterios,
       SUM(CASE WHEN situacion = 'CUMPLE' THEN 1 ELSE 0 END)         AS cumplen,
       SUM(CASE WHEN situacion = 'FALLA'  THEN 1 ELSE 0 END)         AS fallan,
       SUM(CASE WHEN situacion NOT IN ('CUMPLE','FALLA') THEN 1 ELSE 0 END) AS ni_una_cosa_ni_otra
FROM   est
GROUP  BY 1
ORDER  BY 1;


-- ---------------------------------------------------------------------
-- (1b) EL MISMO CONTEO, PERO POR SITUACION
--      Es el desglose de la columna `ni_una_cosa_ni_otra` de arriba, y
--      es lo que hay que tener a mano si en la sesion preguntan "y los
--      que no cumplen?". Ninguna fila deberia decir FALLA.
-- ---------------------------------------------------------------------
WITH cat AS (
  SELECT 'Unificacion'  AS proceso, criterio FROM bdm_datos.cert_criterio
  UNION ALL SELECT 'Ordenamiento', criterio FROM bdm_datos.cert_criterio_ord
  UNION ALL SELECT 'Novedades',    criterio FROM bdm_datos.cert_criterio_nov
),
res AS (
  SELECT 'Unificacion'  AS proceso, criterio, estado FROM bdm_datos.cert_resultado
  UNION ALL SELECT 'Ordenamiento', criterio, estado FROM bdm_datos.cert_resultado_ord
  UNION ALL SELECT 'Novedades',    criterio, estado FROM bdm_datos.cert_resultado_nov
),
agg AS (
  SELECT c.proceso, c.criterio,
         MAX(CASE WHEN r.estado = 'FAILED'           THEN 1 ELSE 0 END) AS f,
         MAX(CASE WHEN r.estado = 'PASSED'           THEN 1 ELSE 0 END) AS p,
         MAX(CASE WHEN r.estado = 'BLOQUEADO'        THEN 1 ELSE 0 END) AS b,
         MAX(CASE WHEN r.estado = 'SIN_DATO'         THEN 1 ELSE 0 END) AS s,
         MAX(CASE WHEN r.estado = 'REVISION_MANUAL'  THEN 1 ELSE 0 END) AS m,
         MAX(CASE WHEN r.estado = 'NO_IMPLEMENTADO'  THEN 1 ELSE 0 END) AS n,
         MAX(CASE WHEN r.estado = 'FUERA_DE_ALCANCE' THEN 1 ELSE 0 END) AS x,
         COUNT(r.estado)                                                AS filas
  FROM cat c LEFT JOIN res r ON r.proceso = c.proceso AND r.criterio = c.criterio
  GROUP BY 1, 2
)
SELECT proceso,
       CASE WHEN f = 1     THEN 'FALLA'
            WHEN p = 1     THEN 'CUMPLE'
            WHEN b = 1     THEN 'ESPERA UN CATALOGO EXTERNO'
            WHEN s = 1     THEN 'EL MOCK NO SIEMBRA EL CASO'
            WHEN m = 1     THEN 'DECISION FUNCIONAL ABIERTA'
            WHEN n = 1     THEN 'DOMINIO O FASE NO PORTADA'
            WHEN x = 1     THEN 'FUERA DE ALCANCE POR ACTA'
            WHEN filas = 0 THEN 'SIN EVALUAR'
            ELSE                'NO APLICA EN NINGUNA FASE'
       END  AS situacion,
       COUNT(*) AS criterios
FROM   agg
GROUP  BY 1, 2
ORDER  BY 1, 3 DESC;


-- ---------------------------------------------------------------------
-- (2) EL DETALLE DE LOS QUE NO CUMPLEN, CON SU ENUNCIADO
--
-- Es la chuleta de la sesion: si preguntan "cuales no cumplen", esto
-- los nombra uno por uno y dice por que. El `detalle` lo escribe el
-- propio evaluador y suele traer la cita del legado.
-- ---------------------------------------------------------------------
WITH cat AS (
  SELECT 'Unificacion'  AS proceso, criterio, bloque, enunciado FROM bdm_datos.cert_criterio
  UNION ALL SELECT 'Ordenamiento', criterio, bloque, enunciado FROM bdm_datos.cert_criterio_ord
  UNION ALL SELECT 'Novedades',    criterio, bloque, enunciado FROM bdm_datos.cert_criterio_nov
),
ult AS (
  SELECT 'Unificacion'  AS proceso, criterio, estado, detalle FROM bdm_datos.v_cert_ultimo
  UNION ALL SELECT 'Ordenamiento', criterio, estado, detalle FROM bdm_datos.v_cert_ord_ultimo
  UNION ALL SELECT 'Novedades',    criterio, estado, detalle FROM bdm_datos.v_cert_nov_ultimo
),
paso AS (
  SELECT 'Unificacion'  AS proceso, criterio FROM bdm_datos.cert_resultado     WHERE estado = 'PASSED'
  UNION     SELECT 'Ordenamiento', criterio FROM bdm_datos.cert_resultado_ord WHERE estado = 'PASSED'
  UNION     SELECT 'Novedades',    criterio FROM bdm_datos.cert_resultado_nov WHERE estado = 'PASSED'
)
SELECT c.proceso, c.bloque, c.criterio,
       COALESCE(u.estado, 'SIN_EVALUAR') AS estado_ultimo,
       LEFT(c.enunciado, 110)            AS enunciado,
       LEFT(u.detalle,   160)            AS detalle
FROM       cat c
LEFT  JOIN ult  u ON u.proceso = c.proceso AND u.criterio = c.criterio
LEFT  JOIN paso p ON p.proceso = c.proceso AND p.criterio = c.criterio
WHERE  p.criterio IS NULL          -- no paso en NINGUNA fase
ORDER  BY c.proceso, c.bloque, c.criterio;


-- =====================================================================
-- (3) UN HALLAZGO QUE ESTA CONSULTA DESTAPA, Y QUE NO SE ARREGLA AQUI
--
-- EL ALCANCE DEL TITULAR DE ORDENAMIENTO SE QUEDO EN 45 DE 90. El WHERE
-- de validacion_certificacion_ord.sql:37-39 cuenta solo FASE4 + CA_FUNC
-- mas nueve transversales, y EXCLUYE FASE1, FASE2 y FASE3 -- 29
-- criterios que hoy ya estan certificados sobre mock (F1 seis de ocho,
-- F2 diez de diez, F3 nueve de once).
--
-- Consecuencia: el titular 45/44/1 SUBESTIMA lo certificado, y la
-- consulta (1) de aqui arriba da un numero mayor. Las dos son ciertas:
-- una cuenta el alcance declarado y la otra el catalogo entero.
--
-- NO se ensancha ese WHERE en el mismo commit que la pagina: mueve el
-- tablero, y el gate de Ordenamiento no esta encendido
-- (run_cert_asercion_final.sql:35-36 llama solo UNIFICACION y NOVEDADES).
-- Encenderlo pide primero verde en Redshift real, que es la condicion
-- que ya se cumplio para Novedades en el job #409.
-- =====================================================================
