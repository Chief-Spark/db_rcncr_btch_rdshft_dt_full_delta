-- Rollback 1:1 reset_mock.sql
-- El script solo hace TRUNCATE de tablas de salida y control del mock: no crea
-- objetos ni inserta datos, asi que no hay nada que revertir. Las tablas en si
-- las elimina el rollback de strct.
SELECT 1;
