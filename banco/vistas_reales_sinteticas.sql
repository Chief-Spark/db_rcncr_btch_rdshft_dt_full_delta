-- ============================================================
-- Prueba de las VISTAS REALES con datos SINTETICOS (inventados).
-- No es certificacion: comprueba la FORMA de las llaves, el bloqueo, el
-- suscriptor y el canal TEL sobre el stub del datashare, que el banco deja
-- vacio. Cinco personas que reproducen lo medido en C4-C16
-- (docs/edf_views/RESULTADOS_CONSULTAS_EDF.md).
--
-- Uso: ./banco.sh init nueva && fase strct && fase pgm, y luego
--   ./banco.sh psql -f vistas_reales_sinteticas.sql
-- Lo esperado esta al final, junto a cada consulta.
-- ============================================================
TRUNCATE edf_views.xpm, edf_views.xpm_location,
         edf_views.xpm_location_val_contactinformations, edf_views.xpm_counterparties;

INSERT INTO edf_views.xpm (pin, location, counterparties) VALUES
  ('1001', 501, 801),   -- P1: dos reportes, una contraparte
  ('1002', 502, NULL),  -- P2: reporta la MISMA direccion que P1
  ('1004', 504, NULL),  -- P4: reporte bloqueado
  ('1005', 505, 805);   -- P5: dos contrapartes y suscriptor propio

INSERT INTO edf_views.xpm_location
  (id, "location.val.contactinformations", "location.val.blockreason",
   "location.val.counterpartyidnumber", "location.val.cutoffdate",
   "location.val.personidtype", "location.val.accounttype") VALUES
  (501, 9001, '',  '',          '1772323200000', '1', ''),
  (501, 9002, '0', '',          '1772323200000', '1', ''),
  (502, 9003, '',  '',          '1772323200000', '2', ''),
  (504, 9004, '2', '',          '1772323200000', '1', ''),
  (505, 9005, '',  '890000005', '1772323200000', '1', '');

INSERT INTO edf_views.xpm_location_val_contactinformations
  (id, "index", "location.val.contactinformations.val.contacttype",
   "location.val.contactinformations.val.standardizedtextoubicacion",
   "location.val.contactinformations.val.contactasreported",
   "location.val.contactinformations.val.standardizeddanecode",
   "location.val.contactinformations.val.cityname",
   "location.val.contactinformations.val.contacteventlastupdated") VALUES
  (9001, '0', '8',  'CL 10 # 5 - 20', 'CL 10 5 20',  '05001000', 'MEDELLIN', '1772323200000'),
  (9001, '1', '6',  NULL,             'MEDELLIN',    NULL,       'MEDELLIN', '1772323200000'),
  (9001, '2', '10', NULL,             'x@ejemplo.co', NULL,      NULL,       '1772323200000'),
  (9001, '3', '4',  NULL,             '6041234567',  NULL,       NULL,       '1772323200000'),
  (9002, '0', '8',  'KR 50 # 30 - 10','KR 50 30 10', '05001000', 'MEDELLIN', '1772323200000'),
  (9002, '1', '9',  NULL,             '3001234567',  NULL,       NULL,       '1772323200000'),
  (9003, '0', '8',  'CL 10 # 5 - 20', 'CALLE 10 5-20','05001000','MEDELLIN', '1772323200000'),
  (9004, '0', '8',  'CL 1 # 1 - 1',   'CL 1 1 1',    '11001000', 'BOGOTA',   '1772323200000'),
  (9004, '1', '4',  NULL,             '6011111111',  NULL,       NULL,       '1772323200000'),
  (9005, '0', '8',  'CL 2 # 2 - 2',   'CL 2 2 2',    NULL,       'BOGOTA',   '1772323200000'),
  (9005, '1', '4',  NULL,             '6012222222',  NULL,       NULL,       '1772323200000');

INSERT INTO edf_views.xpm_counterparties (id, "index", "counterparties.val.counterpartyidnumber") VALUES
  (801, '0', '860000001'),
  (805, '0', '800000001'),
  (805, '1', '800000002');

-- 1. Cinco direcciones con llave propia. P1 y P2 ("CL 10 # 5 - 20", mismo
--    DANE) comparten cod_dw_ubic; las dos de P1 no. P4 bloqueado = 1.
--    P5 sin DANE: cod_dw_ciudad NULL.
SELECT texto_ubicacion, cod_dw_persona_ubic, cod_dw_ubic, cod_dw_ciudad, bloqueado
  FROM bdm_tempo.v_xpm_contacto_direccion ORDER BY 1, 2;
-- 2. Cuatro lugares, una fila cada uno; municipio 5001 y 11001.
SELECT cod_dw_ubic, texto_ubicacion, cod_dw_municipio,
       COUNT(*) OVER (PARTITION BY cod_dw_ubic) AS filas_por_lugar
  FROM bdm_tempo.v_xpm_ubicacion_estandarizada ORDER BY 2;
-- 3. Canales: telefono, celular y correo apuntan a la direccion de SU
--    reporte; nada de P4; P5 con dos contrapartes sale una vez y con su
--    suscriptor propio (890000005); P1 toma su contraparte unica (860000001).
SELECT contact_type, valor_contacto, cod_dw_persona_ubic, id_buro_suscriptor
  FROM bdm_tempo.v_xpm_contacto_canal ORDER BY 2;
-- 4. TEL: dos telefonos (P1 y P5) y ninguna direccion.
SELECT direccion_fisica, descripcion_gestion FROM bdm_datos.insumo_telefono;
