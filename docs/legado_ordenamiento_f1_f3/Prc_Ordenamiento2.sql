--<ScriptOptions statementTerminator=";"/>

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CALC_UBICACIONES( IN	P_Lote						INTEGER
													,IN	P_StartTimeStampPadre		VARCHAR(20)
													,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
													,IN	P_BDDATOS					VARCHAR(20)
													,IN	P_BDVISTA					VARCHAR(20)
													,IN	P_BDSTAGE					VARCHAR(20)
													,IN	P_BTTDATOS					VARCHAR(20)
													,IN	P_BTTVISTA					VARCHAR(20)
													,IN	P_BDMTDAT					VARCHAR(20)
													,IN	P_BTTMTDAT					VARCHAR(20)
													,IN P_VARQUERY	/*#1*/			VARCHAR (500)
													,OUT P_ERROR					VARCHAR(50)
													)
/*
* ################################################################################
* 
 * Objetivo:      Materializacion tablas BTT y Reconocer Ordenamiento.
* Fecha:                     2017-02-17
* Lider Tecnico:         
* Realizado por:         Capgemini
* Parametros: 
* Proyecto:     
* Script:          24.2 -- Ordenamiento. 
* 
* 
* 
* BITACORA
* ---------------------------------------------------------------------------
* Fecha                      Objetivo                                                                                                                                                                                                       Realizado por
* #1                Ajuste ubicaciones validas                                                                                                                                                              Capgemini-Experian
* #2                Ajuste filtro solo direcciones sin unificar o padres                                                                           Capgemini-Experian
* #3                Ajuste Usar VU_Cuenta                                                                                                                                                                              Capgemini-Experian              
* #4                Ajuste Left Join Fuente para Camara y Comercio                                                                                                  Capgemini-Experian
* #5 2018-09-26                    Cambio Calculo objeto vmo_reporte_relacion_pers_ubi                                                     Capgemini-Experian
* #6 2018-10-01                    Nuevo Calculo objeto vmo_reporte_relacion_pers_ubi por duplicados            Capgemini-Experian
* #7 2018-10-03 Cambio definicion PRO_ORD_CALC_UBICACIONES                                                                                     Capgemini-Experian
* #8 2018-10-05 Eliminacion de tablas temporales despues de ser consumidas                                     Capgemini-Experian
* #9 2018-12-26 Optimización del SP   Fernando Garrido M - Experian.
* ---------------------------------------------------------------------------
* 
* Copyright 2017 Fabrica Teradata - Capgemini
* 
*  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
*                     se encuentra protegido por las leyes de derechos de autor
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
	DECLARE V_StartTimeStampPadre           TIMESTAMP(6);
	DECLARE V_ERROR                                  VARCHAR(30);
	DECLARE V_CADENA                    VARCHAR(32000);
	DECLARE V_TABLE                        VARCHAR(30);
	DECLARE Temp CHAR(30);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:  BEGIN	

	-- SE USA LA NUEVA MAT CON EL FILTRO DE LAS PERSONAS A ORDENAR

	---------------------------
	-- Busca la tabla TMP_ORD_CAL1
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_ORD_CAL1' ;

	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL1 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;          

	SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL1
					 AS (SELECT  a.Cod_DW_Reporte_Persona_Ubic
								,a.Cod_DW_Persona_Ubic
								,a.Id_Buro_Suscriptor
								,a.Cod_DW_Cta
								,a.Fecha_Reporte Fecha_Reporte_Step1
								,a.Fecha_Apertura
								,a.Fecha_Nov
								,a.Desc_Est_Vigencia
								,a.Nombre_Natu_Cta
								,a.Nombre_Tipo_Rel_con_Cta
								,a.Cod_DW_Motivo_Bloqueo
								,a.Id_Flag_Nuevo
								,a.Id_Flag_Desde 
								--1 -- validar si los flags de la ubicacion tienen valor v y no son fechas de reporte nulas para tomar el campo fecha_nov
								--2 -- validar si los flags de la ubicacion tienen valor v y no son fechas de reporte nulas para tomar el campo fecha_nov
								 --2.5 Regla para el Codeudor ya que estos casos no se tienen en cuenta para las reglas inicialmente entregadas?
								, CASE WHEN a.Desc_Est_Vigencia=''A'' THEN 								  
										  CASE WHEN a.Nombre_Natu_Cta = ''PASIVO''  OR  (a.Nombre_Natu_Cta=''ACTIVO'' AND a.Nombre_Tipo_Rel_con_Cta=''PRINCIPAL'' ) OR a.Nombre_Tipo_Rel_Con_Cta=''CODEUDOR'' 
													THEN 
														CASE WHEN a.ID_FLAG_NUEVO=1 AND a.Fecha_Reporte IS NOT NULL THEN  a.Fecha_Apertura  ELSE  a.Fecha_Reporte END						                
										   END							                                            
								  ELSE
										  CASE WHEN a.Desc_Est_Vigencia<>''A'' OR a.Cod_DW_Motivo_Bloqueo <> 1 AND a.ID_FLAG_DESDE=0 
													  THEN --3 --Fecha_Nov  -- Aplicar la evalucacion de la Regla de Fechas
															CASE WHEN a.Fecha_Reporte>a.Fecha_Nov THEN   a.Fecha_Nov    ELSE  a.Fecha_Reporte END 
												   ELSE   a.Fecha_Reporte --4
										  END   
								 END  Fecha_Reporte
								,A.Cod_DW_Matricula                                  
					FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A

					Where cod_Dw_cta in (select cod_Dw_cta from  '||P_BTTVISTA||'.vu_cuenta )
					and  Cod_DW_Cta > -1

					)
					WITH DATA
					PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic);';



			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(1):CREACION DE TABLA TMP_ORD_CAL1'
											,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
								
			-----------------------------------------
			-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL1
			-----------------------------------------
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL1 INDEX(Cod_DW_Reporte_Persona_Ubic);';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(1.1):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL1'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
		---------------------------
		-- Busca la tabla TMP_ORD_CAL11
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL11' ;

		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_ORD_CAL11 si existe
		-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL11';
		  CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          


	        SET V_CADENA = ' ';
			SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL11
							AS
							  ( SELECT a.Cod_DW_Reporte_Persona_Ubic
									 ,a.Cod_DW_Persona_Ubic
									 ,a.Id_Buro_Suscriptor
									 ,a.Cod_DW_Cta
									 ,C.Fecha_Act Fecha_Reporte
									 ,a.Fecha_Apertura
									 ,a.Fecha_Nov
									 ,a.Desc_Est_Vigencia
									 ,a.Nombre_Natu_Cta
									 ,a.Nombre_Tipo_Rel_con_Cta
									 ,a.Cod_DW_Motivo_Bloqueo
									 ,0 Id_Flag_Nuevo
									 ,2 Id_Flag_Desde 
									 ,C.Fecha_Act-- Fecha                                               
									 ,A.Cod_DW_Matricula                                                          
								   FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A

								   INNER JOIN (SELECT B.COD_PIN_PERSONA,
										  B.ID_BURO_PERSONA,
										  A.COD_DW_CTA,
										  MAX(A.FECHA_REPORTE) FECHA_ACT
										FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A
										INNER JOIN '||P_BDDATOS || '.RELACION_PERSONA_UBICACION B
										ON A.COD_DW_PERSONA_UBIC=B.COD_DW_PERSONA_UBIC
										WHERE A.ID_Flag_Desde=1
										AND (A.Cod_DW_Cta<>-1 AND A.Cod_DW_Cta IS NOT NULL) -- Se incluye este filtro para Direcciones sin cuenta por Contactabilidad. 28/09/2017
										
										GROUP BY 1,2,3) C
								   ON a.id_buro_persona=c.id_buro_persona
								   AND a.COD_DW_CTA=c.COD_DW_CTA
								   
								   INNER JOIN (SELECT Cod_DW_Reporte_Persona_Ubic
										  ,COD_DW_CTA
										  ,Cod_DW_Persona_Ubic
										  ,Id_Buro_Suscriptor
										  ,Id_Flag_Desde
										FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT
										WHERE ID_Flag_Desde=0
										) D

								   ON a.Cod_DW_Cta=d.Cod_DW_Cta
								   AND a.Cod_DW_Persona_Ubic=d.Cod_DW_Persona_Ubic
								   AND a.Id_Buro_Suscriptor=d.Id_Buro_Suscriptor
								   AND a.id_Flag_Desde=d.Id_Flag_Desde
								   Group by 1,2,3,4,5,6,7,8,9,10,11,14,15
							)WITH DATA 
							PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic);';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(2):Insertando en TMP_ORD_CAL11'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL11 INDEX(Cod_DW_Reporte_Persona_Ubic);';
			
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(2.1):ESTADISTICAS para TMP_ORD_CAL11'
										   ,V_ERROR);
            
			SET V_CADENA = ' ';
			SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.TMP_ORD_CAL1
							SELECT * FROM '||P_BDSTAGE||'.TMP_ORD_CAL11';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(2.2):Insertando en TMP_ORD_CAL1'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL1 INDEX(Cod_DW_Reporte_Persona_Ubic);';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(2.3):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL1'
										   ,V_ERROR);								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
	    ---------------------------
		-- Busca la tabla TMP_ORD_CAL11
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL11' ;

		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_ORD_CAL11 si existe
		-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL11';
		  CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		---------------------------
		-- Busca la tabla TMP_AGR_CNTAS_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_AGR_CNTAS_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_AGR_CNTAS_242 si existe
	    -----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_CNTAS_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

		SET V_CADENA= 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.TMP_AGR_CNTAS_242
						 AS 
						 (SEL COD_DW_CTA, Cod_Entrega_Dato_Fte
						  FROM '||P_BTTVISTA||'.VU_CUENTA
						  WHERE COD_DW_CTA IN (SELECT COD_DW_CTA FROM '||P_BDSTAGE||'.TMP_ORD_CAL1)
						 )WITH DATA
						 PRIMARY INDEX(COD_DW_CTA,Cod_Entrega_Dato_Fte);';


		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES(3):CREACION DE TABLA TMP_AGR_CNTAS_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
					
		---------------------------------------------------------
		-- RECOLECCION DE ESTADISTICAS  TMP_AGR_CNTAS_242
		---------------------------------------------------------
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX(COD_DW_CTA,Cod_Entrega_Dato_Fte), COLUMN(COD_DW_CTA)  ON '||P_BDSTAGE||'.TMP_AGR_CNTAS_242 ;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES(3.1):RECOLECCION DE ESTADISTICAS TMP_AGR_CNTAS_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;

		---------------------------
		-- Busca la tabla TMP_ORD_CAL2
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL2' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		----------------------------------------------------------
		-- Se borra la tabla TMP_ORD_CAL2 si existe
	    ----------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL2';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          



    	SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL2 
						AS ( SELECT  a.Cod_DW_Reporte_Persona_Ubic
									,a.Cod_DW_Persona_Ubic
									,a.Id_Buro_Suscriptor
									,a.Cod_DW_Cta
									,a.Fecha_Reporte Fecha_Reporte_Step1
									,a.Fecha_Apertura
									,a.Fecha_Nov
									,a.Desc_Est_Vigencia
									,a.Nombre_Natu_Cta
									,a.Nombre_Tipo_Rel_con_Cta
									,a.Cod_DW_Motivo_Bloqueo
									,a.Id_Flag_Nuevo
									,a.Id_Flag_Desde 
									,a.Fecha_Reporte
									,a.Cod_DW_Matricula
									,B.Cod_Entrega_Dato_Fte
						FROM '||P_BDSTAGE||'.TMP_ORD_CAL1 A

						LEFT JOIN '||P_BDSTAGE||'.TMP_AGR_CNTAS_242 B
						ON A.COD_DW_CTA=B.COD_DW_CTA		
								
						)WITH DATA
						PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde, Cod_Entrega_Dato_Fte);';



			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(4):CREACION DE TABLA TMP_ORD_CAL2'
										   ,V_ERROR);
										   
			SET P_ERROR = V_ERROR;
								
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
						
			----------------------------------------------
			-- RECOLECCION DE ESTADISTICAS  TMP_ORD_CAL2
			----------------------------------------------
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde, Cod_Entrega_Dato_Fte) ON  '||P_BDSTAGE||'.TMP_ORD_CAL2;';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(4.1):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL2'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;

					
		---------------------------
		--#8 Busca la tabla TMP_ORD_CAL1
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL1' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		--#8 Se borra la tabla TMP_ORD_CAL1 si existe
		-----------------------------
				SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL1';
				CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
	
	----------------------------------------------------
	-- Busca la tabla TMP_ORD_CAL3
	----------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL3' ;
		
		IF ACTIVITY_COUNT > 0 THEN
	----------------------------------------------------------
	-- Se borra la tabla TMP_ORD_CAL3 si existe
	----------------------------------------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL3';
					CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          


		SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL3
						AS
						(SELECT a.Cod_DW_Reporte_Persona_Ubic
										,a.Cod_DW_Persona_Ubic
										,a.Id_Buro_Suscriptor
										,a.Cod_DW_Cta
										,a.Fecha_Reporte Fecha_Reporte_Step1
										,a.Fecha_Apertura
										,a.Fecha_Nov
										,a.Desc_Est_Vigencia
										,a.Nombre_Natu_Cta
										,a.Nombre_Tipo_Rel_con_Cta
										,a.Cod_DW_Motivo_Bloqueo
										,a.Id_Flag_Nuevo
										,a.Id_Flag_Desde 
										,a.Fecha_Reporte
										,a.Cod_DW_Matricula
						FROM '||P_BDSTAGE||'.TMP_ORD_CAL2 a
						QUALIFY(ROW_NUMBER()OVER(PARTITION BY a.Cod_Entrega_Dato_Fte, a.Cod_DW_Persona_Ubic,a.Cod_DW_Cta,a.Id_Flag_Desde ORDER BY a.Id_Flag_Desde))<=3
						)WITH DATA
						PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde);';



			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(5):CREACION DE TABLA TMP_ORD_CAL3'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
						
			-----------------------------------------
			-- RECOLECCION DE ESTADISTICAS TMP_ORD_CAL3
			-----------------------------------------
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL3 INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde);';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES(5.1):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL3'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
		--------------------------------------------------------
		-- Busca la tabla TMP_AGR_CNTAS_242
		--------------------------------------------------------
			SELECT TABLENAME 
			INTO :Temp
			FROM dbc.tables
			WHERE databasename =:P_BDSTAGE
			AND TABLENAME = 'TMP_AGR_CNTAS_242' ;
			
			IF ACTIVITY_COUNT > 0 THEN
		----------------------------------------------------------
		-- Se borra la tabla TMP_AGR_CNTAS_242 si existe
		----------------------------------------------------------
						SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_CNTAS_242';
						CALL DBC.SysExecSQL(:V_CADENA);
			END IF;          
					
		--------------------------------------------------------
		-- Busca la tabla TMP_ORD_CAL2
		--------------------------------------------------------
			SELECT TABLENAME 
			INTO :Temp
			FROM dbc.tables
			WHERE databasename =:P_BDSTAGE
			AND TABLENAME = 'TMP_ORD_CAL2' ;
			
			IF ACTIVITY_COUNT > 0 THEN
		----------------------------------------------------------
		-- Se borra la tabla TMP_ORD_CAL2 si existe
		----------------------------------------------------------
						SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL2';
						CALL DBC.SysExecSQL(:V_CADENA);
			END IF;          
					
   END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CALC_UBICACIONES_1( IN	P_Lote						INTEGER
													,IN	P_StartTimeStampPadre		VARCHAR(20)
													,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
													,IN	P_BDDATOS					VARCHAR(20)
													,IN	P_BDVISTA					VARCHAR(20)
													,IN	P_BDSTAGE					VARCHAR(20)
													,IN	P_BTTDATOS					VARCHAR(20)
													,IN	P_BTTVISTA					VARCHAR(20)
													,IN	P_BDMTDAT					VARCHAR(20)
													,IN	P_BTTMTDAT					VARCHAR(20)
													,IN P_VARQUERY	/*#1*/			VARCHAR (500)
													,OUT P_ERROR					VARCHAR(50)
													)
 /*
 * ################################################################################
 * 
 * Objetivo:	Ordenamiento PRO_ORD_CTA_ATRIBUTOS.
 * Fecha:		2019-01-09
 * Lider Tecnico:	
 * Realizado por:	Fernando Garrido M.
 * Parametros:	
 * Proyecto:	 Reconocer Master
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha:2019-01-09 VERSION INICIAL  Realizado por: Fernando Garrido
 * 
 * --------------------------------------------------------------------------- 
 
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Experian  y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */
 BEGIN
            

	------------------------
	-- Declaracion de variables
	------------------------
	DECLARE V_StartTimeStampPadre           TIMESTAMP(6);
	DECLARE V_ERROR                                  VARCHAR(30);
	DECLARE V_CADENA                    VARCHAR(32000);
	DECLARE V_TABLE                        VARCHAR(30);
	DECLARE Temp CHAR(30);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:  BEGIN	
---------------------------
	-- Busca la tabla TMP_ORD_CAL6
	---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL6' ;
		
		IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL6 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL6';
					CALL DBC.SysExecSQL(:V_CADENA);
	  END IF;          


	  SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL6 
					AS (SELECT a.Cod_DW_Reporte_Persona_Ubic
								,a.Cod_DW_Persona_Ubic
								,a.Id_Buro_Suscriptor
								,a.Cod_DW_Cta
								,a.Fecha_Reporte Fecha_Reporte_Step1
								,a.Fecha_Apertura
								,a.Fecha_Nov
								,a.Desc_Est_Vigencia
								,a.Nombre_Natu_Cta
								,a.Nombre_Tipo_Rel_con_Cta
								,a.Cod_DW_Motivo_Bloqueo
								,a.Id_Flag_Nuevo
								,a.Id_Flag_Desde 
								--1 -- validar si los flags de la ubicacion tienen valor v y no son fechas de reporte nulas para tomar el campo fecha_nov
								--2 -- validar si los flags de la ubicacion tienen valor v y no son fechas de reporte nulas para tomar el campo fecha_nov
								 --2.5 Regla para el Codeudor ya que estos casos no se tienen en cuenta para las reglas inicialmente entregadas?
								,CASE WHEN a.Desc_Est_Vigencia=''A'' THEN 
											CASE WHEN a.Nombre_Natu_Cta = ''PASIVO'' OR (a.Nombre_Natu_Cta=''ACTIVO'' AND a.Nombre_Tipo_Rel_con_Cta=''PRINCIPAL'' )  OR  a.Nombre_Tipo_Rel_Con_Cta=''CODEUDOR'' 
														 THEN 
												   CASE WHEN a.ID_FLAG_NUEVO=1 AND a.Fecha_Reporte IS NOT NULL THEN    a.Fecha_Apertura ELSE a.Fecha_Reporte END                                                                                    
											END
																			   
								   ELSE
										   CASE WHEN a.Desc_Est_Vigencia<>''A'' OR a.Cod_DW_Motivo_Bloqueo <> 1 AND a.ID_FLAG_DESDE=0 
																		THEN --3 --Fecha_Nov  -- Aplicar la evalucacion de la Regla de Fechas
																	 CASE WHEN a.Fecha_Reporte>a.Fecha_Nov THEN   a.Fecha_Nov ELSE  a.Fecha_Reporte END      
												 ELSE         a.Fecha_Reporte --4
											END                                                            
								  END Fecha_Reporte
								 ,A.Cod_DW_Matricula                                              
					FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A

					WHERE A.COD_DW_CTA NOT IN  (SELECT COD_DW_CTA FROM '||P_BTTVISTA||'.VU_CUENTA)

					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,id_flag_desde);';



		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_1(1):CREACION DE TABLA TMP_ORD_CAL6'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
					
		-----------------------------------------
		-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL4
		-----------------------------------------
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Reporte_Persona_Ubic,id_flag_desde) ON '||P_BDSTAGE||'.TMP_ORD_CAL6;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_1(1.1):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL6'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
        
	---------------------------
	-- Busca la tabla TMP_ORD_CAL61
	---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL61' ;
		
		IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL61 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL61';
					CALL DBC.SysExecSQL(:V_CADENA);
	   END IF;          
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL61 
						 AS (
						  SELECT a.Cod_DW_Reporte_Persona_Ubic
							,a.Cod_DW_Persona_Ubic
							,a.Id_Buro_Suscriptor
							,a.Cod_DW_Cta
							,C.Fecha_Act --Fecha_Reporte
							,a.Fecha_Apertura
							,a.Fecha_Nov
							,a.Desc_Est_Vigencia
							,a.Nombre_Natu_Cta
							,a.Nombre_Tipo_Rel_con_Cta
							,a.Cod_DW_Motivo_Bloqueo
							,0 Id_Flag_Nuevo
							,2 Id_Flag_Desde 
							,C.Fecha_Act Fecha_Reporte                                              
							,a.Cod_DW_Matricula                                                           
						  FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A
						  INNER JOIN '||P_BDDATOS || '. Relacion_Persona_ubicacion b
						  ON a.cod_dw_Persona_Ubic=b.cod_dw_Persona_Ubic

						  INNER JOIN (SELECT B.COD_PIN_PERSONA,
								 B.ID_BURO_PERSONA,
								 A.Cod_DW_Persona_Ubic,
								 A.Cod_DW_Fuente,
								 A.Cod_DW_Matricula Cod_DW_Matricula,
								 MAX(A.FECHA_REPORTE) FECHA_ACT
							   FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT A
							   INNER JOIN '||P_BDDATOS || '.RELACION_PERSONA_UBICACION B
							   ON A.COD_DW_PERSONA_UBIC=B.COD_DW_PERSONA_UBIC
							   WHERE A.ID_Flag_Desde=1
							   AND (A.Cod_DW_Cta=-1 OR A.Cod_DW_Cta IS NULL)-- Se incluye este filtro para Direcciones sin cuenta por Contactabilidad. 28/09/2017
							   GROUP BY 1,2,3,4,5) C

						  ON    b.Cod_Pin_Persona=c.Cod_Pin_Persona
						  AND b.Id_Buro_Persona=c.Id_Buro_Persona
						  AND  a.Cod_DW_Persona_Ubic=c.Cod_DW_Persona_Ubic
						  AND a. Cod_DW_Fuente=c.Cod_DW_Fuente
						  AND a.Cod_DW_Matricula=c.Cod_DW_Matricula
						  
						  INNER JOIN (SELECT Cod_DW_Reporte_Persona_Ubic
								 ,Cod_DW_Cta
								 ,Cod_DW_Persona_Ubic
								 ,Id_Buro_Suscriptor
								 ,Cod_DW_Matricula
							   FROM '||P_BDSTAGE||'.TMP_ORD_CAL_MAT
							   WHERE ID_Flag_Desde=0) D

						  ON a.Cod_DW_Cta=d.Cod_DW_Cta
						  AND a.Cod_DW_Persona_Ubic=d.Cod_DW_Persona_Ubic
						  AND a.Id_Buro_Suscriptor=d.Id_Buro_Suscriptor
						  AND a.Cod_DW_Matricula=d.Cod_DW_Matricula

						  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
						 )WITH DATA 
						 PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic);';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_1(2):CREANDO EN TMP_ORD_CAL61'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
			SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Reporte_Persona_Ubic) ON '||P_BDSTAGE||'.TMP_ORD_CAL61;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_1(2.1):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL61'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.TMP_ORD_CAL6
		                SELECT * FROM '||P_BDSTAGE||'.TMP_ORD_CAL61;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_1(3):INSERTANDO EN TMP_ORD_CAL6'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
        
	---------------------------
	-- Busca la tabla TMP_ORD_CAL61
	---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL61' ;
		
		IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL61 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL61';
					CALL DBC.SysExecSQL(:V_CADENA);
	   END IF;       
						
   END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CALC_UBICACIONES_2( IN	P_Lote						INTEGER
														,IN	P_StartTimeStampPadre		VARCHAR(20)
														,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
														,IN	P_BDDATOS					VARCHAR(20)
														,IN	P_BDVISTA					VARCHAR(20)
														,IN	P_BDSTAGE					VARCHAR(20)
														,IN	P_BTTDATOS					VARCHAR(20)
														,IN	P_BTTVISTA					VARCHAR(20)
														,IN	P_BDMTDAT					VARCHAR(20)
														,IN	P_BTTMTDAT					VARCHAR(20)
														,IN P_VARQUERY	/*#1*/			VARCHAR (500)
														,OUT P_ERROR					VARCHAR(50)
														)
 /*
 * ################################################################################
 * 
 * Objetivo:	Ordenamiento PRO_ORD_CTA_ATRIBUTOS.
 * Fecha:		2019-01-09
 * Lider Tecnico:	
 * Realizado por:	Fernando Garrido M.
 * Parametros:	
 * Proyecto:	 Reconocer Master
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha:2019-01-09 VERSION INICIAL  Realizado por: Fernando Garrido
 * 
 * --------------------------------------------------------------------------- 
 
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Experian  y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */
 BEGIN
            

	------------------------
	-- Declaracion de variables
	------------------------
	DECLARE V_StartTimeStampPadre           TIMESTAMP(6);
	DECLARE V_ERROR                                  VARCHAR(30);
	DECLARE V_CADENA                    VARCHAR(32000);
	DECLARE V_TABLE                        VARCHAR(30);
	DECLARE Temp CHAR(30);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:  BEGIN	

	-------------------------------------------
	-- Busca la tabla TMP_ORD_CAL_MAT 
	-------------------------------------------
   SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_ORD_CAL_MAT' ;

	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL_MAT si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL_MAT';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;                                  
				

	-- Tabla Union 2
	-- Tabla definitiva

	------------------------------------------------------
	-- Busca la tabla vmo_reporte_relacion_pers_ubi
	------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'vmo_reporte_relacion_pers_ubi' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla vmo_reporte_relacion_pers_ubi si existe
		-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi';
					CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          



		SET V_CADENA=  'CREATE SET TABLE '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi 
						 AS (SELECT a.Cod_DW_Reporte_Persona_Ubic
												,a.Cod_DW_Persona_Ubic
												,a.Id_Buro_Suscriptor
												,a.Cod_DW_Cta
												,a.Fecha_Reporte Fecha_Reporte_Step1
												,a.Fecha_Apertura
												,a.Fecha_Nov
												,a.Desc_Est_Vigencia
												,a.Nombre_Natu_Cta
												,a.Nombre_Tipo_Rel_con_Cta
												,a.Cod_DW_Motivo_Bloqueo
												,a.Id_Flag_Nuevo
												,a.Id_Flag_Desde 
												,a.Fecha_Reporte
												,a.Cod_DW_Matricula 
						FROM  '||P_BDSTAGE||'.TMP_ORD_CAL3 a
						)WITH DATA
						PRIMARY INDEX (Cod_DW_Reporte_Persona_Ubic, Id_Flag_Desde);';


			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES_2(1):CREACION DE TABLA vmo_reporte_relacion_pers_ubi'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
						
			-----------------------------------------
			-- RECOLECCION DE ESTADISTICAS       vmo_reporte_relacion_pers_ubi
			-----------------------------------------
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Reporte_Persona_Ubic, Id_Flag_Desde), COLUMN (COD_DW_PERSONA_UBIC) ON '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi;';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(1.1):RECOLECCION DE ESTADISTICAS vmo_reporte_relacion_pers_ubi'
								   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi 
			                SELECT *  FROM '||P_BDSTAGE||'.TMP_ORD_CAL6;';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(1.2):Insertando en vmo_reporte_relacion_pers_ubi'
								   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Reporte_Persona_Ubic, Id_Flag_Desde), COLUMN (COD_DW_PERSONA_UBIC) ON '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi;';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(1.3):RECOLECCION DE ESTADISTICAS vmo_reporte_relacion_pers_ubi'
								   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;

		-----------------------------
		--#8 Se borra la tabla TMP_ORD_CAL3 si existe
		-----------------------------            

		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL3' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		--#8 Se borra la tabla TMP_ORD_CAL3 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL3';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

		---------------------------
		--#8 Busca la tabla TMP_ORD_CAL6
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_ORD_CAL6' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		--#8 Se borra la tabla TMP_ORD_CAL6 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL6';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;                                  

	    -------------------------------------------------------------------------------------------------------------------------------------------                   
	    ----------------------------------------- FIN CALCULO vmo_reporte_relacion_pers_ubi /*#5*/ /*#6*/ -----------------------------------------
	    -------------------------------------------------------------------------------------------------------------------------------------------
		---------------------------
		-- Busca la tabla VECTOR_UBI_INSUMO_BASE_0
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'VECTOR_UBI_INSUMO_BASE_0' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla VECTOR_UBI_INSUMO_BASE_0 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE_0';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;
		-----------------------------------------
		-- STEP 7 CREACION DE TABLA VECTOR_UBI_INSUMO_BASE_0
		-----------------------------------------

		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.VECTOR_UBI_INSUMO_BASE_0 AS 
					   (SELECT a.Cod_Pin_Persona
							   ,a.Id_Buro_Persona
							   ,b.Cod_DW_Persona_Ubic
							   ,b.Cod_DW_Ubic
							   ,b.Cod_DW_Telefono
							   ,b.Cod_DW_Direccion_Electronica
							   ,b.Cod_DW_Direccion_Fisica
							   ,b.Cod_DW_Tipo_Ubicacion_Dir                                                                  
							   ,b.Orden_Prioridad
							   ,b.Ind_Unificacion
							   /*,c.Cod_DW_Reporte_Persona_Ubic
							   ,c.Cod_DW_Cta
							   ,c.ID_Buro_Suscriptor
							   ,c.Fecha_Reporte*/

						   FROM '||P_BDSTAGE || '.UNIFICA_BTT_RECONOCER a -- unificacion btt_reconocer 
						   INNER JOIN '||P_BDDATOS || '.relacion_persona_ubicacion b
						   ON a.cod_pin_persona=b.cod_pin_persona
						   AND a.id_buro_persona=b.id_buro_persona


						   /* excluyendo registros con bloqueo */
						   LEFT JOIN '||P_BDDATOS || '.bloqueo d
						   ON b.cod_dw_persona_ubic=d.cod_dw_persona_ubic

						   WHERE d.cod_dw_persona_ubic IS NULL -- Modificado por Experian. Andy Garcia 27-07-2017
						   AND b.Ind_Unificacion IS NULL /*#2*/
					   )WITH DATA
					   PRIMARY INDEX(Cod_DW_Persona_Ubic)';
														
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES_2(2):CREACION DE TABLA VECTOR_UBI_INSUMO_BASE_0'
										   ,V_ERROR);								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;
								
			-----------------------------------------
			-- RECOLECCION DE ESTADISTICAS       VECTOR_UBI_INSUMO_BASE_0  
			-----------------------------------------
			
			SET V_CADENA = ' ';
			SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE_0 INDEX(Cod_DW_Persona_Ubic);';
								   
			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										   ,V_StartTimeStampPadre
										   ,:P_Nombre_Proceso_Padre
										   ,:V_CADENA
										   ,'PRO_ORD_CALC_UBICACIONES_2(2.1):RECOLECCION DE ESTADISTICAS VECTOR_UBI_INSUMO_BASE_0'
										   ,V_ERROR);
								   
			SET P_ERROR = V_ERROR;
						
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
						LEAVE L1;
			END IF;

			---------------------------
			-- Busca la tabla VECTOR_UBI_INSUMO_BASE
			---------------------------
			SELECT TABLENAME 
			INTO :Temp
			FROM dbc.tables
			WHERE databasename =:P_BDSTAGE
			AND TABLENAME = 'VECTOR_UBI_INSUMO_BASE' ;
			
			IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla VECTOR_UBI_INSUMO_BASE si existe
		-----------------------------
						SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE';
						CALL DBC.SysExecSQL(:V_CADENA);
			END IF;
		-----------------------------------------
		-- STEP 7 CREACION DE TABLA VECTOR_UBI_INSUMO_BASE
		-----------------------------------------
					
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.VECTOR_UBI_INSUMO_BASE
						   AS (SELECT A.*
									  ,b.Cod_DW_Reporte_Persona_Ubic
									  ,b.Cod_DW_Cta
									   ,b.ID_Buro_Suscriptor
									  ,b.Fecha_Reporte
									  ,b.Id_Flag_Desde
									  ,b.Id_Flag_Nuevo

						   FROM '||P_BDSTAGE || '.VECTOR_UBI_INSUMO_BASE_0 A
						   INNER JOIN '||P_BDSTAGE || '.vmo_reporte_relacion_pers_ubi B                                                                         
						   ON A.COD_DW_PERSONA_UBIC=B.COD_DW_PERSONA_UBIC
						   )WITH DATA
						   PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde);';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(3):CREACION DE TABLA VECTOR_UBI_INSUMO_BASE'
									   ,V_ERROR);
												   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
								
		----------------------------------------------------------------------------------
		-- RECOLECCION DE ESTADISTICAS       VECTOR_UBI_INSUMO_BASE      
		----------------------------------------------------------------------------------
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX(Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde)
													   ,COLUMN (COD_DW_TIPO_UBICACION_DIR)
													   ,COLUMN (COD_DW_UBIC)
													   ,COLUMN (COD_DW_UBIC,COD_DW_TIPO_UBICACION_DIR) ON '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE;';

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(3.1):RECOLECCION DE ESTADISTICAS        VECTOR_UBI_INSUMO_BASE'
									   ,V_ERROR);
										   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;


		------------------------------------------------------
		--#8 Busca la tabla VECTOR_UBI_INSUMO_BASE_0
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'VECTOR_UBI_INSUMO_BASE_0' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		--#8 Se borra la tabla VECTOR_UBI_INSUMO_BASE_0 si existe
		--------------------------------------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE_0';
					CALL DBC.SysExecSQL(:V_CADENA);
		END IF;                      
					
		------------------------------------------------------
		--#8 Busca la tabla vmo_reporte_relacion_pers_ubi
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'vmo_reporte_relacion_pers_ubi' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		--#8 Se borra la tabla vmo_reporte_relacion_pers_ubi si existe
		--------------------------------------------------------
				SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.vmo_reporte_relacion_pers_ubi';
				CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
					
					
		------------------------------------------------------
		-- Busca la tabla TMP_UBIC_ESTANDARIZA_242
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_UBIC_ESTANDARIZA_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		-- Se borra la tabla TMP_UBIC_ESTANDARIZA_242 si existe
		--------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

							 
		---------------------------------------------------------------
		-- Step 8: Calcular datos de ubicaciones estandarizadas    
		---------------------------------------------------------------   
		SET V_CADENA = '';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242
						AS 
						(SEL Cod_DW_Ubic ,b.Cod_DW_Tipo_Ubicacion,  b.Texto_Ubicacion,b.Cod_DW_Fuente_Est,b.cod_Dw_ciudad,''Valida'' Descripcion_Gestion_Registro
						 FROM '||P_BDVISTA||'.V_Ubicacion_estandarizada b  
						WHERE Cod_DW_Ubic IN (SEL Cod_DW_Ubic FROM '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE )
						AND b.Cod_DW_Gestion_Registro  =  ( SEL Cod_DW_Gestion_Registro from '||P_BDVISTA||'.v_gestion_registro where descripcion_gestion_registro = ''Valida'' )
						)WITH DATA 
						PRIMARY INDEX(Cod_DW_Ubic);';
					
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(4):CREACION TABLA TMP_UBIC_ESTANDARIZA_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX(Cod_DW_Ubic)
                                    ,COLUMN(Cod_DW_Fuente_Est)
                                    ,COLUMN(cod_Dw_ciudad)		
					  ON '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242 ;';
													   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(4.1):RECOLECCION ESTADISTICAS  TMP_UBIC_ESTANDARIZA_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		------------------------------------------------------
		-- Busca la tabla TMP_UBIC_ESTANDARIZA_242_1
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_UBIC_ESTANDARIZA_242_1' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		-- Se borra la tabla TMP_UBIC_ESTANDARIZA_242_1 si existe
		--------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242_1';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

							 
		---------------------------------------------------------------
		-- Step 8: Calcular datos de ubicaciones estandarizadas    
		---------------------------------------------------------------   
		SET V_CADENA = '';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242_1
						AS 
						(SELECT b.cod_DW_Ubic, b.Cod_DW_Tipo_Ubicacion /* Cambio propuesto Experian 6-6-17*/
								,b.Texto_Ubicacion
								,e.Descripcion_Fuente			
								,b.Descripcion_Gestion_Registro                                                    
								,b.Cod_DW_Fuente_Est
								,b.cod_Dw_ciudad
								,f.Cod_Dane_Municipio AS Cod_Dane_Ciudad -- Modificado por Experian. Andy Garcia 12-12-2017
								,f.Cod_Dane_Departamento
						FROM '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242 b

						LEFT JOIN '||P_BDVISTA||'.v_Fuente e /*#4*/
						ON b.Cod_DW_Fuente_Est=e.Cod_DW_Fuente

						LEFT JOIN '||P_BDVISTA||'.V_Geografia f 
						ON b.cod_Dw_ciudad=f.cod_dw_ciudad
						)WITH DATA 
						PRIMARY INDEX(cod_DW_Ubic);';
					
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(5):CREACION TABLA TMP_UBIC_ESTANDARIZA_242_1'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;		
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX(Cod_DW_Ubic)  ON '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242_1;';
													   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(5.1):RECOLECCION ESTADISTICAS TMP_UBIC_ESTANDARIZA_242_1'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		------------------------------------------------------
		-- Busca la tabla TMP_UBIC_ESTANDARIZA_242
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_UBIC_ESTANDARIZA_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		-- Se borra la tabla TMP_UBIC_ESTANDARIZA_242 si existe
		--------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          		
							
		------------------------------------------------------
		-- Busca la tabla DATOS_UBIC_ESTANDARIZADAS
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_UBIC_ESTANDARIZADAS' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		-- Se borra la tabla DATOS_UBIC_ESTANDARIZADAS si existe
		--------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_UBIC_ESTANDARIZADAS';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

							 
		---------------------------------------------------------------
		-- Step 8: Calcular datos de ubicaciones estandarizadas    
		---------------------------------------------------------------   
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.DATOS_UBIC_ESTANDARIZADAS, --PASO 16
						NO BEFORE JOURNAL,
						NO AFTER JOURNAL,
						CHECKSUM = DEFAULT
						AS  (SELECT a.*
									  ,b.Cod_DW_Tipo_Ubicacion /* Cambio propuesto Experian 6-6-17*/
									  ,b.Texto_Ubicacion
									  ,b.Descripcion_Fuente
									  ,c.Descripcion_Tipo_Ubicacion_Dir
									  ,b.Descripcion_Gestion_Registro
									  ,(EXTRACT(YEAR FROM a.Fecha_Reporte)*100) + EXTRACT(MONTH FROM a.Fecha_Reporte) Periodo_Reporte
									  ,b.Cod_Dane_Ciudad -- Modificado por Experian. Andy Garcia 12-12-2017
									  ,b.Cod_Dane_Departamento

						   FROM '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE a 

						   INNER JOIN '||P_BDSTAGE||'.TMP_UBIC_ESTANDARIZA_242_1 b  
						   ON a.cod_DW_Ubic=b.Cod_DW_Ubic

						   INNER JOIN '||P_BDVISTA||'.V_Tipo_Ubicacion_Direccion c
						   ON a.Cod_DW_Tipo_Ubicacion_Dir=c.Cod_DW_Tipo_Ubicacion_Dir 

						)WITH DATA
						PRIMARY INDEX (Cod_DW_Reporte_Persona_Ubic,Id_Flag_Desde);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(6):CREACION TABLA DATOS_UBIC_ESTANDARIZADAS'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX(Cod_DW_Reporte_Persona_Ubic,ID_Flag_Desde)
													   ,COLUMN(cod_pin_persona,id_buro_persona)
                        ON '||P_BDSTAGE||'.DATOS_UBIC_ESTANDARIZADAS ;';
													   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(6.1):RECOLECCION ESTADISTICAS  DATOS_UBIC_ESTANDARIZADAS'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		------------------------------------------------------
		-- Busca la tabla VECTOR_UBI_INSUMO_BASE
		------------------------------------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'VECTOR_UBI_INSUMO_BASE' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		--------------------------------------------------------
		-- Se borra la tabla VECTOR_UBI_INSUMO_BASE si existe
		--------------------------------------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.VECTOR_UBI_INSUMO_BASE';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;   	
		
	---------------------------
	-- Busca la tabla TMP_PERSONAS_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PERSONAS_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PERSONAS_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PERSONAS_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;          

							 
	-- Step 9: Calcular datos Tipo Persona

   SET V_CADENA = ' ';
   SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PERSONAS_242
				AS 
				(SEL cod_pin_persona,id_buro_persona,  c.Desc_Tipo_Persona
				FROM '||P_BTTVISTA||'.VU_Persona b
				LEFT JOIN '||P_BTTVISTA||'.V_Tipo_persona c
				ON b.Cod_DW_Tipo_Persona=c.Cod_DW_Tipo_Persona
				)WITH DATA
				PRIMARY INDEX(cod_pin_persona,id_buro_persona);';
					
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(7):CREACION DE LA TABLA  TMP_PERSONAS_242'
								   ,V_ERROR);
										   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
					
										   
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS  INDEX(cod_pin_persona,id_buro_persona)  ON '||P_BDSTAGE||'.TMP_PERSONAS_242;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(7.1):RECOLECCION DE ESTADISTICAS  TMP_PERSONAS_242'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	
	---------------------------
		-- Busca la tabla DATOS_TIPO_PERSONA
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_TIPO_PERSONA' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_TIPO_PERSONA si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_TIPO_PERSONA';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          

								 
		-- Step 9: Calcular datos Tipo Persona

	   SET V_CADENA = ' ';
	   SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.DATOS_TIPO_PERSONA,
					NO BEFORE JOURNAL,
					NO AFTER JOURNAL,
					CHECKSUM = DEFAULT
					AS (SELECT a.*                          
							  ,b.Desc_Tipo_Persona

					FROM '||P_BDSTAGE||'.DATOS_UBIC_ESTANDARIZADAS a

					INNER JOIN '||P_BDSTAGE||'.TMP_PERSONAS_242 b
					ON a.cod_pin_persona=b.cod_pin_persona
					AND a.id_buro_persona=b.id_buro_persona

					)WITH DATA
					PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,ID_Flag_Desde);';
										
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(8):CREACION DE LA TABLA  DATOS_TIPO_PERSONA'
								   ,V_ERROR);
										   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
					
										   
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS  INDEX(Cod_DW_Reporte_Persona_Ubic,ID_Flag_Desde),COLUMN (Cod_DW_Cta) ON '||P_BDSTAGE||'.DATOS_TIPO_PERSONA;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_CALC_UBICACIONES_2(8.1):RECOLECCION DE ESTADISTICAS  DATOS_TIPO_PERSONA'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_PERSONAS_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PERSONAS_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PERSONAS_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PERSONAS_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF; 
					
	---------------------------
	-- Busca la tabla TMP_Desc_Cta_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_Desc_Cta_242' ;

	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_Desc_Cta_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Desc_Cta_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;          
								
	-- Step 10: Calcular datos Tipo Cuenta

	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_Desc_Cta_242
					AS
					(SEL cod_dw_cta,Desc_Tipo_Cta
						FROM '||P_BTTVISTA||'.vu_cuenta b
						LEFT JOIN '||P_BTTVISTA||'.v_tipo_cuenta c
						ON b.cod_dw_tipo_cta=c.cod_dw_tipo_cta
						WHERE Cod_Dw_Cta In (Select cod_dw_cta From '||P_BDSTAGE||'.DATOS_TIPO_PERSONA) 
					)WITH DATA 
					PRIMARY INDEX(cod_dw_cta);';
					
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(9):CREACION DE TABLA  TMP_Desc_Cta_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(cod_dw_cta) ON '||P_BDSTAGE||'.TMP_Desc_Cta_242 ;'; 
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(9.1):RECOLECCION DE ESTADISTICAS  DATOS_TIPO_CUENTA'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
	
	---------------------------
	-- Busca la tabla DATOS_TIPO_CUENTA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'DATOS_TIPO_CUENTA' ;

	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla DATOS_TIPO_CUENTA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_TIPO_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;          
								
	-- Step 10: Calcular datos Tipo Cuenta

	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.DATOS_TIPO_CUENTA,  --PASO18
					NO BEFORE JOURNAL,
					NO AFTER JOURNAL,
					CHECKSUM = DEFAULT
					AS(SELECT a.*,
						 b.Desc_Tipo_Cta
					FROM '||P_BDSTAGE||'.DATOS_TIPO_PERSONA a

					LEFT JOIN '||P_BDSTAGE||'.TMP_Desc_Cta_242 b /*#3*/
					ON a.cod_dw_cta=b.cod_dw_cta
					)
					WITH DATA
					PRIMARY INDEX(Cod_DW_Ubic ,Cod_DW_Direccion_Fisica );';
					
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(10):CREACION DE TABLA  DATOS_TIPO_CUENTA'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
			
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX(Cod_DW_Ubic ,Cod_DW_Direccion_Fisica) ON '||P_BDSTAGE||'.DATOS_TIPO_CUENTA ;'; 
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(10.1):RECOLECCION DE ESTADISTICAS  DATOS_TIPO_CUENTA'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
		
		---------------------------
		-- Busca la tabla DATOS_TIPO_PERSONA
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_TIPO_PERSONA' ;

		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_TIPO_PERSONA si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_TIPO_PERSONA';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;   
		
		---------------------------
		-- Busca la tabla DATOS_UBIC_ESTANDARIZADAS
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_UBIC_ESTANDARIZADAS' ;

		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_UBIC_ESTANDARIZADAS si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_UBIC_ESTANDARIZADAS';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;   
         ---------------------------
		-- Busca la tabla TMP_Desc_Cta_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_Desc_Cta_242' ;

		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_Desc_Cta_242 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Desc_Cta_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;   

		---------------------------
		-- Busca la tabla TMP_AGR_DIRFIS_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_AGR_DIRFIS_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_AGR_DIRFIS_242 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		


		-- Step 11. Calcular datos de complemento y direccion fisica.

		
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242
						AS         
						(SEL cod_dw_ubic, cod_dw_direccion_fisica,  Complemento
						FROM '||P_BDDATOS || '.direccion_fisica b
						Where  (cod_dw_ubic, cod_dw_direccion_fisica) IN (SELECT cod_dw_ubic, cod_dw_direccion_fisica FROM '||P_BDSTAGE||'.DATOS_TIPO_CUENTA where  cod_dw_direccion_fisica > -1 GROUP BY 1, 2)
						)WITH DATA 
						PRIMARY INDEX(cod_dw_direccion_fisica );';
		
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(11):CREACION DE TABLA  TMP_AGR_DIRFIS_242'
									   ,V_ERROR);
								
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
			
			
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE INDEX(cod_dw_direccion_fisica,cod_dw_ubic) ON '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(11.1):CREANDO INDEX A TMP_AGR_DIRFIS_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS  INDEX(cod_dw_direccion_fisica),INDEX(cod_dw_direccion_fisica,cod_dw_ubic) ON '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(11.2):RECOLECCION DE ESTADISTICAS  DATOS_COMPL_DIR_FISICA'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		---------------------------
		-- Busca la tabla DATOS_COMPL_DIR_FISICA
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_COMPL_DIR_FISICA' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_COMPL_DIR_FISICA si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		
		-- Step 11. Calcular datos de complemento y direccion fisica.		
		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET  TABLE '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA,  --PASO19
						NO BEFORE JOURNAL,
						NO AFTER JOURNAL,
						CHECKSUM = DEFAULT
						AS(SELECT a.*
						,TRIM(a.Texto_Ubicacion ||'' ''||COALESCE (b.Complemento ,'' '')) Direccion_Fisica -- Modificado por Experian. Andy Garcia 27-07-2017
						,b.Complemento
						FROM '||P_BDSTAGE||'.DATOS_TIPO_CUENTA a
						LEFT JOIN '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242 b 
						ON a.cod_dw_ubic=b.cod_dw_ubic /*#7 Se anade un join adicional para mejorar el uso de spool  03/10/2018 */
						AND  a.cod_dw_direccion_fisica=b.cod_dw_direccion_fisica
						)WITH DATA
						PRIMARY INDEX(Cod_DW_Ubic);';
		
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(11.3):CREACION DE TABLA  DATOS_COMPL_DIR_FISICA'
									   ,V_ERROR);
								
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS INDEX (Cod_DW_Ubic) ON '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA;';
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(11.1):RECOLECCION DE ESTADISTICAS  DATOS_COMPL_DIR_FISICA'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
		
	    ---------------------------
		-- Busca la tabla DATOS_TIPO_CUENTA
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_TIPO_CUENTA' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_TIPO_CUENTA si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_TIPO_CUENTA';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;  
		
		---------------------------
		-- Busca la tabla TMP_AGR_DIRFIS_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_AGR_DIRFIS_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_AGR_DIRFIS_242 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_DIRFIS_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
					
		---------------------------
		-- Busca la tabla TMP_RelUbicEstanGeo_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_RelUbicEstanGeo_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_RelUbicEstanGeo_242 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelUbicEstanGeo_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		-- Step 12: Calcular datos de latitud, longitud y GEO.

		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_RelUbicEstanGeo_242
						AS 
						(SELECT  b. cod_dw_ubic
								,b.Urbanizacion_Barrio
								,b.Latitud
								,b.Longitud
						FROM '||P_BDDATOS || '.relacion_ubicac_estandar_Geo b
						WHERE cod_dw_ubic IN  (SELECT Cod_Dw_Ubic FROM  '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA  Group by 1)
						)WITH DATA 
						PRIMARY INDEX( cod_dw_ubic);' ;
																			   
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(12):CRECION DE TABLA TMP_RelUbicEstanGeo_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
					

		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STAT INDEX( cod_dw_ubic) ON '||P_BDSTAGE||'.TMP_RelUbicEstanGeo_242;';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(12.1):RECOLECCION DE ESTADISTICAS TMP_RelUbicEstanGeo_242'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		---------------------------
		-- Busca la tabla DIRECCIONES_TEMP
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DIRECCIONES_TEMP' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DIRECCIONES_TEMP si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DIRECCIONES_TEMP';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		-- Step 12: Calcular datos de latitud, longitud y GEO.

		SET V_CADENA = ' ';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.DIRECCIONES_TEMP,  --PASO20
						NO BEFORE JOURNAL,
						NO AFTER JOURNAL,
						CHECKSUM = DEFAULT
						AS(SELECT  a.*,
								  b.Urbanizacion_Barrio,
								  b.Latitud,
								  b.Longitud
						FROM '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA a
						LEFT JOIN '||P_BDSTAGE||'.TMP_RelUbicEstanGeo_242 b -- Modificado por Experian. Andy Garcia 27-07-2017
						ON a.cod_dw_ubic=b.cod_dw_ubic
						)WITH DATA
						PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic,ID_Flag_Desde);';
																			   
							   
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(13):CRECION DE TABLA DIRECCIONES_TEMP'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
					

		SET V_CADENA = ' ';
		SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.DIRECCIONES_TEMP INDEX(Cod_DW_Reporte_Persona_Ubic,ID_Flag_Desde);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									   ,V_StartTimeStampPadre
									   ,:P_Nombre_Proceso_Padre
									   ,:V_CADENA
									   ,'PRO_ORD_CALC_UBICACIONES_2(13.1):RECOLECCION DE ESTADISTICAS DIRECCIONES_TEMP'
									   ,V_ERROR);
							   
		SET P_ERROR = V_ERROR;
					
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
		END IF;
		
			
		---------------------------
		-- Busca la tabla TMP_RelUbicEstanGeo_242
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_RelUbicEstanGeo_242' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla TMP_RelUbicEstanGeo_242 si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelUbicEstanGeo_242';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          
		
		---------------------------
		-- Busca la tabla DATOS_COMPL_DIR_FISICA
		---------------------------
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'DATOS_COMPL_DIR_FISICA' ;
		
		IF ACTIVITY_COUNT > 0 THEN
		-----------------------------
		-- Se borra la tabla DATOS_COMPL_DIR_FISICA si existe
		-----------------------------
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.DATOS_COMPL_DIR_FISICA';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF; 

  END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CONCAT_ATRIBUTOS

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
 * Script:		24.2 -- ORDENAMIENTO. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 
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
-- Busca la tabla CONCATENA_ATRIBUTOS
---------------------------
	SELECT tablename 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND tablename = 'CONCATENA_ATRIBUTOS' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla CONCATENA_ATRIBUTOS si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CONCATENA_ATRIBUTOS';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
		--Step6: Concatenando Atributos para el análisis.
		SET V_CADENA = ' ';
		SET V_CADENA = '
		CREATE MULTISET TABLE '||P_BDSTAGE||'.CONCATENA_ATRIBUTOS,  --PASO13
			 NO BEFORE JOURNAL,
			 NO AFTER JOURNAL,
			 CHECKSUM = DEFAULT
		   AS   (
					SELECT a.*
					,COALESCE(CAST(Cod_Clase_Garantia_BURO_Fte AS VARCHAR(20)),''0'')
					/*||COALESCE(CAST(Probabilidad_Incumplimiento AS VARCHAR(20)),''0'') --NO EXISTE */
					/*||COALESCE(CAST(Ind_Sobregiro AS VARCHAR(20)),''0'') --NO EXISTE */
					||COALESCE(CAST(Valor_Inicial AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Cuota_Mensual AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Saldo AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Numero_Dias_Mora AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Saldo_Mora AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Num_Cuotas_Pagadas AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Disponible AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Num_Cuotas_Mora AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Num_Cuotas_Pactadas AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Debitos_Efec AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Creditos_Efec AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Debitos_Transf AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Creditos_Transf AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Cheques_Pags AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Cheques_Devs AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Valor_Score AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Ind_Rel_Suscriptor AS VARCHAR(20)),''0'')
					||COALESCE(CAST(Ind_TEC_Score AS VARCHAR(20)),''0'') Concatena
					,rec_vista.hash_md5(concatena) cod_hash
					FROM '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP2 a -- 4.) CTA_TOTALES_PERSONAS 
				)
		WITH DATA
		PRIMARY INDEX(Cod_DW_Cta);';
		
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CREACION DE LA TABLA CONCATENA_ATRIBUTOS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDSTAGE||'.CONCATENA_ATRIBUTOS INDEX (Cod_DW_Cta);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS CONCATENA_ATRIBUTOS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
		
		END L1;
	END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CONCAT_DIRECCIONES

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
 * Script:		24.1 -- Materializacion RECONOCER. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 
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


	--CALCULAR HASH CARACTERISTICAS DIRECCIONES tabla REC_DES_STAGE.DIRECCIONES_TEMP.

	/* se elimina segun recomendaciones area Arquitectura Experian 
					,COALESCE(CAST(Cod_DW_Persona_Ubic AS VARCHAR(20)),''''0'''')
					||COALESCE(CAST(Cod_PIN_Persona AS VARCHAR(20)),''''0'''')
					||COALESCE(CAST(Id_Buro_Persona AS VARCHAR(20)),''''0'''') 
					
	*/


---------------------------
-- Busca la tabla hash_Carac_direc
---------------------------
	SELECT tablename 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND tablename = 'hash_Carac_direc' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla hash_Carac_direc si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.hash_Carac_direc';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	SET V_CADENA = ' ';
	SET V_CADENA = '
	CREATE MULTISET TABLE '||P_BDSTAGE||'.hash_Carac_direc,  --PASO13
		 NO BEFORE JOURNAL,
		 NO AFTER JOURNAL,
		 CHECKSUM = DEFAULT
	   AS   (
				SELECT a.*

					,COALESCE(CAST(TRIM(Texto_Ubicacion) AS VARCHAR(100)),''0'')
					||COALESCE(CAST(TRIM(Descripcion_Tipo_Ubicacion_Dir) AS VARCHAR(200)),''0'')
					||COALESCE(CAST(TRIM(Descripcion_Gestion_Registro) AS VARCHAR(200)),''0'')
					||COALESCE(CAST(TRIM(Cod_Dane_Ciudad) AS VARCHAR(20)),''0'')
					||COALESCE(CAST(TRIM(Cod_Dane_Departamento) AS VARCHAR(20)),''0'')
					||COALESCE(CAST(TRIM(Desc_Tipo_Persona) AS VARCHAR(500)),''0'')
					||COALESCE(CAST(TRIM(Desc_Tipo_Cta) AS VARCHAR(500)),''0'')
					||COALESCE(CAST(TRIM(Direccion_Fisica) AS VARCHAR(201)),''0'')
					||COALESCE(CAST(TRIM(Complemento) AS VARCHAR(100)),''0'')
					||COALESCE(CAST(TRIM(Urbanizacion_Barrio) AS VARCHAR(20)),''0'')
					||COALESCE(CAST(TRIM(Latitud) AS VARCHAR(50)),''0'')
					||COALESCE(CAST(TRIM(Longitud) AS VARCHAR(50)),''0'') Concatena
					,rec_vista.hash_md5(concatena) cod_hash
				FROM '||P_BDSTAGE||'.DIRECCIONES_TEMP a
			)WITH DATA
	PRIMARY INDEX (Cod_dw_reporte_Persona_ubic);';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CREACION DE TABLA hash_Carac_direc'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_CTA_ATRIBUTOS

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
 * Objetivo:	Ordenamiento PRO_ORD_CTA_ATRIBUTOS.
 * Fecha:		2017-03-27
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


	-------------------------------------------------------------------------------------------------------------------------
	------------------------------------Incio #3 ----------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------
	-- Busca la tabla CTA_TOTALES_PERSONAS_TMP1
	------------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP1_ANT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	--------------------------------------------------------------
	-- Se borra la tabla CTA_TOTALES_PERSONAS_TMP1_ANT si existe
	--------------------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1_ANT';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

    -----------------------------------------------------------------------------------------------------
	-- Step 1: Calculando las cuentas totales de las personas. CTA_TOTALES_PERSONAS_TMP1_ANT alias paso7
	-----------------------------------------------------------------------------------------------------
    SET V_CADENA = ' ';

    SET V_CADENA=  'CREATE MULTISET TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1_ANT
					AS   (SELECT  b.Cod_DW_Cta
						  ,b.Cod_DW_Tipo_Cta
						  ,b.Cod_Tipo_Cta_Fte
						  ,b.Num_Cta
						  ,b.Id_Buro_Suscriptor
						  ,b.Nit_Suscriptor
						  ,b.Id_Buro_Cliente
						  ,b.Cod_PIN_Persona
						  ,b.Cod_Tipo_Ident_Fte
						  ,b.Num_Ident
						  ,b.Cod_DW_Doc_Ident
						  ,b.Num_Contr
						  ,b.Fecha_Apertura
						  ,b.Fecha_Vencimiento
						  ,b.Ind_Moneda_Legal
						  ,b.Cod_DW_Est_Mod
						  ,b.Cod_Est_Mod_Fte
						  ,b.Ind_Tarjeta_Amparada
						  ,b.Nombre_Ciudad_Radicacion
						  ,b.Cod_DW_Razon_Bloqueo
						  ,b.Num_Plastico
						  ,b.Cod_DW_Clase_Tarjeta_Credito
						  ,b.Cod_Clase_Tarjeta_Credito_Fte
						  ,b.Cod_DW_Franquicia
						  ,b.Cod_Franquicia_Fte
						  ,b.Cod_Marca_Privada_Fte
						  ,b.Cod_DW_Tipo_Rel_con_Cta
						  ,b.Cod_Tipo_Rel_Con_Cta_Fte
						  ,b.Cod_DW_Motivo_Origen
						  ,b.Cod_Motivo_Origen_Fte
						  ,b.Cod_DW_Tipo_Obligacion
						  ,b.Cod_Tipo_Obligacion_Fte
						  ,b.Cod_DW_Clase_Cta
						  ,b.Cod_Clase_Cta_Fte
						  ,b.Cod_DW_Clase_Garantia_BURO
						  ,b.Cod_Clase_Garantia_BURO_Fte
						  ,b.Cod_DW_Tipo_Bloqueo
						  ,b.Cod_Tipo_Bloqueo_Fte
						  ,b.Fecha_Ultima_Actualizacion
						  ,b.Cod_DW_Pais
						  ,b.Cod_Pais_Geo_Fte
						  ,b.Cod_DW_Fte_Dato
						  ,b.Cod_DW_Evento_Entrega_Dato
						  ,b.Nombre_Cod_Entrega_Dato
						  ,b.Desc_Cod_Entrega_Dato
						  ,b.Cod_Entrega_Dato_Fte
						  ,b.Cod_Nov_Buro_Fte
						  ,b.Desc_Est_Vigencia
						  ,b.Fecha_Ultima_Actualizacion_Nov
						  ,b.Cod_DW_Est_Suscriptor
						  ,b.Fecha_Est
						  ,b.Cod_Est_Suscriptor_Fte
						  ,b.Cod_Motivo_Bloqueo_Fte
						  ,b.Cod_DW_Natu_Cta
						  ,b.Cod_Natu_Cta_Fte
						  ,b.Fecha_Nov
						  ,b.Cod_Calif_Comp_Cta_Fte
						  ,id_buro_cliente id_buro_persona      
						  ,CAST( NULL AS DECIMAL(18,4))  Valor_Score
						  ,CAST(NULL AS CHAR(1) ) Ind_Rel_Suscriptor
						  ,CAST(NULL AS CHAR(1) ) Ind_TEC_Score
						  ,b.Cod_Entrega_Dato_Fte cod_suscriptor -- Modificado por Experian. Andy Garcia 07-12-2017   
						  ,b.Cod_DW_Entrega_Dato
						 FROM '||P_BTTVISTA||'.VU_CUENTA b 
						 WHERE  id_buro_cliente IN (SELECT id_buro_persona FROM '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER a )    
						--AND a.cod_pin_persona = b.cod_pin_persona solicitado por experian 2018-10-03 #3
					)
					WITH DATA
					PRIMARY INDEX (Cod_DW_Cta);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_ATRIBUTOS(1):Calculando las cuentas totales de las personas CTA_TOTALES_PERSONAS_TMP1_ANT'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    
	----------------------------------------------------
	-- RECOLECCION DE ESTADISTICAS 	CTA_TOTALES_PERSONAS_TMP1_ANT	
	----------------------------------------------------
		
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STAT  INDEX (Cod_DW_Cta)
							  ,  COLUMN(Id_Buro_Persona)
							  ,  COLUMN(Cod_DW_Razon_Bloqueo)
							  ,  COLUMN(Cod_DW_Fte_Dato)
							  ,  COLUMN(Cod_DW_Entrega_Dato) 
					ON   '||P_BDSTAGE || '.CTA_TOTALES_PERSONAS_TMP1_ANT';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_ATRIBUTOS(1.1):RECOLECCION DE ESTADISTICAS CTA_TOTALES_PERSONAS_TMP1_ANT'
									,V_ERROR);
				
	SET P_ERROR = V_ERROR;
		
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
		----------------------------------------------------
	-- Busca la tabla CTA_TOTALES_PERSONAS_TMP1
	----------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP1' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	---------------------------------------------------------
	-- Se borra la tabla CTA_TOTALES_PERSONAS_TMP1 si existe
	---------------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	-------------------------------------------------------------------------------------------------
	-- Step 1: Calculando las cuentas totales de las personas. CTA_TOTALES_PERSONAS_TMP1 alias paso7
	-------------------------------------------------------------------------------------------------
   SET V_CADENA = ' ';

   SET V_CADENA ='CREATE MULTISET  TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1  AS   
                  (SELECT Cod_DW_Cta
					,b.Cod_DW_Tipo_Cta
					,b.Cod_Tipo_Cta_Fte
					,b.Num_Cta
					,b.Id_Buro_Suscriptor
					,b.Nit_Suscriptor
					,b.Id_Buro_Cliente
					,b.Cod_PIN_Persona
					,b.Cod_Tipo_Ident_Fte
					,b.Num_Ident
					,b.Cod_DW_Doc_Ident
					,b.Num_Contr
					,b.Fecha_Apertura
					,b.Fecha_Vencimiento
					,b.Ind_Moneda_Legal
					,b.Cod_DW_Est_Mod
					,b.Cod_Est_Mod_Fte
					,b.Ind_Tarjeta_Amparada
					,b.Nombre_Ciudad_Radicacion
					,b.Cod_DW_Razon_Bloqueo
					,b.Num_Plastico
					,b.Cod_DW_Clase_Tarjeta_Credito
					,b.Cod_Clase_Tarjeta_Credito_Fte
					,b.Cod_DW_Franquicia
					,b.Cod_Franquicia_Fte
					,b.Cod_Marca_Privada_Fte
					,b.Cod_DW_Tipo_Rel_con_Cta
					,b.Cod_Tipo_Rel_Con_Cta_Fte
					,b.Cod_DW_Motivo_Origen
					,b.Cod_Motivo_Origen_Fte
					,b.Cod_DW_Tipo_Obligacion
					,b.Cod_Tipo_Obligacion_Fte
					,b.Cod_DW_Clase_Cta
					,b.Cod_Clase_Cta_Fte
					,b.Cod_DW_Clase_Garantia_BURO
					,b.Cod_Clase_Garantia_BURO_Fte
					,b.Cod_DW_Tipo_Bloqueo
					,b.Cod_Tipo_Bloqueo_Fte
					,b.Fecha_Ultima_Actualizacion
					,b.Cod_DW_Pais
					,b.Cod_Pais_Geo_Fte
					,b.Cod_DW_Fte_Dato
					,b.Cod_DW_Evento_Entrega_Dato
					,b.Nombre_Cod_Entrega_Dato
					,b.Desc_Cod_Entrega_Dato
					,b.Cod_Entrega_Dato_Fte
					,b.Cod_Nov_Buro_Fte
					,b.Desc_Est_Vigencia
					,b.Fecha_Ultima_Actualizacion_Nov
					,b.Cod_DW_Est_Suscriptor
					,b.Fecha_Est
					,b.Cod_Est_Suscriptor_Fte
					,b.Cod_Motivo_Bloqueo_Fte
					,b.Cod_DW_Natu_Cta
					,b.Cod_Natu_Cta_Fte
					,b.Fecha_Nov
					,b.Cod_Calif_Comp_Cta_Fte
					,b.id_buro_persona
					,c.Cod_Razon_Bloqueo_Fte
					,d.Cod_Fte_Dato_Fte
					,e.Fecha_Ingreso_Suscriptor
					,b.Valor_Score
					,b.Ind_Rel_Suscriptor
					,b.Ind_TEC_Score
					,b.cod_suscriptor -- Modificado por Experian. Andy Garcia 07-12-2017

				FROM '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1_ANT b
				LEFT JOIN '||P_BTTVISTA||'.V_Razon_Bloqueo c -- Modificado por Experian. Andy Garcia 31-07-2017
				ON b.Cod_DW_Razon_Bloqueo = c.Cod_DW_Razon_Bloqueo

				LEFT JOIN  '||P_BTTVISTA||'.V_FUENTE_DATO d -- Modificado por Experian. Andy Garcia 31-07-2017
				ON b.Cod_DW_Fte_Dato = d.Cod_DW_Fte_Dato

				LEFT JOIN '||P_BTTVISTA||'.V_COD_ENTREGA_DATO e -- Modificado por Experian. Andy Garcia 31-07-2017
				ON b.Cod_DW_Entrega_Dato= e.Cod_DW_Entrega_Dato -- Modificado para usar el Cod_DW_Entrega_Dato 03/10/2018.																				

						)
				WITH DATA
				PRIMARY INDEX (Cod_DW_Cta);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_ATRIBUTOS(2):Calculando las cuentas totales de las personas.CTA_TOTALES_PERSONAS_TMP1'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


	-----------------------------------------------------
	--#4 Busca la tabla CTA_TOTALES_PERSONAS_TMP1_ANT
	----------------------------------------------------
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CTA_TOTALES_PERSONAS_TMP1_ANT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------------------------------------------
	--#4 Se borra la tabla CTA_TOTALES_PERSONAS_TMP1_ANT si existe
	-----------------------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1_ANT';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
	-------------------------------------------------------------
	-- RECOLECCION DE ESTADISTICAS 	CTA_TOTALES_PERSONAS_TMP1	
    -------------------------------------------------------------
		
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.CTA_TOTALES_PERSONAS_TMP1 INDEX(Cod_DW_Cta);';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_CTA_ATRIBUTOS(2.1):RECOLECCION DE ESTADISTICAS CTA_TOTALES_PERSONAS_TMP1'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
		
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	

	----------------------------------------------------------------------------------------------------------------------------------------------------------
	----------------------------------FIN #3 -----------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------------------------------------------
		
 END L1;
END;

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

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_FINAL_CTA_ATRIBUTOS

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
 * Objetivo:	MaterializaciÃ¸Â³n tablas BTT y Reconocer Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- ORDENAMIENTO FINAL_CTA_ATRIBUTOS. 
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
	DECLARE V_PASO INTEGER;
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:	BEGIN
    SET V_PASO = 1;
    SET P_ERROR = CAST('' AS VARCHAR(50));
   IF V_PASO > 0 THEN
		LEAVE L1;
	END IF;


---------------------------
-- Busca la tabla NUEVOS_DATOS_CARACT_ATRIBUTO
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'NUEVOS_DATOS_CARACT_ATRIBUTO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla NUEVOS_DATOS_CARACT_ATRIBUTO si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_CARACT_ATRIBUTO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
		-- Step 7: Calculando los potenciales para Calculo de Caracteristicas.
		SET V_CADENA = ' ';
		SET V_CADENA = '
		CREATE MULTISET TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_CARACT_ATRIBUTO,  --PASO14
		 NO BEFORE JOURNAL,
		 NO AFTER JOURNAL,
		 CHECKSUM = DEFAULT
	   AS   (
				SELECT a.*
				FROM '||P_BDSTAGE||'.CONCATENA_ATRIBUTOS a
				LEFT JOIN '||P_BDVISTA||'.V_CUENTA_ATRIBUTO_HASH b -- Atributo_HASH
				ON a.Cod_Pin_Persona=b.Cod_Pin_Persona
				AND a.Id_Buro_Persona=b.Id_Buro_Persona
				AND a.Cod_DW_Cta=b.Cod_DW_Cta
				AND a.cod_hash=b.Cod_DW_HASH
				WHERE b.cod_pin_persona IS NULL
				AND b.Id_Buro_Persona IS NULL
				AND b.Cod_DW_Cta IS NULL
				AND b.Cod_DW_HASH IS NULL
			)
			WITH DATA
			PRIMARY INDEX (cod_dw_cta);';
		
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CREACION DE LA TABLA NUEVOS_DATOS_CARACT_ATRIBUTO'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDSTAGE||'.NUEVOS_DATOS_CARACT_ATRIBUTO INDEX (cod_dw_cta);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS NUEVOS_DATOS_CARACT_ATRIBUTO'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
			SET V_CADENA = ' ';
		SET V_CADENA = '
		INSERT INTO REC_DATOS.CUENTA_ATRIBUTO_HASH (Cod_Pin_Persona ,Id_Buro_Persona ,Cod_DW_Cta ,Cod_DW_HASH ,Fecha_Nov )
		SELECT a.Cod_Pin_Persona
		,a.Id_Buro_Persona
		,a.Cod_DW_Cta
		,cod_hash
		,DATE
		FROM '||P_BDSTAGE||'.NUEVOS_DATOS_CARACT_ATRIBUTO a;';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CARGA DE LA TABLA CUENTA_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

			SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDDATOS||'.CUENTA_ATRIBUTO_HASH INDEX (cod_dw_cta);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS CUENTA_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


	/*
 * ################################################################################
 * Por solicitud de Experian se deja en comentario esta parte del codigo Puesto no se va a necesitar

			SET V_CADENA = ' ';
		SET V_CADENA = '
		UPDATE A
FROM '||P_BDDATOS||'.CUENTA_ATRIBUTO_HASH a
 , '||P_BDSTAGE||'.CONCATENA_ATRIBUTOS B
SET Cod_DW_HASH=B.Cod_HASH
WHERE     a.Cod_Pin_Persona=b.Cod_Pin_Persona
				AND a.Id_Buro_Persona=b.Id_Buro_Persona
				AND a.Cod_DW_Cta=b.Cod_DW_Cta
				AND a.Cod_DW_HASH<>b.Cod_HASH;
		';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'ACTUALIZACION DE LA TABLA CUENTA_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	 */
		
  END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_FINAL_UBIC_DIRECCIONES

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
 * Objetivo:	MaterializaciÃ¸ÆÃ´Â³n tablas BTT y Reconocer Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- ORDENAMIENTO FINAL_UBIC_DIRECCIONES. 
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
	DECLARE V_PASO INTEGER;
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:	BEGIN

    SET V_PASO = 1;
    SET P_ERROR = CAST('' AS VARCHAR(50));
   
    IF V_PASO > 0 THEN
		LEAVE L1;
	END IF;
---------------------------
-- Busca la tabla NUEVOS_DATOS_DIRECCIONES
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'NUEVOS_DATOS_DIRECCIONES' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla P_BDSTAGE si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

-- Step 7: Calculando los potenciales para Calculo de Caracteristicas.
		SET V_CADENA = ' ';
		SET V_CADENA = '

-- Validacion de los cambios en hash.
 
CREATE MULTISET TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES,  
		 NO BEFORE JOURNAL,
		 NO AFTER JOURNAL,
		 CHECKSUM = DEFAULT
	   AS   (

			SELECT a.*
			FROM (SELECT UNIQUE cod_pin_persona,
							id_buro_persona,
							Cod_DW_Persona_Ubic,
							COALESCE(CAST(TRIM(Texto_Ubicacion) AS VARCHAR(100)),''0'')
								||COALESCE(CAST(TRIM(Descripcion_Tipo_Ubicacion_Dir) AS VARCHAR(200)),''0'')
								||COALESCE(CAST(TRIM(Descripcion_Gestion_Registro) AS VARCHAR(200)),''0'')
								||COALESCE(CAST(TRIM(Cod_Dane_Ciudad) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Cod_Dane_Departamento) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Desc_Tipo_Persona) AS VARCHAR(500)),''0'')
								||COALESCE(CAST(TRIM(Desc_Tipo_Cta) AS VARCHAR(500)),''0'')
								||COALESCE(CAST(TRIM(Direccion_Fisica) AS VARCHAR(201)),''0'')
								||COALESCE(CAST(TRIM(Complemento) AS VARCHAR(100)),''0'')
								||COALESCE(CAST(TRIM(Urbanizacion_Barrio) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Latitud) AS VARCHAR(50)),''0'')
								||COALESCE(CAST(TRIM(Longitud) AS VARCHAR(50)),''0'') Concatena
								,'||P_BDVISTA||'.hash_md5 (Concatena) Cod_DW_Hash
								FROM '||P_BDSTAGE||'.DIRECCIONES_TEMP
								) a
			LEFT JOIN '||P_BDVISTA||'.V_UBICACION_ATRIBUTO_HASH b
			ON a.cod_pin_persona=b.cod_pin_persona
			AND a.id_buro_persona=b.id_buro_persona
			AND a.Cod_DW_Persona_Ubic=b.Cod_DW_Persona_Ubic
			AND a.Cod_DW_Hash=b.Cod_DW_Hash
			WHERE b. cod_pin_persona IS NULL
			AND b. id_buro_persona IS NULL
			AND b. cod_dw_persona_ubic IS NULL
			AND b.cod_dw_hash IS NULL
			)
			WITH DATA
			PRIMARY INDEX(Cod_DW_Persona_Ubic);';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CREACION DE LA TABLA NUEVOS_DATOS_DIRECCIONES'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES INDEX (Cod_DW_Persona_Ubic);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS NUEVOS_DATOS_DIRECCIONES'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
			SET V_CADENA = ' ';
		SET V_CADENA = '
		INSERT INTO '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH (Cod_Pin_Persona ,Id_Buro_Persona ,Cod_DW_Persona_Ubic ,Cod_DW_HASH ,Fecha_Nov )
		SELECT a.Cod_Pin_Persona
		,a.Id_Buro_Persona
		,a.Cod_DW_Persona_Ubic
		,a.cod_dw_hash
		,DATE
		FROM '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES a;';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CARGA DE LA TABLA UBICACION_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

			SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH INDEX (Cod_DW_Persona_Ubic);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS UBICACION_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	/*
 * ################################################################################
 * Por solicitud de Experian se deja en comentario esta parte del codigo Puesto no se va a necesitar
	
SET V_CADENA = ' ';
		SET V_CADENA = '
		UPDATE A
FROM '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH a
 , '||P_BDSTAGE||'.hash_Carac_direc B
SET Cod_DW_HASH=B.Cod_HASH
WHERE     a.Cod_Pin_Persona=b.Cod_Pin_Persona
				AND a.Id_Buro_Persona=b.Id_Buro_Persona
				AND a.cod_dw_persona_ubic=b.cod_dw_persona_ubic
				AND a.Cod_DW_HASH<>b.Cod_HASH;
		';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'ACTUALIZACION DE LA TABLA CUENTA_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	 */
	
		END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_FINAL_UBIC_DIRECCIONES1

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
 * Script:		24.2 -- ORDENAMIENTO FINAL_UBIC_DIRECCIONES. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 
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
-- Busca la tabla NUEVOS_DATOS_DIRECCIONES
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'NUEVOS_DATOS_DIRECCIONES' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla P_BDSTAGE si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

-- Step 7: Calculando los potenciales para Calculo de Caracteristicas.
		SET V_CADENA = ' ';
		SET V_CADENA = '

-- Validacion de los cambios en hash.
 
CREATE MULTISET TABLE '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES,  
		 NO BEFORE JOURNAL,
		 NO AFTER JOURNAL,
		 CHECKSUM = DEFAULT
	   AS   (

			SELECT a.*
			FROM (SELECT UNIQUE cod_pin_persona,
							id_buro_persona,
							Cod_DW_Persona_Ubic,
							COALESCE(CAST(TRIM(Texto_Ubicacion) AS VARCHAR(100)),''0'')
								||COALESCE(CAST(TRIM(Descripcion_Tipo_Ubicacion_Dir) AS VARCHAR(200)),''0'')
								||COALESCE(CAST(TRIM(Descripcion_Gestion_Registro) AS VARCHAR(200)),''0'')
								||COALESCE(CAST(TRIM(Cod_Dane_Ciudad) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Cod_Dane_Departamento) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Desc_Tipo_Persona) AS VARCHAR(500)),''0'')
								||COALESCE(CAST(TRIM(Desc_Tipo_Cta) AS VARCHAR(500)),''0'')
								||COALESCE(CAST(TRIM(Direccion_Fisica) AS VARCHAR(201)),''0'')
								||COALESCE(CAST(TRIM(Complemento) AS VARCHAR(100)),''0'')
								||COALESCE(CAST(TRIM(Urbanizacion_Barrio) AS VARCHAR(20)),''0'')
								||COALESCE(CAST(TRIM(Latitud) AS VARCHAR(50)),''0'')
								||COALESCE(CAST(TRIM(Longitud) AS VARCHAR(50)),''0'') Concatena
								,'||P_BDVISTA||'.hash_md5 (Concatena) Cod_DW_Hash
								FROM '||P_BDSTAGE||'.DIRECCIONES_TEMP
								) a
			LEFT JOIN '||P_BDVISTA||'.V_UBICACION_ATRIBUTO_HASH b
			ON a.cod_pin_persona=b.cod_pin_persona
			AND a.id_buro_persona=b.id_buro_persona
			AND a.Cod_DW_Persona_Ubic=b.Cod_DW_Persona_Ubic
			AND a.Cod_DW_Hash=b.Cod_DW_Hash
			WHERE b. cod_pin_persona IS NULL
			AND b. id_buro_persona IS NULL
			AND b. cod_dw_persona_ubic IS NULL
			AND b.cod_dw_hash IS NULL
			)
			WITH DATA
			PRIMARY INDEX(Cod_DW_Persona_Ubic);';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CREACION DE LA TABLA NUEVOS_DATOS_DIRECCIONES'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
		
		
		SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES INDEX (Cod_DW_Persona_Ubic);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS NUEVOS_DATOS_DIRECCIONES'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
			SET V_CADENA = ' ';
		SET V_CADENA = '
		INSERT INTO '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH (Cod_Pin_Persona ,Id_Buro_Persona ,Cod_DW_Persona_Ubic ,Cod_DW_HASH ,Fecha_Nov )
		SELECT a.Cod_Pin_Persona
		,a.Id_Buro_Persona
		,a.Cod_DW_Persona_Ubic
		,a.cod_dw_hash
		,DATE
		FROM '||P_BDSTAGE||'.NUEVOS_DATOS_DIRECCIONES a;';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'CARGA DE LA TABLA UBICACION_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

			SET V_CADENA = ' ';
		SET V_CADENA = '
		COLLECT STATISTICS ON '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH INDEX (Cod_DW_Persona_Ubic);';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'RECOLECCION DE ESTADISTICAS UBICACION_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
SET V_CADENA = ' ';
		SET V_CADENA = '
		UPDATE A
FROM '||P_BDDATOS||'.UBICACION_ATRIBUTO_HASH a
 , '||P_BDSTAGE||'.hash_Carac_direc B
SET Cod_DW_HASH=B.Cod_HASH
WHERE     a.Cod_Pin_Persona=b.Cod_Pin_Persona
				AND a.Id_Buro_Persona=b.Id_Buro_Persona
				AND a.cod_dw_persona_ubic=b.cod_dw_persona_ubic
				AND a.Cod_DW_HASH<>b.Cod_HASH
				AND a.FECHA_NOV=B.Fecha_Reporte;
		';
		
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'ACTUALIZACION DE LA TABLA CUENTA_ATRIBUTO_HASH'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
		END L1;
	END;

REPLACE PROCEDURE REC_DATOS.PRO_ORD_MATERIALIZA_BTT
	(
		 IN	P_Lote						INTEGER
		,IN	P_StartTimeStampPadre		VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDDATOS				VARCHAR(20)
		,IN	P_BDVISTA					VARCHAR(20)
		,IN	P_BDSTAGE					VARCHAR(20)
		,IN	P_BTTDATOS				VARCHAR(20)
		,IN	P_BTTVISTA					VARCHAR(20)
		,IN	P_BDMTDAT				VARCHAR(20)
		,IN	P_BTTMTDAT					VARCHAR(20)
		,IN P_VARQUERY1	/*#2*/			VARCHAR (500)
		,OUT P_ERROR		VARCHAR(50)
	)

/*
 * ################################################################################
 * 
 * Objetivo:	Materialización tablas BTT Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Materializacion BTT. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 25/09/2018   #1 Uso de la Vista VU_Cuenta     Andy Garcia
 * Fecha:2018-09-26  Objetivo=#2 Se agrega IN P_VARQUERY  Realizado por: CARLOS CASTILLO
 * 27/12/2018  Optimizar SP         Fernando Garrido M.
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
 *                                 METADATA TABLAS BDM_%  Modelo BTT
 * 
 * ################################################################################
 */
 
-- 1. Definir la fecha de Ultimo Ordenamiento. (YA CREADA, SOLO CONSUMIRLA)


BEGIN

------------------------
-- DeclaraciÃ³n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR				VARCHAR(30);
	DECLARE V_CADENA				VARCHAR(32000);
	DECLARE V_TABLE					VARCHAR(30);
	DECLARE Temp 					CHAR(30);
	DECLARE V_VARQUERY1			VARCHAR(500);
	DECLARE V_VARQUERY2			VARCHAR(500);
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_VARQUERY1 = NULLIF(TRIM(P_VARQUERY1),''); /*#2*/
L1:	
BEGIN

---------------------------
-- Busca la tabla Estructuras_MTDAT_BDM
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Estructuras_MTDAT_BDM' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla Estructuras_MTDAT_BDM si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.Estructuras_MTDAT_BDM';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	-----------------------------
	-- Convirtiendo fecha de varchar a date
	-----------------------------

    SET V_CADENA = '';
	SET V_CADENA = ' CREATE MULTISET TABLE  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS (SELECT  No_Lote
								,Tabla1 
								,Insert_1
								,Update_1
								,descripcion
								,CAST(CAST (fecha AS DATE )+36525 AS DATE) FechaProc
								,fecha
  						  FROM bdm_mtdat.MetadataCargaLog 
						) WITH DATA
					PRIMARY INDEX ( No_Lote );';


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(1):Convirtiendo fecha de varchar a date.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


  /*otro query*/
	
    SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM column(No_Lote);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(1.1):Recolectar estadisticas Estructuras_MTDAT_BDM .'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	---------------------------
	-- Busca la tabla CALCULA_LOTE_BTT
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'CALCULA_LOTE_BTT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla CALCULA_LOTE_BTT si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.CALCULA_LOTE_BTT';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	-----------------------------------------------------------------------------------------------------
	---------------- CALCULO QUERY DINAMICO /*#2*/ -----------------------------------------------
	-----------------------------------------------------------------------------------------------------


	SELECT CAMPO
	INTO :V_VARQUERY2
	FROM 
	(SELECT 	CASE WHEN V_VARQUERY1 IS NULL  THEN 
	' INNER JOIN '||P_BDMTDAT||'.Control_Ordenamiento b -- se debe crear en stage alli se almacena la fecha de la ultima vez que se actualiza el proceso
	ON a.FechaProc>=b.Fecha_Ult_Ord
	AND a.Tabla1 IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BTTVISTA||''') -- SUBSELECT PARA EXTRAER WHERE ESQUEMA = BDM
	AND (a.Insert_1>0 OR a.Update_1>0)
	AND TRIM(a.Descripcion)=''Ok'' '
	ELSE 'WHERE a.FechaProc '||V_VARQUERY1||'
	AND a.Tabla1 IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BTTVISTA||''') -- SUBSELECT PARA EXTRAER WHERE ESQUEMA = BDM
	AND (a.Insert_1>0 OR a.Update_1>0)
	AND TRIM(a.Descripcion)=''Ok''' END AS CAMPO
	) A
	;

		
	-- Calculando los Lotes para BTT, Fechas y Tablas a validar.
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.CALCULA_LOTE_BTT ,
						 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
				    AS(SELECT a.No_Lote, a.FechaProc, a.Tabla1  -- actualizar la volatil con los campos que se van a tra
					   FROM  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM a
					   '||V_VARQUERY2||' /*#2*/
					)WITH DATA
					PRIMARY INDEX(No_Lote);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(2):Calculando los Lotes para BTT, Fechas y Tablas a validar.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	/*otro query*/
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.CALCULA_LOTE_BTT INDEX(No_Lote);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(2.1):Recolectar estadisticas CALCULA_LOTE_BTT.'
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	
	
---------------------------
-- Busca la tabla PASO_V_CUENTA
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_CUENTA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla PASO_V_CUENTA si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
-- Calculando los Id_buro_persona, Cod_Pin_Persona para las Cuentas modificadas.

	SET V_CADENA = '';
	SET V_CADENA = ' CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_CUENTA ,
						 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
						 AS  (
					SELECT c.Cod_Pin_Persona,
						a.Id_Buro_Cliente Id_Buro_Persona
					FROM '||P_BTTVISTA||'.V_CUENTA a
					INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
					ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
					AND (B.TABLA1 =''CUENTA'')

					INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
					ON a.Id_Buro_Cliente=c.Id_Buro_Persona
					
					Group by 1,2
					)
					WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(3):Calculando los Id_buro_persona, Cod_Pin_Persona para las Cuentas modificadas'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_CUENTA INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(3.1):Recolecion estadisticas PASO_V_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	---------------------------
	-- Busca la tabla PASO_V_BURO_PERSONA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_BURO_PERSONA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_BURO_PERSONA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_BURO_PERSONA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    --*************creacion tabla PASO_V_BURO_PERSONA *******************
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_BURO_PERSONA ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS (SELECT  a.Cod_Pin_Persona,
							a.Id_Buro_Persona
						FROM '||P_BTTVISTA||'.V_BURO_PERSONA a
							INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
							ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
								AND (B.TABLA1 =''BURO_PERSONA'')
								
						Group by 1,2
						)
				WITH DATA
				PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
					
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(4):creacion tabla PASO_V_BURO_PERSONA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_BURO_PERSONA INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(4.1):Recoleccion estadisticas PASO_V_BURO_PERSONA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla TMP_PASO_COMCTA_242
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PASO_COMCTA_242
					AS 
					(SEL Cod_DW_Cta
					FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA a
					Where a.Lote IN (SEL No_Lote FROM  REC_STAGE.CALCULA_LOTE_BTT  WHERE TABLA1 =''COMPORTAMIENTO_CUENTA'' )
					OR a.Lote_Actualizacion IN (SEL No_Lote FROM  REC_STAGE.CALCULA_LOTE_BTT  WHERE TABLA1 =''COMPORTAMIENTO_CUENTA'' )
					Group by 1 
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Cta);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5):creacion tabla TMP_PASO_COMCTA_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_PASO_COMCTA_242 INDEX(Cod_DW_Cta); ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5.1):recoleccion estadisticas TMP_PASO_COMCTA_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_1_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_1_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_1_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_1_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla TMP_PASO_COMCTA_1_242
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242
					AS 
					(SEL Id_Buro_Cliente
					FROM '||P_BTTVISTA||'.VU_CUENTA
					WHERE Cod_DW_Cta IN (SELECT Cod_DW_Cta FROM '||P_BDSTAGE||'.TMP_PASO_COMCTA_242)
					Group by 1 )
					WITH DATA 
					PRIMARY INDEX( Id_Buro_Cliente );';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(6):creacion tabla TMP_PASO_COMCTA_1_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242 INDEX(Id_Buro_Cliente);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(6.1):recoleccion estadisticas TMP_PASO_COMCTA_1_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
	---------------------------
	-- Busca la tabla PASO_V_COMPORTAMIENTO_CUENTA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORTAMIENTO_CUENTA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORTAMIENTO_CUENTA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORTAMIENTO_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla PASO_V_COMPORTAMIENTO_CUENTA
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS  
					(SELECT  c.Cod_Pin_Persona,
							a.Id_Buro_Cliente Id_Buro_Persona
				      FROM  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242 a

					  INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
					  ON a.Id_Buro_Cliente=c.Id_Buro_Persona
					  group by 1,2
					)
					WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5):creacion tabla PASO_V_COMPORTAMIENTO_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA INDEX(Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5.1):recoleccion estadisticas PASO_V_COMPORTAMIENTO_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
    -- Busca la tabla TMP_PASO_COMCTA_1_242
      ---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_1_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_1_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_1_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
	---------------------------
    -- Busca la tabla PASO_V_COMPORT_CTA_ACTIVO
      ---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORT_CTA_ACTIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_ACTIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORT_CTA_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
	
    -- creacion tabla PASO_V_COMPORT_CTA_ACTIVO
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
			        AS (SELECT c.Cod_Pin_Persona,
         						x.Id_Buro_Cliente Id_Buro_Persona
						FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA_ACTIVO a


						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
						ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
						AND (B.TABLA1 =''COMPORTAMIENTO_CUENTA_ACTIVO'')

						inner join '||P_BTTVISTA||'.VU_CUENTA x /*#1*/
						on a.Cod_DW_Cta = x.Cod_DW_Cta


						INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
						ON x.Id_Buro_Cliente=c.Id_Buro_Persona
						
						Group by 1,2
						)
						WITH DATA
						PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(7):creacion tabla PASO_V_COMPORT_CTA_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO INDEX(Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(7.1):recolectar estadisticas PASO_V_COMPORT_CTA_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	---------------------------
	-- Busca la tabla PASO_V_COMPORT_CTA_PASIVO
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORT_CTA_PASIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_PASIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORT_CTA_PASIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
		
	
	
    --*creacion tabla PASO_V_COMPORT_CTA_PASIVO
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO ,
							 NO BEFORE JOURNAL,
							 NO AFTER JOURNAL,
							 CHECKSUM = DEFAULT
					AS  (SELECT c.Cod_Pin_Persona,
								x.Id_Buro_Cliente Id_Buro_Persona
						FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA_PASIVO a

						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
						ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
						AND (B.TABLA1 =''COMPORTAMIENTO_CUENTA_PASIVO'')
							
						inner join '||P_BTTVISTA||'.VU_CUENTA x /*#1*/
						on a.Cod_DW_Cta = x.Cod_DW_Cta
							

						INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
                        ON x.Id_Buro_Cliente=c.Id_Buro_Persona
						Group by 1,2
					)WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(8):creacion tabla PASO_V_COMPORT_CTA_PASIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(8.1):Recoleccion estadisticas PASO_V_COMPORT_CTA_PASIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_MATERIALIZA_REC

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
		,IN	P_BTTMTDAT				VARCHAR(20)
		,IN P_VARQUERY1	/*#2*/			VARCHAR (500)
		,OUT P_ERROR						VARCHAR(50)
	)


/*
 * ################################################################################
 * 
 * Objetivo:	Materialización tablas Reconocer Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.1 -- Materializacion RECONOCER. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * #1   2018-09-18  		Incluir valor en filtros para Lotes desde Log_TD
 * Fecha:2018-09-26  Objetivo=#2 Se agrega IN P_VARQUERY  Realizado por: CARLOS CASTILLO
 * 27/12/2018  Optimizar SP         Fernando Garrido M.
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
	
	------------------------------
	-- Declaracion de variables
	------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_TABLE			VARCHAR(30);
	DECLARE Temp CHAR(30);
	DECLARE V_VARQUERY1			VARCHAR(500);
	DECLARE V_VARQUERY2			VARCHAR(500);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_VARQUERY1 = NULLIF(TRIM(P_VARQUERY1),''); /*#2*/
	
L1:	BEGIN
	--------------------------------------
	-- Busca la tabla CALCULA_LOTE_REC
	--------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'CALCULA_LOTE_REC' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	---------------------------------------------------
	-- Se borra la tabla CALCULA_LOTE_REC si existe
	---------------------------------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CALCULA_LOTE_REC';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	-----------------------------------------------------------------------------------------------------
	---------------- CALCULO QUERY DINAMICO /*#2*/ -----------------------------------------------
	-----------------------------------------------------------------------------------------------------

	SELECT CAMPO
	INTO :V_VARQUERY2
	FROM
	(SELECT 	CASE WHEN V_VARQUERY1 IS NULL  THEN 
	' INNER JOIN '||P_BDMTDAT||'.Control_Ordenamiento b
		ON a.Fecha_Hora_Inicio>=b.Fecha_Ult_Ord
		AND trim(a.Tabla_Destino_Prod) IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BDVISTA||''')
		AND a.Estado_Ejecucion in (''Cargue Ok'',''Finalizado OK'') -- #1 '
	ELSE 'WHERE a.Fecha_Hora_Inicio '||V_VARQUERY1||'
	  AND trim(a.Tabla_Destino_Prod) IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BDVISTA||''')
	 AND a.Estado_Ejecucion in (''Cargue Ok'',''Finalizado OK'') -- #1' END AS CAMPO
	) A
	;/*#2*/
   --Calculando los lotes para el Modelo Reconocer
    SET V_CADENA = ' ';
	SET V_CADENA = ' CREATE	MULTISET TABLE  '||P_BDSTAGE||'.CALCULA_LOTE_REC ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					AS (
								SELECT 
									a.Lote,
									a.Fecha_Hora_Inicio,
									a.Tabla_Destino_Prod
								FROM '||P_BDMTDAT||'.log_td a
									
									'||V_VARQUERY2||' /*#2*/
									
							)
				WITH DATA
				PRIMARY INDEX (Lote);
				 ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_RECC(1):alculando los lotes para el Modelo Reconocer.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	  SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.CALCULA_LOTE_REC INDEX(Lote) ; ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(1.1):recolectar estadisticas CALCULA_LOTE_REC.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla PASO_REPORTE_UBIC_ORIGINAL
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_REPORTE_UBIC_ORIGINAL' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_REPORTE_UBIC_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	-- Calculando para la tabla Reporte_Ubicacion_Original las personas que deben aplicar Calculo Atributos
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET  TABLE  '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS (
						SELECT a.Cod_Pin_Persona, 
										  a.Id_Buro_Persona
						FROM '||P_BDVISTA||'.V_reporte_ubicacion_original a    
						 WHERE LOTE IN  ( SEL  LOTE FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''REPORTE_UBICACION_ORIGINAL'')
						 OR lote_Actualizacion IN   ( SEL  LOTE FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''REPORTE_UBICACION_ORIGINAL'')
						 group by 1, 2 
						)
					WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(2):Creando Tabla PASO_REPORTE_UBIC_ORIGINAL'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
   SET V_CADENA = '';
   SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
   CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(2.1):Ejecutando Estadisticas a PASO_REPORTE_UBIC_ORIGINAL'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla PASO_RPU
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_RPU' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_RPU si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_RPU';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    -- CREACION TABLA PASO_RPU
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_RPU ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS ( SELECT a.Cod_Pin_Persona, 
								   a.Id_Buro_Persona
							FROM '||P_BDVISTA||'.VU_RELACION_PERSONA_UBICACION a
							INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_REC b
							ON (a.lote=b.lote OR a.lote_Actualizacion=b.lote)
							AND (B.Tabla_Destino_Prod =''RELACION_PERSONA_UBICACION'')
							Group by 1,2
						  )WITH DATA
					  PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(3):CREACION TABLA PASO_RPU'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

    SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_RPU INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(3.1):CREACION TABLA PASO_RPU'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	---------------------------
	-- Busca la tabla TMP_PASO_RRPU_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PASO_RRPU_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_RRPU_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PASO_RRPU_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

   -- CREACION TABLA TMP_PASO_RRPU_242
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PASO_RRPU_242
					AS
					(SEL Cod_DW_Persona_Ubic
					FROM '||P_BDVISTA||'.VU_Reporte_Relacion_Pers_Ubi 
					WHERE lote IN  (SEL lote FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''REPORTE_RELACION_PERSONA_UBICA'') 
					OR lote_Actualizacion  IN (SEL lote FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''REPORTE_RELACION_PERSONA_UBICA'') 
					GROUP BY 1
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Persona_Ubic); ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(4):CREACION TABLA TMP_PASO_RRPU_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

    SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_PASO_RRPU_242 INDEX(Cod_DW_Persona_Ubic);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(4.1):Ejecuta Estadisticas a TMP_PASO_RRPU_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ---------------------------
	-- Busca la tabla PASO_RRPU
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_RRPU' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_RRPU si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_RRPU';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

   -- CREACION TABLA PASO_RRPU
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_RRPU ,NO FALLBACK ,
					NO BEFORE JOURNAL,
					NO AFTER JOURNAL,
					CHECKSUM = DEFAULT
					AS 
					(SELECT  b.Cod_Pin_Persona,
							 b.Id_Buro_Persona
					FROM '||P_BDSTAGE||'.TMP_PASO_RRPU_242 a
					INNER JOIN  '||P_BDVISTA||'.VU_RELACION_PERSONA_UBICACION b
					ON a.Cod_DW_Persona_Ubic=b.Cod_DW_Persona_Ubic
					Group by 1,2
					)WITH DATA 
					PRIMARY INDEX(Cod_Pin_Persona,Id_Buro_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(4):CREACION TABLA PASO_RRPU'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

    SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_RRPU INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(4.1):Ejecuta estadisticas a PASO_RRPU'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
			
    ---------------------------
	-- Busca la tabla TMP_PASO_RRPU_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PASO_RRPU_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_RRPU_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PASO_RRPU_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	---------------------------
	-- Busca la tabla PASO_V_BLOQUEO
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_BLOQUEO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_BLOQUEO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_BLOQUEO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
			
	--****************** CREACION PASO_V_BLOQUEO **************
    SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_BLOQUEO ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS (SELECT x.Cod_Pin_Persona,
								 x.Id_Buro_Persona
						 FROM '||P_BDVISTA||'.V_BLOQUEO a
						
						INNER JOIN '||P_BDMTDAT||'.Control_Ordenamiento b 
						ON a.Fecha_Bloqueo>= b.Fecha_Ult_Ord

						INNER JOIN '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION x
						ON (a.Cod_DW_Persona_Ubic=x.Cod_DW_Persona_Ubic)
						group by 1,2
						)WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(5):CREACION PASO_V_BLOQUEO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_BLOQUEO INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(5.1):COLLECT STATISTICS PASO_V_BLOQUEO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	---------------------------
	-- Busca la tabla TMP_RELAUBICESTANGEO_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RELAUBICESTANGEO_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RELAUBICESTANGEO_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RELAUBICESTANGEO_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	--*************** revisar2 *****************
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_RELAUBICESTANGEO_242
					AS 
					(SEL Cod_DW_Ubic
					 FROM  '||P_BDVISTA||'.v_RELACION_UBICAC_ESTANDAR_GEO
					 Where Lote IN  (SELECT LOTE FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC  WHERE  Tabla_Destino_Prod =''RELACION_UBICAC_ESTANDAR_GEO'')
					 OR lote_Actualizacion   IN  (SELECT LOTE FROM '||P_BDSTAGE||'.CALCULA_LOTE_REC  WHERE  Tabla_Destino_Prod =''RELACION_UBICAC_ESTANDAR_GEO'')
					 Group by 1 
					)WITH DATA 
					PRIMARY INDEX( Cod_DW_Ubic);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(6):CREACION TABLA TMP_RELAUBICESTANGEO_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_RELAUBICESTANGEO_242 INDEX(Cod_DW_Ubic);
 ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(6.1):COLLECT STATISTICS TMP_RELAUBICESTANGEO_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla PASO_V_RELA_UBIC_ESTANDAR_GEO
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_RELA_UBIC_ESTANDAR_GEO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_RELA_UBIC_ESTANDAR_GEO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_RELA_UBIC_ESTANDAR_GEO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	--*************** revisar2 *****************
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_RELA_UBIC_ESTANDAR_GEO ,NO FALLBACK ,
					NO BEFORE JOURNAL,
					NO AFTER JOURNAL,
					CHECKSUM = DEFAULT
					AS (SEL Cod_Pin_Persona,
							Id_Buro_Persona
						FROM '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION 
						WHERE Cod_Dw_Ubic IN (Select Cod_Dw_Ubic From '||P_BDSTAGE||'.TMP_RELAUBICESTANGEO_242)
						Group by 1,2 
					)WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(6):CREACION TABLA PASO_V_RELA_UBIC_ESTANDAR_GEO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_RELA_UBIC_ESTANDAR_GEO INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(6.1):COLLECT STATISTICS PASO_V_RELA_UBIC_ESTANDAR_GEO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_RELAUBICESTANGEO_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RELAUBICESTANGEO_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RELAUBICESTANGEO_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RELAUBICESTANGEO_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	--*************** revisar3 *****************
	---------------------------
	-- Busca la tabla TMP_Lote_RELPERUBIC_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_Lote_RELPERUBIC_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_Lote_RELPERUBIC_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Lote_RELPERUBIC_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_Lote_RELPERUBIC_242
					AS 
					(SELECT Cod_DW_Ubic
					FROM  '||P_BDVISTA||'.V_UBICACION_ORIGINAL 
					WHERE  Lote  IN (SEL Lote  From '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''UBICACION_ORIGINAL'' ) 
					UNION ALL 
					SELECT Cod_DW_Ubic
					FROM  '||P_BDVISTA||'.V_UBICACION_ORIGINAL 
					WHERE  lote_Actualizacion IN (SEL Lote  From '||P_BDSTAGE||'.CALCULA_LOTE_REC WHERE Tabla_Destino_Prod =''UBICACION_ORIGINAL'' ) 
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Ubic);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(7):CREACION TABLA TMP_Lote_RELPERUBIC_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_Lote_RELPERUBIC_242 INDEX(Cod_DW_Ubic);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(7.1):RECOLECCION ESTADISTICAS TMP_Lote_RELPERUBIC_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla PASO_V_UBICACION_ORIGINAL
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_UBICACION_ORIGINAL' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UBICACION_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL
					 AS (SELECT Cod_Pin_Persona,
							   Id_Buro_Persona
						FROM '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION
						WHERE Cod_DW_Ubic IN  (SEL Cod_DW_Ubic FROM  '||P_BDSTAGE||'.TMP_Lote_RELPERUBIC_242) 
						Group by 1,2
					 )WITH DATA 
					 PRIMARY INDEX(Id_Buro_Persona, Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(7.2):CREACION TABLA PASO_V_UBICACION_ORIGINAL'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(7.3):RECOLECCION ESTADISTICAS PASO_V_UBICACION_ORIGINAL'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	--*************** revisar4 *****************
	---------------------------
	-- Busca la tabla PASO_V_UBICACION_ESTANDARIZADA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_UBICACION_ESTANDARIZADA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UBICACION_ESTANDARIZADA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ESTANDARIZADA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
		
    SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_UBICACION_ESTANDARIZADA ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS (SELECT x.Cod_Pin_Persona,
								x.Id_Buro_Persona
						FROM '||P_BDVISTA||'.V_UBICACION_ESTANDARIZADA a

						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_REC b
						ON (a.lote=b.lote OR a.lote_Actualizacion=b.lote)
						AND (B.Tabla_Destino_Prod =''UBICACION_ESTANDARIZADA'')

						INNER JOIN '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION x
						ON (a.Cod_DW_Ubic=x.Cod_DW_Ubic)					
						group by 1,2
						)WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(8):CREACION TABLA PASO_V_UBICACION_ESTANDARIZADA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_UBICACION_ESTANDARIZADA INDEX(Id_Buro_Persona,Cod_Pin_Persona);
 ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(8.1):RECOLECCION ESTADISTICAS PASO_V_UBICACION_ESTANDARIZADA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	--*************** revisar5 *****************

    ---------------------------
	-- Busca la tabla PASO_V_LOG_UBIC_ESTANDARIZADA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_LOG_UBIC_ESTANDARIZADA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_LOG_UBIC_ESTANDARIZADA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_LOG_UBIC_ESTANDARIZADA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


    SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_LOG_UBIC_ESTANDARIZADA ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS (SELECT x.Cod_Pin_Persona,
								 x.Id_Buro_Persona
						  FROM '||P_BDVISTA||'.V_Log_Ubicacion_Estandariza a

						  INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_REC b
						  ON (a.lote=b.lote OR a.lote_Actualizacion=b.lote)
						  AND (B.Tabla_Destino_Prod =''LOG_UBICACION_ESTANDARIZADA'')
                          
						  INNER JOIN '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION x
						  ON (a.Cod_DW_Ubic=x.Cod_DW_Ubic)										
						  group by 1,2
                       )WITH DATA
					PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(9):CREACION TABLA PASO_V_LOG_UBIC_ESTANDARIZADA'
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_LOG_UBIC_ESTANDARIZADA INDEX(Id_Buro_Persona,Cod_Pin_Persona);';	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(9.1):RECOLECCION ESTADISTICAS PASO_V_LOG_UBIC_ESTANDARIZADA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	--********************************

	---------------------------
	-- Busca la tabla PASO_V_UNIFICACION_DIRECCION
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PASO_V_UNIFICACION_DIRECCION' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UNIFICACION_DIRECCION si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


    SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION ,NO FALLBACK ,
					 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
					  AS (SELECT Cod_Pin_Persona,
								Id_Buro_Persona
						FROM '||P_BDVISTA||'.V_UNIFICACION_DIRECCION a
						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_REC b
						ON (a.lote=b.lote OR a.lote_Actualizacion=b.lote)
						AND (B.Tabla_Destino_Prod =''UNIFICACION_DIRECCION'')

						INNER JOIN '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION x
						ON (a.Cod_DW_Persona_Ubic=x.Cod_DW_Persona_Ubic)					
                        group by 1,2
                       )WITH DATA
					  PRIMARY INDEX (Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(10):CREACION TABLA PASO_V_UNIFICACION_DIRECCION'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION INDEX(Id_Buro_Persona,Cod_Pin_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_REC(10.1):RECOLECCION ESTADISTICAS PASO_V_UNIFICACION_DIRECCION'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	 	
END L1;
END;

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_UBIC_DIRECCIONES

     (
		 IN	P_Lote						INTEGER
		,IN	P_StartTimeStampPadre		VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
		,IN	P_BDDATOS					VARCHAR(20)
		,IN	P_BDVISTA					VARCHAR(20)
		,IN	P_BDSTAGE					VARCHAR(20)
		,IN	P_BTTDATOS					VARCHAR(20)
		,IN	P_BTTVISTA					VARCHAR(20)
		,IN	P_BDMTDAT					VARCHAR(20)
		,IN	P_BTTMTDAT					VARCHAR(20)
		,IN P_VARQUERY	/*#1*/			VARCHAR (500)
		,OUT P_ERROR					VARCHAR(50)
	)


/*
 * ################################################################################
 * 
 * Objetivo:	Ordenamiento PRO_ORD_CTA_ATRIBUTOS.
 * Fecha:		2019-01-09
 * Lider Tecnico:	
 * Realizado por:	Fernando Garrido M.
 * Parametros:	
 * Proyecto:	 Reconocer Master
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha:2019-01-09 VERSION INICIAL  Realizado por: Fernando Garrido
 * 
 * --------------------------------------------------------------------------- 
 
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Experian  y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */

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
    
	
	----------------------------------------- INICIO CALCULO vmo_reporte_relacion_pers_ubi /*#5*/ /*#6*/---------------------------------------------------------
	-- Objetivo: Persistir a nivel de capa stage el calculo de la data con informacion historica para el algoritmo de ordenamiento.
	-- Objetos a Modificar : SP PRO_ORD_UBIC_DIRECCIONES.                                                   
	-------------------------------------------------------------------------------------------------------------------------------------------------------

	---------------------------
	-- Busca la tabla TMP_RelPerUbic_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RelPerUbic_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RelPerUbic_242 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242';
					CALL DBC.SysExecSQL(:V_CADENA);
    END IF;          


 	 SET V_CADENA= 'CREATE MULTISET  TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242
					 AS 
					(SELECT cod_dw_persona_ubic, Id_Buro_Persona 
					 FROM  '||P_BDDATOS||'.relacion_persona_ubicacion  
					 WHERE (cod_pin_persona, id_buro_persona)  IN (SELECT cod_pin_persona, id_buro_persona FROM '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER) 
					 )WITH DATA 
					 PRIMARY INDEX(cod_dw_persona_ubic);';



    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'PRO_ORD_UBIC_DIRECCIONES(1):CREACION DE TABLA TMP_RelPerUbic_242'
								,V_ERROR);
																	   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;

					
	-----------------------------------------
	-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL_MAT
	-----------------------------------------

	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_RelPerUbic_242 INDEX(cod_dw_persona_ubic);';
						   
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_UBIC_DIRECCIONES(2):RECOLECCION DE ESTADISTICAS TMP_RelPerUbic_242'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_ORD_CAL_MAT
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_ORD_CAL_MAT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL_MAT si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL_MAT';
					CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          


 	 SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL_MAT 
				   AS (SELECT CASE WHEN ID_FLAG_DESDE = 0 THEN MAX(a.Cod_DW_Reporte_Persona_Ubic) else MIN(a.Cod_DW_Reporte_Persona_Ubic) END Cod_DW_Reporte_Persona_Ubic
							,a.Cod_DW_Persona_Ubic
							,COALESCE(a.Id_Buro_Suscriptor,-1) Id_Buro_Suscriptor
							,COALESCE(a.Cod_DW_Cta,-1) Cod_DW_Cta
							,CASE WHEN ID_FLAG_DESDE =0 THEN MAX(Fecha_Reporte) ELSE  MIN(Fecha_Reporte)  END  Fecha_Reporte
							,a.Fecha_Apertura
							,a.Fecha_Nov
							,a.Desc_Est_Vigencia
							,a.Nombre_Natu_Cta
							,a.Nombre_Tipo_Rel_con_Cta
							,a.Cod_DW_Motivo_Bloqueo  
							,a.Id_Flag_Nuevo
							,a.Id_Flag_Desde
							,a.Flag_Bloqueo
							,a.Cod_DW_Fuente
							,COALESCE(a.Cod_DW_Matricula,-1) Cod_DW_Matricula
							,b.Id_Buro_Persona

					FROM '||P_BDDATOS||'.MAT_REPORTE_REL_PERS_UBI A

					INNER JOIN '||P_BDSTAGE||'.TMP_RelPerUbic_242 b
                    ON a.cod_dw_persona_ubic=b.cod_dw_persona_ubic 

					WHERE ID_FLAG_DESDE in (0,1)

					GROUP BY a.Cod_DW_Persona_Ubic
					,a.Id_Buro_Suscriptor
					,a.Cod_DW_Cta
					,a.Fecha_Apertura
					,a.Fecha_Nov
					,a.Desc_Est_Vigencia
					,a.Nombre_Natu_Cta
					,a.Nombre_Tipo_Rel_con_Cta
					,a.Cod_DW_Motivo_Bloqueo
					,a.Id_Flag_Nuevo
					,a.Id_Flag_Desde
					,a.Flag_Bloqueo
					,a.Cod_DW_Fuente
					,a.Cod_DW_Matricula
					,b.Id_Buro_Persona			
				)WITH DATA
				PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic);';



    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'PRO_ORD_UBIC_DIRECCIONES(1):CREACION DE TABLA TMP_ORD_CAL_MAT'
								,V_ERROR);
																	   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;

					
	-----------------------------------------
	-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL_MAT
	-----------------------------------------

	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL_MAT INDEX(Cod_DW_Reporte_Persona_Ubic);';
						   
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_UBIC_DIRECCIONES(2):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL_MAT'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_RelPerUbic_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RelPerUbic_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RelPerUbic_242 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242';
					CALL DBC.SysExecSQL(:V_CADENA);
    END IF;          
		
 END L1;
END;

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

REPLACE   PROCEDURE REC_DATOS.PRO_ORD_UNIF_BTT_REC_2

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
 * Objetivo:	SP Borra Tabla.
 * Fecha:		2019-01-14
 * Lider Tecnico:	
 * Realizado por:	Experian
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Unificacion BTT - RECONOCER. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 2019-01-14   Objetivo=#1     Fernando Garrido
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2017 Fabrica Teradata  
 
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
	DECLARE CNT_ERRORES INTEGER;
	
	SET V_StartTimeStampPadre = Cast(P_StartTimeStampPadre AS TIMESTAMP(6) Format 'yyyy-mm-ddhh:mi:ss');

L1:	BEGIN

    SET P_ERROR ='';
	-------------------------------------------
	-- Busca la tabla PASO_REPORTE_UBIC_ORIGINAL 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_REPORTE_UBIC_ORIGINAL' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_REPORTE_UBIC_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla Estructuras_MTDAT_BDM 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'Estructuras_MTDAT_BDM' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla Estructuras_MTDAT_BDM si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.Estructuras_MTDAT_BDM';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla Estructuras_MTDAT_BDM 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'Estructuras_MTDAT_BDM' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla Estructuras_MTDAT_BDM si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.Estructuras_MTDAT_BDM';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla CALCULA_LOTE_REC 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'CALCULA_LOTE_REC' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla CALCULA_LOTE_REC si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.CALCULA_LOTE_REC';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla PASO_V_CUENTA 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_CUENTA' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_CUENTA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla PASO_REPORTE_UBIC_ORIGINAL 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_REPORTE_UBIC_ORIGINAL' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_REPORTE_UBIC_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_REPORTE_UBIC_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla PASO_V_BURO_PERSONA 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_BURO_PERSONA' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_BURO_PERSONA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_BURO_PERSONA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	-------------------------------------------
	-- Busca la tabla PASO_V_COMPORTAMIENTO_CUENTA 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_COMPORTAMIENTO_CUENTA' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORTAMIENTO_CUENTA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	-------------------------------------------
	-- Busca la tabla PASO_RPU 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_RPU' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_RPU si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_RPU';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
    -------------------------------------------
	-- Busca la tabla PASO_RRPU 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_RRPU' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_RRPU si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_RRPU';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	-------------------------------------------
	-- Busca la tabla PASO_V_BLOQUEO 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_BLOQUEO' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_BLOQUEO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_BLOQUEO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	-------------------------------------------
	-- Busca la tabla PASO_V_UBICACION_ORIGINAL 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_UBICACION_ORIGINAL' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UBICACION_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
	
	-------------------------------------------
	-- Busca la tabla PASO_V_UBICACION_ORIGINAL 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_UBICACION_ORIGINAL' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UBICACION_ORIGINAL si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ORIGINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  
    -------------------------------------------
	-- Busca la tabla PASO_V_COMPORT_CTA_ACTIVO 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_COMPORT_CTA_ACTIVO' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_ACTIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	
	-------------------------------------------
	-- Busca la tabla PASO_V_COMPORT_CTA_PASIVO 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_COMPORT_CTA_PASIVO' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_PASIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	

	-------------------------------------------
	-- Busca la tabla PASO_V_UBICACION_ESTANDARIZADA 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_UBICACION_ESTANDARIZADA' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UBICACION_ESTANDARIZADA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UBICACION_ESTANDARIZADA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	
	-------------------------------------------
	-- Busca la tabla PASO_V_LOG_UBIC_ESTANDARIZADA 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_LOG_UBIC_ESTANDARIZADA' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_LOG_UBIC_ESTANDARIZADA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_LOG_UBIC_ESTANDARIZADA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	
	-------------------------------------------
	-- Busca la tabla PASO_V_UNIFICACION_DIRECCION 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_UNIFICACION_DIRECCION' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UNIFICACION_DIRECCION si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	
	-------------------------------------------
	-- Busca la tabla PASO_V_UNIFICACION_DIRECCION 
	-------------------------------------------
    SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'PASO_V_UNIFICACION_DIRECCION' ;

	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_UNIFICACION_DIRECCION si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PASO_V_UNIFICACION_DIRECCION';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;  	
	
	-----------------------------------------------------
	-- Validando si existe error en los pasos anteriores.
	------------------------------------------------------
	
	SET CNT_ERRORES = 0;
	SELECT Count(1) Cnt 
	 INTO :CNT_ERRORES
	FROM rec_mtdat.log_td_detalle
	WHERE Lote = :P_Lote
	AND  Descripcion_Teradata_Error  <>  'Finalizo Exitosamente'
	AND Nombre_proceso_Padre = :P_Nombre_Proceso_Padre
	HAVING Cnt > 0;
	
	IF Activity_Count > 0 THEN
	-----------------------------
	-- Se borra la tabla vmo_reporte_relacion_pers_ubi si existe
	-----------------------------
	  SET P_ERROR ='ERROR: Fallo proceso Ordenamiento_242';
				
	END IF;     


END L1;
END;

