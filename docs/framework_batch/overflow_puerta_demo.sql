-- ============================================================
-- D-DEMO-01: el overflow de la Regla 3 en DEMO, medido
--
-- POR QUE EXISTE ESTE ARCHIVO. El 2026-11-18 la Unificacion FULL de DEMO
-- (lote 20261112) murio en la Regla 3 con
--   ERROR: sp_unificacion_regla3 failed:
--          Overflow (Long valid range -9223372036854775808 to 9223372036854775807)
-- El diagnostico por lectura de codigo senala
-- sp_unificacion_r3_esc1_geo_misma_via_puerta_cercana.sql:155: la guarda que
-- QA #176 anadio castea a BIGINT para comprobar si el numero de puerta cabe en
-- INTEGER, y ESE cast desborda con un texto de 19 digitos o mas.
--
-- UNA LECTURA DE CODIGO NO ES UNA MEDICION. La consulta 1 lo confirma o lo
-- tumba contra el dato, y hay que correrla ANTES de desplegar el arreglo:
-- si da 0, el diagnostico esta mal y no hay que tocar nada.
--
-- Se corre en DEMO, en la base del pipeline -- NO en 'dba', donde no existen
-- bdm_datos / bdm_tempo / bdm_stage.
-- ============================================================

-- ------------------------------------------------------------
-- 1. BLOQUEANTE: hay numeros de puerta que no caben en INTEGER?
--
-- 'fuera_de_integer' > 0 cierra el diagnostico. 'max_digitos' dice cuanto se
-- paso: con 19 o mas desborda BIGINT (el Long del error); entre 10 y 18 habria
-- desbordado solo INTEGER, que es el caso de QA #176.
-- ------------------------------------------------------------
SELECT COUNT(*)                                                      AS filas,
       MAX(LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$'))) AS max_digitos,
       SUM(CASE WHEN LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$')) > 9
                THEN 1 ELSE 0 END)                                   AS fuera_de_integer,
       SUM(CASE WHEN LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$')) > 18
                THEN 1 ELSE 0 END)                                   AS fuera_de_bigint
  FROM bdm_tempo.v_xpm_direccion_fisica;

-- ------------------------------------------------------------
-- 2. De que rama vienen: del datashare o de las que escribe la R2
--
-- generada_enriquecida = 0 es v_xpm_contacto_direccion (standardizednumeropuerta
-- del datashare); 1 es bdm_datos.direccion_fisica_generada. Importa porque si
-- vienen de la R2, el valor largo lo produjimos nosotros y hay que mirar el
-- motor que lo escribio, no solo descartarlo en la R3.
-- ------------------------------------------------------------
SELECT generada_enriquecida,
       COUNT(*)                                                      AS filas,
       MAX(LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$'))) AS max_digitos
  FROM bdm_tempo.v_xpm_direccion_fisica
 WHERE LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$')) > 9
 GROUP BY 1;

-- ------------------------------------------------------------
-- 3. Una muestra, para ver QUE es ese valor
--
-- Un numero de puerta de 20 digitos no es una puerta: suele ser un telefono,
-- un documento o una concatenacion de la libreria de estandarizacion. Verlo
-- decide si basta descartarlo (lo que hace el arreglo) o si hay que avisar a
-- EDF de la calidad del campo.
-- ------------------------------------------------------------
SELECT cod_dw_direccion_fisica, generada_enriquecida,
       tipo_via_principal, via_principal, via_generadora,
       LEN(numero_puerta) AS largo_crudo, numero_puerta
  FROM bdm_tempo.v_xpm_direccion_fisica
 WHERE LEN(REGEXP_SUBSTR(COALESCE(numero_puerta, ''), '^[0-9]+$')) > 9
 LIMIT 20;

-- ------------------------------------------------------------
-- 4. DESPUES de desplegar el arreglo: que la R3 complete
--
-- El arreglo descarta la puerta que no cabe (numero_puerta_num = NULL) y el
-- escenario ya trata el NULL como "sin numero comparable", de modo que esas
-- filas no emparejan por puerta. No se pierde la direccion: se pierde su
-- comparacion por numero, que es lo correcto.
-- ------------------------------------------------------------
SELECT corrida_id, etapa, estado, fecha_inicio, fecha_fin
  FROM bdm_datos.unif_control_etapa
 WHERE lote = 20261112
 ORDER BY fecha_inicio;

-- ------------------------------------------------------------
-- 5. Y el resto de la clase: los otros once sitios
--
-- Las once guardas restantes tenian la MISMA forma y se corrigieron en el
-- mismo commit. Dos interesa medirlas: standardizeddanecode, que viene del
-- mismo lote de columnas de estandarizacion que la puerta, y
-- counterpartyidnumber, que alimenta id_buro_suscriptor -- si desborda no cae
-- una regla, caen las tres.
--
-- OJO, Y ESTO ES LO QUE HAY QUE NO EQUIVOCAR: se mide la columna de ORIGEN en
-- el datashare, NUNCA la salida de la vista. En la vista esas dos columnas ya
-- son INTEGER, de modo que si desbordaran la consulta FALLARIA en vez de
-- devolver un valor largo: medir ahi no mide nada y daria un 0 tranquilizador.
-- Es la trampa de "una medida de observabilidad tambien se equivoca".
--
-- Sustituir <datashare> por el esquema del datashare en DEMO. Desde DBeaver se
-- puede consultar desde cualquier base porque el nombre lleva las tres partes.
-- ------------------------------------------------------------
-- SELECT MAX(LEN(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR))) AS max_danecode
--   FROM <datashare>.xpm_location_val_contactinformations ci;
--
-- SELECT MAX(LEN(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR)))     AS max_counterparty
--   FROM <datashare>.xpm_location loc;
--
-- Un 0 o un valor corto en las dos NO prueba que la correccion sobrara:
-- prueba que DEMO no habia llegado a pisarlas todavia.
