-- ============================================================================
-- Script:      05_tablas_control.sql
-- Objetivo:    Tablas de control, plan de ejecucion, logging y resultados
--              consumidas/producidas por el orquestador y los pasos del
--              pipeline BATCH2. Estructura inferida de su uso en los .BTQ
--              (no estan en el DDL.sql original).
-- ============================================================================

-- -----------------------------------------------------------------------
-- rec_mtdat.lote_id: contador correlativo global de lotes de ejecucion.
-- Equivalente a REC_MTDAT.LOTE_ID (ver funGenerateLote en el orquestador).
-- Se modela como tabla de una sola fila que se incrementa con UPDATE.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_mtdat.lote_id
(
    lote   BIGINT NOT NULL
)
DISTSTYLE ALL;

-- Fila inicial unica (solo si la tabla esta vacia).
INSERT INTO rec_mtdat.lote_id (lote)
SELECT 0
WHERE NOT EXISTS (SELECT 1 FROM rec_mtdat.lote_id);

-- -----------------------------------------------------------------------
-- rec_mtdat.log_td / log_td_detalle: bitacora de ejecucion de cada
-- stored procedure del pipeline, usada para decidir exito/fallo
-- (patron repetido: "SEL Descripcion_Teradata_Error ... <> 'Finalizo Exitosamente'")
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_mtdat.log_td
(
    lote                   BIGINT        NOT NULL,
    fecha_hora_inicio        TIMESTAMP,
    fecha_hora_fin           TIMESTAMP,
    nombre_proceso           VARCHAR(100),
    tabla_origen_stage        VARCHAR(100),
    tabla_destino_prod        VARCHAR(100),
    usuario_bd               VARCHAR(100),
    ip_maquina               VARCHAR(100),
    estado_ejecucion          VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (lote)
SORTKEY (lote);

CREATE TABLE IF NOT EXISTS rec_mtdat.log_td_detalle
(
    lote                           BIGINT        NOT NULL,
    fecha_hora                      TIMESTAMP,
    nombre_proceso                  VARCHAR(100),
    cadena                         VARCHAR(65535), -- SQL ejecutado (rec_mtdat.sp_execstring_des)
    paso                           VARCHAR(500),   -- descripcion del paso (4o parametro de SP_EXECSTRING_DES)
    descripcion_teradata_error        VARCHAR(1000)  -- 'Finalizo Exitosamente' = OK; cualquier otro valor = fallo
)
DISTSTYLE KEY
DISTKEY (lote)
SORTKEY (lote);

-- -----------------------------------------------------------------------
-- rec_stage.batch2_shells_planejecucion: plan de pasos a ejecutar para una
-- solicitud. Estructura REAL (2026-10-14): es la del CREATE de la fila
-- ID=11 de PRO_PLAN_EJECUCION (Dlls-Batch/Dll_Btach2.csv). El motor
-- sp_batch2_plan_ejecucion_shell la BORRA y la vuelve a crear en cada
-- corrida (filas ID 10 y 11 de Redshift/datos/01_catalogos_motor.sql), por
-- lo que esta definicion y la de esa fila deben ser iguales.
-- SET TABLE en Teradata: sin efecto practico (ORDEN_ID es un correlativo).
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch2_shells_planejecucion
(
    orden_id               INTEGER,
    id_solicitud           BIGINT,
    id_plantilla           BIGINT,
    nombre_seccion         VARCHAR(100),   -- 'CON DATOS DE UBICACION' | 'INCONSISTENCIAS' | 'X' (paso sin iteracion)
    nombre_shell           VARCHAR(500),   -- ej. 'P0033_BATCH2_EXPORTPLANO'
    estado_ejecutado       CHAR(1),
    lote                   BIGINT,
    fecha_hora_inicio      TIMESTAMP,
    fecha_hora_fin         TIMESTAMP,
    estado_ejecucion       VARCHAR(100),   -- 'Pendiente' al crear el plan
    log_archivo            VARCHAR(200),
    actualiza_solicitud    CHAR(1),
    actualiza_plantilla    CHAR(1),
    actualiza_ruta_salida  CHAR(1)
)
DISTSTYLE ALL
SORTKEY (orden_id);

-- -----------------------------------------------------------------------
-- rec_stage.batch2_homologacion: catalogo que mapea codigo_campo/grupo_campo
-- a nombre fisico de columna, cubo de origen (xalias) y orden de salida.
-- Es la base de la vista v_ba2_campos_salida usada en EXPORTPLANO/CUBOEXPORT.
-- -----------------------------------------------------------------------
-- Columnas id_sequencia y homologado confirmadas en Sps_Batch.sql
-- (PRO_BATCH2_FILTRO_D/G/H, PRO_BATCH2_HOMOLOGACIONES):
--   id_sequencia : orden del campo dentro del cubo
--   homologado   : nombre FISICO de la columna en la tabla cubo
--   cubo         : 'Celular' | 'Ciiu' | 'Correo' | 'Direccion' | 'Persona' |
--                  'Telefono' | 'PuntoInteres' (los SP comparan sin
--                  distinguir mayusculas, igual que NOT CASESPECIFIC)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch2_homologacion
(
    id_sequencia      INTEGER,
    codigo_campo      VARCHAR(10),
    homologado        VARCHAR(100),
    grupo_campo       VARCHAR(100),   -- 'CUBO_TEL' | 'CUBO_CEL' | 'CUBO_DIR' | 'CUBO_EMAIL' | 'CUBO_CIIU' | 'CUBO_PT_INT' | 'CUBO_PERS'
    cubo             VARCHAR(50),
    xalias           VARCHAR(10),    -- 'CBTEL' | 'CBDIR' | 'CBCEL' | 'CBCOR' | 'CBCII' | 'CBPER' | 'CBPIC' | 'CBBAT'
    valor_ini         VARCHAR(100),   -- nombre de columna fisica cuando xalias='CBPER'
    campo_nuevo        VARCHAR(100),   -- nombre de columna de salida (p.ej. 'NUMERO_001')
    ordenamiento       INTEGER,
    descripcion_campo  VARCHAR(100)    -- 'Numero' | 'DIRECCION' | 'CORREO' ... (filas LOG 14-16 de BATCH_MOTOR_LOG, 2026-10-14)
)
DISTSTYLE ALL
SORTKEY (codigo_campo);

-- -----------------------------------------------------------------------
-- rec_datos.batch_historia_resultados: historico de personas ya entregadas
-- por solicitud (usado por ACTUALIZA_HISTORIA para la regla NO_ENTREGADO_X_MESES)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_datos.batch_historia_resultados
(
    id_solicitud          INTEGER,
    id_plantilla          INTEGER,
    cod_dw_persona_ubic     VARCHAR(50),
    fecha_ejecucion         DATE,
    id_buro_suscriptor      BIGINT
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud, fecha_ejecucion);

-- -----------------------------------------------------------------------
-- rec_datos.batch_estadisticas_pro: estadisticas por solicitud/plantilla
-- (poblada por PRO_BATCH2_ESTADISTICAS y PRO_BATCH2_ESTADISTICAS_CFG).
-- El orden de columnas importa: ESTADISTICAS hace INSERT sin lista de
-- columnas (id_solicitud, id_plantilla, identificador, valor1, valor2, conteo).
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_datos.batch_estadisticas_pro
(
    id_solicitud     BIGINT        NOT NULL,
    id_plantilla     BIGINT,
    identificador     VARCHAR(50),    -- 'GENERALES' | 'REP_DIR_100' | 'GENERO' | 'CIUDAD_DIR1' | ...
    valor1           VARCHAR(500),   -- 'CON_UBI' | 'SIN_UBI' | 'INCO' | ciudad | numero | correo ...
    valor2           VARCHAR(500),   -- direccion/numero en REP_*_100, ciudad en CIUDAD_DIR1, etc.
    conteo           BIGINT
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

-- -----------------------------------------------------------------------
-- rec_stage.batch_identificaciones_validas / _incons: resultado de la
-- validacion de identificacion (nombre vs Registraduria/DIAN, vigencia, etc.)
-- aplicada por el SP compilado PRO_BATCH2_ADICIONAR_INCON (ver placeholder).
-- batch_identificaciones_incons alimenta directamente vstg_INCONSIS_* y por
-- tanto el archivo INCONSISTENCIA_<id>_<timestamp>.CSV.
-- -----------------------------------------------------------------------
-- numero_id VARCHAR(20) (antes 15): mismo largo que batch_cubo_persona y
-- stg_insumo_batch_validacion. HOMOLOGACIONES y ADICIONAR_INCON escriben
-- CAST(CAST(numero_id AS BIGINT) AS VARCHAR(20)); en Redshift un valor mas
-- largo que la columna da error (Teradata truncaba). Ajustado 2026-10-13.
-- Nota: ambas tablas las carga P0037 (sh-BATCH-VFORNOM) desde
-- BATCH_VALFORM_ST4; ADICIONAR_INCON solo agrega filas 06/04 a _incons y
-- borra de _validas.
CREATE TABLE IF NOT EXISTS rec_stage.batch_identificaciones_validas
(
    id_solicitud     BIGINT        NOT NULL,
    id_plantilla     BIGINT,
    tipo_id          VARCHAR(5),
    numero_id        VARCHAR(20)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

CREATE TABLE IF NOT EXISTS rec_stage.batch_identificaciones_incons
(
    id_solicitud               BIGINT        NOT NULL,
    id_plantilla               BIGINT,
    tipo_id                    VARCHAR(5),
    numero_id                  VARCHAR(20),
    nombre_completo             VARCHAR(100),
    nombre_entidad              VARCHAR(100),
    fecha_expedicion            VARCHAR(20),
    ciudad_expedicion           VARCHAR(100),
    departamento_expedicion      VARCHAR(100),
    estado                     VARCHAR(100),
    causal                     VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);

-- -----------------------------------------------------------------------
-- rec_stage.batch_archivo_log: pares DATO/VALOR con metadatos operativos de
-- cada ejecucion (origen de BATCH_SOLICITUD_BATCH.ARCHIVO_LOG).
-- Segun PRO_BATCH2_ARCHIVO_LOG (Sps_Batch.sql) es un CATALOGO PRECARGADO:
-- el SP hace "UPDATE ... SET VALOR = NULL" y luego cada sentencia del motor
-- (BATCH_MOTOR_LOG, TIPO='LOG') actualiza el VALOR de un DATO. Las 18 filas
-- (ID, DATO) se cargan en Redshift/datos/01_catalogos_motor.sql (tomadas
-- de las filas del motor y confirmadas con Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG).
-- VSTG_BATCH_ESTADISTICAS_EXP usa ID=7 (REGISTROS LEIDOS) e ID=8
-- (REGISTROS GRABADOS).
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_archivo_log
(
    id      INTEGER       NOT NULL,
    dato    VARCHAR(100),
    valor   VARCHAR(1000)
)
DISTSTYLE ALL
SORTKEY (id);

-- -----------------------------------------------------------------------
-- rec_stage.batch2_cantidad_reporte_canal: resultado de PRO_BATCH2_CANTREPCANAL_CON
-- (ver placeholder) -- conteo de reportes por canal de contacto.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch2_cantidad_reporte_canal
(
    id_solicitud     BIGINT        NOT NULL,
    id_plantilla     BIGINT,
    canal            VARCHAR(20),    -- 'TELEFONO' | 'CELULAR' | 'DIRECCION' | 'CORREO'
    cantidad         INTEGER,
    p_cdatos_sdatos    VARCHAR(1)     -- '0' con datos | '1' sin datos
)
DISTSTYLE KEY
DISTKEY (id_solicitud)
SORTKEY (id_solicitud);
