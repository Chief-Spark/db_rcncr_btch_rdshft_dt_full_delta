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

-- Resumen legible en la consola del job, con la misma forma que el resto de
-- los gates de la bateria.
SELECT criterio, estado, LEFT(detalle, 160) AS detalle
FROM bdm_datos.cert_resultado
WHERE modo = 'GEO'
  AND fecha_hora = (SELECT MAX(fecha_hora) FROM bdm_datos.cert_resultado WHERE modo = 'GEO')
ORDER BY criterio;
