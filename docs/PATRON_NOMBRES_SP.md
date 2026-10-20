# Patrón de nombres de los SP de Reconocer (vía real)

Aprobado el 2026-10-20 (plan `PLAN_RECONOCER_DESDE_DOWNSTREAM.md` §7).

**Alcance:** se renombran **solo los SP de la vía real**. El mock conserva sus nombres; la columna "Mock" dice cuál es su espejo. Las funciones (`fw_resolver_param`, `unif_resolver_param`) **no cambian**: `fw_resolver_param` es parte del contrato con el Framework.

## La regla

```
sp_rcn_<proceso>_<fase>_<nn>_<que_hace>
```

| Parte | Valores | Para qué |
|---|---|---|
| `rcn` | fijo | Reconocer. Distingue nuestros objetos de los de otros procesos en `bdm_datos` |
| `<proceso>` | `unif` · `geo` · `ord` · `nov` · `ctl` | el proceso dueño |
| `<fase>` | `r1` `r2` `r3` (reglas) · `f1` `f2` `f3` `sc` (Ordenamiento) · `d1`..`d7` (dominios de Novedades) | la etapa de negocio |
| `<nn>` | `00` preparar · `01`..`89` en orden de ejecución · `99` limpiar | **el número es el orden**. En la cascada R2 cambiar el orden cambia el resultado, por eso queda escrito en el nombre |
| `<que_hace>` | minúsculas, corto, sin artículos | la lógica del paso; en R2 lleva el sello del escenario (`l3`, `x4`, …) |

Además:
- **Entradas del Framework** (los 6 `VARCHAR`): `sp_rcn_<proceso>_ciclo`. Son las únicas que el Framework puede llamar.
- **Orquestador de una regla o fase:** `sp_rcn_<proceso>_<fase>`, sin número.
- **Control y traza:** `sp_rcn_ctl_<proceso>_<acción>`.

**Reglas del renombrado:**
1. Las **firmas no cambian**.
2. Cada renombre lleva su `DROP PROCEDURE <viejo>(<firma exacta>)` en `RevSQL/` y su línea en los dos `.par`.
3. **Los SP que comparte el mock** (los 4 de scoring, la consolidación y la limpieza) se renombran; en el mock solo cambia la línea del `CALL`.
4. Los nombres de **etapa** en las tablas de traza (`'preparar'`, `'scoring_dir'`, …) no cambian: son datos y los leen los criterios.

## Equivalencias

### Entradas del Framework (6 `VARCHAR`)

| Hoy | Nuevo | Mock |
|---|---|---|
| `bdm_datos.sp_unificacion_ciclo` | `bdm_datos.sp_rcn_unif_ciclo` | `sp_unificacion_mock_ciclo` |
| `bdm_datos.sp_ordenamiento_ciclo` | `bdm_datos.sp_rcn_ord_ciclo` | `sp_ordenamiento_ejecucion_mock` |
| `bdm_datos.sp_novedades_ciclo_edf` | `bdm_datos.sp_rcn_nov_ciclo` | `sp_novedades_mock_ciclo` |
| `bdm_stage.sp_geo_ciclo_lote` (envoltorio) | `bdm_datos.sp_rcn_geo_ciclo` | — |
| `bdm_stage.sp_geo_exportar_insumo` (envoltorio) | `bdm_datos.sp_rcn_geo_exportar_ciclo` | — |
| `bdm_stage.sp_geo_reenganchar_r3` (envoltorio) | `bdm_datos.sp_rcn_geo_reenganchar_ciclo` | — |

**Los envoltorios GEO cambian de esquema (`bdm_stage` → `bdm_datos`).** Hoy tienen el **mismo nombre** que los SP internos de `bdm_datos`, con otra firma, y eso confunde. Al pasar a `sp_rcn_geo_*_ciclo` quedan junto a las otras entradas.

### Unificación

| Hoy (`bdm_datos.`) | Nuevo | Sello | Mock |
|---|---|---|---|
| `sp_unificacion_regla1` | `sp_rcn_unif_r1` | — | `sp_unificacion_mock_regla1` |
| `sp_unificacion_r1_preparar_insumo` | `sp_rcn_unif_r1_00_preparar` | — | `sp_unificacion_mock_r1_preparar_insumo` |
| `sp_unificacion_r1_esc1_ciiu10_mismo_texto_padre_lab_crr` | `sp_rcn_unif_r1_01_ciiu10_mismo_texto` | — | `…mock_r1_esc1_…` |
| `sp_unificacion_r1_esc2_ciiu81_90_mismo_texto_padre_res_crr` | `sp_rcn_unif_r1_02_ciiu81_90_mismo_texto` | — | `…mock_r1_esc2_…` |
| `sp_unificacion_r1_esc3_otros_ciiu_mayor_entidades_reportan` | `sp_rcn_unif_r1_03_otros_ciiu_mas_entidades` | — | `…mock_r1_esc3_…` |
| `sp_unificacion_regla2` | `sp_rcn_unif_r2` | — | `sp_unificacion_mock_regla2` |
| `sp_unificacion_r2_preparar_insumo` | `sp_rcn_unif_r2_00_preparar` | — | `…mock_r2_preparar_insumo` |
| `sp_unificacion_r2_construir_diccionario_complementos` | `sp_rcn_unif_r2_01_diccionario_complementos` | — | `…mock_r2_construir_…` |
| `sp_unificacion_r2_esc1_complemento_vacio_esc2_substring_complemento` | `sp_rcn_unif_r2_02_h1k2_complemento_vacio_substring` | H1, K2 | `…mock_r2_esc1_…` |
| `sp_unificacion_r2_esc3_sin_nit_misma_nomenclatura` | `sp_rcn_unif_r2_03_l3_sin_nit_misma_nomenclatura` | L3 | `…mock_r2_esc3_…` |
| `sp_unificacion_r2_motor_nit_empates_nuevas_direcciones` | `sp_rcn_unif_r2_04_x4_motor_nit_empates` | X4 | `…mock_r2_motor_nit_…` |
| `sp_unificacion_r2_esc4_diccionario_frecuencia_complemento` | `sp_rcn_unif_r2_05_b5_diccionario_frecuencia` | B5 | `…mock_r2_esc4_…` |
| `sp_unificacion_r2_motor_nivel_nueva_direccion` | `sp_rcn_unif_r2_06_a6_motor_nivel` | A6 | `…mock_r2_motor_nivel_…` |
| `sp_unificacion_r2_motor_dif_nueva_direccion` | `sp_rcn_unif_r2_07_d9_motor_dif` | D9 | `…mock_r2_motor_dif_…` |
| `sp_unificacion_r2_esc5_nomenclatura_menor_nivel_pierde` | `sp_rcn_unif_r2_08_c7_nomenclatura_menor_nivel` | C7 | `…mock_r2_esc5_…` |
| `sp_unificacion_r2_motor_cruce_nueva_direccion` | `sp_rcn_unif_r2_09_a8_motor_cruce` | A8 | `…mock_r2_motor_cruce_…` |
| `sp_unificacion_r2_esc6_frecuencia_complemento_gana` | `sp_rcn_unif_r2_10_e6_frecuencia_complemento_gana` | E6 | `…mock_r2_esc6_…` |
| `sp_unificacion_regla3` | `sp_rcn_unif_r3` | — | `sp_unificacion_mock_regla3` |
| `sp_unificacion_r3_esc1_geo_misma_via_puerta_cercana` | `sp_rcn_unif_r3_01_geo_misma_via_puerta` | — | `…mock_r3_esc1_…` |
| `sp_unificacion_cleanup` | **se retira**: nadie lo llama y solo trunca | — | — |

### GEO (internos)

| Hoy (`bdm_datos.`) | Nuevo | Mock |
|---|---|---|
| `sp_geo_exportar_insumo` | `sp_rcn_geo_01_exportar` | `sp_geo_exportar_insumo_mock` |
| `sp_geo_cargar_georreferenciacion` | `sp_rcn_geo_02_cargar_georef` | `sp_geo_cargar_georreferenciacion_mock` |
| `sp_geo_cargar_distancias` | `sp_rcn_geo_03_cargar_distancias` | — |
| `sp_geo_reenganchar_r3` | `sp_rcn_geo_04_reenganchar_r3` | `sp_geo_reenganchar_r3_mock` |
| `sp_geo_ciclo_lote` | `sp_rcn_geo_ciclo_lote` (lo llama `sp_rcn_geo_ciclo`) | — |

### Ordenamiento

| Hoy (`bdm_datos.`) | Nuevo | Mock |
|---|---|---|
| `sp_ordenamiento_preparar_insumos_edf` | `sp_rcn_ord_f1_alcance` | `sp_ordenamiento_preparar_insumos_mock` |
| `sp_ordenamiento_cuentas_edf` | `sp_rcn_ord_f2_cuentas` | `sp_ordenamiento_cuentas_mock` |
| `sp_ordenamiento_ubicaciones_edf` | `sp_rcn_ord_f3_ubicaciones` | `sp_ordenamiento_ubicaciones_mock` |
| `sp_ordenamiento_scoring_dir_edf` | `sp_rcn_ord_sc_01_dir` | **compartido** |
| `sp_ordenamiento_scoring_tel_edf` | `sp_rcn_ord_sc_02_tel` | **compartido** |
| `sp_ordenamiento_scoring_cel_edf` | `sp_rcn_ord_sc_03_cel` | **compartido** |
| `sp_ordenamiento_scoring_ema_edf` | `sp_rcn_ord_sc_04_ema` | **compartido** |
| `sp_ordenamiento_consolidacion_edf` | `sp_rcn_ord_sc_05_consolidar` | **compartido** |
| `sp_ordenamiento_drop_staging_edf` | `sp_rcn_ord_99_limpiar` | **compartido** |
| `sp_ordenamiento_ejecucion_edf` | **se retira**: nadie lo llama y está roto (no corre F2 ni F3) | — |

### Novedades

| Hoy (`bdm_datos.`) | Nuevo | Mock |
|---|---|---|
| `sp_novedades_ubicacion_edf` / `sp_novedades_cargar_mat_ubicacion_edf` | `sp_rcn_nov_d1_ubicacion_calcular` / `_cargar` | `sp_novedades_ubicacion_mock` / `…cargar_mat_ubicacion_mock` |
| `sp_novedades_actividad_economica_edf` / `…cargar_mat_acteco_edf` | `sp_rcn_nov_d2_actividad_economica_calcular` / `_cargar` | `…_mock` |
| `sp_novedades_ubi_agregada_edf` / `…cargar_mat_ubi_agregada_edf` | `sp_rcn_nov_d3_ubicacion_agregada_calcular` / `_cargar` | `…_mock` |
| (por portar) | `sp_rcn_nov_d4_info_basica_*`, `d5_contactabilidad_*`, `d6_movilidad_*`, `d7_punto_interes_*` | — |

### Control y traza

| Hoy (`bdm_datos.`) | Nuevo | Mock |
|---|---|---|
| `unif_control_abrir` / `_cerrar` | `sp_rcn_ctl_unif_abrir` / `_cerrar` | `unif_control_mock_abrir` / `_cerrar` |
| `unif_traza_inicio` / `_fin` | `sp_rcn_ctl_unif_traza_inicio` / `_fin` | `unif_traza_mock_inicio` / `_fin` |
| `ord_control_abrir` / `_cerrar` | `sp_rcn_ctl_ord_abrir` / `_cerrar` | (en línea dentro del mock) |
| `ord_traza_inicio` / `_fin` | `sp_rcn_ctl_ord_traza_inicio` / `_fin` | (en línea) |
| `nov_control_abrir` / `_cerrar` / `_etapa_marcar` | `sp_rcn_ctl_nov_abrir` / `_cerrar` / `_etapa_marcar` | `nov_control_mock_*` |

## Impacto fuera de este repo

- **Framework (`tf_fw_dynbtch_chief`)**: el YAML de Reconocer debe llamar las entradas nuevas, en tres niveles:

  ```
  sp_rcn_unif_ciclo → sp_rcn_ord_ciclo → sp_rcn_nov_ciclo
  ```

  `sp_rcn_geo_ciclo` corre aparte, cuando ArcGIS responda. **El `PP9999999.yml` actual ya está roto**: lleva `()` en `step_procedure` y apunta a un SP que no existe. Se corrige en ese repo, que no es nuestro.
- **Runners de `dt`** (`run_*.sql`, validaciones): se actualizan en el mismo commit que el renombre.
