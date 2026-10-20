-- ============================================================================
-- Script:      04_tablas_pivote.sql
-- Objetivo:    Tablas de trabajo horizontales (pivote), equivalentes a
--              w_cubo_telefono / w_cubo_celular / w_cubo_direccion /
--              w_cubo_correo / w_cubo_ciiu generadas dinamicamente por
--              P0033_BATCH2_CUBOEXPORT_120.BTQ / _130.TPT.
--
-- DIFERENCIA DE DISEÑO IMPORTANTE respecto a Teradata:
-- En Teradata el numero de columnas repetidas (_001, _002, ...) se genera
-- 100% dinamicamente ensamblando texto SQL como filas de la tabla
-- w_Borrar_001 y ejecutandolo via TPT. Redshift no permite CREATE TABLE con
-- un numero de columnas calculado en tiempo de ejecucion dentro de un
-- stored procedure de forma practica (EXECUTE si soporta DDL dinamico, pero
-- el *numero* de columnas de una tabla fisica no puede variar sin recrearla
-- en cada corrida, lo cual es costoso y propenso a bloqueos en un cluster
-- compartido).
--
-- Por eso se fija un NUMERO MAXIMO DE REPETICIONES POR CUBO = 10
-- (MAX_REPETICIONES_CUBO), igual al numero de posiciones "_001".."_010"
-- observado en las muestras reales de Salidas/*.ESQUEMA. Si una plantilla
-- de cliente requiriera mas de 10 telefonos/direcciones/correos por persona,
-- ampliar estas tablas (agregar columnas _011, _012, ...) y actualizar
-- sp_batch2_cubo_export y sp_batch2_exportplano acorde.
-- ============================================================================

CREATE TABLE IF NOT EXISTS rec_stage.w_cubo_telefono
(
    id_buro_persona   BIGINT NOT NULL,
    filtro_h          INTEGER DEFAULT 0,
    ciudad_001 VARCHAR(30), departamento_001 VARCHAR(30), codigo_dane_ciudad_001 VARCHAR(20), codigo_dane_departamento_001 VARCHAR(20), numero_001 VARCHAR(30), tipo_001 VARCHAR(15), fecha_ultima_actualizacion_001 VARCHAR(10), numero_entidades_reporta_001 VARCHAR(10), por_sim_tel_001 VARCHAR(30),
    ciudad_002 VARCHAR(30), departamento_002 VARCHAR(30), codigo_dane_ciudad_002 VARCHAR(20), codigo_dane_departamento_002 VARCHAR(20), numero_002 VARCHAR(30), tipo_002 VARCHAR(15), fecha_ultima_actualizacion_002 VARCHAR(10), numero_entidades_reporta_002 VARCHAR(10), por_sim_tel_002 VARCHAR(30),
    ciudad_003 VARCHAR(30), departamento_003 VARCHAR(30), codigo_dane_ciudad_003 VARCHAR(20), codigo_dane_departamento_003 VARCHAR(20), numero_003 VARCHAR(30), tipo_003 VARCHAR(15), fecha_ultima_actualizacion_003 VARCHAR(10), numero_entidades_reporta_003 VARCHAR(10), por_sim_tel_003 VARCHAR(30),
    ciudad_004 VARCHAR(30), departamento_004 VARCHAR(30), codigo_dane_ciudad_004 VARCHAR(20), codigo_dane_departamento_004 VARCHAR(20), numero_004 VARCHAR(30), tipo_004 VARCHAR(15), fecha_ultima_actualizacion_004 VARCHAR(10), numero_entidades_reporta_004 VARCHAR(10), por_sim_tel_004 VARCHAR(30),
    ciudad_005 VARCHAR(30), departamento_005 VARCHAR(30), codigo_dane_ciudad_005 VARCHAR(20), codigo_dane_departamento_005 VARCHAR(20), numero_005 VARCHAR(30), tipo_005 VARCHAR(15), fecha_ultima_actualizacion_005 VARCHAR(10), numero_entidades_reporta_005 VARCHAR(10), por_sim_tel_005 VARCHAR(30)
    -- Ampliar hasta _010 (u otro maximo acordado) replicando el bloque anterior.
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS rec_stage.w_cubo_celular
(
    id_buro_persona   BIGINT NOT NULL,
    filtro_h          INTEGER DEFAULT 0,
    ciudad_001 VARCHAR(30), departamento_001 VARCHAR(30), codigo_dane_ciudad_001 VARCHAR(20), codigo_dane_departamento_001 VARCHAR(20), numero_001 VARCHAR(30), tipo_001 VARCHAR(15), fecha_ultima_actualizacion_001 VARCHAR(10), numero_entidades_reporta_001 VARCHAR(10), por_sim_cel_001 VARCHAR(30),
    ciudad_002 VARCHAR(30), departamento_002 VARCHAR(30), codigo_dane_ciudad_002 VARCHAR(20), codigo_dane_departamento_002 VARCHAR(20), numero_002 VARCHAR(30), tipo_002 VARCHAR(15), fecha_ultima_actualizacion_002 VARCHAR(10), numero_entidades_reporta_002 VARCHAR(10), por_sim_cel_002 VARCHAR(30)
    -- Ampliar hasta _010 replicando el bloque anterior.
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS rec_stage.w_cubo_direccion
(
    id_buro_persona   BIGINT NOT NULL,
    filtro_h          INTEGER DEFAULT 0,
    ciudad_001 VARCHAR(30), departamento_001 VARCHAR(30), codigo_dane_ciudad_001 VARCHAR(20), codigo_dane_departamento_001 VARCHAR(20), direccion_001 VARCHAR(100), tipo_001 VARCHAR(15), zona_001 VARCHAR(10), estrato_001 VARCHAR(5), fecha_ultima_actualizacion_001 VARCHAR(10), numero_entidades_reporta_001 VARCHAR(10), por_sim_dir_001 VARCHAR(30),
    ciudad_002 VARCHAR(30), departamento_002 VARCHAR(30), codigo_dane_ciudad_002 VARCHAR(20), codigo_dane_departamento_002 VARCHAR(20), direccion_002 VARCHAR(100), tipo_002 VARCHAR(15), zona_002 VARCHAR(10), estrato_002 VARCHAR(5), fecha_ultima_actualizacion_002 VARCHAR(10), numero_entidades_reporta_002 VARCHAR(10), por_sim_dir_002 VARCHAR(30)
    -- Ampliar hasta _010 replicando el bloque anterior.
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS rec_stage.w_cubo_correo
(
    id_buro_persona   BIGINT NOT NULL,
    filtro_h          INTEGER DEFAULT 0,
    correo_001 VARCHAR(61), numero_001 VARCHAR(30),
    correo_002 VARCHAR(61), numero_002 VARCHAR(30)
    -- Ampliar hasta _010 replicando el bloque anterior.
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS rec_stage.w_cubo_ciiu
(
    id_buro_persona   BIGINT NOT NULL,
    filtro_h          INTEGER DEFAULT 0,
    ciiu_001 VARCHAR(20), actividad_economica_001 VARCHAR(500)
    -- Ampliar hasta _010 replicando el bloque anterior.
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);
