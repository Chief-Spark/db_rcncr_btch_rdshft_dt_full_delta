-- ============================================================================
-- Reconocer - PRODUCCION
-- Datashare ds_dba_rncr_batch, esquemas propios, rol propietario y permisos.
--
-- Adjunto de la subtarea del CHG. Sustento y citas de cada dato en
-- dt/docs/PETICION_DATASHARE_PROD_SERVICENOW.md
--
-- UTF-8 sin BOM. ASCII sin acentos, a proposito.
--
-- COMO SE USA: los bloques 1 y 2 corren en el cluster PRODUCTOR (EDF); los
-- bloques 3 a 6 en el cluster CONSUMIDOR de Reconocer. NO ejecutar el archivo
-- entero de una vez: cada bloque dice donde corre y que espera del anterior.
--
-- SEIS VALORES ENTRE < > HAY QUE REEMPLAZARLOS ANTES DE EJECUTAR. Estan
-- listados abajo y no se inventan aqui a proposito.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DATOS CONFIRMADOS (no se cambian)
--   Base consumidora ............ dba_rncr_batch
--   Cuenta AWS Reconocer PDN .... 696708350333
--   Datashare ................... ds_dba_rncr_batch
--   Esquema del productor ....... edf_views
--   Usuario de ejecucion ........ user_sp
--   Esquemas propios ............ bdm_datos, bdm_tempo, bdm_stage
--   Region ...................... us-east-1
--
-- AVISO: la cuenta 324037294240 NO es la de Reconocer, es la del Framework
-- Batch en produccion. Las dos conviven en la misma configuracion.
--
-- DATOS QUE FALTAN (reemplazar antes de ejecutar)
--   <cuenta-productor-EDF> ...... cuenta AWS del cluster productor de EDF
--   <namespace-productor-EDF> ... GUID del namespace productor de EDF
--   <usuario_despliegue> ........ usuario con el que se despliega el paquete
-- ----------------------------------------------------------------------------


-- ============================================================================
-- BLOQUE 1 - CLUSTER PRODUCTOR (EDF)
-- Crea el datashare con las NUEVE relaciones que el paquete consume, ni una mas.
-- ============================================================================

CREATE DATASHARE ds_dba_rncr_batch;

ALTER DATASHARE ds_dba_rncr_batch ADD SCHEMA edf_views;

ALTER DATASHARE ds_dba_rncr_batch ADD TABLE
  edf_views.xpm,
  edf_views.xpm_location,
  edf_views.xpm_location_val_contactinformations,
  edf_views.xpm_counterparties,
  edf_views.xpm_personalinformation,
  edf_views.xpm_chamberofcommerce,
  edf_views.xpm_bestidentifications,
  edf_views.xpm_bestaccounts,
  edf_views.xpm_bestaccounts_val_frequentbehaviour;

-- Cross-account: el consumidor esta en otra cuenta.
GRANT USAGE ON DATASHARE ds_dba_rncr_batch TO ACCOUNT '696708350333';

-- Comprobacion en el productor: deben salir las nueve relaciones.
SHOW DATASHARES LIKE 'ds_dba_rncr_batch';


-- ============================================================================
-- BLOQUE 2 - ASOCIACION (consola de Redshift o AWS CLI, no es SQL)
-- El administrador de la cuenta 696708350333 asocia el datashare. Sin esta
-- asociacion el BLOQUE 3 falla.
--
--   aws redshift associate-data-share-consumer \
--     --data-share-arn <arn-del-datashare> \
--     --consumer-arn   <arn-del-namespace-consumidor> \
--     --region us-east-1
-- ============================================================================


-- ============================================================================
-- BLOQUE 3 - CLUSTER CONSUMIDOR: crear la base desde el datashare
-- ============================================================================

CREATE DATABASE ds_dba_rncr_batch
  FROM DATASHARE ds_dba_rncr_batch
  OF ACCOUNT '<cuenta-productor-EDF>'
  NAMESPACE '<namespace-productor-EDF>';


-- ============================================================================
-- BLOQUE 4 - CLUSTER CONSUMIDOR: rol propietario y esquemas
--
-- EL ROL VA PRIMERO Y ESTO NO ES COSMETICO: el rol tiene que existir ANTES de
-- desplegar el paquete, porque los objetos quedan a nombre de quien los crea y
-- en Redshift TRUNCATE exige ser DUENO del objeto. Veintisiete procedimientos
-- de la via real truncan, y ninguno de los 116 se declara SECURITY DEFINER.
--
-- SI ALGUNO DE LOS TRES ESQUEMAS YA EXISTE con objetos de otros equipos, NO se
-- recrea ni se le cambia el dueno: en ese caso se va por permisos explicitos
-- del BLOQUE 5 y se deja constancia en la tarea.
-- ============================================================================

CREATE ROLE rol_rcncr_batch;

CREATE SCHEMA IF NOT EXISTS bdm_datos AUTHORIZATION ROLE rol_rcncr_batch;
CREATE SCHEMA IF NOT EXISTS bdm_tempo AUTHORIZATION ROLE rol_rcncr_batch;
CREATE SCHEMA IF NOT EXISTS bdm_stage AUTHORIZATION ROLE rol_rcncr_batch;

GRANT ROLE rol_rcncr_batch TO <usuario_despliegue>;
GRANT ROLE rol_rcncr_batch TO user_sp;


-- ============================================================================
-- BLOQUE 5 - CLUSTER CONSUMIDOR: permisos
-- ============================================================================

-- Acceso al datashare: lo necesitan LOS DOS usuarios.
GRANT USAGE ON DATABASE ds_dba_rncr_batch TO <usuario_despliegue>;
GRANT USAGE ON DATABASE ds_dba_rncr_batch TO user_sp;

-- Usuario de despliegue: crea tablas, vistas, funciones y procedimientos, y
-- los borra en la reversion.
GRANT CREATE ON DATABASE dba_rncr_batch TO <usuario_despliegue>;
GRANT ALL ON SCHEMA bdm_datos, bdm_tempo, bdm_stage TO <usuario_despliegue>;

-- Usuario del Framework Batch: ejecuta la cadena.
GRANT USAGE ON SCHEMA bdm_datos, bdm_tempo, bdm_stage TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_datos TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_tempo TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_stage TO user_sp;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA bdm_datos TO user_sp;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA bdm_stage TO user_sp;

-- LOS TRES DE ABAJO NO SON OPCIONALES. Sin ellos esto funciona HOY y se rompe
-- en el SIGUIENTE despliegue: cada entrega crea objetos nuevos sobre los que
-- user_sp no tendria permiso.
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_datos
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_tempo
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_stage
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;


-- ============================================================================
-- BLOQUE 6 - VERIFICACION
-- Los cinco puntos. El 5 es el que de verdad cierra la tarea.
-- ============================================================================

-- (1) Como <usuario_despliegue>: devuelve un numero, sin XX000.
SELECT COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm;

-- (2) Lo mismo COMO user_sp: tiene que dar identico.
--     (reconectar la sesion como user_sp y repetir la consulta de arriba)

-- (3) LAS NUEVE RELACIONES, UNA POR UNA Y HASTA EL FINAL. Una sonda que se
--     detiene en el primer error no mide el universo: si una falla, seguir con
--     las demas y reportar la lista completa.
SELECT 'xpm'                                        AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm;
SELECT 'xpm_location'                               AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_location;
SELECT 'xpm_location_val_contactinformations'       AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations;
SELECT 'xpm_counterparties'                         AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_counterparties;
SELECT 'xpm_personalinformation'                    AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_personalinformation;
SELECT 'xpm_chamberofcommerce'                      AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce;
SELECT 'xpm_bestidentifications'                    AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_bestidentifications;
SELECT 'xpm_bestaccounts'                           AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts;
SELECT 'xpm_bestaccounts_val_frequentbehaviour'     AS relacion, COUNT(*) AS filas FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts_val_frequentbehaviour;

-- (4) Los tres esquemas existen.
SELECT nspname FROM pg_namespace
 WHERE nspname IN ('bdm_datos', 'bdm_tempo', 'bdm_stage');

-- (5) COMO user_sp. ES LA PRUEBA QUE CIERRA LA TAREA: distingue "los permisos
--     estan puestos" de "los permisos sirven". Las tres sentencias deben pasar.
CREATE TABLE bdm_tempo.prueba_permiso (id INTEGER);
TRUNCATE bdm_tempo.prueba_permiso;
DROP TABLE bdm_tempo.prueba_permiso;


-- ============================================================================
-- REVERSION
-- En orden inverso. No se tocan los esquemas si tenian objetos de otros
-- equipos antes de esta tarea.
-- ============================================================================

-- Consumidor:
-- REVOKE ROLE rol_rcncr_batch FROM user_sp;
-- REVOKE ROLE rol_rcncr_batch FROM <usuario_despliegue>;
-- DROP DATABASE ds_dba_rncr_batch;
-- DROP ROLE rol_rcncr_batch;
--
-- Productor:
-- REVOKE USAGE ON DATASHARE ds_dba_rncr_batch FROM ACCOUNT '696708350333';
-- DROP DATASHARE ds_dba_rncr_batch;


-- ============================================================================
-- PETICION ADICIONAL A EDF, que no es SQL y conviene no olvidar:
-- confirmar que el usuario o rol consumidor queda EXENTO de enmascaramiento
-- dinamico sobre las nueve relaciones. CREATE OR REPLACE VIEW no lo detecta
-- porque no ejecuta la consulta: el error
--   XX000: cross-cluster query of the masked relation "<rel>" is not supported
-- sale la primera vez que algo la EJECUTA, mucho despues y en otro sitio.
-- En DEV tumbo un despliegue completo (job #453).
-- ============================================================================
