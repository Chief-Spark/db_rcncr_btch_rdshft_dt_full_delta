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
 WHERE id_buro_persona BETWEEN 9800000 AND 9999999;

DELETE FROM bdm_stage.ubicacion_estandarizada
 WHERE cod_dw_ubic BETWEEN 98000000 AND 99999999;

DELETE FROM bdm_stage.reporte_relacion_persona_ubica
 WHERE cod_dw_persona_ubic BETWEEN 98000000 AND 99999999;

DELETE FROM bdm_stage.contacto_canal
 WHERE id_buro_persona BETWEEN 9800000 AND 9999999;

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
           UNION ALL SELECT 9840000 UNION ALL SELECT 9850000
           UNION ALL SELECT 9860000 UNION ALL SELECT 9890000
           UNION ALL SELECT 9900000
           -- SLCOPRBA-1355, segunda tanda: ARQ 91..95.
           UNION ALL SELECT 9910000 UNION ALL SELECT 9920000
           UNION ALL SELECT 9930000 UNION ALL SELECT 9940000
           UNION ALL SELECT 9950000) a
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
           UNION ALL SELECT 9840000 UNION ALL SELECT 9850000
           UNION ALL SELECT 9860000 UNION ALL SELECT 9890000
           UNION ALL SELECT 9900000
           -- SLCOPRBA-1355, segunda tanda: ARQ 91..95.
           UNION ALL SELECT 9910000 UNION ALL SELECT 9920000
           UNION ALL SELECT 9930000 UNION ALL SELECT 9940000
           UNION ALL SELECT 9950000) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT (a.base + n.i) * 10 + 1, 7001, DATEADD(month, -15, CURRENT_DATE)
FROM      (SELECT 9820000 AS base UNION ALL SELECT 9830000
           UNION ALL SELECT 9840000 UNION ALL SELECT 9850000
           UNION ALL SELECT 9860000 UNION ALL SELECT 9890000
           UNION ALL SELECT 9900000
           -- SLCOPRBA-1355, segunda tanda: ARQ 91..95.
           UNION ALL SELECT 9910000 UNION ALL SELECT 9920000
           UNION ALL SELECT 9930000 UNION ALL SELECT 9940000
           UNION ALL SELECT 9950000) a
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

-- ============================================================
-- ARQ 85 -- CANAL CEL: la palanca es CEL019 (SLCOPRBA-1355)
-- ------------------------------------------------------------
-- POR QUE UN ARQUETIPO NUEVO Y NO AMPLIAR EL 83: el 83 mueve CEL018 por el
-- prefijo del operador. Si la misma fila moviera ademas el tipo de cuenta,
-- el delta dejaria de ser legible -- seria la suma de dos saltos y no se
-- sabria cual fallo. Es la disciplina que la cabecera del ARQ 84 explica.
--
-- ESTE COPIA LA FORMA DEL ARQ 82, que ya esta medido en 0.0000: dos
-- celulares con prefijos 300 y 301, los dos de valor 0,55 en
-- catalogo_operador_ord_cel, misma fecha y mismo suscriptor. Al ser el
-- delta de ese par exactamente cero, cualquier diferencia que aparezca
-- aqui la introduce la unica columna que cambia: cod_tipo_cta_fte.
--
--   k=1  prefijo 300  tipo de cuenta '2'  -> catalogo valor 100 -> cat 3
--   k=2  prefijo 301  tipo de cuenta '1'  -> catalogo valor  10 -> cat 1
--   (umbrales :151 del legado, "< 35 -> 1, < 80 -> 2, >= 80 -> 3")
--
-- Los dos prefijos estan en catalogo_operador_ord_cel, de modo que cel018
-- no es 0 y la compuerta del canal deja pasar las dos filas.
--
-- DELTA ESPERADO ARQ 85: 93.3610 = (3-1)/4 * 186.72199170
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT
  (9850000 + n.i) * 10 + 1, 9850000 + n.i, 9850000 + n.i, '9',
  c.prefijo || '1234567', NULL, 11001, CURRENT_DATE, 7001, c.tipo_cta
FROM (
  -- El CAST de la primera rama fija el tipo del nodo UNION ALL.
  SELECT CAST('300' AS VARCHAR(3)) AS prefijo,
         CAST('2' AS VARCHAR(20))  AS tipo_cta UNION ALL
  SELECT '301', '1'
) c
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- ARQ 86 -- CANAL EMA: la palanca es EMA021 (SLCOPRBA-1355)
-- ------------------------------------------------------------
-- EMA021 es una suma de banderas por tipo de cuenta, 50/25/12/8/5
-- (Caracteristicas.txt:235). Dos correos de la misma persona que solo
-- difieren en cod_tipo_cta_fte:
--
--   'arq.ord.cta1'  tipo '1' -> 50 -> cat 3   (umbral :2988, "> 45 y <= 50")
--   'arq.ord.cta5'  tipo '5' ->  5 -> cat 1   (umbral :2988, "<= 5")
--
-- POR QUE LOS DOS BUZONES MIDEN 12 CARACTERES: EMA025 es un escalon sobre
-- el largo del buzon y asi no se mueve. Mismo dominio, de modo que EMA018
-- tampoco. Una fila por correo y un solo suscriptor, de modo que EMA024
-- vale 100 en los dos. La unica diferencia es el tipo de cuenta.
--
-- DELTA ESPERADO ARQ 86: 56.5375 = (3-1)/4 * 113.07492490
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT
  (9860000 + n.i) * 10 + 1, 9860000 + n.i, 9860000 + n.i, '10',
  e.buzon || '@experian-arq.co', NULL, 11001, CURRENT_DATE, 7001, e.tipo_cta
FROM (
  SELECT CAST('arq.ord.cta1' AS VARCHAR(40)) AS buzon,
         CAST('1' AS VARCHAR(20))            AS tipo_cta UNION ALL
  SELECT 'arq.ord.cta5', '5'
) e
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- ARQ 87 -- CANAL DIR: la palanca es DIR001IN (SLCOPRBA-1355)
-- ------------------------------------------------------------
-- DIR001IN es el MIN de meses_reporte RESTRINGIDO a los reportes cuyo
-- suscriptor tiene Portafolio_Nuevo = 'IN', es decir prefijo 05
-- (Caracteristicas.txt:172, WHERE PIDR.portafolio_nuevo = 'IN').
--
-- POR QUE cod_suscriptor ES LA PALANCA BUENA DE ESTE CANAL: la cabecera del
-- ARQ 80 avisa de que tocar la fecha mueve a la vez DIR001IN, DIR004RO,
-- DIR007TO, DIR019 y DIR034FI. El codigo de suscriptor, en cambio, solo
-- mueve el portafolio, siempre que las dos direcciones tengan el MISMO
-- numero de suscriptores distintos -- que es lo que cuentan DIR009 y
-- EMA015. Aqui cada direccion tiene exactamente un suscriptor.
--
--   k=1  suscriptor 050001 -> portafolio 'IN' -> DIR001IN = 15 -> cat 2
--   k=2  suscriptor 080001 -> portafolio 'RS' -> DIR001IN = NULL -> cat 1
--   (umbrales :195, "IS NULL -> 1, <= 24 -> 2, ELSE 3")
--
-- Las dos direcciones son RES y comparten fecha, de modo que DIR017, DIR019
-- y las ventanas no se mueven. Los dos codigos estan fuera de la lista VE y
-- ninguno es 'FI' ni 'OT' por sector... 'RS' colapsa a 'RE' e 'IN' a 'FI',
-- asi que DIR010FI SI se mueve con k=1. Ver el delta compuesto abajo.
--
-- DELTA ESPERADO ARQ 87: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT (9870000 + n.i) * 10 + d.k, 9870000 + n.i, 9870000 + n.i,
       (9870000 + n.i) * 10 + d.k, (9870000 + n.i) * 10 + d.k, 1, NULL, d.k,
       CAST('2026-03-01' AS DATE), 1356301, '1'
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento,
  latitud, longitud, tipo_ubicacion
)
SELECT (9870000 + n.i) * 10 + d.k,
       CAST('ORD ARQ 87 P' || CAST(n.i AS VARCHAR) || ' D' || CAST(d.k AS VARCHAR) AS VARCHAR(500)),
       11001, 'BOGOTA', 'CUNDINAMARCA', NULL, NULL, NULL
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, cod_suscriptor, fecha_reporte
)
SELECT (9870000 + n.i) * 10 + d.k, 7001,
       CASE WHEN d.k = 1 THEN '050001' ELSE '080001' END,
       DATEADD(month, -15, CURRENT_DATE)
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ============================================================
-- ARQ 88 -- CANAL DIR: la palanca es DIR009 (SLCOPRBA-1355)
-- ------------------------------------------------------------
-- DIR009 cuenta CUANTAS DIRECCIONES DE LA PERSONA son de correspondencia,
-- es decir tienen al menos un reporte con tipo de ubicacion 'CRR'
-- (Caracteristicas.txt:201, sobre CO00DIR016 > 0). NO es "entidades
-- distintas reportando", que es la lectura vieja que el enunciado del RF
-- todavia arrastra y que nuestro codigo abandono a proposito.
--
-- Es una caracteristica A GRANO DE PERSONA que el legado reparte igual a
-- todas las direcciones de esa persona (el join de :201 es solo por
-- Id_Buro_Persona). Por tanto NO puede medirse con un delta entre las dos
-- filas de una persona: hay que comparar DOS PERSONAS.
--
--   persona par   (i par):  k=1 RES, k=2 CRR -> DIR009 = 1 -> cat 2
--   persona impar (i impar): k=1 RES, k=2 RES -> DIR009 = 0 -> cat 2
--     (0 y 1 caen los dos en "<= 1 -> 2"; hace falta llegar a 2 para cat 3)
--   => k=2 CRR en las pares y DOS direcciones CRR en las impares:
--      pares DIR009 = 1 -> cat 2 ; impares DIR009 = 2 -> cat 3
--
-- DELTA ESPERADO ARQ 88: entre personas, (3-2)/3 * -51.61290323 = -17.2043
-- El beta es NEGATIVO: mas direcciones de correspondencia PENALIZAN.
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT (9880000 + n.i) * 10 + d.k, 9880000 + n.i, 9880000 + n.i,
       (9880000 + n.i) * 10 + d.k, (9880000 + n.i) * 10 + d.k,
       -- 3 = CRR. La persona impar tiene las DOS direcciones CRR; la par
       -- solo la segunda. Es la unica diferencia entre ambas.
       CASE WHEN MOD(n.i, 2) = 1 THEN 3
            WHEN d.k = 2        THEN 3
            ELSE 1 END,
       NULL, d.k, CAST('2026-03-01' AS DATE), 1356301, '1'
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento,
  latitud, longitud, tipo_ubicacion
)
SELECT (9880000 + n.i) * 10 + d.k,
       CAST('ORD ARQ 88 P' || CAST(n.i AS VARCHAR) || ' D' || CAST(d.k AS VARCHAR) AS VARCHAR(500)),
       11001, 'BOGOTA', 'CUNDINAMARCA', NULL, NULL, NULL
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, cod_suscriptor, fecha_reporte
)
SELECT (9880000 + n.i) * 10 + d.k, 7001, '080001', DATEADD(month, -15, CURRENT_DATE)
FROM (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ============================================================
-- ARQ 89 -- CANAL TEL: la palanca es TEL010 (SLCOPRBA-1355)
-- ------------------------------------------------------------
-- TEL010 es la cuota de los reportes de la persona de los ULTIMOS 12 MESES
-- que corresponden a ESTE telefono (Caracteristicas.txt:249, flat
-- 2968-2983), sobre Total_Reportes_12. NO tiene nada que ver con la
-- coincidencia geografica: el motivo que lo tenia en SIN_DATO describia
-- codigo que ya no existe.
--
--   telefono A: 3 reportes dentro de 12 meses
--   telefono B: 1 reporte dentro de 12 meses
--   Total_Reportes_12 de la persona = 4
--   TEL010(A) = 75 -> cat 4   TEL010(B) = 25 -> cat 2
--   (umbrales :77, "<20 ->1, <50 ->2, <70 ->3, >=70 ->4")
--
-- DELTA ESPERADO ARQ 89: (4-2)/4 * 61.93969030 = 30.9698
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte, cod_suscriptor
)
SELECT (9890000 + n.i) * 10 + 1, 9890000 + n.i, 9890000 + n.i, '4',
       t.tel, NULL, 11001, DATEADD(month, -t.meses, CURRENT_DATE),
       7001, NULL, '080001'
FROM (
  -- El CAST de la primera rama fija el tipo del nodo UNION ALL.
  SELECT CAST('6011111111' AS VARCHAR(200)) AS tel, CAST(2 AS INTEGER) AS meses UNION ALL
  SELECT '6011111111', 4 UNION ALL
  SELECT '6011111111', 8 UNION ALL
  SELECT '6022222222', 10
) t
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ============================================================
-- ARQ 90 -- CANAL TEL: la palanca es el guardia de validez (F4-TEL-04)
-- ------------------------------------------------------------
-- El criterio exige que solo cuenten los reportes validos. Nuestro insumo
-- deriva descripcion_gestion del propio numero
-- (preparar_insumos_edf.sql:320-323): 'VALIDA' si es todo digitos y mide 7
-- o mas, 'NO VALIDA' en caso contrario. Los cinco contadores de TEL ya lo
-- excluyen (scoring_tel_edf.sql:37, 41, 57, 72, 74).
--
--   telefono A: '6033333333', 10 digitos -> VALIDA
--   telefono B: '60444',       5 digitos -> NO VALIDA
--   Los dos con un solo reporte, misma fecha y mismo suscriptor.
--   El B no suma al total_reporte de la persona, de modo que sus cuotas
--   caen y el A se lleva el lugar 1.
--
-- DIVERGENCIA QUE ESTE ARQUETIPO LEVANTA, y hay que decirla:
--   en el legado este filtro es CODIGO MUERTO. Descripcion_Gestion_Registro
--   se cablea al literal 'Valida' en Prc_Ordenamiento2.sql:1295, y el WHERE
--   de :1298 ademas excluye fisicamente cualquier otra gestion, de modo que
--   'NO VALIDA' no puede existir y los 15 predicados del legado siempre son
--   ciertos. El legado excluye AGUAS ARRIBA, por catalogo de gestion;
--   nosotros sintetizamos la validez del propio numero. Misma intencion,
--   distinta definicion de "invalido". Para la bitacora G-03.
--
-- DELTA ESPERADO ARQ 90: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte, cod_suscriptor
)
SELECT (9900000 + n.i) * 10 + 1, 9900000 + n.i, 9900000 + n.i, '4',
       t.tel, NULL, 11001, DATEADD(month, -5, CURRENT_DATE),
       7001, NULL, '080001'
FROM (
  SELECT CAST('6033333333' AS VARCHAR(200)) AS tel UNION ALL
  SELECT '60444'
) t
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ============================================================
-- ARQ 91..95 -- SLCOPRBA-1355, segunda tanda de paridad
-- ------------------------------------------------------------
-- Cierran las correcciones que salieron de auditar los 42 buckets de los
-- cuatro canales contra Caracteristicas.txt. Hasta esta tanda, 33 de los 42
-- terminos entraban en la suma sin que ninguna prueba los moviera: un
-- bucket mal portado NO sale FAILED, sale un numero plausible.
--
-- LOS DELTAS DE EMA SON COMPUESTOS A PROPOSITO, y no es un defecto del
-- arquetipo: las cuotas por ventana del canal comparten el numero de
-- reportes de la persona, asi que mover una mueve a las vecinas. Es el
-- mismo caso que el ARQ 89 en TEL, documentado alli. Lo que el arquetipo
-- garantiza es que la DIFERENCIA sea estable y reproducible; el valor se
-- mide en la corrida y se escribe en el evaluador.
--
-- Todas las fechas son RELATIVAS (DATEADD sobre CURRENT_DATE) y los meses
-- elegidos caen lejos de los umbrales de ventana 3, 6, 12 y 24.
-- ============================================================

-- ------------------------------------------------------------
-- ARQ 91 -- CANAL EMA: la palanca es EMA014
-- ------------------------------------------------------------
-- EMA014 es la cuota de reportes de mas de 24 meses sobre Total_Reportes_24m
-- (Caracteristicas.txt:1723-1727) y su categoria son CUATRO bandas,
-- 8.33 / 41.18 / 85 (:1005-1012). Nuestro port tenia `= 1 THEN 4 ELSE 1`:
-- una bandera binaria olvidada comparada contra un porcentaje 0..100, que
-- solo disparaba con un 1,00% exacto.
--
--   k=1  buzon viejo, reporte a 30 meses -> ema014 = 100 -> cat 4
--   k=2  buzon nuevo, reporte a  2 meses -> ema014 =   0 -> cat 1
--
-- La beta de EMA014 es NEGATIVA (-130.80018340): el legado CASTIGA al buzon
-- muerto, de modo que el k=1 debe quedar POR DEBAJO en el ranking.
-- DELTA ESPERADO ARQ 91: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT (9910000 + n.i) * 10 + 1, 9910000 + n.i, 9910000 + n.i, '10',
       e.buzon || '@experian-arq.co', NULL, 11001,
       DATEADD(month, -e.meses, CURRENT_DATE), 7001, '1'
FROM (
  SELECT CAST('arq.ord.e14a' AS VARCHAR(40)) AS buzon, CAST(30 AS INTEGER) AS meses UNION ALL
  SELECT 'arq.ord.e14b', 2
) e
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ------------------------------------------------------------
-- ARQ 92 -- CANAL EMA: la palanca son EMA015 y EMA016
-- ------------------------------------------------------------
-- Las dos son BINARIAS en el legado, `<= 0 -> 1 ELSE 4` (:1013-1018), de la
-- misma familia que CEL015, CEL017 y CEL023: saltan 1 -> 4 y dividen entre
-- 4, asi que el salto vale 3/4 de beta de golpe. Nuestro port las graduaba
-- en cuatro bandas inventadas.
--
--   k=1  reporte a 5 meses, ventana (3,6]  -> ema015 = 100 -> cat 4
--                                             ema016 =   0 -> cat 1
--   k=2  reporte a 9 meses, ventana (6,12] -> ema015 =   0 -> cat 1
--                                             ema016 = 100 -> cat 4
--
-- Las dos se mueven a la vez y en sentidos opuestos, con betas del mismo
-- signo (+79.46 y +85.57), de modo que el delta neto es pequeno pero NO
-- cero: lo fija la diferencia de las dos betas mas el arrastre de EMA010.
-- Un arquetipo con las dos categorias clavadas en 1 no probaria nada.
-- DELTA ESPERADO ARQ 92: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT (9920000 + n.i) * 10 + 1, 9920000 + n.i, 9920000 + n.i, '10',
       e.buzon || '@experian-arq.co', NULL, 11001,
       DATEADD(month, -e.meses, CURRENT_DATE), 7001, '1'
FROM (
  SELECT CAST('arq.ord.e15x' AS VARCHAR(40)) AS buzon, CAST(5 AS INTEGER) AS meses UNION ALL
  SELECT 'arq.ord.e16x', 9
) e
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ------------------------------------------------------------
-- ARQ 93 -- CANAL EMA: la palanca es EMA017, que TOPA EN 3
-- ------------------------------------------------------------
-- EMA017 es la cuota de la ventana (12,24] (:1736-1742) y su CASE del
-- legado tiene TRES ramas, no cuatro: `<= 0 -> 1`, `(0, 66.67] -> 2`,
-- `> 66.67 -> 3` (:1019-1024). Y aun asi se divide entre 4 (:679), de modo
-- que aporta como mucho el 75% de su beta. Es el TERCER caso de esa familia
-- junto a CEL019 y CEL006; defecto del legado y se porta tal cual.
-- Nuestro port llegaba a 4 y sobre-penalizaba (beta -30.56079051).
--
--   k=1  reporte a 18 meses, ventana (12,24] -> ema017 = 100 -> cat 3
--   k=2  reporte a  2 meses                  -> ema017 =   0 -> cat 1
--
-- DELTA ESPERADO ARQ 93: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT (9930000 + n.i) * 10 + 1, 9930000 + n.i, 9930000 + n.i, '10',
       e.buzon || '@experian-arq.co', NULL, 11001,
       DATEADD(month, -e.meses, CURRENT_DATE), 7001, '1'
FROM (
  SELECT CAST('arq.ord.e17a' AS VARCHAR(40)) AS buzon, CAST(18 AS INTEGER) AS meses UNION ALL
  SELECT 'arq.ord.e17b', 2
) e
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ------------------------------------------------------------
-- ARQ 94 -- CANAL CEL: la palanca es CEL020
-- ------------------------------------------------------------
-- CEL020 es la cuota de SUSCRIPTORES DISTINTOS del celular sobre los
-- suscriptores distintos de la persona: el legado agrupa por Cod_Suscriptor
-- y cuenta ESOS GRUPOS (Caracteristicas.txt:1583-1591, :3031-3037,
-- :3153-3154). Nuestro port contaba FILAS DE REPORTE, que es otra magnitud.
--
-- EL ARQUETIPO DISTINGUE LAS DOS LECTURAS, que es lo que lo hace util:
--   k=1  celular 3101111111, DOS suscriptores (7001 y 7002)
--   k=2  celular 3102222222, DOS filas del MISMO suscriptor (7003)
--
--   suscriptores distintos de la persona = 3
--   con la formula CORRECTA : k=1 -> 2/3 = 66.67 -> cat 3
--                             k=2 -> 1/3 = 33.33 -> cat 2   (delta != 0)
--   con la formula VIEJA    : los dos 2 filas / 4 = 50.00 -> cat 3 los dos
--                             (delta CERO: el arquetipo no veria nada)
--
-- Todo lo demas esta igualado a proposito: mismo prefijo 310 en los dos, de
-- modo que CEL018 no se mueve y la compuerta del canal deja pasar las dos
-- filas; misma fecha, de modo que ninguna cuota por ventana se mueve; mismo
-- tipo de cuenta, de modo que CEL019 no se mueve; y dos filas por celular,
-- de modo que los conteos pelados tampoco. La UNICA diferencia es cuantos
-- suscriptores distintos reportan cada celular.
--
-- DELTA ESPERADO ARQ 94: 50.8299 = (3-2)/4 * 203.31950210. NO es compuesto.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT (9940000 + n.i) * 10 + 1, 9940000 + n.i, 9940000 + n.i, '9',
       c.cel, NULL, 11001, DATEADD(month, -9, CURRENT_DATE), c.susc, '1'
FROM (
  SELECT CAST('3101111111' AS VARCHAR(200)) AS cel, CAST(7001 AS INTEGER) AS susc UNION ALL
  SELECT '3101111111', 7002 UNION ALL
  SELECT '3102222222', 7003 UNION ALL
  SELECT '3102222222', 7003
) c
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;

-- ------------------------------------------------------------
-- ARQ 95 -- CANAL CEL: la palanca es el filtro de gestion de CEL023
-- ------------------------------------------------------------
-- CEL023 compara la recencia mas vieja de la PERSONA con la de ESTE
-- celular, y el legado toma las dos FILTRADAS por gestion
-- (Caracteristicas.txt:1566-1568 y :3133-3135). Nuestro port no filtraba
-- ninguna de las dos, de modo que un celular 'NO VALIDA' con la recencia
-- mas vieja desplazaba el divisor y volteaba el bit para TODOS los
-- celulares de esa persona: 121,37 puntos (binaria 1 -> 4, beta 161.83).
--
--   k=1  3101000000, diez digitos -> VALIDA,    reporte a 10 meses
--   k=2  31012,      cinco digitos -> NO VALIDA, reporte a 40 meses
--
--   con el filtro CORRECTO: el maximo de la persona es 10 (solo el k=1),
--     k=1 -> (10-10)/10 = 0 -> cat 1
--     k=2 -> no tiene ninguna fila valida -> NULL -> ELSE 0 -> cat 0
--   sin el filtro (lo viejo): el maximo de la persona seria 40,
--     k=1 -> (40-10)/40 = 75 -> cat 4   <-- el bit volteado
--     k=2 -> (40-40)/40 =  0 -> cat 1
--
-- Los dos prefijos son 310, catalogado, de modo que CEL018 no es 0 y la
-- compuerta deja pasar las dos filas: el arquetipo mide el filtro de
-- gestion y no la compuerta del operador. Misma forma que el ARQ 90 de TEL.
--
-- El delta ES compuesto: el reporte a 40 meses mueve ademas CEL003, CEL013
-- y CEL014, que es inevitable porque la validez viaja pegada a la fecha.
-- DELTA ESPERADO ARQ 95: lo fija la corrida; se mide y se escribe aqui.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor, cod_tipo_cta_fte
)
SELECT (9950000 + n.i) * 10 + 1, 9950000 + n.i, 9950000 + n.i, '9',
       c.cel, NULL, 11001, DATEADD(month, -c.meses, CURRENT_DATE), 7001, '1'
FROM (
  SELECT CAST('3101000000' AS VARCHAR(200)) AS cel, CAST(10 AS INTEGER) AS meses UNION ALL
  SELECT '31012', 40
) c
CROSS JOIN bdm_stage.mock_numeros n WHERE n.i < 1000;
