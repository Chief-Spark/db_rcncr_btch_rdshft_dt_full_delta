-- Rollback 1:1 seed_mock_matriz_r2.sql
-- Elimina solo el rango que ese script posee: ARQ 21..50 (Regla 2) y ARQ 56
-- (GEO con coordenadas). No toca las semillas de Regla 1 (ARQ 1..20) ni ningun
-- dato real. Orden inverso al INSERT.
-- El catalogo bdm_stage.nomenclatura NO se borra aqui: es compartido y lo
-- necesitan otros consumidores; su contenido es idempotente (DELETE + INSERT
-- completo en cada ejecucion del seed).
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.diccionario_complementos       WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
