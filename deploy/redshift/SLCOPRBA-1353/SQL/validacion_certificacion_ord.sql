-- ============================================================
-- validacion_certificacion_ord.sql
-- SLCOPRBA-1355: tablero de certificacion del ORDENAMIENTO (90 criterios).
-- Gemelo de validacion_certificacion_51.sql, que hace lo mismo para
-- Unificacion. Solo SELECT: no crea ni modifica nada.
-- UTF-8 sin BOM, sin acentos.
-- ============================================================

-- ------------------------------------------------------------
-- 1) EL NUMERO DE LA CERTIFICACION QA.
--
--    ALCANCE: los criterios que el evaluador puede verificar hoy -- los 30
--    de la Fase 4, los 6 CA-F, y los transversales RG-02, RG-03, RG-05,
--    RG-07, RG-08, CA-T02, CA-T03, CA-T04 y CA-T05. Son 45.
--
--    Quedan FUERA del alcance, con estado explicito en el tablero:
--      - los 29 de las Fases 1, 2 y 3, que no estan portadas a Redshift;
--      - RG-01, RG-04, RG-06, CA-M04 y CA-T01, que dependen de ellas;
--      - la gobernanza (G-01..G-06, RG-09, RG-10, CA-M02, CA-M03), que
--        requiere acta del area funcional;
--      - CA-M01, bloqueado: la paridad numerica con Teradata exige las
--        vistas frontera V_DIRECCIONES_TEMP_*, que no estan en el entregable.
--
--    El alcance se CUENTA, no se escribe a mano: si el catalogo crece, el
--    numero se mueve solo. Es el defecto que arrastra el titular de
--    Unificacion, donde el 45 es un literal.
-- ------------------------------------------------------------
SELECT
  COUNT(*)                                                             AS alcance_qa,
  SUM(CASE WHEN r.estado IN ('PASSED', 'NO_APLICA') THEN 1 ELSE 0 END) AS certificados,
  SUM(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
           THEN 1 ELSE 0 END)                                          AS pendientes,
  LISTAGG(CASE WHEN r.estado NOT IN ('PASSED', 'NO_APLICA') OR r.estado IS NULL
               THEN c.criterio END, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales_faltan
FROM            bdm_datos.cert_criterio_ord c
LEFT JOIN       bdm_datos.v_cert_ord_ultimo r ON r.criterio = c.criterio
WHERE c.bloque IN ('FASE4', 'CA_FUNC')
   OR c.criterio IN ('RG-02', 'RG-03', 'RG-05', 'RG-07', 'RG-08',
                     'CA-T02', 'CA-T03', 'CA-T04', 'CA-T05');

-- ------------------------------------------------------------
-- 2) EL TABLERO: las 90 filas, siempre.
--    El LEFT JOIN desde el catalogo mas el COALESCE garantizan que ninguna
--    falte: un criterio que el gate no escribio sale SIN_EVALUAR, que en el
--    tablero significa "defecto del gate", no "no hay dato".
-- ------------------------------------------------------------
SELECT c.bloque, c.criterio, c.prioridad, c.verificable,
       COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
       r.modo, r.lote,
       c.enunciado,
       COALESCE(r.detalle, c.evidencia)  AS detalle
FROM            bdm_datos.cert_criterio_ord c
LEFT JOIN       bdm_datos.v_cert_ord_ultimo r ON r.criterio = c.criterio
ORDER BY c.bloque, c.criterio;

-- ------------------------------------------------------------
-- 3) Resumen por estado. FAILED primero: es lo unico que tumba el build.
-- ------------------------------------------------------------
SELECT COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
       COUNT(*)                          AS criterios,
       LISTAGG(c.criterio, ', ') WITHIN GROUP (ORDER BY c.criterio) AS cuales
FROM            bdm_datos.cert_criterio_ord c
LEFT JOIN       bdm_datos.v_cert_ord_ultimo r ON r.criterio = c.criterio
GROUP BY 1
ORDER BY CASE COALESCE(r.estado, 'SIN_EVALUAR')
              WHEN 'FAILED'           THEN 1
              WHEN 'SIN_EVALUAR'      THEN 2
              WHEN 'REVISION_MANUAL'  THEN 3
              WHEN 'SIN_DATO'         THEN 4
              WHEN 'BLOQUEADO'        THEN 5
              WHEN 'NO_IMPLEMENTADO'  THEN 6
              WHEN 'FUERA_DE_ALCANCE' THEN 7
              ELSE 8 END;

-- ------------------------------------------------------------
-- 4) Resumen por bloque, una columna por estado.
-- ------------------------------------------------------------
SELECT c.bloque,
       COUNT(*)                                                                AS total,
       SUM(CASE WHEN r.estado = 'PASSED'           THEN 1 ELSE 0 END)          AS passed,
       SUM(CASE WHEN r.estado = 'FAILED'           THEN 1 ELSE 0 END)          AS failed,
       SUM(CASE WHEN r.estado = 'SIN_DATO'         THEN 1 ELSE 0 END)          AS sin_dato,
       SUM(CASE WHEN r.estado = 'REVISION_MANUAL'  THEN 1 ELSE 0 END)          AS revision,
       SUM(CASE WHEN r.estado = 'NO_IMPLEMENTADO'  THEN 1 ELSE 0 END)          AS no_impl,
       SUM(CASE WHEN r.estado = 'BLOQUEADO'        THEN 1 ELSE 0 END)          AS bloqueado,
       SUM(CASE WHEN r.estado = 'FUERA_DE_ALCANCE' THEN 1 ELSE 0 END)          AS fuera,
       SUM(CASE WHEN r.estado IS NULL              THEN 1 ELSE 0 END)          AS sin_evaluar
FROM            bdm_datos.cert_criterio_ord c
LEFT JOIN       bdm_datos.v_cert_ord_ultimo r ON r.criterio = c.criterio
GROUP BY 1
ORDER BY 1;

-- ------------------------------------------------------------
-- 5) Solo lo que hay que mirar: FAILED, SIN_EVALUAR y REVISION_MANUAL.
--    Los tres primeros son trabajo; REVISION_MANUAL es decision de negocio.
-- ------------------------------------------------------------
SELECT c.criterio, COALESCE(r.estado, 'SIN_EVALUAR') AS estado,
       c.enunciado, COALESCE(r.detalle, c.evidencia) AS detalle
FROM            bdm_datos.cert_criterio_ord c
LEFT JOIN       bdm_datos.v_cert_ord_ultimo r ON r.criterio = c.criterio
WHERE COALESCE(r.estado, 'SIN_EVALUAR') IN ('FAILED', 'SIN_EVALUAR', 'REVISION_MANUAL')
ORDER BY CASE COALESCE(r.estado, 'SIN_EVALUAR')
              WHEN 'FAILED'      THEN 1
              WHEN 'SIN_EVALUAR' THEN 2
              ELSE 3 END,
         c.criterio;

-- ------------------------------------------------------------
-- 6) Evolucion por fase. Un criterio que pasa en FULL y falla en DELTA2 es
--    un defecto de incrementalidad, no de la regla.
-- ------------------------------------------------------------
SELECT criterio,
       MAX(CASE WHEN modo = 'FULL'   THEN estado END) AS full_,
       MAX(CASE WHEN modo = 'DELTA1' THEN estado END) AS delta1,
       MAX(CASE WHEN modo = 'DELTA2' THEN estado END) AS delta2,
       MAX(CASE WHEN modo = 'FULL2'  THEN estado END) AS full2
FROM bdm_datos.cert_resultado_ord
GROUP BY criterio
ORDER BY criterio;

-- ------------------------------------------------------------
-- 7) Evidencia de respaldo: el catalogo de betas, canal a canal.
--
--    NOTA DE ORDEN: este script va en el .par ANTES de
--    run_unif_convergencia_mock.sql, que ejecuta cuatro ciclos mas de
--    Unificacion y deja el mock en el estado de la cuarta corrida. Si
--    corriera despues, las consultas de evidencia leerian una
--    unificacion_direccion_mock posterior a los scores del e2e y la
--    foto saldria descuadrada. Los veredictos no dependen del orden
--    (se escriben junto a cada corrida de Ordenamiento); la evidencia si.
--    Esperado DIR 12, TEL 11, CEL 11, EMA 13 = 47 (RITM5226589).
-- ------------------------------------------------------------
SELECT canal,
       COUNT(*)                             AS betas,
       COUNT(DISTINCT cod_caracteristica)   AS codigos_distintos,
       MIN(valor_beta)                      AS beta_min,
       MAX(valor_beta)                      AS beta_max
FROM bdm_datos.beta_ordenamiento
GROUP BY 1
ORDER BY 1;

-- ------------------------------------------------------------
-- 8) Evidencia de respaldo: los scores del universo mock, canal a canal.
--    'grupos_con_empate' es el que decide la idempotencia: el ranking es un
--    ROW_NUMBER sin columna de desempate, asi que un empate de score hace el
--    lugar no determinista y dos corridas pueden intercambiarlo.
-- ------------------------------------------------------------
SELECT s.canal,
       COUNT(*)                                        AS scores,
       COUNT(DISTINCT s.id_buro_persona)               AS personas,
       SUM(CASE WHEN s.score IS NULL THEN 1 ELSE 0 END) AS score_nulo,
       MIN(s.score)                                    AS score_min,
       MAX(s.score)                                    AS score_max,
       MAX(s.lugar)                                    AS lugar_max
FROM bdm_datos.score_ordenamiento s
WHERE s.id_buro_persona BETWEEN 9000000 AND 9999999
GROUP BY 1
ORDER BY 1;

SELECT g.canal,
       COUNT(*)                                                   AS grupos,
       SUM(CASE WHEN g.n_filas > g.n_scores THEN 1 ELSE 0 END)    AS grupos_con_empate
FROM ( SELECT canal, id_buro_persona,
              COUNT(*)              AS n_filas,
              COUNT(DISTINCT score) AS n_scores
         FROM bdm_datos.score_ordenamiento
        WHERE id_buro_persona BETWEEN 9000000 AND 9999999
        GROUP BY 1, 2 ) g
GROUP BY 1
ORDER BY 1;
