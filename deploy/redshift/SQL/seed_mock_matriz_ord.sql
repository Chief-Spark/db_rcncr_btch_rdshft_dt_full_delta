-- ============================================================
-- seed_mock_matriz_ord.sql
-- SLCOPRBA-1355: matriz de arquetipos del ORDENAMIENTO (scoring).
-- UTF-8 sin BOM. Sin acentos a proposito. Nunca GRANT ... TO PUBLIC.
--
-- POR QUE UNA MATRIZ APARTE DE LA DE UNIFICACION:
--   los arquetipos de Unificacion estan disenados para sobrevivir a la
--   cascada de R1/R2/R3, y eso fija su forma. Los del Ordenamiento tienen que
--   caer en CATEGORIAS CONOCIDAS del scoring, que es otro criterio y a menudo
--   incompatible. Mezclarlos obligaria a cada arquetipo a servir a dos amos.
--
-- BANDA: ARQ 80..84 -> id_buro_persona 9800000..9840999,
--        cod_dw_persona_ubic 98000000..98409999.
--   Verificado que no la toca ninguna semilla, gate, validacion ni limpieza
--   de Unificacion: el ARQ mas alto ocupado es 73 (9730999 / 97309999) y el
--   gate por arquetipo acota BETWEEN 90100000 AND 97309999. El unico
--   predicado que la captura es el del tablero de Ordenamiento
--   (BETWEEN 9000000 AND 9999999), que es donde se quiere que aparezca.
--
-- DOS DECISIONES DE DISENO QUE CONVIENE ENTENDER
--
--   (1) cod_dw_ubic ES DISTINTO POR DIRECCION, al reves que en la matriz de
--       R2, donde las direcciones de una persona lo COMPARTEN. Alli se
--       comparte porque R1 y R2 agrupan por texto_ubicacion y necesitan que
--       coincida. Aqui el scoring de DIR agrupa por texto_ubicacion
--       (sp_ordenamiento_scoring_dir_edf.sql:54), de modo que dos direcciones
--       con el mismo texto COLAPSARIAN en una sola fila de score y no habria
--       ranking que certificar.
--
--   (2) LAS FECHAS SON RELATIVAS A CURRENT_DATE, no literales. El insumo
--       calcula meses_reporte con DATEDIFF(month, fecha, CURRENT_DATE)
--       (sp_ordenamiento_preparar_insumos_edf.sql:197), asi que un literal
--       como '2026-02-01' significa 8 meses hoy y 9 el mes que viene: el
--       score DERIVARIA CON EL CALENDARIO y un criterio que hoy pasa fallaria
--       solo. Con DATEADD(month, -15, CURRENT_DATE) el arquetipo mide
--       siempre 15 meses.
--
--       Y 15 esta elegido a proposito: los umbrales de las ventanas son 3, 6,
--       12 y 24 meses. 15 queda a 3 meses del mas cercano por abajo y a 9 por
--       arriba, de modo que ningun redondeo de borde puede moverlo de
--       categoria.
--
-- LA FECHA DE LA RELACION es '2026-03-01' = el watermark del mock tras el
--   FULL. El predicado del alcance es >= p_watermark, inclusivo
--   (preparar_insumos:87), asi que estos arquetipos entran en el FULL y
--   tambien en TODOS los DELTA. Es deliberado: score_ordenamiento NO se
--   trunca nunca -- su unica limpieza es el DELETE acotado por alcance -- de
--   modo que un arquetipo fuera de ventana conservaria para siempre el score
--   de la primera corrida.
--
-- LO QUE NO SE PUEDE EJERCITAR EN MOCK, corregido tras auditar las 47
-- caracteristicas contra el legado (SLCOPRBA-1355). La lista anterior daba
-- por bloqueadas CUATRO que no lo estaban: CEL014, CEL017, TEL017 y TEL010
-- no dependen de tipo_cuenta ni de sector_financiero en el legado, y ya
-- estan portadas. Lo que queda de verdad:
--   - sector_financiero: su catalogo se carga de la vista REAL del datashare
--     (02_catalogos_ordenamiento.sql:16) y no tiene variante mock, asi que
--     vale 0 para todo suscriptor inventado. Y en el legado no es una
--     bandera 0/1 sino un Sector en {CO,CC,RE,FI,OT} por cuenta, de modo que
--     DIR010FI y DIR013OT quedan con la forma correcta y el predicado
--     aproximado.
--   - coincidencia_geo esta fijada al literal 0 (preparar_insumos:303), pero
--     ya solo afecta a TEL020, que NO entra en la suma del score ni en el
--     legado (Caracteristicas.txt:2830-2834) ni aqui. Sin impacto.
--   - catalogo_tipo_cuenta_tel no contiene ningun 'POSPAGO'
--     (02_catalogos_ordenamiento.sql:27-32): CEL019 sigue constante.
--   - EMA020 necesita REC_VISTA.V_Ind_Efectiv_Orden_Peso_Email (:2713-2714)
--     y EMA021 el Cod_Tipo_Cta_Fte de CTA_TOTALES_PERSONAS_TMP3 (:2768-2769).
--   - DIR001IN y DIR004RO necesitan Portafolio_Nuevo (:2123, :2917) y
--     DIR034FI el importe CO00END005 de Insumo_Caracteristica (:2594-2595).
--
-- Y UN LIMITE QUE NO ES DE CATALOGO SINO DE SIEMBRA: el mock solo tiene dos
-- recencias, 0 y 8 meses (mas 15 en estos arquetipos), asi que las ventanas
-- (3,6] y >24 estan VACIAS para el universo general. Detalle en
-- docs/HALLAZGOS_RECENCIA_MOCK_ORDENAMIENTO.md.
-- ============================================================

-- ------------------------------------------------------------
-- Limpieza idempotente, acotada por banda. WHERE explicito en todos los
-- DELETE: lo exige la politica del pipeline [REDSHIFT:232].
-- ------------------------------------------------------------
DELETE FROM bdm_stage.relacion_persona_ubicacion
 WHERE id_buro_persona BETWEEN 9800000 AND 9849999;

DELETE FROM bdm_stage.ubicacion_estandarizada
 WHERE cod_dw_ubic BETWEEN 98000000 AND 98499999;

DELETE FROM bdm_stage.reporte_relacion_persona_ubica
 WHERE cod_dw_persona_ubic BETWEEN 98000000 AND 98499999;

DELETE FROM bdm_stage.contacto_canal
 WHERE id_buro_persona BETWEEN 9800000 AND 9849999;

-- ============================================================
-- ARQ 80 y 81 -- CANAL DIR: dos direcciones por persona
-- ------------------------------------------------------------
-- ARQ 80: las dos direcciones caen en LAS MISMAS categorias -> MISMO score.
--         Certifica que el desempate existe y es estable: sin el, el lugar
--         1 y el 2 se reparten al azar entre corridas.
-- ARQ 81: identico salvo que la segunda direccion es LAB en vez de RES.
--         Certifica que el lugar 1 es el de mayor score.
--
-- POR QUE tipo_ubicacion ES LA PALANCA: es la unica columna que mueve UNA
-- sola caracteristica (DIR017, scoring_dir_edf.sql:46-48). Cualquier otra
-- arrastra varias: tocar la fecha mueve a la vez DIR001IN, DIR004RO,
-- DIR007TO, DIR019 y DIR034FI, y entonces el score hay que recalcularlo
-- entero y el arquetipo deja de ser legible.
--
-- CATEGORIAS ESPERADAS (las dos direcciones, 1 reporte cada una, 1 solo
-- suscriptor, ninguno financiero, 15 meses de antiguedad):
--   DIR001IN=2  DIR004RO=2  DIR007TO=2  DIR009=2   DIR010FI=2  DIR013OT=5
--   DIR017=2 (RES) o 3 (LAB)            DIR019=1   DIR034FI=1
--   DIR050TO=3  DIR057=3  DIR059=3
--
-- SCORE ESPERADO:
--   ARQ 80, las dos direcciones ........ 556.9892
--   ARQ 81, direccion RES .............. 556.9892  -> lugar 2
--   ARQ 81, direccion LAB .............. 566.6667  -> lugar 1
--   La diferencia es (3-2)/3 * 29.03225806 = 9.677419, el salto mas pequeno
--   que admite el canal DIR. Sirve ademas de prueba de resolucion.
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (a.base + n.i) * 10 + d.k,          -- cod_dw_persona_ubic
  a.base + n.i,                       -- id_buro_persona
  a.base + n.i,                       -- cod_pin_persona
  (a.base + n.i) * 10 + d.k,          -- cod_dw_ubic DISTINTO por direccion
  (a.base + n.i) * 10 + d.k,
  CASE WHEN a.base = 9810000 AND d.k = 2 THEN 2 ELSE 1 END,  -- 2=LAB, 1=RES
  NULL,                               -- vigente: no es hija de unificacion
  d.k,
  CAST('2026-03-01' AS DATE),
  1356301,
  '1'
FROM      (SELECT 9800000 AS base UNION ALL SELECT 9810000) a
CROSS JOIN (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- El texto DEBE diferir entre las dos direcciones, o el scoring las agrupa
-- en una sola fila y no hay ranking.
INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento,
  latitud, longitud, tipo_ubicacion
)
SELECT
  (a.base + n.i) * 10 + d.k,
  CAST('ORD ARQ ' || CAST(a.base AS VARCHAR) || ' P' || CAST(n.i AS VARCHAR)
       || ' DIR' || CAST(d.k AS VARCHAR) AS VARCHAR(500)),
  11001, 'BOGOTA', 'CUNDINAMARCA', NULL, NULL, NULL
FROM      (SELECT 9800000 AS base UNION ALL SELECT 9810000) a
CROSS JOIN (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- Un reporte por direccion. Sin reporte no hay score DIR: el insumo une
-- contra stg_reporte_rpu con INNER JOIN (preparar_insumos:247-248).
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT
  (a.base + n.i) * 10 + d.k,
  7001,                                        -- un unico suscriptor -> DIR009 cat 2
  DATEADD(month, -15, CURRENT_DATE)
FROM      (SELECT 9800000 AS base UNION ALL SELECT 9810000) a
CROSS JOIN (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- ARQ 82 y 83 -- CANAL CEL
-- ------------------------------------------------------------
-- ARQ 82: dos celulares con prefijos DISTINTOS pero del MISMO valor de
--         catalogo -- 300 y 301, los dos COMCEL con valor 0.55
--         (02_catalogos_ordenamiento.sql:45). Mismo score: certifica el
--         desempate en un segundo canal.
--
-- ARQ 83 (RE-SEMBRADO, SLCOPRBA-1355): TRES celulares, no dos.
--
--   Antes enfrentaba 310 contra 322 y certificaba que CEL013 reconocia el
--   prefijo del operador. CEL013 NO MIRA EL OPERADOR: el legado la define
--   como el conteo de reportes de mas de 24 meses (Caracteristicas.txt:2449).
--   El arquetipo certificaba una invencion nuestra, asi que daba verde a un
--   modelo que ya no existe.
--
--   Ahora la palanca es CEL018, que SI depende del operador, y la eleccion
--   de prefijos es la que de verdad discrimina: el legado distingue
--   operadores por su VALOR de catalogo, no por estar dentro o fuera de el.
--
--     k=1  310  valor 0.62 -> 62.00 -> categoria 3   (sobrevive)
--     k=2  300  valor 0.55 -> 55.00 -> categoria 2   (sobrevive)
--     k=3  322  NO esta en el catalogo -> 0 -> FUERA DEL RANKING
--
--   El 322 se mantiene a proposito, pero ya no para medir un score: para
--   certificar LA COMPUERTA. Orden_Celular del legado filtra
--   "WHERE CEl018.CO01CEL018 <> 0" (:899) y nosotros ya la aplicamos
--   (scoring_cel_edf.sql, WHERE del SELECT final), de modo que de los TRES
--   celulares sembrados solo DOS tienen fila de score. Eso es F4-CEL-04.
--
--   Que el 322 entre en el insumo y no en el ranking no contamina el delta:
--   las tres filas comparten ventana (meses_reporte = 0), asi que CEL006 y
--   CEL020 valen lo mismo para las dos supervivientes -- 1/3 del total de la
--   persona -- y se cancelan.
--
-- DELTA ESPERADO ARQ 83: 38.3817 = (3-2)/4 * 153.52697100, el salto de una
--   sola categoria de CEL018. Las otras diez caracteristicas del canal son
--   identicas entre los dos celulares: misma fecha, mismo suscriptor, y
--   300 y 310 son los dos PREPAGO en catalogo_tipo_cuenta_tel, de modo que
--   CEL019 tampoco se mueve.
--
-- ARQ 82 no cambia: 300 y 301 valen los dos 0.55, los dos sobreviven a la
--   compuerta y empatan.
-- ============================================================

-- Cada persona de CEL/EMA necesita UNA direccion vigente: sin ella no entra
-- en stg_persona_dir_ganadora y sus contactos de canal se caen por el INNER
-- JOIN de preparar_insumos:218-219.
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (a.base + n.i) * 10 + 1, a.base + n.i, a.base + n.i,
  (a.base + n.i) * 10 + 1, (a.base + n.i) * 10 + 1, 1, NULL, 1,
  CAST('2026-03-01' AS DATE), 1356301, '1'
FROM      (SELECT 9820000 AS base UNION ALL SELECT 9830000
           UNION ALL SELECT 9840000) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento,
  latitud, longitud, tipo_ubicacion
)
SELECT
  (a.base + n.i) * 10 + 1,
  CAST('ORD ARQ ' || CAST(a.base AS VARCHAR) || ' P' || CAST(n.i AS VARCHAR)
       AS VARCHAR(500)),
  11001, 'BOGOTA', 'CUNDINAMARCA', NULL, NULL, NULL
FROM      (SELECT 9820000 AS base UNION ALL SELECT 9830000
           UNION ALL SELECT 9840000) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT (a.base + n.i) * 10 + 1, 7001, DATEADD(month, -15, CURRENT_DATE)
FROM      (SELECT 9820000 AS base UNION ALL SELECT 9830000
           UNION ALL SELECT 9840000) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- Los celulares. contact_type '9' es el discriminante del canal
-- (preparar_insumos:316). fecha_contacto a hoy -> meses_reporte = 0.
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor
)
SELECT
  (c.base + n.i) * 10 + 1, c.base + n.i, c.base + n.i, '9',
  c.prefijo || '1234567', NULL, 11001, CURRENT_DATE, 7001
FROM (
  SELECT 9820000 AS base, CAST('300' AS VARCHAR(3)) AS prefijo UNION ALL
  SELECT 9820000, '301' UNION ALL
  SELECT 9830000, '310' UNION ALL
  SELECT 9830000, '300' UNION ALL
  SELECT 9830000, '322'
) c
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- ARQ 84 -- CANAL EMA (RE-SEMBRADO, SLCOPRBA-1355)
-- ------------------------------------------------------------
-- ANTES: dos correos que solo diferian en el dominio, uno conocido y otro
-- no. Certificaba que el dominio conocido PERDIA 121.0207 puntos, porque
-- nuestro codigo lo metia en EMA014 y EMA017, las dos con beta negativa y
-- las dos dentro de la suma.
--
-- ESO YA NO EXISTE. EMA014 y EMA017 son cuotas de recencia en el legado
-- (Caracteristicas.txt:1724 y :1739) y asi estan portadas; el dominio vive
-- ahora en EMA018 (:1090-1094), que esta FUERA de la suma en el legado
-- (:2936, literal 0) y tambien en nuestro port. El dominio dejo de mover el
-- score -- que era justo lo que pedia F4-EMA-02 -- y el arquetipo se quedo
-- midiendo cero.
--
-- AHORA la palanca es EMA024 (:1406-1433): cuantos SUSCRIPTORES DISTINTOS
-- reportan cada correo, contra el mayor de la persona.
--
--   correo A  'arq.ord.multi'  2 filas, suscriptores 7001 y 7002 -> locals 2
--   correo B  'arq.ord.unico'  2 filas, suscriptor 7001 las dos  -> locals 1
--   divisor = MAX(locals) de la persona = 2
--   EMA024(A) = 100 -> categoria 4      EMA024(B) = 50 -> categoria 1
--   (umbrales :2234-2241, "<= 50 THEN 1 ELSE 4")
--
-- POR QUE DOS FILAS EN CADA CORREO Y NO UNA Y DOS: para que la palanca sea
-- UNA SOLA. Si un correo tuviera mas filas que el otro se moverian con el
-- las cuotas por ventana -- EMA010, EMA015, EMA016, EMA017 -- y el delta
-- dejaria de ser legible. Con dos filas cada uno, los dos correos comparten
-- numero de reportes, fecha y dominio, y solo difieren en cuantos
-- suscriptores distintos los reportan.
--
-- Las dos filas del correo B difieren en cod_dane_ciudad, que el insumo de
-- EMA ni siquiera selecciona: es solo para que no sean dos filas identicas.
--
-- DELTA ESPERADO ARQ 84: 100.8506 = (4-1)/4 * 134.46747820
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor
)
SELECT
  (9840000 + n.i) * 10 + 1, 9840000 + n.i, 9840000 + n.i, '10',
  e.buzon || CAST(n.i AS VARCHAR) || '@experian-arq.co',
  NULL, e.ciudad, CURRENT_DATE, e.suscriptor
FROM (
  -- El CAST de la primera rama fija el tipo del nodo UNION ALL.
  -- Los dos buzones miden lo mismo (13 caracteres) a proposito: EMA025 es un
  -- escalon sobre el largo del buzon y asi tampoco se mueve.
  SELECT CAST('arq.ord.multi' AS VARCHAR(40)) AS buzon,
         CAST(7001 AS INTEGER) AS suscriptor,
         CAST(11001 AS INTEGER) AS ciudad UNION ALL
  SELECT 'arq.ord.multi', 7002, 11001 UNION ALL
  SELECT 'arq.ord.unico', 7001, 11001 UNION ALL
  SELECT 'arq.ord.unico', 7001,  5001
) e
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;
