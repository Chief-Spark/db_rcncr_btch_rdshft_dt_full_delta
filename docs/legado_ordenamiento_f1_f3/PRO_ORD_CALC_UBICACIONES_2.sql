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

