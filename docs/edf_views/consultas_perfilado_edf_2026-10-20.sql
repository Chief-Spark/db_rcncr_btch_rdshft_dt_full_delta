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
