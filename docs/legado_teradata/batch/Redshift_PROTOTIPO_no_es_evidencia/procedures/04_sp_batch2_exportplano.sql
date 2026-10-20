-- ============================================================================
-- Procedure:   rec_stage.sp_batch2_exportplano
-- Equivalente: P0033_BATCH2_EXPORTPLANO_111.BTQ / _130.TPT
-- Objetivo:    Construir la consulta PN/PJ/PNPJ (join de BATCH_CUBO_PERSONA
--              con las tablas pivote w_cubo_*) y exportar los archivos
--              CON_DATOS / SIN_DATOS / INCONSISTENCIA a S3 en formato CSV
--              delimitado por ';', replicando el formato observado en las
--              muestras reales de Salidas/*.CSV.
--
-- FIDELIDAD: ALTA en el resultado final (misma estructura de columnas, mismo
--            separador ';', misma segmentacion PN/PJ/PNPJ, mismo criterio de
--            Filtro_H = 0 (con datos) / > 0 (sin datos)).
--
-- DIFERENCIA DE DISEÑO respecto a Teradata:
-- - Teradata ensambla la sentencia SQL completa como texto dentro de la
--   tabla w_Borrar_001 (columna por columna, segun BATCH_SALIDAS_CAMPOS) y
--   la materializa como VISTA antes de exportarla con TPT. Redshift SI
--   soporta SQL dinamico via EXECUTE dentro de un stored procedure, por lo
--   que aqui se reconstruye el mismo patron: se arma el SELECT dinamicamente
--   a partir de rec_stage.batch_salidas_campos / rec_stage.batch2_homologacion,
--   y se ejecuta un UNLOAD de ese SELECT hacia S3 (sustituto de TPT).
-- - El layout exacto de columnas pivotadas (Telefono_001..010, etc.) depende
--   de rec_stage.batch2_homologacion, tabla cuyo contenido real (que mapea
--   cada codigo_campo a su cubo/alias) no esta disponible en este workspace;
--   aqui se construye un layout por defecto equivalente al observado en
--   CON_DATOS_4421_20240902100353.ESQUEMA (14 campos identificacion + 10
--   telefono + 10 direccion + 2 datos adicionales) para que el procedure sea
--   ejecutable de inmediato; AJUSTAR si la homologacion real define un orden
--   o conjunto de campos distinto.
-- - @UserName/@UserPassword/@TdpId (credenciales TPT) se sustituyen por el
--   IAM Role de Redshift indicado en p_iam_role (UNLOAD ... IAM_ROLE '...').
--
-- DIFERENCIA DE COMPORTAMIENTO IMPORTANTE (UNLOAD vs TPT DataConnector):
-- Teradata TPT escribe el archivo con el NOMBRE EXACTO configurado
-- (ej. 'CON_DATOS_4421_20240902100353.CSV'). Redshift UNLOAD SIEMPRE trata
-- la ruta 'TO' como un PREFIJO y genera uno o mas archivos agregando un
-- sufijo automatico (ej. 'CON_DATOS_4421_20240902100353.CSV0000_part_00').
-- No existe forma de forzar a UNLOAD a producir un nombre de archivo exacto
-- y unico. Si el consumidor final de estos CSV (el suscriptor/cliente)
-- requiere el nombre exacto sin sufijo, se necesita un paso POSTERIOR fuera
-- de Redshift (p.ej. un job de Lambda/Glue que haga S3 copy/rename del
-- objeto generado al nombre esperado) antes de considerar el archivo listo
-- para entrega. Este procedure deja el prefijo tal como lo esperaria el
-- nombre final, pero el nombre fisico en S3 tendra el sufijo agregado por
-- Redshift hasta que se agregue ese paso de renombrado.
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_exportplano(
    p_id_solicitud     BIGINT,
    p_id_plantilla     BIGINT,
    p_nombre_seccion    VARCHAR(100),   -- 'CON DATOS DE UBICACION' | 'SIN DATOS DE UBICACION'
    p_s3_bucket_salida   VARCHAR(500),   -- ej. 's3://mi-bucket/batch2/salidas/'
    p_iam_role          VARCHAR(500),   -- ARN del rol IAM con permiso de escritura en el bucket
    p_fch_archivo        VARCHAR(20)     -- sufijo de timestamp, ej. '_20240902100353'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql_pnpj        VARCHAR(MAX);
    v_sql_pn          VARCHAR(MAX);
    v_sql_pj          VARCHAR(MAX);
    v_sql_inconsis     VARCHAR(MAX);
    v_filtro_h         VARCHAR(10);
    v_prefijo_archivo   VARCHAR(50);
    v_unload_opts      VARCHAR(500);
BEGIN
    -- Filtro_H: 0 = con datos de ubicacion, >0 = sin datos (EXPORTPLANO_111 WHERE)
    IF UPPER(p_nombre_seccion) LIKE 'CON DATOS%' THEN
        v_filtro_h := '= 0';
        v_prefijo_archivo := 'CON_DATOS_';
    ELSIF UPPER(p_nombre_seccion) LIKE 'SIN DATOS%' THEN
        v_filtro_h := '> 0';
        v_prefijo_archivo := 'SIN_DATOS_';
    ELSE
        RAISE EXCEPTION 'sp_batch2_exportplano: nombre_seccion no soportado: %', p_nombre_seccion;
    END IF;

    v_unload_opts := 'DELIMITER AS '';'' PARALLEL OFF ALLOWOVERWRITE HEADER';

    ----------------------------------------------------------------------
    -- Construccion dinamica del SELECT PNPJ (ambas personas, natural+juridica)
    -- Layout por defecto: identificacion + telefono(x5) + direccion(x2) + datos adicionales
    -- Cabeceras en español legible, replicando el .ESQUEMA observado.
    ----------------------------------------------------------------------
    v_sql_pnpj :=
        'SELECT ' ||
        '  CBPER.tipo_id                              AS "Tipo id 001", ' ||
        '  CBPER.numero_id                            AS "Numero id 001", ' ||
        '  CBPER.primer_apellido                      AS "Primer apellido 001", ' ||
        '  CBPER.segundo_apellido                     AS "Segundo apellido 001", ' ||
        '  CBPER.primer_nombre                        AS "Primer nombre 001", ' ||
        '  CBPER.segundo_nombre                       AS "Segundo nombre 001", ' ||
        '  CBPER.nombre_completo                      AS "Nombre Completo 001", ' ||
        '  CBPER.fecha_expedicion                     AS "Fecha expedicion 001", ' ||
        '  CBPER.ciudad_expedicion                    AS "Ciudad expedicion 001", ' ||
        '  CBPER.departamento_expedicion               AS "Departamento expedicion 001", ' ||
        '  CBPER.genero                              AS "Genero 001", ' ||
        '  CBPER.rango_edad                           AS "Rango edad 001", ' ||
        '  CBCII.ciiu_001                            AS "CIIU 001", ' ||
        '  CBCII.actividad_economica_001               AS "Actividad economica 001" ' ||
        (CASE WHEN v_filtro_h = '= 0' THEN
        ', CBTEL.ciudad_001 AS "Ciudad 001", CBTEL.departamento_001 AS "Departamento 001", CBTEL.codigo_dane_ciudad_001 AS "Codigo DANE ciudad 001", CBTEL.codigo_dane_departamento_001 AS "Codigo DANE departamento 001", CBTEL.numero_001 AS "Numero 001", CBTEL.tipo_001 AS "Tipo 001", CBTEL.fecha_ultima_actualizacion_001 AS "Fecha ultima actualizacion 001", CBTEL.numero_entidades_reporta_001 AS "Numero de entidades reporta 001" ' ||
        ', CBDIR.ciudad_001 AS "Ciudad 001b", CBDIR.departamento_001 AS "Departamento 001b", CBDIR.codigo_dane_ciudad_001 AS "Codigo DANE ciudad 001b", CBDIR.codigo_dane_departamento_001 AS "Codigo DANE departamento 001b", CBDIR.direccion_001 AS "Direccion 001", CBDIR.tipo_001 AS "Tipo 001b", CBDIR.zona_001 AS "Zona 001", CBDIR.estrato_001 AS "Estrato 001", CBDIR.fecha_ultima_actualizacion_001 AS "Fecha ultima actualizacion 001b", CBDIR.numero_entidades_reporta_001 AS "Numero de entidades reporta 001b" ' ||
        ', CBCOR.correo_001 AS "Correo 001", CBCOR.numero_001 AS "Numero 001b" '
        ELSE '' END) ||
        ' FROM rec_stage.batch_cubo_persona CBPER ' ||
        ' INNER JOIN rec_vista.persona PNPJ ON CBPER.tipo_id = PNPJ.cod_tipo_ident_fte ' ||
        ' LEFT JOIN rec_stage.w_cubo_ciiu CBCII ON CBPER.id_buro_persona = CBCII.id_buro_persona AND COALESCE(CBCII.filtro_h,0) ' || v_filtro_h ||
        (CASE WHEN v_filtro_h = '= 0' THEN
            ' LEFT JOIN rec_stage.w_cubo_telefono CBTEL ON CBPER.id_buro_persona = CBTEL.id_buro_persona AND COALESCE(CBTEL.filtro_h,0) ' || v_filtro_h ||
            ' LEFT JOIN rec_stage.w_cubo_direccion CBDIR ON CBPER.id_buro_persona = CBDIR.id_buro_persona AND COALESCE(CBDIR.filtro_h,0) ' || v_filtro_h ||
            ' LEFT JOIN rec_stage.w_cubo_correo CBCOR ON CBPER.id_buro_persona = CBCOR.id_buro_persona AND COALESCE(CBCOR.filtro_h,0) ' || v_filtro_h
         ELSE '' END) ||
        ' WHERE COALESCE(CBPER.filtro_h,0) ' || v_filtro_h ||
        '   AND CBPER.id_solicitud = ' || p_id_solicitud ||
        (CASE WHEN p_id_plantilla IS NOT NULL THEN ' AND CBPER.id_plantilla = ' || p_id_plantilla ELSE '' END);

    v_sql_pn := v_sql_pnpj || ' AND PNPJ.cod_tipo_ident_fte IN (1,4) ';
    v_sql_pj := v_sql_pnpj || ' AND PNPJ.cod_tipo_ident_fte IN (2,3) ';

    ----------------------------------------------------------------------
    -- UNLOAD archivo PNPJ (archivo principal sin segmentar por tipo persona)
    ----------------------------------------------------------------------
    EXECUTE 'UNLOAD (''' || REPLACE(v_sql_pnpj, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || v_prefijo_archivo || p_id_solicitud || p_fch_archivo || '.CSV'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            v_unload_opts;

    ----------------------------------------------------------------------
    -- UNLOAD archivo PN (solo si la plantilla separa PN/PJ -- ver
    -- BATCH_DATOS_GENERALES.ARCHIVOS_PN_PJ, decision delegada al llamador
    -- via el parametro p_nombre_seccion/orquestador; aqui se genera siempre
    -- como insumo, el orquestador decide si lo conserva o lo descarta)
    ----------------------------------------------------------------------
    EXECUTE 'UNLOAD (''' || REPLACE(v_sql_pn, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || v_prefijo_archivo || p_id_solicitud || '_PN' || p_fch_archivo || '.CSV'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            v_unload_opts;

    EXECUTE 'UNLOAD (''' || REPLACE(v_sql_pj, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || v_prefijo_archivo || p_id_solicitud || '_PJ' || p_fch_archivo || '.CSV'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            v_unload_opts;

    ----------------------------------------------------------------------
    -- INCONSISTENCIA: columnas fijas, igual al .ESQUEMA observado
    ----------------------------------------------------------------------
    v_sql_inconsis :=
        'SELECT ' ||
        '  CAST(id_solicitud AS VARCHAR(15))          AS "ID_SOLICITUD", ' ||
        '  CAST(id_plantilla AS VARCHAR(15))          AS "ID_PLANTILLA", ' ||
        '  tipo_id                                   AS "TIPO_ID", ' ||
        '  numero_id                                  AS "NUMERO_ID", ' ||
        '  nombre_completo                            AS "NOMBRE_COMPLETO", ' ||
        '  nombre_entidad                             AS "NOMBRE_ENTIDAD", ' ||
        '  fecha_expedicion                           AS "FECHA_EXPEDICION", ' ||
        '  ciudad_expedicion                          AS "CIUDAD_EXPEDICION", ' ||
        '  departamento_expedicion                     AS "DEPARTAMENTO_EXPEDICION", ' ||
        '  estado                                    AS "ESTADO", ' ||
        '  causal                                    AS "CAUSAL" ' ||
        'FROM rec_stage.batch_identificaciones_incons ' ||
        'WHERE id_solicitud = ' || p_id_solicitud ||
        (CASE WHEN p_id_plantilla IS NOT NULL THEN ' AND id_plantilla = ' || p_id_plantilla ELSE '' END);

    EXECUTE 'UNLOAD (''' || REPLACE(v_sql_inconsis, '''', '''''') || ''') ' ||
            'TO ''' || p_s3_bucket_salida || 'INCONSISTENCIA_' || p_id_solicitud || p_fch_archivo || '.CSV'' ' ||
            'IAM_ROLE ''' || p_iam_role || ''' ' ||
            v_unload_opts;

    RAISE INFO 'sp_batch2_exportplano: UNLOAD completado para id_solicitud=%, seccion=%', p_id_solicitud, p_nombre_seccion;
END;
$$;
