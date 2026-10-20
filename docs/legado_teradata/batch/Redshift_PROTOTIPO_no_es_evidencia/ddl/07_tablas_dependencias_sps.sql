-- ============================================================================
-- Script:      07_tablas_dependencias_sps.sql
-- Objetivo:    Tablas que aparecen como dependencia en el codigo fuente real
--              de los SP Teradata (Sps_Batch.sql) y que no estaban en el
--              DDL.sql original ni en los scripts 02..06.
--              Estructura MINIMA inferida: solo las columnas que los SP
--              referencian. Los tipos son inferidos.
-- ============================================================================

-- -----------------------------------------------------------------------
-- rec_stage.batch_motor_log: "motor" de SQL guardado como datos.
-- Consumido por:
--   PRO_BATCH2_FILTRO_C            (TIPO = 'FILTRO-C')
--   PRO_BATCH2_ARCHIVO_LOG         (TIPO = 'LOG')
--   PRO_BATCH2_CANTREPCANAL_CON    (TIPO = 'CANT_REP_CANAL_CONTACTO')
-- SQL_STRING contiene sentencias con marcadores que el SP reemplaza
-- (P_BDSTAGE, P_ID_SOLICITUD, P_ID_PLANTILLA, P_BDDATOS, P_BDVISTA,
--  P_BTTVISTA, P_StartTimeStampPadre, P_ARCHIVOPRN, P_MAQUINA, P_RUTA,
--  P_FEINICIO, P_NOMBRE_SECCION, P_CDATOS_SDATOS).
--
-- Estructura Teradata confirmada (Dlls-Batch/Dll_Btach.csv): ID INTEGER,
-- TIPO VARCHAR(100), DATO VARCHAR(100), SQL_STRING VARCHAR(3200),
-- UNIQUE PRIMARY INDEX (ID, TIPO).
-- FILAS: las 18 de TIPO='LOG' ya estan reescritas a Redshift en
-- Redshift/datos/01_catalogos_motor.sql. Siguen FALTANDO las de
-- TIPO='FILTRO-C' y 'CANT_REP_CANAL_CONTACTO' (no venian en el insumo).
-- El SP Redshift ejecuta el texto tal cual despues de reemplazar los
-- marcadores, por lo que cada SQL_STRING debe estar en sintaxis Redshift.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_motor_log
(
    id           INTEGER        NOT NULL,
    tipo         VARCHAR(100),
    dato         VARCHAR(100),
    sql_string   VARCHAR(65535)
)
DISTSTYLE ALL
SORTKEY (tipo, id);

-- -----------------------------------------------------------------------
-- rec_stage.pro_plan_ejecucion: motor de PRO_BATCH2_PLAN_EJECUCION_SHELL.
-- Cada fila (PARTE, CAMPO, SQL_VALOR) es una sentencia que puebla/arma
-- REC_STAGE.BATCH2_SHELLS_PLANEJECUCION. CAMPO = nombre de la tabla que
-- crea la sentencia (si es CREATE), para hacer DROP previo.
-- Marcadores: P_StartTimeStampPadre, P_ID_SOLICITUD.
-- Estructura Teradata confirmada (Dlls-Batch/Dll_Btach2.csv): ID INTEGER,
-- PARTE VARCHAR(200), CAMPO VARCHAR(200), SQL_VALOR VARCHAR(2000),
-- PRIMARY INDEX (ID, PARTE).
-- FILAS: las 12 de PARTE='ITERADOR' estan reescritas a Redshift en
-- Redshift/datos/01_catalogos_motor.sql.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.pro_plan_ejecucion
(
    id          INTEGER        NOT NULL,
    parte       VARCHAR(200),
    campo       VARCHAR(200),
    sql_valor   VARCHAR(65535)
)
DISTSTYLE ALL
SORTKEY (parte, id);

-- -----------------------------------------------------------------------
-- rec_stage.batch2_shells_config: catalogo de shells (pasos) de los
-- procesos Batch1 (P0032), Batch2 (P0033) y Batch4 (P0034) con su orden y
-- banderas. Lo leen y actualizan las filas ITERADOR de PRO_PLAN_EJECUCION
-- (ESTADO segun la orientacion pedida y la subseccion 'VALIDACION'), y de
-- el sale el plan BATCH2_SHELLS_PLANEJECUCION.
-- Columnas inferidas de las sentencias de PRO_PLAN_EJECUCION (la tabla real
-- puede tener mas). ESTADO / ITERACION / ACTUALIZA_* = 'S' | 'N'.
-- ACCION REQUERIDA: migrar las FILAS desde Teradata
--   SELECT * FROM REC_STAGE.BATCH2_SHELLS_CONFIG ORDER BY ORDEN_ID, ORDEN_IDLL, ORDEN_IDLLL;
-- Sin filas, el plan de ejecucion queda vacio (no falla).
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch2_shells_config
(
    orden_id               INTEGER,
    orden_idll             INTEGER,
    orden_idlll            INTEGER,
    nombre_shell           VARCHAR(500),
    estado                 CHAR(1),
    iteracion              CHAR(1),     -- 'S': un paso por seccion de BATCH_SALIDAS_CAMPOS
    actualiza_estado       CHAR(1),
    actualiza_solicitud    CHAR(1),
    actualiza_plantilla    CHAR(1),
    actualiza_ruta_salida  CHAR(1)
)
DISTSTYLE ALL;

-- -----------------------------------------------------------------------
-- rec_stage.stg_insumo_batch_validacion: insumo del suscriptor (Batch4 /
-- validacion) estandarizado. Usado por FILTRO_F (similitud insumo vs cubo)
-- y PRO_BATCH_ADD_PORC_INSUMO (devuelve % similitud y orden).
-- Solo columnas referenciadas por los SP; la tabla real tiene mas.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.stg_insumo_batch_validacion
(
    id_buro_persona           BIGINT,
    tipo_id                   VARCHAR(5),
    numero_id                 VARCHAR(20),
    dir_insumo_std_000        VARCHAR(200),
    tel_insumo_std_000        VARCHAR(30),
    cel_insumo_std_000        VARCHAR(30),
    email_insumo_std_000      VARCHAR(200),
    por_sim_dir_000           INTEGER,
    orden_prioridad_dir_000   INTEGER,
    por_sim_tel_000           INTEGER,
    orden_prioridad_tel_000   INTEGER,
    por_sim_cel_000           INTEGER,
    orden_prioridad_cel_000   INTEGER,
    por_sim_mail_000          INTEGER,
    orden_prioridad_mail_000  INTEGER
)
DISTSTYLE KEY
DISTKEY (id_buro_persona);

-- -----------------------------------------------------------------------
-- rec_datos.pro_batch2_filtros_estadisticas: catalogo con dos usos:
--   1. PRO_BATCH2_ESTADISTICAS: criterios (CAMPO='CAUSAL'|'ESTADO',
--      CRITERIO = codigo, IDENTIFICADOR/VALOR1 = fila destino en
--      BATCH_ESTADISTICAS_PRO).
--   2. PRO_BATCH2_ESTADISTICAS_CFG (motor, Dlls-Batch/Dll_Btach.csv):
--      filas de una PARTE ('SQL-PARAM', 'ESTADISTICAS', 'TMP_ESTADISTICAS',
--      'GENERO', 'CIIU', ...) ordenadas por ORDEN; CRITERIO contiene una
--      sentencia SQL y CAMPO el nombre de la tabla que crea (si es CREATE).
-- Por eso CRITERIO se declara VARCHAR(65535) (el SP lo leia como
-- VARCHAR(33000)) y se agregan PARTE y ORDEN. Estructura real no recibida.
-- ACCION REQUERIDA: migrar filas desde Teradata y reescribir a Redshift las
-- que son SQL:
--   SELECT * FROM REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS ORDER BY PARTE, ORDEN;
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_datos.pro_batch2_filtros_estadisticas
(
    parte          VARCHAR(100),
    orden          INTEGER,
    campo          VARCHAR(100),
    criterio       VARCHAR(65535),
    identificador  VARCHAR(50),
    valor1         VARCHAR(100)
)
DISTSTYLE ALL;

-- -----------------------------------------------------------------------
-- rec_vista.tipo_identificacion: equivalente a BDM_VISTA.V_TIPO_IDENTIFICACION
-- (usado en ESTADISTICAS para el conteo 'PROC').
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_vista.tipo_identificacion
(
    cod_tipo_ident_fte  VARCHAR(5)   NOT NULL,
    nombre_tipo_ident   VARCHAR(100)          -- 'Cedula de Ciudadania' | 'Nit Juridicos' | 'Nit de Extranjeria' | 'Cedula de Extranjeria' | ...
)
DISTSTYLE ALL;

-- -----------------------------------------------------------------------
-- rec_stage.secuencia: secuenciador 1..N (REC_STAGE.Secuencia en Teradata),
-- usado por CUBOEXPORT y Completitud_Canal.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.secuencia
(
    secuencia  INTEGER NOT NULL
)
DISTSTYLE ALL
SORTKEY (secuencia);

-- Carga 1..100 (generate_series no sirve para INSERT en Redshift: es solo del leader node).
INSERT INTO rec_stage.secuencia (secuencia)
SELECT a.d * 10 + b.d + 1
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN
     (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
WHERE NOT EXISTS (SELECT 1 FROM rec_stage.secuencia);

-- -----------------------------------------------------------------------
-- Tablas del proceso hermano P0037 (VFORNOM) que ESTADISTICAS lee:
--   batch_valform_st2 : base de entrada cargada (conteo BASE_EN)
--   batch_valform_st4 : base validada (Val_Dupe = 0 -> duplicados, BASE_DUP)
-- Son PROPIEDAD de P0037; se declaran aqui solo con las columnas que lee
-- BATCH2, con IF NOT EXISTS para no pisar la definicion real si ya existe.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.batch_valform_st2
(
    id_solicitud  BIGINT,
    id_plantilla  BIGINT,
    registro      VARCHAR(65535)
);

CREATE TABLE IF NOT EXISTS rec_stage.batch_valform_st4
(
    id_solicitud  BIGINT,
    id_plantilla  BIGINT,
    tipo_id       VARCHAR(5),
    numero_id     VARCHAR(20),
    val_dupe      INTEGER
);

-- -----------------------------------------------------------------------
-- rec_stage.vstgbatchcargaubicestandarizada: migrada el 2026-10-14 en
--   ddl/09_vistas_dependencias_sps.sql (vista late-binding sobre las tablas
--   de P0034, que siguen siendo dependencia externa).
--
-- DEPENDENCIA EXTERNA NO CREADA AQUI:
--   rec_vista.vu_persona (<BDVISTA>.VU_PERSONA) y rec_vista.v_tipo_persona
--   (BDM_VISTA.V_TIPO_PERSONA): vistas del DW que usa PRO_BATCH2_FILTRO_E para
--   saber que tipos de identificacion son persona natural ('N') o juridica
--   ('J'). Columnas usadas: vu_persona.cod_tipo_ident_fte,
--   vu_persona.cod_dw_tipo_persona, v_tipo_persona.cod_dw_tipo_persona,
--   v_tipo_persona.nombre_tipo_persona. Obtener con SHOW VIEW en Teradata.
--
--   rec_stage.batch_cubo_temp_dir_total / _telefono_total / _celular_total /
--   _correo_total: las crea PRO_BATCH2_ESTADISTICAS_CFG (modo 'TMP_ESTADISTICAS').
--   El SP ya esta migrado (procedures/09b), pero el SQL que crea esas tablas
--   esta en las filas de rec_datos.pro_batch2_filtros_estadisticas, que
--   siguen sin recibirse.
--
--   Vistas/tablas del DW que leen las filas TIPO='LOG' de BATCH_MOTOR_LOG
--   (Redshift/datos/01_catalogos_motor.sql):
--     rec_vista.v_evento_entrega_dato (cod_dw_entrega_dato, id_buro_proveedor_dato),
--     rec_vista.v_cod_entrega_dato    (cod_dw_entrega_dato, cod_entrega_dato_fte),
--     rec_stage.vstg_buropers_tmp     (cod_tipo_ident_fte, num_ident, id_buro_persona).
--   Sin ellas fallan las sentencias ID 6 y 13 (CODIGO SUSCRIPTOR).
-- -----------------------------------------------------------------------
