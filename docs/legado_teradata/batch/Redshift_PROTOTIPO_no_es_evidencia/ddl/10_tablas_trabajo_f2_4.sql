-- ============================================================================
-- Script:   10_tablas_trabajo_f2_4.sql           (2026-10-15, tarea F2-4)
-- Objetivo: Tablas de trabajo que los SP de F2-4 asumen YA CREADAS porque en
--           Teradata las creaba el paso BTEQ previo, no el stored procedure.
--
-- Origen de cada DDL (literal, solo traducido a Redshift):
--   w_borrar_002, w_ejecutor  ->  P0033_BATCH2_CANALCONTACTO_111.BTQ
--                                (labels CREA2 y CREA3, lineas 69-150)
--
-- NOTA SOBRE tabla_w1 / tabla_w2: NO se declaran aqui a proposito. El BTEQ
-- solo las BORRA; su CREATE lo genera PRO_Batch2_Completitud_Canal en tiempo
-- de ejecucion, con un numero de columnas que depende de los campos
-- configurados en la plantilla. sp_batch2_completitud_canal replica eso.
--
-- Traduccion:
--   PRIMARY INDEX (Secuencia) -> DISTKEY (secuencia)
--   CREATE MULTISET TABLE     -> CREATE TABLE (Redshift no desduplica)
--   VARCHAR(10000)            -> VARCHAR(10000) (cabe: el maximo es 65535)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- rec_stage.w_borrar_002: acumula los FRAGMENTOS de texto SQL que
-- PRO_Batch2_Completitud_Canal concatena despues (uno por campo de la
-- plantilla). Equivalente a w_Borrar_001, que usa CUBOEXPORT.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.w_borrar_002
(
    secuencia  INTEGER,
    detalle    VARCHAR(10000)
)
DISTSTYLE KEY
DISTKEY (secuencia)
SORTKEY (secuencia);

-- ----------------------------------------------------------------------------
-- rec_stage.w_ejecutor: guarda la sentencia YA CONSOLIDADA (el LISTAGG de
-- w_borrar_002) que el SP lee con SELECT ... INTO y ejecuta.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.w_ejecutor
(
    secuencia  INTEGER,
    campo      VARCHAR(10000)
)
DISTSTYLE KEY
DISTKEY (secuencia)
SORTKEY (secuencia);


-- ============================================================================
-- DEPENDENCIAS QUE ESTE DDL *NO* CREA Y QUE F2-4 NECESITA
-- ============================================================================
-- Los cuatro SP de F2-4 leen objetos que en Teradata crean los pasos BTEQ de
-- CUBOEXPORT y EXPORTPLANO, y que la migracion Redshift todavia NO construye
-- (el sp_batch2_exportplano actual va directo de las tablas pivote al UNLOAD
-- con un SELECT fijo; ver GUIA_PRUEBA_PRODUCTO_ESENCIAL.md seccion 3.2):
--
--   rec_stage.v_ba2_campos_salida
--       Catalogo final de campos de salida de la plantilla (una fila por
--       columna del archivo). Columnas que usa F2-4: ordenamiento, xalias,
--       valor_ini, camponuevo, codigo_campo.
--       Definicion original: P0033_BATCH2_CUBOEXPORT_111.BTQ linea 1339.
--       Depende a su vez de v_ba2_camposbase (linea 177/754) y
--       vstg_ba2_campos (linea 43), que dependen de batch_salidas_campos y
--       batch2_homologacion.
--       Lo usan: sp_batch2_transpuesta, sp_batch2_completitud_canal.
--
--   rec_stage.vstg_batch2_pn / _pj / _pnpj
--       Vistas anchas de salida por tipo de persona.
--       Definicion original: P0033_BATCH2_EXPORTPLANO_111.BTQ / _120.BTQ.
--       Las usan: sp_batch2_transpuesta, sp_batch2_completitud_canal.
--
--   rec_stage.vstg_inconsis_pnpj
--       Vista de inconsistencias.
--       Definicion original: P0033_BATCH2_CUBOEXPORT_111.BTQ lineas 1134
--       (formato fijo) y 1225 (formato variable).
--       La usa: sp_batch2_estadisticas (la materializa como
--       vstg_inconsis_pnpj_tabla).
--
--   rec_stage.batch_cubo_persona11
--       Tabla de trabajo. Su DDL NO esta en ningun archivo del workspace;
--       la unica aparicion del nombre es Sps_Batch.sql linea 9121.
--       La usa: sp_batch2_cantrepcanal_con.
--       PENDIENTE DE INSUMO (ver lista del 14-oct).
--
--   rec_stage.batch_cubo_temp_dir_total / _telefono_total / _celular_total /
--   _correo_total
--       Las crea sp_batch2_estadisticas_cfg en modo 'TMP_ESTADISTICAS', a
--       partir de las filas de rec_datos.pro_batch2_filtros_estadisticas, que
--       siguen sin recibirse (insumo #2).
--       Las usa: sp_batch2_estadisticas (conteos CON_DIR/CON_TEL/CON_CEL/
--       CON_EMAIL).
--
-- CONSECUENCIA: el codigo de F2-4 esta completo y referencia estos objetos
-- con el mismo nombre que el original, pero NO se puede ejecutar de punta a
-- punta hasta que existan. Construir v_ba2_campos_salida y las vistas
-- vstg_batch2_* es trabajo de F2-5 (ajuste de cuboexport/exportplano).
-- ============================================================================
