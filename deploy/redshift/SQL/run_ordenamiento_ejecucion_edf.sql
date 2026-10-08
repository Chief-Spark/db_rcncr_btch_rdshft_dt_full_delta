-- Orquestador DT — ordenamiento post-unificacion (apunta al ciclo FULL/DELTA)
-- Default FULL; la malla parametrizada usa run_ordenamiento_full/delta.
CALL bdm_datos.sp_ordenamiento_ciclo(CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('' AS VARCHAR(256)), CAST('FULL' AS VARCHAR(256)), CAST('1356001' AS VARCHAR(256)), CAST('' AS VARCHAR(256)));
