-- HU SLCOPRBA-1820 | Subtarea SLCOPRBA-1823 (STRCT) - UNLOAD Calculo RECONOCER
-- ============================================================
-- 40_ddl_nov_config.sql  (Reconocer / Novedades hacia la cuenta Batch)
-- DDL + seed de la tabla de configuracion por ambiente del Exportador de
-- Novedades (UNLOAD de las 7 tablas de dominio a S3 + CTL final).
-- Objeto en bdm_datos; idempotente. UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
--
-- POR QUE UNA TABLA Y NO VALORES CABLEADOS EN EL SP:
--   Mismo patron que bdm_datos.geo_config (03_ddl_geo.sql): el bucket de
--   triggers y el rol de IAM del UNLOAD cambian por ambiente, y el SP NO debe
--   adivinarlos por current_database(). El SP (repo pgm) autodetecta el
--   ambiente por CURRENT_AWS_ACCOUNT y lee de aqui bucket/iam_role/prefijos.
--   El mismo artefacto versionado se despliega en los 4 ambientes y el filtro
--   por 'ambiente' se aplica en tiempo de consulta.
--
-- Estructura nombre->valor, reemplaza SSM. DISTSTYLE ALL: catalogo pequeno
-- replicado en cada nodo para joins baratos.
--
-- Cuentas AWS por ambiente:
--   DEV 647096294147 | QA 667397050561 | DEMO 453645298399 | PROD 696708350333
--
-- Destino del UNLOAD (por ambiente):
--   s3://<triggers_bucket>/<s3_base_prefix>/<run_id>/data/<tabla>/
--   s3://<triggers_bucket>/<s3_base_prefix>/<run_id>/7_tablas_finish000.json
--   con <triggers_bucket> = <amb>-<cuenta>-rcncr-ws5-triggers-reconocer-s3
--   y   <unload_iam_role> = arn:aws:iam::<cuenta>:role/BURoleFor-<amb>-<cuenta>-rcncr-ws5-redshift-unload
--
-- Parametros (una fila por (ambiente, parametro)):
--   aws_account_id   cuenta AWS del ambiente (autodeteccion: debe coincidir
--                    con CURRENT_AWS_ACCOUNT).
--   triggers_bucket  bucket de triggers de Reconocer.
--   unload_iam_role  ARN del rol que el cluster Reconocer asume para el UNLOAD.
--   s3_base_prefix   prefijo base de la corrida ('nov').
--   region           region de S3 para el UNLOAD.
-- ============================================================

-- ------------------------------------------------------------
-- bdm_datos.nov_config (Tabla_Config Novedades) - PERMANENTE
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.nov_config (
  ambiente    VARCHAR(10)   NOT NULL,   -- DEV | QA | DEMO | PROD
  parametro   VARCHAR(60)   NOT NULL,
  valor       VARCHAR(500)  NOT NULL
)
DISTSTYLE ALL
SORTKEY (ambiente, parametro);

-- ------------------------------------------------------------
-- NOTA Redshift: NO se crea FUNCTION nov_get_config. Las SQL UDFs de Redshift
-- no admiten SELECT ... FROM (error 0A000). Los SP (_pgm) leen esta tabla con
-- SELECT ... INTO, igual que con geo_config.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Seed idempotente por REEMPLAZO: se borran los parametros que este script
-- administra y se vuelven a insertar. Asi un re-despliegue actualiza valores
-- (p.ej. el cambio del bucket/rol GEO de prueba al de triggers) sin depender
-- de que la tabla se recree. El DELETE lleva WHERE explicito (REDSHIFT:232).
-- Incluye las etiquetas antiguas (UAT/TEST) para limpiar despliegues previos.
-- ------------------------------------------------------------
DELETE FROM bdm_datos.nov_config
WHERE ambiente IN ('DEV', 'QA', 'DEMO', 'PROD', 'UAT', 'TEST')
  AND parametro IN ('aws_account_id', 'triggers_bucket', 'unload_iam_role', 's3_base_prefix', 'region');

INSERT INTO bdm_datos.nov_config (ambiente, parametro, valor)
SELECT v.ambiente, v.parametro, v.valor
FROM (
  -- DEV (cuenta 647096294147)
  SELECT 'DEV' AS ambiente, 'aws_account_id' AS parametro, '647096294147'                                                            AS valor UNION ALL
  SELECT 'DEV',  'triggers_bucket', 'dev-647096294147-rcncr-ws5-triggers-reconocer-s3'                                                          UNION ALL
  SELECT 'DEV',  'unload_iam_role', 'arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-unload'                       UNION ALL
  SELECT 'DEV',  's3_base_prefix',  'nov'                                                                                                       UNION ALL
  SELECT 'DEV',  'region',          'us-east-1'                                                                                                 UNION ALL

  -- QA (cuenta 667397050561)
  SELECT 'QA',   'aws_account_id',  '667397050561'                                                                                             UNION ALL
  SELECT 'QA',   'triggers_bucket', 'qa-667397050561-rcncr-ws5-triggers-reconocer-s3'                                                           UNION ALL
  SELECT 'QA',   'unload_iam_role', 'arn:aws:iam::667397050561:role/BURoleFor-qa-667397050561-rcncr-ws5-redshift-unload'                        UNION ALL
  SELECT 'QA',   's3_base_prefix',  'nov'                                                                                                       UNION ALL
  SELECT 'QA',   'region',          'us-east-1'                                                                                                 UNION ALL

  -- DEMO (cuenta 453645298399)
  -- OJO AL TOKEN: la cuenta se llama DEMO en Jenkins, 'uat' en el alias de AWS y
  -- 'stg' en todo lo que crea la IaC. MEDIDO en la salida del apply de
  -- COAWSPPR/tf_rcncr_linea_ws5_infra, job DEMO/TERRAFORM #7274 (2026-11-23,
  -- 135 added): "redshift_unload" = BURoleFor-stg-453645298399-...-redshift-unload
  -- y s3_triggers_bucket = stg-453645298399-rcncr-ws5-triggers-reconocer-s3.
  -- El token NO se deduce del nombre del ambiente ni del de otro recurso: se mide
  -- por cuenta. Aqui decia 'demo' en los dos y ninguno de los dos objetos existe.
  SELECT 'DEMO', 'aws_account_id',  '453645298399'                                                                                             UNION ALL
  SELECT 'DEMO', 'triggers_bucket', 'stg-453645298399-rcncr-ws5-triggers-reconocer-s3'                                                          UNION ALL
  SELECT 'DEMO', 'unload_iam_role', 'arn:aws:iam::453645298399:role/BURoleFor-stg-453645298399-rcncr-ws5-redshift-unload'                       UNION ALL
  SELECT 'DEMO', 's3_base_prefix',  'nov'                                                                                                       UNION ALL
  SELECT 'DEMO', 'region',          'us-east-1'                                                                                                 UNION ALL

  -- PROD (cuenta 696708350333)
  SELECT 'PROD', 'aws_account_id',  '696708350333'                                                                                             UNION ALL
  SELECT 'PROD', 'triggers_bucket', 'prod-696708350333-rcncr-ws5-triggers-reconocer-s3'                                                         UNION ALL
  SELECT 'PROD', 'unload_iam_role', 'arn:aws:iam::696708350333:role/BURoleFor-prod-696708350333-rcncr-ws5-redshift-unload'                      UNION ALL
  SELECT 'PROD', 's3_base_prefix',  'nov'                                                                                                       UNION ALL
  SELECT 'PROD', 'region',          'us-east-1'
) v;
