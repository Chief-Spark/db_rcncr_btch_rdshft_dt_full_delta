-- Rollback 1:1 seed_mock_matriz.sql
-- Elimina solo el rango de arquetipos que ese script posee -- ARQ 1..20
-- (Regla 1) y la banda 9570000..9590999 del Grupo A (ARQ 57, 58 y 59) --, sin
-- tocar otras semillas mock ni ningun dato real. Mismo orden inverso al INSERT.
-- SLCOPRBA-1355: la banda del Grupo A faltaba. El seed es idempotente y limpia
-- sus propios restos al re-aplicarse, de modo que el defecto no rompia la
-- bateria; lo que si hacia era dejar 3000 personas sembradas despues de un
-- rollback que decia haberlas quitado.
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9010000 AND 9200999
    OR id_buro_persona BETWEEN 9570000 AND 9590999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9010000 AND 9200999
    OR id_buro_persona BETWEEN 9570000 AND 9590999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 90100000 AND 92009999
    OR cod_dw_persona_ubic BETWEEN 95700000 AND 95909999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 90100000 AND 92009999
    OR cod_dw_direccion_fisica BETWEEN 95700000 AND 95909999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 90100000 AND 92009999
    OR cod_dw_ubic BETWEEN 95700000 AND 95909999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9010000 AND 9200999
    OR id_buro_persona BETWEEN 9570000 AND 9590999;
