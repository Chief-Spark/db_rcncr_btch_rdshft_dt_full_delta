-- ============================================================
-- seed_mock_matriz_r2.sql
-- Matriz de semillas MOCK -- Regla 2 (ARQ 21..55) + GEO con coordenadas (ARQ 56).
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
--   debajo. De ahi las tres direcciones: 10, 10 y 3.
--   CONSECUENCIA: esc6 empareja la de menor frecuencia contra CADA una de las
--   empatadas, asi que produce DOS filas -- una hija con dos padres. No es un
--   error de la semilla: es el comportamiento del escenario.
--   Los tres complementos arrancan con el MISMO token (CA) para que
--   nomenclatura_pri sea igual en los tres y esc5 tampoco los capture: esc5
--   exige a.nomenclatura_pri <> b.nomenclatura_pri. El diccionario
--   (bdm_stage.diccionario_complementos) y el catalogo de niveles
--   (bdm_stage.nomenclatura) son tablas distintas.
--
--   E7 motor              TRES direcciones, CON NIT: 'BR 5' (padre, BR nivel 1),
--                          'AP 301 TO 2' y 'AP 302 CS 4' (hijos, los dos
--                          arrancan con AP nivel 7). Certifica el motor de
--                          direcciones nuevas, que antes era INOBSERVABLE: el
--                          SP se quedaba en staging y no escribia en ninguna
--                          tabla. Ahora persiste en
--                          bdm_datos.direccion_fisica_generada_mock y
--                          bdm_datos.rpu_generada_mock.
--
-- POR QUE E7 ES ASI
--   El legado crea direcciones nuevas en DOS sitios (PRO_UnificacionR2.sql
--   lineas 1602 y 3423, los unicos con REC_MTDAT.MAX_ID), al final de las
--   cadenas E03 y E051, es decir sobre los pares que marcaron esc3 y esc5. Emite
--   UNA direccion por PADRE agregando TODOS sus hijos, con complemento
--   COMPLEMENTO_PADRE || NUEVA_NOMENCLATURA.
--
--   Para ejercitar el caso de un padre con VARIOS hijos hace falta que los hijos
--   NO se emparejen entre si. esc5 empareja con
--   a.nomenclatura_pri <> b.nomenclatura_pri, asi que los dos hijos comparten
--   token inicial (AP) y solo se emparejan contra 'BR 5'. Con tres niveles
--   DISTINTOS el arquetipo seria AMBIGUO: 'BR 5'/'TO 2'/'AP 301' genera los
--   pares (BR,TO), (BR,AP) y (TO,AP), y como el UPDATE de esc5 lleva
--   'AND id_padre IS NULL' el padre de AP depende de cual fila gane primero.
--
--   Asi queda, con un solo padre y dos hijos:
--     diccionario  BR:v=5,f=1  AP:v=301,f=2  TO:v=2,f=1  CS:v=4,f=1
--     conteos      'BR 5'=1  'AP 301 TO 2'=3  'AP 302 CS 4'=3
--                  -> esc4 empata en el maximo (2 filas) y no dispara
--     esc5         padre 'BR 5' (nivel 1), hijos los dos AP (nivel 7)
--     aporte nuevo TO y CS de los hijos, mas AP que el padre no tiene.
--                  AP lo aportan los DOS hijos: se conserva UNO, el del hijo de
--                  menor cod_dw_persona_ubic (k=2), que es el caso de
--                  deduplicacion por 'nomen' que se quiere certificar.
--     resultado    nueva_nomenclatura = 'TO 2 CS 4 AP 301'  (nivel ASC)
--                  complemento_motor  = 'BR 5 TO 2 CS 4 AP 301'
--
--   OJO con la posicion YA_UNIF (pi=5): marca la ULTIMA direccion (k=nk=3,
--   'AP 302 CS 4') con ind_unificacion = 1 y el filtro de estado la saca del
--   insumo. A diferencia del resto de arquetipos, el grupo NO se queda sin
--   pareja porque quedan dos direcciones: sigue generando, pero sin el aporte
--   de CS -> complemento_motor = 'BR 5 TO 2 AP 301'.
--
-- QUE ARQUETIPOS GENERAN DIRECCION (poblacion del motor: n_id en 'L3','E5')
--   E3 (esc3, 'L3')  los dos complementos tienen el MISMO nomen (AP), el hijo
--                    no aporta nada -> NO genera.
--   E5 (esc5, 'E5')  padre 'BR 5', hijo 'AP 301' -> genera 'BR 5 AP 301'.
--   E7 (esc5, 'E5')  padre con dos hijos -> genera 'BR 5 TO 2 CS 4 AP 301'.
--   E1, E2, E4, E6   marcan 'H1', 'K2', 'B5' o no marcan: fuera de la poblacion.
--                    En particular E6 no genera, igual que en el legado, donde
--                    la cadena E06 no contiene MAX_ID.
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
--   E6 (via esc6)             2      2*     2        2        0
--   E7 (via esc5)             1      1*     1        1        1
--
--   Direcciones generadas por el motor (filas en direccion_fisica_generada_mock
--   y rpu_generada_mock por replica; una por PADRE):
--
--   escenario            DENTRO  FUERA  NULL  CABALLO  YA_UNIF
--   E5 (padre 'BR 5')         1      1*     1        1        0
--   E7 (padre 'BR 5')         1      1*     1        1        1
--   los demas                 0      0      0        0        0
--
--   (*) FUERA produce la fila en el FULL pero 0 en el DELTA: la persona no
--       tiene ninguna relacion en la ventana y no entra al driver.
--   YA_UNIF marca la ULTIMA direccion del grupo (la hija) con
--   ind_unificacion = 1; el filtro de estado del legado la saca del insumo y el
--   grupo se queda sin pareja. En E6 eso deja a 'CA 1 LT 2' y 'CA 3 LT 4'
--   empatadas, de modo que ni esc4 ni esc6 disparan: 0 filas, igual que el
--   resto.
-- ============================================================

-- ------------------------------------------------------------
-- Limpieza idempotente del rango que posee este script:
-- ARQ 21..50 (Regla 2) y ARQ 56 (GEO con coordenadas).
-- ------------------------------------------------------------
DELETE FROM bdm_stage.contacto_canal                 WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.diccionario_complementos       WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.ciiu_persona                   WHERE id_buro_persona BETWEEN 9210000 AND 9560999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.direccion_fisica               WHERE cod_dw_direccion_fisica BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.ubicacion_estandarizada        WHERE cod_dw_ubic BETWEEN 92100000 AND 95609999;
DELETE FROM bdm_stage.relacion_persona_ubicacion     WHERE id_buro_persona BETWEEN 9210000 AND 9560999;

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
DELETE FROM bdm_stage.nomenclatura;
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
  SELECT 6, 1, 3, 'BR 5'        , '3' UNION ALL
  SELECT 6, 2, 3, 'AP 301 TO 2' , '3' UNION ALL
  SELECT 6, 3, 3, 'AP 302 CS 4' , '3'
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
-- 3) UBICACION (una por persona). Coordenadas NULL salvo el ARQ 56.
-- ============================================================
INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento, latitud, longitud
)
SELECT DISTINCT
  rpu.cod_dw_ubic,
  'CL ' || CAST(100 + (rpu.id_buro_persona - 9000000) / 10000 AS VARCHAR)
        || ' # ' || CAST(rpu.id_buro_persona AS VARCHAR) || ' - 20',
  11001, 'BOGOTA D.C.', 'CUNDINAMARCA',
  CASE WHEN rpu.id_buro_persona BETWEEN 9560000 AND 9560999
       THEN CAST( 4.60971000 AS DECIMAL(12,8)) ELSE CAST(NULL AS DECIMAL(12,8)) END,
  CASE WHEN rpu.id_buro_persona BETWEEN 9560000 AND 9560999
       THEN CAST(-74.08175000 AS DECIMAL(12,8)) ELSE CAST(NULL AS DECIMAL(12,8)) END
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999;

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
  SELECT 6, 1, 'BR 5'          UNION ALL
  SELECT 6, 2, 'AP 301 TO 2'   UNION ALL
  SELECT 6, 3, 'AP 302 CS 4'
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
-- numero_entidades_reportan no es criterio en R2; una entidad por relacion.
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
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999;

INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT DISTINCT rpu.id_buro_persona, '99'
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999;

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
WHERE rpu.id_buro_persona BETWEEN 9210000 AND 9560999
  AND rpu.cod_dw_persona_ubic % 10 = 1;
