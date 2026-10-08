-- Rollback 1:1 run_unificacion_full.sql
-- Corrida FULL: vaciar salida de unificacion (no toca datashare)
TRUNCATE TABLE bdm_datos.unificacion_direccion;
