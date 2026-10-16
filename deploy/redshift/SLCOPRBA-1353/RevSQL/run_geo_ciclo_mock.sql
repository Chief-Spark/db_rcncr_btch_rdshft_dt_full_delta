-- Rollback de run_geo_ciclo_mock.sql
-- El runner no crea objetos: solo invoca el ciclo GEO mock y escribe filas
-- de resultado. El reverso es borrar esas filas, con WHERE explicito
-- (politica REDSHIFT:232).
DELETE FROM bdm_datos.cert_resultado WHERE modo = 'GEO';
