-- Rollback 1:1 seed_mock_matriz_r3.sql
-- Elimina solo el rango que ese script posee: ARQ 61..70 (Regla 3), banda
-- 9610000..9700999. No toca las semillas de Regla 1 (9010000..9200999), de
-- Regla 2 (9210000..9560999), del Grupo A (9570000..9590999) ni del ARQ 60
-- (9600000..9600999), y ningun dato real. Orden inverso al INSERT.
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9610000 AND 9700999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9610000 AND 9700999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9610000 AND 9700999;
