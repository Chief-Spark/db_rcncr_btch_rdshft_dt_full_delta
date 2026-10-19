REPLACE   PROCEDURE REC_DATOS.PRO_ORD_UNIF_BTT_REC

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


/*
 * ################################################################################
 * 
 * Objetivo:	Materialización tablas BTT y Reconocer Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Unificacion BTT - RECONOCER. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * Fecha:2018-09-26  Objetivo=#1 Se agrega IN P_VARQUERY  Realizado por: CARLOS CASTILLO
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

	---------------------------
	-- Busca la tabla UNIFICA_BTT_RECONOCER
	---------------------------
	SELECT tablename 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND tablename = 'UNIFICA_BTT_RECONOCER' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla UNIFICA_BTT_RECONOCER si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	-------------------------------
	-- CREACION DE TABLA UNIFICA_BTT_RECONOCER
	-------------------------------
   SET V_CADENA = ' ';
   SET V_CADENA = 'CREATE SET TABLE  '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER ,
						 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
						 AS  (
					SELECT Id_Buro_Persona,Cod_Pin_Persona -- INICIA JOINS BTT
					FROM  '||P_BDSTAGE||'.PASO_V_CUENTA

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_BURO_PERSONA

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO

					UNION ALL -- INICIA JOINS RECONOCER

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_RPU

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_RRPU

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_BLOQUEO

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_RELA_UBIC_ESTANDAR_GEO

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_UBICACION_ESTANDARIZADA

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_LOG_UBIC_ESTANDARIZADA

					UNION ALL

					SELECT Id_Buro_Persona,Cod_Pin_Persona
					FROM  '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION

					)
					WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_UNIF_BTT_REC(1):CREACION TABLA UNIFICA_BTT_RECONOCER'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
	-------------------------------
	-- RECOLECCION DE ESTADISTICAS UNIFICA_BTT_RECONOCER
	-------------------------------
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER INDEX(Cod_Pin_Persona, Id_Buro_Persona);';


		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_ORD_UNIF_BTT_REC(1.1):RECOLECCION DE ESTADISTICAS UNIFICA_BTT_RECONOCER'
										,V_ERROR);
				
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
	END L1;
END;

