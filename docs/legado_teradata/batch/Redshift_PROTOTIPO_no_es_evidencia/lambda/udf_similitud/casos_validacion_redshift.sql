/* ============================================================================
 * casos_validacion_redshift.sql
 * Ejecutar en REDSHIFT despues de desplegar la Lambda y ddl/08_funciones_udf.sql.
 * Mismos casos que casos_validacion_teradata.sql: toda fila debe tener
 * OK = 'S'. Si en Teradata algun caso dio otro valor, ese valor manda.
 * ============================================================================ */

SELECT caso, obtenido, esperado,
       CASE WHEN obtenido = esperado OR (obtenido IS NULL AND esperado IS NULL) THEN 'S' ELSE 'N' END AS ok
FROM (
          SELECT 'TEL-1 iguales' AS caso, rec_vista.f_bach_similitud_tel('2826373','2826373') AS obtenido, 100 AS esperado
UNION ALL SELECT 'TEL-2 un digito',            rec_vista.f_bach_similitud_tel('2822994','2822992'), 86
UNION ALL SELECT 'TEL-3 transposicion',        rec_vista.f_bach_similitud_tel('3434620','3436420'), 86
UNION ALL SELECT 'TEL-4',                      rec_vista.f_bach_similitud_tel('3432064','3436420'), 43
UNION ALL SELECT 'TEL-5 invertido',            rec_vista.f_bach_similitud_tel('7654321','1234567'), 14
UNION ALL SELECT 'TEL-6 OSA vs Damerau',       rec_vista.f_bach_similitud_tel('ABC','CA'), 0
UNION ALL SELECT 'TEL-7 negativo',             rec_vista.f_bach_similitud_tel('123','12345678'), -66
UNION ALL SELECT 'TEL-8 truncamiento',         rec_vista.f_bach_similitud_tel('123456789012345678901234','12345678901234567890XXXX'), 100
UNION ALL SELECT 'TEL-9 insumo vacio',         rec_vista.f_bach_similitud_tel('','123'), -2147483648
UNION ALL SELECT 'TEL-10 NULL',                rec_vista.f_bach_similitud_tel(CAST(NULL AS VARCHAR),'1'), CAST(NULL AS INTEGER)
UNION ALL SELECT 'MAIL-1 caso .BTQ',           rec_vista.f_bach_similitud_email('luedu01','gmail.com','L300','G540','luedu','gmail.com','L300','G540',70,50,50,30,50,50), 89
UNION ALL SELECT 'MAIL-2 soundex distinto',    rec_vista.f_bach_similitud_email('ana','x.com','A500','X250','ana','x.com','B000','X250',70,50,50,30,50,50), 65
UNION ALL SELECT 'MAIL-3 buzon vacio',         rec_vista.f_bach_similitud_email('','x.com','','X250','luedu','x.com','','X250',70,50,50,30,50,50), 65
UNION ALL SELECT 'MZ-1 caso .BTQ',             rec_vista.f_bach_similitud_dir_mz('KR 9 161B 23','KR 9 161B 23',0,100,20,80,50,50,70,30), 100
UNION ALL SELECT 'MZ-2 sin numeros',           rec_vista.f_bach_similitud_dir_mz('MZ A','MZ B',0,100,20,80,50,50,70,30), 75
UNION ALL SELECT 'MZ-3 aciertos repetidos',    rec_vista.f_bach_similitud_dir_mz('CL 9 9','CL 9 9 9',0,100,20,80,50,50,70,30), 183
) t
ORDER BY caso;

SELECT caso, obtenido, esperado,
       CASE WHEN ABS(obtenido - esperado) < 1e-9 THEN 'S' ELSE 'N' END AS ok
FROM (
          SELECT 'PORC-1' AS caso, rec_vista.f_porc_similitud('2822994','2822992') AS obtenido, CAST(85.71428571428571 AS DOUBLE PRECISION) AS esperado
UNION ALL SELECT 'PORC-2 direcciones largas', rec_vista.f_porc_similitud('CALLE 123 NUMERO 45 67 SUR BARRIO','CALLE 123 NUMERO 45 67 NORTE'), 100
UNION ALL SELECT 'PORC-3 iguales',            rec_vista.f_porc_similitud('ABCD','ABCD'), 100
) t
ORDER BY caso;

SELECT caso, obtenido, esperado,
       CASE WHEN obtenido = esperado THEN 'S' ELSE 'N' END AS ok
FROM (
          SELECT 'DM-1' AS caso, rec_vista.f_datamasking('3001234567') AS obtenido, CAST('300123XXXX' AS VARCHAR(500)) AS esperado
UNION ALL SELECT 'DM-2 dato de 3 caracteres', rec_vista.f_datamasking('ana'), 'ana'
UNION ALL SELECT 'DIR-1',   rec_vista.f_dirdatamasking('CL 10 # 5-20'), 'CL XX # X-XX'
UNION ALL SELECT 'RAZON-1', rec_vista.f_razondatamasking('  INVERSIONES  ABC   LTDA '), 'INVERSIXXXX ABC XXXX'
) t
ORDER BY caso;
