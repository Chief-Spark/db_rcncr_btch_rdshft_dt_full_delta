-- ============================================================
-- CONSULTAS DE CONTROL DE LA VIA REAL
-- Para correr en DBeaver contra DEV, despues de un build que haya
-- ejecutado SQL/run_reconocer_e2e_real_full.sql (hoy: puesto 4 de deploy.par).
--
-- ANTES DE EJECUTAR NADA: en DBeaver la conexion abre en la base 'dba', donde
-- NO existen bdm_datos / bdm_tempo / bdm_stage. Cambiar a la base del
-- pipeline. Las del datashare (tres partes en el nombre) funcionan desde
-- cualquiera, y por eso enganan: parecen confirmar que la conexion esta bien.
--
-- EL DISCRIMINADOR ES EL LOTE, NO LA TABLA.
--   lote 1356301             -> via REAL (run_reconocer_e2e_real_full.sql:60)
--   lote 1356601/02/04       -> bateria MOCK (run_reconocer_e2e_mock_full_delta.sql:125,158,288)
-- Las cabeceras de control SI estan separadas -- el mock escribe
-- unif_control_mock, nov_control_mock y bdm_stage.mock_ord_control --, pero
-- DOS TABLAS DE SALIDA SON COMPARTIDAS: rpu_orden_prioridad y
-- score_ordenamiento, porque el mock reutiliza
-- sp_ordenamiento_consolidacion_edf. Ahi hay que filtrar (bloque 10).
--
-- CADA BLOQUE DICE QUE TIENE QUE SALIR. Un numero sin expectativa escrita no
-- se puede leer: es la leccion de que un DELTA en cero no prueba nada.
-- ============================================================


-- ============================================================
-- 1. LAS TRES CABECERAS: una fila por corrida y por proceso
-- Fuente: strct/11_ddl_unif_control.sql:28, 12_ddl_ord_control.sql:9,
--         31_ddl_nov_control.sql:55
--
-- QUE TIENE QUE SALIR: 2 filas por proceso y por build (el pipeline corre el
-- DPLY dos veces), las dos con estado 'completado' y modo 'FULL'. Si sale una
-- sola, la segunda pasada no llego; si sale 'en proceso', la corrida murio sin
-- cerrar y el watermark no se movio.
-- ============================================================
SELECT 'UNIFICACION' AS proceso, corrida_id, lote, modo, bootstrap, estado,
       watermark_anterior, watermark_nuevo,
       relaciones_entrada, personas_distintas, total_unificaciones AS salida,
       fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.unif_control
 WHERE lote = 1356301
UNION ALL
SELECT 'ORDENAMIENTO', corrida_id, lote, modo, bootstrap, estado,
       watermark_anterior, watermark_nuevo,
       contactos_entrada, personas_entrada, scores_generados,
       fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.ord_control
 WHERE lote = 1356301
UNION ALL
SELECT 'NOVEDADES', corrida_id, lote, modo, bootstrap, estado,
       watermark_anterior, watermark_nuevo,
       relaciones_entrada, personas_distintas, filas_mat_escritas,
       fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.nov_control
 WHERE lote = 1356301
 ORDER BY 1, 2;


-- ============================================================
-- 2. CONTINUIDAD DEL WATERMARK ENTRE CORRIDAS
-- El watermark sale del MAX del DATO, nunca del reloj
-- (16_sp_unificacion_ciclo.sql:375-392). Esta consulta verifica la cadena.
--
-- QUE TIENE QUE SALIR: 'OK' en toda fila salvo la primera de cada proceso
-- (que es bootstrap y no tiene de donde encadenar). Un 'ROTO' dice que una
-- corrida partio de un watermark que no es el que dejo la anterior.
-- Un 'RETROCEDE' es el riesgo latente ya anotado: un FULL que baja la
-- frontera porque el dato de encima desaparecio.
-- ============================================================
WITH c AS (
  SELECT 'UNIFICACION' AS proceso, corrida_id, modo, estado,
         watermark_anterior, watermark_nuevo
    FROM bdm_datos.unif_control WHERE lote = 1356301
  UNION ALL
  SELECT 'ORDENAMIENTO', corrida_id, modo, estado, watermark_anterior, watermark_nuevo
    FROM bdm_datos.ord_control WHERE lote = 1356301
  UNION ALL
  SELECT 'NOVEDADES', corrida_id, modo, estado, watermark_anterior, watermark_nuevo
    FROM bdm_datos.nov_control WHERE lote = 1356301
)
SELECT proceso, corrida_id, modo, estado, watermark_anterior, watermark_nuevo,
       LAG(watermark_nuevo) OVER (PARTITION BY proceso ORDER BY corrida_id) AS wm_nuevo_anterior,
       CASE
         WHEN LAG(watermark_nuevo) OVER (PARTITION BY proceso ORDER BY corrida_id) IS NULL
              THEN 'PRIMERA'
         WHEN watermark_anterior = LAG(watermark_nuevo) OVER (PARTITION BY proceso ORDER BY corrida_id)
              THEN 'OK'
         WHEN watermark_anterior < LAG(watermark_nuevo) OVER (PARTITION BY proceso ORDER BY corrida_id)
              THEN 'RETROCEDE'
         ELSE 'ROTO'
       END AS cadena
  FROM c
 ORDER BY proceso, corrida_id;


-- ============================================================
-- 3. ETAPAS DE NOVEDADES: los siete dominios, por corrida
-- Fuente: strct/31_ddl_nov_control.sql:91. Nombres de etapa en
-- pgm/sp_novedades_ciclo_edf.sql:85,118,150,196,230,269,302.
--
-- QUE TIENE QUE SALIR: 7 filas por corrida, las siete 'completado'.
-- filas_bajas TIENE que ser 0 en las siete: FLAG_OP = 'E' es codigo muerto en
-- el legado (Novedad.sql:7590-7594 contra :8393), y es lo que verifican
-- NOV-UB-13 y NOV-UB-15. Una baja distinta de 0 es una divergencia, no un
-- dato.
-- OJO AL PATRON DEL #413: relaciones_entrada = 0 con estado 'completado' NO
-- es un exito, es una rama que no recogio nada. Hay que explicar cada cero.
-- ============================================================
SELECT corrida_id, etapa, estado,
       relaciones_entrada, personas_distintas,
       filas_altas, filas_cambios, filas_bajas,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos,
       CASE WHEN estado <> 'completado'        THEN 'REVISAR: etapa no cerro'
            WHEN COALESCE(filas_bajas, 0) > 0  THEN 'REVISAR: baja imposible en el AS-IS'
            WHEN COALESCE(relaciones_entrada, 0) = 0 THEN 'REVISAR: rama vacia'
            ELSE 'ok'
       END AS lectura
  FROM bdm_datos.nov_control_etapa
 WHERE lote = 1356301
 ORDER BY corrida_id, etapa;


-- ============================================================
-- 4. ETAPAS DE UNIFICACION Y DE ORDENAMIENTO
-- Fuente: strct/11_ddl_unif_control.sql:62, 12_ddl_ord_control.sql:32
--
-- QUE TIENE QUE SALIR en Unificacion: regla1, las etapas de la cascada de la
-- Regla 2 en su orden (esc1/esc2, esc3, motor NIT, esc4, motor NIVEL, motor
-- DIF, esc5, motor CRUCE, esc6), geo y regla3. La etapa 'geo' puede salir
-- 'fallido' y eso NO tumba la corrida: GEO no es bloqueante por decision de
-- negocio. Lo que hay que mirar entonces es el bloque 6.
-- ============================================================
SELECT 'UNIFICACION' AS proceso, corrida_id, etapa, estado,
       relaciones_entrada AS entrada,
       unificaciones_producidas AS salida,
       candidatos_geo_exportados, candidatos_geo_cargados,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.unif_control_etapa
 WHERE lote = 1356301
UNION ALL
SELECT 'ORDENAMIENTO', corrida_id, etapa, estado,
       filas_entrada, filas_salida, NULL, NULL,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.ord_control_etapa
 WHERE lote = 1356301
 ORDER BY 1, 2, 3;


-- ============================================================
-- 5. LAS SIETE TABLAS DOMINIO: filas y personas
-- Es LA medida contra la meta del proyecto.
--
-- QUE TIENE QUE SALIR (referencia del job #491):
--   mat_info_actividad_economica  124.263 filas / 58.512 personas
--   mat_info_ubicacion             60.452 /  55.259
--   mat_info_contactabilidad       60.452 /  55.259
--   mat_ubicacion_agregada         59.282 /  55.259
--   mat_info_basica                58.878 /  58.878   <- una fila por persona
--   mat_info_punto_interes              0
--   mat_info_movilidad                  0
--
-- POR QUE INFO BASICA DA MAS PERSONAS QUE LAS OTRAS TRES, Y NO ES UN DEFECTO:
-- el legado arranca Info basica de la RPU ENTERA (Novedad.sql:2266-2267),
-- mientras Ubicacion, Ubicacion agregada y Contactabilidad filtran ademas por
-- no bloqueada, no unificada y orden de prioridad no nulo. 58.878 - 55.259 =
-- 3.619 es exactamente esa diferencia, y el bloque 9 la descompone.
-- ============================================================
--
-- Y UN AVISO QUE HAY QUE LEER ANTES DE COMPARAR COLUMNAS: LA LLAVE DE PERSONA
-- NO SE LLAMA IGUAL EN LAS SIETE, Y DOS NO LA TIENEN.
--   mat_info_ubicacion, mat_info_basica      -> id
--   mat_info_actividad_economica, movilidad  -> info_basica_id
--   mat_ubicacion_agregada                   -> info_basica
--   mat_info_contactabilidad                 -> NO HAY. Su columna id es la
--      llave del evento de gestion y sale NULL siempre (36_ddl_nov_contactabilidad.sql:93);
--      el grano es ubicacion_id.
--   mat_info_punto_interes                   -> NO HAY. El grano es ubicacion_id
--      (= cod_dw_ubic) y su id es un FNV_HASH de la llave 1:N.
-- Un COUNT(DISTINCT id) uniforme sobre las siete daria 0 en contactabilidad y
-- un numero sin sentido en punto de interes.
SELECT 'mat_info_ubicacion' AS tabla, COUNT(*) AS filas,
       COUNT(DISTINCT id) AS personas, NULL AS ubicaciones
  FROM bdm_datos.mat_info_ubicacion
UNION ALL SELECT 'mat_info_actividad_economica', COUNT(*),
       COUNT(DISTINCT info_basica_id), NULL
  FROM bdm_datos.mat_info_actividad_economica
UNION ALL SELECT 'mat_ubicacion_agregada', COUNT(*),
       COUNT(DISTINCT info_basica), NULL
  FROM bdm_datos.mat_ubicacion_agregada
UNION ALL SELECT 'mat_info_contactabilidad', COUNT(*),
       NULL, COUNT(DISTINCT ubicacion_id)
  FROM bdm_datos.mat_info_contactabilidad
UNION ALL SELECT 'mat_info_basica', COUNT(*), COUNT(DISTINCT id), NULL
  FROM bdm_datos.mat_info_basica
UNION ALL SELECT 'mat_info_punto_interes', COUNT(*),
       NULL, COUNT(DISTINCT ubicacion_id)
  FROM bdm_datos.mat_info_punto_interes
UNION ALL SELECT 'mat_info_movilidad', COUNT(*),
       COUNT(DISTINCT info_basica_id), NULL
  FROM bdm_datos.mat_info_movilidad
 ORDER BY 2 DESC;


-- ============================================================
-- 6. CONCILIACION: lo que la etapa DIJO contra lo que la tabla TIENE
-- Este es el bloque que caza el fallo peor de todos -- la etapa en
-- 'completado' sobre una tabla vacia --, que es justo el modo en que GEO
-- estuvo roto en silencio durante dos jobs.
--
-- QUE TIENE QUE SALIR: 'ok' en los cinco dominios poblados. Un
-- 'ETAPA VERDE Y TABLA VACIA' es un defecto aunque el build salga verde.
-- ============================================================
WITH ult AS (
  SELECT MAX(corrida_id) AS corrida_id FROM bdm_datos.nov_control WHERE lote = 1356301
), etapa AS (
  SELECT e.etapa, e.estado, e.filas_altas, e.filas_cambios, e.personas_distintas
    FROM bdm_datos.nov_control_etapa e JOIN ult u ON u.corrida_id = e.corrida_id
), tabla AS (
  SELECT 'ubicacion' AS etapa, COUNT(*) AS filas FROM bdm_datos.mat_info_ubicacion
  UNION ALL SELECT 'actividad_economica', COUNT(*) FROM bdm_datos.mat_info_actividad_economica
  UNION ALL SELECT 'ubi_agregada',        COUNT(*) FROM bdm_datos.mat_ubicacion_agregada
  UNION ALL SELECT 'contactabilidad',     COUNT(*) FROM bdm_datos.mat_info_contactabilidad
  UNION ALL SELECT 'info_basica',         COUNT(*) FROM bdm_datos.mat_info_basica
  UNION ALL SELECT 'punto_interes',       COUNT(*) FROM bdm_datos.mat_info_punto_interes
  UNION ALL SELECT 'movilidad',           COUNT(*) FROM bdm_datos.mat_info_movilidad
)
SELECT t.etapa, e.estado, e.personas_distintas,
       e.filas_altas, e.filas_cambios, t.filas AS filas_en_tabla,
       CASE WHEN e.estado = 'completado' AND t.filas = 0 THEN 'ETAPA VERDE Y TABLA VACIA'
            WHEN e.estado IS NULL                        THEN 'LA ETAPA NO CORRIO'
            WHEN e.estado <> 'completado'                THEN 'ETAPA NO CERRO'
            ELSE 'ok'
       END AS lectura
  FROM tabla t
  LEFT JOIN etapa e ON e.etapa = t.etapa
 ORDER BY t.filas DESC;


-- ============================================================
-- 7. GEO: el unico sitio donde el fallo no tumba el build
-- Fuente: strct/03_ddl_geo.sql:42
--
-- QUE TIENE QUE SALIR HOY: un Lote por corrida en estado 'fallido' con
-- fase_fallo = 'exportacion' y ultimo_error nombrando el rol IAM
-- rcncr-batch-redshift-geo. Eso es el bloqueo de permisos conocido y es
-- ESPERADO en DEV, no un defecto del port.
--
-- LO QUE SERIA UN DEFECTO: cero filas. Significaria que el export no llego
-- ni a crear el Lote -- que es como estuvo roto hasta el #484, por los dos
-- EXISTS correlacionados contra una vista del datashare.
-- ============================================================
SELECT lote, corrida_id, estado, fase_fallo,
       conteo_esperado, conteo_cargado, intentos, max_reintentos, ambiente,
       LEFT(ultimo_error, 160) AS error,
       fecha_exportacion, fecha_carga
  FROM bdm_datos.geo_lote_control
 ORDER BY COALESCE(fecha_actualizacion, fecha_exportacion) DESC
 LIMIT 40;


-- ============================================================
-- 8. ORDENAMIENTO: censo de alcance y las dos tablas de hash
-- Fuente: strct/12_ddl_ord_control.sql:117 (censo), :187 (ubicacion), :237 (cuenta)
--
-- QUE TIENE QUE SALIR en el censo: alcance_filas = alcance_personas (es lo
-- que exige F1-03), stg_residuales = 0 (F1-05). Las cuatro por_* en NULL NO
-- son un descuido: NULL dice "no hay senal con la que medir", y 0 diria "la
-- busque y no habia".
--
-- Y UNA EXPECTATIVA QUE CONVIENE SABER DE ANTEMANO: cuenta_atributo_hash sale
-- en 0 en la via real, y es correcto. v_xpm_cuenta es un stub de cero filas a
-- proposito (04_vistas_insumo_ordenamiento_edf_views.sql), hasta verificar la
-- llave de xpm_bestaccounts. Un 0 ahi no es un fallo de la Fase 2.
-- ============================================================
SELECT corrida_id, lote, modo, watermark_usado, watermark_origen,
       alcance_filas, alcance_personas,
       por_ubicacion, por_unificacion, por_cuenta,
       por_estandarizacion, por_bloqueo, por_comportamiento,
       fuera_ventana_total, fuera_ventana_dentro, stg_residuales,
       CASE WHEN alcance_filas <> alcance_personas THEN 'REVISAR: fan-out en el alcance'
            WHEN COALESCE(stg_residuales, 0) <> 0  THEN 'REVISAR: staging sin limpiar'
            ELSE 'ok'
       END AS lectura
  FROM bdm_datos.ord_alcance_censo
 WHERE lote = 1356301
 ORDER BY corrida_id;

SELECT 'ubicacion_atributo_hash' AS tabla,
       COUNT(*) AS filas,
       COUNT(DISTINCT cod_dw_persona_ubic) AS ubicaciones,
       COUNT(DISTINCT id_buro_persona) AS personas,
       SUM(CASE WHEN LENGTH(TRIM(cod_dw_hash)) <> 32 THEN 1 ELSE 0 END) AS hash_mal_formado,
       SUM(CASE WHEN tipo_persona IS NULL THEN 1 ELSE 0 END) AS sin_tipo_persona
  FROM bdm_datos.ubicacion_atributo_hash
 WHERE lote = 1356301
UNION ALL
SELECT 'cuenta_atributo_hash', COUNT(*), COUNT(DISTINCT cod_dw_cta),
       COUNT(DISTINCT id_buro_persona),
       SUM(CASE WHEN LENGTH(TRIM(cod_dw_hash)) <> 32 THEN 1 ELSE 0 END), NULL
  FROM bdm_datos.cuenta_atributo_hash
 WHERE lote = 1356301;


-- ============================================================
-- 9. DE DONDE SALEN LAS 3.619 PERSONAS DE DIFERENCIA
-- Descompone el universo de la RPU en los tres filtros que Ubicacion aplica y
-- que Info basica no. Si la suma de los tres excluidos no explica la
-- diferencia, entonces SI hay algo que mirar.
--
-- QUE TIENE QUE SALIR: personas_rpu = 58.878 (el universo de Info basica), y
-- personas_tras_filtros = 55.259 (el de los otros tres dominios).
-- ============================================================
-- 9a. El universo crudo y las dos banderas que lo recortan.
-- OJO: orden_prioridad de ESTA vista es un ROW_NUMBER y nunca es nulo
-- (02_vistas_insumo_edf_views.sql:328-331). El filtro de la etapa 1 de
-- Novedades mira bdm_datos.rpu_orden_prioridad, que es otra tabla y la
-- escribe el Ordenamiento; por eso va aparte, en 9c.
SELECT COUNT(DISTINCT id_buro_persona) AS personas_rpu,
       COUNT(*)                        AS filas_rpu,
       COUNT(DISTINCT CASE WHEN COALESCE(bloqueado, 0) <> 0
                           THEN id_buro_persona END) AS con_alguna_bloqueada,
       COUNT(DISTINCT CASE WHEN COALESCE(ind_unificacion, 0) = 1
                           THEN id_buro_persona END) AS con_alguna_unificada
  FROM bdm_tempo.v_xpm_relacion_persona_ubicacion;

-- 9b. La diferencia, nombrada: personas que estan en Info basica y no en
-- Ubicacion. Tiene que dar 3.619 contra los numeros del #491.
SELECT COUNT(*) AS en_basica_y_no_en_ubicacion
  FROM ( SELECT DISTINCT id FROM bdm_datos.mat_info_basica ) b
  LEFT JOIN ( SELECT DISTINCT id FROM bdm_datos.mat_info_ubicacion ) u
    ON u.id = b.id
 WHERE u.id IS NULL;

-- 9c. Y POR QUE quedaron fuera esas personas, repartidas por motivo.
-- Si la suma de los motivos no cubre el total de 9b, queda un resto sin
-- explicar y ESO si es trabajo: seria gente que la etapa 1 descarta por una
-- razon que no esta en la lista.
WITH fuera AS (
  SELECT b.id
    FROM ( SELECT DISTINCT id FROM bdm_datos.mat_info_basica ) b
    LEFT JOIN ( SELECT DISTINCT id FROM bdm_datos.mat_info_ubicacion ) u
      ON u.id = b.id
   WHERE u.id IS NULL
), rpu AS (
  SELECT id_buro_persona,
         MAX(COALESCE(bloqueado, 0))      AS alguna_bloqueada,
         MIN(COALESCE(bloqueado, 1))      AS todas_bloqueadas,
         MAX(COALESCE(ind_unificacion,0)) AS alguna_unificada,
         MIN(COALESCE(ind_unificacion,0)) AS todas_unificadas
    FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
   GROUP BY id_buro_persona
), pri AS (
  SELECT DISTINCT id_buro_persona FROM bdm_datos.rpu_orden_prioridad
   WHERE orden_prioridad IS NOT NULL
)
SELECT COUNT(*) AS personas_fuera,
       SUM(CASE WHEN r.todas_bloqueadas = 1 THEN 1 ELSE 0 END) AS todas_sus_ubic_bloqueadas,
       SUM(CASE WHEN r.todas_unificadas = 1 THEN 1 ELSE 0 END) AS todas_sus_ubic_unificadas,
       SUM(CASE WHEN p.id_buro_persona IS NULL THEN 1 ELSE 0 END) AS sin_orden_prioridad,
       SUM(CASE WHEN r.id_buro_persona IS NULL THEN 1 ELSE 0 END) AS NI_SIQUIERA_EN_LA_RPU
  FROM fuera f
  LEFT JOIN rpu r ON r.id_buro_persona = f.id
  LEFT JOIN pri p ON p.id_buro_persona = f.id;


-- ============================================================
-- 10. CONTAMINACION MOCK EN LAS DOS TABLAS COMPARTIDAS
-- rpu_orden_prioridad y score_ordenamiento las escriben las DOS vias, porque
-- el mock reutiliza sp_ordenamiento_consolidacion_edf, y la consolidacion solo
-- borra por el alcance de su propia corrida.
--
-- QUE TIENE QUE SALIR: filas en las dos bandas. La banda mock
-- (9.000.000..9.999.999) es residuo de la bateria y NO es un defecto -- esta
-- documentado en run_reconocer_e2e_real_full.sql:40-43 --, pero cualquier
-- consulta de negocio sobre estas dos tablas tiene que excluirla.
-- ============================================================
SELECT CASE WHEN id_buro_persona BETWEEN 9000000 AND 9999999
            THEN 'banda mock' ELSE 'real' END AS origen,
       canal,
       COUNT(*) AS filas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max,
       MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento
 GROUP BY 1, 2
 ORDER BY 1, 2;

SELECT CASE WHEN id_buro_persona BETWEEN 9000000 AND 9999999
            THEN 'banda mock' ELSE 'real' END AS origen,
       COUNT(*) AS filas,
       COUNT(DISTINCT id_buro_persona) AS personas,
       SUM(CASE WHEN orden_prioridad IS NULL THEN 1 ELSE 0 END) AS sin_orden_prioridad
  FROM bdm_datos.rpu_orden_prioridad
 GROUP BY 1
 ORDER BY 1;


-- ============================================================
-- 11. UNIFICACION: la salida por lote
-- Fuente: strct/01_ddl_unificacion_direccion.sql:39
--
-- QUE TIENE QUE SALIR: filas del lote 1356301, con severidad y
-- unifica_atributos distribuidos. lote_actualizacion distinto de lote marca
-- las filas que una corrida posterior re-toco.
-- ============================================================
SELECT lote, lote_actualizacion, severidad, unifica_atributos,
       COUNT(*) AS filas,
       COUNT(DISTINCT cod_dw_persona_ubic) AS ubicaciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS direcciones_destino,
       MIN(fecha_unificacion) AS desde, MAX(fecha_unificacion) AS hasta
  FROM bdm_datos.unificacion_direccion
 GROUP BY 1, 2, 3, 4
 ORDER BY 1, 2, 3, 4;


-- ============================================================
-- 12. LA HIPOTESIS ABIERTA: con_fecha_exp = 861 de 58.878 (1,5%)
-- En el #484 eran 42.147 de 1,19 M. La bitacora lo dejo como hipotesis y no
-- como defecto: hace falta ESTE numero para cerrarla.
--
-- Y HAY UNA SEGUNDA EXPLICACION POSIBLE QUE LA PRIMERA CONSULTA NO VE.
-- v_xpm_persona_basica elige UNA identificacion por persona con un
-- ROW_NUMBER que ordena por officialsourcevalidationstatus y luego por index
-- (02_vistas_insumo_edf_views.sql:903-912). Si la identificacion validada no
-- lleva issuedate y otra de la misma persona si, el ranking se COME la fecha.
--
-- COMO SE LEE EL RESULTADO:
--   personas_con_alguna_fecha ~= 861   -> el dato no existe. Hipotesis cerrada,
--                                         no hay nada que arreglar.
--   personas_con_alguna_fecha >> 861   -> el ranking esta descartando fechas.
--                                         Es un defecto nuestro y hay que
--                                         decidir si la cascada de prioridad
--                                         debe preferir la que trae fecha.
-- ============================================================
WITH rpu AS (
  SELECT DISTINCT id_buro_persona
    FROM bdm_tempo.v_xpm_relacion_persona_ubicacion
), ident AS (
  SELECT xpm.pin,
         FNV_HASH(xpm.pin) AS id_buro_persona,
         b0."bestidentifications.val.issuedate" AS issuedate,
         b0."bestidentifications.val.officialsourcevalidationstatus" AS validada,
         b0."index" AS idx
    FROM ds_dba_rncr_batch.edf_views.xpm xpm
    JOIN ds_dba_rncr_batch.edf_views.xpm_bestidentifications b0
      ON b0.id = xpm.bestidentifications
   WHERE b0."index" IS NOT NULL
)
SELECT COUNT(DISTINCT i.id_buro_persona) AS personas_rpu_con_identificacion,
       COUNT(DISTINCT CASE WHEN i.issuedate IS NOT NULL
                           THEN i.id_buro_persona END) AS personas_con_alguna_fecha,
       COUNT(DISTINCT CASE WHEN i.issuedate IS NOT NULL AND i.validada
                           THEN i.id_buro_persona END) AS personas_con_fecha_en_la_validada,
       COUNT(DISTINCT CASE WHEN i.issuedate IS NOT NULL AND NOT i.validada
                           THEN i.id_buro_persona END) AS personas_con_fecha_solo_en_otra
  FROM ident i
  JOIN rpu r ON r.id_buro_persona = i.id_buro_persona;

-- Y el contraste directo contra lo que la tabla final tiene.
SELECT COUNT(*) AS filas,
       COUNT(fecha_expedicion) AS con_fecha_exp,
       COUNT(lugar_expedicion) AS con_lugar_exp,
       COUNT(numero_identificacion) AS con_documento,
       COUNT(nombre_completo) AS con_nombre,
       COUNT(tipo_identificacion) AS con_tipo_ident,
       SUM(CASE WHEN COALESCE(genero, '') = '' THEN 1 ELSE 0 END) AS genero_en_blanco,
       COUNT(pagina_web) + COUNT(mosaic_id) AS en_las_dos_bloqueadas
  FROM bdm_datos.mat_info_basica;


-- ============================================================
-- 13. CONTACTABILIDAD: contar filas NO es contar dominio resuelto
-- Diez de sus doce columnas salen en NULL porque no existe la fuente de
-- gestion (D-NOV-08). Un COUNT(*) de 60.452 esconde eso por completo.
--
-- QUE TIENE QUE SALIR: filas > 0 y la mayoria de las columnas en 0. Es el
-- estado conocido, y esta consulta existe para que nadie lea el conteo de
-- filas del bloque 5 como si el dominio estuviera cerrado.
-- ============================================================
SELECT COUNT(*) AS filas, COUNT(DISTINCT id) AS personas
  FROM bdm_datos.mat_info_contactabilidad;

SELECT COUNT(*)                        AS filas,
       COUNT(id)                       AS con_id,
       COUNT(contactabilidad)          AS con_contactabilidad,
       COUNT(fecha_ultimo_contacto)    AS con_fecha_ult_contacto,
       COUNT(fecha_gestion)            AS con_fecha_gestion,
       COUNT(mejor_dia_gestion)        AS con_mejor_dia,
       COUNT(mejor_hora_gestion)       AS con_mejor_hora,
       COUNT(reportado_por)            AS con_reportado_por,
       COUNT(sector)                   AS con_sector,
       COUNT(ubicacion_id)             AS con_ubicacion_id,
       COUNT(peso)                     AS con_peso,
       COUNT(mejor_resultado_3meses)   AS con_mejor_3m,
       COUNT(mejor_resultado_6meses)   AS con_mejor_6m
  FROM bdm_datos.mat_info_contactabilidad;
-- LAS TRES QUE TIENEN QUE TRAER DATO son con_fecha_ult_contacto,
-- con_reportado_por y con_ubicacion_id, y las dos primeras CON OTRA SEMANTICA
-- que la del legado: fecha_ultimo_contacto es ContactEventLastUpdated y
-- reportado_por es quien REPORTO, no quien gestiono
-- (36_ddl_nov_contactabilidad.sql:94,99). Las otras nueve en 0 es el estado
-- conocido y documentado (D-NOV-08), no un defecto a investigar.
