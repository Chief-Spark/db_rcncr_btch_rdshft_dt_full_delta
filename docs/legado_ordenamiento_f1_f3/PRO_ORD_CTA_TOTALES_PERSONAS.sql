REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CTA_TOTALES_PERSONAS
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
 * Fecha:		2019-01-14
 * Lider Tecnico:	
 * Realizado por:	Experian
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Cuenta totales personas. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 *  2018-12-26  #5 Optimizar SP       Experian - Fernando Garrido M.
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

	----------------------------------------
	-- Busca la tabla TMP_CNTA_FECHAS
	----------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_CNTA_FECHAS' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-------------------------------------------------
	-- Se borra la tabla TMP_CNTA_FECHAS si existe
	-------------------------------------------------
  	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_CNTA_FECHAS';
	CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	---------------------------------------------------------------------------------------
	-- Step 1: Calculando las cuentas totales de las personas. TMP_CNTA_FECHAS alias paso7
	---------------------------------------------------------------------------------------
   SET V_CADENA = ' ';

   SET V_CADENA=  'create multiset table '||P_BDSTAGE || '.TMP_CNTA_FECHAS as 
				(
				select cod_dw_cta,add_months(fecha_nov,-12) fecha_nov_ini,fecha_nov
				from '||P_BDSTAGE || '.CTA_TOTALES_PERSONAS_TMP1 a
				)
				with data
				primary index(cod_dw_cta,fecha_nov_ini,fecha_nov);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS(1):Calculando las cuentas totales de las personas.TMP_CNTA_FECHAS'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	----------------------------------------------------
	-- RECOLECCION DE ESTADISTICAS 	TMP_CNTA_FECHAS	
	----------------------------------------------------
		
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS  index(cod_dw_cta,fecha_nov_ini,fecha_nov)
	                                   ,COLUMN (COD_DW_CTA)
									   ,COLUMN (FECHA_NOV_INI)
                                       ,COLUMN (FECHA_NOV)
				    on  '||P_BDSTAGE||'.TMP_CNTA_FECHAS ;';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS(1.1):RECOLECCION DE ESTADISTICAS TMP_CNTA_FECHAS'
									,V_ERROR);
				
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;	

 END L1;	
END;

