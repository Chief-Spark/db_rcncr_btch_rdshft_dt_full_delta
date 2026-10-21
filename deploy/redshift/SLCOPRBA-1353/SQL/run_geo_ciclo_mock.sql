-- ============================================================
-- run_geo_ciclo_mock.sql  (Reconocer / GEO MOCK - SLCOPRBA-1355)
--
-- Corre el ciclo GEO mock completo y deja el veredicto de CA-02, CA-03,
-- CA-04 y CA-05 en bdm_datos.cert_resultado. CA-01 lo afirma la bateria.
--
-- VA AQUI Y NO ANTES, y el sitio es parte del diseno: entre la convergencia
-- y el tablero. El cargador mueve el Lote a 'cargado' y CA-01 exige verlo en
-- 'exportado', de modo que dentro del e2e este ciclo tumbaria CA-01 por un
-- efecto de orden. Despues del tablero tampoco vale: sus cuatro criterios no
-- llegarian a tiempo para contarse.
--
-- NO MUEVE EL TABLERO DE UNIFICACION. El simulador solo devuelve
-- geocodificadas las ubicaciones que YA tenian coordenadas en el mock, con
-- esas mismas coordenadas, de modo que el insumo de la Regla 3 queda igual y
-- los conteos exactos de R3-02..R3-10 no se mueven. Si alguna vez esta
-- bateria empieza a fallar en Regla 3 despues de tocar GEO, es aqui donde
-- hay que mirar primero.
-- ============================================================

CALL bdm_datos.sp_cert_geo_mock();

-- ------------------------------------------------------------
-- Y AHORA SI, LA TABLA DOMINIO d7 (2026-10-21).
-- mat_info_punto_interes se alimenta de geo_distancias, que en la via mock
-- no existe hasta que el ciclo de arriba la carga. El orquestador de
-- Novedades tiene su etapa 'punto_interes' igual que en la via real -- la
-- paridad no se rompe --, pero en mock corre DENTRO del e2e, o sea ANTES de
-- este ciclo, y registra cero con razon: en ese instante no hay distancias.
--   Esto no es un parche al orden: es la consecuencia de que el ciclo GEO
--   mock tenga que correr entre la convergencia y el tablero (si corriera
--   dentro del e2e, CA-01 se caeria por un efecto de orden). En la via REAL
--   no hace falta nada de esto: sp_rcn_geo_02_buscar_resultados carga las
--   distancias dentro del ciclo de Unificacion, antes de Novedades.
-- ------------------------------------------------------------
CALL bdm_datos.sp_novedades_punto_interes_mock(1356604);

SELECT 'd7 mat_info_punto_interes_mock' AS tabla,
       COUNT(*)                         AS filas,
       COUNT(DISTINCT ubicacion_id)     AS ubicaciones,
       COUNT(nombre)                    AS con_nombre,
       COUNT(distancia)                 AS con_distancia,
       COUNT(tipo) + COUNT(nombre_entidad) + COUNT(nit_entidad)
                                        AS en_las_tres_bloqueadas
FROM   bdm_datos.mat_info_punto_interes_mock;

-- Resumen legible en la consola del job, con la misma forma que el resto de
-- los gates de la bateria.
SELECT criterio, estado, LEFT(detalle, 160) AS detalle
FROM bdm_datos.cert_resultado
WHERE modo = 'GEO'
  AND fecha_hora = (SELECT MAX(fecha_hora) FROM bdm_datos.cert_resultado WHERE modo = 'GEO')
ORDER BY criterio;
