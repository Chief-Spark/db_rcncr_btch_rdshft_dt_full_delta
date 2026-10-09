-- ============================================================
-- seed_mock_matriz.sql
-- Matriz de semillas MOCK para la certificacion FULL/DELTA.
-- (repo dt / db_rcncr_btch_rdshft_dt)
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Prerequisito: strct desplegado (bdm_stage.* y bdm_stage.mock_numeros).
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1356: genera un volumen amplio de semillas con resultado esperado
-- EXACTO y CALCULABLE.
--
-- METODO: generacion por ARQUETIPOS, no datos aleatorios.
--   Un arquetipo = una celda de la matriz (escenario de regla x posicion
--   respecto al Watermark). Cada arquetipo se replica N veces con IDs
--   distintos y estructura identica, de modo que
--       filas_esperadas = N x filas_por_caso
--   Sin RANDOM(): todo se deriva de bdm_stage.mock_numeros.i, asi que dos
--   ejecuciones producen exactamente los mismos datos y la evidencia de QA es
--   reproducible.
--
-- POR QUE UN GENERADOR Y NO INSERTs LITERALES: a N = 1000 son ~40.000 filas
-- solo en R1; un .sql con esa cantidad de INSERT ... VALUES pesa decenas de MB
-- y el pipeline lo ejecuta con rsql (candidato directo a timeout). Aqui cada
-- tabla se puebla con un unico INSERT ... SELECT contra mock_numeros.
--
-- ------------------------------------------------------------
-- ESQUEMA DE IDENTIFICADORES (decodificable, sin colisiones)
--   id_buro_persona        = 9000000 + ARQ * 10000 + i        (i = 0..N-1)
--   cod_dw_persona_ubic    = id_buro_persona * 10 + k         (k = direccion)
--   cod_dw_ubic            = id_buro_persona * 10 + 1         (compartido por
--                            las direcciones de la persona: misma ubicacion y
--                            por tanto mismo texto_ubicacion, que es lo que
--                            agrupan R1 y R2)
--   cod_dw_direccion_fisica= cod_dw_persona_ubic              (1:1, su propio
--                            complemento)
-- El arquetipo se recupera con  ARQ = (id_buro_persona - 9000000) / 10000,
-- lo que permite a los gates agrupar por caso sin tabla auxiliar.
--
-- Estos id_buro_persona (rango 9.01e6 .. 9.21e6) NO colisionan con los reales,
-- que son FNV_HASH(pin): valores de 64 bits, tipicamente negativos.
--
-- ------------------------------------------------------------
-- NUMERACION DE ARQUETIPOS
--   ARQ = (escenario - 1) * 5 + posicion
--   escenario R1: 1 = E1 (CIIU 10)      2 = E2 (CIIU 81/82/90)
--                 3 = E3 (otros CIIU)   4 = EMPATE
--   posicion:     1 = DENTRO   2 = FUERA   3 = NULL
--                 4 = CABALLO  5 = YA_UNIFICADA
--   => ARQ 1..20 = Regla 1.   ARQ 21..55 reservados para Regla 2.
--      ARQ 56    = GEO_CON_COORDENADAS.
--
-- ------------------------------------------------------------
-- POSICIONES RESPECTO AL WATERMARK
--   El FULL siembra el Watermark con MAX(fecha_relacion_persona_ubicaci) del
--   universo mock = 2026-03-01. La ventana DELTA es entonces
--       fecha >= 2026-03-01  OR  fecha IS NULL
--   DENTRO : ambas direcciones 2026-03-01  -> persona en la ventana.
--   FUERA  : ambas 2024-01-15              -> persona fuera de la ventana.
--   NULL   : ambas NULL                    -> siempre dentro (nulo inclusivo).
--   CABALLO: una 2026-03-01 y otra 2024-01-15. Es EL caso que certifica la
--            ventana por persona: con filtro por fila la persona llegaria al
--            insumo con una sola direccion y no se unificaria nunca.
--   YA_UNIF: fechas dentro, pero la HIJA lleva ind_unificacion = 1. Certifica
--            el mecanismo incremental por ESTADO del legado Teradata
--            ("las direcciones ya unificadas no deben volver a tomarse").
--
-- ------------------------------------------------------------
-- RESULTADO ESPERADO POR ARQUETIPO (filas en unificacion_direccion_mock,
-- por replica; multiplicar por N)
--
--   escenario   DENTRO  FUERA  NULL  CABALLO  YA_UNIF
--   E1               1      1*     1        1        0
--   E2               1      1*     1        1        0
--   E3               1      1*     1        1        0
--   EMPATE           0      0      0        0        0
--
--   (*) FUERA produce la fila en el FULL (sin frontera) pero NO en el DELTA,
--       donde la persona queda fuera del driver. La fila del FULL sobrevive
--       con su lote original y NO se re-toca: su lote_actualizacion queda NULL.
--
--   EMPATE da 0 siempre: los dos scores maximos empatan y el ganador exige
--   HAVING COUNT(*) = 1.
-- ============================================================

-- N = numero de replicas por arquetipo. 20 arquetipos R1 x 1000 = 20.000
-- personas y ~40.000 relaciones solo en esta entrega. Subir N aqui es el unico
-- cambio necesario para escalar (mock_numeros llega a 9999).

-- ------------------------------------------------------------
-- Limpieza idempotente del rango que posee este script (ARQ 1..20).
-- Se borra por rango de id para no tocar semillas de otros arquetipos.
-- ------------------------------------------------------------
DELETE FROM bdm_stage.contacto_canal             WHERE id_buro_persona BETWEEN 9010000 AND 9200999;
DELETE FROM bdm_stage.ciiu_persona               WHERE id_buro_persona BETWEEN 9010000 AND 9200999;
DELETE FROM bdm_stage.reporte_relacion_persona_ubica WHERE cod_dw_persona_ubic BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.direccion_fisica           WHERE cod_dw_direccion_fisica BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.ubicacion_estandarizada    WHERE cod_dw_ubic BETWEEN 90100000 AND 92009999;
DELETE FROM bdm_stage.relacion_persona_ubicacion WHERE id_buro_persona BETWEEN 9010000 AND 9200999;

-- ============================================================
-- 1) PERSONAS Y SUS DOS DIRECCIONES (padre k=1, hija k=2)
-- ------------------------------------------------------------
-- La definicion de cada arquetipo vive en la subconsulta 'arq':
--   tipo_padre / tipo_hija : cod_dw_tipo_ubicacion_dir (1=RES, 2=LAB, 3=CRR)
--   fecha_padre / fecha_hija: posicion respecto al Watermark
--   indunif_hija           : 1 marca la hija como ya unificada
-- Los tipos se eligen para que el PADRE gane el score de su escenario:
--   E1 (CIIU 10)     -> padre CRR, hija RES  (CRR suma 100000, RES no)
--   E2 (CIIU 81)     -> padre CRR, hija LAB  (CRR suma 100000, LAB no)
--   E3 (otros CIIU)  -> gana el de mas entidades; tipos distintos para que el
--                       par padre/hija sea valido (exige tipo distinto)
--   EMPATE (CIIU 10) -> LAB y CRR, ambos suman 100000 y mismas entidades
-- ============================================================
INSERT INTO bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
  cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
  orden_prioridad, fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte
)
SELECT
  (9000000 + arq.arq * 10000 + n.i) * 10 + d.k            AS cod_dw_persona_ubic,
   9000000 + arq.arq * 10000 + n.i                        AS id_buro_persona,
   9000000 + arq.arq * 10000 + n.i                        AS cod_pin_persona,
  (9000000 + arq.arq * 10000 + n.i) * 10 + 1              AS cod_dw_ubic,
  (9000000 + arq.arq * 10000 + n.i) * 10 + d.k            AS cod_dw_direccion_fisica,
  CASE WHEN d.k = 1 THEN arq.tipo_padre ELSE arq.tipo_hija END AS cod_dw_tipo_ubicacion_dir,
  CASE WHEN d.k = 2 THEN NULLIF(arq.indunif_hija, 0) ELSE NULL END AS ind_unificacion,
  d.k                                                     AS orden_prioridad,
  CASE WHEN d.k = 1 THEN arq.fecha_padre ELSE arq.fecha_hija END AS fecha_relacion_persona_ubicaci,
  1356301                                                 AS lote,
  '1'                                                     AS cod_tipo_ident_fte
FROM (
  --   arq  ciiu  tipo_padre tipo_hija  ent_padre ent_hija  fecha_padre     fecha_hija      indunif_hija
  SELECT  1 AS arq, '10' AS ciiu, 3 AS tipo_padre, 1 AS tipo_hija, 1 AS ent_padre, 1 AS ent_hija, CAST('2026-03-01' AS DATE) AS fecha_padre, CAST('2026-03-01' AS DATE) AS fecha_hija, 0 AS indunif_hija UNION ALL
  SELECT  2, '10', 3, 1, 1, 1, CAST('2024-01-15' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT  3, '10', 3, 1, 1, 1, CAST(NULL AS DATE),         CAST(NULL AS DATE),         0 UNION ALL
  SELECT  4, '10', 3, 1, 1, 1, CAST('2026-03-01' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT  5, '10', 3, 1, 1, 1, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 1 UNION ALL
  SELECT  6, '81', 3, 2, 1, 1, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 0 UNION ALL
  SELECT  7, '81', 3, 2, 1, 1, CAST('2024-01-15' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT  8, '81', 3, 2, 1, 1, CAST(NULL AS DATE),         CAST(NULL AS DATE),         0 UNION ALL
  SELECT  9, '81', 3, 2, 1, 1, CAST('2026-03-01' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT 10, '81', 3, 2, 1, 1, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 1 UNION ALL
  SELECT 11, '47', 3, 1, 3, 1, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 0 UNION ALL
  SELECT 12, '47', 3, 1, 3, 1, CAST('2024-01-15' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT 13, '47', 3, 1, 3, 1, CAST(NULL AS DATE),         CAST(NULL AS DATE),         0 UNION ALL
  SELECT 14, '47', 3, 1, 3, 1, CAST('2026-03-01' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT 15, '47', 3, 1, 3, 1, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 1 UNION ALL
  SELECT 16, '10', 2, 3, 5, 5, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 0 UNION ALL
  SELECT 17, '10', 2, 3, 5, 5, CAST('2024-01-15' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT 18, '10', 2, 3, 5, 5, CAST(NULL AS DATE),         CAST(NULL AS DATE),         0 UNION ALL
  SELECT 19, '10', 2, 3, 5, 5, CAST('2026-03-01' AS DATE), CAST('2024-01-15' AS DATE), 0 UNION ALL
  SELECT 20, '10', 2, 3, 5, 5, CAST('2026-03-01' AS DATE), CAST('2026-03-01' AS DATE), 1
) arq
CROSS JOIN (SELECT 1 AS k UNION ALL SELECT 2) d
CROSS JOIN bdm_stage.mock_numeros n
WHERE n.i < 1000;

-- ============================================================
-- 2) UBICACION (una por persona: texto y ciudad compartidos por sus direcciones)
-- ------------------------------------------------------------
-- latitud/longitud NULL: todas las ubicaciones son Ubicacion_Candidata para el
-- Exportador_GEO. El arquetipo con coordenadas (ARQ 56) se sembrara aparte.
-- ============================================================
INSERT INTO bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, municipio, departamento, latitud, longitud
)
SELECT DISTINCT
  rpu.cod_dw_ubic,
  'CL ' || CAST(100 + (rpu.id_buro_persona - 9000000) / 10000 AS VARCHAR)
        || ' # ' || CAST(rpu.id_buro_persona AS VARCHAR) || ' - 20'  AS texto_ubicacion,
  11001            AS cod_dw_ciudad,
  'BOGOTA D.C.'    AS municipio,
  'CUNDINAMARCA'   AS departamento,
  CAST(NULL AS DECIMAL(12,8)) AS latitud,
  CAST(NULL AS DECIMAL(12,8)) AS longitud
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9010000 AND 9200999;

-- ============================================================
-- 3) DIRECCION FISICA (una por relacion, con su propio complemento)
-- ------------------------------------------------------------
-- En Regla 1 el complemento no participa del criterio; se siembra distinto por
-- direccion para que los datos sean realistas y para no inducir sin querer
-- emparejamientos de Regla 2 sobre estas mismas personas.
-- ============================================================
INSERT INTO bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica, complemento, cod_dw_ubic, generada_enriquecida
)
SELECT
  rpu.cod_dw_direccion_fisica,
  'AP ' || CAST(100 + (rpu.cod_dw_persona_ubic % 10) AS VARCHAR) AS complemento,
  rpu.cod_dw_ubic,
  0
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9010000 AND 9200999;

-- ============================================================
-- 4) REPORTES POR RELACION  -> numero_entidades_reportan
-- ------------------------------------------------------------
-- numero_entidades_reportan = COUNT(DISTINCT id_buro_suscriptor) por RPU.
-- Es el criterio de desempate de E1/E2 y el criterio PRINCIPAL de E3, donde el
-- padre debe reportar mas entidades que la hija.
-- id_buro_suscriptor se mantiene en el rango 1001..1005: solo importa que sean
-- distintos DENTRO de la misma RPU, y asi no desborda el INTEGER de la tabla.
-- ============================================================
INSERT INTO bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic, id_buro_suscriptor, fecha_reporte
)
SELECT
  rpu.cod_dw_persona_ubic,
  1000 + j.j                       AS id_buro_suscriptor,
  CAST('2026-02-01' AS DATE)       AS fecha_reporte
FROM bdm_stage.relacion_persona_ubicacion rpu
CROSS JOIN (SELECT 1 AS j UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) j
WHERE rpu.id_buro_persona BETWEEN 9010000 AND 9200999
  AND j.j <= CASE
        -- E3 (ARQ 11..15): el padre (k=1, cod_dw_persona_ubic impar en su
        -- ultimo digito = 1) reporta 3 entidades y la hija 1.
        WHEN (rpu.id_buro_persona - 9000000) / 10000 BETWEEN 11 AND 15
             THEN CASE WHEN rpu.cod_dw_persona_ubic % 10 = 1 THEN 3 ELSE 1 END
        -- EMPATE (ARQ 16..20): ambas con 5, para que los scores empaten.
        WHEN (rpu.id_buro_persona - 9000000) / 10000 BETWEEN 16 AND 20
             THEN 5
        -- E1 / E2: una entidad por direccion; el tipo decide el score.
        ELSE 1
      END;

-- ============================================================
-- 5) CIIU POR PERSONA (selector de escenario en Regla 1)
-- ------------------------------------------------------------
--   '10'          -> escenario 1
--   '81','82','90'-> escenario 2
--   cualquier otro-> escenario 3
-- ============================================================
INSERT INTO bdm_stage.ciiu_persona (id_buro_persona, cod_act_econo_ciiu_fte)
SELECT DISTINCT
  rpu.id_buro_persona,
  CASE
    WHEN (rpu.id_buro_persona - 9000000) / 10000 BETWEEN  6 AND 10 THEN '81'
    WHEN (rpu.id_buro_persona - 9000000) / 10000 BETWEEN 11 AND 15 THEN '47'
    ELSE '10'
  END AS cod_act_econo_ciiu_fte
FROM bdm_stage.relacion_persona_ubicacion rpu
WHERE rpu.id_buro_persona BETWEEN 9010000 AND 9200999;

-- ============================================================
-- 6) CONTACTOS DE CANAL (TEL / CEL / EMA) PARA EL ORDENAMIENTO
-- ------------------------------------------------------------
-- Se cuelgan de la direccion PADRE (k=1), que es la que sobrevive a la
-- unificacion. El Ordenamiento solo toma canales de personas con al menos una
-- RPU no-hija (stg_persona_dir_ganadora), de modo que estos contactos entran al
-- scoring TEL/CEL/EMA.
-- Codificacion de contact_type del datashare:
--   '4','5','8' -> telefono fijo   '9' -> celular   '10' -> correo
-- El telefono se siembra numerico y de 7+ digitos para que el insumo TEL lo
-- clasifique 'VALIDA'; el celular con prefijo 310 para que resuelva operador.
-- ============================================================
INSERT INTO bdm_stage.contacto_canal (
  cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, contact_type,
  valor_contacto, texto_ubicacion_vinculo, cod_dane_ciudad, fecha_contacto,
  id_buro_suscriptor
)
SELECT
  rpu.cod_dw_persona_ubic,
  rpu.id_buro_persona,
  rpu.cod_pin_persona,
  c.contact_type,
  CASE c.contact_type
    WHEN '4'  THEN '601' || LPAD(CAST(rpu.id_buro_persona % 10000000 AS VARCHAR), 7, '0')
    WHEN '9'  THEN '310' || LPAD(CAST(rpu.id_buro_persona % 10000000 AS VARCHAR), 7, '0')
    ELSE           'mock' || CAST(rpu.id_buro_persona AS VARCHAR) || '@gmail.com'
  END                              AS valor_contacto,
  ubi.texto_ubicacion              AS texto_ubicacion_vinculo,
  11001                            AS cod_dane_ciudad,
  CAST('2026-02-15' AS DATE)       AS fecha_contacto,
  1001                             AS id_buro_suscriptor
FROM bdm_stage.relacion_persona_ubicacion rpu
JOIN bdm_stage.ubicacion_estandarizada ubi
  ON ubi.cod_dw_ubic = rpu.cod_dw_ubic
CROSS JOIN (SELECT '4' AS contact_type UNION ALL SELECT '9' UNION ALL SELECT '10') c
WHERE rpu.id_buro_persona BETWEEN 9010000 AND 9200999
  AND rpu.cod_dw_persona_ubic % 10 = 1;
