-- ============================================================
-- Prueba de las VISTAS REALES con datos SINTETICOS (inventados).
-- No es certificacion: comprueba la FORMA de las llaves, el bloqueo, el
-- suscriptor, los canales, la normalizacion de telefonos y la ciudad de
-- respaldo sobre el stub del datashare, que el banco deja vacio. Las personas
-- reproducen lo medido en C4-C22 en DEV y QA
-- (docs/edf_views/RESULTADOS_CONSULTAS_EDF.md).
--
-- Los tipos de contacto siguen el catalogo OFICIAL de contactType
-- (RESULTADOS_CONSULTAS_EDF.md seccion 16): 7 Legal y 8 Business Address
-- dan JUD y CCL; 12 no se lee; 13 Notification Phone y 14 Business Email si.
--
-- Uso: ./banco.sh init nueva && fase strct && fase pgm, y luego
--   ./banco.sh psql -f vistas_reales_sinteticas.sql
-- Lo esperado esta junto a cada consulta.
-- ============================================================
TRUNCATE edf_views.xpm, edf_views.xpm_location,
         edf_views.xpm_location_val_contactinformations, edf_views.xpm_counterparties;

INSERT INTO edf_views.xpm (pin, location, counterparties) VALUES
  ('1001', 501, 801),   -- P1: dos reportes de suscriptor, una contraparte
  ('1002', 502, NULL),  -- P2: reporta la MISMA direccion que P1
  ('1004', 504, NULL),  -- P4: reporte bloqueado
  ('1005', 505, 805),   -- P5: dos contrapartes y suscriptor propio
  ('1006', 506, NULL),  -- P6: fuente 6 (direccion 8 con citycode, telefono 6)
  ('1007', 507, NULL);  -- P7: direcciones de suscriptor sin DANE (Divipola)

INSERT INTO edf_views.xpm_location
  (id, "location.val.contactinformations", "location.val.blockreason",
   "location.val.counterpartyidnumber", "location.val.cutoffdate",
   "location.val.personidtype", "location.val.accounttype") VALUES
  (501, 9001, '',  '',          '1772323200000', '1', ''),
  (501, 9002, '0', '',          '1772323200000', '1', ''),
  (502, 9003, '',  '',          '1772323200000', '2', ''),
  (504, 9004, '2', '',          '1772323200000', '1', ''),
  (505, 9005, '',  '890000005', '1772323200000', '1', ''),
  (506, 9006, '',  '',          '1772323200000', '2', ''),
  (506, 9007, '',  '',          '1772323200000', '2', ''),
  (507, 9008, '',  '890000007', '1772323200000', '1', '');

-- Los telefonos de suscriptor llegan como en EDF: 12 digitos con ceros a la
-- izquierda (C22). Los de la fuente 6, sin relleno (C18).
INSERT INTO edf_views.xpm_location_val_contactinformations
  (id, "index", "location.val.contactinformations.val.contacttype",
   "location.val.contactinformations.val.standardizedtextoubicacion",
   "location.val.contactinformations.val.contactasreported",
   "location.val.contactinformations.val.standardizeddanecode",
   "location.val.contactinformations.val.citycode",
   "location.val.contactinformations.val.cityname",
   "location.val.contactinformations.val.statename",
   "location.val.contactinformations.val.contacteventlastupdated") VALUES
  (9001, '0', '8',  'CL 10 # 5 - 20', 'CL 10 5 20',     '05001000', NULL,   'MEDELLIN', NULL,     '1772323200000'),
  (9001, '1', '6',  NULL,             '3115556677',     NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9001, '2', '10', NULL,             'x@ejemplo.co',   NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9001, '3', '4',  NULL,             '006041234567',   NULL,       NULL,   'MEDELLIN', NULL,     '1772323200000'),
  (9002, '0', '8',  'KR 50 # 30 - 10','KR 50 30 10',    '05001000', NULL,   'MEDELLIN', NULL,     '1772323200000'),
  (9002, '1', '9',  NULL,             '003001234567',   NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9003, '0', '8',  'CL 10 # 5 - 20', 'CALLE 10 5-20',  '05001000', NULL,   'MEDELLIN', NULL,     '1772323200000'),
  (9004, '0', '8',  'CL 1 # 1 - 1',   'CL 1 1 1',       '11001000', NULL,   'BOGOTA',   NULL,     '1772323200000'),
  (9004, '1', '4',  NULL,             '006011111111',   NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9005, '0', '8',  'CL 2 # 2 - 2',   'CL 2 2 2',       NULL,       NULL,   'BOGOTA',   NULL,     '1772323200000'),
  (9005, '1', '4',  NULL,             '006012222222',   NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9006, '0', '8',  'CL 50 # 50 - 50','CL 50 50 50',    NULL,       '5001', NULL,       NULL,     '1772323200000'),
  (9006, '1', '6',  NULL,             '3101234567',     NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9006, '2', '11', NULL,             '',               NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9007, '0', '8',  'CL 60 # 60 - 60','CL 60 60 60',    NULL,       '11001',NULL,       NULL,     '1772323200000'),
  (9007, '1', '6',  NULL,             '6042223344',     NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9007, '2', '13', NULL,             '3209998877',     NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9007, '3', '14', NULL,             'y@empresa.co',   NULL,       NULL,   NULL,       NULL,     '1772323200000'),
  (9008, '0', '1',  'KR 1 # 2 - 3',   'KR 1 2 3',       NULL,       NULL,   U&'Medell\00EDn', NULL, '1772323200000'),
  (9008, '1', '3',  'CL 7 # 8 - 9',   'CL 7 8 9',       NULL,       NULL,   'MIRAFLORES', U&'Boyac\00E1', '1772323200000'),
  (9008, '2', '2',  'CL 9 # 9 - 9',   'CL 9 9 9',       NULL,       NULL,   'MIRAFLORES', NULL,   '1772323200000'),
  (9008, '3', '7',  'CL 5 # 5 - 5',   'CL 5 5 5',       '05001000', NULL,   NULL,       NULL,     '1772323200000'),
  (9008, '4', '12', 'CL 12 # 12 - 12','CL 12 12 12',    '05001000', NULL,   NULL,       NULL,     '1772323200000');

INSERT INTO edf_views.xpm_counterparties (id, "index", "counterparties.val.counterpartyidnumber") VALUES
  (801, '0', '860000001'),
  (805, '0', '800000001'),
  (805, '1', '800000002');

-- 1. Direcciones: llave propia; P1 y P2 comparten lugar; P4 bloqueado = 1.
--    Ciudad: DANE donde viene; 5001000 por citycode 5001 (P6) y 11001000 por
--    citycode 11001; 5001000 para Medellin con tilde por Divipola; 15455000
--    para MIRAFLORES de Boyaca; NULL para MIRAFLORES sin departamento (hay
--    dos) y para BOGOTA de P5... salvo que el nombre unico la resuelva:
--    BOGOTA si es unico en el catalogo -> 11001000.
--    Tipo: el 8 da 5 (CCL), el 1/2/3 pasan tal cual y el 7 (CL 5) da 4 (JUD);
--    el 12 (CL 12) no aparece.
SELECT texto_ubicacion, cod_dw_persona_ubic, cod_dw_ubic, cod_dw_ciudad, bloqueado,
       cod_dw_tipo_ubicacion_dir
  FROM bdm_tempo.v_xpm_contacto_direccion ORDER BY 1, 2;
-- 2. Un lugar por fila; municipio = ciudad / 1000.
SELECT cod_dw_ubic, texto_ubicacion, cod_dw_ciudad, cod_dw_municipio,
       COUNT(*) OVER (PARTITION BY cod_dw_ubic) AS filas_por_lugar
  FROM bdm_tempo.v_xpm_ubicacion_estandarizada ORDER BY 2;
-- 3. Canales: telefonos sin ceros de relleno; el 6 reparte 3115556677 y
--    3101234567 a CEL y 6042223344 a TEL; el 13 (3209998877) va a CEL y el 14
--    a EMA; el 11 vacio no aparece; nada de P4; P5 una sola vez con su
--    suscriptor propio.
SELECT contact_type, canal, valor_contacto, cod_dw_persona_ubic, id_buro_suscriptor
  FROM bdm_tempo.v_xpm_contacto_canal ORDER BY canal, valor_contacto;
-- 4. TEL: 6041234567, 6012222222 y 6042223344, y ninguna direccion.
SELECT direccion_fisica, descripcion_gestion FROM bdm_datos.insumo_telefono ORDER BY 1;
-- 5. CEL: cuatro celulares con su operador del catalogo real (300, 310, 311,
--    320).
SELECT celular, operador FROM bdm_datos.insumo_celular ORDER BY 1;
