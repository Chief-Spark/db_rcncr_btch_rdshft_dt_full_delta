-- DDL de las SIETE tablas dominio REALES (bdm_datos), extraido del paquete strct
-- Paquete: deploy/redshift/SLCOPRBA-1353/SQL -- solo las reales, sin los espejos _mock

-- ============================================================
-- mat_info_ubicacion  (45 columnas)  -- fuente: 30_ddl_novedades.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_ubicacion (
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),
  numero_identificacion           BIGINT,
  id                              BIGINT,
  orden                           INTEGER,
  indicativo                      VARCHAR(20),
  dato                            VARCHAR(201),
  estrato                         VARCHAR(10),
  tipo                            VARCHAR(30),
  zona                            VARCHAR(30),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  longitud                        DECIMAL(10,6),
  latitud                         DECIMAL(10,6),
  reportado_desde                 DATE,
  ultimo_reporte                  DATE,
  fuente                          INTEGER,
  numero_reportes                 INTEGER,
  numero_entidades                INTEGER,
  barrio                          VARCHAR(100),
  localidad                       VARCHAR(100),
  codigo_postal                   VARCHAR(20),
  clase                           VARCHAR(5),
  info_basica                     BIGINT,
  codigo_dane                     VARCHAR(20),
  es_tipo_crr                     VARCHAR(1),
  es_tipo_res                     VARCHAR(1),
  es_tipo_ppl                     VARCHAR(1),
  es_tipo_agn                     VARCHAR(1),
  es_tipo_suc                     VARCHAR(1),
  es_tipo_est                     VARCHAR(1),
  es_tipo_cdi                     VARCHAR(1),
  es_tipo_lab                     VARCHAR(1),
  tipo_cuenta                     VARCHAR(1),
  cod_dw_ubic                     BIGINT,
  cod_dw_direccion_fisica         BIGINT,
  cod_dw_telefono                 BIGINT,
  cod_dw_direccion_electronica    BIGINT,
  ind_unificacion                 INTEGER,
  cod_dw_tipo_ubicacion_dir       INTEGER,
  cod_pin_persona                 BIGINT,
  flag_op                         SMALLINT,     -- 1 = I, 2 = A, 3 = E
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);

-- ============================================================
-- mat_info_actividad_economica  (11 columnas)  -- fuente: 34_ddl_nov_actividad_economica.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_actividad_economica (
  id                      INTEGER,
  ciiu                    VARCHAR(20),
  actividad_economica     VARCHAR(500),
  version                 INTEGER,
  fecha_reporte           DATE,
  info_basica_id          BIGINT,
  tipo_identificacion     VARCHAR(30),
  numero_identificacion   BIGINT,
  lote                    INTEGER,
  fecha_actualizacion     TIMESTAMP DEFAULT GETDATE(),
  usuario_bd              VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id);

-- ============================================================
-- mat_ubicacion_agregada  (32 columnas)  -- fuente: 35_ddl_nov_ubi_agregada.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_ubicacion_agregada (
  tipo_identificacion             VARCHAR(30),    -- SI se puebla desde el 2026-10-21 (llego el catalogo)
  numero_identificacion           BIGINT,
  info_basica                     BIGINT,         -- id_buro_persona; BIGINT, ver cabecera
  codigo_dane                     VARCHAR(20),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  ubicacion_dato                  VARCHAR(201),
  ubicacion_reportdesde           DATE,           -- SI se puebla: viene de la etapa 2
  ubicacion_ultreporte            DATE,           -- SI se puebla: viene de la etapa 2
  ubicacion_numentidades          INTEGER,        -- SI se puebla: viene de la etapa 2
  ubicacion_numreportes           INTEGER,        -- SI se puebla: viene de la etapa 2
  ubicacion_clase                 VARCHAR(5),
  ubicacion_tipocuenta            VARCHAR(1),     -- BLOQUEADA: falta V_TIPO_CORREO
  ubicacion_orden                 INTEGER,
  ubicacion_indicativo            VARCHAR(20),    -- BLOQUEADA: falta V_TELEFONO_FIJO
  ubicacion_estrato               VARCHAR(10),    -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_zona                  VARCHAR(30),    -- BLOQUEADA: falta V_ZONA_UBICACION
  ubicacion_ciudad                VARCHAR(30),
  ubicacion_departamento          VARCHAR(30),
  ubicacion_codigodane            VARCHAR(20),
  ubicacion_barrio                VARCHAR(100),   -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_localidad             VARCHAR(100),   -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_codigopostal          VARCHAR(20),    -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_longitud              DECIMAL(10,6),
  ubicacion_latitud               DECIMAL(10,6),
  tipo                            VARCHAR(30),    -- cadena agregada: 'R - L - C'
  fuente                          VARCHAR(30),    -- cadena agregada: 'SUS - CAM'
  id                              VARCHAR(1000),  -- lista de cod_dw_ubic separada por comas
  cod_pais                        VARCHAR(3),     -- BLOQUEADA: falta V_PAIS
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica)
SORTKEY (info_basica, ubicacion_dato);

-- ============================================================
-- mat_info_contactabilidad  (15 columnas)  -- fuente: 36_ddl_nov_contactabilidad.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_contactabilidad (
  id                              BIGINT,         -- NULL: es COD_DW_CONTACTABILIDAD, la llave del evento de gestion
  contactabilidad                 VARCHAR(2),     -- NULL: necesita V_CONTACTO_EFECTIVO y el indicador de efectividad
  fecha_ultimo_contacto           TIMESTAMP,      -- SI se puebla, con OTRA semantica: ContactEventLastUpdated
  fecha_gestion                   TIMESTAMP,      -- NULL: no hay eventos de gestion
  mejor_dia_gestion               VARCHAR(10),    -- NULL: se deriva de fecha_gestion
  mejor_hora_gestion              VARCHAR(20),    -- NULL: pide hora del dia, que EDF no trae
  reportado_por                   INTEGER,        -- SI se puebla, con OTRA semantica: quien REPORTO, no quien gestiono
  sector                          VARCHAR(100),   -- NULL: falta V_PERSONA_CLASE_BURO y v_clase_buro
  ubicacion_id                    BIGINT,         -- SI se puebla: cod_dw_persona_ubic
  peso                            BIGINT,         -- NULL: es COUNT(*) de eventos de gestion
  mejor_resultado_3meses          VARCHAR(100),   -- NULL: codigo GESTION de la ventana de 3 meses
  mejor_resultado_6meses          VARCHAR(100),   -- NULL: idem, 6 meses
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id);

-- ============================================================
-- mat_info_basica  (25 columnas)  -- fuente: 37_ddl_nov_info_basica.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_basica (
  id                              BIGINT,         -- id_buro_persona. BIGINT y no INTEGER: D-NOV-04
  primer_nombre                   VARCHAR(100),
  segundo_nombre                  VARCHAR(100),
  primer_apellido                 VARCHAR(100),
  segundo_apellido                VARCHAR(100),
  nombre_completo                 VARCHAR(200),
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),    -- NULL: falta V_Hom_Tip_Ident_Linea (C37)
  numero_identificacion           BIGINT,
  estado_documento                VARCHAR(20),    -- businessidstatus con LPAD a 2 (D-EDF-13)
  rango_edad                      VARCHAR(25),
  lugar_expedicion                VARCHAR(100),
  fecha_expedicion                DATE,
  genero                          VARCHAR(508),   -- M | F | O | vacio (D-EDF-14). Ancho del contrato
  ciiu                            VARCHAR(20),
  actividad_economica             VARCHAR(500),
  razon_social                    VARCHAR(500),   -- derivada: fullname cuando el tipo es NIT
  pagina_web                      VARCHAR(100),   -- NULL: NO EXISTE EN EDF (CCBR 251264543)
  mosaic_id                       INTEGER,        -- NULL: Mosaic fuera por decision legal (D-NOV-07)
  departamento_expedicion         VARCHAR(100),
  cod_pin_persona                 BIGINT,         -- BIGINT y no INTEGER: D-NOV-04
  rut                             VARCHAR(1),
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);

-- ============================================================
-- mat_info_punto_interes  (13 columnas)  -- fuente: 38_ddl_nov_punto_interes.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_punto_interes (
  id                               BIGINT,         -- derivada: FNV_HASH de la llave 1:N
  nombre                           VARCHAR(200),
  distancia                        INTEGER,        -- metros
  descripcion_tipo_punto_interes   VARCHAR(1000),  -- valor CRUDO: falta V_TIPO_PUNTO_INTERES
  ubicacion_id                     BIGINT,         -- cod_dw_ubic, NO la relacion persona-ubicacion
  nombre_entidad                   VARCHAR(1000),  -- NULL: falta RELACION_PUNTO_INTERES_X_PERS
  nit_entidad                      VARCHAR(20),    -- NULL: idem
  latitud                          VARCHAR(40),    -- del PUNTO DE INTERES. VARCHAR por el contrato
  longitud                         VARCHAR(40),    -- idem
  tipo                             VARCHAR(30),    -- codigo Linea (catalogo de homologacion)
  lote                             INTEGER,
  fecha_actualizacion              TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                       VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id, id);

-- ============================================================
-- mat_info_movilidad  (11 columnas)  -- fuente: 39_ddl_nov_movilidad.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_movilidad (
  id                     BIGINT,         -- derivada: FNV_HASH(persona|indicador|fecha)
  fecha                  DATE,           -- cuando se detecto el cambio
  descripcion            VARCHAR(100),   -- la FRASE larga del indicador (catalogo)
  novedad                VARCHAR(1000),  -- 'Cambio de Direccion' | 'de Ciudad' | 'de Estrato'
  info_basica_id         BIGINT,         -- id_buro_persona
  novedad_2              VARCHAR(30),    -- codigo Linea: CAM_LOC | CAM_CIU | CAM_EST
  tipo_identificacion    VARCHAR(30),
  numero_identificacion  BIGINT,
  lote                   INTEGER,
  fecha_actualizacion    TIMESTAMP DEFAULT GETDATE(),
  usuario_bd             VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id, novedad);

