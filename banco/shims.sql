-- banco/shims.sql -- lo que Redshift trae de fabrica y Postgres no.
--
-- Vive en el esquema `rs`, que va en el search_path de la base. Asi
-- GETDATE(), FNV_HASH(), LEN() y TRUNC(timestamp) resuelven por sobrecarga y
-- el transpilador NO tiene que tocar el texto: una regla de reescritura menos
-- es una fuente de errores menos.
--
-- Solo DATEADD y DATEDIFF llegan aqui reescritos, y no por el nombre sino por
-- la sintaxis: en Redshift la unidad va como palabra desnuda (DATEADD(month,
-- ...)), y Postgres eso lo lee como una referencia a columna.

CREATE SCHEMA IF NOT EXISTS rs;

-- ---------------------------------------------------------------------------
-- FNV-1a de 64 bits, el mismo que Redshift: base 0xcbf29ce484222325, primo
-- 0x100000001b3, sobre los bytes UTF-8.
--
-- Va en numeric y no en bigint porque la multiplicacion desborda los 64 bits
-- con signo y Postgres levanta error en vez de truncar. El XOR solo afecta al
-- byte bajo, asi que se descompone: quitar h%256, XOR en integer, devolver.
-- Al final se mapea el rango alto a negativo, que es lo que hace Redshift.
--
-- Nota de coste: ~4 operaciones numeric por byte. Si una corrida se vuelve
-- lenta, el sospechoso es este, y la salida es un hash derivado de md5 --
-- determinista y rapido, pero YA NO COINCIDE con Redshift. Para certificar en
-- mock da igual (los gates comparan corrida contra corrida en el mismo motor);
-- no da igual si alguien compara un id local contra uno de Redshift.
CREATE OR REPLACE FUNCTION rs.fnv_hash(v text) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE STRICT AS $fn$
DECLARE
  h numeric := 14695981039346656037;
  p numeric := 1099511628211;
  m numeric := 18446744073709551616;
  b bytea   := convert_to(v, 'UTF8');
  i integer;
BEGIN
  FOR i IN 0 .. octet_length(b) - 1 LOOP
    h := h - (h % 256) + (((h % 256)::integer) # get_byte(b, i));
    h := (h * p) % m;
  END LOOP;
  IF h >= 9223372036854775808 THEN
    RETURN (h - m)::bigint;
  END IF;
  RETURN h::bigint;
END
$fn$;

-- A proposito NO hay sobrecarga numerica. Redshift hashea la representacion
-- BINARIA de un numero, no su texto, asi que una sobrecarga que convirtiera a
-- texto daria valores distintos en silencio. Que el banco grite.
CREATE OR REPLACE FUNCTION rs.fnv_hash(v bigint) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE AS $fn$
BEGIN
  RAISE EXCEPTION 'rs.fnv_hash(bigint): Redshift hashea los bytes del numero, '
                  'no su texto. Castea explicitamente y decide cual quieres.';
END
$fn$;

-- ---------------------------------------------------------------------------
-- GETDATE() es clock_timestamp(), no now().
--
-- En Redshift la cadena de CALL es NONATOMIC y el reloj avanza por sentencia.
-- En Postgres un CALL es una transaccion, asi que now() congelaria el tiempo de
-- toda la fase y DATEDIFF(second, inicio, fin) daria 0 en la traza.
CREATE OR REPLACE FUNCTION rs.getdate() RETURNS timestamp
LANGUAGE sql VOLATILE AS $fn$ SELECT clock_timestamp()::timestamp $fn$;

CREATE OR REPLACE FUNCTION rs.len(v text) RETURNS integer
LANGUAGE sql IMMUTABLE STRICT AS $fn$ SELECT length(v) $fn$;

CREATE OR REPLACE FUNCTION rs.trunc(v timestamp) RETURNS date
LANGUAGE sql IMMUTABLE STRICT AS $fn$ SELECT v::date $fn$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rs.dateadd(parte text, n integer, d timestamp)
RETURNS timestamp LANGUAGE plpgsql IMMUTABLE AS $fn$
BEGIN
  IF d IS NULL OR n IS NULL THEN RETURN NULL; END IF;
  CASE lower(parte)
    WHEN 'year'   THEN RETURN d + (n || ' year')::interval;
    WHEN 'month'  THEN RETURN d + (n || ' month')::interval;
    WHEN 'week'   THEN RETURN d + (n || ' week')::interval;
    WHEN 'day'    THEN RETURN d + (n || ' day')::interval;
    WHEN 'hour'   THEN RETURN d + (n || ' hour')::interval;
    WHEN 'minute' THEN RETURN d + (n || ' minute')::interval;
    WHEN 'second' THEN RETURN d + (n || ' second')::interval;
    ELSE RAISE EXCEPTION 'rs.dateadd: unidad % no portada a proposito', parte;
  END CASE;
END
$fn$;

-- DATEDIFF cuenta FRONTERAS cruzadas, no periodos completos. Es la semantica
-- de Redshift y hay que escribirla a mano:
--   DATEDIFF(month, '2026-01-31', '2026-02-01') = 1
-- Una resta de intervalos daria 0, y eso moveria meses_reporte, que es insumo
-- directo del scoring de Ordenamiento.
CREATE OR REPLACE FUNCTION rs.datediff(parte text, a timestamp, b timestamp)
RETURNS bigint LANGUAGE plpgsql IMMUTABLE AS $fn$
BEGIN
  IF a IS NULL OR b IS NULL THEN RETURN NULL; END IF;
  CASE lower(parte)
    WHEN 'year'  THEN
      RETURN (DATE_PART('year', b) - DATE_PART('year', a))::bigint;
    WHEN 'month' THEN
      RETURN ((DATE_PART('year', b) - DATE_PART('year', a)) * 12
              + (DATE_PART('month', b) - DATE_PART('month', a)))::bigint;
    WHEN 'week'  THEN
      RETURN (DATE_TRUNC('week', b)::date - DATE_TRUNC('week', a)::date) / 7;
    WHEN 'day'   THEN
      RETURN (b::date - a::date)::bigint;
    WHEN 'hour'  THEN
      RETURN (EXTRACT(EPOCH FROM (DATE_TRUNC('hour', b)
                                - DATE_TRUNC('hour', a))) / 3600)::bigint;
    WHEN 'minute' THEN
      RETURN (EXTRACT(EPOCH FROM (DATE_TRUNC('minute', b)
                                - DATE_TRUNC('minute', a))) / 60)::bigint;
    WHEN 'second' THEN
      RETURN EXTRACT(EPOCH FROM (DATE_TRUNC('second', b)
                               - DATE_TRUNC('second', a)))::bigint;
    ELSE RAISE EXCEPTION 'rs.datediff: unidad % no portada a proposito', parte;
  END CASE;
END
$fn$;

-- ---------------------------------------------------------------------------
-- CURRENT_AWS_ACCOUNT: la cuenta AWS del cluster que ejecuta.
--
-- sp_geo_exportar_insumo la usa para resolver el Ambiente contra
-- geo_config.arcgis_account_id, y si no resuelve lanza excepcion. Se devuelve
-- la cuenta de DEV -- 647096294147, la del consumidor reconocerbatch -- para
-- que el banco se comporte como DEV y el SP siga su camino en vez de abortar.
--
-- Despues de esto, el UNLOAD a S3 fallara, que es lo correcto: es la misma ruta
-- que ya toma QA en Redshift porque el rol IAM rcncr-batch-redshift-geo no esta
-- asociado al cluster, y el propio SP la atrapa con EXCEPTION WHEN OTHERS y
-- marca el lote como fallido sin re-lanzar.
CREATE OR REPLACE FUNCTION rs.current_aws_account() RETURNS varchar(20)
LANGUAGE sql IMMUTABLE AS $fn$ SELECT '647096294147'::varchar(20) $fn$;
