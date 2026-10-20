-- Rollback 1:1 de run_migracion_nov_info_basica.sql
-- La migracion no se revierte a proposito: devolver info_basica a INTEGER
-- volveria a romper Novedades con datos reales. La tabla, si hay que quitarla,
-- la elimina el rollback de strct (30_rollback_ddl_novedades.sql).
SELECT 1;
