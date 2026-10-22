-- Rollback 1:1 run_reconocer_e2e_real_full.sql
-- Solo invocacion: no crea objetos permanentes que revertir. Los
-- procedimientos invocados se revierten desde el repo pgm, y las siete tablas
-- dominio desde strct.
-- NO se vacian las tablas dominio aqui: un rollback del paquete no es una
-- orden de borrar el dato que la corrida entrego.
SELECT 1;
