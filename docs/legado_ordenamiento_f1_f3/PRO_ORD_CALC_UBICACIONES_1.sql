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

