-- ============================================================
-- validacion_certificacion_51.sql
-- SLCOPRBA-1355: TABLERO DE CERTIFICACION. Los 51 criterios de aceptacion de
-- los dos documentos de negocio, con el ID del documento como clave.
-- UTF-8 sin BOM.
--
-- PARA QUIEN LO EJECUTA (QA):
--   Esto es lo unico que hay que leer para saber si el proceso cumple. No hay
--   que traducir nombres internos ni cruzar tableros: una fila por criterio,
--   con su enunciado, su veredicto y donde mirar si no paso.
--
--   Se ejecuta DESPUES de:
--     reset_mock.sql
--     seed_mock_matriz.sql
--     seed_mock_matriz_r2.sql
--     run_reconocer_e2e_mock_full_delta.sql
--     run_unif_convergencia_mock.sql
--
-- COMO SE LEE EL ESTADO:
--   PASSED           cumple, verificado por consulta.
--   FAILED           NO cumple, verificado por consulta. Es un defecto.
--   NO_IMPLEMENTADO  la funcionalidad no existe todavia. No es un defecto de
--                    ejecucion: es alcance pendiente.
--   SIN_DATO         el codigo lo contempla pero ningun dato de la bateria lo
--                    ejercita, asi que no se puede afirmar. Tampoco se puede
--                    negar.
--   BLOQUEADO        depende de un insumo externo que no esta disponible
--                    (extracto de Teradata, COPY desde S3, ArcGIS).
--   REVISION_MANUAL  propiedad de diseno o de proceso; no hay consulta que la
--                    pueda afirmar. Se revisa leyendo codigo o actas.
--   FUERA_DE_ALCANCE no es responsabilidad de este desarrollo. Se muestra para
--                    que el tablero siga mapeando 1:1 con el documento, pero NO
--                    cuenta para la certificacion QA.
--   NO_APLICA        el criterio no se evalua en esta fase. Un escenario de la
--                    Regla 2 en un DELTA sobre datos sin mutar produce cero
--                    unificaciones, y eso es CORRECTO: se certifica en el FULL.
--                    No es un defecto.
--   SIN_EVALUAR      el gate no escribio fila para ese criterio. Si aparece,
--                    es un defecto DEL TABLERO, no del proceso: avisar.
-- ============================================================

-- ------------------------------------------------------------
-- Nota sobre bdm_datos.v_cert_ultimo (definida en strct/13_ddl_cert_criterios):
-- es el ULTIMO veredicto de cada criterio, tomado por fecha_hora y NO por
-- numero de lote. El numero de lote no ordena las corridas en el tiempo: la
-- bateria corre primero el e2e (1356601, 1356602, 1356604) y despues la
-- convergencia (1356501..1356504), que son numericamente MENORES. Con
-- MAX(lote) el tablero mostraria la evaluacion del e2e, donde G-06 sale
-- SIN_DATO porque CA-C01..CA-C08 aun no se habian escrito.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 1) EL NUMERO DE LA CERTIFICACION QA.
--
--    ALCANCE = 50 criterios: los 51 de los documentos menos GOB-03 (acta de
--    aprobacion del area de negocio, fuera del alcance de este desarrollo).
--
--    LOS CINCO DE GEO ENTRAN DESDE SLCOPRBA-1355 y antes no estaban. El
--    motivo por el que se excluian -- "el Cargador y el Reenganchador no
--    tienen variante mock y el rol IAM no esta asociado al cluster" -- dejo
--    de ser cierto en su primera mitad: ya existen
--    sp_geo_cargar_georreferenciacion_mock y sp_geo_reenganchar_r3_mock, y
--    el viaje a S3 se sustituye por bdm_stage.mock_geo_respuesta.
--
--    La segunda mitad SIGUE SIENDO CIERTA y conviene no perderla de vista:
--    el rol sigue sin asociar, de modo que lo que NO se certifica es que el
--    UNLOAD escriba en S3 y que el COPY lo lea. Son dos sentencias cuyo
--    riesgo es de permisos, no de logica; todo lo demas del ciclo GEO --
--    gates de estado y de conteo, conciliacion de tipos, rechazos, los tres
--    UPDATE por Status y las dos ramas del reenganche -- es el mismo SQL y
--    si queda certificado.
--
--    Esta es la fila que se reporta. Si certificados = 50, la unificacion
--    cumple los criterios de aceptacion que QA puede probar hoy.
-- ------------------------------------------------------------
SELECT
  50                                                                  AS alcance_qa,
  SUM(CASE WHEN r.estado IN ('PASSED', 'NO_APLICA') THEN 1 ELSE 0 END) AS certificados,
  SUM(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
           THEN 1 ELSE 0 END)                                          AS pendientes,
  LISTAGG(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
               THEN c.criterio END, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales_faltan
FROM            bdm_datos.cert_criterio  c
LEFT JOIN       bdm_datos.v_cert_ultimo  r ON r.criterio = c.criterio
WHERE c.criterio <> 'GOB-03';

-- ------------------------------------------------------------
-- 2) EL TABLERO. 51 filas, siempre.
--    El LEFT JOIN contra el catalogo es lo que garantiza las 51: un criterio
--    que el gate no evalue sale SIN_EVALUAR de forma explicita, no ausente.
-- ------------------------------------------------------------
SELECT
  c.bloque,
  c.criterio,
  COALESCE(r.estado, 'SIN_EVALUAR')              AS estado,
  c.verificable,
  c.enunciado,
  COALESCE(r.detalle, '(el gate no escribio fila)') AS detalle,
  c.evidencia
FROM            bdm_datos.cert_criterio c
LEFT JOIN       bdm_datos.v_cert_ultimo r
             ON r.criterio = c.criterio
ORDER BY
  CASE c.bloque WHEN 'REGLA1' THEN 1 WHEN 'REGLA2' THEN 2 WHEN 'REGLA3' THEN 3
                WHEN 'GENERAL' THEN 4 WHEN 'GEO' THEN 5 ELSE 6 END,
  c.criterio;

-- ------------------------------------------------------------
-- 3) RESUMEN POR ESTADO. Es el numero que se reporta.
-- ------------------------------------------------------------
SELECT
  COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
  COUNT(*)                          AS criterios,
  LISTAGG(c.criterio, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales
FROM            bdm_datos.cert_criterio c
LEFT JOIN       bdm_datos.v_cert_ultimo r
             ON r.criterio = c.criterio
GROUP BY 1
ORDER BY
  CASE COALESCE(r.estado, 'SIN_EVALUAR')
    WHEN 'FAILED' THEN 1 WHEN 'SIN_EVALUAR' THEN 2 WHEN 'NO_IMPLEMENTADO' THEN 3
    WHEN 'SIN_DATO' THEN 4 WHEN 'BLOQUEADO' THEN 5 WHEN 'REVISION_MANUAL' THEN 6
    WHEN 'NO_APLICA' THEN 7 WHEN 'FUERA_DE_ALCANCE' THEN 8
    WHEN 'PASSED' THEN 9 ELSE 10 END;

-- ------------------------------------------------------------
-- 4) RESUMEN POR BLOQUE. Dice que regla esta lista y que regla no.
-- ------------------------------------------------------------
SELECT
  c.bloque,
  COUNT(*)                                                                AS criterios,
  SUM(CASE WHEN r.estado = 'PASSED'          THEN 1 ELSE 0 END)            AS passed,
  SUM(CASE WHEN r.estado = 'FAILED'          THEN 1 ELSE 0 END)            AS failed,
  SUM(CASE WHEN r.estado = 'NO_IMPLEMENTADO' THEN 1 ELSE 0 END)            AS no_implementado,
  SUM(CASE WHEN r.estado = 'SIN_DATO'        THEN 1 ELSE 0 END)            AS sin_dato,
  SUM(CASE WHEN r.estado = 'BLOQUEADO'       THEN 1 ELSE 0 END)            AS bloqueado,
  SUM(CASE WHEN r.estado = 'REVISION_MANUAL' THEN 1 ELSE 0 END)            AS revision_manual,
  SUM(CASE WHEN r.estado = 'NO_APLICA'       THEN 1 ELSE 0 END)            AS no_aplica,
  SUM(CASE WHEN r.estado = 'FUERA_DE_ALCANCE' THEN 1 ELSE 0 END)           AS fuera_alcance,
  SUM(CASE WHEN r.estado IS NULL             THEN 1 ELSE 0 END)            AS sin_evaluar
FROM            bdm_datos.cert_criterio c
LEFT JOIN       bdm_datos.v_cert_ultimo r
             ON r.criterio = c.criterio
GROUP BY 1
ORDER BY
  CASE c.bloque WHEN 'REGLA1' THEN 1 WHEN 'REGLA2' THEN 2 WHEN 'REGLA3' THEN 3
                WHEN 'GENERAL' THEN 4 WHEN 'GEO' THEN 5 ELSE 6 END;

-- ------------------------------------------------------------
-- 5) SOLO LO QUE NO PASO. La lista de trabajo.
-- ------------------------------------------------------------
SELECT c.criterio, r.estado, c.enunciado, r.detalle, c.evidencia
FROM            bdm_datos.cert_criterio c
INNER JOIN      bdm_datos.v_cert_ultimo r
             ON r.criterio = c.criterio
-- NO_APLICA no entra: no es trabajo pendiente, es un criterio que esta fase no
-- evalua y que la fase FULL si certifica.
WHERE r.estado NOT IN ('PASSED', 'NO_APLICA', 'FUERA_DE_ALCANCE')
ORDER BY
  CASE r.estado WHEN 'FAILED' THEN 1 WHEN 'NO_IMPLEMENTADO' THEN 2
                WHEN 'SIN_DATO' THEN 3 WHEN 'BLOQUEADO' THEN 4 ELSE 5 END,
  c.criterio;

-- ------------------------------------------------------------
-- 6) EVOLUCION POR FASE. El mismo criterio en FULL, DELTA1, DELTA2 y FULL2.
--    Un criterio que pasa en FULL y falla en DELTA2 es un defecto de
--    incrementalidad, no de la regla.
--
--    LA COLUMNA geo ES APARTE Y NO ES UNA FASE. El ciclo GEO mock corre UNA
--    vez, entre la convergencia y este tablero, de modo que sus criterios no
--    tienen veredicto por fase: lo que hay es un veredicto y ya. Sin esta
--    columna, CA-02..CA-05 salian con el residuo BLOQUEADO de las filas
--    viejas del evaluador mientras el titular los daba en PASSED (job #402),
--    que es exactamente la clase de contradiccion que hace desconfiar de un
--    tablero entero.
--
--    Se anade la columna en vez de reescribir el modo de esas filas a
--    'DELTA2': ponerles una fase seria afirmar que se evaluaron en una fase
--    en la que no se evaluaron.
-- ------------------------------------------------------------
SELECT criterio,
       MAX(CASE WHEN modo = 'FULL'   THEN estado END) AS full_,
       MAX(CASE WHEN modo = 'DELTA1' THEN estado END) AS delta1,
       MAX(CASE WHEN modo = 'DELTA2' THEN estado END) AS delta2,
       MAX(CASE WHEN modo = 'FULL2'  THEN estado END) AS full2,
       MAX(CASE WHEN modo = 'GEO'    THEN estado END) AS geo
FROM   bdm_datos.cert_resultado
GROUP  BY criterio
ORDER  BY criterio;

-- ============================================================
-- EVIDENCIA DE RESPALDO
-- Lo que QA mira cuando una fila del tablero no cuadra.
-- ============================================================

-- 7) Traza de la corrida: orden de las etapas y duracion de cada una.
--    Respalda G-01 (cascada estricta).
SELECT c.corrida_id, c.lote, c.modo, c.estado,
       e.etapa, e.estado AS estado_etapa,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin) AS segundos,
       e.relaciones_entrada, e.personas_distintas, e.unificaciones_producidas
FROM            bdm_datos.unif_control_mock c
LEFT JOIN       bdm_datos.unif_control_etapa_mock e ON e.corrida_id = c.corrida_id
ORDER BY c.corrida_id, e.fecha_hora_inicio;

-- 8) Censo de escenarios: cuantas direcciones resolvio cada sello del legado y
--    cuantas quedaron sin resolver. Respalda R2-01..R2-07 y R2-14.
SELECT lote, modo, COALESCE(n_id, '-') AS n_id, escenario, ref_legado,
       direcciones, personas
FROM   bdm_datos.unif_escenario_censo_mock
ORDER  BY lote, direcciones DESC, n_id;

-- 9) Convergencia: los checksums de las cuatro corridas. Respalda G-06.
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
WHERE  criterio_ca LIKE '%CA-C%'
ORDER  BY 1;

-- 10) Gate por arquetipo: la evidencia fina, escenario por escenario.
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
WHERE  criterio_ca NOT LIKE '%CA-C%'
ORDER  BY 1;

-- 11) REGLA 3: la evidencia fina de los diez criterios -- SLCOPRBA-1355.
--     Una fila por arquetipo de la banda 9610000..9700999 con el subcaso que
--     siembra, lo que produjo y lo que debia producir. Es donde QA mira cuando
--     un criterio del bloque REGLA3 no sale PASSED.
SELECT
  r.arq,
  CASE r.arq WHEN 61 THEN 'una sola geolocalizada          (R3-02)'
             WHEN 62 THEN 'ninguna geolocalizada           (R3-03)'
             WHEN 63 THEN 'las dos geolocalizadas          (R3-04)'
             WHEN 64 THEN 'puerta a +-2                    (R3-05)'
             WHEN 65 THEN 'puerta a +-5                    (R3-06)'
             WHEN 66 THEN 'modificador de via en el texto  (R3-07)'
             WHEN 67 THEN 'cuadrante en la via principal   (R3-08)'
             WHEN 68 THEN 'tipo MZ                         (R3-01)'
             WHEN 69 THEN 'tipo Rural                      (R3-01)'
             WHEN 70 THEN 'empate de diccionario           (R3-10)'
  END                                            AS subcaso,
  COUNT(*)                                       AS direcciones,
  SUM(CASE WHEN r.unificada = 1 THEN 1 ELSE 0 END) AS parejas_r3,
  CASE WHEN r.arq IN (61, 62, 63, 64, 67) THEN 1000 ELSE 0 END AS esperado,
  CASE WHEN SUM(CASE WHEN r.unificada = 1 THEN 1 ELSE 0 END)
          = CASE WHEN r.arq IN (61, 62, 63, 64, 67) THEN 1000 ELSE 0 END
       THEN 'OK' ELSE '<-- REVISAR' END          AS veredicto
FROM ( SELECT CAST((rpu.cod_dw_persona_ubic / 10 - 9000000) / 10000 AS INTEGER) AS arq,
              CASE WHEN u.cod_dw_persona_ubic IS NOT NULL THEN 1 ELSE 0 END     AS unificada
         FROM bdm_stage.relacion_persona_ubicacion rpu
         LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
                       FROM bdm_datos.unificacion_direccion_mock
                      WHERE unifica_atributos = 3 ) u
                ON u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
        WHERE rpu.cod_dw_persona_ubic BETWEEN 96100000 AND 97009999 ) r
GROUP BY r.arq
ORDER BY r.arq;

-- 12) Diccionario de Via: las llaves de la banda de R3 con su conteo. Respalda
--     R3-04 (gana la mas reportada) y R3-10 (empate no decide: dos valores con
--     el MISMO conteo bajo la misma llave).
SELECT tipo, llave, valor, cod_dw_municipio, conteo
FROM   bdm_stage.diccionario_via
ORDER  BY tipo, llave, conteo DESC, valor;

-- 13) Dominio de tipo_ubicacion, el criterio de ENTRADA de R3 (R3-01).
--     En mock lo siembra la matriz. EN LA VIA REAL ESTA MISMA CONSULTA SOBRE
--     bdm_tempo.v_xpm_ubicacion_estandarizada es la que confirma que el literal
--     del datashare (standardizedtipo) sea de verdad 'Via': si alli no lo
--     fuera, R3 daria 0 filas sin dar ningun error.
SELECT COALESCE(tipo_ubicacion, '(nulo)') AS tipo_ubicacion,
       COUNT(*)                           AS ubicaciones
FROM   bdm_tempo.v_mock_ubicacion_estandarizada
GROUP  BY 1
ORDER  BY 2 DESC;

-- 14) SITIO 2 DE CREACION DE DIRECCIONES (ARQ 71). La evidencia fina de R2-06.
--     Una fila por direccion generada por el sitio 2, con las dos originales
--     que quedaron como hijas. Las tres columnas de la derecha son las tres
--     mitades del criterio: que se cree la direccion, que combine ambas sin
--     repetir la nomenclatura compartida, y que las DOS originales -- el padre
--     de la comparacion incluido -- cuelguen de ella.
SELECT g.complemento                                   AS complemento_generado,
       COUNT(*)                                        AS direcciones_generadas,
       SUM(h.hijas)                                    AS hijas_totales,
       MIN(h.hijas)                                    AS hijas_min,
       MAX(h.hijas)                                    AS hijas_max,
       CASE WHEN TRIM(g.complemento) = 'ED 1 CS 5 LC 3'
             AND MIN(h.hijas) = 2 AND MAX(h.hijas) = 2
            THEN 'OK' ELSE 'REVISAR' END               AS veredicto
FROM   bdm_datos.direccion_fisica_generada_mock g
JOIN   bdm_datos.rpu_generada_mock r
  ON   r.cod_dw_direccion_fisica = g.cod_dw_direccion_fisica
JOIN ( SELECT cod_dw_direccion_unificada AS padre,
              COUNT(DISTINCT cod_dw_persona_ubic) AS hijas
       FROM   bdm_datos.unificacion_direccion_mock
       WHERE  cod_dw_persona_ubic BETWEEN 97100000 AND 97109999
         AND  unifica_atributos = 2
       GROUP  BY 1 ) h
  ON   h.padre = r.cod_dw_persona_ubic
GROUP  BY 1
ORDER  BY 1;

-- 15) EVIDENCIA FINA DEL SITIO 3 (sello 'A8', escenario 6 subcaso 1)
--     Espejo de la consulta 14. El ARQ 72 trae los MISMOS dos componentes en
--     orden CRUZADO ('BL 2 ED 7' y 'ED 7 BL 2'); el motor debe fusionarlos y
--     reordenarlos por (nivel, valor). Con BL y ED ambos en nivel 2 el
--     desempate lo da el valor, de modo que el resultado correcto es
--     'BL 2 ED 7' -- sin repetir nomenclatura, que es lo que exige R2-12.
SELECT g.complemento                                   AS complemento_generado,
       COUNT(*)                                        AS direcciones_generadas,
       SUM(h.hijas)                                    AS hijas_totales,
       MIN(h.hijas)                                    AS hijas_min,
       MAX(h.hijas)                                    AS hijas_max,
       CASE WHEN TRIM(g.complemento) = 'BL 2 ED 7'
             AND MIN(h.hijas) = 2 AND MAX(h.hijas) = 2
            THEN 'OK' ELSE 'REVISAR' END               AS veredicto
FROM   bdm_datos.direccion_fisica_generada_mock g
JOIN   bdm_datos.rpu_generada_mock r
  ON   r.cod_dw_direccion_fisica = g.cod_dw_direccion_fisica
JOIN ( SELECT cod_dw_direccion_unificada AS padre,
              COUNT(DISTINCT cod_dw_persona_ubic) AS hijas
       FROM   bdm_datos.unificacion_direccion_mock
       WHERE  cod_dw_persona_ubic BETWEEN 97200000 AND 97209999
         AND  unifica_atributos = 2
       GROUP  BY 1 ) h
  ON   h.padre = r.cod_dw_persona_ubic
GROUP  BY 1
ORDER  BY 1;

-- 16) EVIDENCIA FINA DEL SITIO 4 (sello 'D9', escenario 6 subcaso 2)
--     Espejo de la consulta 15. El ARQ 73 trae dos complementos que no
--     comparten NINGUNA nomenclatura y cuyos niveles difieren ('BR 5',
--     nivel 1, y 'AP 301', nivel 7); el motor debe fusionarlos y reordenarlos
--     por (nivel, valor), de donde BR va antes que AP y el resultado correcto
--     es 'BR 5 AP 301' -- sin repetir nomenclatura, que es lo que exige R2-12.
SELECT g.complemento                                   AS complemento_generado,
       COUNT(*)                                        AS direcciones_generadas,
       SUM(h.hijas)                                    AS hijas_totales,
       MIN(h.hijas)                                    AS hijas_min,
       MAX(h.hijas)                                    AS hijas_max,
       CASE WHEN TRIM(g.complemento) = 'BR 5 AP 301'
             AND MIN(h.hijas) = 2 AND MAX(h.hijas) = 2
            THEN 'OK' ELSE 'REVISAR' END               AS veredicto
FROM   bdm_datos.direccion_fisica_generada_mock g
JOIN   bdm_datos.rpu_generada_mock r
  ON   r.cod_dw_direccion_fisica = g.cod_dw_direccion_fisica
JOIN ( SELECT cod_dw_direccion_unificada AS padre,
              COUNT(DISTINCT cod_dw_persona_ubic) AS hijas
       FROM   bdm_datos.unificacion_direccion_mock
       WHERE  cod_dw_persona_ubic BETWEEN 97300000 AND 97309999
         AND  unifica_atributos = 2
       GROUP  BY 1 ) h
  ON   h.padre = r.cod_dw_persona_ubic
GROUP  BY 1
ORDER  BY 1;
