-- Rollback 1:1 run_unif_convergencia_mock.sql
-- El script corre cuatro ciclos y deja evidencia en las dos tablas del gate de
-- convergencia. Se vacian; las tablas en si las elimina el rollback de strct
-- (RevSQL/12_rollback_ddl_unif_convergencia_mock.sql).
TRUNCATE TABLE bdm_stage.mock_unif_ca_result;
TRUNCATE TABLE bdm_stage.mock_unif_convergencia;
