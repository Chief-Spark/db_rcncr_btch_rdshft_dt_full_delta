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
-- CUATRO CARACTERISTICAS NO SE PUEDEN EJERCITAR EN MOCK, y conviene que
-- conste aqui porque explica por que ciertos criterios siguen en SIN_DATO:
--   - sector_financiero: su catalogo se carga de la vista REAL del datashare
--     (02_catalogos_ordenamiento.sql:16) y no tiene variante mock, asi que
--     vale 0 para todo suscriptor inventado. Deja clavadas DIR010FI, TEL017,
--     CEL017 y EMA016.
--   - coincidencia_geo esta fijada al literal 0 (preparar_insumos:234):
--     TEL010 y TEL020 no discriminan.
--   - catalogo_tipo_cuenta_tel no contiene ningun 'POSPAGO'
--     (02_catalogos_ordenamiento.sql:27-32): CEL014 y CEL019 son constantes.
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
-- ARQ 83: el celular k=1 lleva prefijo 310 (CLARO, valor 0.62, y ademas en
--         la lista de CEL013) y el k=2 lleva 322, que NO ESTA EN EL
--         CATALOGO. Certifica dos cosas a la vez:
--           - CEL013: 310 da categoria 4, 322 da 1
--           - CEL018: 310 da 62.00 -> categoria 3; 322 cae al default
--             0.22 -> 22.00 -> categoria 1
--
--         Y DOCUMENTA UNA DIVERGENCIA IMPORTANTE. En el legado, un prefijo
--         no catalogado EXCLUYE el celular del ranking
--         (Caracteristicas.txt:79, WHERE CO01CEL018 <> 0). En Redshift el
--         join es LEFT y el COALESCE le da 0.22, de modo que la fila
--         SOBREVIVE y compite, solo que penalizada. Este arquetipo hace
--         visible y medible esa diferencia en vez de dejarla en un comentario.
--
-- SCORE ESPERADO:
--   ARQ 82, los dos celulares ....... 636.9295  (empate)
--   ARQ 83, celular 310 ............. 768.6722  -> lugar 1
--   ARQ 83, celular 322 ............. 636.9295  -> lugar 2
--   El salto de 131.7427 es la suma de CEL013 (+93.3610) y CEL018 (+38.3817).
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
  SELECT 9830000, '322'
) c
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- ARQ 84 -- CANAL EMA: el dominio conocido PIERDE
-- ------------------------------------------------------------
-- Dos correos por persona, identicos salvo el dominio:
--   k=1  @experian-arq.co  dominio DESCONOCIDO
--   k=2  @gmail.com        dominio CONOCIDO
--
-- Y el conocido saca MENOS puntuacion. No es un error del arquetipo: en
-- nuestro codigo el dominio conocido alimenta DOS caracteristicas, las dos
-- con beta NEGATIVA y las dos dentro de la suma:
--   EMA014  beta -130.80018340  (scoring_ema_edf.sql:32)
--   EMA017  beta  -30.56079051  (deriva de tipo_cuenta = 'PERSONAL', que se
--                                calcula con la MISMA lista de dominios,
--                                preparar_insumos_edf.sql:295-296)
-- Juntas restan (4-1)/4 * (130.80018340 + 30.56079051) = 121.0207 puntos.
--
-- EN EL LEGADO ESTO NO PASA: alli el dominio conocido es EMA018
-- (Caracteristicas.txt:94), con beta POSITIVA y FUERA de la suma (:246), de
-- modo que el dominio no afecta al score. Donde el legado es indiferente,
-- nosotros penalizamos. Es la divergencia que persigue F4-EMA-02, y este
-- arquetipo la convierte en un numero que se puede ver en el tablero.
--
-- SCORE ESPERADO:
--   @experian-arq.co ... 215.6064  -> lugar 1
--   @gmail.com ......... 94.5856   -> lugar 2
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor
)
SELECT
  (9840000 + n.i) * 10 + 1, 9840000 + n.i, 9840000 + n.i, '10',
  e.buzon || CAST(n.i AS VARCHAR) || e.dominio,
  NULL, 11001, CURRENT_DATE, 7001
FROM (
  SELECT CAST('arq.ord.desconocido' AS VARCHAR(40)) AS buzon,
         CAST('@experian-arq.co' AS VARCHAR(40))    AS dominio UNION ALL
  SELECT 'arq.ord.conocido', '@gmail.com'
) e
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;
