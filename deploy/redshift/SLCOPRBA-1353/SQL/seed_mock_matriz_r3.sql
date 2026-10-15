-- ============================================================
-- seed_mock_matriz_r3.sql
-- Matriz de semillas MOCK -- Regla 3 (ARQ 61..70).
-- (repo dt / db_rcncr_btch_rdshft_dt)
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Prerequisito: strct desplegado; seed_mock_matriz.sql y seed_mock_matriz_r2.sql
--               ejecutados antes (rangos disjuntos, pero el orden del .par los
--               pone antes y asi se mantiene).
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1355. Banda 9610000..9700999, DISJUNTA de Regla 1
-- (9010000..9200999), de Regla 2 (9210000..9560999), del Grupo A
-- (9570000..9590999) y del ARQ 60 (9600000..9600999).
--
-- QUE CERTIFICA. Los diez criterios del bloque REGLA3, uno por arquetipo. El
-- legado de la regla es P0021_UNIFICACION_111.BTQ y su formula de puntaje es
-- lo que hace que un solo mecanismo cubra cuatro criterios:
--
--     id_unificacion = CASE WHEN lat Y long  THEN 100000000 + conteo_diccionario
--                    + CASE WHEN falta una   THEN fecha_como_entero
--                    + numero_entidades_reportan
--
-- Cada arquetipo aisla UN termino de esa suma.
--
--   ARQ  subcaso                          criterio   parejas/persona
--    61  una sola geolocalizada             R3-02       1
--    62  ninguna geolocalizada              R3-03       1
--    63  las dos geolocalizadas             R3-04       1
--    64  puerta a +-2                       R3-05       1
--    65  puerta a +-5                       R3-06       0
--    66  modificador de via en el texto     R3-07       0
--    67  cuadrante en la via principal      R3-08       1
--    68  tipo MZ (Manzana)                  R3-01       0
--    69  tipo Rural                         R3-01       0
--    70  empate de diccionario              R3-10       0
--
--   TOTAL: 5 parejas por replica -> 5000 filas.
--
-- ------------------------------------------------------------
-- POR QUE CADA DIRECCION TIENE SU PROPIA UBICACION
-- ------------------------------------------------------------
-- En las matrices de R1 y R2 todas las direcciones de una persona comparten un
-- solo cod_dw_ubic. Aqui NO se puede: las coordenadas viven en
-- ubicacion_estandarizada, de modo que con una ubicacion compartida es
-- IMPOSIBLE sembrar "una geolocalizada y la otra no" -- que es exactamente el
-- subcaso del criterio R3-02.
--   cod_dw_ubic = persona * 10 + k, igual que cod_dw_persona_ubic.
-- El texto_ubicacion sigue siendo el MISMO para las direcciones de una persona:
-- R3 no empareja por texto (empareja por los cuatro componentes de via), pero
-- el Diccionario de Via se acota por texto_ubicacion, y asi las dos
-- direcciones del grupo entran al mismo alcance del diccionario.
--
-- ------------------------------------------------------------
-- INMUNIDAD A REGLA 1 Y A REGLA 2
-- ------------------------------------------------------------
-- No es un detalle: si R1 o R2 tocaran estos arquetipos, el conteo esperado del
-- gate dejaria de medir R3.
--   Regla 1 exige tipo de ubicacion DISTINTO dentro del grupo. Todas las
--   direcciones son RES (1), de modo que R1 no forma pareja.
--   Regla 2 exige el MISMO tipo -- que si se cumple -- pero TODOS sus
--   escenarios discriminan por una DIFERENCIA de complemento: esc1 vacio contra
--   informado, esc2 substring, esc3 mismo token con distinto valor, esc4/5/6
--   nomenclaturas distintas. Aqui el complemento es 'AP 101' IDENTICO en todas,
--   asi que ninguna diferencia existe y ningun escenario dispara.
--   El motor de direcciones nuevas (sello X4) exige NIT; cod_tipo_ident_fte
--   es '1'.
--
-- Y AL REVES, R3 TAMPOCO TOCA LAS OTRAS BANDAS: su insumo exige
-- tipo_ubicacion = 'Via', y esta es la UNICA semilla que escribe esa columna.
-- Las demas la dejan NULL, de modo que quedan fuera del insumo de R3 sin
-- necesidad de ningun filtro por rango.
--
-- ------------------------------------------------------------
-- EL ARQUETIPO 63 AISLA EL DICCIONARIO, Y ESO TIENE TRUCO
-- ------------------------------------------------------------
-- R3-04 dice que con las dos direcciones geolocalizadas decide el Diccionario
-- de Via. Pero el puntaje suma TAMBIEN numero_entidades_reportan, de modo que
-- si la ganadora tuviera mas entidades la victoria no se le podria atribuir al
-- diccionario.
--
-- El legado distingue dos cosas que parecen la misma:
--     Numero_entidades_que_Reportan = COUNT(DISTINCT Id_Buro_Suscriptor)
--     CONTEO del diccionario        = COUNT(filas de reporte)
-- Asi que el k=1 del ARQ 63 lleva TRES filas de reporte DEL MISMO SUSCRIPTOR:
-- conteo de diccionario 3 contra 1, y entidades 1 contra 1. Las entidades
-- EMPATAN y lo unico que puede decidir es el diccionario. La asercion de R3-04
-- verifica las dos mitades.
--
-- ------------------------------------------------------------
-- EL CONTRASTE 64 / 65 ES LA AFIRMACION DEL UMBRAL
-- ------------------------------------------------------------
-- Los dos arquetipos son IDENTICOS salvo el numero de puerta de la segunda
-- direccion: 22 (diferencia 2, unifica) contra 25 (diferencia 5, no unifica).
-- Un 0 solo no prueba que el umbral exista -- podria no haber dato -- y un 1
-- solo no prueba que haya tope. El par de arquetipos prueba las dos cosas.
-- Las dos direcciones de los dos arquetipos estan geolocalizadas porque la
-- divergencia (D4) acota el umbral a ese subcaso.
--
-- ------------------------------------------------------------
-- CIFRAS QUE SE MUEVEN
-- ------------------------------------------------------------
--   CA-U02 total del FULL            55 000 -> 60 000  (+5 000)
--   CA-U10 total tras la mutacion    55 200 -> 60 200
--   rango de la semilla en el gate   ..96009999 -> ..97009999
-- Los checksums de convergencia NO se mueven: la comparacion es relativa.
-- ============================================================

-- ------------------------------------------------------------
-- Limpieza idempotente del rango que posee este script: ARQ 61..70.
-- ------------------------------------------------------------
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9610000 AND 9700999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9610000 AND 9700999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 96100000 AND 97009999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9610000 AND 9700999;

-- ============================================================
-- 1) RELACIONES: dos por persona (k = 1, 2)
-- ------------------------------------------------------------
-- La matriz 'arqdir' es la definicion COMPLETA de los diez arquetipos y la
-- usan las cinco secciones siguientes. Columnas:
--   arq        numero de arquetipo (61..70)
--   k          posicion de la direccion dentro del grupo
--   vp         via_principal ('67 SUR' en el 67: el cuadrante)
--   vg         via_generadora
--   puerta     numero_puerta
--   coord      1 = su ubicacion lleva latitud/longitud
--   n_rep      cuantas FILAS de reporte (lo que cuenta el diccionario)
--   susc_dist  0 = cada fila con un suscriptor distinto; 1 = todas el mismo
--   fecha_rep  fecha del primer reporte (las demas, +1 dia cada una)
--   tipo_ubic  valor del catalogo Tipo_Via
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k AS cod_dw_persona_ubic,
   9000000 + a.arq * 10000 + n.i             AS id_buro_persona,
   9000000 + a.arq * 10000 + n.i             AS cod_pin_persona,
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k AS cod_dw_ubic,
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k AS cod_dw_direccion_fisica,
  1                                          AS cod_dw_tipo_ubicacion_dir,
  NULL                                       AS ind_unificacion,
  a.k                                        AS orden_prioridad,
  CAST('2026-03-01' AS DATE)                 AS fecha_relacion_persona_ubicaci,
  1356301                                    AS lote,
  '1'                                        AS cod_tipo_ident_fte
FROM (
  --      arq   k   vp          vg      puerta  coord  n_rep  susc_dist  fecha_rep                    tipo_ubic
  SELECT  61 AS arq, 1 AS k, '61'     AS vp, '10' AS vg, '20' AS puerta, 1 AS coord, 1 AS n_rep, 1 AS susc_dist, CAST('2026-02-01' AS DATE) AS fecha_rep, 'Via'   AS tipo_ubic UNION ALL
  SELECT  61,        2,      '61',        '11',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  62,        1,      '62',        '10',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  62,        2,      '62',        '11',       '20',             0,           1,          1,              CAST('2024-01-15' AS DATE),              'Via'   UNION ALL
  SELECT  63,        1,      '63',        '10',       '20',             1,           3,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  63,        2,      '63',        '11',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  64,        1,      '64',        '10',       '20',             1,           2,          0,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  64,        2,      '64',        '10',       '22',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  65,        1,      '65',        '10',       '20',             1,           2,          0,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  65,        2,      '65',        '10',       '25',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  66,        1,      '66',        '10',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  66,        2,      '66',        '11',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  67,        1,      '67 SUR',    '10',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  67,        2,      '67',        '11',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  68,        1,      '68',        '10',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'MZ'    UNION ALL
  SELECT  68,        2,      '68',        '11',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'MZ'    UNION ALL
  SELECT  69,        1,      '69',        '10',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Rural' UNION ALL
  SELECT  69,        2,      '69',        '11',       '20',             0,           1,          1,              CAST('2026-02-01' AS DATE),              'Rural' UNION ALL
  SELECT  70,        1,      '70',        '10',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'   UNION ALL
  SELECT  70,        2,      '70',        '11',       '20',             1,           1,          1,              CAST('2026-02-01' AS DATE),              'Via'
) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 2) UBICACION: UNA POR DIRECCION (ver la cabecera)
-- ------------------------------------------------------------
-- texto_ubicacion IGUAL para las dos direcciones de una persona.
-- El ARQ 66 lleva un texto distinto a proposito: '45B' casa el patron de
-- modificadores de via del legado ('[0-9]{1,3}[A-Z]{1,5}') y es lo que lo saca
-- del insumo de R3. Es el unico arquetipo cuyo texto importa.
-- Las coordenadas NO se resuelven con un CASE aqui: Redshift infiere el tipo
-- del nodo CASE a partir del literal y lo contrasta contra el de la columna,
-- y aborta con "Assert: Type inference inconsistency detected". Se insertan
-- todas sin coordenadas y se marcan despues con un UPDATE escalar.
-- ============================================================
INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento, tipo_ubicacion
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k,
  CASE WHEN a.arq = 66
       THEN 'CL 45B # ' || CAST(9000000 + a.arq * 10000 + n.i AS VARCHAR) || ' - 20'
       ELSE 'CL ' || CAST(100 + a.arq AS VARCHAR)
            || ' # ' || CAST(9000000 + a.arq * 10000 + n.i AS VARCHAR) || ' - 20'
  END,
  11001, 'BOGOTA D.C.', 'CUNDINAMARCA',
  a.tipo_ubic
FROM (
  SELECT  61 AS arq, 1 AS k, 'Via'   AS tipo_ubic UNION ALL
  SELECT  61, 2, 'Via'   UNION ALL
  SELECT  62, 1, 'Via'   UNION ALL SELECT  62, 2, 'Via'   UNION ALL
  SELECT  63, 1, 'Via'   UNION ALL SELECT  63, 2, 'Via'   UNION ALL
  SELECT  64, 1, 'Via'   UNION ALL SELECT  64, 2, 'Via'   UNION ALL
  SELECT  65, 1, 'Via'   UNION ALL SELECT  65, 2, 'Via'   UNION ALL
  SELECT  66, 1, 'Via'   UNION ALL SELECT  66, 2, 'Via'   UNION ALL
  SELECT  67, 1, 'Via'   UNION ALL SELECT  67, 2, 'Via'   UNION ALL
  SELECT  68, 1, 'MZ'    UNION ALL SELECT  68, 2, 'MZ'    UNION ALL
  SELECT  69, 1, 'Rural' UNION ALL SELECT  69, 2, 'Rural' UNION ALL
  SELECT  70, 1, 'Via'   UNION ALL SELECT  70, 2, 'Via'
) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- Coordenadas de las direcciones con coord = 1. UPDATE escalar, sin CASE: es
-- la forma que no dispara la inferencia de tipos de Redshift.
UPDATE bdm_stage.ubicacion_estandarizada
   SET latitud  = CAST(  4.60971000 AS DECIMAL(12,8)),
       longitud = CAST(-74.08175000 AS DECIMAL(12,8))
 WHERE cod_dw_ubic IN (
   SELECT (9000000 + a.arq * 10000 + n.i) * 10 + a.k
   FROM (
     SELECT 61 AS arq, 1 AS k UNION ALL
     SELECT 63, 1 UNION ALL SELECT 63, 2 UNION ALL
     SELECT 64, 1 UNION ALL SELECT 64, 2 UNION ALL
     SELECT 65, 1 UNION ALL SELECT 65, 2 UNION ALL
     SELECT 66, 1 UNION ALL
     SELECT 67, 1 UNION ALL
     SELECT 68, 1 UNION ALL
     SELECT 69, 1 UNION ALL
     SELECT 70, 1 UNION ALL SELECT 70, 2
   ) a
   CROSS JOIN bdm_stage.mock_numeros n
   WHERE n.i < 1000 );

-- ============================================================
-- 3) DIRECCION FISICA: aqui viven los CUATRO COMPONENTES DE VIA,
--    que son todo el criterio de la Regla 3.
-- ------------------------------------------------------------
-- complemento 'AP 101' IDENTICO en todas: es lo que hace al arquetipo inmune a
-- los seis escenarios de Regla 2 (ver la cabecera).
-- ============================================================
INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, tipo_via_principal, via_principal,
  via_generadora, numero_puerta, cod_dw_ubic, generada_enriquecida
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k,
  'AP 101',
  'CL',
  a.vp,
  a.vg,
  a.puerta,
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k,
  0
FROM (
  SELECT  61 AS arq, 1 AS k, '61' AS vp, '10' AS vg, '20' AS puerta UNION ALL
  SELECT  61, 2, '61',     '11', '20' UNION ALL
  SELECT  62, 1, '62',     '10', '20' UNION ALL
  SELECT  62, 2, '62',     '11', '20' UNION ALL
  SELECT  63, 1, '63',     '10', '20' UNION ALL
  SELECT  63, 2, '63',     '11', '20' UNION ALL
  SELECT  64, 1, '64',     '10', '20' UNION ALL
  SELECT  64, 2, '64',     '10', '22' UNION ALL
  SELECT  65, 1, '65',     '10', '20' UNION ALL
  SELECT  65, 2, '65',     '10', '25' UNION ALL
  SELECT  66, 1, '66',     '10', '20' UNION ALL
  SELECT  66, 2, '66',     '11', '20' UNION ALL
  SELECT  67, 1, '67 SUR', '10', '20' UNION ALL
  SELECT  67, 2, '67',     '11', '20' UNION ALL
  SELECT  68, 1, '68',     '10', '20' UNION ALL
  SELECT  68, 2, '68',     '11', '20' UNION ALL
  SELECT  69, 1, '69',     '10', '20' UNION ALL
  SELECT  69, 2, '69',     '11', '20' UNION ALL
  SELECT  70, 1, '70',     '10', '20' UNION ALL
  SELECT  70, 2, '70',     '11', '20'
) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 4) REPORTES: el numero de FILAS y el de SUSCRIPTORES son dos cosas
--    distintas, y de esa distincion depende el ARQ 63.
-- ------------------------------------------------------------
--   filas de reporte  -> CONTEO del Diccionario de Via
--   suscriptores dist -> numero_entidades_reportan del puntaje
-- El k=1 del ARQ 63 lleva 3 filas del MISMO suscriptor: diccionario 3 contra
-- 1 y entidades 1 contra 1. Las fechas se separan un dia por fila para que las
-- tres filas sean distinguibles.
-- ============================================================
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT
  (9000000 + a.arq * 10000 + n.i) * 10 + a.k,
  1001 + CASE WHEN a.susc_dist = 1 THEN 0 ELSE r.j END,
  a.fecha_rep + r.j
FROM (
  SELECT  61 AS arq, 1 AS k, 1 AS n_rep, 1 AS susc_dist, CAST('2026-02-01' AS DATE) AS fecha_rep UNION ALL
  SELECT  61, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  62, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  62, 2, 1, 1, CAST('2024-01-15' AS DATE) UNION ALL
  SELECT  63, 1, 3, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  63, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  64, 1, 2, 0, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  64, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  65, 1, 2, 0, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  65, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  66, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  66, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  67, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  67, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  68, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  68, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  69, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  69, 2, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  70, 1, 1, 1, CAST('2026-02-01' AS DATE) UNION ALL
  SELECT  70, 2, 1, 1, CAST('2026-02-01' AS DATE)
) a
CROSS JOIN (SELECT 0 AS j UNION ALL SELECT 1 UNION ALL SELECT 2) r
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000
  AND r.j < a.n_rep;

-- ============================================================
-- 5) CIIU Y CONTACTOS
-- ------------------------------------------------------------
-- CIIU '99': no esta en 10 / 81 / 82 / 90, de modo que de Regla 1 solo podria
-- interesarle al escenario 3 -- que exige tipo de ubicacion DISTINTO, y aqui
-- todas son RES. Se deja explicito para que la inmunidad se vea en los datos.
-- ============================================================
INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT DISTINCT rpu.id_buro_persona, '99'
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9610000 AND 9700999;

INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor
)
SELECT
  rpu.cod_dw_persona_ubic, rpu.id_buro_persona, rpu.cod_pin_persona, c.contact_type,
  CASE c.contact_type
    WHEN '4'  THEN '601' || LPAD(CAST(rpu.id_buro_persona % 10000000 AS VARCHAR), 7, '0')
    WHEN '9'  THEN '310' || LPAD(CAST(rpu.id_buro_persona % 10000000 AS VARCHAR), 7, '0')
    ELSE           'mock' || CAST(rpu.id_buro_persona AS VARCHAR) || '@gmail.com'
  END,
  ubi.texto_ubicacion, 11001, CAST('2026-02-15' AS DATE), 1001
FROM bdm_stage.relacion_persona_ubicacion rpu
JOIN bdm_stage.ubicacion_estandarizada ubi ON ubi.cod_dw_ubic = rpu.cod_dw_ubic
CROSS JOIN (SELECT '4' AS contact_type UNION ALL SELECT '9' UNION ALL SELECT '10') c
WHERE rpu.id_buro_persona BETWEEN 9610000 AND 9700999
  AND rpu.cod_dw_persona_ubic % 10 = 1;
