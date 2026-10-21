-- Reverso de run_migracion_observabilidad.sql.
--
-- NO HAY NADA QUE DESHACER, como en las otras dos migraciones: quitar las
-- columnas dejaria las tablas sin lo que los SP escriben, y estrechar etapa
-- de vuelta a 20 o 30 PERDERIA dato -- justo lo que el ensanche existe para
-- evitar. El reverso del OBJETO vive en pgm
-- (RevSQL/sp_rcn_ctl_obs_migrar.sql, que borra el procedimiento).
SELECT 1;
