-- ============================================================
-- Perfilado de edf_views para la homologacion AS-IS -> Redshift.
-- 2026-10-20. SOLO LECTURA. Solo conteos y dominios de CODIGOS.
-- Ninguna consulta devuelve nombres, documentos, telefonos, correos
-- ni direcciones: para los campos de texto libre solo se cuenta si
-- vienen llenos.
--
-- NO va en deploy.par. Se corre a mano en el consumidor DEV y la
-- salida se pega en docs/edf_views/RESULTADOS_CONSULTAS_EDF.md.
-- Nombres con punto: siempre entre comillas dobles. "index" tambien.
-- Si el esquema no resuelve, anteponer ds_dba_rncr_batch.
-- ============================================================

-- C4a. La llave del contacto: el id de contactinformations es el ARREGLO?
SELECT COUNT(*)                                            AS filas,
       COUNT(DISTINCT id)                                  AS ids,
       COUNT(DISTINCT id::VARCHAR || ':' || "index"::VARCHAR) AS id_index
  FROM edf_views.xpm_location_val_contactinformations;

-- C4b. Cuantos tipos de contacto distintos comparte un mismo id
SELECT n_tipos, COUNT(*) AS ids
  FROM (SELECT id,
               COUNT(DISTINCT "location.val.contactinformations.val.contacttype") AS n_tipos
          FROM edf_views.xpm_location_val_contactinformations
         GROUP BY id) t
 GROUP BY n_tipos
 ORDER BY n_tipos;

-- C4c. Cardinalidad xpm -> location -> contactinformations
SELECT COUNT(*)                                                AS filas_location,
       COUNT(DISTINCT id)                                      AS ids_location,
       COUNT(DISTINCT id::VARCHAR || ':' || "index"::VARCHAR)  AS id_index_location,
       COUNT(DISTINCT "location.val.contactinformations")      AS arreglos_contacto
  FROM edf_views.xpm_location;

SELECT COUNT(*) AS filas_xpm, COUNT(DISTINCT pin) AS pines,
       COUNT(DISTINCT location) AS arreglos_location
  FROM edf_views.xpm;

-- C6a. Dominio de contacttype
SELECT "location.val.contactinformations.val.contacttype" AS contacttype, COUNT(*)
  FROM edf_views.xpm_location_val_contactinformations
 GROUP BY 1 ORDER BY 2 DESC;

-- C6b. Dominio de standardizedtipo y de contacttypereportedforfirsttime, cruzado con contacttype
SELECT "location.val.contactinformations.val.contacttype"                    AS contacttype,
       "location.val.contactinformations.val.standardizedtipo"               AS standardizedtipo,
       "location.val.contactinformations.val.contacttypereportedforfirsttime" AS tipo_primera_vez,
       COUNT(*)
  FROM edf_views.xpm_location_val_contactinformations
 GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 60;

-- C6c. Largo del codigo DANE (5 = municipio, 8 = centro poblado)
SELECT LEN(TRIM("location.val.contactinformations.val.standardizeddanecode")) AS largo_dane,
       COUNT(*)
  FROM edf_views.xpm_location_val_contactinformations
 GROUP BY 1 ORDER BY 1;

-- C8. Marca de DELTA del productor
SELECT delta_operation, source_type, generation, COUNT(*)
  FROM edf_views.xpm
 GROUP BY 1, 2, 3 ORDER BY 4 DESC;

-- C9. Dominios de persona (codigos, no personas)
SELECT "bestpersonalinformation.gender"   AS genero, COUNT(*) FROM edf_views.xpm GROUP BY 1 ORDER BY 2 DESC;
SELECT "bestpersonalinformation.agerange" AS rango_edad, COUNT(*) FROM edf_views.xpm GROUP BY 1 ORDER BY 1;
SELECT "bestpersonalinformation.citizentaxregistrationindicator" AS rut, COUNT(*) FROM edf_views.xpm GROUP BY 1;

-- C10. Identificacion "mejor" por persona: dominio y unicidad
SELECT "bestidentifications.val.personidtype" AS tipo_id,
       "bestidentifications.val.idstatus"     AS estado_id,
       COUNT(*)
  FROM edf_views.xpm_bestidentifications
 GROUP BY 1, 2 ORDER BY 3 DESC;

SELECT COUNT(*) AS filas, COUNT(DISTINCT id) AS ids,
       COUNT(DISTINCT id::VARCHAR || ':' || "index"::VARCHAR) AS id_index
  FROM edf_views.xpm_bestidentifications;

-- C11. Que tan llenos vienen los campos que el AS-IS saca de GEO o de catalogos
SELECT COUNT(*) AS filas,
       COUNT(NULLIF(TRIM("location.val.contactinformations.val.contactneighborhood"), '')) AS con_barrio,
       COUNT(NULLIF(TRIM("location.val.contactinformations.val.contactburroughs"), ''))    AS con_localidad,
       COUNT(NULLIF(TRIM("location.val.contactinformations.val.contactzipcode"), ''))      AS con_postal,
       COUNT(NULLIF(TRIM("location.val.contactinformations.val.website"), ''))             AS con_web,
       COUNT(NULLIF(TRIM("location.val.contactinformations.val.citycode"), ''))            AS con_citycode
  FROM edf_views.xpm_location_val_contactinformations;

SELECT "location.val.stratum" AS estrato, COUNT(*)
  FROM edf_views.xpm_location GROUP BY 1 ORDER BY 1;

-- C12. Tipo de dato del reporte
SELECT "location.val.typeofdata" AS typeofdata, COUNT(*)
  FROM edf_views.xpm_location GROUP BY 1 ORDER BY 2 DESC;

-- C13. Cuentas (F2): llave, tipos y bloqueo
SELECT COUNT(*) AS filas, COUNT(DISTINCT id) AS ids,
       COUNT(DISTINCT id::VARCHAR || ':' || "index"::VARCHAR) AS id_index
  FROM edf_views.xpm_bestaccounts;

SELECT "bestaccounts.val.accounttype" AS tipo_cuenta, COUNT(*)
  FROM edf_views.xpm_bestaccounts GROUP BY 1 ORDER BY 2 DESC;

SELECT "bestaccounts.val.blockreason", "bestaccounts.val.subscriberblockstatus",
       "bestaccounts.val.blockseverity", COUNT(*)
  FROM edf_views.xpm_bestaccounts GROUP BY 1, 2, 3 ORDER BY 4 DESC;

-- C14. Sector economico de la fuente (para SECTOR y sector financiero)
SELECT "counterparties.val.businesslines.val.economicsector" AS sector, COUNT(*)
  FROM edf_views.xpm_counterparties_val_businesslines GROUP BY 1 ORDER BY 2 DESC;

-- C15. Fan-out del join a counterparties (D-EDF-03). La vista de reporte une
-- xpm_counterparties por PERSONA (xpm.counterparties = cp.id): cada reporte se
-- repite tantas veces como contrapartes tenga la persona. Distribucion de
-- contrapartes por persona.
SELECT n_contrapartes, COUNT(*) AS personas
  FROM (SELECT x.pin, COUNT(cp.id) AS n_contrapartes
          FROM edf_views.xpm x
          LEFT JOIN edf_views.xpm_counterparties cp
            ON x.counterparties = cp.id
         GROUP BY x.pin) t
 GROUP BY 1 ORDER BY 1;

-- C16. Llenado del suscriptor y de la fecha de corte del propio reporte
-- (D-EDF-03 y D-EDF-04): sin suscriptor hoy cae a una cubeta de hash, y sin
-- fecha cae a CURRENT_DATE.
SELECT COUNT(*) AS filas,
       COUNT(NULLIF(TRIM("location.val.counterpartyidnumber"::VARCHAR), '')) AS con_suscriptor,
       SUM(CASE WHEN TRIM("location.val.counterpartyidnumber"::VARCHAR) ~ '^[0-9]+$'
                THEN 1 ELSE 0 END)                                          AS suscriptor_numerico,
       COUNT(NULLIF(TRIM("location.val.cutoffdate"::VARCHAR), ''))           AS con_fecha_corte,
       SUM(CASE WHEN TRIM("location.val.cutoffdate"::VARCHAR) ~ '^[0-9]+$'
                THEN 1 ELSE 0 END)                                          AS fecha_epoch
  FROM edf_views.xpm_location;

-- ============================================================
-- C17 a C20: verificacion de las hipotesis de RESULTADOS_CONSULTAS_EDF.md
-- (seccion 12). Agregadas: ninguna devuelve un valor de contacto.
-- ============================================================

-- C17. Direcciones por persona (brecha 2). Hoy todas las de una persona
-- comparten cod_dw_ubic; esto mide cuantas personas se cruzan.
SELECT n_direcciones, COUNT(*) AS personas
  FROM (SELECT loc.id, COUNT(*) AS n_direcciones
          FROM edf_views.xpm_location loc
          JOIN edf_views.xpm_location_val_contactinformations ci
            ON loc."location.val.contactinformations" = ci.id
         WHERE loc."index" IS NOT NULL
           AND ci."index" IS NOT NULL
           AND ci."location.val.contactinformations.val.contacttype"::VARCHAR IN ('1','2','3','8')
         GROUP BY loc.id) t
 GROUP BY 1 ORDER BY 1;

-- C18. Forma de cada tipo de contacto (brechas 1, 3 y 5): sin mostrar el
-- valor, si parece correo, celular colombiano, fijo o texto; y que trae de
-- ciudad.
SELECT ci."location.val.contactinformations.val.contacttype"::VARCHAR AS contacttype,
       COUNT(*) AS filas,
       SUM(CASE WHEN ci."location.val.contactinformations.val.contactasreported"::VARCHAR LIKE '%@%'
                THEN 1 ELSE 0 END) AS con_arroba,
       SUM(CASE WHEN REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreported"::VARCHAR, '[^0-9]', '') ~ '^3[0-9]{9}$'
                THEN 1 ELSE 0 END) AS forma_celular_co,
       SUM(CASE WHEN LEN(REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreported"::VARCHAR, '[^0-9]', '')) BETWEEN 7 AND 8
                THEN 1 ELSE 0 END) AS forma_fijo_7_8,
       SUM(CASE WHEN ci."location.val.contactinformations.val.contactasreported"::VARCHAR ~ '[A-Za-z]'
                THEN 1 ELSE 0 END) AS con_letras,
       AVG(LEN(ci."location.val.contactinformations.val.contactasreported"::VARCHAR)) AS largo_medio,
       COUNT(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '')) AS con_dane,
       COUNT(NULLIF(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR), ''))            AS con_citycode,
       MIN(LEN(NULLIF(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR), '')))       AS largo_min_citycode,
       MAX(LEN(NULLIF(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR), '')))       AS largo_max_citycode,
       COUNT(NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), ''))            AS con_cityname
  FROM edf_views.xpm_location_val_contactinformations ci
 WHERE ci."index" IS NOT NULL
 GROUP BY 1 ORDER BY 2 DESC;

-- C19. Que es la contraparte de la PERSONA (brecha 4): si son pocos valores
-- distintos, es la fuente y no un suscriptor.
SELECT "counterparties.val.counterpartyidtype"::VARCHAR AS tipo_id_contraparte,
       COUNT(*) AS filas,
       COUNT(NULLIF(TRIM("counterparties.val.counterpartyidnumber"::VARCHAR), '')) AS con_numero,
       COUNT(DISTINCT "counterparties.val.counterpartyidnumber")                    AS numeros_distintos
  FROM edf_views.xpm_counterparties
 WHERE "index" IS NOT NULL
 GROUP BY 1 ORDER BY 2 DESC;

SELECT COUNT(DISTINCT "location.val.counterpartyidnumber") AS suscriptores_distintos_en_reportes
  FROM edf_views.xpm_location
 WHERE "index" IS NOT NULL;

-- C20. Tipo de dato del reporte contra tipos de contacto y suscriptor
-- (brechas 3 y 8: typeofdata como fuente).
SELECT loc."location.val.typeofdata"::VARCHAR AS typeofdata,
       ci."location.val.contactinformations.val.contacttype"::VARCHAR AS contacttype,
       COUNT(*) AS contactos
  FROM edf_views.xpm_location loc
  JOIN edf_views.xpm_location_val_contactinformations ci
    ON loc."location.val.contactinformations" = ci.id
 WHERE loc."index" IS NOT NULL AND ci."index" IS NOT NULL
 GROUP BY 1, 2 ORDER BY 1, 3 DESC;

SELECT "location.val.typeofdata"::VARCHAR AS typeofdata,
       COUNT(*) AS reportes,
       COUNT(NULLIF(TRIM("location.val.counterpartyidnumber"::VARCHAR), '')) AS con_suscriptor,
       COUNT(NULLIF(TRIM("location.val.accounttype"::VARCHAR), ''))          AS con_tipo_cuenta,
       COUNT(NULLIF(TRIM("location.val.personidtype"::VARCHAR), ''))         AS con_tipo_id
  FROM edf_views.xpm_location
 WHERE "index" IS NOT NULL
 GROUP BY 1 ORDER BY 2 DESC;

-- C21. Forma del valor ESTANDARIZADO de telefonos y celulares (el repo usa
-- primero contactasreportedstandardized). Sin mostrar valores.
SELECT ci."location.val.contactinformations.val.contacttype"::VARCHAR AS contacttype,
       COUNT(*) AS filas,
       SUM(CASE WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), '') IS NULL THEN 1 ELSE 0 END) AS estandar_vacio,
       SUM(CASE WHEN REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR, '[^0-9]', '') ~ '^3[0-9]{9}$' THEN 1 ELSE 0 END) AS estandar_cel_10,
       SUM(CASE WHEN REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR, '[^0-9]', '') ~ '^573[0-9]{9}$' THEN 1 ELSE 0 END) AS estandar_cel_57,
       SUM(CASE WHEN REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreported"::VARCHAR, '[^0-9]', '') ~ '^573[0-9]{9}$' THEN 1 ELSE 0 END) AS reportado_cel_57,
       SUM(CASE WHEN REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR, '[^0-9]', '') ~ '^60[1-8][0-9]{7}$' THEN 1 ELSE 0 END) AS estandar_fijo_10,
       SUM(CASE WHEN ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR ~ '[^0-9]' THEN 1 ELSE 0 END) AS estandar_con_no_digitos,
       MIN(LEN(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''))) AS largo_min,
       MAX(LEN(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''))) AS largo_max
  FROM edf_views.xpm_location_val_contactinformations ci
 WHERE ci."index" IS NOT NULL
   AND ci."location.val.contactinformations.val.contacttype"::VARCHAR IN ('4', '5', '6', '9', '11')
 GROUP BY 1 ORDER BY 1;

-- C22. Telefonos de suscriptor (4, 5, 9): largo en digitos y prefijo de 2
-- digitos. El prefijo no identifica a nadie (es operador o indicativo).
SELECT ci."location.val.contactinformations.val.contacttype"::VARCHAR AS contacttype,
       LEN(REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreported"::VARCHAR, '[^0-9]', '')) AS digitos,
       LEFT(REGEXP_REPLACE(ci."location.val.contactinformations.val.contactasreported"::VARCHAR, '[^0-9]', ''), 2) AS prefijo2,
       SUM(CASE WHEN ci."location.val.contactinformations.val.contactasreported"::VARCHAR ~ '[^0-9]' THEN 1 ELSE 0 END) AS con_no_digitos,
       COUNT(*) AS filas
  FROM edf_views.xpm_location_val_contactinformations ci
 WHERE ci."index" IS NOT NULL
   AND ci."location.val.contactinformations.val.contacttype"::VARCHAR IN ('4', '5', '9')
 GROUP BY 1, 2, 3
 ORDER BY 1, 5 DESC;

-- ============================================================
-- C23 (2026-10-20): cuantos telefonos fijos (4, 5) y cuantos 11/13 traen
-- forma de celular una vez quitado el relleno de ceros. Solo conteos.
-- Decide si la regla de forma del 6 se extiende a los demas telefonos.
-- ============================================================
SELECT ct AS contacttype,
       COUNT(*) AS filas,
       SUM(CASE WHEN LEN(n) = 10 AND LEFT(n, 1) = '3' THEN 1 ELSE 0 END) AS forma_celular,
       SUM(CASE WHEN LEN(n) BETWEEN 7 AND 10 AND LEFT(n, 1) <> '3' THEN 1 ELSE 0 END) AS forma_fijo,
       SUM(CASE WHEN n IS NULL THEN 1 ELSE 0 END) AS vacios
FROM (
  SELECT NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') AS ct,
         NULLIF(LTRIM(REGEXP_REPLACE(COALESCE(
           NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
           NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')),
           '[^0-9]', ''), '0'), '') AS n
  FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
) x
WHERE ct IN ('4', '5', '6', '9', '11', '13')
GROUP BY 1
ORDER BY 1;
