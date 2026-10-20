-- ============================================================================
-- Script:      01_schemas.sql
-- Objetivo:    Crear los esquemas Redshift equivalentes a las bases de datos
--              Teradata usadas por el proceso BATCH2 (REC_STAGE, REC_MTDAT,
--              REC_DATOS, REC_VISTA).
-- Proyecto:    Migracion BATCH2 Teradata -> Redshift
--
-- NOTA DE DISEÑO:
-- Teradata usa "bases de datos" como unidad de particionamiento logico
-- (REC_STAGE, REC_MTDAT, REC_DATOS...). Redshift no tiene bases de datos
-- separadas accesibles en la misma conexion/transaccion; el equivalente es
-- un ESQUEMA dentro de la misma base de datos. Se preserva la misma
-- separacion logica usando esquemas con nombre en minuscula.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS rec_stage;   -- equivalente a REC_STAGE (staging / configuracion / cubos)
CREATE SCHEMA IF NOT EXISTS rec_mtdat;   -- equivalente a REC_MTDAT (control, lotes, logs de ejecucion)
CREATE SCHEMA IF NOT EXISTS rec_datos;   -- equivalente a REC_DATOS (BDDATOS: resultados/estadisticas de proceso)
CREATE SCHEMA IF NOT EXISTS rec_vista;   -- equivalente a REC_VISTA/BTTPRUVI (vistas de dimension persona, tipo persona)
