-- ============================================================
-- seed_mock_matriz_r2.sql
-- Matriz de semillas MOCK -- Regla 2 (ARQ 21..55), GEO con coordenadas (ARQ 56)
-- y la cascada R1 -> R2 (ARQ 60).
-- (repo dt / db_rcncr_btch_rdshft_dt)
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Prerequisito: strct desplegado y seed_mock_matriz.sql ejecutado antes.
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1356. Continuacion de seed_mock_matriz.sql (Regla 1, ARQ 1..20);
-- mismo esquema de identificadores y mismas 5 posiciones respecto al Watermark.
--
-- LA CASCADA DE REGLA 2 (lo que condiciona todo este diseno)
--   Los escenarios de R2 NO son independientes. Se ejecutan en orden
--       esc1 -> esc2 -> esc3 -> esc4 -> esc5 -> esc6
--   sobre una tabla de trabajo compartida: esc3..esc6 leen
--       bdm_tempo.stg_mock_regla2_e2 WHERE ind_unificacion = 'N'
--   es decir, SOLO lo que los escenarios anteriores no consumieron, y cada uno
--   marca 'S' lo que toma. Por eso cada arquetipo debe ser INMUNE a todos los
--   escenarios previos: si cumple el predicado de uno anterior, lo captura ese
--   y el resultado esperado documentado deja de valer.
--
-- PREDICADO BASE, COMUN A LOS SEIS (el emparejamiento):
--   misma persona, mismo texto_ubicacion, MISMO cod_dw_tipo_ubicacion_dir,
--   mismo municipio, distinto cod_dw_persona_ubic.
--   Nota: R2 exige tipo de ubicacion IGUAL, al reves que R1, que lo exige
--   DISTINTO. Por eso todos los arquetipos de R2 usan RES (1) en todas sus
--   direcciones: eso por si solo los hace inmunes a Regla 1.
--
-- DISCRIMINANTE Y BLINDAJE DE CADA ARQUETIPO
--   E1 complemento vacio   padre 'AP 301' / hija ''            primero en la
--                          cadena: no necesita blindaje.
--   E2 substring           padre 'TO 1 AP 502' / hija 'TO 1'   inmune a esc1:
--                          ambos complementos no vacios.
--   E3 misma nomenclatura  'AP 201' / 'AP 202', SIN NIT        inmune a esc1
--                          (no vacios) y a esc2 (ninguno es substring del otro).
--   E4 diccionario         'OF 301 TO 2' (conteo 2) / 'LC 2' (conteo 1), CON
--                          NIT. El conteo lo calcula el constructor del
--                          diccionario tokenizando el complemento: OF(1)+TO(1)
--                          contra LC(1). 'OF 301 TO 2' es el maximo UNICO, que
--                          es lo que esc4 exige (HAVING COUNT(*) = 1).
--                          inmune a esc3 por dos vias: nomenclaturas distintas
--                          (OF vs LC) y cod_tipo_ident_fte = '3'.
--   E5 nivel nomenclatura  'BR 5' (nivel 1) / 'AP 301' (nivel 7), CON NIT.
--                          Los dos tokens estan en el catalogo y aparecen una
--                          sola vez, asi que EMPATAN en conteo 1 y esc4 no los
--                          captura (exige ganador UNICO). En esc5 gana el de
--                          MENOR nivel, que queda de padre.
--   E6 frecuencia gana     TRES direcciones, CON NIT: 'CA 1 LT 2' (conteo 5),
--                          'CA 3 LT 4' (conteo 5) y 'CA 9' (conteo 3). Las tres
--                          arrancan con el MISMO token (CA, nivel 4) a
--                          proposito: asi esc5 no puede discriminar por nivel y
--                          el caso llega a esc6. Dos empatan en el maximo y una
--                          pierde, que es el discriminador que esc6 certifica.
--
-- POR QUE E6 NECESITA TRES DIRECCIONES (y no dos)
--   esc4 y esc6 leen LA MISMA fuente de frecuencia. Con dos direcciones de
--   frecuencia distinta, esc4 siempre encuentra un maximo unico y dispara
--   primero, de modo que esc6 nunca llega a ejecutarse: con grupos de dos
--   direcciones el escenario 6 es INALCANZABLE. Para que esc4 no dispare hace
--   falta un EMPATE en el maximo, y para que esc6 si lo haga, alguien por
--   debajo. De ahi las tres direcciones: 5, 5 y 3.
--   Los tres complementos arrancan con el MISMO token (CA) para que
--   nomenclatura_pri sea igual en los tres y esc5 tampoco los capture: esc5
--   exige a.nomenclatura_pri <> b.nomenclatura_pri. El diccionario
--   (bdm_stage.diccionario_complementos) y el catalogo de niveles
--   (bdm_stage.nomenclatura) son tablas distintas.
--
--   CUANTAS FILAS PRODUCE. 'CA 1 LT 2' y 'CA 3 LT 4' empatan en el maximo y
--   ninguna puede ser hija de la otra; solo 'CA 9' tiene por encima a alguien
--   estrictamente mayor. Tras SLCOPRBA-1355 (C) esc6 deja UN SOLO padre por
--   hija, asi que el arquetipo produce UNA fila: 'CA 9' contra 'CA 1 LT 2'.
--   Antes producia dos -- la misma hija contra CADA una de las empatadas -- y
--   eso era un dato corrupto, no el comportamiento del escenario.
--
--   LO QUE E6 TODAVIA NO CERTIFICA: con que criterio el legado rompe el empate
--   5/5. La frecuencia no lo rompe, y el 'esc6' del legado no es un escenario
--   de emparejamiento sino el SITIO 2 de creacion de direcciones (ver abajo).
--   Hasta decodificar ese pivote, el arquetipo mide una fila consistente y
--   declara que falta la otra.
--   E7 motor NIT           TRES direcciones, CON NIT, las tres arrancan con la
--                          MISMA nomenclatura (TO): 'TO 2 CS 4' (padre),
--                          'TO 9 AP 1' y 'TO 7 AP 1' (hijas).
--                          Certifica el motor de direcciones nuevas, sitio 1
--                          del legado (marca 'X4').
--
-- POR QUE E7 ES ASI
--   El legado crea direcciones nuevas en DOS sitios (PRO_UnificacionR2.sql
--   lineas 1602 y 3423, los unicos con REC_MTDAT.MAX_ID). El sitio 1 vive en la
--   etapa (3) y su poblacion es Tmp_Unificacion_E031 (linea 650):
--     Tmp_Unificacion_E2 WHERE Nombre_Tipo_Ident LIKE '%Nit%' AND Ind_Unificacion='N'
--   mas el auto-join de Tmp_Unificacion_E03_B (linea 703): mismo grupo,
--   complemento distinto y MISMA nomenclatura inicial. Es el complemento exacto
--   de esc3, que resuelve "SIN NIT, misma nomenclatura" uniendo contra un padre
--   real. De ahi que las tres direcciones arranquen con TO y lleven NIT.
--
--   QUIEN ES EL PADRE: el de MAYOR JERARQUIA por MDIR, no el de fecha mas
--   antigua. Tmp_Unificacion_E031_codigo (linea 1491) -- de donde sale
--   COMPLEMENTO_PADRE -- se arma FROM Tmp_Unificacion_E051_P (el padre) LEFT
--   JOIN Tmp_Unificacion_E051_H (la hija), y E051_P (linea 1337) es
--   ROW_NUMBER() OVER (... ORDER BY MDIR, ORDEN) = 1: MDIR primero, la fecha
--   solo como desempate.
--
--   QUE ES MDIR (linea 891, "ID para identificar la direccion de mayor
--   jerarquia"): el SQL dinamico de Tmp_Unificacion_E03_Bx pivota los
--   componentes de cada direccion y ordena ASCENDENTE por el nivel del 1er
--   componente mas bajo, el del 2o, el del 3o..., rellenando con 99 los slots
--   que la direccion no tiene. El relleno con 99 manda al FINAL a las
--   direcciones con POCOS componentes, de modo que MDIR = 1 es la direccion
--   con MAS componentes y de nivel MAS BAJO: la mas RICA.
--
--   POR ESO ESTE ARQUETIPO CAMBIO. Hasta SLCOPRBA-1355 era 'AP 9' (padre) /
--   'AP 301 TO 2 CS 4' / 'AP 302 TO 5', construido sobre la premisa de que el
--   padre es el complemento mas POBRE y las hijas lo enriquecen. Con MDIR leido
--   bien el padre habria sido 'AP 301 TO 2 CS 4' -- la mas rica -- y entonces
--   NINGUNA hija puede aportarle nada: el motor no generaria nunca y el
--   arquetipo no certificaria nada. El arquetipo tiene que tener al padre
--   arriba en la jerarquia Y una hija con un componente que al padre le falte.
--
--   Lo que certifica, en un solo arquetipo:
--     catalogo     TO=4   CS=5   AP=7
--     padre        'TO 2 CS 4'   niveles (4,5,99)   <- MDIR 1, la mas rica
--     hija k=2     'TO 9 AP 1'   niveles (4,7,99)   aporta AP 1
--     hija k=3     'TO 7 AP 1'   niveles (4,7,99)   aporta AP 1 -> se DEDUPLICA
--     resultado    nueva_nomenclatura = 'AP 1'
--                  complemento_motor  = 'TO 2 CS 4 AP 1'
--     y las TRES direcciones, INCLUIDO EL PADRE, quedan unificadas contra la
--     generada con n_id = 'X4'. Eso es textual del legado (linea 757):
--     "este nuevo registro correspondera a la direccion unificada y las dos
--      direcciones evaluadas deben ser unidas a esta ultima".
--
--   Las dos hijas aportan AP con el MISMO valor a proposito: asi el complemento
--   fusionado NO depende de con que criterio se desempata la deduplicacion, que
--   el legado resuelve con un XMLAGG ... ORDER BY MDIR DESC que no se porto.
--
--   Ningun complemento es substring de otro, de modo que esc2 no se los come
--   antes de llegar al motor.
--
--   OJO con la posicion YA_UNIF (pi=5): marca la ULTIMA direccion (k=nk=3) con
--   ind_unificacion = 1 y el filtro de estado la saca del insumo. Quedan dos
--   direcciones, el grupo sigue en pie y sigue generando, y como lo que se
--   pierde es el aporte DUPLICADO de AP el resultado es el MISMO complemento
--   'TO 2 CS 4 AP 1' con DOS filas de unificacion en vez de tres.
-- QUE ARQUETIPOS GENERAN DIRECCION (poblacion del sitio 1: CON NIT, misma
-- nomenclatura inicial, y que los hijos aporten algo nuevo)
--   E7               si. Es el unico construido para esta ruta.
--   E6               no, aunque las tres arrancan con CA y llevan NIT. Por
--                    MDIR el padre es 'CA 1 LT 2' (niveles 4,5; empata con
--                    'CA 3 LT 4' y desempata el valor, 1 < 3) y ni 'CA 3 LT 4'
--                    ni 'CA 9' le aportan un componente que no tenga: no se
--                    crea direccion NI se marca, y el grupo sigue su camino
--                    hasta esc6.
--                    Esto es exactamente lo que el job #305 desmintio cuando el
--                    motor ordenaba al reves: con el padre en 'CA 9' las hijas
--                    si aportaban LT, E6 generaba, y ARQ 46-49 subian de 1000 a
--                    3000 filas cada uno.
--   E4, E5           no: sus nomenclaturas iniciales son distintas (OF/LC,
--                    BR/AP), asi que no entran al sitio 1.
--   E1, E2, E3       no: no llevan NIT.
--
-- SITIO 2 DEL LEGADO ('A6', etapa 5.1) NO IMPLEMENTADO. Su poblacion base esta
-- leida (Tmp_Unificacion_E051, linea 2280) pero NO la regla con que elige al
-- padre, que vive en el pivote dinamico de E051_A / E051_D (lineas 2331-2900).
-- Implementarlo por analogia con esc5 seria suponer, y ademas starveria a esc5.
--
-- RESULTADO ESPERADO (filas en unificacion_direccion_mock por replica;
-- multiplicar por N). Verificado por simulacion de la cascada completa antes de
-- escribir este archivo: cada arquetipo es consumido por el escenario previsto.
--
--   escenario            DENTRO  FUERA  NULL  CABALLO  YA_UNIF
--   E1 (via esc1)             1      1*     1        1        0
--   E2 (via esc2)             1      1*     1        1        0
--   E3 (via esc3)             1      1*     1        1        0
--   E4 (via esc4)             1      1*     1        1        0
--   E5 (via esc5)             1      1*     1        1        0
--   E6 (via esc6)             1      1*     1        1        0
--   E7 (via X4)               3      3*     3        3        2
--
--   E7 produce TRES filas porque el motor unifica el grupo COMPLETO contra la
--   direccion generada, el padre incluido. En YA_UNIF son DOS: la tercera
--   direccion queda fuera del insumo.
--
--   Direcciones generadas por el motor (filas en direccion_fisica_generada_mock
--   y rpu_generada_mock por replica; una por PADRE):
--
--   escenario            DENTRO  FUERA  NULL  CABALLO  YA_UNIF
--   E7 (padre 'TO 2 CS 4')    1      1*     1        1        1
--   los demas                 0      0      0        0        0
--
--   (*) FUERA produce la fila en el FULL pero 0 en el DELTA: la persona no
--       tiene ninguna relacion en la ventana y no entra al driver.
--   YA_UNIF marca la ULTIMA direccion del grupo (la hija) con
--   ind_unificacion = 1; el filtro de estado del legado la saca del insumo y el
--   grupo se queda sin pareja. En E6 eso deja a 'CA 1 LT 2' y 'CA 3 LT 4'
--   empatadas, de modo que ni esc4 ni esc6 disparan: 0 filas, igual que el
--   resto. En E7 no: el grupo se queda con dos y sigue generando.
--
--   TOTAL de la matriz completa (R1 + R2 + GEO), que es lo que mide CA-U02:
--   51 filas por replica -> 51000. Baja de 55000 porque E6 pasa de 2 filas a 1
--   en sus cuatro posiciones.
--
-- ------------------------------------------------------------
-- ARQ 60: LA CASCADA R1 -> R2 (cierra G-02)
-- ------------------------------------------------------------
-- G-02 dice: "una direccion seleccionada como padre en R1 puede ser evaluada
-- como hija en R2 si otra tiene complemento mas completo". Es un PERMISO, no
-- una obligacion, de modo que solo la evidencia POSITIVA lo afirma: hasta el
-- job #324 el criterio salia SIN_DATO porque la matriz no tenia ni un caso.
-- Ningun arquetipo anterior podia producirlo, y no por descuido: los de R1
-- usan tipos de ubicacion DISTINTOS (R1 lo exige) y los de R2 los usan IGUALES
-- (R2 lo exige), asi que un grupo construido para una regla es inmune a la
-- otra por diseno. El unico caso que cruza las dos necesita TRES direcciones
-- con dos tipos a la vez.
--
--   k   tipo        complemento   entidades   papel
--   1   CRR (3)     ''            2           padre en R1, HIJA en R2
--   2   RES (1)     ''            1           hija en R1
--   3   CRR (3)     'AP 301'      1           padre en R2
--
-- POR QUE FUNCIONA, leido contra los SP y no supuesto:
--
--   R1 esc1 (CIIU 10, sp_unificacion_mock_r1_esc1...). El grupo es
--   (persona, texto_ubicacion, cod_dw_ciudad) y las tres direcciones caen en
--   uno solo. El score es
--       (tipo IN ('LAB','CRR')) * 100000 + numero_entidades_reportan
--   -> k=1: 100002   k=3: 100001   k=2: 1
--   El maximo es UNICO, que es lo que el HAVING COUNT(*) = 1 del ganador pide,
--   y el padre es el de orden 1: k=1. Las hijas son las de orden > 1 CON
--   'padre.cod_dw_tipo_ubicacion_dir <> hijo.cod_dw_tipo_ubicacion_dir', de
--   modo que k=3 -- mismo tipo que el padre -- queda FUERA y la unica pareja
--   es k=2 -> k=1.
--
--   LA SEGUNDA ENTIDAD DE k=1 NO ES DECORATIVA. Sin ella k=1 y k=3 empatan en
--   100001, el maximo deja de ser unico, el ganador no existe y R1 no produce
--   NINGUNA pareja: el arquetipo entero no certificaria nada.
--
--   R2 esc1 (complemento vacio). El insumo de R2 filtra
--   'ind_unificacion IS NULL', y la vista mock DERIVA ind_unificacion de
--   unificacion_direccion_mock, de modo que tras R1 la hija k=2 ya no entra.
--   k=1 es PADRE, no hija, asi que sigue dentro -- y eso es exactamente lo que
--   el criterio afirma. Quedan k=1 ('') y k=3 ('AP 301'), mismo tipo, mismo
--   texto, mismo municipio: esc1 toma el de complemento informado como padre.
--   Pareja k=1 -> k=3.
--
--   INMUNIDAD AL RESTO DE LA CASCADA. Tras esc1 solo k=3 queda en 'N' y una
--   sola direccion no forma pareja con nadie: esc2..esc6 no la tocan. El motor
--   (sitio 1, sello X4) exige NIT y aqui cod_tipo_ident_fte = '1'. R1 esc2 y
--   esc3 no la ven porque el CIIU es '10'.
--
--   LO QUE NO VIOLA. R2-10 ("un padre no puede ser hija dentro de la misma
--   regla") compara con 'b.regla = a.regla': k=1 es padre en la regla 1 e hija
--   en la regla 2, reglas distintas, no hay violacion. G-03 ("una hija no
--   recibe un segundo padre") cuenta reglas por HIJA: k=1 recibe padre solo en
--   R2 y k=2 solo en R1. CA-U05 (un hijo, un padre) se cumple igual.
--
--   FILAS: 2 por persona -> 2000. La matriz pasa de 53000 a 55000 (CA-U02) y
--   el DELTA2 de 53200 a 55200 (CA-U10).
-- ============================================================

-- ------------------------------------------------------------
-- Limpieza idempotente del rango que posee este script:
-- ARQ 21..50 (Regla 2), ARQ 56 (GEO con coordenadas) y ARQ 60 (cascada
-- R1 -> R2). La banda 9570000..9590999 del Grupo A NO se toca aqui: la posee
-- seed_mock_matriz.sql, que corre antes.
-- ------------------------------------------------------------
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999;
DELETE FROM bdm_stage.diccionario_complementos       WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 92100000 AND 95609999
    OR cod_dw_persona_ubic BETWEEN 96000000 AND 96009999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 92100000 AND 95609999
    OR cod_dw_direccion_fisica BETWEEN 96000000 AND 96009999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 92100000 AND 95609999
    OR cod_dw_ubic BETWEEN 96000000 AND 96009999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9210000 AND 9560999
    OR id_buro_persona BETWEEN 9600000 AND 9600999;

-- ============================================================
-- 0) CATALOGO DE NOMENCLATURAS
-- ------------------------------------------------------------
-- 02a crea bdm_stage.nomenclatura pero NO la siembra, y la quiere vacia no
-- sirve: esc3 la usa para exigir misma nomenclatura inicial y esc5 para
-- comparar niveles. Se siembran los mismos 12 valores que
-- bdm_datos.nomenclatura (01_ddl_unificacion_direccion.sql), de modo que la via
-- mock y la real compartan la misma jerarquia.
-- Menor nivel = mas general (BR barrio = 1) y es el que queda de PADRE;
-- mayor nivel = mas especifico (AP apartamento = 7) y queda de hija.
-- ============================================================
-- WHERE explicito: la politica del pipeline (REDSHIFT:232) lo exige en todo
-- DELETE, y aqui ademas es lo correcto. El catalogo es COMPARTIDO: acotar el
-- borrado a los 12 tokens que esta semilla siembra deja intacta cualquier otra
-- entrada que haya puesto otro consumidor. El INSERT de abajo los repone, de
-- modo que la siembra sigue siendo idempotente.
DELETE FROM bdm_stage.nomenclatura
 WHERE nomenclatura IN ('TO','AP','CS','LC','OF','BL','IN','ED','BR','MZ','CA','LT');
INSERT INTO bdm_stage.nomenclatura (nomenclatura, nivel_complemento)
SELECT v.nomenclatura, v.nivel_complemento
FROM (
  SELECT 'TO' AS nomenclatura, 4 AS nivel_complemento UNION ALL
  SELECT 'AP', 7 UNION ALL SELECT 'CS', 5 UNION ALL SELECT 'LC', 3 UNION ALL
  SELECT 'OF', 6 UNION ALL SELECT 'BL', 2 UNION ALL SELECT 'IN', 8 UNION ALL
  SELECT 'ED', 2 UNION ALL SELECT 'BR', 1 UNION ALL SELECT 'MZ', 3 UNION ALL
  SELECT 'CA', 4 UNION ALL SELECT 'LT', 5
) v;

-- ============================================================
-- 1) RELACIONES: una fila por (arquetipo, replica, direccion)
-- ------------------------------------------------------------
-- 'arqdir' define las direcciones de cada escenario (la ULTIMA de cada grupo es
-- la hija) y 'pos' las cinco posiciones respecto al Watermark.
--   ARQ = 21 + esc_idx * 5 + (pi - 1)
-- Todas las direcciones usan cod_dw_tipo_ubicacion_dir = 1 (RES): R2 exige tipo
-- IGUAL y eso las hace inmunes a Regla 1, que lo exige distinto.
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i) * 10 + a.k AS cod_dw_persona_ubic,
   9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i             AS id_buro_persona,
   9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i             AS cod_pin_persona,
  (9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i) * 10 + 1   AS cod_dw_ubic,
  (9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i) * 10 + a.k AS cod_dw_direccion_fisica,
  1                                                                    AS cod_dw_tipo_ubicacion_dir,
  CASE WHEN p.pi = 5 AND a.k = a.nk THEN 1 ELSE NULL END               AS ind_unificacion,
  a.k                                                                  AS orden_prioridad,
  CASE p.pi
    WHEN 2 THEN CAST('2024-01-15' AS DATE)
    WHEN 3 THEN CAST(NULL AS DATE)
    WHEN 4 THEN CASE WHEN a.k = 1 THEN CAST('2026-03-01' AS DATE) ELSE CAST('2024-01-15' AS DATE) END
    ELSE        CAST('2026-03-01' AS DATE)
  END                                                                  AS fecha_relacion_persona_ubicaci,
  1356301                                                              AS lote,
  a.nit                                                                AS cod_tipo_ident_fte
FROM (
  --  esc_idx  k  nk  complemento      nit
  SELECT 0 AS esc_idx, 1 AS k, 2 AS nk, 'AP 301'      AS complemento, '1' AS nit UNION ALL
  SELECT 0, 2, 2, ''            , '1' UNION ALL
  SELECT 1, 1, 2, 'TO 1 AP 502' , '1' UNION ALL
  SELECT 1, 2, 2, 'TO 1'        , '1' UNION ALL
  SELECT 2, 1, 2, 'AP 201'      , '1' UNION ALL
  SELECT 2, 2, 2, 'AP 202'      , '1' UNION ALL
  SELECT 3, 1, 2, 'OF 301 TO 2' , '3' UNION ALL
  SELECT 3, 2, 2, 'LC 2'        , '3' UNION ALL
  SELECT 4, 1, 2, 'BR 5'        , '3' UNION ALL
  SELECT 4, 2, 2, 'AP 301'      , '3' UNION ALL
  SELECT 5, 1, 3, 'CA 1 LT 2'   , '3' UNION ALL
  SELECT 5, 2, 3, 'CA 3 LT 4'   , '3' UNION ALL
  SELECT 5, 3, 3, 'CA 9'        , '3' UNION ALL
  SELECT 6, 1, 3, 'TO 2 CS 4'   , '3' UNION ALL
  SELECT 6, 2, 3, 'TO 9 AP 1'   , '3' UNION ALL
  SELECT 6, 3, 3, 'TO 7 AP 1'   , '3'
) a
CROSS JOIN (SELECT 1 AS pi UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) p
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 2) ARQUETIPO 56: GEO CON COORDENADAS (control negativo del Exportador_GEO)
-- ------------------------------------------------------------
-- Misma forma que E1 (unifica via esc1), pero su ubicacion SI trae
-- latitud/longitud. Debe producir su fila de unificacion y NO generar
-- Ubicacion_Candidata: el predicado de candidatos exige
-- (sin fila en geo_atributos OR latitud IS NULL OR longitud IS NULL).
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9560000 + n.i) * 10 + a.k, 9560000 + n.i, 9560000 + n.i,
  (9560000 + n.i) * 10 + 1,   (9560000 + n.i) * 10 + a.k, 1, NULL, a.k,
  CAST('2026-03-01' AS DATE), 1356301, '1'
FROM (SELECT 1 AS k, 'AP 301' AS complemento UNION ALL SELECT 2, '') a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 2b) ARQUETIPO 60: CASCADA R1 -> R2 (el unico caso de G-02)
-- ------------------------------------------------------------
-- TRES direcciones y DOS tipos de ubicacion en el mismo grupo, que es lo que
-- obliga la cascada: R1 exige tipo DISTINTO y R2 lo exige IGUAL.
--   k=1 CRR ''        padre en R1 (gana por tipo + 2 entidades), hija en R2
--   k=2 RES ''        hija en R1
--   k=3 CRR 'AP 301'  padre en R2 (es el que trae complemento informado)
-- La justificacion completa esta en la cabecera. Sin NIT ('1'): asi el motor
-- del sitio 1 no lo toca.
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9600000 + n.i) * 10 + a.k, 9600000 + n.i, 9600000 + n.i,
  (9600000 + n.i) * 10 + 1,   (9600000 + n.i) * 10 + a.k, a.tipo, NULL, a.k,
  CAST('2026-03-01' AS DATE), 1356301, '1'
FROM (
  --      k  tipo  complemento
  SELECT  1 AS k, 3 AS tipo, CAST('' AS VARCHAR(200)) AS complemento UNION ALL
  SELECT  2,      1,         ''                                      UNION ALL
  SELECT  3,      3,         'AP 301'
) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 3) UBICACION (una por persona). Coordenadas NULL salvo el ARQ 56.
-- ============================================================
-- Las coordenadas NO se resuelven aqui con un CASE. Redshift infiere el tipo
-- del nodo CASE a partir del literal (4.60971000 es NUMERIC(9,8)) y lo
-- contrasta contra el tipo de la columna destino, DECIMAL(12,8); cuando las
-- ramas llevan su propio CAST el planificador se contradice y aborta con
-- "Assert: Type inference inconsistency detected: variable of type numeric
-- expected a precision of (12, 8), but the source column has a precision of
-- (9, 8)". Se insertan todas las ubicaciones sin coordenadas (NULL por
-- omision en la lista de columnas) y el ARQ 56 se marca despues con un UPDATE
-- escalar, donde no hay inferencia que pueda discrepar.
INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento
)
SELECT DISTINCT
  rpu.cod_dw_ubic,
  'CL ' || CAST(100 + (rpu.id_buro_persona - 9000000) / 10000 AS VARCHAR)
        || ' # ' || CAST(rpu.id_buro_persona AS VARCHAR) || ' - 20',
  11001, 'BOGOTA D.C.', 'CUNDINAMARCA'
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999
   OR rpu.id_buro_persona BETWEEN 9600000 AND 9600999;

-- Unico arquetipo con latitud/longitud: el 56, control negativo del
-- Exportador_GEO. Su cod_dw_ubic es (9560000 + i) * 10 + 1 con i < 1000, o sea
-- el tramo 95600001..95609991; ningun otro arquetipo entra ahi porque todos
-- nacen de id_buro_persona <= 9559999.
UPDATE bdm_stage.ubicacion_estandarizada
   SET latitud  = CAST(  4.60971000 AS DECIMAL(12,8)),
       longitud = CAST(-74.08175000 AS DECIMAL(12,8))
 WHERE cod_dw_ubic BETWEEN 95600000 AND 95609999;

-- ============================================================
-- 4) DIRECCION FISICA: aqui vive el COMPLEMENTO, que es el criterio de R2.
-- ============================================================
INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, cod_dw_ubic, generada_enriquecida
)
SELECT
  (9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i) * 10 + a.k,
  a.complemento,
  (9000000 + (21 + a.esc_idx * 5 + p.pi - 1) * 10000 + n.i) * 10 + 1,
  0
FROM (
  SELECT 0 AS esc_idx, 1 AS k, 'AP 301'      AS complemento UNION ALL
  SELECT 0, 2, ''             UNION ALL
  SELECT 1, 1, 'TO 1 AP 502'  UNION ALL
  SELECT 1, 2, 'TO 1'         UNION ALL
  SELECT 2, 1, 'AP 201'       UNION ALL
  SELECT 2, 2, 'AP 202'       UNION ALL
  SELECT 3, 1, 'OF 301 TO 2'  UNION ALL
  SELECT 3, 2, 'LC 2'         UNION ALL
  SELECT 4, 1, 'BR 5'         UNION ALL
  SELECT 4, 2, 'AP 301'       UNION ALL
  SELECT 5, 1, 'CA 1 LT 2'    UNION ALL
  SELECT 5, 2, 'CA 3 LT 4'    UNION ALL
  SELECT 5, 3, 'CA 9'          UNION ALL
  SELECT 6, 1, 'TO 2 CS 4'    UNION ALL
  SELECT 6, 2, 'TO 9 AP 1'    UNION ALL
  SELECT 6, 3, 'TO 7 AP 1'
) a
CROSS JOIN (SELECT 1 AS pi UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) p
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, cod_dw_ubic, generada_enriquecida
)
SELECT (9560000 + n.i) * 10 + a.k, a.complemento, (9560000 + n.i) * 10 + 1, 0
FROM (SELECT 1 AS k, 'AP 301' AS complemento UNION ALL SELECT 2, '') a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ARQ 60 (cascada R1 -> R2). Los complementos son el discriminante de esc1:
-- k=1 y k=2 vacios, k=3 informado. El de k=2 no llega a compararse -- R1 lo
-- sella como hija antes -- pero se siembra vacio por coherencia con k=1: las
-- dos son la misma direccion vista desde dos tipos de ubicacion.
INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, cod_dw_ubic, generada_enriquecida
)
SELECT (9600000 + n.i) * 10 + a.k, a.complemento, (9600000 + n.i) * 10 + 1, 0
FROM (
  -- El CAST de la primera rama NO es decorativo: es la que fija el tipo del
  -- nodo UNION ALL, y con un '' desnudo el ancho inferido podria truncar
  -- 'AP 301' a cadena vacia. Sin complemento informado en k=3 el escenario 1
  -- no tendria discriminante, no habria pareja de R2 y G-02 volveria a
  -- quedarse sin evidencia -- en silencio, con el seed corriendo "bien".
  -- El resto del archivo lo esquiva poniendo el literal largo primero; aqui el
  -- orden de k se conserva porque es lo que hace legible la matriz.
  SELECT 1 AS k, CAST('' AS VARCHAR(200)) AS complemento UNION ALL
  SELECT 2,      ''                                      UNION ALL
  SELECT 3,      'AP 301'
) a
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 5) DICCIONARIO DE COMPLEMENTOS -- YA NO SE SIEMBRA AQUI
-- ------------------------------------------------------------
-- Antes esta seccion insertaba filas a mano en
-- bdm_stage.diccionario_complementos con 'nomenclatura' = el complemento
-- COMPLETO ('OF 301') y una frecuencia elegida a dedo (9, 1, 10, 10, 3).
--
-- Ahora la tabla la construye
-- bdm_datos.sp_unificacion_mock_r2_construir_diccionario_complementos,
-- espejo del real, que TOKENIZA el complemento contra el catalogo de
-- nomenclaturas (equivalente al PRO_CreaDicNomenclaturaReg2 del legado). Las
-- dos formas son incompatibles: el join de los consumidores es
-- LIKE '%' || dc.nomenclatura || '%', de modo que una fila con el complemento
-- completo y una fila con el token 'OF' casan las dos contra 'OF 301' y sus
-- frecuencias se sumarian. El constructor es dueno unico de la tabla.
--
-- Por eso los complementos de esc4 y esc6 se re-derivaron para que la
-- frecuencia REAL (numero de direcciones de la persona en esa ubicacion que
-- contienen el token) reproduzca el discriminador que antes se fijaba a mano:
--
--   esc4 (ARQ 36-40)  'OF 301 TO 2' -> OF(1)+TO(1) = 2   <- maximo unico, gana
--                     'LC 2'        -> LC(1)       = 1
--     Antes 'OF 301'(9) vs 'LC 2'(1). Con tokenizacion real ambos daban 1 y
--     esc4 NO disparaba: el arquetipo se caia a esc5. El token TO extra
--     restituye el maximo unico que esc4 exige (HAVING COUNT(*) = 1).
--
--   esc6 (ARQ 46-50)  'CA 1 LT 2'   -> CA(3)+LT(2) = 5   <- empatan en el maximo
--                     'CA 3 LT 4'   -> CA(3)+LT(2) = 5   <-
--                     'CA 9'        -> CA(3)       = 3      pierde
--     Antes 'ZA 1'(10) / 'ZA 2'(10) / 'ZB 9'(3). ZA y ZB NO estan en el
--     catalogo de nomenclaturas, asi que sin el fixture los tres quedaban en
--     conteo 0 y empataban los TRES, no dos. Los tres complementos arrancan
--     con el MISMO token (CA, nivel 4) a proposito: asi esc5 no puede
--     discriminar por nivel y el caso llega a esc6, que es lo que se certifica.
--
-- esc5 (ARQ 41-45, 'BR 5' / 'AP 301') no necesita ajuste: los dos tokens si
-- estan en el catalogo, empatan en frecuencia 1 (esc4 no dispara) y sus
-- niveles difieren (BR=1, AP=7), que es justo lo que esc5 pide.
-- ============================================================

-- ============================================================
-- 6) REPORTES, CIIU Y CONTACTOS
-- ------------------------------------------------------------
-- SLCOPRBA-1356: una entidad base por relacion, MAS una segunda entidad para
-- el padre de esc3. Antes este comentario decia "numero_entidades_reportan no
-- es criterio en R2" y eso era FALSO: esc3 elige al padre por ID, y
--
--   ID = fecha_relacion_como_numero + numero_entidades_reportan + 10000000
--
-- (Tmp_Unificacion_E03_A, linea 530 de PRO_UnificacionR2.sql). El par se forma
-- en Tmp_Unificacion_E03_E1 con 'A.ID > B.ID' (linea 607), comparacion
-- ESTRICTA que el codigo reproduce fielmente. Con una sola entidad en todo el
-- mock, el ID quedaba determinado solo por la fecha, y en las posiciones
-- DENTRO, FUERA y NULL las dos direcciones del arquetipo comparten fecha: IDs
-- identicos, la desigualdad falla en los dos sentidos y NO se forma par. Por
-- eso ARQ 31, 32 y 33 daban 0 en el job #302 mientras ARQ 34 (CABALLO, fechas
-- distintas) si unificaba. El defecto estaba en el fixture, no en la logica.
--
-- El empate perfecto NO unifica, y eso es comportamiento legitimo del legado;
-- lo que no era legitimo es que el fixture lo provocara en tres posiciones que
-- existen para probar la VENTANA, no el desempate.
--
-- La segunda entidad va al k = 1 de esc_idx = 2, que es el padre que la semilla
-- ya documenta ("la ULTIMA de cada grupo es la hija", nk = 2). Con eso el padre
-- gana por entidades en las tres posiciones de fecha igual, y en CABALLO sigue
-- ganando -- ya ganaba por fecha -- de modo que el padre es el mismo en las
-- cuatro. El alcance esta acotado a las personas de ARQ 31..35 para no mover el
-- ID de ningun otro escenario ni el id_orden del motor.
--
-- El CIIU se fija en '99' (no esta en 10 / 81 / 82 / 90): esos arquetipos
-- caerian en el escenario 3 de Regla 1, pero R1 exige tipo de ubicacion
-- DISTINTO y aqui todas las direcciones son RES, asi que R1 no los toca. El
-- valor se deja explicito para que la inmunidad sea visible en los datos.
-- ============================================================
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT rpu.cod_dw_persona_ubic, 1001, CAST('2026-02-01' AS DATE)
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999
   OR rpu.id_buro_persona BETWEEN 9600000 AND 9600999;

-- Segunda entidad SOLO para el padre de esc3 (ARQ 31..35, k = 1).
-- k = 1 es la direccion cuyo cod_dw_persona_ubic coincide con su cod_dw_ubic,
-- porque ambos se construyen como (persona * 10 + 1).
-- ARQ 31 -> personas 9310000..9310999 ; ARQ 35 -> 9350000..9350999.
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT rpu.cod_dw_persona_ubic, 1002, CAST('2026-02-15' AS DATE)
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9310000 AND 9350999
  AND rpu.cod_dw_persona_ubic = rpu.cod_dw_ubic;

-- Segunda entidad para el k = 1 del ARQ 60, y por la misma razon de fondo que
-- la de esc3: sin ella hay EMPATE y el escenario no dispara. Aqui el empate
-- seria entre k=1 y k=3 -- las dos CRR, las dos con una entidad -- de modo que
-- el score maximo de R1 esc1 no seria UNICO, el ganador (HAVING COUNT(*) = 1)
-- no existiria y el arquetipo no produciria NINGUNA pareja, ni de R1 ni de R2.
-- Con la segunda entidad k=1 saca 100002 contra 100001 y queda de padre, que es
-- la premisa que G-02 necesita para despues verlo caer como hija en R2.
-- El k = 1 es el unico cuyo cod_dw_persona_ubic coincide con su cod_dw_ubic
-- (ambos son persona * 10 + 1).
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT rpu.cod_dw_persona_ubic, 1002, CAST('2026-02-15' AS DATE)
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9600000 AND 9600999
  AND rpu.cod_dw_persona_ubic = rpu.cod_dw_ubic;

INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT DISTINCT rpu.id_buro_persona, '99'
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999;

-- El ARQ 60 es la excepcion: su CIIU es '10' (asalariado) porque necesita que
-- R1 lo tome, y R1 esc1 -- el unico que prefiere LAB/CRR, que es como k=1 gana
-- la primera ronda -- se activa solo con '10'. Con '99' caeria en esc3, que no
-- tiene preferencia de tipo y elegiria por entidades sin que el tipo importe.
INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT DISTINCT rpu.id_buro_persona, '10'
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9600000 AND 9600999;

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
WHERE ( rpu.id_buro_persona BETWEEN 9210000 AND 9560999
     OR rpu.id_buro_persona BETWEEN 9600000 AND 9600999 )
  AND rpu.cod_dw_persona_ubic % 10 = 1;
