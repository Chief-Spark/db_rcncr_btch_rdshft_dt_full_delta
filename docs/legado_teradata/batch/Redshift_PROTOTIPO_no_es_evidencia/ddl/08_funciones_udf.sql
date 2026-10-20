-- ============================================================================
-- Script:      08_funciones_udf.sql
-- Objetivo:    Equivalentes Redshift de las UDF Teradata (base REC_VISTA)
--              que usan los SP migrados desde Sps_Batch.sql.
-- Fuente:      FuncionesUDF/ (codigo C + .BTQ de cada UDF), aportado el
--              2026-10-14.
--
-- REEMPLAZO POR FUNCIONES NATIVAS (no requieren UDF):
--   REC_VISTA.eListGetValByIdx(cad, '@', n)  -> SPLIT_PART(cad, '@', n)
--   REC_VISTA.hash_md5(x)                    -> MD5(x)
--   TRANSLATE(... USING UNICODE_TO_LATIN)    -> se elimina: en FILTRO_F se
--        aplica DESPUES de REGEXP_REPLACE(x,'[^a-zA-Z]',''), que ya deja
--        solo letras ASCII, por lo que la traduccion no cambia el resultado.
--   SOUNDEX(x)                               -> SOUNDEX(x) (nativa en Redshift)
--
-- UDF CON LOGICA PROPIA (codigo C portado):
--   a) Similitud (usan distancia de edicion, no expresable en SQL de
--      Redshift): LAMBDA UDF. Las 4 apuntan a la MISMA funcion Lambda
--      (Redshift/lambda/udf_similitud/lambda_function.py), que elige la
--      UDF por el nombre de la funcion externa que la invoca.
--        Bach_Similitud_Dir_MZ -> rec_vista.f_bach_similitud_dir_mz
--        PorcSimilitud         -> rec_vista.f_porc_similitud
--        Bach_Similitud_Tel    -> rec_vista.f_bach_similitud_tel
--        Bach_Similitud_email  -> rec_vista.f_bach_similitud_email
--      Las Python UDF de Redshift ya no estan soportadas (fin de soporte
--      30-jun-2026); AWS recomienda Lambda UDF.
--   b) Enmascaramiento (logica de cadenas simple): SQL UDF, sin Lambda.
--        DataMasking      -> rec_vista.f_datamasking
--        DirDataMasking   -> rec_vista.f_dirdatamasking
--        RazonDataMasking -> rec_vista.f_razondatamasking
--      Equivalencia con el C probada en
--      Redshift/lambda/udf_similitud/test_lambda_function.py
--      (TestEnmascaramientoSQL, 5 000 cadenas aleatorias).
--
-- No migrada: Bach_Similitud_Dir_VIA. Ningun SP de BATCH2 la llama y
-- depende de Address_Normalization (AddressNormalization.h, no disponible).
--
-- SEMANTICA TERADATA QUE SE CONSERVA (detalle en lambda_function.py):
--   - PARAMETER STYLE TD_GENERAL: argumento NULL -> resultado NULL.
--   - Truncamiento silencioso de los argumentos al VARCHAR declarado en
--     Teradata: 20 (PorcSimilitud, Bach_Similitud_Tel), 30/5
--     (Bach_Similitud_email), 500 (Bach_Similitud_Dir_MZ), 200
--     (enmascaramiento). OJO: FILTRO_F llama a PorcSimilitud con direcciones
--     completas, asi que en Teradata solo se comparaban sus 20 primeros
--     caracteres; se replica. Por eso aqui los parametros se declaran
--     VARCHAR(65535) y el recorte lo hace la propia funcion (resultado
--     identico sin depender de como Redshift ajusta largos de argumentos).
--   - Conversion double -> int de C: trunca hacia cero; division por cero
--     (insumo vacio) da INT_MIN (-2147483648) en x86-64.
--
-- SUPUESTO PENDIENTE DE VALIDAR EN TERADATA:
--   La distancia de edicion editdistance_u (loadParamsAcepAut.h, no esta en
--   el workspace) se implemento como Damerau-Levenshtein OSA con costos 1.
--   Ejecutar Redshift/lambda/udf_similitud/casos_validacion_teradata.sql en
--   Teradata y comparar con casos_validacion_redshift.sql.
--
-- ANTES DE EJECUTAR ESTE SCRIPT:
--   1. Desplegar la Lambda (Python 3.12, handler lambda_function.lambda_handler,
--      sin dependencias externas). Timeout sugerido: 5 min.
--   2. Reemplazar:
--        <LAMBDA_UDF_SIMILITUD>  -> nombre (o ARN) de la funcion Lambda
--        <IAM_ROLE_LAMBDA_ARN>   -> ARN del rol que Redshift asume para
--                                   invocarla (permiso lambda:InvokeFunction),
--                                   o la palabra default
--   3. Si una version anterior de este script creo f_datamasking,
--      f_dirdatamasking o f_razondatamasking como EXTERNAL FUNCTION, borrarlas
--      antes: DROP FUNCTION rec_vista.f_datamasking(VARCHAR); (idem las otras).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SQL UDF: equivalente a TO_NUMBER(x) de Teradata con UN argumento, que
-- devuelve NULL (en vez de error) si la cadena no es numerica. Redshift
-- TO_NUMBER exige formato y falla con cadenas invalidas.
-- Usada en: FILTRO_E/F (porcentajes), HOMOLOGACIONES y ADICIONAR_INCON
-- ("COALESCE(TO_NUMBER(Numero_Id),0) > 0").
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rec_vista.f_td_to_number (VARCHAR)
RETURNS DECIMAL(38,10)
IMMUTABLE
AS $$
    SELECT CASE
             WHEN TRIM($1) ~ '^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)$'
             THEN CAST(TRIM($1) AS DECIMAL(38,10))
           END
$$ LANGUAGE sql;

-- ============================================================================
-- a) LAMBDA UDF de similitud (FILTRO_F)
-- ============================================================================

-- Bach_Similitud_Dir_MZ: similitud de direcciones tipo manzana.
-- Args: dir_insumo, dir_bodega, PorHitMz0, PorDisMz0, PorHitMz1, PorDisMz1,
--       PorHitMz2, PorDisMz2, PorHitMz3, PorDisMz3
-- Puntaje = % de numeros del insumo presentes en la bodega * PorHit +
-- (1 - distancia/largo insumo) * PorDis; el par de pesos depende de cuantos
-- numeros (1 a 9 digitos) tiene el insumo (0, 1, 2, 3+). Puede ser > 100
-- (numeros repetidos en la bodega cuentan varias veces) o < 0.
CREATE OR REPLACE EXTERNAL FUNCTION rec_vista.f_bach_similitud_dir_mz
    (VARCHAR(65535), VARCHAR(65535), INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER)
RETURNS INTEGER
STABLE
LAMBDA '<LAMBDA_UDF_SIMILITUD>'
IAM_ROLE '<IAM_ROLE_LAMBDA_ARN>';

-- PorcSimilitud: (largo - distancia) / largo * 100 sobre los 20 primeros
-- caracteres de cada cadena. Teradata: RETURNS FLOAT -> DOUBLE PRECISION
-- (FILTRO_F lo trunca con CAST(TRUNC(..) AS INTEGER)). Insumo vacio -> NULL
-- (en C seria inf/NaN; ver lambda_function.py).
-- Args: cadena_insumo, cadena_bodega
CREATE OR REPLACE EXTERNAL FUNCTION rec_vista.f_porc_similitud
    (VARCHAR(65535), VARCHAR(65535))
RETURNS DOUBLE PRECISION
STABLE
LAMBDA '<LAMBDA_UDF_SIMILITUD>'
IAM_ROLE '<IAM_ROLE_LAMBDA_ARN>';

-- Bach_Similitud_Tel: (1 - distancia/largo insumo + 0.00499) * 100, truncado.
-- Args: numero_insumo, numero_bodega (FILTRO_F pasa numero_cubo, numero_insumo)
CREATE OR REPLACE EXTERNAL FUNCTION rec_vista.f_bach_similitud_tel
    (VARCHAR(65535), VARCHAR(65535))
RETURNS INTEGER
STABLE
LAMBDA '<LAMBDA_UDF_SIMILITUD>'
IAM_ROLE '<IAM_ROLE_LAMBDA_ARN>';

-- Bach_Similitud_email: buzon y dominio, cada uno con SOUNDEX igual (100/0)
-- y % de distancia, ponderados.
-- Args: BuzonInsumo, DominioInsumo, SoundexBuzonInsumo, SoundexDominioInsumo,
--       BuzonBodega, DominioBodega, SoundexBuzonBodega, SoundexDominioBodega,
--       PorBz, PorBzSoun, PorBzDist, PorDom, PorDomSoun, PorDomDist
CREATE OR REPLACE EXTERNAL FUNCTION rec_vista.f_bach_similitud_email
    (VARCHAR(65535), VARCHAR(65535), VARCHAR(65535), VARCHAR(65535),
     VARCHAR(65535), VARCHAR(65535), VARCHAR(65535), VARCHAR(65535),
     INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER)
RETURNS INTEGER
STABLE
LAMBDA '<LAMBDA_UDF_SIMILITUD>'
IAM_ROLE '<IAM_ROLE_LAMBDA_ARN>';

-- ============================================================================
-- b) SQL UDF de enmascaramiento (HOMOLOGACIONES, bloque L2: solicitudes de
--    PRUEBA). Entrada recortada a 200 (VARCHAR(200) en Teradata).
-- ============================================================================

-- DataMasking.c: si el dato tiene mas de 3 caracteres, reemplaza los 4
-- ultimos por 'X'.
-- DECISION: con 3 caracteres o menos el C devuelve un buffer sin
-- inicializar (resultado indefinido; en la practica basura de la llamada
-- anterior). Aqui se devuelve el dato sin cambios, que es lo que el codigo
-- intenta (el "if" solo protege los indices). Afecta a buzones de correo
-- cortos ('ana@...') en solicitudes de prueba.
CREATE OR REPLACE FUNCTION rec_vista.f_datamasking (VARCHAR(65535))
RETURNS VARCHAR(500)
IMMUTABLE
AS $$
    SELECT CASE
             WHEN LEN(LEFT($1, 200)) > 3
             THEN LEFT(LEFT($1, 200), LEN(LEFT($1, 200)) - 4) || 'XXXX'
             ELSE LEFT($1, 200)
           END
$$ LANGUAGE sql;

-- DirDataMasking.c: cada digito 0-9 se reemplaza por 'X'.
CREATE OR REPLACE FUNCTION rec_vista.f_dirdatamasking (VARCHAR(65535))
RETURNS VARCHAR(500)
IMMUTABLE
AS $$
    SELECT TRANSLATE(LEFT($1, 200), '0123456789', 'XXXXXXXXXX')
$$ LANGUAGE sql;

-- RazonDataMasking.c: separa por espacios (strtok: varios espacios cuentan
-- como uno y se quitan los de los extremos), reemplaza los 4 ultimos
-- caracteres de cada palabra de mas de 3 caracteres por 'X' y une las
-- palabras con un solo espacio.
-- SQL: 1) BTRIM + colapsar espacios; 2) agregar un espacio final y cambiar
-- cada "4 no-espacios + espacio" por 'XXXX ' (solo calza al final de cada
-- palabra); 3) quitar el espacio agregado.
CREATE OR REPLACE FUNCTION rec_vista.f_razondatamasking (VARCHAR(65535))
RETURNS VARCHAR(500)
IMMUTABLE
AS $$
    SELECT RTRIM(
             REGEXP_REPLACE(
               REGEXP_REPLACE(BTRIM(LEFT($1, 200)), ' +', ' ') || ' ',
               '[^ ]{4} ', 'XXXX '),
             ' ')
$$ LANGUAGE sql;

-- Bugs del C que NO se replican (no aplican a los datos de BATCH2):
--   - sprintf(salida, cadena) usa el dato como cadena de formato: un '%' en
--     el dato produce salida corrupta en Teradata.
--   - Buffer de 200 bytes para un VARCHAR(200): con exactamente 200
--     caracteres el C escribe 1 byte fuera del buffer.
