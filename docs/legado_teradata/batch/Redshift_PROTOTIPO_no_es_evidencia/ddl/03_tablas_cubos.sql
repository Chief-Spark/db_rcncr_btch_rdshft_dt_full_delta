-- ============================================================================
-- Script:      03_tablas_cubos.sql
-- Objetivo:    Tablas "cubo" de datos de contacto consumidas y producidas
--              por el pipeline BATCH2 (entrada de la cadena de filtros
--              PROCESACUBOS y fuente de los CSV CON_DATOS/SIN_DATOS).
--
-- ORIGEN DE LA ESTRUCTURA (actualizado 2026-10-13):
--   Las columnas de BATCH_CUBO_DIRECCION/TELEFONO/CELULAR/CORREO se toman
--   de la lista EXPLICITA de columnas que usa PRO_BATCH_ADD_PORC_INSUMO
--   (Sps_Batch.sql, tablas TMP_BATCH_PORPOS_*), que es la estructura real
--   de Teradata (sin las columnas Mosaic, eliminadas en 2021).
--   Las columnas de BATCH_CUBO_PERSONA, BATCH_CUBO_CIIU y
--   BATCH_CUBO_PUNTO_INTERES_DIR se toman de las referencias en
--   PRO_BATCH2_FILTRO_D/E/F/G/H y PRO_BATCH2_HOMOLOGACIONES.
--   Los TIPOS de dato siguen siendo inferidos (el DDL Teradata de los
--   cubos no esta en el workspace).
--
--   Columnas marcadas "(compat)" NO aparecen en los SP originales; se
--   conservan porque las usa la version Redshift de sp_batch2_cubo_export
--   (layout por defecto de las tablas pivote w_cubo_*).
--
-- NOTA: en Teradata los cubos contienen SOLO la corrida actual (se recargan
-- en cada ejecucion), por eso los filtros A..J no filtran por solicitud.
-- La version Redshift conserva ese supuesto.
-- ============================================================================

-- -----------------------------------------------------------------------
-- BATCH_CUBO_PERSONA
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_persona
(
    id_auto                  BIGINT        NOT NULL,
    id_buro_persona          BIGINT        NOT NULL,
    cod_pin_persona          VARCHAR(50),
    id_solicitud             BIGINT,          -- (compat) usado por cubo_export/exportplano Redshift
    id_plantilla             BIGINT,          -- (compat)
    tipo_id                  VARCHAR(5),
    numero_id                VARCHAR(20),     -- HOMOLOGACIONES lo normaliza a TRIM(CAST(... AS BIGINT))
    primer_apellido          VARCHAR(50),
    segundo_apellido         VARCHAR(50),
    primer_nombre            VARCHAR(50),
    segundo_nombre           VARCHAR(50),
    nombre_completo          VARCHAR(200),
    fecha_expedicion         VARCHAR(10),
    ciudad_expedicion        VARCHAR(100),
    departamento_expedicion  VARCHAR(100),
    genero                   VARCHAR(20),
    rango_edad               VARCHAR(20),
    orden_prioridad          INTEGER,
    filtro_d                 INTEGER,
    filtro_h                 INTEGER       DEFAULT 0   -- 0 = con datos, 1 = sin datos (FILTRO_H)
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_DIRECCION (unico cubo con Filtro_A)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_direccion
(
    id_auto                        BIGINT        NOT NULL,
    id_buro_persona                BIGINT        NOT NULL,
    cod_pin_persona                VARCHAR(50),
    cod_dw_agenda_batch            VARCHAR(50),
    cod_dw_persona_ubic            VARCHAR(50),
    direccion                      VARCHAR(200),
    ciudad                         VARCHAR(100),
    departamento                   VARCHAR(100),
    cod_dane_ciudad                VARCHAR(20),
    cod_dane_departamento          VARCHAR(20),
    tipo                           VARCHAR(30),
    localidad                      VARCHAR(100),
    barrio                         VARCHAR(100),
    zona                           VARCHAR(30),
    estrato                        VARCHAR(10),
    fecha_ultima_actualizacion     DATE,
    numero_de_entidades_reporta    INTEGER,
    fuente                         VARCHAR(100),
    contactabilidad                VARCHAR(100),
    medio_acceso                   VARCHAR(100),
    mejor_dia_para_gestion         VARCHAR(50),
    mejor_hora_para_gestion        VARCHAR(50),
    mejor_resultado_3meses         VARCHAR(100),
    mejor_resultado_6meses         VARCHAR(100),
    reportado_por                  VARCHAR(200),
    reportado_por_el_suscriptor    VARCHAR(10),
    meses_desde_el_ultimo_reporte  INTEGER,
    por_sim_dir                    INTEGER,
    orden_prioridad                INTEGER,
    filtro_a INTEGER, filtro_b INTEGER, filtro_c INTEGER, filtro_d INTEGER,
    filtro_e INTEGER, filtro_f INTEGER, filtro_g INTEGER,
    filtro_h INTEGER DEFAULT 0,
    filtro_i INTEGER,
    filtro_j INTEGER                                -- (compat) FILTRO_J borra filas, no marca columna
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_TELEFONO
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_telefono
(
    id_auto                        BIGINT        NOT NULL,
    id_buro_persona                BIGINT        NOT NULL,
    cod_pin_persona                VARCHAR(50),
    cod_dw_agenda_batch            VARCHAR(50),
    cod_dw_persona_ubic            VARCHAR(50),
    numero                         VARCHAR(30),
    ciudad                         VARCHAR(100),
    departamento                   VARCHAR(100),
    cod_dane_ciudad                VARCHAR(20),
    cod_dane_departamento          VARCHAR(20),
    indicativo                     VARCHAR(10),
    tipo                           VARCHAR(30),
    fecha_ultima_actualizacion     DATE,
    numero_de_entidades_reporta    INTEGER,
    fuente                         VARCHAR(100),
    reportado_por_el_suscriptor    VARCHAR(10),
    meses_desde_el_ultimo_reporte  INTEGER,
    contactabilidad                VARCHAR(100),
    medio_acceso                   VARCHAR(100),
    mejor_dia_para_gestion         VARCHAR(50),
    mejor_hora_para_gestion        VARCHAR(50),
    mejor_resultado_3meses         VARCHAR(100),
    mejor_resultado_6meses         VARCHAR(100),
    reportado_por                  VARCHAR(200),
    por_sim_tel                    INTEGER,
    orden_prioridad                INTEGER,
    filtro_b INTEGER, filtro_c INTEGER, filtro_d INTEGER,
    filtro_e INTEGER, filtro_f INTEGER, filtro_g INTEGER,
    filtro_h INTEGER DEFAULT 0,
    filtro_i INTEGER
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_CELULAR
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_celular
(
    id_auto                        BIGINT        NOT NULL,
    id_buro_persona                BIGINT        NOT NULL,
    cod_pin_persona                VARCHAR(50),
    cod_dw_agenda_batch            VARCHAR(50),
    cod_dw_persona_ubic            VARCHAR(50),
    numero                         VARCHAR(30),
    fecha_ultima_actualizacion     DATE,
    numero_de_entidades_reporta    INTEGER,
    fuente                         VARCHAR(100),
    reportado_por_el_suscriptor    VARCHAR(10),
    meses_desde_el_ultimo_reporte  INTEGER,
    contactabilidad                VARCHAR(100),
    medio_acceso                   VARCHAR(100),
    mejor_dia_para_gestion         VARCHAR(50),
    mejor_hora_para_gestion        VARCHAR(50),
    mejor_resultado_3meses         VARCHAR(100),
    mejor_resultado_6meses         VARCHAR(100),
    reportado_por                  VARCHAR(200),
    por_sim_cel                    INTEGER,
    orden_prioridad                INTEGER,
    -- (compat) columnas usadas por el layout por defecto de w_cubo_celular:
    ciudad                         VARCHAR(100),
    departamento                   VARCHAR(100),
    cod_dane_ciudad                VARCHAR(20),
    cod_dane_departamento          VARCHAR(20),
    tipo                           VARCHAR(30),
    filtro_b INTEGER, filtro_c INTEGER, filtro_d INTEGER,
    filtro_e INTEGER, filtro_f INTEGER, filtro_g INTEGER,
    filtro_h INTEGER DEFAULT 0,
    filtro_i INTEGER
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_CORREO
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_correo
(
    id_auto                        BIGINT        NOT NULL,
    id_buro_persona                BIGINT        NOT NULL,
    cod_pin_persona                VARCHAR(50),
    cod_dw_agenda_batch            VARCHAR(50),
    cod_dw_persona_ubic            VARCHAR(50),
    correo                         VARCHAR(200),
    fecha_ultima_actualizacion     DATE,
    numero_de_entidades_reporta    INTEGER,
    fuente                         VARCHAR(100),
    reportado_por_el_suscriptor    VARCHAR(10),
    meses_desde_el_ultimo_reporte  INTEGER,
    contactabilidad                VARCHAR(100),
    medio_acceso                   VARCHAR(100),
    mejor_dia_para_gestion         VARCHAR(50),
    mejor_hora_para_gestion        VARCHAR(50),
    mejor_resultado_3meses         VARCHAR(100),
    mejor_resultado_6meses         VARCHAR(100),
    reportado_por                  VARCHAR(200),
    por_sim_mail                   INTEGER,
    orden_prioridad                INTEGER,
    numero                         VARCHAR(30),   -- (compat) layout por defecto de w_cubo_correo
    filtro_b INTEGER, filtro_c INTEGER, filtro_d INTEGER,
    filtro_e INTEGER, filtro_f INTEGER, filtro_g INTEGER,
    filtro_h INTEGER DEFAULT 0,
    filtro_i INTEGER
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_CIIU (FILTRO_G lo ordena por FECHA_REPORTE; FILTRO_H usa D+G)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_ciiu
(
    id_auto              BIGINT        NOT NULL,
    id_buro_persona      BIGINT        NOT NULL,
    cod_pin_persona      VARCHAR(50),
    ciiu                 VARCHAR(20),
    actividad_economica  VARCHAR(500),
    fecha_reporte        DATE,
    orden_prioridad      INTEGER,
    filtro_d INTEGER, filtro_g INTEGER,
    filtro_h INTEGER DEFAULT 0
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- BATCH_CUBO_PUNTO_INTERES_DIR (referenciado por FILTRO_G, cubo 'PuntoInteres')
-- Estructura minima inferida de PRO_BATCH2_FILTRO_G (#2, #7).
-- La columna que corresponde a BATCH2_HOMOLOGACION.HOMOLOGADO para el
-- codigo 'DECB_NOM' se asume 'nombre_punto_interes'; AJUSTAR al nombre real.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_cubo_punto_interes_dir
(
    id_auto                     BIGINT        NOT NULL,
    id_buro_persona             BIGINT        NOT NULL,
    cod_dw_ubic                 VARCHAR(50),
    cod_dw_ubic_punto_interes   VARCHAR(50),
    nombre_punto_interes        VARCHAR(200),
    distancia                   DECIMAL(18,4),
    orden_prioridad             INTEGER,
    fecha_ultima_actualizacion  DATE,
    filtro_g                    INTEGER,
    filtro_h                    INTEGER DEFAULT 0
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

-- Las tablas de trabajo horizontales (pivote N->columnas) w_cubo_* estan
-- en 04_tablas_pivote.sql.
