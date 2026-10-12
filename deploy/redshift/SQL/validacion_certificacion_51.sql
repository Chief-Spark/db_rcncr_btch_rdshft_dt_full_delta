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
--   SIN_EVALUAR      el gate no escribio fila para ese criterio. Si aparece,
--                    es un defecto DEL TABLERO, no del proceso: avisar.
-- ============================================================

-- ------------------------------------------------------------
-- 1) EL TABLERO. 51 filas, siempre.
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
LEFT JOIN       bdm_datos.cert_resultado r
             ON r.criterio = c.criterio
            AND r.lote = ( SELECT MAX(lote) FROM bdm_datos.cert_resultado )
ORDER BY
  CASE c.bloque WHEN 'REGLA1' THEN 1 WHEN 'REGLA2' THEN 2 WHEN 'REGLA3' THEN 3
                WHEN 'GENERAL' THEN 4 WHEN 'GEO' THEN 5 ELSE 6 END,
  c.criterio;

-- ------------------------------------------------------------
-- 2) RESUMEN POR ESTADO. Es el numero que se reporta.
-- ------------------------------------------------------------
SELECT
  COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
  COUNT(*)                          AS criterios,
  LISTAGG(c.criterio, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales
FROM            bdm_datos.cert_criterio c
LEFT JOIN       bdm_datos.cert_resultado r
             ON r.criterio = c.criterio
            AND r.lote = ( SELECT MAX(lote) FROM bdm_datos.cert_resultado )
GROUP BY 1
ORDER BY
  CASE COALESCE(r.estado, 'SIN_EVALUAR')
    WHEN 'FAILED' THEN 1 WHEN 'SIN_EVALUAR' THEN 2 WHEN 'NO_IMPLEMENTADO' THEN 3
    WHEN 'SIN_DATO' THEN 4 WHEN 'BLOQUEADO' THEN 5 WHEN 'REVISION_MANUAL' THEN 6
    WHEN 'PASSED' THEN 7 ELSE 8 END;

-- ------------------------------------------------------------
-- 3) RESUMEN POR BLOQUE. Dice que regla esta lista y que regla no.
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
  SUM(CASE WHEN r.estado IS NULL             THEN 1 ELSE 0 END)            AS sin_evaluar
FROM            bdm_datos.cert_criterio c
LEFT JOIN       bdm_datos.cert_resultado r
             ON r.criterio = c.criterio
            AND r.lote = ( SELECT MAX(lote) FROM bdm_datos.cert_resultado )
GROUP BY 1
ORDER BY
  CASE c.bloque WHEN 'REGLA1' THEN 1 WHEN 'REGLA2' THEN 2 WHEN 'REGLA3' THEN 3
                WHEN 'GENERAL' THEN 4 WHEN 'GEO' THEN 5 ELSE 6 END;

-- ------------------------------------------------------------
-- 4) SOLO LO QUE NO PASO. La lista de trabajo.
-- ------------------------------------------------------------
SELECT c.criterio, r.estado, c.enunciado, r.detalle, c.evidencia
FROM            bdm_datos.cert_criterio c
INNER JOIN      bdm_datos.cert_resultado r
             ON r.criterio = c.criterio
            AND r.lote = ( SELECT MAX(lote) FROM bdm_datos.cert_resultado )
WHERE r.estado <> 'PASSED'
ORDER BY
  CASE r.estado WHEN 'FAILED' THEN 1 WHEN 'NO_IMPLEMENTADO' THEN 2
                WHEN 'SIN_DATO' THEN 3 WHEN 'BLOQUEADO' THEN 4 ELSE 5 END,
  c.criterio;

-- ------------------------------------------------------------
-- 5) EVOLUCION POR FASE. El mismo criterio en FULL, DELTA1, DELTA2 y FULL2.
--    Un criterio que pasa en FULL y falla en DELTA2 es un defecto de
--    incrementalidad, no de la regla.
-- ------------------------------------------------------------
SELECT criterio,
       MAX(CASE WHEN modo = 'FULL'   THEN estado END) AS full_,
       MAX(CASE WHEN modo = 'DELTA1' THEN estado END) AS delta1,
       MAX(CASE WHEN modo = 'DELTA2' THEN estado END) AS delta2,
       MAX(CASE WHEN modo = 'FULL2'  THEN estado END) AS full2
FROM   bdm_datos.cert_resultado
GROUP  BY criterio
ORDER  BY criterio;

-- ============================================================
-- EVIDENCIA DE RESPALDO
-- Lo que QA mira cuando una fila del tablero no cuadra.
-- ============================================================

-- 6) Traza de la corrida: orden de las etapas y duracion de cada una.
--    Respalda G-01 (cascada estricta).
SELECT c.corrida_id, c.lote, c.modo, c.estado,
       e.etapa, e.estado AS estado_etapa,
       DATEDIFF(second, e.fecha_hora_inicio, e.fecha_hora_fin) AS segundos,
       e.relaciones_entrada, e.personas_distintas, e.unificaciones_producidas
FROM            bdm_datos.unif_control_mock c
LEFT JOIN       bdm_datos.unif_control_etapa_mock e ON e.corrida_id = c.corrida_id
ORDER BY c.corrida_id, e.fecha_hora_inicio;

-- 7) Censo de escenarios: cuantas direcciones resolvio cada sello del legado y
--    cuantas quedaron sin resolver. Respalda R2-01..R2-07 y R2-14.
SELECT lote, modo, COALESCE(n_id, '-') AS n_id, escenario, ref_legado,
       direcciones, personas
FROM   bdm_datos.unif_escenario_censo_mock
ORDER  BY lote, direcciones DESC, n_id;

-- 8) Convergencia: los checksums de las cuatro corridas. Respalda G-06.
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
WHERE  criterio_ca LIKE '%CA-C%'
ORDER  BY 1;

-- 9) Gate por arquetipo: la evidencia fina, escenario por escenario.
SELECT criterio_ca, estado, detalle
FROM   bdm_stage.mock_unif_ca_result
WHERE  criterio_ca NOT LIKE '%CA-C%'
ORDER  BY 1;
