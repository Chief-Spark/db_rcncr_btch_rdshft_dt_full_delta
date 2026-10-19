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

