REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CTA_TOTALES_PERSONAS_2
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
 * Realizado por:	Capgemini
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
			
   ------------------------------------------------------
   -- Busca la tabla STG_COMPORTAMIENTO_CTA_PASIVO
   ------------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_COMPORTAMIENTO_PASIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	----------------------------------------------------------
	-- Se borra la tabla TMP_COMPORTAMIENTO_PASIVO si existe
	----------------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_COMPORTAMIENTO_PASIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	----------------------------------------
	-- Creacion tabla TMP_COMPORTAMIENTO_PASIVO
	----------------------------------------
 
    SET V_CADENA = ' ';
	SET V_CADENA = 'create multiset table '||P_BDSTAGE || '.TMP_COMPORTAMIENTO_PASIVO
					as 
					(select  a.COD_DW_CTA
						,b.Fecha_Nov
						,Valor_Debitos_Efec
						,Valor_Creditos_Efec
						,Valor_Debitos_Transf
						,Valor_Creditos_Transf
						,Valor_Cheques_Pags
						,Valor_Cheques_Devs
						,Cantidad_Cheques_Devs
						,Cantidad_Cheques_Pags
						,Dias_Sobregiro_Aut
						,Valor_Cupo_Sobregiro_Aut
					from  '||P_BDSTAGE || '.TMP_CNTA_FECHAS  b
					inner join  '||P_BTTVISTA||'.vu_comportamiento_cta_pasivo  a
					on b.cod_dw_cta=a.cod_dw_cta
					and a.fecha_nov between b.fecha_nov_ini and b.fecha_nov
					)with data
					primary index(cod_dw_cta);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS_2(4):Creacion tabla TMP_COMPORTAMIENTO_PASIVO'
									,V_ERROR);		
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   
    SET V_CADENA = ' ';
    SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Cta) on  '||P_BDSTAGE||'.TMP_COMPORTAMIENTO_PASIVO ;';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS_2(4.1):RECOLECCION DE ESTADISTICAS STG_COMPORTAMIENTO_CTA_ACTIVO'
									,V_ERROR);
				
	SET P_ERROR = V_ERROR;
		
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	------------------------------------------------------
	--#4 Busca la tabla TMP_CNTA_FECHAS
	------------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_CNTA_FECHAS' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	--#4 Se borra la tabla TMP_CNTA_FECHAS si existe
	-----------------------------
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_CNTA_FECHAS';
	CALL DBC.SysExecSQL(:V_CADENA);

	END IF;	
	---------------------------
	-- Busca la tabla CTA_TOTALES_PERSONAS_TMP2
	---------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP2' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla CTA_TOTALES_PERSONAS_TMP2 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
		
		
  -- step 3 CREACION CTA_TOTALES_PERSONAS_TMP2 alias paso7 CRUZANDO TMP1 CON tablas precalculadas para CTA ACTIVO Y PASIVO.
 
    SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2 ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
				   AS (SELECT a.*
								,g.Valor_Inicial
								,g.Valor_Saldo
								,g.Valor_Cuota_Mensual
								,g.Numero_Dias_Mora
								,g.Valor_Saldo_Mora
								,g.Num_Cuotas_Pagadas
								,g.Valor_Disponible
								,g.Num_Cuotas_Mora
								,g.Num_Cuotas_Pactadas
								,g.Flag_Comp_Cta_Activo
								,h.Valor_Debitos_Efec
								,h.Valor_Creditos_Efec
								,h.Valor_Debitos_Transf
								,h.Valor_Creditos_Transf
								,h.Valor_Cheques_Pags
								,h.Valor_Cheques_Devs
								,h.Cantidad_Cheques_Devs
								,h.Cantidad_Cheques_Pags
								,h.Dias_Sobregiro_Aut
								,h.Valor_Cupo_Sobregiro_Aut
								,CASE WHEN h.cod_dw_cta IS NOT NULL THEN ''Y'' ELSE ''N'' END Flag_Comp_Cta_Pasivo
						FROM '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1 A

						LEFT JOIN '||P_BDSTAGE||'.STG_COMPORTAMIENTO_CTA_ACTIVO g -- Modificado por Experian. Andy Garcia 26-07-2017
						ON a.Cod_DW_Cta = g.Cod_DW_Cta

						LEFT JOIN '||P_BDSTAGE||'.STG_COMPORTAMIENTO_CTA_PASIVO h -- Modificado por Experian. Andy Garcia 26-07-2017
						ON a.Cod_DW_Cta = H.Cod_DW_Cta
						)
						WITH DATA
						PRIMARY INDEX (Cod_DW_Cta);	';	
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_ORD_CTA_TOTALES_PERSONAS_2(5):CREACION CTA_TOTALES_PERSONAS_TMP2 '
										,V_ERROR);
				
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;		
		   
    SET V_CADENA = ' ';
    SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Cta) on  '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2 ;';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_TOTALES_PERSONAS_2(4.1):RECOLECCION DE ESTADISTICAS CTA_TOTALES_PERSONAS_TMP2'
									,V_ERROR);
				
	SET P_ERROR = V_ERROR;
		
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	

	---------------------------
	--#4 Busca la tabla CTA_TOTALES_PERSONAS_TMP1
	---------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP1' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	--#4 Se borra la tabla CTA_TOTALES_PERSONAS_TMP1 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

   ---------------------------
   --#4 Busca la tabla STG_COMPORTAMIENTO_CTA_ACTIVO
   ---------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'STG_COMPORTAMIENTO_CTA_ACTIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	 -----------------------------
	 --#4 Se borra la tabla STG_COMPORTAMIENTO_CTA_ACTIVO si existe
     -----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.STG_COMPORTAMIENTO_CTA_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);    
		
	END IF;

---------------------------
-- Busca la tabla CTA_TOTALES_PERSONAS_TMP3
---------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP3' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla CTA_TOTALES_PERSONAS_TMP2 si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP3 ,
			 NO BEFORE JOURNAL,
			 NO AFTER JOURNAL,
			 CHECKSUM = DEFAULT
		   AS   (
					SELECT 
		a.*
						, CASE WHEN a.Flag_Comp_Cta_Pasivo = ''Y'' THEN 
											CASE WHEN CAST(a.Cod_Tipo_Cta_Fte AS INTEGER)=1 AND SUBSTR(a.Cod_suscriptor,1,2)=51 THEN
											 ''AH'' 
											 ELSE
															  CASE WHEN CAST(Cod_Tipo_Cta_Fte AS INTEGER)=1 AND SUBSTR(Cod_suscriptor,1,2) <>51 THEN
															  ''CT''
															  ELSE
																		''--''
															  END
											END
									ELSE 
									--''--''
											CASE WHEN a.Flag_Comp_Cta_Activo = ''Y'' THEN
														CASE WHEN Cod_Tipo_Rel_Con_Cta_Fte  = ''C'' AND CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) <> 2 THEN
																	''CO''
														ELSE
																	CASE WHEN (CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (2,3))
																									  OR ((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (5,6,27,49)) AND (CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=2 AND A.NUM_CUOTAS_PACTADAS=0 AND Cod_Clase_Garantia_Buro_Fte <>''1''))
																									  OR (CAST(a.Cod_Tipo_Cta_Fte AS INTEGER)=18 AND (CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=2 AND (A.NUM_CUOTAS_PACTADAS=0 AND Cod_Clase_Garantia_Buro_Fte <>''1''))) THEN -- Modificado por Experian. Andy Garcia 01/08/2017
																	''RO''
																	
																	ELSE
																			CASE WHEN (((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (5,6,7,8,18,27,49)) AND CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=2)
																									  OR (CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) = 18 AND CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=1)) 
																									  AND A.NUM_CUOTAS_PACTADAS BETWEEN 1 AND 60  
																									  AND Cod_Clase_Garantia_Buro_Fte =''1'' THEN
																			''VE''								  
																			ELSE
																						CASE WHEN CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) =13 
																						OR ((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (5,6,7,8,27,49)) AND (CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=3 
																						OR (A.NUM_CUOTAS_PACTADAS>60 AND Cod_Clase_Garantia_Buro_Fte =''1''))) THEN -- Modificado por Experian. Andy Garcia 01/08/2017
																						
																						''HP''						
																						
																						ELSE
																						
																								CASE WHEN CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (5,6,7,8,9,14,18,27,33,46,49) THEN
																								
																								''IN''
																								
																								ELSE
																											CASE WHEN ((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (4,9,10,11,15,16,19,20,21,22,26,28,29,34,35,36,43,44,45) AND (CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)=2))
																																	OR (CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (15,16) AND CAST(Cod_Tipo_Obligacion_Fte AS INTEGER) = 3))
																																	OR (((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (4 , 9 , 10 , 11 , 19 , 20 , 21 , 22 , 26 , 28 , 29 , 34 , 35 , 36 , 43 , 44 , 45)) AND CAST(Cod_Tipo_Obligacion_Fte AS INTEGER)<>2)
																																	OR ((CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (15,16) AND CAST(Cod_Tipo_Obligacion_Fte AS INTEGER) NOT IN (3,2)) 
																																	OR  CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (30 , 31 , 32 , 37 , 38 , 39 , 41 , 42))) THEN
																											
																											''OT''
																											
																											ELSE
																											
																														CASE WHEN CAST(a.Cod_Tipo_Cta_Fte AS INTEGER) IN (23,24) THEN
																														''CC''
																														
																														ELSE
																														
																														''OT''
																														END
																											END
																								
																								END
																						
																						END
																			END
																	END
														END
														
											
											ELSE
											''OT''
											
											END

									END Portafolio		
		,CASE WHEN portafolio = ''CO'' THEN ''CO''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (02,03) THEN ''RO''
				 WHEN SUBSTR(cod_suscriptor,1,2) = 05 THEN ''IN''   
				 WHEN (SUBSTR(cod_suscriptor,1,2) = 04 AND cod_suscriptor IN (040003, 040076, 040909, 040301, 040131, 040657, 040803, 040129, 040039, 042627, 041336, 040125, 040099, 040980, 040895,040390, 040195, 040022, 042027, 041901, 040249, 040368, 041409, 040142, 040218, 040127, 040290, 040468,040190,041153, 040507, 043410, 040199,  040189, 040188) OR (SUBSTR(cod_suscriptor,1,2)=05 AND cod_suscriptor = 050058) OR (SUBSTR(cod_suscriptor,1,2)=18 AND cod_suscriptor IN (180110, 180015, 180007, 180185, 189905, 180151, 180114)) OR (SUBSTR(cod_suscriptor,1,2)=20 AND cod_suscriptor=200059) OR (SUBSTR(cod_suscriptor,1,2)=45 AND cod_suscriptor IN (450043, 450030, 450053, 450050, 450035, 450036, 450034,   450051, 450028, 450045, 450048, 450074, 450032, 450052,  450031, 450042, 450033, 450039, 450049, 450041, 450044,  450112))) THEN ''VE''
				 WHEN SUBSTR(cod_suscriptor,1,2)=13 THEN ''HP''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (07, 14, 17, 18, 20, 48, 49) THEN ''FR''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (23,24) THEN ''CC''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (06, 27) THEN ''CP''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (04, 09, 10, 11, 19, 22, 28, 32, 34, 35, 37, 39, 45, 47) THEN ''RC''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (08, 12, 15, 16, 21, 25, 26, 29, 30, 31, 33, 36, 38, 40, 41, 42, 43, 44, 46) THEN ''RS''
				 WHEN SUBSTR(cod_suscriptor,1,2) IN (51,01) THEN ''CT''
				 ELSE ''OT'' END Portafolio_Nuevo

		,CASE WHEN Portafolio_nuevo =''CO'' THEN ''CO''
				 WHEN Portafolio_nuevo =''CC'' THEN ''CC''
				 WHEN Portafolio_nuevo IN (''RC'',''RS'') THEN ''RE''
				 WHEN Portafolio_nuevo IN (''IN'',''RO'',''HP'',''VE'',''CP'',''FR'') THEN ''FI''
				 ELSE ''OT''
				 END Sector
				 FROM '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2 a
			)
		WITH DATA
		PRIMARY INDEX (Cod_DW_Cta);	';	
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_ORD_CTA_TOTALES_PERSONAS_2(6.1):CREACION CTA_TOTALES_PERSONAS_TMP3 '
										,V_ERROR);
				
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;

		
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Cta) on  '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP3 ;';
					
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_ORD_CTA_TOTALES_PERSONAS_2(4.1):RECOLECCION DE ESTADISTICAS CTA_TOTALES_PERSONAS_TMP3'
										,V_ERROR);
					
		SET P_ERROR = V_ERROR;
			
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;	
		
		---------------------------
		-- Busca la tabla CTA_TOTALES_PERSONAS_TMP2
		---------------------------
		SELECT TableName 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TableName = 'CTA_TOTALES_PERSONAS_TMP3' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla CTA_TOTALES_PERSONAS_TMP2 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;

 END L1;	
END;

