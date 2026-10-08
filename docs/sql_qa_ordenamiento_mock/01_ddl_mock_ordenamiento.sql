-- ============================================================
-- 01_ddl_mock_ordenamiento.sql
-- Tablas lab en bdm_stage para suite Ordenamiento MOCK
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

DROP TABLE IF EXISTS bdm_stage.mock_ord_score;
DROP TABLE IF EXISTS bdm_stage.mock_ord_prioridad;
DROP TABLE IF EXISTS bdm_stage.mock_ord_rpu;
DROP TABLE IF EXISTS bdm_stage.mock_ord_escenario;
DROP TABLE IF EXISTS bdm_stage.mock_ord_ca_result;

CREATE TABLE bdm_stage.mock_ord_escenario (
  id_buro_persona   BIGINT       NOT NULL,
  cod_escenario     VARCHAR(32)  NOT NULL,
  criterio_ca       VARCHAR(16)  NOT NULL,
  descripcion       VARCHAR(256),
  es_html_ejemplo   SMALLINT     DEFAULT 1
);

CREATE TABLE bdm_stage.mock_ord_rpu (
  id_buro_persona      BIGINT   NOT NULL,
  cod_pin_persona      BIGINT,
  cod_dw_persona_ubic  BIGINT   NOT NULL,
  ind_unificacion      INTEGER,          -- 1 = hija
  etiqueta             VARCHAR(64)       -- casa / oficina / hija …
);

CREATE TABLE bdm_stage.mock_ord_score (
  id_buro_persona      BIGINT         NOT NULL,
  cod_dw_persona_ubic  BIGINT         NOT NULL,
  cod_pin_persona      BIGINT,
  canal                VARCHAR(10)    NOT NULL,
  score                DECIMAL(18,4)  NOT NULL,
  lugar                INTEGER        NOT NULL,
  nota                 VARCHAR(128)
);

CREATE TABLE bdm_stage.mock_ord_prioridad (
  id_buro_persona      BIGINT   NOT NULL,
  cod_dw_persona_ubic  BIGINT   NOT NULL,
  orden_prioridad      INTEGER  NOT NULL
);

CREATE TABLE bdm_stage.mock_ord_ca_result (
  criterio_ca   VARCHAR(16)  NOT NULL,
  estado        VARCHAR(16)  NOT NULL,  -- PASSED / FAILED
  detalle       VARCHAR(512),
  fecha_check   TIMESTAMP    DEFAULT GETDATE()
);

SELECT 'DDL_MOCK_ORD_OK' AS paso, COUNT(*)::BIGINT AS tablas
FROM information_schema.tables
WHERE table_schema = 'bdm_stage'
  AND table_name LIKE 'mock_ord_%';
