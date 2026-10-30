-- =====================================================================
-- CAPTURA DE LA TERCERA VERTIENTE: datos reales en QA.
--
-- Son las MISMAS consultas que produjeron las cifras de DEV del job #491,
-- para que las dos columnas se puedan comparar de verdad. Cambiar una
-- consulta aqui y no alla hace que la comparacion mienta.
--
-- Se corre DESPUES del e2e real en QA, antes de que nada trunque las
-- tablas de staging.
--
-- OJO: DBeaver abre en la base 'dba', donde no existen bdm_datos ni
-- bdm_tempo. Cambiar a la base del pipeline (dba_rncr_batch).
--
-- El destino de estas cifras es la tabla de las tres vertientes de
-- SESION_NEGOCIO_E2E_RECONOCER.md y la pagina del artefacto.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. EL EMBUDO DE ENTRADA
--    DEV dio: 299.575 total · 221.383 bloqueadas (73,9%) · 78.192 entran
--    Las tres cifras tienen que sumar. Si no suman, hay una tercera rama
--    y hay que mirarla antes de presentar nada.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                 AS relaciones_total,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 1 THEN 1 ELSE 0 END) AS caen_por_bloqueada,
       SUM(CASE WHEN COALESCE(bloqueado,0) = 0 THEN 1 ELSE 0 END) AS entran,
       COUNT(DISTINCT cod_dw_persona_ubic)                      AS ubicaciones_fisicas
FROM   bdm_tempo.v_xpm_relacion_persona_ubicacion;


-- ---------------------------------------------------------------------
-- 2. LA CONCENTRACION EN EMPRESAS
--    Es el numero que sostiene el "no estamos botando el 74%".
--    DEV dio: 106 NIT con 134.357 relaciones (el 44,9% del total).
-- ---------------------------------------------------------------------
WITH por_persona AS (
  SELECT id_buro_persona, cod_tipo_ident_fte, COUNT(*) AS relaciones
  FROM   bdm_tempo.v_xpm_relacion_persona_ubicacion
  GROUP  BY 1, 2
)
SELECT cod_tipo_ident_fte                AS tipo_identificacion,
       COUNT(*)                          AS personas_con_mas_de_500,
       SUM(relaciones)                   AS relaciones_que_concentran
FROM   por_persona
WHERE  relaciones > 500
GROUP  BY 1
ORDER  BY relaciones_que_concentran DESC;


-- ---------------------------------------------------------------------
-- 3. UNIFICACION: cuantas resolvio y por que regla
--    DEV dio: 19 filas (R1 cero, R2 dos, R3 diecisiete).
-- ---------------------------------------------------------------------
SELECT unifica_atributos AS regla,
       COUNT(*)          AS filas
FROM   bdm_datos.unificacion_direccion
GROUP  BY 1
ORDER  BY 1;


-- ---------------------------------------------------------------------
-- 4. EL CENSO DE ESCENARIOS: la defensa de las 19 unificaciones
--    La fila que importa es BRECHA. En DEV dio CERO: ni un solo caso en
--    que existiera pareja posible y ningun escenario la resolviera.
--    Si en QA sale distinto de cero, ESO es un hallazgo y hay que mirarlo
--    antes de la sesion.
-- ---------------------------------------------------------------------
SELECT escenario,
       n_id,
       SUM(direcciones) AS direcciones,
       SUM(personas)    AS personas
FROM   bdm_datos.unif_escenario_censo
GROUP  BY 1, 2
ORDER  BY direcciones DESC;


-- ---------------------------------------------------------------------
-- 5. ORDENAMIENTO: los cuatro canales
--    DEV dio: DIR 64.393 · EMA 59.756 · CEL 48.493 · TEL 12.600
--             total 185.242 sobre 58.878 personas
--    lugar_max es lo que prueba que el ranking discrimina: en DEV llego
--    a 57 en correo. En mock nunca pasa de 2.
-- ---------------------------------------------------------------------
SELECT canal,
       COUNT(*)                            AS filas,
       COUNT(DISTINCT id_buro_persona)     AS personas,
       MAX(lugar)                          AS lugar_max
FROM   bdm_datos.score_ordenamiento
GROUP  BY 1
ORDER  BY filas DESC;

SELECT COUNT(*)                        AS scores_total,
       COUNT(DISTINCT id_buro_persona) AS personas_total
FROM   bdm_datos.score_ordenamiento;


-- ---------------------------------------------------------------------
-- 6. NOVEDADES: las siete tablas dominio
--    DEV dio 363.327 filas en total:
--      actividad economica 124.263 · ubicacion 60.452 ·
--      contactabilidad 60.452 · ubicacion agregada 59.282 ·
--      info basica 58.878 · punto de interes 0 · movilidad 0
--    Los dos ceros son dependencia del georreferenciador, no codigo que
--    falte. Si en QA salen distintos de cero, es noticia buena y hay que
--    contarla.
-- ---------------------------------------------------------------------
SELECT 'actividad economica' AS dominio, COUNT(*) AS filas,
       COUNT(DISTINCT numero_identificacion) AS personas
  FROM bdm_datos.mat_info_actividad_economica
UNION ALL
SELECT 'ubicacion',            COUNT(*), COUNT(DISTINCT info_basica)
  FROM bdm_datos.mat_info_ubicacion
UNION ALL
SELECT 'contactabilidad',      COUNT(*), NULL
  FROM bdm_datos.mat_info_contactabilidad
UNION ALL
SELECT 'ubicacion agregada',   COUNT(*), NULL
  FROM bdm_datos.mat_ubicacion_agregada
UNION ALL
SELECT 'info basica',          COUNT(*), COUNT(DISTINCT numero_identificacion)
  FROM bdm_datos.mat_info_basica
UNION ALL
SELECT 'punto de interes',     COUNT(*), NULL
  FROM bdm_datos.mat_info_punto_interes
UNION ALL
SELECT 'movilidad',            COUNT(*), NULL
  FROM bdm_datos.mat_info_movilidad
ORDER  BY filas DESC;


-- ---------------------------------------------------------------------
-- 7. LOS TIEMPOS, que es la comparacion que pidio Negocio
--    DEV dio: Unificacion 130 s · Ordenamiento 61 s · Novedades 70 s
--             cadena 263 s
--    Las tres tablas de control llevan el inicio y el fin de cada corrida.
-- ---------------------------------------------------------------------
--
--    Y ES TAMBIEN LA COMPARACION FULL CONTRA DELTA, SIN CONSULTA NUEVA: esta
--    consulta ya trae una fila por corrida con su 'modo' y sus segundos, de modo
--    que disparando el .val de FULL y detras el de DELTA (mismo nombre, cambia
--    'full' por 'delta') las dos filas salen aqui. El watermark se lee como
--    MAX(watermark_nuevo) WHERE estado='completado', SIN filtrar por lote
--    (16_sp_unificacion_ciclo.sql:160-169), asi que el DELTA si ve la frontera
--    que dejo el FULL aunque el lote del Framework sea otro.
--
--    OJO AL LEER LA DIFERENCIA, QUE ES LA TRAMPA: un DELTA lanzado detras del
--    FULL sobre dato que no se movio mide EL SUELO -- lo que cuesta confirmar
--    que no hay cambios --, no la eficiencia de una incremental real. Sin
--    cambios en origen solo entra la rama 'fecha IS NULL'. Presentarlo como
--    "el DELTA es N veces mas rapido" es la leccion de NOV-UB-12 otra vez: un
--    DELTA en cero no prueba que no haya cambios. La cifra de la incremental
--    CON cambios necesita que el datashare se mueva, y eso no lo controlamos.
--
--    Razon estructural por la que el DELTA es mas barato, independiente del
--    volumen: el FULL trunca unificacion_direccion en su paso 6
--    (16_sp_unificacion_ciclo.sql:204-214) y el DELTA no.
-- ---------------------------------------------------------------------
SELECT 'unificacion' AS proceso, corrida_id, lote, modo,
       fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
  FROM bdm_datos.unif_control
UNION ALL
SELECT 'ordenamiento', corrida_id, lote, modo, fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.ord_control
UNION ALL
SELECT 'novedades',    corrida_id, lote, modo, fecha_hora_inicio, fecha_hora_fin,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin)
  FROM bdm_datos.nov_control
ORDER  BY fecha_hora_inicio;

-- La cadena completa: del primer inicio al ultimo fin.
SELECT MIN(fecha_hora_inicio)                                  AS arranque,
       MAX(fecha_hora_fin)                                     AS cierre,
       DATEDIFF(second, MIN(fecha_hora_inicio), MAX(fecha_hora_fin)) AS cadena_segundos
FROM ( SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.unif_control
       UNION ALL
       SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.ord_control
       UNION ALL
       SELECT fecha_hora_inicio, fecha_hora_fin FROM bdm_datos.nov_control ) t;


-- ---------------------------------------------------------------------
-- 8. QUE LAS SIETE ETAPAS HAYAN QUEDADO EN 'completado'
--    Es el gate de que la corrida no se trago una excepcion en silencio.
--    Una etapa en 'fallido' con la tabla poblada es peor que un error:
--    el verde no lo dice.
-- ---------------------------------------------------------------------
SELECT corrida_id, etapa, estado,
       relaciones_entrada, personas_distintas,
       filas_altas, filas_cambios, filas_bajas,
       DATEDIFF(second, fecha_hora_inicio, fecha_hora_fin) AS segundos
FROM   bdm_datos.nov_control_etapa
ORDER  BY corrida_id, fecha_hora_inicio;

-- GEO corre en su propio bloque de excepcion y NO tumba la corrida.
-- Si el Lote queda en 'fallido', hay que decirlo en la sesion.
SELECT lote, estado, conteo_esperado, fase_fallo, ultimo_error
FROM   bdm_datos.geo_lote_control
ORDER  BY lote DESC
LIMIT  5;


-- =====================================================================
-- NOMBRES DE COLUMNA: VERIFICADOS CONTRA EL DDL (2026-10-30)
--
-- Este pie decia antes que los bloques 4, 7 y 8 usaban nombres tomados de la
-- bitacora y no leidos del DDL. Lo eran, y los TRES estaban mal: el bloque 4
-- murio en QA con 42703 ('casos' no existe en unif_escenario_censo) y los
-- otros dos habrian muerto detras. Corregidos contra el DDL:
--
--   unif_escenario_censo    casos        -> direcciones / personas
--   las tres *_control      fecha_inicio -> fecha_hora_inicio
--                           fecha_fin    -> fecha_hora_fin
--   nov_control_etapa       no tiene fase_fallo ni ultimo_error; lleva
--                           filas_altas / filas_cambios / filas_bajas
--   mat_info_actividad_economica   no tiene id_buro_persona; la persona es
--                           numero_identificacion
--
-- LA LECCION, Y ES LA MISMA DE SIEMPRE: un nombre de columna copiado de la
-- bitacora es una hipotesis. El motor para en el primer error, de modo que
-- un 42703 tapa a los tres que vienen detras. Se leen del DDL de una vez:
--
--   SELECT column_name, data_type FROM information_schema.columns
--    WHERE table_schema = 'bdm_datos' AND table_name = '<la tabla>'
--    ORDER BY ordinal_position;
-- =====================================================================
