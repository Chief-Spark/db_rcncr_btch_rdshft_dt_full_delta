-- ============================================================
-- diagnostico_datashare_edf_views.sql
-- SLCOPRBA-1355: QUE HAY DE VERDAD EN EL DATASHARE.
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- NO VA EN deploy.par. Es un diagnostico de lectura, se corre a mano contra
-- DEV y su salida se pega en docs/PETICION_DATASHARE_F1_F3_ORDENAMIENTO.md.
-- No crea, no borra y no modifica nada.
--
-- POR QUE EXISTE
--
--   Ocho caracteristicas del Ordenamiento estan marcadas como bloqueadas por
--   el datashare, y la peticion al productor da por hecho que `edf_views`
--   expone CUATRO objetos. Esa afirmacion nunca se comprobo contra el
--   datashare: se comprobo contra nuestro propio codigo, que es otra cosa.
--
--   Las tres "verificaciones" que existen son la misma, contada tres veces:
--     - la peticion dice "verificado sobre los 25 archivos de DDL del repo"
--     - banco/stub_datashare.py DERIVA las tablas stub de nuestras vistas
--     - un grep de ds_dba_rncr_batch.edf_views.* sobre strct
--   Las tres miden lo que LEEMOS. Ninguna mira el catalogo.
--
--   El repo no pide `accounts` en ningun sitio, de modo que su SQL no prueba
--   que no exista: prueba que nunca lo intentamos. Esto lo resuelve.
--
-- NO SE PUEDE CORRER EN EL BANCO LOCAL. El banco es PostgreSQL y sus tablas
-- de edf_views las genera stub_datashare.py a partir de nuestras vistas, asi
-- que devolveria exactamente las cuatro que ya sabemos: la respuesta seria
-- circular. Hace falta una sesion contra el Redshift de DEV.
-- ============================================================

-- ------------------------------------------------------------
-- 1) EL CATALOGO COMPLETO. Es la consulta que decide el trabajo.
--
--    Si aparece xpm_accounts, xpm_tradelines o xpm_<algo>_val_accounts, las
--    caracteristicas bloqueadas NO son una peticion a otro equipo: son una
--    vista que nos falta escribir.
-- ------------------------------------------------------------
SELECT schema_name, table_name, table_type
  FROM svv_all_tables
 WHERE database_name = 'ds_dba_rncr_batch'
 ORDER BY schema_name, table_name;

-- ------------------------------------------------------------
-- 2) LAS COLUMNAS, para ver que ramas del payload relationalizado llegan.
--
--    El payload es salida de AWS Glue Relationalize: cada array anidado se
--    materializa en una tabla hija y el padre guarda un id de enlace. Hoy
--    conocemos cuatro entidades de primer nivel -- location,
--    location.val.contactinformations, counterparties y
--    bestpersonalinformation. Lo que se busca aqui es si hay una quinta.
-- ------------------------------------------------------------
SELECT table_name, column_name, data_type
  FROM svv_all_columns
 WHERE database_name = 'ds_dba_rncr_batch'
   AND schema_name   = 'edf_views'
 ORDER BY table_name, column_name;

-- ------------------------------------------------------------
-- 3) COBERTURA DE counterpartyidnumber.
--
--    Independiente de las dos anteriores y mas barata todavia.
--
--    id_buro_suscriptor (02_vistas_insumo_edf_views.sql:319-333) es un
--    COALESCE de tres ramas. Las DOS PRIMERAS leen columnas reales del
--    datashare; la tercera es
--        MOD(ABS(FNV_HASH(pin || ':' || ci.id)), 9998) + 1
--    una cubeta de hash que solo entra cuando las dos vienen nulas o fuera
--    del rango INTEGER.
--
--    O sea que la identidad del reportante YA ESTA publicada, al menos para
--    parte de las filas, y nadie ha medido cuantas caen al hash. De esa
--    fraccion depende:
--      - si CEL020 (suscriptores distintos del celular contra el total de la
--        persona, Caracteristicas.txt:3153-3164) es portable HOY
--      - si TEL023 y EMA024, que ya estan portadas contando
--        id_buro_suscriptor, estan midiendo suscriptores o ruido
--      - si EMA015, que hace COUNT(DISTINCT id_buro_suscriptor), cuenta
--        cubetas de hash como si fueran entidades distintas
--
--    Los joins son los mismos de 02_vistas_insumo_edf_views.sql:341-346.
-- ------------------------------------------------------------
SELECT COUNT(*)                                                      AS filas,
       SUM(CASE WHEN t.cp_ok  = 1                   THEN 1 ELSE 0 END) AS en_counterparties,
       SUM(CASE WHEN t.loc_ok = 1                   THEN 1 ELSE 0 END) AS en_location,
       SUM(CASE WHEN t.cp_ok = 1 OR t.loc_ok = 1    THEN 1 ELSE 0 END) AS con_suscriptor_real,
       SUM(CASE WHEN t.cp_ok = 0 AND t.loc_ok = 0   THEN 1 ELSE 0 END) AS al_hash,
       CAST(100.0 * SUM(CASE WHEN t.cp_ok = 0 AND t.loc_ok = 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) AS DECIMAL(18,2))                    AS pct_al_hash
  FROM (
    SELECT
      CASE WHEN NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') ~ '^[0-9]+$'
            AND CAST(NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') AS BIGINT) <= 2147483647
           THEN 1 ELSE 0 END AS cp_ok,
      CASE WHEN NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') ~ '^[0-9]+$'
            AND CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS BIGINT) <= 2147483647
           THEN 1 ELSE 0 END AS loc_ok
    FROM      ds_dba_rncr_batch.edf_views.xpm                                   xpm
    JOIN      ds_dba_rncr_batch.edf_views.xpm_location                          loc
           ON xpm.location = loc.id
    JOIN      ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations  ci
           ON loc."location.val.contactinformations" = ci.id
    LEFT JOIN ds_dba_rncr_batch.edf_views.xpm_counterparties                    cp
           ON xpm.counterparties = cp.id
  ) t;

-- ------------------------------------------------------------
-- 4) FORMA DEL cod_suscriptor, si resulta que llega.
--
--    El clasificador Portafolio_Nuevo del legado
--    (PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:378-396) parte del PREFIJO DE DOS
--    DIGITOS de un cod_suscriptor de SEIS. Diez de sus once ramas dependen
--    solo de ese codigo; unicamente portafolio = 'CO' necesita el tipo de
--    cuenta.
--
--    Si lo que llega por counterpartyidnumber tiene seis digitos, el
--    clasificador se reproduce casi entero SIN ESPERAR A F2, y con el
--    Sector {CO,CC,RE,FI,OT} que hoy sustituimos por una bandera 0/1.
--    Si llega con otra longitud o es un identificador distinto, no sirve y
--    conviene saberlo antes de prometerlo.
-- ------------------------------------------------------------
SELECT LENGTH(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR)) AS largo,
       LEFT(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), 2) AS prefijo_2,
       COUNT(*) AS filas
  FROM ds_dba_rncr_batch.edf_views.xpm_counterparties cp
 WHERE NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') IS NOT NULL
 GROUP BY 1, 2
 ORDER BY 3 DESC
 LIMIT 50;
