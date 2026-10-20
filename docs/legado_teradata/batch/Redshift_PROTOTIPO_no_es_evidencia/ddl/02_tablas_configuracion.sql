-- ============================================================================
-- Script:      02_tablas_configuracion.sql
-- Objetivo:    Traduccion directa a Redshift de las tablas definidas en el
--              DDL.sql original de Teradata (esquema REC_STAGE).
-- Fuente:      DDL.sql (raiz del workspace)
--
-- NOTAS DE TRADUCCION TERADATA -> REDSHIFT:
-- - "CREATE SET/MULTISET TABLE ... FALLBACK, NO BEFORE JOURNAL, ..." son
--   clausulas de almacenamiento propias de Teradata sin equivalente directo;
--   se omiten (Redshift maneja la replicacion/durabilidad a nivel de cluster).
-- - "PRIMARY INDEX" (hashing de distribucion de Teradata) se traduce a
--   DISTSTYLE KEY / DISTKEY sobre la misma columna, que es el concepto
--   analogo mas cercano en Redshift (controla en que nodo vive cada fila).
-- - "VARCHAR(n) CHARACTER SET LATIN NOT CASESPECIFIC" -> VARCHAR(n) en
--   Redshift siempre es case-sensitive en comparaciones binarias por
--   defecto salvo collation; se documenta la diferencia pero no se emula
--   "NOT CASESPECIFIC" (si se requiere, comparar con UPPER()/LOWER() en el
--   codigo de los stored procedures).
-- - TIMESTAMP(6) -> TIMESTAMP (Redshift soporta hasta microsegundos nativamente).
-- - No existe clausula FORMAT de Teradata; se documenta en comentario.
-- ============================================================================

-- -----------------------------------------------------------------------
-- BATCH_DATOS_GENERALES: configuracion de formato/salida por solicitud+plantilla
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_datos_generales
(
    id_solicitud                BIGINT        NOT NULL,
    id_plantilla                BIGINT,
    formato_salida               VARCHAR(100),   -- 'FE_TXT' (ancho fijo) | 'FE_CSV' (delimitado)
    separador                    VARCHAR(100),
    ancho_fijo                   VARCHAR(100),
    orientacion                  VARCHAR(100),   -- 'OE_HORIZON' | 'OE_VERTICA'
    incluir_cabecera              VARCHAR(100),
    archivos_pn_pj                VARCHAR(100),   -- '1' = separa salidas PN/PJ, '0' = archivo unico PNPJ
    sector                       VARCHAR(100),
    no_reportado_suscriptor       VARCHAR(100),
    no_entregado_x_meses          VARCHAR(100),   -- > 0 activa regla de exclusion de reincidentes (ACTUALIZA_HISTORIA)
    fecha_recogida                VARCHAR(100),
    archivo_condatos              VARCHAR(100),
    sindatos                     VARCHAR(100),
    archivo_inconsistencia        VARCHAR(100),
    archivo_tablas                VARCHAR(100),
    archivo_alertas               VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud, id_plantilla);

-- -----------------------------------------------------------------------
-- BATCH_DIRECCION_FILTROS: filtros de particulas de direccion por solicitud
-- NOTA: no se encontro referencia directa a esta tabla en los .BTQ/.TPT del
-- workspace; se infiere que la consumen los SP compilados PRO_BATCH2_FILTRO_*.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_direccion_filtros
(
    id_solicitud       BIGINT        NOT NULL,
    id_plantilla       BIGINT,
    codigo_campo        VARCHAR(100),
    valor_particula      VARCHAR(100),
    codigo_tipo          VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

-- -----------------------------------------------------------------------
-- BATCH_HOMOLOGACIONES: homologacion de valores de campo por solicitud
-- NOTA: no se encontro referencia directa; se infiere consumida por el SP
-- compilado PRO_BATCH2_HOMOLOGACIONES.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_homologaciones
(
    id_solicitud        BIGINT        NOT NULL,
    id_plantilla        BIGINT,
    codigo_campo          VARCHAR(200),
    grupo_campo           VARCHAR(200),
    valor_defecto         VARCHAR(200),
    valor_homologado       VARCHAR(200)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

-- -----------------------------------------------------------------------
-- BATCH_PORCENTAJES_FILTROS: porcentajes de similitud minimos por solicitud
-- NOTA: no se encontro referencia directa; se infiere consumida por el SP
-- compilado PRO_BATCH_ADD_PORC_INSUMO.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_porcentajes_filtros
(
    id_solicitud   BIGINT        NOT NULL,
    id_plantilla   BIGINT,
    prc_tel_pn      VARCHAR(100),
    prc_cel_pn      VARCHAR(100),
    prc_dir_pn      VARCHAR(100),
    prc_mail_pn     VARCHAR(100),
    prc_tel_pj      VARCHAR(100),
    prc_cel_pj      VARCHAR(100),
    prc_dir_pj      VARCHAR(100),
    prc_mail_pj     VARCHAR(100),
    pmd_tel        VARCHAR(100),
    pmd_cel        VARCHAR(100),
    pmd_dir        VARCHAR(100),
    pmd_mail       VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

-- -----------------------------------------------------------------------
-- BATCH_SALIDAS_CAMPOS: catalogo de secciones/campos de la plantilla de salida
-- Confirmada en uso real: EXPORTPLANO_111 (v_ba2_Campos_Salida), VALIDAR_ARCHIVOS_111
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_salidas_campos
(
    id_solicitud             BIGINT        NOT NULL,
    id_plantilla             BIGINT,
    nombre_seccion            VARCHAR(100),   -- 'CON DATOS DE UBICACION' | 'SIN DATOS DE UBICACION' | ..._PERSONALIZADO
    codigo_seccion             VARCHAR(10),
    nombre_subseccion          VARCHAR(100),
    codigo_subseccion          VARCHAR(10),
    orden_subseccion           INTEGER,
    grupo_campo                VARCHAR(100),
    nombre_campo               VARCHAR(100),
    codigo_campo               VARCHAR(10)   NOT NULL,
    orden_campo                INTEGER,
    cantidad_max_campo          INTEGER,
    af_ancho_campo              INTEGER,
    af_relleno_campo            VARCHAR(10),
    af_orientacion_campo        VARCHAR(10),   -- '0'=izquierda (LPAD) | '1'=derecha (RPAD)
    requerido_campo             VARCHAR(2),
    minimo_requerido_campo       VARCHAR(10)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud, codigo_campo);

-- -----------------------------------------------------------------------
-- BATCH_SOLICITUD_BATCH: solicitud raiz del proceso (1 fila por ejecucion)
-- Confirmada en uso real: EXPORT_111, ACTUALIZA_HISTORIA_111/130
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_solicitud_batch
(
    id_solicitud          BIGINT        NOT NULL,
    tipo_id_suscriptor      VARCHAR(10),
    num_id_suscriptor       VARCHAR(20),    -- Teradata: FORMAT 'X(10)' (solo formato de despliegue, no se migra)
    nombre_plantilla        VARCHAR(100),
    prueba                 VARCHAR(100),
    archivo_control         VARCHAR(100),
    fecha_solicitud         TIMESTAMP,
    archivo_log            VARCHAR(100),
    estado                 VARCHAR(100),   -- NULL = pendiente, 'GENERADO' = cerrada (ver sp_batch2_actualiza_historia)
    id_planilla            BIGINT,
    fecha_generacion        TIMESTAMP
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);
