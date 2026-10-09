-- Rollback 1:1 seed_mock_matriz.sql
-- Elimina solo el rango de arquetipos que ese script posee (ARQ 1..20), sin
-- tocar otras semillas mock ni ningun dato real. Mismo orden inverso al INSERT.
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9010000 AND 9200999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9010000 AND 9200999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9010000 AND 9200999;
