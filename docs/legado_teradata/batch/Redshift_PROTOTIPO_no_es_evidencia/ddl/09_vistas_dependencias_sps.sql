-- ============================================================================
-- Script:      09_vistas_dependencias_sps.sql
-- Objetivo:    Vistas Teradata de las que dependen los SP migrados y cuya
--              definicion llego despues (Dlls-Batch/Dll_Btach.csv, 2026-10-14).
--
-- rec_stage.vstgbatchcargaubicestandarizada
--   Equivalente: REC_STAGE.VstgBATCHCargaUbicEstandarizada
--   Uso en BATCH2: PRO_BATCH_ADD_PORC_INSUMO (universo de personas del insumo
--   para actualizar POR_SIM_* / ORDEN_PRIORIDAD_* en STG_INSUMO_BATCH_VALIDACION;
--   solo lee ID_BURO_PERSONA).
--   Que hace: una fila por persona del insumo estandarizado (P0034) con su
--   direccion, telefono, celular y correo originales y estandarizados,
--   ciudad y departamento. Las demas columnas son constantes (NULL o
--   CURRENT_DATE) para conservar el layout de la vista de ubicaciones.
--
-- Traduccion:
--   - LOCK ROW FOR ACCESS se elimina (Redshift lee con aislamiento de
--     instantanea, no bloquea escrituras).
--   - Vista LATE-BINDING (WITH NO SCHEMA BINDING): se puede crear aunque las
--     tablas de P0034 aun no existan, y no impide que P0034 las borre y
--     recree. Exige nombres calificados con esquema (cumplido).
--   - GROUP BY 7,22,24,25 + QUALIFY: se calcula en una subconsulta agrupada
--     por las mismas 4 columnas (id_buro_persona, cod_pin_persona, tipo_id,
--     numero_id) con ROW_NUMBER, y se filtra rn = 1 afuera. Las columnas
--     constantes se agregan en la consulta externa, en el mismo orden.
--   - ROW_NUMBER() OVER (PARTITION BY Id_Buro_Persona ORDER BY Id_Buro_Persona):
--     si una persona tiene varias combinaciones (PIN, TIPO_ID, NUMERO_ID), la
--     fila elegida no es determinista en ninguno de los dos motores.
--   - EQ -> =. DESCRIPCION_TIPO_UBICACION (sin alias en el original) es de
--     V_Tipo_Ubicacion: se califica con vtu.
--   - CAST((... || ' ' || ...) AS VARCHAR(100)): Teradata trunca en silencio;
--     se usa LEFT(..., 100) para no depender del comportamiento de CAST.
--   - Comparaciones 'Geografica' / 'Telefono' / 'Celular' / 'Mail': Teradata
--     NOT CASESPECIFIC; aqui dependen de la collation CASE_INSENSITIVE de la
--     base (requisito de despliegue, ver README).
--
-- DEPENDENCIAS EXTERNAS (proceso P0034 de carga y estandarizacion del insumo,
-- y vistas del DW). NO se crean aqui; columnas que usa la vista:
--   rec_stage.batch_tmp_carga_insumo_standard
--       cod_dw_reporte_ubic_original, cod_dw_tipo_ubicacion, id_buro_persona,
--       cod_pin_persona, tipo_id, numero_id, texto_ubicacion_original, texto_ciudad
--   rec_vista.v_tipo_ubicacion          cod_dw_tipo_ubicacion, descripcion_tipo_ubicacion
--   rec_stage.batch_direccionfisica_estandarizada
--       cod_dw_reporte_ubic_original, codigo_ciudad_dane, dir_tipo_dire,
--       texto_ciudad, dire_geo, dire_complemento
--   rec_vista.vu_geografia              cod_dane_ciudad, descripcion_departamento
--   rec_stage.batch_telefonofijoestandarizado
--       cod_dw_reporte_ubic_original, codigo_ciudad_dane, texto_ciudad, componente_tel
--   rec_stage.batch_telefonomovil_estandarizado  cod_dw_reporte_ubic_original, ubicacion_stand
--   rec_stage.batch_emails_estandarizados        cod_dw_reporte_ubic_original, ubicacion_stand2
--   Si codigo_ciudad_dane y cod_dane_ciudad tienen tipos distintos (Teradata
--   convertia implicitamente), el JOIN falla en Redshift: agregar CAST.
--   Mientras P0034 no este migrado, la vista se crea pero falla al
--   consultarla. Para una prueba sin P0034, ver el bloque opcional al final.
-- ============================================================================

CREATE OR REPLACE VIEW rec_stage.vstgbatchcargaubicestandarizada AS
SELECT CAST(NULL AS INTEGER)       AS cod_dw_reporte_ubic_original
      ,CAST(NULL AS VARCHAR(1000)) AS texto_ubicacion_original
      ,CAST(NULL AS INTEGER)       AS cod_dw_tipo_ubicacion
      ,CAST(NULL AS INTEGER)       AS cod_dw_fuente
      ,CAST(NULL AS INTEGER)       AS lote
      ,CAST(NULL AS INTEGER)       AS id_buro_suscriptor
      ,g.id_buro_persona
      ,CAST(NULL AS INTEGER)       AS cod_dw_cta
      ,CAST(NULL AS CHAR(32))      AS cod_dw_hash
      ,CAST(NULL AS INTEGER)       AS cod_dw_ubic
      ,CAST(NULL AS VARCHAR(20))   AS valor
      ,CAST(NULL AS VARCHAR(20))   AS texto_ciudad
      ,CAST(NULL AS VARCHAR(20))   AS codigo_ciudad_dane
      ,CURRENT_DATE                AS fecha_reporte
      ,CAST(NULL AS INTEGER)       AS cod_dw_ubicacion_original
      ,CAST(NULL AS INTEGER)       AS cod_dw_tipo_ubicacion_dir
      ,CAST(NULL AS VARCHAR(20))   AS usuario_bd
      ,CURRENT_DATE                AS fecha_desde
      ,CURRENT_DATE                AS fecha_hasta
      ,CAST(NULL AS INTEGER)       AS id_flag_nuevo
      ,CAST(NULL AS INTEGER)       AS id_flag_desde
      ,g.cod_pin_persona
      ,CAST(NULL AS INTEGER)       AS cod_dw_pais
      ,g.tipo_id
      ,g.numero_id
      ,g.direccion
      ,g.telefono
      ,g.celular
      ,g.email
      ,g.tipo_dir_std
      ,g.ciudad_dir_insumo_std
      ,g.dir_insumo_std
      ,g.ciudad_tel_insumo_std
      ,g.tel_insumo_std
      ,g.cel_insumo_std
      ,g.email_insumo_std
      ,CAST(1 AS INTEGER)          AS severidad
      ,g.ciudad_direccion
      ,g.ciudad_telefono
      ,g.departamento_direccion
      ,g.departamento_telefono
      ,CAST(NULL AS INTEGER)       AS por_sim_dir
      ,CAST(NULL AS INTEGER)       AS orden_prioridad_dir
      ,CAST(NULL AS INTEGER)       AS por_sim_tel
      ,CAST(NULL AS INTEGER)       AS orden_prioridad_tel
      ,CAST(NULL AS INTEGER)       AS por_sim_cel
      ,CAST(NULL AS INTEGER)       AS orden_prioridad_cel
      ,CAST(NULL AS INTEGER)       AS por_sim_mail
      ,CAST(NULL AS INTEGER)       AS orden_prioridad_mail
FROM (
    SELECT cis.id_buro_persona
          ,cis.cod_pin_persona
          ,cis.tipo_id
          ,cis.numero_id
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Geografica' THEN cis.texto_ubicacion_original END) AS direccion
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Telefono'   THEN cis.texto_ubicacion_original END) AS telefono
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Celular'    THEN cis.texto_ubicacion_original END) AS celular
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Mail'       THEN cis.texto_ubicacion_original END) AS email
          ,MAX(dfe.dir_tipo_dire)  AS tipo_dir_std
          ,MAX(dfe.texto_ciudad)   AS ciudad_dir_insumo_std
          ,MAX(LEFT(COALESCE(dfe.dire_geo, '') || ' ' || COALESCE(dfe.dire_complemento, ''), 100)) AS dir_insumo_std
          ,MAX(tfe.texto_ciudad)   AS ciudad_tel_insumo_std
          ,MAX(tfe.componente_tel) AS tel_insumo_std
          ,MAX(tme.ubicacion_stand)  AS cel_insumo_std
          ,MAX(eme.ubicacion_stand2) AS email_insumo_std
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Geografica' THEN cis.texto_ciudad END) AS ciudad_direccion
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Telefono'   THEN cis.texto_ciudad END) AS ciudad_telefono
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Geografica' THEN vgec.descripcion_departamento END) AS departamento_direccion
          ,MAX(CASE WHEN vtu.descripcion_tipo_ubicacion = 'Telefono'   THEN vget.descripcion_departamento END) AS departamento_telefono
          ,ROW_NUMBER() OVER (PARTITION BY cis.id_buro_persona ORDER BY cis.id_buro_persona) AS rn
    FROM rec_stage.batch_tmp_carga_insumo_standard cis
    LEFT JOIN rec_vista.v_tipo_ubicacion vtu
           ON vtu.cod_dw_tipo_ubicacion = cis.cod_dw_tipo_ubicacion
    LEFT JOIN rec_stage.batch_direccionfisica_estandarizada dfe
           ON cis.cod_dw_reporte_ubic_original = dfe.cod_dw_reporte_ubic_original
    LEFT JOIN rec_vista.vu_geografia vgec
           ON dfe.codigo_ciudad_dane = vgec.cod_dane_ciudad
    LEFT JOIN rec_stage.batch_telefonofijoestandarizado tfe
           ON cis.cod_dw_reporte_ubic_original = tfe.cod_dw_reporte_ubic_original
    LEFT JOIN rec_vista.vu_geografia vget
           ON tfe.codigo_ciudad_dane = vget.cod_dane_ciudad
    LEFT JOIN rec_stage.batch_telefonomovil_estandarizado tme
           ON cis.cod_dw_reporte_ubic_original = tme.cod_dw_reporte_ubic_original
    LEFT JOIN rec_stage.batch_emails_estandarizados eme
           ON cis.cod_dw_reporte_ubic_original = eme.cod_dw_reporte_ubic_original
    GROUP BY cis.id_buro_persona, cis.cod_pin_persona, cis.tipo_id, cis.numero_id
) g
WHERE g.rn = 1
WITH NO SCHEMA BINDING;

-- ============================================================================
-- OPCIONAL, SOLO PARA PRUEBAS SIN P0034 (p. ej. la prueba del producto
-- Esencial): tablas vacias con las columnas que lee la vista, para que
-- PRO_BATCH_ADD_PORC_INSUMO no falle por "relation does not exist". Con estas
-- tablas vacias la vista no devuelve filas y el UPDATE de
-- STG_INSUMO_BATCH_VALIDACION no cambia nada. Los tipos son supuestos.
-- No ejecutar en un ambiente donde P0034 ya este migrado (los CREATE ... IF
-- NOT EXISTS no lo pisan, pero las dos vistas del DW quedarian como tablas).
-- ============================================================================
/*
CREATE TABLE IF NOT EXISTS rec_stage.batch_tmp_carga_insumo_standard
( cod_dw_reporte_ubic_original BIGINT, cod_dw_tipo_ubicacion INTEGER, id_buro_persona BIGINT,
  cod_pin_persona BIGINT, tipo_id VARCHAR(5), numero_id VARCHAR(20),
  texto_ubicacion_original VARCHAR(1000), texto_ciudad VARCHAR(100) );
CREATE TABLE IF NOT EXISTS rec_vista.v_tipo_ubicacion
( cod_dw_tipo_ubicacion INTEGER, descripcion_tipo_ubicacion VARCHAR(100) );
CREATE TABLE IF NOT EXISTS rec_stage.batch_direccionfisica_estandarizada
( cod_dw_reporte_ubic_original BIGINT, codigo_ciudad_dane VARCHAR(20), dir_tipo_dire VARCHAR(50),
  texto_ciudad VARCHAR(100), dire_geo VARCHAR(200), dire_complemento VARCHAR(200) );
CREATE TABLE IF NOT EXISTS rec_vista.vu_geografia
( cod_dane_ciudad VARCHAR(20), descripcion_departamento VARCHAR(100) );
CREATE TABLE IF NOT EXISTS rec_stage.batch_telefonofijoestandarizado
( cod_dw_reporte_ubic_original BIGINT, codigo_ciudad_dane VARCHAR(20), texto_ciudad VARCHAR(100),
  componente_tel VARCHAR(30) );
CREATE TABLE IF NOT EXISTS rec_stage.batch_telefonomovil_estandarizado
( cod_dw_reporte_ubic_original BIGINT, ubicacion_stand VARCHAR(30) );
CREATE TABLE IF NOT EXISTS rec_stage.batch_emails_estandarizados
( cod_dw_reporte_ubic_original BIGINT, ubicacion_stand2 VARCHAR(200) );
*/
