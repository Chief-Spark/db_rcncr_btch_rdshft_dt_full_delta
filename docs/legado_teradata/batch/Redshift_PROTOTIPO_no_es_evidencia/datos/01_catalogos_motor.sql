-- ============================================================================
-- Script:      datos/01_catalogos_motor.sql
-- Objetivo:    Cargar las filas de los catalogos y "motores" de SQL guardado
--              como datos, reescritas a sintaxis Redshift.
-- Fuente:      Dlls-Batch/Dll_Btach.csv (BATCH_MOTOR_LOG, TIPO='LOG') y
--              Dlls-Batch/Dll_Btach2.csv (PRO_PLAN_EJECUCION, PARTE='ITERADOR'),
--              aportados el 2026-10-14. Catalogo BATCH_ARCHIVO_LOG: ID y DATO
--              de las filas del motor, confirmados con
--              Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG (mismo orden y texto).
-- Ejecutar:    despues de ddl/01..09. Idempotente (borra y recarga solo las
--              filas que carga). Archivo en UTF-8 (tildes en DATO): ejecutar
--              con client_encoding UTF8.
--
-- Reglas de la reescritura (las mismas de procedures/08):
--   - Los marcadores se dejan en el texto y los reemplaza el SP en tiempo de
--     ejecucion, EN MAYUSCULAS: P_BDSTAGE (-> rec_stage), P_ID_SOLICITUD,
--     P_ID_PLANTILLA, P_StartTimeStampPadre, P_ARCHIVOPRN, P_MAQUINA, P_RUTA,
--     P_FEINICIO. El resto del SQL va en minusculas para que ningun texto
--     coincida por accidente con un marcador.
--   - En PRO_PLAN_EJECUCION el original compara ID_SOLICITUD = 'P_ID_SOLICITUD'
--     (texto contra BIGINT, conversion implicita de Teradata); aqui va sin
--     comillas.
--   - BDM_VISTA (vistas del DW) -> rec_vista, igual que en los SP migrados.
--   - SEL -> SELECT; REPLACE VIEW -> CREATE OR REPLACE VIEW ... WITH NO
--     SCHEMA BINDING (vista late-binding: no impide el DROP de las tablas que
--     lee); LOCK ROW FOR ACCESS se elimina; QUALIFY -> subconsulta con
--     ROW_NUMBER; XMLAGG(x) -> LISTAGG(x, ' ') (XMLAGG separa los elementos
--     con un espacio); BYTEINT -> SMALLINT; MULTISET/SET/FALLBACK/PRIMARY
--     INDEX se eliminan (tablas chicas: DISTSTYLE ALL).
--   - Valor asignado a BATCH_ARCHIVO_LOG.VALOR (VARCHAR(1000)): Teradata
--     convertia numeros a texto en forma implicita y truncaba textos largos;
--     aqui CAST(... AS VARCHAR(1000)) y LEFT(..., 1000).
--   - El texto de la exportacion CSV del insumo perdio los saltos de linea
--     (p. ej. "BATCH2_SHELLS_CONFIGFROM(", "SEL TOP 200ORDEN_ID"); se
--     reconstruyeron los espacios.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. rec_stage.batch_archivo_log: catalogo DATO/VALOR del archivo
--    BATCH_SOLICITUD_BATCH.ARCHIVO_LOG. PRO_BATCH2_ARCHIVO_LOG pone VALOR en
--    NULL y cada fila TIPO='LOG' del motor lo llena.
-- ----------------------------------------------------------------------------
DELETE FROM rec_stage.batch_archivo_log;

INSERT INTO rec_stage.batch_archivo_log (id, dato, valor) VALUES
 (1,  'FECHA INICIO', NULL)
,(2,  'FECHA FIN', NULL)
,(3,  'MAQUINA', NULL)
,(4,  'RUTA', NULL)
,(5,  'ARCHIVO PRN', NULL)
,(6,  'CODIGO SUSCRIPTOR', NULL)
,(7,  'REGISTROS LEIDOS', NULL)
,(8,  'REGISTROS GRABADOS', NULL)
,(9,  'NUMERO DE TELEFONOS FIJOS', NULL)
,(10, 'NUMERO DE CELULARES', NULL)
,(11, 'NUMERO DE DIRECCIONES', NULL)
,(12, 'NUMERO DE CORREOS ELECTRÓNICOS', NULL)
,(13, 'NUMERO DE DATOS MÍNIMOS POR TELÉFONO FIJO', NULL)
,(14, 'NUMERO DE DATOS MÍNIMOS POR TELÉFONO CELULAR', NULL)
,(15, 'NUMERO DE DATOS MÍNIMOS POR DIRECCIONES', NULL)
,(16, 'NUMERO DE DATOS MÍNIMOS POR CORREOS ELECTRÓNICOS', NULL)
,(17, 'SEGMENTO VALIDACION DE INDENTIDAD(PSVNO)', NULL)
,(18, 'DISTRIBUCION DE INCONSISTENCIAS', NULL);

-- ----------------------------------------------------------------------------
-- 2. rec_stage.batch_motor_log, TIPO = 'LOG' (18 filas). Las ejecuta
--    rec_stage.sp_batch2_archivo_log en orden de ID.
--
-- Comportamientos del original que se conservan (confirmados con las 4
-- corridas de Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG):
--   - ID 13 (DATO 'NUMERO DE DATOS MINIMOS POR TELEFONO FIJO') NO llena el
--     ID 13: es una copia de la sentencia de CODIGO SUSCRIPTOR que filtra
--     ID_SOLICITUD = P_ID_PLANTILLA y actualiza WHERE ID=6. Como corre despues
--     de la fila 6, sobrescribe CODIGO SUSCRIPTOR. En las muestras el ID 13
--     siempre sale vacio.
--   - ID 8 (REGISTROS GRABADOS): el original compara dos literales,
--     CASE WHEN TRIM('SIN DATOS DE UBICACION')='CON DATOS DE UBICACION'
--     THEN COUNT(NUMERO_ID) ELSE 0 END, sobre Vstg_Batch2_PNPJ, _PN y _PJ.
--     La condicion siempre es falsa y cada SELECT es un agregado sin GROUP BY
--     (una fila aunque la vista este vacia), asi que el resultado es siempre
--     0 (asi sale en las 4 muestras). Esas vistas no existen en Redshift
--     (sp_batch2_exportplano usa un SELECT fijo), por lo que se escribe el
--     valor equivalente '0'. Sentencia original:
--       UPDATE P_BDSTAGE.BATCH_ARCHIVO_LOG SET VALOR=(SELECT SUM(CANT) FROM(
--         SELECT CAST(CASE WHEN TRIM('SIN DATOS DE UBICACION' )='CON DATOS DE UBICACION'
--                THEN COUNT( NUMERO_ID) ELSE 0 END AS INTEGER) AS CANT FROM P_BDSTAGE.Vstg_Batch2_PNPJ
--         UNION ALL SELECT CASE ... FROM P_BDSTAGE.Vstg_Batch2_PN
--         UNION ALL SELECT CASE ... FROM P_BDSTAGE.Vstg_Batch2_PJ )A) WHERE ID=8;
--   - XMLAGG (ID 6, 13, 18): orden de los elementos no definido en ambos
--     motores. XMLAGG ademas escapa &, < y > como entidades XML; LISTAGG no.
--
-- Dependencias externas (DW, no creadas): rec_vista.v_evento_entrega_dato,
-- rec_vista.v_cod_entrega_dato y rec_stage.vstg_buropers_tmp (ID 6 y 13).
-- Si COD_ENTREGA_DATO_FTE es numerico en Teradata, su conversion implicita a
-- texto agregaba espacios a la izquierda; aqui CAST sin espacios.
-- ----------------------------------------------------------------------------
DELETE FROM rec_stage.batch_motor_log WHERE tipo = 'LOG';

INSERT INTO rec_stage.batch_motor_log (id, tipo, dato, sql_string) VALUES
 (1, 'LOG', 'FECHA INICIO',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = ''P_FEINICIO'' WHERE id = 1')
,(2, 'LOG', 'FECHA FIN',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = ''P_StartTimeStampPadre'' WHERE id = 2')
,(3, 'LOG', 'MAQUINA',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = ''P_MAQUINA'' WHERE id = 3')
,(4, 'LOG', 'RUTA',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = ''P_RUTA'' WHERE id = 4')
,(5, 'LOG', 'ARCHIVO PRN',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = LEFT(''P_ARCHIVOPRN'', 1000) WHERE id = 5')
,(6, 'LOG', 'CODIGO SUSCRIPTOR',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT LEFT(LISTAGG(d.cod_suscriptor, '' ''), 1000)
             FROM (SELECT DISTINCT CAST(b.cod_entrega_dato_fte AS VARCHAR(100)) || '','' AS cod_suscriptor
                   FROM rec_vista.v_evento_entrega_dato a
                   INNER JOIN rec_vista.v_cod_entrega_dato b
                           ON a.cod_dw_entrega_dato = b.cod_dw_entrega_dato
                   WHERE a.id_buro_proveedor_dato IN (SELECT vbt.id_buro_persona
                                                      FROM P_BDSTAGE.batch_solicitud_batch bsb
                                                      INNER JOIN P_BDSTAGE.vstg_buropers_tmp vbt
                                                              ON bsb.tipo_id_suscriptor = vbt.cod_tipo_ident_fte
                                                             AND bsb.num_id_suscriptor = vbt.num_ident
                                                      WHERE bsb.id_solicitud = P_ID_SOLICITUD)) d)
WHERE id = 6')
,(7, 'LOG', 'REGISTROS LEIDOS',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(SUM(a.total) AS VARCHAR(1000))
             FROM (/*#1 Ajuste cantidad registro leidos mantis 7101 -- #2 cambio de conteo validas e inconsistentes */
                   SELECT CASE WHEN i.nombre_tipo_ident = ''Cedula de Ciudadania''  THEN ''ID_CC_CON_DATOS''
                               WHEN i.nombre_tipo_ident = ''Nit Juridicos''         THEN ''ID_NIT_CON_DATOS''
                               WHEN i.nombre_tipo_ident = ''Nit de Extranjeria''    THEN ''ID_NITE_CON_DATOS''
                               WHEN i.nombre_tipo_ident = ''Cedula de Extranjeria'' THEN ''ID_CE_CON_DATOS''
                          END AS tipo
                         ,COUNT(*) AS total
                   FROM (SELECT tipo_id FROM P_BDSTAGE.batch_identificaciones_validas WHERE id_solicitud = P_ID_SOLICITUD
                         UNION ALL
                         SELECT tipo_id FROM P_BDSTAGE.batch_identificaciones_incons WHERE id_solicitud = P_ID_SOLICITUD) cp
                   LEFT JOIN rec_vista.tipo_identificacion i
                          ON cp.tipo_id = i.cod_tipo_ident_fte
                   GROUP BY 1) a)
WHERE id = 7')
,(8, 'LOG', 'REGISTROS GRABADOS',
  'UPDATE P_BDSTAGE.batch_archivo_log SET valor = ''0'' WHERE id = 8')
,(9, 'LOG', 'NUMERO DE TELEFONOS FIJOS',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(COUNT(DISTINCT bct.numero) AS VARCHAR(1000))
             FROM P_BDSTAGE.batch_cubo_telefono bct
             INNER JOIN P_BDSTAGE.batch_cubo_persona bcp
                     ON bct.id_buro_persona = bcp.id_buro_persona
                    AND bcp.filtro_h = 0
             WHERE bct.filtro_h = 0)
WHERE id = 9')
,(10, 'LOG', 'NUMERO DE CELULARES',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(COUNT(DISTINCT bcc.numero) AS VARCHAR(1000))
             FROM P_BDSTAGE.batch_cubo_celular bcc
             INNER JOIN P_BDSTAGE.batch_cubo_persona bcp
                     ON bcc.id_buro_persona = bcp.id_buro_persona
                    AND bcp.filtro_h = 0
             WHERE bcc.filtro_h = 0)
WHERE id = 10')
,(11, 'LOG', 'NUMERO DE DIRECCIONES',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(COUNT(DISTINCT bcd.direccion) AS VARCHAR(1000))
             FROM P_BDSTAGE.batch_cubo_direccion bcd
             INNER JOIN P_BDSTAGE.batch_cubo_persona bcp
                     ON bcd.id_buro_persona = bcp.id_buro_persona
                    AND bcp.filtro_h = 0
             WHERE bcd.filtro_h = 0)
WHERE id = 11')
,(12, 'LOG', 'NUMERO DE CORREOS ELECTRÓNICOS',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(COUNT(DISTINCT bcc.correo) AS VARCHAR(1000))
             FROM P_BDSTAGE.batch_cubo_correo bcc
             INNER JOIN P_BDSTAGE.batch_cubo_persona bcp
                     ON bcc.id_buro_persona = bcp.id_buro_persona
                    AND bcp.filtro_h = 0
             WHERE bcc.filtro_h = 0)
WHERE id = 12')
,(13, 'LOG', 'NUMERO DE DATOS MÍNIMOS POR TELÉFONO FIJO',
  -- BUG ORIGINAL REPLICADO: ID_SOLICITUD = P_ID_PLANTILLA y WHERE id = 6
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT LEFT(LISTAGG(d.cod_suscriptor, '' ''), 1000)
             FROM (SELECT DISTINCT CAST(b.cod_entrega_dato_fte AS VARCHAR(100)) || '','' AS cod_suscriptor
                   FROM rec_vista.v_evento_entrega_dato a
                   INNER JOIN rec_vista.v_cod_entrega_dato b
                           ON a.cod_dw_entrega_dato = b.cod_dw_entrega_dato
                   WHERE a.id_buro_proveedor_dato IN (SELECT vbt.id_buro_persona
                                                      FROM P_BDSTAGE.batch_solicitud_batch bsb
                                                      INNER JOIN P_BDSTAGE.vstg_buropers_tmp vbt
                                                              ON bsb.tipo_id_suscriptor = vbt.cod_tipo_ident_fte
                                                             AND bsb.num_id_suscriptor = vbt.num_ident
                                                      WHERE bsb.id_solicitud = P_ID_PLANTILLA)) d)
WHERE id = 6')
,(14, 'LOG', 'NUMERO DE DATOS MÍNIMOS POR TELÉFONO CELULAR',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT bsc.minimo_requerido_campo
             FROM P_BDSTAGE.batch_salidas_campos bsc
             INNER JOIN P_BDSTAGE.batch2_homologacion b2h
                     ON bsc.codigo_campo = b2h.codigo_campo
             WHERE b2h.cubo = ''CELULAR''
               AND b2h.descripcion_campo = ''Numero''
               AND bsc.id_solicitud = P_ID_SOLICITUD
               AND bsc.id_plantilla = P_ID_PLANTILLA)
WHERE id = 14')
,(15, 'LOG', 'NUMERO DE DATOS MÍNIMOS POR DIRECCIONES',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT bsc.minimo_requerido_campo
             FROM P_BDSTAGE.batch_salidas_campos bsc
             INNER JOIN P_BDSTAGE.batch2_homologacion b2h
                     ON bsc.codigo_campo = b2h.codigo_campo
             WHERE b2h.cubo = ''DIRECCION''
               AND b2h.descripcion_campo = ''DIRECCION''
               AND bsc.id_solicitud = P_ID_SOLICITUD
               AND bsc.id_plantilla = P_ID_PLANTILLA)
WHERE id = 15')
,(16, 'LOG', 'NUMERO DE DATOS MÍNIMOS POR CORREOS ELECTRÓNICOS',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT bsc.minimo_requerido_campo
             FROM P_BDSTAGE.batch_salidas_campos bsc
             INNER JOIN P_BDSTAGE.batch2_homologacion b2h
                     ON bsc.codigo_campo = b2h.codigo_campo
             WHERE b2h.cubo = ''CORREO''
               AND b2h.descripcion_campo = ''CORREO''
               AND bsc.id_solicitud = P_ID_SOLICITUD
               AND bsc.id_plantilla = P_ID_PLANTILLA)
WHERE id = 16')
,(17, 'LOG', 'SEGMENTO VALIDACION DE INDENTIDAD(PSVNO)',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT CAST(COUNT(*) AS VARCHAR(1000))
             FROM P_BDSTAGE.batch_identificaciones_incons
             WHERE id_solicitud = P_ID_SOLICITUD
               AND id_plantilla = P_ID_PLANTILLA)
WHERE id = 17')
,(18, 'LOG', 'DISTRIBUCION DE INCONSISTENCIAS',
  'UPDATE P_BDSTAGE.batch_archivo_log
SET valor = (SELECT LEFT(LISTAGG(a.campo, '' ''), 1000)
             FROM (SELECT DISTINCT causal || '' '' || CAST(COUNT(*) AS VARCHAR(20)) || '','' AS campo
                   FROM P_BDSTAGE.batch_identificaciones_incons
                   WHERE id_solicitud = P_ID_SOLICITUD
                     AND id_plantilla = P_ID_PLANTILLA
                   GROUP BY causal) a)
WHERE id = 18');

-- ----------------------------------------------------------------------------
-- 3. rec_stage.pro_plan_ejecucion, PARTE = 'ITERADOR' (12 filas). Las ejecuta
--    rec_stage.sp_batch2_plan_ejecucion_shell en orden de ID y arman
--    rec_stage.batch2_shells_planejecucion a partir de
--    rec_stage.batch2_shells_config (filas pendientes de migrar, ver ddl/07)
--    y de las secciones de BATCH_SALIDAS_CAMPOS de la solicitud.
--
-- Diferencias con el original:
--   - ID 5 y 10: DROP TABLE -> DROP TABLE IF EXISTS. En Teradata la tabla
--     siempre existia de una corrida anterior; en un cluster nuevo el DROP
--     sin IF EXISTS fallaria en la primera ejecucion.
--   - ID 4: se quita GROUP BY 1 dentro del NOT EXISTS (no cambia el
--     resultado del EXISTS).
--   - ID 6: CONS BYTEINT (maximo 127 pasos en Teradata) -> SMALLINT.
--   - ID 7, 8 y 9: en los ORDER BY de ventana se agrega NULLS FIRST (orden de
--     NULL de Teradata en ASC).
--   - ID 7: GROUP BY 1..10 incluia la constante 'X' (posicion 7); se agrupa
--     por las 9 columnas reales (mismo resultado).
--   - ID 11: debe ser igual a la definicion de ddl/05_tablas_control.sql.
-- ----------------------------------------------------------------------------
DELETE FROM rec_stage.pro_plan_ejecucion WHERE parte = 'ITERADOR';

INSERT INTO rec_stage.pro_plan_ejecucion (id, parte, campo, sql_valor) VALUES
 (1, 'ITERADOR', 'BATCH2_SHELLS_CONFIG',
  'UPDATE rec_stage.batch2_shells_config /*Si no solicitan export_horizontal se quita del export*/
SET estado = (SELECT CASE WHEN NVL(SUM(1), 0) = 0 THEN ''N'' ELSE ''S'' END
              FROM rec_stage.batch_datos_generales
              WHERE id_solicitud = P_ID_SOLICITUD
                AND orientacion = ''OE_HORIZON'')
WHERE nombre_shell = ''P0033_BATCH2_EXPORTPLANO''')
,(2, 'ITERADOR', 'BATCH2_SHELLS_CONFIG',
  'UPDATE rec_stage.batch2_shells_config /*Si no solicitan expor_vertical se quita del export*/
SET estado = (SELECT CASE WHEN NVL(SUM(1), 0) = 0 THEN ''N'' ELSE ''S'' END
              FROM rec_stage.batch_datos_generales
              WHERE id_solicitud = P_ID_SOLICITUD
                AND orientacion = ''OE_VERTICA'')
WHERE nombre_shell = ''P0033_BATCH2_EXPORTVERTPLANO''')
,(3, 'ITERADOR', 'BATCH2_SHELLS_CONFIG',
  'UPDATE rec_stage.batch2_shells_config
SET estado = tmp.actualizar
FROM (SELECT cfg.nombre_shell AS proceso
            ,CASE WHEN rta.reg > 0 THEN ''S'' ELSE ''N'' END AS actualizar
      FROM rec_stage.batch2_shells_config cfg
      CROSS JOIN (SELECT COALESCE(SUM(1), 0) AS reg
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = P_ID_SOLICITUD
                    AND UPPER(nombre_subseccion) = ''VALIDACION'') rta
      WHERE cfg.nombre_shell IN (''P0034_CARGA_INSUMO_STANDARD''
                                ,''P0034_EstandarizacionUbicacion''
                                ,''P0034_UBICACION_ESTANDARIZADA'')
        AND cfg.actualiza_estado = ''S'') tmp
WHERE TRIM(batch2_shells_config.nombre_shell) = TRIM(tmp.proceso)')
,(4, 'ITERADOR', 'STG_INSUMO_BATCH_VALIDACION',
  'DELETE FROM rec_stage.stg_insumo_batch_validacion
WHERE NOT EXISTS (SELECT 1
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = P_ID_SOLICITUD
                    AND UPPER(nombre_subseccion) = ''VALIDACION'')
  AND EXISTS (SELECT 1
              FROM rec_stage.batch2_shells_config
              WHERE nombre_shell IN (''P0034_CARGA_INSUMO_STANDARD'', ''P0034_EstandarizacionUbicacion'', ''P0034_UBICACION_ESTANDARIZADA'')
                AND actualiza_estado = ''S''
                AND estado = ''N'')')
,(5, 'ITERADOR', 'INTEGRADOR_TMP',
  'DROP TABLE IF EXISTS rec_stage.integrador_tmp')
,(6, 'ITERADOR', 'INTEGRADOR_TMP',
  'CREATE TABLE rec_stage.integrador_tmp
(
    orden_id               INTEGER,
    orden_idll             INTEGER,
    orden_idlll            INTEGER,
    nombre_shell           VARCHAR(500),
    id_solicitud           BIGINT,
    id_plantilla           BIGINT,
    seccion                VARCHAR(100),
    actualiza_solicitud    CHAR(1),
    actualiza_plantilla    CHAR(1),
    actualiza_ruta_salida  CHAR(1),
    cons                   SMALLINT
)
DISTSTYLE ALL')
,(7, 'ITERADOR', 'ORDEN_SHELL',
  'CREATE OR REPLACE VIEW rec_stage.orden_shell AS
SELECT TOP 200
       orden_id, orden_idll, orden_idlll, nombre_shell, id_solicitud, id_plantilla, seccion
      ,actualiza_solicitud, actualiza_plantilla, actualiza_ruta_salida
FROM (SELECT cfg.orden_id, cfg.orden_idll, cfg.orden_idlll, cfg.nombre_shell
            ,sal.id_solicitud, sal.id_plantilla
            ,CAST(''X'' AS VARCHAR(100)) AS seccion
            ,cfg.actualiza_solicitud, cfg.actualiza_plantilla, cfg.actualiza_ruta_salida
      FROM (SELECT id_solicitud, id_plantilla, nombre_seccion
            FROM rec_stage.batch_salidas_campos
            WHERE id_solicitud = P_ID_SOLICITUD
            GROUP BY 1, 2, 3) sal
      CROSS JOIN rec_stage.batch2_shells_config cfg
      WHERE cfg.iteracion = ''N''
        AND cfg.estado = ''S''
      GROUP BY cfg.orden_id, cfg.orden_idll, cfg.orden_idlll, cfg.nombre_shell
              ,sal.id_solicitud, sal.id_plantilla
              ,cfg.actualiza_solicitud, cfg.actualiza_plantilla, cfg.actualiza_ruta_salida
      UNION
      SELECT cfg.orden_id, cfg.orden_idll, cfg.orden_idlll, cfg.nombre_shell
            ,sal.id_solicitud, sal.id_plantilla
            ,sal.nombre_seccion
            ,cfg.actualiza_solicitud, cfg.actualiza_plantilla, cfg.actualiza_ruta_salida
      FROM rec_stage.batch2_shells_config cfg
      CROSS JOIN (SELECT id_solicitud, id_plantilla, nombre_seccion
                  FROM rec_stage.batch_salidas_campos
                  WHERE id_solicitud = P_ID_SOLICITUD
                  GROUP BY 1, 2, 3) sal
      WHERE cfg.iteracion = ''S''
        AND cfg.estado = ''S'') xx
ORDER BY 1 NULLS FIRST, 7 NULLS FIRST, 5 NULLS FIRST, 6 NULLS FIRST, 2 NULLS FIRST, 3 NULLS FIRST
WITH NO SCHEMA BINDING')
,(8, 'ITERADOR', 'TEMP1',
  'CREATE OR REPLACE VIEW rec_stage.temp1 AS
SELECT o.orden_id, o.orden_idll, o.orden_idlll, o.nombre_shell, o.id_solicitud, o.id_plantilla, o.seccion
      ,o.actualiza_solicitud, o.actualiza_plantilla, o.actualiza_ruta_salida
      ,ROW_NUMBER() OVER (PARTITION BY o.id_plantilla
                          ORDER BY o.orden_id NULLS FIRST, o.seccion NULLS FIRST, o.id_solicitud NULLS FIRST
                                  ,o.orden_idll NULLS FIRST, o.orden_idlll NULLS FIRST) AS consp
FROM rec_stage.orden_shell o
CROSS JOIN (SELECT COALESCE(MAX(cons), 0) AS seq FROM rec_stage.integrador_tmp) x
WHERE o.nombre_shell IN (''P0032_BATCH_GENERACUBO'', ''P0032_BATCH_GENERACUBO_PUNTO_INT'', ''P0032_BATCH_EXPL_DE_PUNTOS_DE_INT''
                        ,''P0034_CARGA_INSUMO_STANDARD'', ''P0034_EstandarizacionUbicacion'', ''P0034_UBICACION_ESTANDARIZADA''
                        ,''P0033_BATCH2_PROCESACUBOS'', ''P0033_BATCH2_EXPORT'', ''P0033_BATCH2_CUBOEXPORT''
                        ,''P0033_BATCH2_EXPORTPLANO'', ''P0033_BATCH2_EXPORTVERTPLANO'', ''P0033_BATCH2_EXPORTLOG''
                        ,''P0033_BATCH2_ESTADISTICAS'', ''P0033_BATCH2_CANTREPCANAL'', ''P0033_BATCH2_VALIDAR_ARCHIVOS''
                        ,''P0033_BATCH2_CANALCONTACTO'', ''P0033_BATCH2_ACTUALIZA_HISTORIA'')
WITH NO SCHEMA BINDING')
,(9, 'ITERADOR', 'INTEGRADOR_TMP',
  'INSERT INTO rec_stage.integrador_tmp
SELECT q.orden_id, q.orden_idll, q.orden_idlll, q.nombre_shell, q.id_solicitud, q.id_plantilla, q.seccion
      ,q.actualiza_solicitud, q.actualiza_plantilla, q.actualiza_ruta_salida, q.ooo
FROM (SELECT t.orden_id, t.orden_idll, t.orden_idlll, t.nombre_shell, t.id_solicitud, t.id_plantilla, t.seccion
            ,t.actualiza_solicitud, t.actualiza_plantilla, t.actualiza_ruta_salida
            ,x.sequ + ROW_NUMBER() OVER (ORDER BY t.id_plantilla NULLS FIRST, t.orden_id NULLS FIRST, t.seccion NULLS FIRST
                                                 ,t.id_solicitud NULLS FIRST, t.orden_idll NULLS FIRST, t.orden_idlll NULLS FIRST) AS ooo
            ,ROW_NUMBER() OVER (PARTITION BY t.id_plantilla, t.orden_id, t.seccion, t.id_solicitud, t.orden_idll, t.orden_idlll
                                ORDER BY t.id_plantilla NULLS FIRST) AS rn
      FROM rec_stage.temp1 t
      CROSS JOIN (SELECT COALESCE(MAX(cons), 0) AS sequ FROM rec_stage.integrador_tmp) x) q
WHERE q.rn = 1')
,(10, 'ITERADOR', 'BATCH2_SHELLS_PLANEJECUCION',
  'DROP TABLE IF EXISTS rec_stage.batch2_shells_planejecucion')
,(11, 'ITERADOR', 'BATCH2_SHELLS_PLANEJECUCION',
  'CREATE TABLE rec_stage.batch2_shells_planejecucion
(
    orden_id               INTEGER,
    id_solicitud           BIGINT,
    id_plantilla           BIGINT,
    nombre_seccion         VARCHAR(100),
    nombre_shell           VARCHAR(500),
    estado_ejecutado       CHAR(1),
    lote                   BIGINT,
    fecha_hora_inicio      TIMESTAMP,
    fecha_hora_fin         TIMESTAMP,
    estado_ejecucion       VARCHAR(100),
    log_archivo            VARCHAR(200),
    actualiza_solicitud    CHAR(1),
    actualiza_plantilla    CHAR(1),
    actualiza_ruta_salida  CHAR(1)
)
DISTSTYLE ALL
SORTKEY (orden_id)')
,(12, 'ITERADOR', 'BATCH2_SHELLS_PLANEJECUCION',
  'INSERT INTO rec_stage.batch2_shells_planejecucion
       (orden_id, id_solicitud, id_plantilla, nombre_seccion, nombre_shell
       ,actualiza_solicitud, actualiza_plantilla, actualiza_ruta_salida, estado_ejecucion)
SELECT cons, id_solicitud, id_plantilla, seccion, nombre_shell
      ,actualiza_solicitud, actualiza_plantilla, actualiza_ruta_salida, ''Pendiente''
FROM rec_stage.integrador_tmp
WHERE seccion <> ''SIN DATOS DE UBICACION''');
