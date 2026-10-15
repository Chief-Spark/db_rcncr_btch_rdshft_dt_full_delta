-- Rollback 1:1 validacion_certificacion_51.sql
-- Tablero de certificacion: solo SELECT sobre bdm_datos.cert_criterio,
-- bdm_datos.cert_resultado y las tablas de traza y censo. Sin objetos
-- permanentes que revertir. Las dos tablas del tablero las elimina el rollback
-- de strct (13_rollback_ddl_cert_criterios.sql).
SELECT 1;
