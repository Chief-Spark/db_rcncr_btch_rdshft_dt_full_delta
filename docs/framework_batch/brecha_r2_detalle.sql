-- =====================================================================
-- QUE SON LAS 175 DE LA BRECHA: reconstruccion del cubo SIN_RESOLVER
--
-- POR QUE HACE FALTA RECONSTRUIR. unif_escenario_censo guarda SOLO
-- conteos. El detalle vive en bdm_tempo.stg_regla2_e2, que
-- sp_unificacion_regla2.sql:218 borra al cerrar la regla. Despues de la
-- corrida no hay a quien preguntarle cuales eran.
--
-- QUE REPLICA. El mismo CASE del censo (sp_unificacion_regla2.sql:148-165):
-- una direccion es BRECHA si en su grupo hay DOS complementos distintos
-- -- MIN <> MAX sobre el PARTITION BY de cuatro columnas -- y no quedo
-- sellada por ningun escenario ni es el padre de una unificacion.
--
-- Las fuentes y los JOIN salen de sp_unificacion_r2_preparar_insumo.sql:41-59,
-- literal, incluido el alias ubi.cod_dw_ciudad AS cod_dw_municipio.
--
-- LO QUE ESTA CONSULTA NO ES, Y HAY QUE DECIRLO AL LEERLA:
-- no reproduce el numero 175. Reconstruye sobre el estado de HOY, no sobre
-- el universo que la R2 vio en su momento -- la R1 ya habia resuelto parte,
-- y la ventana del DELTA acota. Sirve para ver la FORMA de los casos, que
-- es lo que decide si son las dos piezas del legado sin portar (el sitio 2
-- 'A6' y el desempate de esc6 'E6', las dos en CERO en el censo de QA) o
-- si es otra cosa. Si la forma no casa, ESO si es un defecto.
--
-- Base dba_rncr_batch, no dba.
-- =====================================================================

WITH insumo AS (
  SELECT rpu.cod_dw_persona_ubic,
         rpu.id_buro_persona,
         rpu.cod_dw_tipo_ubicacion_dir,
         ubi.texto_ubicacion,
         df.complemento,
         ubi.cod_dw_ciudad AS cod_dw_municipio
  FROM   bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
  JOIN   bdm_tempo.v_xpm_ubicacion_estandarizada ubi
    ON   rpu.cod_dw_ubic = ubi.cod_dw_ubic
  LEFT JOIN bdm_tempo.v_xpm_direccion_fisica df
    ON   rpu.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
  WHERE  COALESCE(rpu.bloqueado, 0) = 0
),
grupo AS (
  SELECT i.cod_dw_persona_ubic, i.id_buro_persona, i.texto_ubicacion,
         i.complemento, i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio,
         MIN(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_min,
         MAX(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_max,
         COUNT(*) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS filas_del_grupo
  FROM   insumo i
),
brecha AS (
  SELECT g.*
  FROM   grupo g
  LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
                FROM bdm_datos.unificacion_direccion )        hija
    ON   hija.cod_dw_persona_ubic = g.cod_dw_persona_ubic
  LEFT JOIN ( SELECT DISTINCT cod_dw_direccion_unificada
                FROM bdm_datos.unificacion_direccion )        padre
    ON   padre.cod_dw_direccion_unificada = g.cod_dw_persona_ubic
  WHERE  g.comp_min <> g.comp_max                 -- tenia pareja posible
    AND  hija.cod_dw_persona_ubic         IS NULL -- no se unifico
    AND  padre.cod_dw_direccion_unificada IS NULL -- ni es el padre de otra
)
-- (A) EL TAMANO
SELECT COUNT(*)                           AS direcciones_en_brecha,
       COUNT(DISTINCT id_buro_persona)    AS personas,
       COUNT(DISTINCT texto_ubicacion)    AS direcciones_distintas
FROM   brecha;


-- (B) LA FORMA: el grupo entero de los 40 primeros casos.
--     Es lo que de verdad responde la pregunta. Hay que mirar la columna
--     complementos y preguntarse por que NINGUN escenario los unio:
--
--       - si los complementos difieren en el NIVEL de la nomenclatura
--         (piso 2 contra apto 201, torre 1 contra bloque 1) -> es el
--         sitio 2 'A6', que no esta portado. Esperado.
--       - si son dos complementos igual de validos y habria que elegir por
--         frecuencia -> es el desempate de esc6 'E6', tampoco portado.
--         Esperado.
--       - si son el MISMO complemento escrito distinto, o uno vacio y otro
--         no -> eso lo tenia que haber cogido esc1 o esc2, que SI estan
--         portados. ESO es un defecto y hay que abrirlo.
WITH insumo AS (
  SELECT rpu.cod_dw_persona_ubic, rpu.id_buro_persona,
         rpu.cod_dw_tipo_ubicacion_dir, ubi.texto_ubicacion,
         df.complemento, ubi.cod_dw_ciudad AS cod_dw_municipio
  FROM   bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
  JOIN   bdm_tempo.v_xpm_ubicacion_estandarizada ubi
    ON   rpu.cod_dw_ubic = ubi.cod_dw_ubic
  LEFT JOIN bdm_tempo.v_xpm_direccion_fisica df
    ON   rpu.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
  WHERE  COALESCE(rpu.bloqueado, 0) = 0
),
grupo AS (
  SELECT i.cod_dw_persona_ubic, i.id_buro_persona, i.texto_ubicacion,
         i.complemento, i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio,
         MIN(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_min,
         MAX(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_max
  FROM   insumo i
),
brecha AS (
  SELECT g.id_buro_persona, g.texto_ubicacion,
         g.cod_dw_tipo_ubicacion_dir, g.cod_dw_municipio
  FROM   grupo g
  LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
                FROM bdm_datos.unificacion_direccion )        hija
    ON   hija.cod_dw_persona_ubic = g.cod_dw_persona_ubic
  LEFT JOIN ( SELECT DISTINCT cod_dw_direccion_unificada
                FROM bdm_datos.unificacion_direccion )        padre
    ON   padre.cod_dw_direccion_unificada = g.cod_dw_persona_ubic
  WHERE  g.comp_min <> g.comp_max
    AND  hija.cod_dw_persona_ubic         IS NULL
    AND  padre.cod_dw_direccion_unificada IS NULL
)
SELECT i.id_buro_persona,
       i.texto_ubicacion,
       COUNT(*)                               AS filas_del_grupo,
       LISTAGG(COALESCE(i.complemento, '(vacio)'), '  |  ')
         WITHIN GROUP (ORDER BY i.complemento) AS complementos
FROM   insumo i
JOIN ( SELECT DISTINCT id_buro_persona, texto_ubicacion,
              cod_dw_tipo_ubicacion_dir, cod_dw_municipio
         FROM brecha ) b
  ON  b.id_buro_persona           = i.id_buro_persona
  AND b.texto_ubicacion           = i.texto_ubicacion
  AND b.cod_dw_tipo_ubicacion_dir = i.cod_dw_tipo_ubicacion_dir
  AND b.cod_dw_municipio          = i.cod_dw_municipio
GROUP  BY 1, 2
ORDER  BY filas_del_grupo DESC, 1
LIMIT  40;
