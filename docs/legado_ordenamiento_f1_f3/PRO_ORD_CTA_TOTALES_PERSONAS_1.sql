REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CTA_TOTALES_PERSONAS_1
     (
		 IN	P_Lote							INTEGER
		,IN	P_StartTimeStampPadre		VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
		,IN	P_BDDATOS					VARCHAR(20)
		,IN	P_BDVISTA						VARCHAR(20)
		,IN	P_BDSTAGE					VARCHAR(20)
		,IN	P_BTTDATOS					VARCHAR(20)
		,IN	P_BTTVISTA					VARCHAR(20)
		,IN	P_BDMTDAT					VARCHAR(20)
		,IN	P_BTTMTDAT					VARCHAR(20)
		,IN P_VARQUERY	/*#1*/			VARCHAR (500)
		,OUT P_ERROR						VARCHAR(50)
	)
/* ################################################################################
 * 
 * Objetivo:	Materializacin tablas BTT y Reconocer Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por: Experian
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Cuenta totales personas. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 *  2019-01-19  #5 Optimizar SP       Experian - Fernando Garrido M.
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2017 Fabrica Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */

 
 /* ###############################################################################
 *                                 METADATA TABLAS RECONOCER
 * 
 * ################################################################################
 */

-- inicia reconocer Calculando los lotes para el Modelo Reconocer


BEGIN
	

	------------------------
	-- Declaracion de variables
	------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_TABLE			VARCHAR(30);
	DECLARE Temp CHAR(30);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:	BEGIN

----------------------------------------------------
	-- Busca la tabla TMP_COMPORTAMIENTO_ACTIVO
	----------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_COMPORTAMIENTO_ACTIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	----------------------------------------------------
	-- Se borra la tabla TMP_COMPORTAMIENTO_ACTIVO si existe
	----------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_COMPORTAMIENTO_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;

	----------------------------------------------------------------------------------------
	-- Step 1: Calculando las cuentas totales de las personas. TMP_COMPORTAMIENTO_ACTIVO alias paso7
	----------------------------------------------------------------------------------------
   SET V_CADENA = ' ';

   SET V_CADENA= 'create multiset table '||P_BDSTAGE || '.TMP_COMPORTAMIENTO_ACTIVO as 
					(
					select 	a.cod_dw_cta
								,Valor_Inicial
								,Valor_Cuota_Mensual
								,Valor_Saldo
								,Numero_Dias_Mora
								,Valor_Saldo_Mora
								,Num_Cuotas_Pagadas
								,Valor_Disponible
								,Num_Cuotas_Mora
								,Num_Cuotas_Pactadas
								,a.Fecha_Nov
								, CASE WHEN a.cod_dw_cta IS NOT NULL THEN ''Y'' ELSE ''N'' END Flag_Comp_Cta_Activo
								,a.cod_altura_mora_fte
					from  '||P_BDSTAGE || '.TMP_CNTA_FECHAS b
					inner join '||P_BTTVISTA||'.vu_comportamiento_cta_Activo a
					ON a.cod_dw_cta=b.cod_dw_cta 
					AND a.fecha_nov between b.fecha_nov_ini and b.fecha_nov
					)
					with data
					primary index(cod_dw_cta);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS_1(1):Calculando las cuentas totales de las personas.TMP_COMPORTAMIENTO_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	-----------------------------------------------------------
	-- RECOLECCION DE ESTADISTICAS 	TMP_COMPORTAMIENTO_ACTIVO	
	-----------------------------------------------------------
		
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS INDEX(cod_dw_cta),column(cod_dw_cta,fecha_nov) on  '||P_BDSTAGE||'.TMP_COMPORTAMIENTO_ACTIVO ;';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS_1(1.1):RECOLECCION DE ESTADISTICAS TMP_COMPORTAMIENTO_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
		
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	

   ---------------------------
   -- Busca la tabla STG_COMPORTAMIENTO_CTA_ACTIVO
   ---------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'STG_COMPORTAMIENTO_CTA_ACTIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	 -----------------------------
	 -- Se borra la tabla STG_COMPORTAMIENTO_CTA_ACTIVO si existe
     -----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.STG_COMPORTAMIENTO_CTA_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);    
		
	END IF;
	
	
   -- Step 2: Construccin tablas precalculadas para CTA ACTIVO Y PASIVO.

    SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE || '.STG_COMPORTAMIENTO_CTA_ACTIVO
					AS 
					(SEL	a.cod_dw_cta
								,Valor_Inicial
								,Valor_Cuota_Mensual
								,Valor_Saldo
								,Numero_Dias_Mora
								,Valor_Saldo_Mora
								,Num_Cuotas_Pagadas
								,Valor_Disponible
								,Num_Cuotas_Mora
								,Num_Cuotas_Pactadas
								,a.Fecha_Nov
								,a.Flag_Comp_Cta_Activo
					FROM '||P_BDSTAGE || '.TMP_COMPORTAMIENTO_ACTIVO a 
					INNER  JOIN '||P_BDSTAGE || '.CTA_TOTALES_PERSONAS_TMP1 b
					ON a.Fecha_Nov = b.Fecha_Nov 
					AND a.cod_dw_cta= b.cod_dw_cta
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Cta );';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_ORD_CTA_TOTALES_PERSONAS_1(2):Construccin tablas precalculadas para STG_COMPORTAMIENTO_CTA_ACTIVO.'
										,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	-----------------------------------------
	-- RECOLECCION DE ESTADISTICAS 	TMP_COMPORTAMIENTO_ACTIVO	
	-----------------------------------------
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Cta),column(Cod_DW_Cta ,Fecha_Nov) on  '||P_BDSTAGE||'.STG_COMPORTAMIENTO_CTA_ACTIVO ;';
				
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'PRO_ORD_CTA_TOTALES_PERSONAS_1(2.1):RECOLECCION DE ESTADISTICAS STG_COMPORTAMIENTO_CTA_ACTIVO'
				,V_ERROR);
				
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;			   
	   
 END L1;	
END;

