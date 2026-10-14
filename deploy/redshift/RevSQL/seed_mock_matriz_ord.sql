-- Rollback 1:1 seed_mock_matriz_ord.sql
-- Borra solo la banda del Ordenamiento (ARQ 80..84). WHERE explicito en todos
-- los DELETE: lo exige [REDSHIFT:232]. No se dropean las tablas: son
-- compartidas con la matriz de Unificacion.
DELETE FROM bdm_stage.relacion_persona_ubicacion
 WHERE id_buro_persona BETWEEN 9800000 AND 9849999;

DELETE FROM bdm_stage.ubicacion_estandarizada
 WHERE cod_dw_ubic BETWEEN 98000000 AND 98499999;

DELETE FROM bdm_stage.reporte_relacion_persona_ubica
 WHERE cod_dw_persona_ubic BETWEEN 98000000 AND 98499999;

DELETE FROM bdm_stage.contacto_canal
 WHERE id_buro_persona BETWEEN 9800000 AND 9849999;
