-- ============================================================================
--  VALIDACION DE INVENTARIO - calculo Reconocer (SLCOPRBA-1353 + SLCOPRBA-1820)
--  Se ejecuta DESPUES de las carpetas 01 a 05, en la misma base y usuario.
--  Resultado esperado: esperados = 273, faltantes = 0, titular COMPLETO.
-- ============================================================================

-- ---------------------------------------------------------------- CONSULTA 1
-- Redshift NO admite VALUES como constructor de tabla (es de PostgreSQL):
-- 42601 syntax error at or near "VALUES". Se arma con SELECT ... UNION ALL,
-- y el CAST de la PRIMERA rama fija el tipo del nodo (trampa ya documentada).
WITH esperado AS (
  SELECT 'TABLA'::VARCHAR(10) AS tipo, 'bdm_datos'::VARCHAR(64) AS esquema, 'beta_ordenamiento'::VARCHAR(128) AS objeto
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_fuente'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_fuente_dato'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_gestion_registro'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_hom_ind_mov'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_hom_tipo_ident'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_hom_tipo_pto_int'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_indicador_movilidad'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_operador_ord_cel'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_portafolio_prefijo'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_portafolio_ve'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_razon_bloqueo'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_sector_financiero'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_tipo_cuenta_ord'
  UNION ALL SELECT 'TABLA','bdm_datos','catalogo_tipo_cuenta_tel'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_criterio'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_criterio_nov'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_criterio_ord'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_resultado'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_resultado_nov'
  UNION ALL SELECT 'TABLA','bdm_datos','cert_resultado_ord'
  UNION ALL SELECT 'TABLA','bdm_datos','cuenta_atributo_hash'
  UNION ALL SELECT 'TABLA','bdm_datos','cuenta_atributo_hash_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','direccion_fisica_generada'
  UNION ALL SELECT 'TABLA','bdm_datos','direccion_fisica_generada_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_atributos'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_atributos_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_config'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_config_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_distancias'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_distancias_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_lote_control'
  UNION ALL SELECT 'TABLA','bdm_datos','geo_lote_control_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_actividad_economica'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_actividad_economica_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_basica'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_basica_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_contactabilidad'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_contactabilidad_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_movilidad'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_movilidad_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_punto_interes'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_punto_interes_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_ubicacion'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_info_ubicacion_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_ubicacion_agregada'
  UNION ALL SELECT 'TABLA','bdm_datos','mat_ubicacion_agregada_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','nomenclatura'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_config'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_control'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_control_etapa'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_control_etapa_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_control_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_export_control'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_movilidad_foto'
  UNION ALL SELECT 'TABLA','bdm_datos','nov_movilidad_foto_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','ord_alcance_censo'
  UNION ALL SELECT 'TABLA','bdm_datos','ord_control'
  UNION ALL SELECT 'TABLA','bdm_datos','ord_control_etapa'
  UNION ALL SELECT 'TABLA','bdm_datos','relacion_persona_ubicacion'
  UNION ALL SELECT 'TABLA','bdm_datos','rpu_generada'
  UNION ALL SELECT 'TABLA','bdm_datos','rpu_generada_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','rpu_orden_prioridad'
  UNION ALL SELECT 'TABLA','bdm_datos','score_ordenamiento'
  UNION ALL SELECT 'TABLA','bdm_datos','tipo_ubicacion_dir'
  UNION ALL SELECT 'TABLA','bdm_datos','ubicacion_atributo_hash'
  UNION ALL SELECT 'TABLA','bdm_datos','ubicacion_atributo_hash_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_alcance_censo'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_alcance_censo_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_control'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_control_etapa'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_control_etapa_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_control_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_escenario_censo'
  UNION ALL SELECT 'TABLA','bdm_datos','unif_escenario_censo_mock'
  UNION ALL SELECT 'TABLA','bdm_datos','unificacion_direccion'
  UNION ALL SELECT 'TABLA','bdm_datos','unificacion_direccion_mock'
  UNION ALL SELECT 'TABLA','bdm_stage','ciiu_persona'
  UNION ALL SELECT 'TABLA','bdm_stage','contacto_canal'
  UNION ALL SELECT 'TABLA','bdm_stage','diccionario_complementos'
  UNION ALL SELECT 'TABLA','bdm_stage','diccionario_via'
  UNION ALL SELECT 'TABLA','bdm_stage','direccion_fisica'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_geo_distancias'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_geo_respuesta'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_ord_alcance_censo'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_ord_ca_result'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_ord_control'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_ord_control_etapa'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_ord_prioridad'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_unif_ca_result'
  UNION ALL SELECT 'TABLA','bdm_stage','mock_unif_convergencia'
  UNION ALL SELECT 'TABLA','bdm_stage','nomenclatura'
  UNION ALL SELECT 'TABLA','bdm_stage','reporte_relacion_persona_ubica'
  UNION ALL SELECT 'TABLA','bdm_stage','tipo_ubicacion_dir'
  UNION ALL SELECT 'TABLA','bdm_stage','ubicacion_estandarizada'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_acteco_etapa_1'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_acteco_etapa_1_mock'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubiagr_etapa_final'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubiagr_etapa_final_mock'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubica_etapa_2'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubica_etapa_2_mock'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubica_etapa_9'
  UNION ALL SELECT 'TABLA','bdm_tempo','stg_nov_ubica_etapa_9_mock'
  UNION ALL SELECT 'VISTA','bdm_datos','insumo_celular'
  UNION ALL SELECT 'VISTA','bdm_datos','insumo_direccion'
  UNION ALL SELECT 'VISTA','bdm_datos','insumo_email'
  UNION ALL SELECT 'VISTA','bdm_datos','insumo_telefono'
  UNION ALL SELECT 'VISTA','bdm_datos','v_cert_nov_ultimo'
  UNION ALL SELECT 'VISTA','bdm_datos','v_cert_ord_ultimo'
  UNION ALL SELECT 'VISTA','bdm_datos','v_cert_ultimo'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_actividad_economica_persona'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_ciiu_persona'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_comportamiento_cta'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_contacto_canal'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_contacto_direccion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_cuenta'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_direccion_fisica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_persona_basica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_relacion_persona_ubicacion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_reporte_relacion_persona_ubica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_rpu_post_unificacion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_mock_ubicacion_estandarizada'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_relacion_persona_ubicacion_ord'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_rpu_post_unificacion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_actividad_economica_persona'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_ciiu_persona'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_comportamiento_cta'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_contacto_canal'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_contacto_direccion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_cuenta'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_cuenta_bloqueada'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_direccion_fisica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_persona_basica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_persona_dir_ganadora'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_relacion_persona_ubicacion'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_reporte_relacion_persona_ubica'
  UNION ALL SELECT 'VISTA','bdm_tempo','v_xpm_ubicacion_estandarizada'
  UNION ALL SELECT 'RUTINA','bdm_datos','convert_epoch_to_date'
  UNION ALL SELECT 'RUTINA','bdm_datos','fn_novedades_dominio_json'
  UNION ALL SELECT 'RUTINA','bdm_datos','fw_resolver_param'
  UNION ALL SELECT 'RUTINA','bdm_datos','nov_control_mock_abrir'
  UNION ALL SELECT 'RUTINA','bdm_datos','nov_control_mock_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','nov_control_mock_etapa_marcar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_cert_asercion_final'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_cert_evaluar_criterios_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_cert_evaluar_criterios_nov_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_cert_evaluar_criterios_ord_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_cert_geo_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_cargar_distancias'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_cargar_distancias_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_cargar_georreferenciacion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_cargar_georreferenciacion_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_ciclo_lote'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_exportar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_exportar_insumo_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_reenganchar_r3'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_reenganchar_r3_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_simular_arcgis_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_geo_simular_distancias_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_mock_ciclo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_actividad_economica_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_actividad_economica_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_acteco_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_acteco_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_ubi_agregada_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_ubi_agregada_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_ubicacion_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_cargar_mat_ubicacion_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_ciclo_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_contactabilidad_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_contactabilidad_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_exportar_7_tablas'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_info_basica_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_info_basica_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_mock_ciclo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_movilidad_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_movilidad_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_punto_interes_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_punto_interes_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_ubi_agregada_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_ubi_agregada_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_ubicacion_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_ubicacion_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_novedades_unload_una'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_ciclo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_consolidacion_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_cuentas_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_cuentas_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_drop_staging_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_ejecucion_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_ejecucion_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_preparar_insumos_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_preparar_insumos_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_scoring_cel_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_scoring_dir_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_scoring_ema_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_scoring_tel_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_ubicaciones_edf'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_ordenamiento_ubicaciones_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_nov_abrir'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_nov_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_nov_etapa_marcar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_nov_migrar_info_basica'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_obs_migrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_ord_abrir'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_ord_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_ord_migrar_canal'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_ord_traza_fin'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_ord_traza_inicio'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_unif_abrir'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_unif_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_unif_traza_fin'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_ctl_unif_traza_inicio'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_geo_02_buscar_resultados'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_rcn_geo_02_buscar_resultados_mock'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unif_gate_convergencia_evaluar'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unif_gate_convergencia_snapshot'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_ciclo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_cleanup'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_ciclo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_gate_arq'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r1_esc1_ciiu10_mismo_texto_padre_lab_crr'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r1_esc2_ciiu81_90_mismo_texto_padre_res_crr'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r1_esc3_otros_ciiu_mayor_entidades_reportan'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r1_preparar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_construir_diccionario_complementos'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_esc1_complemento_vacio_esc2_substring_complemento'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_esc3_sin_nit_misma_nomenclatura'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_esc4_diccionario_frecuencia_complemento'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_esc5_nomenclatura_menor_nivel_pierde'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_esc6_frecuencia_complemento_gana'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_motor_cruce_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_motor_dif_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_motor_nit_empates_nuevas_direcciones'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_motor_nivel_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r2_preparar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_r3_esc1_geo_misma_via_puerta_cercana'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_regla1'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_regla2'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_mock_regla3'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r1_esc1_ciiu10_mismo_texto_padre_lab_crr'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r1_esc2_ciiu81_90_mismo_texto_padre_res_crr'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r1_esc3_otros_ciiu_mayor_entidades_reportan'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r1_preparar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_construir_diccionario_complementos'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_esc1_complemento_vacio_esc2_substring_complemento'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_esc3_sin_nit_misma_nomenclatura'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_esc4_diccionario_frecuencia_complemento'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_esc5_nomenclatura_menor_nivel_pierde'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_esc6_frecuencia_complemento_gana'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_motor_cruce_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_motor_dif_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_motor_nit_empates_nuevas_direcciones'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_motor_nivel_nueva_direccion'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r2_preparar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_r3_esc1_geo_misma_via_puerta_cercana'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_regla1'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_regla2'
  UNION ALL SELECT 'RUTINA','bdm_datos','sp_unificacion_regla3'
  UNION ALL SELECT 'RUTINA','bdm_datos','unif_control_mock_abrir'
  UNION ALL SELECT 'RUTINA','bdm_datos','unif_control_mock_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_datos','unif_resolver_param'
  UNION ALL SELECT 'RUTINA','bdm_datos','unif_traza_mock_fin'
  UNION ALL SELECT 'RUTINA','bdm_datos','unif_traza_mock_inicio'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_geo_ciclo_lote'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_geo_exportar_insumo'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_geo_reenganchar_r3'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_cerrar'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_preparar'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_scoring_cel'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_scoring_dir'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_scoring_ema'
  UNION ALL SELECT 'RUTINA','bdm_stage','sp_ordenamiento_scoring_tel'
),
real_ AS (
  SELECT 'TABLA'::VARCHAR(10) AS tipo, schemaname::VARCHAR(64) AS esquema, tablename::VARCHAR(128) AS objeto
    FROM pg_tables  WHERE schemaname IN ('bdm_datos','bdm_tempo','bdm_stage')
  UNION ALL
  SELECT 'VISTA', schemaname::VARCHAR(64), viewname::VARCHAR(128)
    FROM pg_views   WHERE schemaname IN ('bdm_datos','bdm_tempo','bdm_stage')
  UNION ALL
  SELECT 'RUTINA', n.nspname::VARCHAR(64), p.proname::VARCHAR(128)
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('bdm_datos','bdm_tempo','bdm_stage')
),
cruce AS (
  SELECT e.tipo, e.esquema, e.objeto,
         CASE WHEN r.objeto IS NULL THEN 'FALTANTE' ELSE 'OK' END AS estado
    FROM esperado e
    LEFT JOIN real_ r ON r.tipo = e.tipo AND r.esquema = e.esquema AND r.objeto = e.objeto
)
SELECT 1 AS orden, 'RESUMEN' AS seccion, tipo AS detalle,
       COUNT(*) AS esperados, SUM(CASE WHEN estado = 'FALTANTE' THEN 1 ELSE 0 END) AS faltantes
  FROM cruce GROUP BY tipo
UNION ALL
SELECT 2, 'FALTANTE', esquema || '.' || objeto || '  (' || tipo || ')', NULL, NULL
  FROM cruce WHERE estado = 'FALTANTE'
UNION ALL
SELECT 3, 'TITULAR',
       CASE WHEN SUM(CASE WHEN estado = 'FALTANTE' THEN 1 ELSE 0 END) = 0
            THEN 'COMPLETO - el calculo Reconocer y el exportador tienen todos sus objetos'
            ELSE 'INCOMPLETO - faltan objetos, ver las filas FALTANTE' END,
       COUNT(*), SUM(CASE WHEN estado = 'FALTANTE' THEN 1 ELSE 0 END)
  FROM cruce
ORDER BY orden, detalle;

-- ---------------------------------------------------------------- CONSULTA 2
-- Los catalogos de parametrizacion tienen que traer FILAS, no solo existir.
SELECT 'bdm_datos.beta_ordenamiento' AS catalogo, COUNT(*) AS filas FROM bdm_datos.beta_ordenamiento UNION ALL
SELECT 'bdm_datos.catalogo_fuente' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_fuente UNION ALL
SELECT 'bdm_datos.catalogo_fuente_dato' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_fuente_dato UNION ALL
SELECT 'bdm_datos.catalogo_gestion_registro' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_gestion_registro UNION ALL
SELECT 'bdm_datos.catalogo_hom_ind_mov' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_hom_ind_mov UNION ALL
SELECT 'bdm_datos.catalogo_hom_tipo_ident' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_hom_tipo_ident UNION ALL
SELECT 'bdm_datos.catalogo_hom_tipo_pto_int' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_hom_tipo_pto_int UNION ALL
SELECT 'bdm_datos.catalogo_indicador_movilidad' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_indicador_movilidad UNION ALL
SELECT 'bdm_datos.catalogo_operador_ord_cel' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_operador_ord_cel UNION ALL
SELECT 'bdm_datos.catalogo_portafolio_prefijo' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_portafolio_prefijo UNION ALL
SELECT 'bdm_datos.catalogo_portafolio_ve' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_portafolio_ve UNION ALL
SELECT 'bdm_datos.catalogo_razon_bloqueo' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_razon_bloqueo UNION ALL
SELECT 'bdm_datos.catalogo_tipo_cuenta_ord' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_tipo_cuenta_ord UNION ALL
SELECT 'bdm_datos.catalogo_tipo_cuenta_tel' AS catalogo, COUNT(*) AS filas FROM bdm_datos.catalogo_tipo_cuenta_tel UNION ALL
SELECT 'bdm_datos.cert_criterio' AS catalogo, COUNT(*) AS filas FROM bdm_datos.cert_criterio UNION ALL
SELECT 'bdm_datos.cert_criterio_nov' AS catalogo, COUNT(*) AS filas FROM bdm_datos.cert_criterio_nov UNION ALL
SELECT 'bdm_datos.cert_criterio_ord' AS catalogo, COUNT(*) AS filas FROM bdm_datos.cert_criterio_ord UNION ALL
SELECT 'bdm_datos.geo_config' AS catalogo, COUNT(*) AS filas FROM bdm_datos.geo_config UNION ALL
SELECT 'bdm_datos.geo_config_mock' AS catalogo, COUNT(*) AS filas FROM bdm_datos.geo_config_mock UNION ALL
SELECT 'bdm_datos.nomenclatura' AS catalogo, COUNT(*) AS filas FROM bdm_datos.nomenclatura UNION ALL
SELECT 'bdm_datos.nov_config' AS catalogo, COUNT(*) AS filas FROM bdm_datos.nov_config UNION ALL
SELECT 'bdm_datos.tipo_ubicacion_dir' AS catalogo, COUNT(*) AS filas FROM bdm_datos.tipo_ubicacion_dir UNION ALL
SELECT 'bdm_stage.tipo_ubicacion_dir' AS catalogo, COUNT(*) AS filas FROM bdm_stage.tipo_ubicacion_dir;

-- ---------------------------------------------------------------- CONSULTA 3
-- Las siete tablas de dominio y la traza del exportador.
SELECT 'mat_info_ubicacion' AS tabla, COUNT(*) AS filas FROM bdm_datos.mat_info_ubicacion
UNION ALL SELECT 'mat_info_contactabilidad',     COUNT(*) FROM bdm_datos.mat_info_contactabilidad
UNION ALL SELECT 'mat_ubicacion_agregada',       COUNT(*) FROM bdm_datos.mat_ubicacion_agregada
UNION ALL SELECT 'mat_info_basica',              COUNT(*) FROM bdm_datos.mat_info_basica
UNION ALL SELECT 'mat_info_actividad_economica', COUNT(*) FROM bdm_datos.mat_info_actividad_economica
UNION ALL SELECT 'mat_info_punto_interes',       COUNT(*) FROM bdm_datos.mat_info_punto_interes
UNION ALL SELECT 'mat_info_movilidad',           COUNT(*) FROM bdm_datos.mat_info_movilidad;

SELECT run_id, ambiente, modo, estado, filas_totales, watermark_anterior, watermark_nuevo
  FROM bdm_datos.nov_export_control ORDER BY 1 DESC LIMIT 5;
