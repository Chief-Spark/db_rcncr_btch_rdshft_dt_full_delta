-- Rollback 1:1 seed_mock_matriz_r2.sql
-- Elimina solo el rango que ese script posee: ARQ 21..50 (Regla 2), ARQ 56
-- (GEO con coordenadas), ARQ 60 (cascada R1 -> R2, el caso de G-02) y ARQ 71
-- (sitio 2, el caso de R2-06) y ARQ 72 (sitio 3, el caso de A8). No toca
-- las semillas de Regla 1 (ARQ 1..20), ni la banda 9570000..9590999 del Grupo
-- A -- esa la posee seed_mock_matriz.sql y la limpia su propio rollback --, ni
-- ningun dato real. Orden inverso al INSERT.
-- El catalogo bdm_stage.nomenclatura NO se borra aqui: es compartido y lo
-- necesitan otros consumidores; su contenido es idempotente (DELETE + INSERT
-- completo en cada ejecucion del seed).
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999
    OR id_buro_persona BETWEEN 9710000 AND 9710999
    OR id_buro_persona BETWEEN 9720000 AND 9720999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999
    OR id_buro_persona BETWEEN 9710000 AND 9710999
    OR id_buro_persona BETWEEN 9720000 AND 9720999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 92100000 AND 95609999
    OR cod_dw_persona_ubic BETWEEN 96000000 AND 96009999
    OR cod_dw_persona_ubic BETWEEN 97100000 AND 97109999
    OR cod_dw_persona_ubic BETWEEN 97200000 AND 97209999;
DELETE FROM bdm_stage.diccionario_complementos       WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999
    OR id_buro_persona BETWEEN 9710000 AND 9710999
    OR id_buro_persona BETWEEN 9720000 AND 9720999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 92100000 AND 95609999
    OR cod_dw_direccion_fisica BETWEEN 96000000 AND 96009999
    OR cod_dw_direccion_fisica BETWEEN 97100000 AND 97109999
    OR cod_dw_direccion_fisica BETWEEN 97200000 AND 97209999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 92100000 AND 95609999
    OR cod_dw_ubic BETWEEN 96000000 AND 96009999
    OR cod_dw_ubic BETWEEN 97100000 AND 97109999
    OR cod_dw_ubic BETWEEN 97200000 AND 97209999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999
    OR id_buro_persona BETWEEN 9710000 AND 9710999
    OR id_buro_persona BETWEEN 9720000 AND 9720999;
