-- ============================================================
-- validacion_certificacion_nov.sql
-- SLCOPRBA-1355: tablero de certificacion de NOVEDADES (32 criterios).
-- Gemelo de validacion_certificacion_ord.sql. Solo SELECT: no crea ni
-- modifica nada. UTF-8 sin BOM, sin acentos.
-- ============================================================

-- ------------------------------------------------------------
-- 1) EL NUMERO DE LA CERTIFICACION QA.
--
--    ALCANCE: los criterios del dominio UBICACION que el evaluador puede
--    verificar hoy, es decir NOV-UB-01..NOV-UB-15.
--
--    Quedan FUERA del alcance, con estado explicito en el tablero:
--      - NOV-UB-16..NOV-UB-22, bloqueados porque falta un catalogo que no se
--        entrego o una columna del contrato GEO que no esta pinada;
--      - los siete dominios no portados (NOV-CAT, NOV-INB, NOV-CON, NOV-PIN,
--        NOV-HIS, NOV-MOV, NOV-AGR);
--      - NOV-G-01..NOV-G-03, que son decisiones y no consultas.
--
--    El alcance se CUENTA, no se escribe a mano: si el catalogo crece, el
--    numero se mueve solo.
-- ------------------------------------------------------------
SELECT
  COUNT(*)                                                             AS alcance_qa,
  SUM(CASE WHEN r.estado IN ('PASSED', 'NO_APLICA') THEN 1 ELSE 0 END) AS certificados,
  SUM(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
           THEN 1 ELSE 0 END)                                          AS pendientes,
  LISTAGG(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
               THEN c.criterio END, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales_faltan
FROM            bdm_datos.cert_criterio_nov c
LEFT JOIN       bdm_datos.v_cert_nov_ultimo r ON r.criterio = c.criterio
WHERE c.bloque = 'UBICACION'
  AND c.criterio NOT IN ('NOV-UB-16', 'NOV-UB-17', 'NOV-UB-18', 'NOV-UB-19',
                         'NOV-UB-20', 'NOV-UB-21', 'NOV-UB-22');

-- ------------------------------------------------------------
-- 2) EL TABLERO: las 32 filas, siempre.
--    El LEFT JOIN desde el catalogo mas el COALESCE garantizan que ninguna
--    falte: un criterio que el gate no escribio sale SIN_EVALUAR, que
--    significa "defecto del gate", no "no hay dato".
-- ------------------------------------------------------------
SELECT c.bloque,
       c.criterio,
       c.prioridad,
       COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
       c.enunciado,
       COALESCE(r.detalle, c.evidencia)  AS detalle
FROM            bdm_datos.cert_criterio_nov c
LEFT JOIN       bdm_datos.v_cert_nov_ultimo r ON r.criterio = c.criterio
ORDER BY CASE c.bloque WHEN 'UBICACION'      THEN 1
                       WHEN 'OTROS_DOMINIOS' THEN 2
                       ELSE 3 END,
         c.criterio;

-- ------------------------------------------------------------
-- 3) EL PIVOTE POR FASE.
--    TRES columnas, no cuatro. FULL2 es la fase de la convergencia y solo la
--    corre la Unificacion (run_unif_convergencia_mock.sql:61): ni el
--    Ordenamiento ni Novedades se evaluan ahi. Una columna que siempre sale
--    en blanco no informa, confunde -- es la leccion del pivote de GEO.
-- ------------------------------------------------------------
SELECT c.criterio,
       MAX(CASE WHEN r.modo = 'FULL'   THEN r.estado END) AS full_,
       MAX(CASE WHEN r.modo = 'DELTA1' THEN r.estado END) AS delta1,
       MAX(CASE WHEN r.modo = 'DELTA2' THEN r.estado END) AS delta2
FROM            bdm_datos.cert_criterio_nov c
LEFT JOIN       bdm_datos.cert_resultado_nov r ON r.criterio = c.criterio
WHERE c.bloque = 'UBICACION'
GROUP BY c.criterio
ORDER BY c.criterio;

-- ------------------------------------------------------------
-- 4) LA TRAZA DE LAS CORRIDAS.
--    Un tablero verde con una corrida fallida detras no vale: aqui se ve el
--    estado de cada corrida y los conteos por dominio.
-- ------------------------------------------------------------
SELECT k.corrida_id,
       k.lote,
       k.modo,
       k.bootstrap,
       k.estado                AS estado_corrida,
       k.watermark_anterior,
       k.watermark_nuevo,
       e.etapa,
       e.estado                AS estado_etapa,
       e.relaciones_entrada,
       e.personas_distintas,
       e.filas_altas,
       e.filas_cambios,
       e.filas_bajas
FROM            bdm_datos.nov_control_mock k
LEFT JOIN       bdm_datos.nov_control_etapa_mock e ON e.corrida_id = k.corrida_id
ORDER BY k.corrida_id, e.etapa;
