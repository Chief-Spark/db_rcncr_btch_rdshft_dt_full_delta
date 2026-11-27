-- ============================================================
-- COMPROBAR QUE LAS 94 COLUMNAS DEL DATASHARE EDF EXISTEN DE VERDAD
--
-- Se lanza en DBeaver contra el cluster de Reconocer.
--
-- DOS COSAS ANTES DE EJECUTAR, Y LAS DOS CUESTAN UN RATO SI NO SE SABEN:
--
--   1. DBeaver abre la conexion en la base 'dba'. SVV_REDSHIFT_COLUMNS es
--      una vista de catalogo CRUZADA entre bases, asi que desde 'dba'
--      funciona igual; pero si se cambia a SVV_ALL_COLUMNS o a pg_table_def
--      hay que estar en la base del pipeline (dba_rncr_batch).
--
--   2. NO se usa VALUES como constructor de tabla: Redshift no lo tiene
--      (42601: syntax error at or near "VALUES"). Por eso la lista va como
--      SELECT ... UNION ALL SELECT ..., con el CAST explicito en la PRIMERA
--      rama, que es la que fija el tipo del nodo.
--
-- Las columnas llevan la ruta completa de la estructura anidada
-- ("location.val.contactinformations.val.contacttype"): el catalogo las
-- guarda asi, con el punto dentro del nombre.
-- ============================================================

-- ------------------------------------------------------------
-- 1) DETALLE: una fila por columna esperada, con OK o FALTA
-- ------------------------------------------------------------
WITH esperado AS (
      SELECT CAST('xpm' AS VARCHAR(100)) AS relacion, CAST('bestaccounts' AS VARCHAR(300)) AS columna
UNION ALL SELECT 'xpm', 'bestidentifications'
UNION ALL SELECT 'xpm', 'bestname.firstlastname'
UNION ALL SELECT 'xpm', 'bestname.firstname'
UNION ALL SELECT 'xpm', 'bestname.fullname'
UNION ALL SELECT 'xpm', 'bestname.secondlastname'
UNION ALL SELECT 'xpm', 'bestname.secondname'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.agerange'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.citizentaxregistrationindicator'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.gender'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.mainisiccodeforproduct'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.productmainisicdescription'
UNION ALL SELECT 'xpm', 'chamberofcommerce'
UNION ALL SELECT 'xpm', 'counterparties'
UNION ALL SELECT 'xpm', 'location'
UNION ALL SELECT 'xpm', 'personalinformation'
UNION ALL SELECT 'xpm', 'pin'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.accountnumber'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.accounttype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.blockseverity'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.businesslinecode'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.cutoffdate'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.frequentbehaviour'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.guaranteetype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.personidnumber'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.personidtype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.totalnumberofinstallments'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.typeofdebtor'
UNION ALL SELECT 'xpm_bestaccounts', 'id'
UNION ALL SELECT 'xpm_bestaccounts', 'index'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.behaviourdate'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.debtbalance'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.paidinstallments'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.valuemonthlypayment'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'id'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'index'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.businessidstatus'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuedate'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuingcityname'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuingstatename'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.officialsourcevalidationstatus'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.personidnumber'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.personidtype'
UNION ALL SELECT 'xpm_bestidentifications', 'id'
UNION ALL SELECT 'xpm_bestidentifications', 'index'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.mainisiccodeforproduct'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode1'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode2'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode3'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode4'
UNION ALL SELECT 'xpm_chamberofcommerce', 'id'
UNION ALL SELECT 'xpm_chamberofcommerce', 'index'
UNION ALL SELECT 'xpm_counterparties', 'counterparties.val.counterpartyidnumber'
UNION ALL SELECT 'xpm_counterparties', 'id'
UNION ALL SELECT 'xpm_counterparties', 'index'
UNION ALL SELECT 'xpm_location', 'id'
UNION ALL SELECT 'xpm_location', 'location.val.accountnumber'
UNION ALL SELECT 'xpm_location', 'location.val.accounttype'
UNION ALL SELECT 'xpm_location', 'location.val.blockreason'
UNION ALL SELECT 'xpm_location', 'location.val.businesslinecode'
UNION ALL SELECT 'xpm_location', 'location.val.contactinformations'
UNION ALL SELECT 'xpm_location', 'location.val.counterpartyidnumber'
UNION ALL SELECT 'xpm_location', 'location.val.cutoffdate'
UNION ALL SELECT 'xpm_location', 'location.val.personidnumber'
UNION ALL SELECT 'xpm_location', 'location.val.personidtype'
UNION ALL SELECT 'xpm_location', 'location.val.typeofdata'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'id'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'index'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.citycode'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.cityname'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasreported'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasreportedstandardized'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasstandardizedscore'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contacteventlastupdated'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactfirsteventdate'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contacttype'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedcomplemento'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizeddanecode'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizeddepartment'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedmunicipality'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizednumeropuerta'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtextoubicacion'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtipo'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtipoviaprincipal'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedviageneradora'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedviaprincipal'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.statename'
UNION ALL SELECT 'xpm_personalinformation', 'id'
UNION ALL SELECT 'xpm_personalinformation', 'index'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.mainisiccode'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode1'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode2'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode3'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode4'
)
SELECT
    e.relacion,
    e.columna,
    CASE WHEN c.column_name IS NULL THEN 'FALTA' ELSE 'OK' END AS estado,
    c.data_type,
    c.character_maximum_length AS ancho
FROM esperado e
LEFT JOIN svv_redshift_columns c
       ON c.database_name = 'ds_dba_rncr_batch'
      AND LOWER(c.schema_name) = 'edf_views'
      AND LOWER(c.table_name)  = e.relacion
      AND LOWER(c.column_name) = e.columna
ORDER BY estado, e.relacion, e.columna;


-- ------------------------------------------------------------
-- 2) TITULAR: el resumen que de verdad se mira. Si 'faltan' no es 0,
--    la consulta 1 dice cuales son.
-- ------------------------------------------------------------
WITH esperado AS (
      SELECT CAST('xpm' AS VARCHAR(100)) AS relacion, CAST('bestaccounts' AS VARCHAR(300)) AS columna
UNION ALL SELECT 'xpm', 'bestidentifications'
UNION ALL SELECT 'xpm', 'bestname.firstlastname'
UNION ALL SELECT 'xpm', 'bestname.firstname'
UNION ALL SELECT 'xpm', 'bestname.fullname'
UNION ALL SELECT 'xpm', 'bestname.secondlastname'
UNION ALL SELECT 'xpm', 'bestname.secondname'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.agerange'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.citizentaxregistrationindicator'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.gender'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.mainisiccodeforproduct'
UNION ALL SELECT 'xpm', 'bestpersonalinformation.productmainisicdescription'
UNION ALL SELECT 'xpm', 'chamberofcommerce'
UNION ALL SELECT 'xpm', 'counterparties'
UNION ALL SELECT 'xpm', 'location'
UNION ALL SELECT 'xpm', 'personalinformation'
UNION ALL SELECT 'xpm', 'pin'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.accountnumber'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.accounttype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.blockseverity'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.businesslinecode'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.cutoffdate'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.frequentbehaviour'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.guaranteetype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.personidnumber'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.personidtype'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.totalnumberofinstallments'
UNION ALL SELECT 'xpm_bestaccounts', 'bestaccounts.val.typeofdebtor'
UNION ALL SELECT 'xpm_bestaccounts', 'id'
UNION ALL SELECT 'xpm_bestaccounts', 'index'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.behaviourdate'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.debtbalance'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.paidinstallments'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'bestaccounts.val.frequentbehaviour.val.valuemonthlypayment'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'id'
UNION ALL SELECT 'xpm_bestaccounts_val_frequentbehaviour', 'index'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.businessidstatus'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuedate'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuingcityname'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.issuingstatename'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.officialsourcevalidationstatus'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.personidnumber'
UNION ALL SELECT 'xpm_bestidentifications', 'bestidentifications.val.personidtype'
UNION ALL SELECT 'xpm_bestidentifications', 'id'
UNION ALL SELECT 'xpm_bestidentifications', 'index'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.mainisiccodeforproduct'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode1'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode2'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode3'
UNION ALL SELECT 'xpm_chamberofcommerce', 'chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode4'
UNION ALL SELECT 'xpm_chamberofcommerce', 'id'
UNION ALL SELECT 'xpm_chamberofcommerce', 'index'
UNION ALL SELECT 'xpm_counterparties', 'counterparties.val.counterpartyidnumber'
UNION ALL SELECT 'xpm_counterparties', 'id'
UNION ALL SELECT 'xpm_counterparties', 'index'
UNION ALL SELECT 'xpm_location', 'id'
UNION ALL SELECT 'xpm_location', 'location.val.accountnumber'
UNION ALL SELECT 'xpm_location', 'location.val.accounttype'
UNION ALL SELECT 'xpm_location', 'location.val.blockreason'
UNION ALL SELECT 'xpm_location', 'location.val.businesslinecode'
UNION ALL SELECT 'xpm_location', 'location.val.contactinformations'
UNION ALL SELECT 'xpm_location', 'location.val.counterpartyidnumber'
UNION ALL SELECT 'xpm_location', 'location.val.cutoffdate'
UNION ALL SELECT 'xpm_location', 'location.val.personidnumber'
UNION ALL SELECT 'xpm_location', 'location.val.personidtype'
UNION ALL SELECT 'xpm_location', 'location.val.typeofdata'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'id'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'index'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.citycode'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.cityname'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasreported'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasreportedstandardized'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactasstandardizedscore'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contacteventlastupdated'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contactfirsteventdate'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.contacttype'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedcomplemento'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizeddanecode'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizeddepartment'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedmunicipality'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizednumeropuerta'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtextoubicacion'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtipo'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedtipoviaprincipal'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedviageneradora'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.standardizedviaprincipal'
UNION ALL SELECT 'xpm_location_val_contactinformations', 'location.val.contactinformations.val.statename'
UNION ALL SELECT 'xpm_personalinformation', 'id'
UNION ALL SELECT 'xpm_personalinformation', 'index'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.mainisiccode'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode1'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode2'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode3'
UNION ALL SELECT 'xpm_personalinformation', 'personalinformation.val.secondaryisiccode.secondaryisiccode4'
)
SELECT
    e.relacion,
    COUNT(*)                                          AS esperadas,
    SUM(CASE WHEN c.column_name IS NOT NULL THEN 1 ELSE 0 END) AS existen,
    SUM(CASE WHEN c.column_name IS NULL     THEN 1 ELSE 0 END) AS faltan
FROM esperado e
LEFT JOIN svv_redshift_columns c
       ON c.database_name = 'ds_dba_rncr_batch'
      AND LOWER(c.schema_name) = 'edf_views'
      AND LOWER(c.table_name)  = e.relacion
      AND LOWER(c.column_name) = e.columna
GROUP BY e.relacion
ORDER BY faltan DESC, e.relacion;


-- ------------------------------------------------------------
-- 3) LAS NUEVE RELACIONES RESPONDEN? Una relacion que no existe sale
--    con 0 columnas, y eso es otro fallo que el 1) mostraria como 94
--    FALTA de golpe sin decir por que.
-- ------------------------------------------------------------
SELECT table_name, COUNT(*) AS columnas_en_el_catalogo
FROM svv_redshift_columns
WHERE database_name = 'ds_dba_rncr_batch'
  AND LOWER(schema_name) = 'edf_views'
  AND LOWER(table_name) IN ('xpm','xpm_bestaccounts',
                            'xpm_bestaccounts_val_frequentbehaviour',
                            'xpm_bestidentifications','xpm_chamberofcommerce',
                            'xpm_counterparties','xpm_location',
                            'xpm_location_val_contactinformations',
                            'xpm_personalinformation')
GROUP BY table_name
ORDER BY table_name;


-- ------------------------------------------------------------
-- 4) EL CATALOGO NO PRUEBA QUE LA COLUMNA SE PUEDA LEER, Y ESA ES LA
--    DIFERENCIA QUE IMPORTA. Una relacion enmascarada figura en el
--    catalogo y revienta al EJECUTARLA:
--      XX000: cross-cluster query of the masked relation "<rel>" is not supported
--    Estas nueve lecturas lo cierran. Van de a una: el motor para en el
--    primer error, de modo que una sonda que se detiene no mide el universo.
-- ------------------------------------------------------------
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts_val_frequentbehaviour;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_bestidentifications;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_counterparties;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_location;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations;
SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_personalinformation;
