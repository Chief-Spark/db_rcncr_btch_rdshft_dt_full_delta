-- ============================================================================
-- Procedure:   rec_stage.sp_batch2_cubo_export
-- Equivalente: P0033_BATCH2_CUBOEXPORT_111.BTQ / _120.BTQ / _130.TPT
-- Objetivo:    Pivotar cada tabla cubo (N filas por persona: telefonos,
--              celulares, direcciones, correos, CIIU) en una tabla horizontal
--              de trabajo w_cubo_* con columnas repetidas _001.._010, usando
--              ROW_NUMBER()/MAX(CASE...) en vez del ensamblado dinamico de
--              SQL como datos (patron w_Borrar_001) que usa Teradata.
--
-- FIDELIDAD: ALTA en el resultado (mismo pivote N->columnas, mismo criterio
--            de orden por Orden_Prioridad). MEDIA en la tecnica: Teradata
--            genera el numero de columnas dinamicamente; aqui el numero
--            maximo de repeticiones esta fijo en 10 (ver 04_tablas_pivote.sql).
--            Filtro_H consolidado se copia del cubo origen (fila con
--            Orden_Prioridad = 1), igual que en el 120.BTQ original donde
--            el filtro se materializa en la fila agregada por persona.
--
-- NOTA DE SINTAXIS: TRUNCATE TABLE hace COMMIT implicito en Redshift (inicia
-- una nueva transaccion automaticamente). Esto es analogo al comportamiento
-- de Teradata (DROP/CREATE de w_cubo_* fuera de una transaccion explicita
-- de negocio), por lo que no cambia la semantica del proceso, pero significa
-- que este procedure NO es atomico de punta a punta: si falla a mitad de
-- camino, los TRUNCATE ya ejecutados no se revierten.
-- ============================================================================

CREATE OR REPLACE PROCEDURE rec_stage.sp_batch2_cubo_export(
    p_id_solicitud   BIGINT,
    p_id_plantilla   BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    ------------------------------------------------------------------
    -- TELEFONO
    ------------------------------------------------------------------
    TRUNCATE TABLE rec_stage.w_cubo_telefono;

    INSERT INTO rec_stage.w_cubo_telefono
    SELECT
        id_buro_persona,
        MIN(filtro_h) AS filtro_h,
        MAX(CASE WHEN rn = 1 THEN ciudad END), MAX(CASE WHEN rn = 1 THEN departamento END), MAX(CASE WHEN rn = 1 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 1 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 1 THEN numero END), MAX(CASE WHEN rn = 1 THEN tipo END), MAX(CASE WHEN rn = 1 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 1 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 1 THEN CAST(por_sim_tel AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 2 THEN ciudad END), MAX(CASE WHEN rn = 2 THEN departamento END), MAX(CASE WHEN rn = 2 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 2 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 2 THEN numero END), MAX(CASE WHEN rn = 2 THEN tipo END), MAX(CASE WHEN rn = 2 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 2 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 2 THEN CAST(por_sim_tel AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 3 THEN ciudad END), MAX(CASE WHEN rn = 3 THEN departamento END), MAX(CASE WHEN rn = 3 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 3 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 3 THEN numero END), MAX(CASE WHEN rn = 3 THEN tipo END), MAX(CASE WHEN rn = 3 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 3 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 3 THEN CAST(por_sim_tel AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 4 THEN ciudad END), MAX(CASE WHEN rn = 4 THEN departamento END), MAX(CASE WHEN rn = 4 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 4 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 4 THEN numero END), MAX(CASE WHEN rn = 4 THEN tipo END), MAX(CASE WHEN rn = 4 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 4 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 4 THEN CAST(por_sim_tel AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 5 THEN ciudad END), MAX(CASE WHEN rn = 5 THEN departamento END), MAX(CASE WHEN rn = 5 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 5 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 5 THEN numero END), MAX(CASE WHEN rn = 5 THEN tipo END), MAX(CASE WHEN rn = 5 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 5 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 5 THEN CAST(por_sim_tel AS VARCHAR(30)) END)
    FROM (
        SELECT t.*,
               ROW_NUMBER() OVER (PARTITION BY t.id_buro_persona ORDER BY t.orden_prioridad) AS rn
        FROM rec_stage.batch_cubo_telefono t
        INNER JOIN rec_stage.batch_cubo_persona p
                ON p.id_buro_persona = t.id_buro_persona
        WHERE p.id_solicitud = p_id_solicitud
          AND (p_id_plantilla IS NULL OR p.id_plantilla = p_id_plantilla)
    ) x
    WHERE rn <= 5   -- ampliar a <= 10 si se amplia 04_tablas_pivote.sql
    GROUP BY id_buro_persona;

    ------------------------------------------------------------------
    -- CELULAR
    ------------------------------------------------------------------
    TRUNCATE TABLE rec_stage.w_cubo_celular;

    INSERT INTO rec_stage.w_cubo_celular
    SELECT
        id_buro_persona,
        MIN(filtro_h),
        MAX(CASE WHEN rn = 1 THEN ciudad END), MAX(CASE WHEN rn = 1 THEN departamento END), MAX(CASE WHEN rn = 1 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 1 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 1 THEN numero END), MAX(CASE WHEN rn = 1 THEN tipo END), MAX(CASE WHEN rn = 1 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 1 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 1 THEN CAST(por_sim_cel AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 2 THEN ciudad END), MAX(CASE WHEN rn = 2 THEN departamento END), MAX(CASE WHEN rn = 2 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 2 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 2 THEN numero END), MAX(CASE WHEN rn = 2 THEN tipo END), MAX(CASE WHEN rn = 2 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 2 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 2 THEN CAST(por_sim_cel AS VARCHAR(30)) END)
    FROM (
        SELECT c.*,
               ROW_NUMBER() OVER (PARTITION BY c.id_buro_persona ORDER BY c.orden_prioridad) AS rn
        FROM rec_stage.batch_cubo_celular c
        INNER JOIN rec_stage.batch_cubo_persona p
                ON p.id_buro_persona = c.id_buro_persona
        WHERE p.id_solicitud = p_id_solicitud
          AND (p_id_plantilla IS NULL OR p.id_plantilla = p_id_plantilla)
    ) x
    WHERE rn <= 2   -- ampliar segun 04_tablas_pivote.sql
    GROUP BY id_buro_persona;

    ------------------------------------------------------------------
    -- DIRECCION
    ------------------------------------------------------------------
    TRUNCATE TABLE rec_stage.w_cubo_direccion;

    INSERT INTO rec_stage.w_cubo_direccion
    SELECT
        id_buro_persona,
        MIN(filtro_h),
        MAX(CASE WHEN rn = 1 THEN ciudad END), MAX(CASE WHEN rn = 1 THEN departamento END), MAX(CASE WHEN rn = 1 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 1 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 1 THEN direccion END), MAX(CASE WHEN rn = 1 THEN tipo END), MAX(CASE WHEN rn = 1 THEN zona END), MAX(CASE WHEN rn = 1 THEN estrato END), MAX(CASE WHEN rn = 1 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 1 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 1 THEN CAST(por_sim_dir AS VARCHAR(30)) END),
        MAX(CASE WHEN rn = 2 THEN ciudad END), MAX(CASE WHEN rn = 2 THEN departamento END), MAX(CASE WHEN rn = 2 THEN cod_dane_ciudad END), MAX(CASE WHEN rn = 2 THEN cod_dane_departamento END), MAX(CASE WHEN rn = 2 THEN direccion END), MAX(CASE WHEN rn = 2 THEN tipo END), MAX(CASE WHEN rn = 2 THEN zona END), MAX(CASE WHEN rn = 2 THEN estrato END), MAX(CASE WHEN rn = 2 THEN TO_CHAR(fecha_ultima_actualizacion, 'DD/MM/YYYY') END), MAX(CASE WHEN rn = 2 THEN CAST(numero_de_entidades_reporta AS VARCHAR(10)) END), MAX(CASE WHEN rn = 2 THEN CAST(por_sim_dir AS VARCHAR(30)) END)
    FROM (
        SELECT d.*,
               ROW_NUMBER() OVER (PARTITION BY d.id_buro_persona ORDER BY d.orden_prioridad) AS rn
        FROM rec_stage.batch_cubo_direccion d
        INNER JOIN rec_stage.batch_cubo_persona p
                ON p.id_buro_persona = d.id_buro_persona
        WHERE p.id_solicitud = p_id_solicitud
          AND (p_id_plantilla IS NULL OR p.id_plantilla = p_id_plantilla)
    ) x
    WHERE rn <= 2   -- ampliar segun 04_tablas_pivote.sql
    GROUP BY id_buro_persona;

    ------------------------------------------------------------------
    -- CORREO
    ------------------------------------------------------------------
    TRUNCATE TABLE rec_stage.w_cubo_correo;

    INSERT INTO rec_stage.w_cubo_correo
    SELECT
        id_buro_persona,
        MIN(filtro_h),
        MAX(CASE WHEN rn = 1 THEN correo END), MAX(CASE WHEN rn = 1 THEN numero END),
        MAX(CASE WHEN rn = 2 THEN correo END), MAX(CASE WHEN rn = 2 THEN numero END)
    FROM (
        SELECT c.*,
               ROW_NUMBER() OVER (PARTITION BY c.id_buro_persona ORDER BY c.orden_prioridad) AS rn
        FROM rec_stage.batch_cubo_correo c
        INNER JOIN rec_stage.batch_cubo_persona p
                ON p.id_buro_persona = c.id_buro_persona
        WHERE p.id_solicitud = p_id_solicitud
          AND (p_id_plantilla IS NULL OR p.id_plantilla = p_id_plantilla)
    ) x
    WHERE rn <= 2   -- ampliar segun 04_tablas_pivote.sql
    GROUP BY id_buro_persona;

    ------------------------------------------------------------------
    -- CIIU
    ------------------------------------------------------------------
    TRUNCATE TABLE rec_stage.w_cubo_ciiu;

    INSERT INTO rec_stage.w_cubo_ciiu
    SELECT
        id_buro_persona,
        MIN(filtro_h),
        MAX(CASE WHEN rn = 1 THEN ciiu END), MAX(CASE WHEN rn = 1 THEN actividad_economica END)
    FROM (
        SELECT ci.*,
               ROW_NUMBER() OVER (PARTITION BY ci.id_buro_persona ORDER BY ci.orden_prioridad) AS rn
        FROM rec_stage.batch_cubo_ciiu ci
        INNER JOIN rec_stage.batch_cubo_persona p
                ON p.id_buro_persona = ci.id_buro_persona
        WHERE p.id_solicitud = p_id_solicitud
          AND (p_id_plantilla IS NULL OR p.id_plantilla = p_id_plantilla)
    ) x
    WHERE rn = 1
    GROUP BY id_buro_persona;

    RAISE INFO 'sp_batch2_cubo_export: pivote completado para id_solicitud=%, id_plantilla=%', p_id_solicitud, p_id_plantilla;
END;
$$;
