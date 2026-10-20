/* ============================================================================
 * casos_validacion_teradata.sql
 * Ejecutar en TERADATA (BTEQ o SQL Assistant, modo de sesion Teradata) para
 * confirmar que la Lambda UDF y las SQL UDF de Redshift dan el mismo
 * resultado que las UDF C originales de REC_VISTA.
 *
 * Columna ESPERADO = valor que devuelve la version Redshift (calculado y
 * probado en test_lambda_function.py). Cualquier fila con OBTENIDO <>
 * ESPERADO indica un supuesto que hay que corregir en lambda_function.py o
 * en ddl/08_funciones_udf.sql.
 *
 * Supuestos que estos casos discriminan:
 *   [OSA]   editdistance_u (loadParamsAcepAut.h, no disponible) es
 *           Damerau-Levenshtein OSA: 'ABC' vs 'CA' = 3. Si fuera Damerau
 *           completo seria 2 (Tel = 33) y si fuera Levenshtein puro la
 *           transposicion de TEL-3 costaria 2 (Tel = 71).
 *   [TRUNC] Un argumento mas largo que el VARCHAR del parametro se trunca en
 *           silencio. Si Teradata da error en estos casos, quitar el
 *           truncamiento de TRUNCAR_A en lambda_function.py.
 *   [NULL]  PARAMETER STYLE TD_GENERAL: un argumento NULL da NULL.
 *   [X86]   Insumo vacio: division por cero en C -> INT_MIN en x86-64.
 * ============================================================================ */

-- Bach_Similitud_Tel (INTEGER). Casos TEL-1..5 = los del .BTQ (insumo = B, bodega = A)
SELECT CAST('TEL-1 iguales' AS VARCHAR(60)) AS CASO
     , REC_VISTA.Bach_Similitud_Tel('2826373','2826373') AS OBTENIDO, 100 AS ESPERADO
UNION ALL SELECT 'TEL-2 un digito',          REC_VISTA.Bach_Similitud_Tel('2822994','2822992'), 86
UNION ALL SELECT 'TEL-3 transposicion [OSA]', REC_VISTA.Bach_Similitud_Tel('3434620','3436420'), 86
UNION ALL SELECT 'TEL-4',                    REC_VISTA.Bach_Similitud_Tel('3432064','3436420'), 43
UNION ALL SELECT 'TEL-5 invertido',          REC_VISTA.Bach_Similitud_Tel('7654321','1234567'), 14
UNION ALL SELECT 'TEL-6 OSA vs Damerau [OSA]', REC_VISTA.Bach_Similitud_Tel('ABC','CA'), 0
UNION ALL SELECT 'TEL-7 negativo',           REC_VISTA.Bach_Similitud_Tel('123','12345678'), -66
UNION ALL SELECT 'TEL-8 truncamiento [TRUNC]',
                 REC_VISTA.Bach_Similitud_Tel('123456789012345678901234','12345678901234567890XXXX'), 100
UNION ALL SELECT 'TEL-9 insumo vacio [X86]', REC_VISTA.Bach_Similitud_Tel('','123'), -2147483648
UNION ALL SELECT 'TEL-10 NULL [NULL]',       REC_VISTA.Bach_Similitud_Tel(CAST(NULL AS VARCHAR(20)),'1'), NULL
ORDER BY 1;

-- PorcSimilitud (FLOAT)
SELECT CAST('PORC-1' AS VARCHAR(60)) AS CASO
     , REC_VISTA.PorcSimilitud('2822994','2822992') AS OBTENIDO
     , CAST(85.71428571428571 AS FLOAT) AS ESPERADO
UNION ALL SELECT 'PORC-2 direcciones largas [TRUNC]',
                 REC_VISTA.PorcSimilitud('CALLE 123 NUMERO 45 67 SUR BARRIO','CALLE 123 NUMERO 45 67 NORTE'), 100
UNION ALL SELECT 'PORC-3 iguales', REC_VISTA.PorcSimilitud('ABCD','ABCD'), 100
ORDER BY 1;

-- Bach_Similitud_email (INTEGER). Mismo SOUNDEX literal en insumo y bodega
-- para aislar la UDF de diferencias de SOUNDEX entre motores.
SELECT CAST('MAIL-1 caso .BTQ' AS VARCHAR(60)) AS CASO
     , REC_VISTA.Bach_Similitud_email('luedu01','gmail.com','L300','G540',
                                      'luedu','gmail.com','L300','G540',
                                      70,50,50,30,50,50) AS OBTENIDO
     , 89 AS ESPERADO
UNION ALL SELECT 'MAIL-2 soundex distinto',
                 REC_VISTA.Bach_Similitud_email('ana','x.com','A500','X250','ana','x.com','B000','X250',70,50,50,30,50,50), 65
UNION ALL SELECT 'MAIL-3 buzon vacio [X86]',
                 REC_VISTA.Bach_Similitud_email('','x.com','','X250','luedu','x.com','','X250',70,50,50,30,50,50), 65
ORDER BY 1;

-- Bach_Similitud_Dir_MZ (INTEGER), pesos de FILTRO_F
SELECT CAST('MZ-1 caso .BTQ' AS VARCHAR(60)) AS CASO
     , REC_VISTA.Bach_Similitud_Dir_MZ('KR 9 161B 23','KR 9 161B 23',0,100,20,80,50,50,70,30) AS OBTENIDO
     , 100 AS ESPERADO
UNION ALL SELECT 'MZ-2 sin numeros',      REC_VISTA.Bach_Similitud_Dir_MZ('MZ A','MZ B',0,100,20,80,50,50,70,30), 75
UNION ALL SELECT 'MZ-3 aciertos repetidos', REC_VISTA.Bach_Similitud_Dir_MZ('CL 9 9','CL 9 9 9',0,100,20,80,50,50,70,30), 183
ORDER BY 1;

-- Enmascaramiento (VARCHAR). DM-2: en C el resultado no esta definido
-- (buffer sin inicializar); Redshift devuelve el dato sin cambios. Anotar
-- lo que devuelva Teradata.
SELECT CAST('DM-1' AS VARCHAR(60)) AS CASO
     , CAST(REC_VISTA.DataMasking('3001234567') AS VARCHAR(200)) AS OBTENIDO
     , CAST('300123XXXX' AS VARCHAR(200)) AS ESPERADO
UNION ALL SELECT 'DM-2 dato de 3 caracteres (indefinido en C)', REC_VISTA.DataMasking('ana'), 'ana'
UNION ALL SELECT 'DIR-1', REC_VISTA.DirDataMasking('CL 10 # 5-20'), 'CL XX # X-XX'
UNION ALL SELECT 'RAZON-1', REC_VISTA.RazonDataMasking('  INVERSIONES  ABC   LTDA '), 'INVERSIXXXX ABC XXXX'
ORDER BY 1;
