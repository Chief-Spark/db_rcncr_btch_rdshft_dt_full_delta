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

-- ============================================================
-- C24 (2026-10-20, CORREGIDA): score de la direccion estandarizada.
-- Negocio: debe ser mayor a 80 %. Confluence (Libreria Estandarizacion,
-- EDCLMI 345374895): escala 0 a 1 como texto; 0.96 y 0.95 alta, 0.80
-- urbana sin geografia confiable, 0.65 rural, 0.50 descriptiva. La version
-- anterior comparaba contra 80 y siempre habria dado cero.
-- Distribucion por contacttype y valor redondeado a 2 decimales. Solo conteos.
-- ============================================================
SELECT ct AS contacttype,
       CASE WHEN s IS NULL THEN '(sin score)'
            WHEN s !~ '^[0-9]+([.][0-9]+)?$' THEN '(no numerico)'
            ELSE CAST(ROUND(CAST(s AS DECIMAL(12,4)), 2) AS VARCHAR(10)) END AS score,
       COUNT(*) AS filas
FROM (SELECT NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR),'') AS ct,
             NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR),'') AS s
      FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
      WHERE ci."index" IS NOT NULL) x
GROUP BY 1, 2
ORDER BY 1, 2;

-- C24b: resumen de las dos lecturas del umbral, solo direcciones (1, 2, 3, 7, 8).
SELECT ct AS contacttype,
       COUNT(*) AS direcciones,
       SUM(CASE WHEN s ~ '^[0-9]+([.][0-9]+)?$' AND CAST(s AS DECIMAL(12,4)) >  0.80 THEN 1 ELSE 0 END) AS mayor_080,
       SUM(CASE WHEN s ~ '^[0-9]+([.][0-9]+)?$' AND CAST(s AS DECIMAL(12,4)) >= 0.80 THEN 1 ELSE 0 END) AS mayor_igual_080,
       SUM(CASE WHEN s IS NULL THEN 1 ELSE 0 END) AS sin_score
FROM (SELECT NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR),'') AS ct,
             NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR),'') AS s
      FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
      WHERE ci."index" IS NOT NULL) x
WHERE ct IN ('1','2','3','7','8')
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- C25 (2026-10-20): GENERO. Dominio del codigo y una pista para deducir cual
-- es M y cual F sin sacar nombres: cuantos primeros nombres terminan en A y
-- cuantos en O por codigo (en castellano, A suele ser femenino y O
-- masculino). Una persona juridica no tiene primer nombre. Solo conteos.
-- ============================================================
SELECT x."bestpersonalinformation.gender" AS gender,
       COUNT(*) AS personas,
       SUM(CASE WHEN UPPER(RIGHT(TRIM(x."bestname.firstname"), 1)) = 'A' THEN 1 ELSE 0 END) AS nombre_termina_en_a,
       SUM(CASE WHEN UPPER(RIGHT(TRIM(x."bestname.firstname"), 1)) = 'O' THEN 1 ELSE 0 END) AS nombre_termina_en_o,
       SUM(CASE WHEN NULLIF(TRIM(x."bestname.firstname"), '') IS NULL THEN 1 ELSE 0 END) AS sin_primer_nombre,
       MIN(x."bestpersonalinformation.agerange") AS rango_edad_min,
       MAX(x."bestpersonalinformation.agerange") AS rango_edad_max
FROM ds_dba_rncr_batch.edf_views.xpm x
GROUP BY 1
ORDER BY 2 DESC;

-- ============================================================
-- C26 (2026-10-20): ESTADO DEL DOCUMENTO. idstatus y businessidstatus por
-- tipo de identificacion (1 CC, 2 NIT, 3 PJE, 4 CE... segun ID Type NH):
-- si businessidstatus solo aparece con NIT, es el estado de la empresa.
-- ============================================================
SELECT b."bestidentifications.val.personidtype"    AS personidtype,
       b."bestidentifications.val.idstatus"         AS idstatus,
       b."bestidentifications.val.businessidstatus" AS businessidstatus,
       COUNT(*) AS filas
FROM ds_dba_rncr_batch.edf_views.xpm_bestidentifications b
WHERE b."index" IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC;

-- ============================================================
-- C27 (2026-10-20): SECTOR ECONOMICO de la linea de negocio de cada
-- contraparte (son entidades, no personas). El nombre de la linea de negocio
-- ayuda a deducir el codigo del sector.
-- ============================================================
SELECT bl."counterparties.val.businesslines.val.economicsector"   AS economicsector,
       COUNT(*)                                                    AS lineas,
       COUNT(DISTINCT bl."counterparties.val.businesslines.val.businesslinename") AS nombres_distintos,
       MIN(bl."counterparties.val.businesslines.val.businesslinename") AS ejemplo_nombre_1,
       MAX(bl."counterparties.val.businesslines.val.businesslinename") AS ejemplo_nombre_2
FROM ds_dba_rncr_batch.edf_views.xpm_counterparties_val_businesslines bl
WHERE bl."index" IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

-- ============================================================
-- C28 (2026-10-20, de paso para el pedido 3): que typeofdata declara cada
-- linea de negocio. Junta el codigo con el nombre de la linea y sirve para
-- deducir que fuente es cada typeofdata (por ejemplo, si el 6 sale con
-- lineas de Camara de Comercio).
-- ============================================================
SELECT l."counterparties.val.businesslines.val.listoftypeofdata.val" AS typeofdata,
       COUNT(*) AS lineas,
       MIN(bl."counterparties.val.businesslines.val.businesslinename") AS ejemplo_linea_1,
       MAX(bl."counterparties.val.businesslines.val.businesslinename") AS ejemplo_linea_2
FROM ds_dba_rncr_batch.edf_views.xpm_counterparties_val_businesslines_val_listoftypeofdata l
JOIN ds_dba_rncr_batch.edf_views.xpm_counterparties_val_businesslines bl
  ON bl."counterparties.val.businesslines.val.listoftypeofdata" = l.id
WHERE l."index" IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- C29 (2026-10-20): los diez nombres de linea de negocio mas frecuentes por
-- sector economico, para confirmar F / R / C. Son nombres de entidades.
-- ============================================================
SELECT economicsector, nombre_linea, lineas
FROM (
  SELECT es AS economicsector, nombre AS nombre_linea, n AS lineas,
         ROW_NUMBER() OVER (PARTITION BY es ORDER BY n DESC) AS rn
  FROM (
    SELECT NULLIF(TRIM(bl."counterparties.val.businesslines.val.economicsector"), '') AS es,
           TRIM(bl."counterparties.val.businesslines.val.businesslinename")           AS nombre,
           COUNT(*) AS n
    FROM ds_dba_rncr_batch.edf_views.xpm_counterparties_val_businesslines bl
    WHERE bl."index" IS NOT NULL
    GROUP BY 1, 2
  ) a
  WHERE es IS NOT NULL
) b
WHERE rn <= 10
ORDER BY economicsector, lineas DESC;

-- ============================================================
-- C30 (2026-10-20): cuantos reportes de location encontrarian sector por el
-- NIT del suscriptor (location.counterpartyidnumber = contraparte -> lineas
-- de negocio -> sector). Solo conteos.
-- ============================================================
SELECT COALESCE(s.sector, '(sin sector)') AS sector,
       COUNT(*)                            AS reportes
FROM ds_dba_rncr_batch.edf_views.xpm_location loc
LEFT JOIN (
  SELECT NULLIF(TRIM(c."counterparties.val.counterpartyidnumber"), '') AS nit,
         MAX(NULLIF(TRIM(bl."counterparties.val.businesslines.val.economicsector"), '')) AS sector
  FROM ds_dba_rncr_batch.edf_views.xpm_counterparties c
  JOIN ds_dba_rncr_batch.edf_views.xpm_counterparties_val_businesslines bl
    ON bl.id = c."counterparties.val.businesslines"
  WHERE c."index" IS NOT NULL AND bl."index" IS NOT NULL
  GROUP BY 1
) s
  ON s.nit = NULLIF(TRIM(loc."location.val.counterpartyidnumber"), '')
WHERE loc."index" IS NOT NULL
  AND NULLIF(TRIM(loc."location.val.counterpartyidnumber"), '') IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

-- ============================================================
-- C31 (2026-10-20): BLOQUEO DE CUENTA. Confluence (Data Provisioning -
-- Filters, 251240769): los reportes de location cuya cuenta tiene
-- bestaccounts.blockseverity = 1 no se muestran a productos. La llave es
-- businesslinecode + accounttype + accountnumber + personidtype +
-- personidnumber, dentro de la misma persona (xpm). Primero se agrega por
-- reporte para no contar dos veces uno que case con dos cuentas. Solo conteos.
-- ============================================================
SELECT r.typeofdata,
       CASE WHEN r.con_cuenta = 0 THEN '(sin cuenta que case)'
            ELSE COALESCE(r.severidad, '(vacio)') END AS blockseverity,
       COUNT(*) AS reportes
FROM (
  SELECT loc.id, loc."index",
         MAX(loc."location.val.typeofdata"::VARCHAR) AS typeofdata,
         MAX(CASE WHEN ba.id IS NOT NULL THEN 1 ELSE 0 END) AS con_cuenta,
         MAX(NULLIF(TRIM(ba."bestaccounts.val.blockseverity"), '')) AS severidad
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  LEFT JOIN ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
    ON ba.id = x."bestaccounts"
   AND ba."index" IS NOT NULL
   AND NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"), '') = NULLIF(TRIM(loc."location.val.businesslinecode"), '')
   AND NULLIF(TRIM(ba."bestaccounts.val.accounttype"), '')      = NULLIF(TRIM(loc."location.val.accounttype"), '')
   AND NULLIF(TRIM(ba."bestaccounts.val.accountnumber"), '')    = NULLIF(TRIM(loc."location.val.accountnumber"), '')
   AND ba."bestaccounts.val.personidtype"                       = loc."location.val.personidtype"
   AND NULLIF(TRIM(ba."bestaccounts.val.personidnumber"), '')   = NULLIF(TRIM(loc."location.val.personidnumber"), '')
  GROUP BY 1, 2
) r
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- ============================================================
-- C32 (2026-10-20): los catalogos oficiales en Redshift. Confluence
-- ("19. BusinessIdStatus", CCBR 251263885) dice que viven en
-- catalogs_collibra.catalogs_output. Ese esquema NO aparece en el volcado
-- de svv_all_tables de DEV: la primera consulta dice si el cluster lo ve.
-- Son catalogos, sin datos personales.
-- ============================================================
SELECT database_name, schema_name, table_name
FROM svv_all_tables
WHERE schema_name ILIKE '%collibra%' OR table_name ILIKE '%catalogs_output%';

SELECT *
FROM catalogs_collibra.catalogs_output
WHERE code IN ('124_REGISTRADURIA_STATUS_OF_PERSON_HO',
               '180_EXPERIAN_ECONOMIC_SECTOR_BY_CUENTA_NH',
               '180_EXPERIAN_ECONOMIC_SECTOR_PER_ACCOUNT_NH',
               '28_SUBSCRIBER_BLOCKING_REASON_TYPES_NH',
               '27_SUBSCRIBER_BLOCK_TYPE_NH',
               '170_EXPERIAN_OFFICIAL_TABLE_OF_INFORMATION_SOURCES_NH',
               '93_GENDER_HO')
ORDER BY code, "code/text";

-- ============================================================
-- C32b (2026-10-21): catalogs_collibra.catalogs_output EXISTE en dba_batch
-- pero la C32 no devolvio filas con esos siete codigos. Antes de pedir nada:
-- cuantas filas tiene, como se llaman de verdad los codigos, y si la copia
-- local bdm_datos.collibra_catalogs_output trae lo mismo. Son catalogos.
-- Correr en dba_batch_DEV.
-- ============================================================
SELECT 'catalogs_collibra.catalogs_output' AS tabla, COUNT(*) AS filas, COUNT(DISTINCT code) AS catalogos
  FROM catalogs_collibra.catalogs_output
UNION ALL
SELECT 'bdm_datos.collibra_catalogs_output', COUNT(*), COUNT(DISTINCT code)
  FROM bdm_datos.collibra_catalogs_output;

SELECT code, COUNT(*) AS filas
FROM catalogs_collibra.catalogs_output
WHERE code ILIKE '%GENDER%' OR code ILIKE '%REGISTRADURIA%' OR code ILIKE '%ECONOMIC_SECTOR%'
   OR code ILIKE '%BLOCK%'  OR code ILIKE '%INFORMATION_SOURCES%' OR code ILIKE '%DEBTOR%'
   OR code ILIKE '%CONTACT%' OR code ILIKE '%THIRD_PARTY%'
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- C33 (2026-10-21): LA LLAVE DE CUENTA CASA? C31 dio que solo 278 de los
-- 6.850 reportes de suscriptor (typeofdata 1 y 2) casan con una cuenta. Antes
-- de dar por bueno el bloqueo de cuenta hay que saber si es porque la persona
-- no tiene cuentas en EDF o porque la llave no casa (ceros a la izquierda,
-- otro formato). Por reporte: tiene cuentas la persona, casa la llave
-- completa, casa solo el numero de cuenta, casa sin ceros a la izquierda.
-- Solo conteos.
-- ============================================================
SELECT r.typeofdata, r.persona_con_cuentas, r.casa_llave, r.casa_numero, r.casa_sin_ceros,
       COUNT(*) AS reportes
FROM (
  SELECT loc.id, loc."index",
         MAX(loc."location.val.typeofdata"::VARCHAR) AS typeofdata,
         MAX(CASE WHEN ba.id IS NOT NULL THEN 1 ELSE 0 END) AS persona_con_cuentas,
         MAX(CASE WHEN NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"), '') = NULLIF(TRIM(loc."location.val.businesslinecode"), '')
                   AND NULLIF(TRIM(ba."bestaccounts.val.accounttype"), '')      = NULLIF(TRIM(loc."location.val.accounttype"), '')
                   AND NULLIF(TRIM(ba."bestaccounts.val.accountnumber"), '')    = NULLIF(TRIM(loc."location.val.accountnumber"), '')
                   AND ba."bestaccounts.val.personidtype"                       = loc."location.val.personidtype"
                   AND NULLIF(TRIM(ba."bestaccounts.val.personidnumber"), '')   = NULLIF(TRIM(loc."location.val.personidnumber"), '')
                  THEN 1 ELSE 0 END) AS casa_llave,
         MAX(CASE WHEN NULLIF(TRIM(ba."bestaccounts.val.accountnumber"), '') = NULLIF(TRIM(loc."location.val.accountnumber"), '')
                  THEN 1 ELSE 0 END) AS casa_numero,
         MAX(CASE WHEN NULLIF(LTRIM(TRIM(ba."bestaccounts.val.accountnumber"), '0'), '') = NULLIF(LTRIM(TRIM(loc."location.val.accountnumber"), '0'), '')
                   AND NULLIF(LTRIM(TRIM(ba."bestaccounts.val.accounttype"), '0'), '')   = NULLIF(LTRIM(TRIM(loc."location.val.accounttype"), '0'), '')
                  THEN 1 ELSE 0 END) AS casa_sin_ceros
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  LEFT JOIN ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
    ON ba.id = x."bestaccounts"
   AND ba."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2)
  GROUP BY 1, 2
) r
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 6 DESC;

-- ============================================================
-- C32c (2026-10-21): CONTENIDO de los catalogos que cierran pedidos. C32b
-- encontro los 321 catalogos (70.899 filas, la copia de bdm_datos es igual).
-- La C32 devolvio cero con un IN exacto sobre codigos que SI existen: se
-- compara con TRIM por si el codigo trae espacios o fin de linea. Quedan
-- fuera 152 (consulados, 21.430 filas) y 209 (ciudades, 1.173). Son
-- catalogos, sin datos personales: exportar a CSV. Correr en dba_batch_DEV.
--   124            estado del documento (D-EDF-13)
--   180, 308, 219  sector economico (D-ORD-15)
--   11, 27, 28, 236 bloqueo de suscriptor y de cuenta (D-EDF-01)
--   198            fuentes de terceros, excepcion del filtro de getXPM
--   170            typeofdata -> fuente (D-NOV-03)
--   173, 320       tipos de contacto (D-EDF-06, el 12)
--   15, 16, 17     tipo de deudor (Fase 2)
--   93             genero
-- ============================================================
SELECT *
FROM catalogs_collibra.catalogs_output
WHERE TRIM(code) IN ('124_REGISTRADURIA_STATUS_OF_PERSON_HO',
                     '180_EXPERIAN_ECONOMIC_SECTOR_PER_ACCOUNT_NH',
                     '308_EXPERIAN_ECONOMIC_SECTOR_BY_CUENTA_NH',
                     '219_ECONOMIC_SECTOR_HO',
                     '11_SUBSCRIBER_BLOCK_TYPE_TO_REASON_MAPPING_NH',
                     '27_SUBSCRIBER_BLOCK_TYPE_NH',
                     '28_SUBSCRIBER_BLOCKING_REASON_TYPES_NH',
                     '236_SUBSCRIBER_BLOCK_REASON_NH',
                     '198_BUSINESS_LINE_CODE_THIRD_PARTY_SOURCES_NH',
                     '170_EXPERIAN_OFFICIAL_TABLE_OF_INFORMATION_SOURCES_NH',
                     '173_EXPERIAN_CONTACT_TYPE_NH',
                     '320_CATALOG_OF_CONTACTASREPORTED_LOCATION',
                     '15_SUBSCRIBER_TYPE_OF_DEBTOR_CREDIT_NH',
                     '16_SUBSCRIBER_TYPE_OF_DEBTOR_CREDITCARD_NH',
                     '17_SUBSCRIBER_TYPE_OF_DEBTOR_OVERDRAFT_NH',
                     '93_GENDER_HO')
ORDER BY code, "code/text";
