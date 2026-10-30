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


-- =====================================================================
-- (C) EL VEREDICTO: ¿defecto del port, o defecto de la MEDIDA?
--
-- Lanzado el bloque B en QA, los 35 grupos salieron TODOS con la misma
-- forma: dos filas con el MISMO complemento y una vacia. Eso NO es el
-- sitio 2 ('A6') ni el desempate de esc6 ('E6'): es exactamente lo que
-- esc1 -- complemento vacio -- existe para resolver, y esc1 SI esta
-- portado (resolvio 18.695 en el censo de QA).
--
-- PERO HAY UNA EXPLICACION ALTERNATIVA, Y LA PRODUCE LA PROPIA MEDIDA.
-- Grupo de tres: A con 'AP 208', B con 'AP 208', C vacia. Si esc1 unifica
-- C -> A, entonces C es hija (el censo la excluye por su sello) y A es
-- padre (lo excluye la rama PADRE), pero B NO ES NINGUNA DE LAS DOS. B
-- sigue en un grupo con dos complementos distintos, de modo que el CASE
-- del censo (sp_unificacion_regla2.sql:148-165) la clasifica
-- SIN_RESOLVER sin que nada haya fallado.
--
-- Es el hermano del defecto que ese mismo comentario ya documenta: en el
-- job #310 los PADRES inflaron la brecha de ~6.000 a 31.000 y por eso se
-- anadio la rama PADRE. Falto el HERMANO del padre.
--
-- COMO SE LEE EL RESULTADO:
--   todo en 'el grupo SI se unifico'  -> la medida sobra, el port esta
--                                        limpio, y hay que corregir el
--                                        CASE del censo, no la Regla 2.
--   algo en 'el grupo NO se unifico'  -> esc1 se salto esos grupos. Eso
--                                        es un defecto real y el bloque D
--                                        dice cuales son.
--
-- Base dba_rncr_batch, no dba.
-- =====================================================================

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
         i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio,
         MIN(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_min,
         MAX(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_max
  FROM   insumo i
),
grupos_brecha AS (
  SELECT DISTINCT g.id_buro_persona, g.texto_ubicacion,
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
),
por_grupo AS (
  SELECT b.id_buro_persona,
         b.texto_ubicacion,
         MAX(CASE WHEN u.cod_dw_persona_ubic IS NOT NULL THEN 1 ELSE 0 END) AS unificado
  FROM   insumo i
  JOIN   grupos_brecha b
    ON   b.id_buro_persona           = i.id_buro_persona
   AND   b.texto_ubicacion           = i.texto_ubicacion
   AND   b.cod_dw_tipo_ubicacion_dir = i.cod_dw_tipo_ubicacion_dir
   AND   b.cod_dw_municipio          = i.cod_dw_municipio
  LEFT JOIN bdm_datos.unificacion_direccion u
    ON   u.cod_dw_persona_ubic = i.cod_dw_persona_ubic
  GROUP  BY 1, 2
)
SELECT CASE WHEN unificado = 1
            THEN 'el grupo SI se unifico -> sobra la medida, no hay defecto'
            ELSE 'el grupo NO se unifico -> defecto real en esc1'
       END      AS veredicto,
       COUNT(*) AS grupos
FROM   por_grupo
GROUP  BY 1
ORDER  BY grupos DESC;


-- =====================================================================
-- (D) SOLO SI EL BLOQUE C SACA ALGO EN 'NO se unifico': cuales son.
--     Es la lista que habria que llevar a un ticket.
-- =====================================================================

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
         i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio,
         MIN(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_min,
         MAX(COALESCE(i.complemento, '')) OVER (
           PARTITION BY i.id_buro_persona, i.texto_ubicacion,
                        i.cod_dw_tipo_ubicacion_dir, i.cod_dw_municipio) AS comp_max
  FROM   insumo i
),
grupos_brecha AS (
  SELECT DISTINCT g.id_buro_persona, g.texto_ubicacion,
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
),
detalle AS (
  SELECT b.id_buro_persona,
         b.texto_ubicacion,
         i.cod_dw_persona_ubic,
         i.complemento,
         MAX(CASE WHEN u.cod_dw_persona_ubic IS NOT NULL THEN 1 ELSE 0 END)
           OVER (PARTITION BY b.id_buro_persona, b.texto_ubicacion) AS grupo_unificado
  FROM   insumo i
  JOIN   grupos_brecha b
    ON   b.id_buro_persona           = i.id_buro_persona
   AND   b.texto_ubicacion           = i.texto_ubicacion
   AND   b.cod_dw_tipo_ubicacion_dir = i.cod_dw_tipo_ubicacion_dir
   AND   b.cod_dw_municipio          = i.cod_dw_municipio
  LEFT JOIN bdm_datos.unificacion_direccion u
    ON   u.cod_dw_persona_ubic = i.cod_dw_persona_ubic
)
SELECT id_buro_persona,
       texto_ubicacion,
       COUNT(*) AS filas_del_grupo,
       LISTAGG(COALESCE(complemento, '(vacio)'), '  |  ')
         WITHIN GROUP (ORDER BY complemento) AS complementos
FROM   detalle
WHERE  grupo_unificado = 0
GROUP  BY 1, 2
ORDER  BY 1;
