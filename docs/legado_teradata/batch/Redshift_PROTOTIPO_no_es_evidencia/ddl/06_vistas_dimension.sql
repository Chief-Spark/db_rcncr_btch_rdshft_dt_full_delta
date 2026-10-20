-- ============================================================================
-- Script:      06_vistas_dimension.sql
-- Objetivo:    Tablas/vistas de dimension de persona (equivalentes a
--              BTTPRUVI.vu_persona / BTTPRUVI.v_tipo_persona en Teradata),
--              usadas para clasificar cada identificacion como Persona
--              Natural (PN) o Persona Juridica (PJ) en EXPORTPLANO.
--
-- NOTA: no estan documentadas en el DDL.sql original; se infiere su
-- estructura minima necesaria a partir del uso real:
--   SELECT a.Cod_Tipo_Ident_Fte, UPPER(b.Nombre_Tipo_Persona)
--   FROM BTTPRUVI.vu_persona a
--   LEFT JOIN BTTPRUVI.v_tipo_persona b ON a.Cod_DW_Tipo_Persona = b.Cod_DW_Tipo_Persona
-- Cod_Tipo_Ident_Fte observados: 1,4 = Natural ; 2,3 = Juridica (ver
-- EXPORTPLANO_111, condiciones WHERE_PN / WHERE_PJ).
-- ============================================================================

CREATE TABLE IF NOT EXISTS rec_vista.tipo_persona
(
    cod_dw_tipo_persona   INTEGER       NOT NULL,
    nombre_tipo_persona    VARCHAR(50)             -- 'NATURALES' | 'JURIDICAS'
)
DISTSTYLE ALL
SORTKEY (cod_dw_tipo_persona);

-- Carga de referencia minima (ajustar/completar segun catalogo real del cliente).
INSERT INTO rec_vista.tipo_persona (cod_dw_tipo_persona, nombre_tipo_persona)
SELECT 1, 'NATURALES' WHERE NOT EXISTS (SELECT 1 FROM rec_vista.tipo_persona WHERE cod_dw_tipo_persona = 1)
UNION ALL
SELECT 2, 'JURIDICAS' WHERE NOT EXISTS (SELECT 1 FROM rec_vista.tipo_persona WHERE cod_dw_tipo_persona = 2);

CREATE TABLE IF NOT EXISTS rec_vista.persona
(
    cod_tipo_ident_fte   INTEGER       NOT NULL,   -- 1,4 = Natural | 2,3 = Juridica
    cod_dw_tipo_persona   INTEGER,
    num_ident            VARCHAR(20)
)
DISTSTYLE ALL
SORTKEY (cod_tipo_ident_fte);

-- -----------------------------------------------------------------------
-- Vista equivalente a REC_STAGE.Vstg_BUROPERS_TMP, usada en
-- ACTUALIZA_HISTORIA_111 para resolver Id_Buro_Suscriptor a partir del
-- tipo/numero de identificacion del suscriptor que hizo la solicitud.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rec_stage.vstg_buropers_tmp
(
    cod_tipo_ident_fte   INTEGER,
    num_ident            VARCHAR(20),
    id_buro_persona       BIGINT
)
DISTSTYLE ALL
SORTKEY (cod_tipo_ident_fte, num_ident);
