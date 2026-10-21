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
-- C32c (2026-10-21, v2): CONTENIDO de los catalogos que cierran pedidos.
-- La v1 leia catalogs_collibra.catalogs_output, que es externa (Spectrum), con
-- TRIM(code) IN (...): seguia corriendo a los 4 minutos. Esta lee la copia
-- LOCAL bdm_datos.collibra_catalogs_output, identica segun C32b (70.899 filas,
-- 321 catalogos), y compara con LIKE 'codigo%', que tolera espacios o un fin
-- de linea al final del codigo sin envolver la columna en una funcion. Son
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
FROM bdm_datos.collibra_catalogs_output
WHERE code LIKE '124_REGISTRADURIA_STATUS_OF_PERSON_HO%'
   OR code LIKE '180_EXPERIAN_ECONOMIC_SECTOR_PER_ACCOUNT_NH%'
   OR code LIKE '308_EXPERIAN_ECONOMIC_SECTOR_BY_CUENTA_NH%'
   OR code LIKE '219_ECONOMIC_SECTOR_HO%'
   OR code LIKE '11_SUBSCRIBER_BLOCK_TYPE_TO_REASON_MAPPING_NH%'
   OR code LIKE '27_SUBSCRIBER_BLOCK_TYPE_NH%'
   OR code LIKE '28_SUBSCRIBER_BLOCKING_REASON_TYPES_NH%'
   OR code LIKE '236_SUBSCRIBER_BLOCK_REASON_NH%'
   OR code LIKE '198_BUSINESS_LINE_CODE_THIRD_PARTY_SOURCES_NH%'
   OR code LIKE '170_EXPERIAN_OFFICIAL_TABLE_OF_INFORMATION_SOURCES_NH%'
   OR code LIKE '173_EXPERIAN_CONTACT_TYPE_NH%'
   OR code LIKE '320_CATALOG_OF_CONTACTASREPORTED_LOCATION%'
   OR code LIKE '15_SUBSCRIBER_TYPE_OF_DEBTOR_CREDIT_NH%'
   OR code LIKE '16_SUBSCRIBER_TYPE_OF_DEBTOR_CREDITCARD_NH%'
   OR code LIKE '17_SUBSCRIBER_TYPE_OF_DEBTOR_OVERDRAFT_NH%'
   OR code LIKE '93_GENDER_HO%'
ORDER BY code, "code/text";

-- ============================================================
-- C34 v2 (2026-10-21): QUE CODIGO HAY DETRAS DE LA SEVERIDAD 2.
-- Alpha junta en blockSeverity = 2 los indicadores 8 y 9, y el legado
-- los trata distinto (V_Razon_Bloqueo): 8 = reclamo sin solucion, NO se
-- muestra; 9 = cuenta sin validar ante la Registraduria, SI se muestra.
-- Si blockreason trae el 8 o el 9, la severidad 2 se parte sin preguntar
-- a Experian. Solo conteos, sin datos personales. Conexion de Reconocer.
--
-- v1 tardaba demasiado. La tabla tiene ~106.000 filas en DEV (7.759
-- cuentas reales, RESULTADOS 11), asi que el volumen no lo explica:
-- HIPOTESIS, estaba en cola detras de otra consulta (la C33 es un join
-- grande). v2 lee dos columnas crudas, sin TRIM ni NULLIF (el filtro baja
-- al escaneo) y descarta las cuentas activas antes de agrupar.
-- ============================================================
SELECT ba."bestaccounts.val.blockseverity" AS severidad,
       ba."bestaccounts.val.blockreason"   AS razon,
       COUNT(*)                            AS cuentas
FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
WHERE ba."bestaccounts.val.blockseverity" <> '0'
GROUP BY 1, 2
ORDER BY 1, 2;

-- C34-diag: si v2 tambien se demora, ver si esta EN COLA o EJECUTANDO.
-- state = 'QueuedWaiting' -> esta esperando turno; cancelar la C33 si
-- sigue viva (SELECT pg_cancel_backend(<pid>);) y relanzar.
SELECT w.query, w.state,
       w.queue_time / 1000000 AS seg_en_cola,
       w.exec_time  / 1000000 AS seg_ejecutando,
       i.pid,
       LEFT(i.text, 60)       AS inicio_consulta
FROM stv_wlm_query_state w
LEFT JOIN stv_inflight i ON i.query = w.query
ORDER BY w.wlm_start_time;

-- ============================================================
-- C33 v2 (2026-10-21): LA LLAVE DE CUENTA CASA? Misma pregunta que C33,
-- reescrita para que corra rapido: en vez de cruzar cada reporte con todas
-- las cuentas de la persona y agrupar, une por igualdad contra listas
-- DISTINCT (sin fan-out). Las llaves se normalizan igual que la vista
-- bdm_tempo.v_xpm_cuenta_bloqueada (TRIM + NULLIF sobre ::VARCHAR), que es
-- lo que importa: si casa aqui, casa en la vista. Solo conteos.
--   persona_con_cuentas = 0 en casi todo  -> DEV trae pocas cuentas
--   casa_numero o casa_sin_ceros = 1 con casa_llave = 0 -> formato de llave
-- Conexion de Reconocer (datashare).
-- ============================================================
WITH ba AS (
  SELECT DISTINCT
         ba.id                                                              AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '')  AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')       AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')     AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')      AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')    AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), rep AS (
  SELECT x."bestaccounts"                                                    AS ba_id,
         loc."location.val.typeofdata"::VARCHAR                              AS typeofdata,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')      AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')           AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')         AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')          AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')        AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2)
)
SELECT r.typeofdata,
       CASE WHEN p.ba_id IS NOT NULL THEN 1 ELSE 0 END AS persona_con_cuentas,
       CASE WHEN k.ba_id IS NOT NULL THEN 1 ELSE 0 END AS casa_llave,
       CASE WHEN n.ba_id IS NOT NULL THEN 1 ELSE 0 END AS casa_numero,
       CASE WHEN z.ba_id IS NOT NULL THEN 1 ELSE 0 END AS casa_sin_ceros,
       COUNT(*)                                        AS reportes
FROM rep r
LEFT JOIN (SELECT DISTINCT ba_id FROM ba) p
  ON p.ba_id = r.ba_id
LEFT JOIN (SELECT DISTINCT ba_id, linea, tipo, num, tipo_doc, num_doc FROM ba) k
  ON k.ba_id = r.ba_id AND k.linea = r.linea AND k.tipo = r.tipo
 AND k.num = r.num AND k.tipo_doc = r.tipo_doc AND k.num_doc = r.num_doc
LEFT JOIN (SELECT DISTINCT ba_id, num FROM ba) n
  ON n.ba_id = r.ba_id AND n.num = r.num
LEFT JOIN (SELECT DISTINCT ba_id, LTRIM(num, '0') AS num0, LTRIM(tipo, '0') AS tipo0 FROM ba) z
  ON z.ba_id = r.ba_id AND z.num0 = LTRIM(r.num, '0') AND z.tipo0 = LTRIM(r.tipo, '0')
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 6 DESC;

-- ============================================================
-- C35 (2026-10-21): LA LISTA DE LOS 321 CATALOGOS DE COLLIBRA. Solo el
-- nombre de cada catalogo y cuantas filas trae, sin contenido. Sirve para
-- cruzarla con lo que todavia pedimos a Experian (CIIU, tipo de
-- identificacion, zona, tipo de via, indicativo, tipo de correo...): lo que
-- este aqui se lee sin preguntar a nadie. Correr en dba_batch_DEV.
-- ============================================================
SELECT REGEXP_REPLACE(code, '[[:space:]]+$', '') AS catalogo,
       COUNT(*)                                  AS filas
FROM bdm_datos.collibra_catalogs_output
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- C33b (2026-10-21): QUE CAMPO DE LA LLAVE NO CASA. C33 v2 dio que el
-- numero de cuenta casa en 5.471 de los 6.850 reportes de suscriptor, pero la
-- llave completa de cinco campos solo en 278. Para los pares que casan por
-- numero, compara campo por campo: igual, igual sin ceros a la izquierda, o
-- distinto. Mas el largo de linea y tipo de cuenta en cada lado, que son
-- codigos de entidad y de producto, no datos personales. Del documento solo
-- se compara, nunca se muestra. Conexion de Reconocer.
-- ============================================================
WITH ba AS (
  SELECT DISTINCT
         ba.id                                                              AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '')  AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')       AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')     AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')      AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')    AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), rep AS (
  SELECT x."bestaccounts"                                                    AS ba_id,
         loc."location.val.typeofdata"::VARCHAR                              AS typeofdata,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')      AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')           AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')         AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')          AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')        AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2)
)
SELECT r.typeofdata,
       CASE WHEN r.linea = b.linea THEN 'igual'
            WHEN LTRIM(r.linea, '0') = LTRIM(b.linea, '0') THEN 'ceros'
            WHEN r.linea IS NULL OR b.linea IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS linea,
       CASE WHEN r.tipo = b.tipo THEN 'igual'
            WHEN LTRIM(r.tipo, '0') = LTRIM(b.tipo, '0') THEN 'ceros'
            WHEN r.tipo IS NULL OR b.tipo IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo,
       CASE WHEN r.tipo_doc = b.tipo_doc THEN 'igual'
            WHEN LTRIM(r.tipo_doc, '0') = LTRIM(b.tipo_doc, '0') THEN 'ceros'
            WHEN r.tipo_doc IS NULL OR b.tipo_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo_doc,
       CASE WHEN r.num_doc = b.num_doc THEN 'igual'
            WHEN LTRIM(r.num_doc, '0') = LTRIM(b.num_doc, '0') THEN 'ceros'
            WHEN r.num_doc IS NULL OR b.num_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS num_doc,
       LEN(r.linea) AS len_linea_rep, LEN(b.linea) AS len_linea_cta,
       LEN(r.tipo)  AS len_tipo_rep,  LEN(b.tipo)  AS len_tipo_cta,
       COUNT(*)                                                AS pares
FROM rep r
JOIN ba b
  ON b.ba_id = r.ba_id
 AND b.num   = r.num
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1, 10 DESC;

-- ============================================================
-- C36 (2026-10-21): ES EL CONTENEDOR bestaccounts DE UNA SOLA PERSONA?
-- C33b dejo una hipotesis sin verificar: que el id de xpm_bestaccounts lo
-- comparten varias personas, igual que ya esta medido en
-- xpm_location_val_contactinformations (568.657 filas / 142.067 ids). Si es
-- asi, unir por numero de cuenta dentro del contenedor empareja la cuenta de
-- una persona con el reporte de otra, y eso explica que fallen a la vez el
-- businesslinecode y el personidnumber en el 95 % de los pares.
-- La segunda consulta es la que decide. Solo conteos. Conexion de Reconocer.
-- ============================================================
SELECT COUNT(*)                 AS filas,
       COUNT(DISTINCT id)       AS ids_distintos
FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts
WHERE "index" IS NOT NULL;

SELECT z.personas_por_contenedor,
       COUNT(*) AS contenedores
FROM ( SELECT x."bestaccounts"      AS ba_id,
              COUNT(DISTINCT x.pin) AS personas_por_contenedor
       FROM ds_dba_rncr_batch.edf_views.xpm x
       WHERE x."bestaccounts" IS NOT NULL
       GROUP BY 1 ) z
GROUP BY 1
ORDER BY 1;
-- ============================================================
-- C38 (2026-10-21): LA LLAVE DE CUENTA EN QA. Las mismas tres medidas que
-- C31/C33b/C36 dieron en DEV, sobre el ambiente que SI tiene volumen: QA
-- trae 118.120 reportes de suscriptor contra los 6.983 de DEV (RESULTADOS
-- seccion 15), de modo que el 4 % de DEV puede ser escasez del ambiente y no
-- un defecto de la llave. Esta consulta lo decide.
--
-- CORRER EN LA CONEXION DE RECONOCER DE **QA**.
-- Si el datashare se llama distinto en QA, cambiar el prefijo
-- ds_dba_rncr_batch.edf_views en los cuatro sitios donde aparece.
--
-- Solo devuelve CONTEOS. Ningun dato personal sale en el resultado.
-- ============================================================

-- ------------------------------------------------------------
-- C38.1  COBERTURA POR NIVEL DE LLAVE
-- En DEV: 6.850 reportes, 81 % casan por contenedor + numero, 4 % por los
-- seis campos. Lo que se compara es la PROPORCION, no el volumen.
-- ------------------------------------------------------------
WITH rep AS (
  SELECT loc.id                                                          AS loc_id,
         loc."index"                                                     AS loc_ix,
         x."bestaccounts"                                                AS ba_id,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')  AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')       AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')     AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')      AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')    AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2, 3, 17)
), ba AS (
  SELECT DISTINCT
         ba.id                                                             AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '') AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')      AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')    AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')     AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')   AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), m AS (
  SELECT r.loc_id,
         r.loc_ix,
         MAX(CASE WHEN b.num IS NOT NULL THEN 1 ELSE 0 END) AS casa_num,
         MAX(CASE WHEN b.linea    = r.linea
                   AND b.tipo     = r.tipo
                   AND b.tipo_doc = r.tipo_doc
                   AND b.num_doc  = r.num_doc THEN 1 ELSE 0 END) AS casa_todo
  FROM rep r
  LEFT JOIN ba b
    ON b.ba_id = r.ba_id
   AND b.num   = r.num
  GROUP BY 1, 2
)
SELECT COUNT(*)        AS reportes_suscriptor,
       SUM(casa_num)   AS casan_contenedor_mas_numero,
       SUM(casa_todo)  AS casan_los_seis_campos
FROM m;

-- ------------------------------------------------------------
-- C38.2  QUE CAMPO ROMPE (el C33b de DEV, igual)
-- En DEV: 'ceros' y 'nulo' no aparecieron ni una vez, y fallaban a la vez
-- businesslinecode y personidnumber en el 95 %.
-- ------------------------------------------------------------
WITH ba AS (
  SELECT DISTINCT
         ba.id                                                             AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '') AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')      AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')    AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')     AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')   AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), rep AS (
  SELECT x."bestaccounts"                                                 AS ba_id,
         loc."location.val.typeofdata"::VARCHAR                           AS typeofdata,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')   AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')        AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')      AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')       AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')     AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm x
  JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2)
)
SELECT r.typeofdata,
       CASE WHEN r.linea = b.linea THEN 'igual'
            WHEN LTRIM(r.linea, '0') = LTRIM(b.linea, '0') THEN 'ceros'
            WHEN r.linea IS NULL OR b.linea IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS linea,
       CASE WHEN r.tipo = b.tipo THEN 'igual'
            WHEN LTRIM(r.tipo, '0') = LTRIM(b.tipo, '0') THEN 'ceros'
            WHEN r.tipo IS NULL OR b.tipo IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo,
       CASE WHEN r.tipo_doc = b.tipo_doc THEN 'igual'
            WHEN LTRIM(r.tipo_doc, '0') = LTRIM(b.tipo_doc, '0') THEN 'ceros'
            WHEN r.tipo_doc IS NULL OR b.tipo_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo_doc,
       CASE WHEN r.num_doc = b.num_doc THEN 'igual'
            WHEN LTRIM(r.num_doc, '0') = LTRIM(b.num_doc, '0') THEN 'ceros'
            WHEN r.num_doc IS NULL OR b.num_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS num_doc,
       LEN(r.linea) AS len_linea_rep, LEN(b.linea) AS len_linea_cta,
       LEN(r.tipo)  AS len_tipo_rep,  LEN(b.tipo)  AS len_tipo_cta,
       COUNT(*)                                                AS pares
FROM rep r
JOIN ba b
  ON b.ba_id = r.ba_id
 AND b.num   = r.num
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1, 10 DESC;

-- ------------------------------------------------------------
-- C38.3  ES EL CONTENEDOR DE UNA SOLA PERSONA? (el C36, en QA)
-- La segunda es la que decide: si hay contenedores con mas de una persona,
-- la llave que falta es de Experian y hay que pedirsela.
-- ------------------------------------------------------------
SELECT COUNT(*)           AS filas,
       COUNT(DISTINCT id) AS ids_distintos
FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts
WHERE "index" IS NOT NULL;

SELECT z.personas_por_contenedor,
       COUNT(*) AS contenedores
FROM ( SELECT x."bestaccounts"      AS ba_id,
              COUNT(DISTINCT x.pin) AS personas_por_contenedor
       FROM ds_dba_rncr_batch.edf_views.xpm x
       WHERE x."bestaccounts" IS NOT NULL
       GROUP BY 1 ) z
GROUP BY 1
ORDER BY 1;
-- ============================================================
-- C39 (2026-10-21): C38 SOBRE EL **PRODUCTOR** DE QA, SIN DATASHARE.
--
-- Mismos objetos y mismas medidas que C38; lo unico que cambia es que no se
-- pasa por el datashare: en el productor las tablas viven en el esquema
-- edf_views de la propia base, con el mismo nombre y sin prefijo
-- (verificado en docs/edf_views/svv_all_tables_2026-10-20.csv: 35 TABLE
-- edf_views.xpm*; las vw_biz_* son otra capa y NO se usan aqui).
--
-- CORRER CONECTADO AL PRODUCTOR DE QA.
--
-- ANTES DE NADA, CORRER C39.0: la ultima corrida de C38 devolvio 6.983
-- reportes de suscriptor, que es EXACTAMENTE la cifra de DEV (QA tiene
-- 118.120, RESULTADOS seccion 15). O se corrio contra DEV, o la conexion
-- llamada QA sirve el dato de DEV. Sin eso, el resto no se puede leer.
--
-- Solo devuelven CONTEOS. Ningun dato personal sale en el resultado.
-- ============================================================

-- ------------------------------------------------------------
-- C39.0  EN QUE AMBIENTE ESTOY, Y CUANTO DATO HAY
-- Esperado en QA: 118.120 reportes de suscriptor. Si sale 6.983, es DEV.
-- ------------------------------------------------------------
SELECT CURRENT_DATABASE()                                        AS base,
       CURRENT_USER                                              AS usuario,
       (SELECT COUNT(*) FROM edf_views.xpm)                      AS personas,
       (SELECT COUNT(*) FROM edf_views.xpm_location
         WHERE "index" IS NOT NULL
           AND "location.val.typeofdata" IN (1, 2, 3, 17))       AS reportes_suscriptor;

-- ------------------------------------------------------------
-- C39.1  COBERTURA POR NIVEL DE LLAVE
-- En DEV: 6.850 reportes, 81 % casan por contenedor + numero, 4 % por los
-- seis campos. Lo que se compara es la PROPORCION, no el volumen.
-- ------------------------------------------------------------
WITH rep AS (
  SELECT loc.id                                                          AS loc_id,
         loc."index"                                                     AS loc_ix,
         x."bestaccounts"                                                AS ba_id,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')  AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')       AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')     AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')      AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')    AS num_doc
  FROM edf_views.xpm x
  JOIN edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2, 3, 17)
), ba AS (
  SELECT DISTINCT
         ba.id                                                             AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '') AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')      AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')    AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')     AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')   AS num_doc
  FROM edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), m AS (
  SELECT r.loc_id,
         r.loc_ix,
         MAX(CASE WHEN b.num IS NOT NULL THEN 1 ELSE 0 END) AS casa_num,
         MAX(CASE WHEN b.linea    = r.linea
                   AND b.tipo     = r.tipo
                   AND b.tipo_doc = r.tipo_doc
                   AND b.num_doc  = r.num_doc THEN 1 ELSE 0 END) AS casa_todo
  FROM rep r
  LEFT JOIN ba b
    ON b.ba_id = r.ba_id
   AND b.num   = r.num
  GROUP BY 1, 2
)
SELECT COUNT(*)        AS reportes_suscriptor,
       SUM(casa_num)   AS casan_contenedor_mas_numero,
       SUM(casa_todo)  AS casan_los_seis_campos
FROM m;

-- ------------------------------------------------------------
-- C39.2  QUE CAMPO ROMPE (el C33b de DEV, igual)
-- En DEV: 'ceros' y 'nulo' no aparecieron ni una vez, y fallaban a la vez
-- businesslinecode y personidnumber en el 95 %.
-- ------------------------------------------------------------
WITH ba AS (
  SELECT DISTINCT
         ba.id                                                             AS ba_id,
         NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '') AS linea,
         NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')      AS tipo,
         NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')    AS num,
         NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')     AS tipo_doc,
         NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')   AS num_doc
  FROM edf_views.xpm_bestaccounts ba
  WHERE ba."index" IS NOT NULL
), rep AS (
  SELECT x."bestaccounts"                                                 AS ba_id,
         loc."location.val.typeofdata"::VARCHAR                           AS typeofdata,
         NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')   AS linea,
         NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')        AS tipo,
         NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')      AS num,
         NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')       AS tipo_doc,
         NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')     AS num_doc
  FROM edf_views.xpm x
  JOIN edf_views.xpm_location loc
    ON loc.id = x."location"
   AND loc."index" IS NOT NULL
  WHERE loc."location.val.typeofdata" IN (1, 2)
)
SELECT r.typeofdata,
       CASE WHEN r.linea = b.linea THEN 'igual'
            WHEN LTRIM(r.linea, '0') = LTRIM(b.linea, '0') THEN 'ceros'
            WHEN r.linea IS NULL OR b.linea IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS linea,
       CASE WHEN r.tipo = b.tipo THEN 'igual'
            WHEN LTRIM(r.tipo, '0') = LTRIM(b.tipo, '0') THEN 'ceros'
            WHEN r.tipo IS NULL OR b.tipo IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo,
       CASE WHEN r.tipo_doc = b.tipo_doc THEN 'igual'
            WHEN LTRIM(r.tipo_doc, '0') = LTRIM(b.tipo_doc, '0') THEN 'ceros'
            WHEN r.tipo_doc IS NULL OR b.tipo_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS tipo_doc,
       CASE WHEN r.num_doc = b.num_doc THEN 'igual'
            WHEN LTRIM(r.num_doc, '0') = LTRIM(b.num_doc, '0') THEN 'ceros'
            WHEN r.num_doc IS NULL OR b.num_doc IS NULL THEN 'nulo'
            ELSE 'distinto' END                                AS num_doc,
       LEN(r.linea) AS len_linea_rep, LEN(b.linea) AS len_linea_cta,
       LEN(r.tipo)  AS len_tipo_rep,  LEN(b.tipo)  AS len_tipo_cta,
       COUNT(*)                                                AS pares
FROM rep r
JOIN ba b
  ON b.ba_id = r.ba_id
 AND b.num   = r.num
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1, 10 DESC;

-- ------------------------------------------------------------
-- C39.3  ES EL CONTENEDOR DE UNA SOLA PERSONA? (el C36, en QA)
-- La segunda es la que decide: si hay contenedores con mas de una persona,
-- la llave que falta es de Experian y hay que pedirsela.
-- ------------------------------------------------------------
SELECT COUNT(*)           AS filas,
       COUNT(DISTINCT id) AS ids_distintos
FROM edf_views.xpm_bestaccounts
WHERE "index" IS NOT NULL;

SELECT z.personas_por_contenedor,
       COUNT(*) AS contenedores
FROM ( SELECT x."bestaccounts"      AS ba_id,
              COUNT(DISTINCT x.pin) AS personas_por_contenedor
       FROM edf_views.xpm x
       WHERE x."bestaccounts" IS NOT NULL
       GROUP BY 1 ) z
GROUP BY 1
ORDER BY 1;
