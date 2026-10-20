--<ScriptOptions statementTerminator=";"/>

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Catalogo
 ( 
 	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BDMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * 
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla Catal_AAAAMMDD_HHMMSS_Lote
 * Fecha:			2017/12/07
 * Realizado por:	Oscar Angel
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Catalogo
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * ################################################################################
 */ 
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE V_CADENA2 VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE nameTableDrop VARCHAR(30);
	DECLARE dynamicDropTable NO SCROLL CURSOR FOR theStatement;
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'Catal';
	SET nameTable = TRIM(acronimo||'_'||V_DateTable||'_'||CAST(P_Lote AS CHAR(10)));
	
------------------------------------------------------------------------------------------------------------------------
-- Elimina la/s tabla/s Catal_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'SELECT B.TABLENAME
	FROM '||P_BDMTDAT||'.LOG_TD A
	INNER JOIN DBC.TABLES B ON SUBSTR(TRIM(B.TABLENAME),1,10) = SUBSTR(TRIM(A.TABLA_ORIGEN_STAGE),1,10)
	WHERE A.NOMBRE_PROCESO = '''||P_Nombre_Proceso_Padre||'''
	AND B.DATABASENAME = '''||P_BDSTAGE||'''
	GROUP BY B.TABLENAME;
	';

	PREPARE theStatement FROM V_CADENA;
	OPEN dynamicDropTable;
		C:LOOP
			FETCH dynamicDropTable  INTO  nameTableDrop;
			IF SQLCODE <> 0 THEN LEAVE C;
			END IF;
			
			IF ACTIVITY_COUNT > 0 THEN
				SET V_CADENA2 = '';
				SET V_CADENA2 = 'DROP TABLE '||P_BDSTAGE||'.'||nameTableDrop||';';
			
				CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
						,:P_Nombre_Proceso_Padre 
						,:V_CADENA2
						,'SP_Linea_Catalogo (0): DROP TABLE '||P_BDSTAGE||'.'||nameTableDrop||''
						,V_ERROR);
				
				SET P_ERROR = V_ERROR;
					
				IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
				END IF;
			END IF;
		END LOOP C;
	CLOSE dynamicDropTable;

------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla Catal_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.'||nameTable||' AS(
	SELECT
	VATA.COD_DW_ATRIBUTO
	,VATA.DESCRIPCION_ATRIBUTO
	,VATA.VALOR_ORIGEN
	,VATA.COD_DW_TIPO_ATRIBUTO
	,VATA.DESCRIPCION_TIPO_ATRIBUTO
	FROM '||P_BDVISTA||'.V_ATRIBUTO_TIPO_ATRIBUTO VATA
	) WITH DATA PRIMARY INDEX (COD_DW_ATRIBUTO);
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Catalogo (1):. Creacion Tabla Linea_Catalogo ' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a Catal_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (COD_DW_ATRIBUTO), COLUMN (COD_DW_ATRIBUTO) ON '||P_BDSTAGE||'.'||nameTable||';';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Catalogo (2):. Actualizar estadisticas a la tabla '||P_BDSTAGE||'.'||nameTable||''
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza la tabla LOG_TD
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
	(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
	CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
	USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
	SELECT
	'||P_Lote||',
	CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
	'''||P_Nombre_Proceso_Padre||''',
	NULL,
	'''||nameTable||''',
	NULL,
	(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
	0,
	(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
	0,
	USER,
	NULL,
	''dbc'',
	NULL,
	NULL;
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Catalogo (3):. Actualiza Tabla LOG_TD' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
 	
	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Contact
 ( 
 	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_HIST_ETAPA_7
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Contact
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 Realizado por
 * 22-10-2018		Version Inicial	                     Fernando Garrido 
 * 05-12-2018		#1 Se incluye borrado de temporales  Andy Garcia
 * 03-05-2019       #Se ajusta Calculo SECTOR            Fernando Garrido.
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'Conta';
	SET nameTable = 'TMP_HIST_ETAPA_7';
	
    ------------------------------------------------------------------------------------------------------------------------
    -- Valida Tipo EjecuciÃ¸Â³n , is null = Carga Full, is not null = Carga Delta
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TABLA_ORIGEN_STAGE =:nameTable;
   
   
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_1
   -------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_1 AS (
					SELECT A.Cod_Dw_Contactabilidad
					,A.FECHA_NUMERIC
					,A.Fecha_Gestion
					,A.Sumatoria_Fecha
					,A.Conteo_Indicador
					,A.List_Indicador
					,A.Orden_Fecha
					,A.Cod_Dw_Persona_Ubic
					FROM  (SELECT  CTB.Cod_Dw_Contactabilidad
					  ,CAST (CAST (CAST(CTB.Fecha_Gestion AS CHAR(10)) AS DATE) AS INTEGER FORMAT ''9999999'') AS FECHA_NUMERIC
					  ,CTB.Fecha_Gestion
					  ,((FECHA_NUMERIC*1000) + ((FECHA_NUMERIC)*-1)) AS Sumatoria_Fecha
					  ,COUNT (CTB.Indicador_Efectividad) OVER (PARTITION BY CTB.Cod_Dw_Persona_Ubic) AS Conteo_Indicador
					  ,((Conteo_Indicador * 10000000)* -1)  AS List_Indicador
					  ,(Sumatoria_Fecha - Conteo_Indicador ) AS Orden_Fecha
					  ,CTB.Cod_Dw_Persona_Ubic
					FROM '||P_BDVISTA||'.V_CONTACTABILIDAD CTB) A
					INNER JOIN '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 B
					ON A.COD_DW_PERSONA_UBIC=B.ID
					QUALIFY ROW_NUMBER() OVER (PARTITION BY A.Cod_Dw_Persona_Ubic ORDER BY A.Orden_Fecha DESC)  = 1
						
					)
					WITH DATA
					PRIMARY INDEX (Cod_Dw_Contactabilidad);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (1):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_HIST_ETAPA_1
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (Cod_Dw_Contactabilidad) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (2):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_2
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_2 
					AS (SELECT CBD.COD_DW_PERSONA_UBIC
								,CBD.GESTION
								,COUNT(COD_DW_TIPO_ENVIO_CONTACTO) AS MAX_CONTEO
								,VPGD.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_DIR
								,VPGE.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_MAIL
								,VPGT.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_TEL
								,VPGC.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_CEL
								,((MAX_CONTEO*1000) + ((PRIORIDAD_DIR + PRIORIDAD_MAIL + PRIORIDAD_TEL + PRIORIDAD_CEL)*-1)) AS SUMATORIA_ORDEN
						FROM  '||P_BDVISTA||'.V_CONTACTABILIDAD CBD
						INNER JOIN '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 B
						ON CBD.COD_DW_PERSONA_UBIC=B.ID
						INNER JOIN  '||P_BDVISTA||'.V_CONTACTO_EFECTIVO VCE				ON VCE.DESCRIPCION_TIPO_UBICACION EQ CBD.TIPO_UBICACION
																											AND VCE.INDICADOR_REAL_EFECTIVIDAD EQ CBD.INDICADOR_EFECTIVIDAD
						LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_DIR VPGD 		ON VPGD.GESTION = CBD.GESTION
						LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_EMAIL VPGE 	ON VPGE.GESTION = CBD.GESTION
						LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_TEL VPGT 		ON VPGT.GESTION = CBD.GESTION
						LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_CEL VPGC 		ON VPGC.GESTION = CBD.GESTION			
						WHERE CBD.FECHA_GESTION BETWEEN ADD_MONTHS(CURRENT_TIMESTAMP , -3) AND CURRENT_TIMESTAMP  
						GROUP BY 1,2,4,5,6,7
						QUALIFY ROW_NUMBER() OVER (PARTITION BY CBD.COD_DW_PERSONA_UBIC ORDER BY SUMATORIA_ORDEN DESC) = 1
					  )WITH DATA
					PRIMARY INDEX (COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (3):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_HIST_ETAPA_2
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (COD_DW_PERSONA_UBIC) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (4):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_3
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_3
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_3 AS (
					SELECT CBD.COD_DW_PERSONA_UBIC
							,CBD.GESTION
							,COUNT(COD_DW_TIPO_ENVIO_CONTACTO) AS MAX_CONTEO
							,VPGD.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_DIR
							,VPGE.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_MAIL
							,VPGT.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_TEL
							,VPGC.ORDEN_PRIORIDAD_GESTION AS PRIORIDAD_CEL
							,((MAX_CONTEO*1000) + ((PRIORIDAD_DIR + PRIORIDAD_MAIL + PRIORIDAD_TEL + PRIORIDAD_CEL)*-1)) AS SUMATORIA_ORDEN
					FROM  '||P_BDVISTA||'.V_CONTACTABILIDAD CBD
					INNER JOIN '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 B
					ON CBD.COD_DW_PERSONA_UBIC=B.ID

					INNER JOIN  '||P_BDVISTA||'.V_CONTACTO_EFECTIVO VCE				ON VCE.DESCRIPCION_TIPO_UBICACION EQ CBD.TIPO_UBICACION
																										AND VCE.INDICADOR_REAL_EFECTIVIDAD EQ CBD.INDICADOR_EFECTIVIDAD
					LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_DIR VPGD 		ON VPGD.GESTION = CBD.GESTION
					LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_EMAIL VPGE 	ON VPGE.GESTION = CBD.GESTION
					LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_TEL VPGT 		ON VPGT.GESTION = CBD.GESTION
					LEFT JOIN  '||P_BDVISTA||'.V_PRIORIDAD_GESTION_CEL VPGC 		ON VPGC.GESTION = CBD.GESTION			
					WHERE CBD.FECHA_GESTION BETWEEN ADD_MONTHS(CURRENT_TIMESTAMP , -6) AND CURRENT_TIMESTAMP  
					GROUP BY 1,2,4,5,6,7
					QUALIFY ROW_NUMBER() OVER (PARTITION BY CBD.COD_DW_PERSONA_UBIC ORDER BY SUMATORIA_ORDEN DESC) = 1

					)
					WITH DATA
					PRIMARY INDEX (COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (5):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_3' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_HIST_ETAPA_2
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (COD_DW_PERSONA_UBIC) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_3;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (6):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_3'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_NCONTACT_AGR_SECTOR
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_NCONTACT_AGR_SECTOR'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_NCONTACT_AGR_SECTOR';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_NCONTACT_AGR_SECTOR
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_NCONTACT_AGR_SECTOR
					AS
					(SEL A.*, B.NOMBRE_CLASE_BURO
								 ,CASE WHEN Cod_Clase_Buro_Fte = ''F'' THEN 1
										  WHEN Cod_Clase_Buro_Fte = ''O'' THEN 2
										  WHEN Cod_Clase_Buro_Fte = ''C'' THEN 3
										  WHEN Cod_Clase_Buro_Fte = ''R'' THEN 4
									   ELSE -1 
									 END Peso_Sector_Mercado			
					FROM '||P_BTTPRUVI||'.V_PERSONA_CLASE_BURO A 
					INNER JOIN '||P_BTTPRUVI||'.v_clase_buro B
					ON A.Cod_dw_Clase_Buro = B.Cod_dw_Clase_Buro
					QUALIFY( row_number() Over(Partition by Id_Buro_Persona order by Peso_Sector_Mercado asc )  = 1)
					)WITH DATA 
					PRIMARY INDEX( Id_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (7):. Creacion Tabla '||P_BDSTAGE||'.TMP_NCONTACT_AGR_SECTOR' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

   ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza estadisticas a TMP_HIST_ETAPA_4
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (Id_Buro_Persona) ON '||P_BDSTAGE||'.TMP_NCONTACT_AGR_SECTOR;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (8):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_4
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_4
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_4 AS (
					SELECT 
							CTB.COD_DW_CONTACTABILIDAD AS ID
							
							,CASE WHEN VCE.DESCRIPCION_TIPO_UBICACION EQ CTB.TIPO_UBICACION
										AND VCE.INDICADOR_REAL_EFECTIVIDAD EQ CTB.INDICADOR_EFECTIVIDAD THEN ''SI''
									ELSE ''NO''
							END AS CONTACTABILIDAD /* #1 */
					--		,MAX(CTB.FECHA_GESTION) AS FECHA_ULTIMO_CONTACTO
							,CTB.FECHA_GESTION
							,CASE WHEN CONTACTABILIDAD = ''SI'' THEN
									CASE WHEN CLD.DAY_OF_WEEK EQ 1 THEN ''Domingo''
											WHEN CLD.DAY_OF_WEEK EQ 2 THEN ''Lunes''
											WHEN CLD.DAY_OF_WEEK EQ 3 THEN ''Martes''
											WHEN CLD.DAY_OF_WEEK EQ 4 THEN ''Miercoles''
											WHEN CLD.DAY_OF_WEEK EQ 5 THEN ''Jueves''
											WHEN CLD.DAY_OF_WEEK EQ 6 THEN ''Viernes''
											WHEN CLD.DAY_OF_WEEK EQ 7 THEN ''Sabado''
									END
							END AS MEJOR_DIA_GESTION /* #1 */
							,CASE WHEN CONTACTABILIDAD EQ ''SI'' THEN
									CASE WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) EQ ''00:00:00'' THEN NULL
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''00:01:00'' AND ''06:00:00'' THEN ''08:01 a 12:00''
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''08:01:00'' AND ''12:00:00'' THEN ''08:01 a 12:00''
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''12:01:00'' AND ''14:00:00'' THEN ''12:01 a 14:00''
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''14:01:00'' AND ''16:00:00'' THEN ''14:01 a 16:00''
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''16:01:00'' AND ''23:59:59'' THEN ''16:01 a 20:00''
											WHEN CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS TIME(6)) BETWEEN ''20:01:00'' AND ''23:59:00'' THEN ''20:01 a 23:59''
									END
							END AS MEJOR_HORA_GESTION
							,CTB.ID_BURO_SUSCRIPTOR AS REPORTADO_POR
							,VPCB.NOMBRE_CLASE_BURO AS SECTOR
							,CTB.COD_DW_PERSONA_UBIC UBICACION_ID
							--,NVL(COUNT(*),0) * 100000000 + NVL(CAST(HTP1.FECHA_GESTION AS CHAR(10)) * 1.00,0) AS PESO /* #1 */
							,VCE.DESCRIPCION_TIPO_UBICACION
							,CTB.TIPO_UBICACION
							,VCE.INDICADOR_REAL_EFECTIVIDAD
							,CTB.INDICADOR_EFECTIVIDAD
							,CLD.DAY_OF_WEEK
							,HTP1.FECHA_GESTION AS FECHA_GESTION_1
							,CTB.ID_BURO_SUSCRIPTOR
							,VPCB.NOMBRE_CLASE_BURO
							--,MMR3.GESTION
							--,MMR6.GESTION							
							,LUL.FLAG_OP AS FLAG_OP1
							,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP 
					FROM '||P_BDVISTA||'.V_CONTACTABILIDAD CTB
					INNER JOIN '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 LUL
					ON CTB.COD_DW_PERSONA_UBIC=LUL.ID
					INNER JOIN  '||P_BDVISTA||'.V_CONTACTO_EFECTIVO VCE 	ON VCE.DESCRIPCION_TIPO_UBICACION = CTB.TIPO_UBICACION AND VCE.INDICADOR_REAL_EFECTIVIDAD = CTB.INDICADOR_EFECTIVIDAD
					LEFT JOIN  '||P_BDSTAGE||'.TMP_HIST_ETAPA_1 HTP1 ON CTB.COD_DW_CONTACTABILIDAD = HTP1.COD_DW_CONTACTABILIDAD
					LEFT JOIN SYS_CALENDAR.CALENDAR CLD 	ON CLD.CALENDAR_DATE = CAST(CAST(HTP1.FECHA_GESTION AS TIMESTAMP) AS DATE)
					LEFT JOIN  '||P_BDSTAGE||'.TMP_NCONTACT_AGR_SECTOR VPCB 			ON VPCB.ID_BURO_PERSONA EQ CTB.ID_BURO_SUSCRIPTOR					

					--GROUP BY 
					)
					WITH DATA
					PRIMARY INDEX (ID,SECTOR,UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (7):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_4' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

   ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza estadisticas a TMP_HIST_ETAPA_4
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (ID,SECTOR,UBICACION_ID) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_4;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (8):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_5
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_5 AS (
					SELECT 	HTP4.ID
							,HTP4.CONTACTABILIDAD /* #1 */
					--		,MAX(CTB.FECHA_GESTION) AS FECHA_ULTIMO_CONTACTO
							,HTP4.FECHA_GESTION
							,HTP4.MEJOR_DIA_GESTION /* #1 */
							,HTP4.MEJOR_HORA_GESTION
							,HTP4.REPORTADO_POR
							,HTP4.SECTOR
							,HTP4.UBICACION_ID
							,HTP4.DESCRIPCION_TIPO_UBICACION
							,HTP4.TIPO_UBICACION
							,HTP4.INDICADOR_REAL_EFECTIVIDAD
							,HTP4.INDICADOR_EFECTIVIDAD
							,HTP4.DAY_OF_WEEK
							,HTP4.FECHA_GESTION_1
							,HTP4.ID_BURO_SUSCRIPTOR
							,HTP4.NOMBRE_CLASE_BURO
							--,NVL(COUNT(*),0) * 100000000 + NVL(CAST(HTP1.FECHA_GESTION AS CHAR(10)) * 1.00,0) AS PESO /* #1 */
							,CASE WHEN HTP4.CONTACTABILIDAD EQ ''SI'' THEN HTP2.GESTION
									ELSE NULL
							END AS MEJOR_RESULTADO_3MESES		
                            ,HTP4.FLAG_OP							
					FROM '||P_BDSTAGE||'.TMP_HIST_ETAPA_4 HTP4
					LEFT JOIN '||P_BDSTAGE||'.TMP_HIST_ETAPA_2 HTP2
					ON HTP4.UBICACION_ID=HTP2.COD_DW_PERSONA_UBIC
					)
					WITH DATA
					PRIMARY INDEX (ID,SECTOR,UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (9):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_4' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_HIST_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (ID,SECTOR,UBICACION_ID) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_5;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Contact (10):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_5'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_6
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_6 AS (
					SELECT 	HTP5.ID
							,HTP5.CONTACTABILIDAD /* #1 */
					--		,MAX(CTB.FECHA_GESTION) AS FECHA_ULTIMO_CONTACTO
							,HTP5.FECHA_GESTION
							,HTP5.MEJOR_DIA_GESTION /* #1 */
							,HTP5.MEJOR_HORA_GESTION
							,HTP5.REPORTADO_POR
							,HTP5.SECTOR
							,HTP5.UBICACION_ID
							,HTP5.DESCRIPCION_TIPO_UBICACION
							,HTP5.TIPO_UBICACION
							,HTP5.INDICADOR_REAL_EFECTIVIDAD
							,HTP5.INDICADOR_EFECTIVIDAD
							,HTP5.DAY_OF_WEEK
							,HTP5.FECHA_GESTION_1
							,HTP5.ID_BURO_SUSCRIPTOR
							,HTP5.NOMBRE_CLASE_BURO
							--,NVL(COUNT(*),0) * 100000000 + NVL(CAST(HTP1.FECHA_GESTION AS CHAR(10)) * 1.00,0) AS PESO /* #1 */
							,HTP5.MEJOR_RESULTADO_3MESES
							
							,CASE WHEN CONTACTABILIDAD EQ ''SI'' THEN HTP3.GESTION
									ELSE NULL
							END AS MEJOR_RESULTADO_6MESES
							,HTP5.FLAG_OP
					FROM '||P_BDSTAGE||'.TMP_HIST_ETAPA_5 HTP5
					LEFT JOIN '||P_BDSTAGE||'.TMP_HIST_ETAPA_3 HTP3
					ON HTP5.UBICACION_ID=HTP3.COD_DW_PERSONA_UBIC
					)WITH DATA
					PRIMARY INDEX (ID,SECTOR,UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (11):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_6' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_HIST_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (ID,SECTOR,UBICACION_ID) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (12):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   -------------------------------------------------------------------------------------------------------------------------
   --- Busca la tabla TMP_HIST_ETAPA_7
   -------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	 
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_HIST_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_7 AS (
					SELECT 	HTP6.ID
							,HTP6.CONTACTABILIDAD /* #1 */
							,MAX(HTP6.FECHA_GESTION) AS FECHA_ULTIMO_CONTACTO
							,HTP6.FECHA_GESTION
							,HTP6.MEJOR_DIA_GESTION /* #1 */
							,HTP6.MEJOR_HORA_GESTION
							,HTP6.REPORTADO_POR
							,HTP6.SECTOR
							,HTP6.UBICACION_ID
							,NVL(COUNT(*),0) * 100000000 + NVL(CAST(HTP6.FECHA_GESTION AS CHAR(10)) * 1.00,0) AS PESO /* #1 */
							,HTP6.MEJOR_RESULTADO_3MESES
							,HTP6.MEJOR_RESULTADO_6MESES	
                            ,HTP6.FLAG_OP							
					FROM '||P_BDSTAGE||'.TMP_HIST_ETAPA_6 HTP6
					GROUP BY HTP6.ID
							,HTP6.CONTACTABILIDAD
							,HTP6.TIPO_UBICACION
							,HTP6.FECHA_GESTION
							,HTP6.MEJOR_DIA_GESTION
							,HTP6.MEJOR_HORA_GESTION
							--,HTP6.INDICADOR_REAL_EFECTIVIDAD
							--,HTP6.INDICADOR_EFECTIVIDAD
							,HTP6.DAY_OF_WEEK
							,HTP6.FECHA_GESTION_1
							,HTP6.MEJOR_RESULTADO_3MESES
							,HTP6.MEJOR_RESULTADO_6MESES
							,HTP6.REPORTADO_POR
							,HTP6.SECTOR
							,HTP6.UBICACION_ID
							,HTP6.FLAG_OP
					QUALIFY ROW_NUMBER() OVER (PARTITION BY HTP6.ID ORDER BY PESO DESC) = 1
					)WITH DATA
					PRIMARY INDEX (ID,SECTOR,UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Contact (13):. Creacion Tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_7' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_HIST_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (ID,SECTOR,UBICACION_ID) ON '||P_BDSTAGE||'.TMP_HIST_ETAPA_7;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (14):. Estadisticas para '||P_BDSTAGE||'.TMP_HIST_ETAPA_7'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
	-- se borra tabla TMP_HIST_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Contact (15): Borra tabla '||P_BDSTAGE||'.TMP_HIST_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- #1 Borrado de Temporales
	------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_HIST_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_HIST_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	
	
	
		
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Contact (14):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

 END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Historial
 ( 
 	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20)
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
	,IN P_BTTMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_PINTER_ETAPA_2
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 	Realizado por
 * 19-10-2018		Version Inicial	                     	Fernando Garrido 
 * 03-11-2018		#1 Se realiza coalesce para traer	 	Andy Garcia	
 *					info de camaras de distintas fuentes 	
 * 15-01-2019		#2 Se incluyen campos al Ã­ndice de la	Andy Garcia
					tabla final.
 * 30-04-2019       #3 Inclusion pin persona para poder traer las actividades economicas sin importar si es persona natural o juridica. 
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'Histo';
	SET nameTable = 'TMP_PERS_ACTIVIDAD_ECONOMIC';
	
	------------------------------------------------------------------------------------------------------------------------
	-- Valida Tipo EjecuciÃ¸ÆÃâ Ã¸â Ã´Â³n , is null = Carga Full, is not null = Carga Delta
	------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TABLA_ORIGEN_STAGE = :nameTable;
	
	------------------------------------------------------------------------------------------------------------------------
-- Busca la tabla TMP_FLAG_OP_I_HISTO
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_HISTO'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_HISTO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_I_HISTO
	------------------------------------------------------------------------------------------------------------------------
		SET V_CADENA = '';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_HISTO AS(
						SELECT VPAEC.ID_BURO_PERSONA
						FROM(SELECT NO_LOTE FROM '||P_BTTMTDAT||'.METADATACARGALOG MCL
								WHERE TRIM(MCL.TABLA1) = ''PERSONA_ACT_ECONOMICA_CIIU''
								AND TRIM(MCL.DESCRIPCION) = ''OK''
								AND CAST(MCL.FECHA AS DATE FORMAT ''yy/MM/dd'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE) (VARCHAR(10)) (DATE) (FORMAT ''yy/MM/dd'')
										FROM '||P_BDMTDAT||'.LOG_TD LTD
										WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
										AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
										AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(MCL.FECHA AS DATE FORMAT ''yy/MM/dd'')-1)
								GROUP BY NO_LOTE) X
						INNER JOIN '||P_BTTPRUVI||'.V_PERSONA_ACT_ECONOMICA_CIIU VPAEC ON VPAEC.LOTE = X.NO_LOTE
						) WITH DATA
						PRIMARY INDEX(ID_BURO_PERSONA);';

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
										,:P_Nombre_Proceso_Padre 
										,:V_CADENA 
										,'SP_Linea_Historial (1):. Creacion Tabla TMP_FLAG_OP_I_HISTO' 
										,V_ERROR);
				
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
			LEAVE L1;
		END IF;
		
	------------------------------------------------------------------------------------------------------------------------
	-- Ejecuta estadisticas a la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  INDEX(ID_BURO_PERSONA) ON  '||P_BDSTAGE||'.TMP_FLAG_OP_I_HISTO;' ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (2):. Creacion Tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_A_HISTO
	------------------------------------------------------------------------------------------------------------------------
		SET V_CADENA = '';
		LOCKING ROW FOR ACCESS
		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE
		AND TABLENAME = 'TMP_FLAG_OP_A_HISTO'
		AND Tablekind IN ('T', 'O');
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_HISTO';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;
		
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_A_HISTO
	------------------------------------------------------------------------------------------------------------------------
		SET V_CADENA = '';
		SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_HISTO AS(
						SELECT VPAEC.ID_BURO_PERSONA
						FROM(SELECT NO_LOTE FROM '||P_BTTMTDAT||'.METADATACARGALOG MCL
								WHERE TRIM(MCL.TABLA1) = ''PERSONA_ACT_ECONOMICA_CIIU''
								AND TRIM(MCL.DESCRIPCION) = ''OK''
								AND CAST(MCL.FECHA AS DATE FORMAT ''yy/MM/dd'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE) (VARCHAR(10)) (DATE) (FORMAT ''yy/MM/dd'')
										FROM '||P_BDMTDAT||'.LOG_TD LTD
										WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
										AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
										AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(MCL.FECHA AS DATE FORMAT ''yy/MM/dd'')-1)
								GROUP BY NO_LOTE) X
						INNER JOIN '||P_BTTPRUVI||'.V_PERSONA_ACT_ECONOMICA_CIIU VPAEC ON VPAEC.LOTE_ACTUALIZACION = X.NO_LOTE
						) WITH DATA
						PRIMARY INDEX(ID_BURO_PERSONA);';

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
										,:P_Nombre_Proceso_Padre 
										,:V_CADENA 
										,'SP_Linea_Historial (3):. Creacion Tabla TMP_FLAG_OP_A_HISTO' 
										,V_ERROR);
				
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
			LEAVE L1;
		END IF;
		
	------------------------------------------------------------------------------------------------------------------------
	-- Ejecuta estadisticas a la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  INDEX(ID_BURO_PERSONA) ON  '||P_BDSTAGE||'.TMP_FLAG_OP_A_HISTO;' ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (4):. Creacion Tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
		
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_VU_PERS_ACTIVIDAD_ECONOMIC'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_VU_PERS_ACTIVIDAD_ECONOMIC';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_VU_PERS_ACTIVIDAD_ECONOMIC
					 AS
					(SEL  VPAE.FECHA_INICIO_RELACION AS FECHA_REPORTE
						 ,VPAE.ID_BURO_PERSONA AS INFO_BASICA_ID	
					     ,VPAE.Cod_Pin_Persona /*#3*/
						 ,VPAE.COD_DW_ACT_ECONO_CIIU
						 ,INBAS.TIPO_IDENTIFICACION
						 ,INBAS.NUMERO_IDENTIFICACION
					FROM  '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10 INBAS
					LEFT JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE 
					--WHERE VPAE.ID_BURO_PERSONA IN (SEL ID FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10)
					ON INBAS.COD_PIN_PERSONA=VPAE.COD_PIN_PERSONA /*#1*/
					)WITH DATA
					PRIMARY INDEX(INFO_BASICA_ID, COD_DW_ACT_ECONO_CIIU);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Historial (5):. Creacion Tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
	-- Ejecuta estadisticas a la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  INDEX(INFO_BASICA_ID, COD_DW_ACT_ECONO_CIIU)
	                                 , COLUMN(COD_DW_ACT_ECONO_CIIU)
                     ON  '||P_BDSTAGE||'.TMP_VU_PERS_ACTIVIDAD_ECONOMIC;' ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (6):. Creacion Tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

    ------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PERS_ACTIVIDAD_ECONOMIC'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PERS_ACTIVIDAD_ECONOMIC';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.TMP_PERS_ACTIVIDAD_ECONOMIC
					AS
					(SEL CAST( SUM(1)  OVER ( ROWS UNBOUNDED PRECEDING ) AS INTEGER)  ID
						,VPAE.TIPO_IDENTIFICACION
						,VPAE.NUMERO_IDENTIFICACION
						,Coalesce(VAEC.COD_ACT_ECONO_CIIU_FTE,B.COD_ACT_ECONO_CIIU_FTE) AS CIIU /*#1*/
						,Coalesce(VAEC.DESC_ACT_ECONO_CIIU,B.DESC_ACT_ECONO_CIIU) AS ACTIVIDAD_ECONOMICA /*#1*/
						,Coalesce(VAEC.VERSION_CODIFICACION_CIIU,B.VERSION_CODIFICACION_CIIU) AS VERSION /*#1*/
						,Coalesce(VPAE.FECHA_REPORTE,VPJC.Fecha_Matricula) AS FECHA_REPORTE /*#1*/
						,VPAE.INFO_BASICA_ID
						,CASE WHEN FOPI.ID_BURO_PERSONA IS NOT NULL THEN ''I''
						      WHEN FOPA.ID_BURO_PERSONA IS NOT NULL THEN ''A''
						END AS FLAG_OP1
						,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP
					FROM '||P_BDSTAGE||'.TMP_VU_PERS_ACTIVIDAD_ECONOMIC VPAE
					LEFT JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC     			
					ON VPAE.COD_DW_ACT_ECONO_CIIU = VAEC.COD_DW_ACT_ECONO_CIIU
					
					LEFT JOIN '||P_BDVISTA||'.V_Persona_Juridica_Camara VPJC
					ON VPAE.Cod_pin_persona=VPJC.Cod_pin_persona /*#3*/
					
					LEFT JOIN '||P_BDVISTA||'.V_Actividad_Econo_CIIU B /*#1*/
                    ON VPJC.Cod_DW_Act_Econo_CIIU=B.Cod_DW_Act_Econo_CIIU /*#1*/

					LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_I_HISTO FOPI      				
					ON VPAE.INFO_BASICA_ID = FOPI.ID_BURO_PERSONA
					
					LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_A_HISTO FOPA    
					ON VPAE.INFO_BASICA_ID = FOPA.ID_BURO_PERSONA
					
					WHERE CIIU IS NOT NULL
					
					/*QUALIFY (Row_Number() Over(PARTITION BY CIIU, VPAE.INFO_BASICA_ID ORDER BY Version DESC ))=1*/ /*#1*/ /*#2*/
					QUALIFY (ROW_NUMBER() OVER(PARTITION BY CIIU, VPAE.INFO_BASICA_ID ORDER BY Version DESC, VPAE.Fecha_Reporte DESC, VPJC.Fecha_Matricula DESC))=1 /*#2*/
					
					)WITH DATA 
					PRIMARY INDEX(ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (7):. Creacion Tabla TMP_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
	-- Ejecuta estadisticas a la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX(ID),COLUMN(info_basica_id,ciiu,fecha_reporte) ON  '||P_BDSTAGE||'.TMP_PERS_ACTIVIDAD_ECONOMIC;' ; /*#2*/

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (8):. Creacion Tabla TMP_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
	-- Borra la tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_VU_PERS_ACTIVIDAD_ECONOMIC;' ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (9):. Borra la Tabla TMP_VU_PERS_ACTIVIDAD_ECONOMIC' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	

	------------------------------------------------------------------------------------------------------------------------
	-- #1 Borra Temporales
	------------------------------------------------------------------------------------------------------------------------	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_HISTO'
	AND Tablekind IN ('T', 'O');
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_HISTO';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	
	

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_HISTO'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_HISTO';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Historial (10):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;


	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Indic_Movilidad
 ( 
 	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_MOVIL_ETAPA_1
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 Realizado por
 * 19-10-2018		Version Inicial	 					 Fernando Garrido 
 * 05-12-2018       #1 Se incluye borrado de temporales	 Andy Garcia 
 * 14-01-2019 		#2 Solo personas Ãºnicas de Ind Mov.  Andy Garcia
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE nameTable3 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'InMov';
	SET nameTable = 'TMP_MOVIL_ETAPA_2';

	------------------------------------------------------------------------------------------------------------------------
	-- Valida Tipo EjecuciÃ¸ÆÃâ Ã¸â Ã´Â³n , is null = Carga Full, is not null = Carga Delta
	------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TRIM(TABLA_ORIGEN_STAGE) = :nameTable;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_I_INMOV
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_INMOV'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INMOV';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_I_INMOV
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INMOV AS(
					SELECT ID_BURO_PERSONA FROM '||P_BDDATOS||'.PERSONA_INDICADOR_MOVILIDAD PIM
					WHERE PIM.LOTE IS NOT NULL AND PIM.LOTE_ACTUALIZACION IS NULL
					AND CAST(PIM.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable|| '''),CAST(PIM.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					GROUP BY 1 /*#2*/				
					) WITH DATA
					PRIMARY INDEX(ID_BURO_PERSONA)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (1):. Creacion Tabla TMP_FLAG_OP_I_INMOV' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
    ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_FLAG_OP_I_INMOV
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_BURO_PERSONA)  ON '||P_BDSTAGE||'.TMP_FLAG_OP_I_INMOV;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (2):. Estadisticas para TMP_FLAG_OP_I_INMOV' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_A_INMOV
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_INMOV'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INMOV';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_A_INMOV
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INMOV AS(
					SELECT ID_BURO_PERSONA FROM '||P_BDDATOS||'.PERSONA_INDICADOR_MOVILIDAD PIM
					WHERE PIM.LOTE_ACTUALIZACION IS NOT NULL
					AND CAST(PIM.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(PIM.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					GROUP BY 1 /*#2*/
					) WITH DATA
					PRIMARY INDEX(ID_BURO_PERSONA)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (3):. Creacion Tabla TMP_FLAG_OP_A_INMOV' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_FLAG_OP_I_INMOV
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_BURO_PERSONA)  ON '||P_BDSTAGE||'.TMP_FLAG_OP_A_INMOV;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (4):. Estadisticas para TMP_FLAG_OP_A_INMOV' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_LUL
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_LUL'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_LUL';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_LUL
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_LUL AS(
					SELECT LUL.INFO_BASICA
					FROM '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 LUL
					INNER JOIN '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10 
					LIBL ON LIBL.ID = LUL.INFO_BASICA
					GROUP BY LUL.INFO_BASICA
					) WITH DATA;
					';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (5):. Creacion Tabla TMP_LUL' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
    ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_LUL
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(INFO_BASICA)  ON '||P_BDSTAGE||'.TMP_LUL;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (6):. Estadisticas para TMP_LUL' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
    ------------------------------------------------------------------------------------------------------------------------
    -- Busca la tabla TMP_MOVIL_ETAPA_0
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_0'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_MOVIL_ETAPA_0
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0 
					AS (SELECT PIM.COD_DW_PERSONA_IND_MOVIL 
							,PIM.FECHA_INICIO AS FECHA
							,VIM.VALOR_INDICADOR_MOVILIDAD AS DESCRIPCION
							,VIM.DESCRIPCION_INDICADOR_MOVILIDA AS NOVEDAD
							--,H1.Descripcion_Hom_Ind_Mov_Linea AS NOVEDAD
							,PIM.ID_BURO_PERSONA AS INFO_BASICA_ID
						
						FROM  '||P_BDVISTA||'.V_PERSONA_INDICADOR_MOVILIDAD PIM	
						LEFT JOIN  '||P_BDVISTA||'.V_INDICADOR_MOVILIDAD VIM				
						ON VIM.COD_DW_INDICADOR_MOVILIDAD = PIM.COD_DW_INDICADOR_MOVILIDAD	
					)
					WITH DATA
					PRIMARY INDEX (COD_DW_PERSONA_IND_MOVIL);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (7):. Creacion Tabla TMP_MOVIL_ETAPA_0' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_MOVIL_ETAPA_0
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(COD_DW_PERSONA_IND_MOVIL)  ON '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (8):. Estadisticas para TMP_MOVIL_ETAPA_0' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;


    ------------------------------------------------------------------------------------------------------------------------
    -- Busca la tabla TMP_MOVIL_ETAPA_0_1
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_0_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_MOVIL_ETAPA_0_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1 
					AS (SELECT IBAS.TIPO_IDENTIFICACION,
							   IBAS.NUMERO_IDENTIFICACION,
							   ET0.*
						
						FROM  '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0 ET0
						LEFT JOIN  '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10 IBAS				
						ON ET0.INFO_BASICA_ID= IBAS.ID
					)
					WITH DATA
					PRIMARY INDEX (COD_DW_PERSONA_IND_MOVIL);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (7):. Creacion Tabla TMP_MOVIL_ETAPA_0_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_MOVIL_ETAPA_0
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(COD_DW_PERSONA_IND_MOVIL)  ON '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (8):. Estadisticas para TMP_MOVIL_ETAPA_0_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_MOVIL_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_MOVIL_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_1 
	                AS (SELECT 	MTP0.TIPO_IDENTIFICACION
								,MTP0.NUMERO_IDENTIFICACION
								,MTP0.COD_DW_PERSONA_IND_MOVIL 
								,MTP0.FECHA
								,MTP0.DESCRIPCION
								,MTP0. NOVEDAD
								
								,MTP0.INFO_BASICA_ID
								,H1.Descripcion_Hom_Ind_Mov_Linea						
						FROM  '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1 MTP0
						LEFT JOIN '||P_BDVISTA||'.V_Hom_Ind_Mov_Linea h1
						ON MTP0.NOVEDAD=h1.Valor_Fuente	
						
						GROUP BY 1,2,3,4,5,6,7,8
					)WITH DATA
					PRIMARY INDEX (COD_DW_PERSONA_IND_MOVIL );';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (9):. Creacion Tabla TMP_MOVIL_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

 ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_MOVIL_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(COD_DW_PERSONA_IND_MOVIL)  ON '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (10):. Estadisticas para TMP_MOVIL_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
 	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_MOVIL_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_MOVIL_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_2 
						AS ( SELECT MTP1.COD_DW_PERSONA_IND_MOVIL  AS ID
									,MTP1.TIPO_IDENTIFICACION
									,MTP1.NUMERO_IDENTIFICACION
									,MTP1.FECHA
									,MTP1.DESCRIPCION
									,MTP1. NOVEDAD
									,MTP1.INFO_BASICA_ID
									,MTP1.Descripcion_Hom_Ind_Mov_Linea AS NOVEDAD_2	
									,CASE WHEN FOPI.ID_BURO_PERSONA IS NOT NULL THEN ''I''
									       WHEN FOPA.ID_BURO_PERSONA IS NOT NULL THEN ''A''
									 END AS FLAG_OP1
									,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP
									
							FROM  '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_1 MTP1	
							
							LEFT JOIN '||P_BDSTAGE||'.TMP_LUL LUL
							ON MTP1.INFO_BASICA_ID = LUL.INFO_BASICA
							
						    LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_I_INMOV FOPI 											
							ON LUL.INFO_BASICA = FOPI.ID_BURO_PERSONA
							
	                        LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_A_INMOV FOPA 			
							ON LUL.INFO_BASICA = FOPA.ID_BURO_PERSONA
							
							 )WITH DATA
						PRIMARY INDEX (ID );';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (11):. Creacion Tabla TMP_MOVIL_ETAPA_2' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

 ------------------------------------------------------------------------------------------------------------------------
   -- Ejecuta Estadisticas a la tabla TMP_MOVIL_ETAPA_2
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID)  ON '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (12):. Estadisticas para TMP_MOVIL_ETAPA_2' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Indic_Movilidad (13):. Barrando Tabla TMP_MOVIL_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF; 

------------------------------------------------------------------------------------------------------------------------
-- #1 BORRADO DE TEMPORALES
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_0'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_MOVIL_ETAPA_0_1'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_MOVIL_ETAPA_0_1';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_INMOV'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INMOV';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_INMOV'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INMOV';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	
------------------------------------------------------------------------------------------------------------------------
-- Actualiza la tabla LOG_TD
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Punto_Interes (14):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Info_Basica

 (  IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
	,IN P_BTTMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) 
) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_INBAS_ETAPA_10
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 Realizado por
 * 18-10-2018		#1 adicionar a la tabla el campo	 Fernando Garrido 
 * 03-12-2018		#2 Incluir Cod Pin Persona			 Andy Garcia
 * 					   y borrado de temporales.	
 * 07-12-2018		#3 Se incluye logica para GENERO	 Andy Garcia
 * 28-12-2018		#4 Se elimina Join Homo Genero		 Andy Garcia
 * 14-01-2019		#5 Desempate Act. Economica			 Andy Garcia
 * 15-01-2019		#6 Modificada la logica para Act.	 Andy Garcia
					   Economica en ETAPA 8 y ETAPA 9
 * 26-04-2019		#7 Cruce contra cod_pin_persona para  Jeimmy Chavez
 *                     traer la actividad economica de una
 *					   persona sin importar si es natural 
 *					   o juridica
 * 15-01-2019		#8 Se adiciona el campo RUT.	 Fernando Garrido
 * 14-02-2020       #9 Se incluyen identificaciones que no tienen informacion de ubicaciones para mostrar en web y ws.
 * 13-07-2021       #10 Ajuste Join para poder llevar las identificaciones sin datos de ubicacion.
 * 12-05-2025       #11 Ajuste para que tome los Datos 
 *						Basicos de la fuente mas confiable	John Bueno
 * --------------------------------------------------------------------------- 
 * ################################################################################
 */ 
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'InBas';
	SET nameTable = 'TMP_INBAS_ETAPA_10';
	
	------------------------------------------------------------------------------------------------------------------------
	-- Valida Tipo Ejecucion , is null = Carga Full, is not null = Carga Delta
	------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TRIM(TABLA_ORIGEN_STAGE) =:nameTable;
	------------------------------------------------------------------------------------------------------------------------
    -- Busca la tabla TMP_FLAG_OP_I_INBAS
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_INBAS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INBAS';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_I_INBAS
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INBAS AS(					
					SELECT COD_DW_PERSONA_UBIC AS ID_FLAG1,CAST(NULL AS INTEGER) AS ID_FLAG2 FROM '||P_BDDATOS||'.RELACION_PERSONA_UBICACION RPU
					WHERE RPU.LOTE IS NOT NULL AND RPU.LOTE_ACTUALIZACION IS NULL
					AND CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')  >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
					PRIMARY INDEX(ID_FLAG1);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (1):. Creacion Tabla TMP_FLAG_OP_I_INBAS' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Aplica Estadisticas a la tabla TMP_FLAG_OP_I_INBAS
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_FLAG1) ON '||P_BDSTAGE||'.TMP_FLAG_OP_I_INBAS;';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (2):. Estadisticas Tabla TMP_FLAG_OP_I_INBAS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	

	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_A_INBAS
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_INBAS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INBAS';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	

	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_A_INBAS
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INBAS AS ( 
	                SELECT COD_DW_PERSONA_UBIC AS ID_FLAG1,CAST(NULL AS INTEGER) AS ID_FLAG2 FROM '||P_BDDATOS||'.RELACION_PERSONA_UBICACION RPU
					WHERE RPU.LOTE_ACTUALIZACION IS NOT NULL
					AND CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')  >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
					PRIMARY INDEX(ID_FLAG1);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (3):. Creacion Tabla TMP_FLAG_OP_A_INBAS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	
	------------------------------------------------------------------------------------------------------------------------
    -- Aplica Estadisticas a la tabla TMP_FLAG_OP_A_INBAS
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_FLAG1) ON '||P_BDSTAGE||'.TMP_FLAG_OP_A_INBAS;';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (4):. Estadisticas Tabla TMP_FLAG_OP_A_INBAS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_INBAS_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_INBAS_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1 AS (
					SELECT RPU.COD_PIN_PERSONA
					,RPU.ID_BURO_PERSONA
					--,RUEG.COD_DW_TIPO_GRUPO_MOSAIC
					--,RPU.COD_DW_PERSONA_UBIC -- CORREGIDO ANDY GARCIA 23/05/2018
					FROM '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION RPU
					INNER JOIN '||P_BDVISTA||'.V_TIPO_UBICACION_DIRECCION VTUD ON VTUD.COD_DW_TIPO_UBICACION_DIR = RPU.COD_DW_TIPO_UBICACION_DIR
					--LEFT JOIN '||P_BDVISTA||'.V_RELACION_UBICAC_ESTANDAR_GEO RUEG  ON RUEG.COD_DW_UBIC = RPU.COD_DW_UBIC
					LEFT JOIN '||P_BDVISTA||'.V_BLOQUEO BQ ON RPU.COD_DW_PERSONA_UBIC=BQ.COD_DW_PERSONA_UBIC
					INNER JOIN '||P_BDVISTA||'.V_UBICACION_ESTANDARIZADA UES ON RPU.COD_DW_UBIC=UES.COD_DW_UBIC
					INNER JOIN '||P_BDVISTA||'.V_GESTION_REGISTRO GR ON UES.COD_DW_GESTION_REGISTRO=UES.COD_DW_GESTION_REGISTRO
					AND GR.DESCRIPCION_GESTION_REGISTRO=''VALIDA''
					INNER JOIN '||P_BDVISTA||'.V_TIPO_UBICACION TU ON UES.COD_DW_TIPO_UBICACION=TU.COD_DW_TIPO_UBICACION
					WHERE BQ.COD_DW_PERSONA_UBIC IS NULL
					AND (RPU.IND_UNIFICACION IS NULL OR RPU.IND_UNIFICACION='''' OR RPU.IND_UNIFICACION=0)
					AND RPU.ORDEN_PRIORIDAD IS NOT NULL
					QUALIFY ROW_NUMBER() OVER (PARTITION BY RPU.ID_BURO_PERSONA ORDER BY RPU.ORDEN_PRIORIDAD ASC) = 1
				)WITH DATA
                PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (5):. Creacion Tabla TMP_INBAS_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

  ------------------------------------------------------------------------------------------------------------------------
  -- Aplica Estadisticas a la tabla TMP_INBAS_ETAPA_1
  ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_BURO_PERSONA) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1;';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (6):. Estadisticas Tabla TMP_INBAS_ETAPA_1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;		
	 ------------------------------------------------------------------------------------------------------------------------
	 -- Busca la tabla TMP_INBAS_ETAPA_2
	 ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_INBAS_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_2 
	                AS (SELECT RPU.ID_BURO_PERSONA
					,RUEG.COD_DW_TIPO_GRUPO_MOSAIC
					--,RPU.COD_DW_PERSONA_UBIC -- CORREGIDO ANDY GARCIA 23/05/2018
					FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1 TET1
					INNER JOIN '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION RPU ON TET1.ID_BURO_PERSONA=RPU.ID_BURO_PERSONA
					INNER JOIN '||P_BDVISTA||'.V_TIPO_UBICACION_DIRECCION VTUD ON VTUD.COD_DW_TIPO_UBICACION_DIR = RPU.COD_DW_TIPO_UBICACION_DIR
					LEFT JOIN '||P_BDVISTA||'.V_RELACION_UBICAC_ESTANDAR_GEO RUEG  ON RUEG.COD_DW_UBIC = RPU.COD_DW_UBIC
					
					--AND RPU.COD_DW_DIRECCION_FISICA <> -1
					--LEFT JOIN '||P_BDVISTA||'.V_BLOQUEO BQ ON RPU.COD_DW_PERSONA_UBIC=BQ.COD_DW_PERSONA_UBIC
					INNER JOIN '||P_BDVISTA||'.V_UBICACION_ESTANDARIZADA UES ON RPU.COD_DW_UBIC=UES.COD_DW_UBIC
					INNER JOIN '||P_BDVISTA||'.V_GESTION_REGISTRO GR ON UES.COD_DW_GESTION_REGISTRO=UES.COD_DW_GESTION_REGISTRO
					AND GR.DESCRIPCION_GESTION_REGISTRO=''VALIDA''
					INNER JOIN '||P_BDVISTA||'.V_TIPO_UBICACION TU ON UES.COD_DW_TIPO_UBICACION=TU.COD_DW_TIPO_UBICACION
					AND TU.DESCRIPCION_TIPO_UBICACION=''GEOGRAFICA''
					
					INNER JOIN '||P_BDVISTA||'.V_GEOGRAFIA GEO ON UES.COD_DW_CIUDAD=GEO.COD_DW_CIUDAD /*#6*/
				 	
				 	INNER JOIN '||P_BDVISTA||'.VM_REPORTE_RELACION_PERS_UBI RRPU ON RPU.COD_DW_PERSONA_UBIC=RRPU.COD_DW_PERSONA_UBIC
				 	AND RRPU.ID_FLAG_DESDE=0 /*#6*/
				 
					WHERE VTUD.DESCRIPCION_TIPO_UBICACION_DIR = ''RES'' 
					--AND BQ.COD_DW_PERSONA_UBIC IS NULL
					AND (RPU.IND_UNIFICACION IS NULL OR RPU.IND_UNIFICACION='''' OR RPU.IND_UNIFICACION=0)
					AND (RUEG.COD_DW_GRUPO_MOSAIC>0 OR RUEG.COD_DW_TIPO_GRUPO_MOSAIC>0)
					AND RPU.ORDEN_PRIORIDAD IS NOT NULL
					QUALIFY ROW_NUMBER() OVER (PARTITION BY RPU.ID_BURO_PERSONA ORDER BY NVL(RPU.ORDEN_PRIORIDAD,999) ASC, RRPU.FECHA_REPORTE DESC, GEO.DESCRIPCION_CIUDAD, GEO.DESCRIPCION_DEPARTAMENTO) = 1 /*#6*/
				)WITH DATA
				PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (7):. Creacion Tabla TMP_INBAS_ETAPA_2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	
------------------------------------------------------------------------------------------------------------------------
-- Estadisticas a la tabla TMP_INBAS_ETAPA_2
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (8):. Estadisticas para Tabla TMP_INBAS_ETAPA_2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	
------------------------------------------------------------------------------------------------------------------------
-- Busca la tabla TMP_INBAS_ETAPA_3
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_INBAS_ETAPA_3
------------------------------------------------------------------------------------------------------------------------

SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_3 
	                AS (SELECT VPR.COD_PIN_PERSONA  /*#2*/
							 ,VPR.ID_BURO_PERSONA
							 ,VPR.NOMBRE_1
							 ,VPR.NOMBRE_2
							 ,VPR.APELLIDO_1
							 ,VPR.APELLIDO_2
							 ,VPR.Nombre_Completo
							 ,VPR.COD_TIPO_IDENT_FTE
							 ,VPR.NUM_IDENT
							 ,VPR.COD_EST_DOC_IDENT_FTE --Estado Documento
							 ,VPR.COD_DW_RANGO_EDAD
							 ,VPR.COD_DW_GENERO
							 ,VPR.Cod_DW_Est_Civil
							 ,VPR.COD_CIUDAD_EXPEDICION
							 ,VPR.FECHA_EXPEDICION
							 ,VPR.NOMBRE_RAZON_SOCIAL
							 ,TET2.COD_DW_TIPO_GRUPO_MOSAIC
					FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1 TET1
					INNER JOIN '||P_BTTPRUVI||'.VU_PERSONA VPR
					ON VPR.ID_BURO_PERSONA=TET1.ID_BURO_PERSONA
					LEFT JOIN '||P_BDSTAGE||'.TMP_INBAS_ETAPA_2 TET2
					ON VPR.ID_BURO_PERSONA=TET2.ID_BURO_PERSONA

					WHERE VPR.COD_DW_FTE_DATO IN (1,2,3,5,7,22)

					)WITH DATA
					PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (9):. Creacion Tabla TMP_INBAS_ETAPA_3'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	
   ------------------------------------------------------------------------------------------------------------------------
   -- drop tabla TMP_INBAS_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_1;';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (10):. Drop Tabla TMP_INBAS_ETAPA_1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
------------------------------------------------------------------------------------------------------------------------
-- drop tabla TMP_INBAS_ETAPA_2
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_2;';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (11):. Drop Tabla TMP_INBAS_ETAPA_2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;


------------------------------------------------------------------------------------------------------------------------
-- Estadisticas a la tabla TMP_INBAS_ETAPA_3
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona),COLUMN(COD_TIPO_IDENT_FTE,NUM_IDENT) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_3;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (12):. Estadisticas para Tabla TMP_INBAS_ETAPA_3'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;



---------------------------------------------
 ---------------------------------------------------------------------------
-- Busca la tabla TMP_INBAS_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_INBAS_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_4
                 	AS (SELECT  TET3.COD_PIN_PERSONA  /*#2*/
							 ,TET3.ID_BURO_PERSONA
							 ,TET3.NOMBRE_1
							 ,TET3.NOMBRE_2
							 ,TET3.APELLIDO_1
							 ,TET3.APELLIDO_2
							 ,TET3.Nombre_Completo
							 ,TET3.COD_TIPO_IDENT_FTE
							 ,TET3.NUM_IDENT
							 ,TET3.COD_EST_DOC_IDENT_FTE --Estado Documento
							 ,TET3.COD_DW_RANGO_EDAD
							 ,TET3.COD_DW_GENERO
							 ,TET3.Cod_DW_Est_Civil
							 ,TET3.COD_CIUDAD_EXPEDICION
							 ,TET3.FECHA_EXPEDICION
							 ,TET3.NOMBRE_RAZON_SOCIAL
							 ,TET3.COD_DW_TIPO_GRUPO_MOSAIC
							 ,BPT.Id_Buro_Persona ID_BuroP_MJF
					FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_3 TET3
					LEFT JOIN '||P_BDSTAGE||'.Vstg_BUROPERS_TMP BPT 
					ON TET3.NUM_IDENT = BPT. NUM_IDENT AND 
					TET3.Cod_Tipo_Ident_Fte = BPT.Cod_Tipo_Ident_Fte
					)WITH DATA
                	PRIMARY INDEX(ID_Buro_Persona);';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (13):. Creacion Tabla TMP_INBAS_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Estadisticas a la tabla TMP_INBAS_ETAPA_4
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona),COLUMN(COD_EST_DOC_IDENT_FTE)
	                             ,COLUMN(COD_DW_RANGO_EDAD),COLUMN(COD_DW_GENERO)
								 ,COLUMN(COD_CIUDAD_EXPEDICION) 
	                 ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_4;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (14):. Estadisticas para Tabla TMP_INBAS_ETAPA_4'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	
------------------------------------------------------------------------------------------------------------------------
-- drop tabla TMP_INBAS_ETAPA_3
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_3;';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (15):. Drop Tabla TMP_INBAS_ETAPA_3'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	
  ------------------------------------------------------------------------------------------------------------------------
  -- Busca la tabla TMP_INBAS_ETAPA_5
  ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_INBAS_ETAPA_5
------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_5 
                  	AS (SELECT  TET4.COD_PIN_PERSONA /*#2*/
							 ,TET4.ID_BURO_PERSONA
							 ,TET4.NOMBRE_1
							 ,TET4.NOMBRE_2
							 ,TET4.APELLIDO_1
							 ,TET4.APELLIDO_2
							 ,TET4.Nombre_Completo
							 ,TET4.COD_TIPO_IDENT_FTE
							 ,TET4.NUM_IDENT
							 ,TET4.COD_EST_DOC_IDENT_FTE --Estado Documento
							 ,TET4.COD_DW_RANGO_EDAD
							 ,TET4.COD_DW_GENERO
							 ,TET4.Cod_DW_Est_Civil
							 ,TET4.COD_CIUDAD_EXPEDICION
							 ,TET4.FECHA_EXPEDICION
							 ,TET4.NOMBRE_RAZON_SOCIAL
							 ,TET4.COD_DW_TIPO_GRUPO_MOSAIC
							 ,TET4.ID_BuroP_MJF  /*#11*/
							 ,Trim(Cast(VRE.Edad_Desde_Rango_Edad AS CHAR(3)))||CASE WHEN VRE.Edad_hasta_rango_edad > 100 THEN ''+'' ELSE ''-''||Cast(VRE.Edad_hasta_rango_edad  AS CHAR(5)) END RANGO_EDAD
							 ,VJG.NOMBRE_CIUDAD AS LUGAR_EXPEDICION
							-- ,VPR.FECHA_EXPEDICION AS FECHA_EXPEDICION
							 /*,VGEC.DESC_GENERO_HOM AS GENERO-- #2*/
							--,COALESCE(VGEC.DESC_GENERO_HOM,VG.COD_GENERO_FTE) AS GENERO /*#3*/ /*#4*/   
							,VG.COD_GENERO_FTE AS GENERO /*#4*/
							 ,VJG.NOMBRE_DEPARTAMENTO AS DEPARTAMENTO_EXPEDICION -- #1					 
					FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_4 TET4
					--LEFT JOIN '||P_BTTPRUVI||'.V_ESTADO_REPORTADO_DOC_IDENT VERC  ON VERC.COD_EST_DOC_IDENT_FTE = VPR.COD_EST_DOC_IDENT_FTE-- #2 Cambio el join Luis Carlos R.
					LEFT JOIN '||P_BTTPRUVI||'.V_RANGO_EDAD VRE         ON TET4.COD_DW_RANGO_EDAD = VRE.COD_DW_RANGO_EDAD
					-- LEFT JOIN '||P_BDVISTA||'.VU_GENERO_ESTADO_CIVIL VGEC    ON TET4.COD_DW_GENERO = VGEC.COD_DW_GENERO AND TET4.Cod_DW_Est_Civil = VGEC.Cod_DW_Est_Civil -- #2 Join Nuevo	#4 Se elimina Join
					LEFT JOIN '||P_BTTPRUVI||'.V_JERARQUIA_GEOGRAFICA VJG     ON TET4.COD_CIUDAD_EXPEDICION= VJG.COD_DW_CIUDAD -- #1 Cambio el join Luis Carlos R.
					LEFT JOIN '||P_BTTPRUVI||'.V_GENERO VG  ON   TET4.COD_DW_GENERO=VG.COD_DW_GENERO /*#3*/
					)WITH DATA
					PRIMARY INDEX(ID_Buro_Persona);';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (16):. Creacion Tabla TMP_INBAS_ETAPA_5'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Estadisticas a la tabla TMP_INBAS_ETAPA_5
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_5;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (17):. Estadisticas para Tabla TMP_INBAS_ETAPA_5'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	
------------------------------------------------------------------------------------------------------------------------
-- drop tabla TMP_INBAS_ETAPA_4
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_4;';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (18):. Drop Tabla TMP_INBAS_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------------------------------------
-- Busca la tabla TMP_INBAS_ETAPA_6
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	

------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_INBAS_ETAPA_6
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6 
					AS (SELECT  TET5.COD_PIN_PERSONA /*#2*/
						 ,TET5.ID_BURO_PERSONA
						 ,TET5.NOMBRE_1
						 ,TET5.NOMBRE_2
						 ,TET5.APELLIDO_1
						 ,TET5.APELLIDO_2
						 ,TET5.Nombre_Completo
						 ,TET5.COD_TIPO_IDENT_FTE
						 ,TET5.NUM_IDENT
						 ,TET5.COD_EST_DOC_IDENT_FTE --Estado Documento
						 ,TET5.COD_DW_RANGO_EDAD
						 ,TET5.COD_DW_GENERO
						 ,TET5.Cod_DW_Est_Civil
						 ,TET5.COD_CIUDAD_EXPEDICION
						 ,TET5.FECHA_EXPEDICION
						 ,TET5.NOMBRE_RAZON_SOCIAL
						 ,TET5.COD_DW_TIPO_GRUPO_MOSAIC
						 ,TET5.Id_Buro_Persona ID_BuroP_MJF
						 ,TET5.RANGO_EDAD
						 ,TET5.LUGAR_EXPEDICION
						 ,TET5.GENERO-- #2
						 ,TET5.DEPARTAMENTO_EXPEDICION -- #1
						 
						 ,VPR2.NOMBRE_1 AS NOMBRE_1_2 
						 ,VPR2.NOMBRE_2 AS NOMBRE_2_2
						 ,VPR2.APELLIDO_1 AS APELLIDO_1_2
						 ,VPR2.APELLIDO_2 AS APELLIDO_2_2
						 ,VPR2.Nombre_Completo AS Nombre_Completo_2
						 ,VPR2.COD_TIPO_IDENT_FTE AS COD_TIPO_IDENT_FTE_2
						 ,VPR2.NUM_IDENT AS NUM_IDENT_2
						 ,VPR2.COD_EST_DOC_IDENT_FTE AS COD_EST_DOC_IDENT_FTE_2  --Estado Documento
						 ,VPR2.COD_DW_RANGO_EDAD AS COD_DW_RANGO_EDAD_2
						 ,VPR2.COD_DW_GENERO AS COD_DW_GENERO_2
						 ,VPR2.Cod_DW_Est_Civil AS Cod_DW_Est_Civil_2
						 ,VPR2.COD_CIUDAD_EXPEDICION AS COD_CIUDAD_EXPEDICION_2
						 ,VPR2.FECHA_EXPEDICION AS FECHA_EXPEDICION_2
						 ,VPR2.NOMBRE_RAZON_SOCIAL AS NOMBRE_RAZON_SOCIAL_2
							 
						 FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_5 TET5
						 LEFT JOIN '||P_BTTPRUVI||'.VU_PERSONA VPR2
						 ON TET5.ID_BuroP_MJF=VPR2.ID_BURO_PERSONA
					)WITH DATA
					PRIMARY INDEX(ID_Buro_Persona);';
	 
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (19):. Creacion Tabla TMP_INBAS_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF; 
	 
	 
------------------------------------------------------------------------------------------------------------------------
-- Estadisticas a la tabla TMP_INBAS_ETAPA_6
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona),COLUMN(COD_EST_DOC_IDENT_FTE_2)
							,COLUMN(COD_DW_RANGO_EDAD_2),COLUMN(COD_DW_GENERO_2)
							,COLUMN(COD_CIUDAD_EXPEDICION_2) 
					ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Info_Basica (20):. Estadisticas para Tabla TMP_INBAS_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	
------------------------------------------------------------------------------------------------------------------------
-- drop tabla TMP_INBAS_ETAPA_5
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_5;';

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
								,:P_Nombre_Proceso_Padre 
								,:V_CADENA 
								,'SP_Linea_Info_Basica (21):. Drop Tabla TMP_INBAS_ETAPA_5'
								,V_ERROR);
								
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;		 
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_INBAS_ETAPA_7
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	 
	------------------------------------------------------------------------------------------------------------------------
    -- Crea la tabla TMP_INBAS_ETAPA_7
    ------------------------------------------------------------------------------------------------------------------------
   
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7 
					 AS (SELECT TET6.COD_PIN_PERSONA /*#2*/
								,TET6.ID_BURO_PERSONA
								,TET6.NOMBRE_1
								,TET6.NOMBRE_2
								,TET6.APELLIDO_1
								,TET6.APELLIDO_2
								,TET6.Nombre_Completo
								,TET6.COD_TIPO_IDENT_FTE
								,TET6.NUM_IDENT
								,TET6.COD_EST_DOC_IDENT_FTE --Estado Documento
								,TET6.COD_DW_RANGO_EDAD
								,TET6.COD_DW_GENERO
								,TET6.Cod_DW_Est_Civil
								,TET6.COD_CIUDAD_EXPEDICION
								,TET6.FECHA_EXPEDICION
								,TET6.NOMBRE_RAZON_SOCIAL
								,TET6.COD_DW_TIPO_GRUPO_MOSAIC
								,TET6.Id_Buro_Persona ID_BuroP_MJF
								,TET6.RANGO_EDAD
								,TET6.LUGAR_EXPEDICION
								,TET6.GENERO-- #2
								,TET6.DEPARTAMENTO_EXPEDICION -- #1
								,TET6. NOMBRE_1_2 
								,TET6.NOMBRE_2_2
								,TET6.APELLIDO_1_2
								,TET6.APELLIDO_2_2
								,TET6.Nombre_Completo_2
								,TET6.COD_TIPO_IDENT_FTE_2
								,TET6.NUM_IDENT_2
								,TET6.COD_EST_DOC_IDENT_FTE_2  --Estado Documento
								,TET6.COD_DW_RANGO_EDAD_2
								,TET6.COD_DW_GENERO_2
								,TET6.Cod_DW_Est_Civil_2
								,TET6.COD_CIUDAD_EXPEDICION_2
								,TET6.FECHA_EXPEDICION_2
								,TET6.NOMBRE_RAZON_SOCIAL_2
								,Trim(Cast(VRE.Edad_Desde_Rango_Edad AS CHAR(3)))||CASE WHEN VRE.Edad_hasta_rango_edad > 100 THEN ''+'' ELSE ''-''||Cast(VRE.Edad_hasta_rango_edad  AS CHAR(5)) END RANGO_EDAD_2
								,VJG.NOMBRE_CIUDAD AS LUGAR_EXPEDICION_2
								-- ,VPR.FECHA_EXPEDICION AS FECHA_EXPEDICION
								--,VGEC.DESC_GENERO_HOM AS GENERO_2-- #2
								,VG.COD_GENERO_FTE AS GENERO_2 /*#4*/
								,VJG.NOMBRE_DEPARTAMENTO AS DEPARTAMENTO_EXPEDICION_2 -- #1
						FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6 TET6
						--LEFT JOIN '||P_BTTPRUVI||'.V_ESTADO_REPORTADO_DOC_IDENT VERC  ON VERC.COD_EST_DOC_IDENT_FTE = VPR.COD_EST_DOC_IDENT_FTE-- #2 Cambio el join Luis Carlos R.
						LEFT JOIN '||P_BTTPRUVI||'.V_RANGO_EDAD VRE         ON TET6.COD_DW_RANGO_EDAD_2 = VRE.COD_DW_RANGO_EDAD
						--LEFT JOIN '||P_BDVISTA||'.VU_GENERO_ESTADO_CIVIL VGEC    ON TET6.COD_DW_GENERO_2 = VGEC.COD_DW_GENERO AND TET6.Cod_DW_Est_Civil = VGEC.Cod_DW_Est_Civil -- #2 Join Nuevo	
						
						LEFT JOIN '||P_BTTPRUVI||'.V_GENERO VG  ON   TET6.COD_DW_GENERO=VG.COD_DW_GENERO /*#4*/
						LEFT JOIN '||P_BTTPRUVI||'.V_JERARQUIA_GEOGRAFICA VJG     ON TET6.COD_CIUDAD_EXPEDICION_2= VJG.COD_DW_CIUDAD -- #1 Cambio el join Luis Carlos R.
						)WITH DATA
					PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (22):. Creacion Tabla Linea_Info_Basica' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a InBas_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Info_Basica (23):. Estadisticas para '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7;'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza la tabla LOG_TD
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = ' CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8 
					 AS (SELECT TET7.COD_PIN_PERSONA /*#2*/
								,TET7.ID_BURO_PERSONA
								,TET7.NOMBRE_1
								,TET7.NOMBRE_2
								,TET7.APELLIDO_1
								,TET7.APELLIDO_2
								,TET7.Nombre_Completo
								,TET7.COD_TIPO_IDENT_FTE
								,TET7.NUM_IDENT
								,TET7.COD_EST_DOC_IDENT_FTE --Estado Documento
								,TET7.COD_DW_RANGO_EDAD
								,TET7.COD_DW_GENERO
								,TET7.Cod_DW_Est_Civil
								,TET7.COD_CIUDAD_EXPEDICION
								,TET7.FECHA_EXPEDICION
								,TET7.NOMBRE_RAZON_SOCIAL
								,TET7.COD_DW_TIPO_GRUPO_MOSAIC
								,TET7.Id_Buro_Persona ID_BuroP_MJF
								,TET7.RANGO_EDAD
								,TET7.LUGAR_EXPEDICION
								,TET7.GENERO-- #2
								,TET7.DEPARTAMENTO_EXPEDICION -- #1

								,TET7.NOMBRE_1_2 
								,TET7.NOMBRE_2_2
								,TET7.APELLIDO_1_2
								,TET7.APELLIDO_2_2
								,TET7.Nombre_Completo_2
								,TET7.COD_TIPO_IDENT_FTE_2
								,TET7.NUM_IDENT_2
								,TET7.COD_EST_DOC_IDENT_FTE_2  --Estado Documento
								,TET7.COD_DW_RANGO_EDAD_2
								,TET7.COD_DW_GENERO_2
								,TET7.Cod_DW_Est_Civil_2
								,TET7.COD_CIUDAD_EXPEDICION_2
								,TET7.FECHA_EXPEDICION_2
								,TET7.NOMBRE_RAZON_SOCIAL_2

								,TET7.RANGO_EDAD_2
								,TET7.LUGAR_EXPEDICION_2
								,TET7.GENERO_2-- #2
								,TET7.DEPARTAMENTO_EXPEDICION_2 -- #1

								/*Inicia #6 */
								/*
								,VAEC.COD_ACT_ECONO_CIIU_FTE AS CIIU
								,VAEC.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA
								,VMCC.PAGINA_WEB AS PAGINA_WEB 
								*/
								
								,VAEC.COD_ACT_ECONO_CIIU_FTE AS CIIU1
								,VAEC.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA1
								,VMCC.PAGINA_WEB AS PAGINA_WEB1
								
								,VAEC2.COD_ACT_ECONO_CIIU_FTE AS CIIU2
								,VAEC2.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA2
								,VAEC2.PAGINA_WEB AS PAGINA_WEB2
								
								,COALESCE(CIIU1,CIIU2) CIIU
								,COALESCE(ACTIVIDAD_ECONOMICA1,ACTIVIDAD_ECONOMICA2) ACTIVIDAD_ECONOMICA
								,COALESCE(PAGINA_WEB1,PAGINA_WEB2) PAGINA_WEB
								/*Fin #6 */
								
							FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7 TET7 
							/*LEFT JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE ON TET7.ID_BURO_PERSONA =  VPAE.ID_BURO_PERSONA AND VPAE.Ind_Act_Principal =''S''
							LEFT JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC     ON VAEC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU
							LEFT JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    ON VPJC.ID_BURO_PERSONA = VPAE.ID_BURO_PERSONA AND VPJC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU
							LEFT JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA
							QUALIFY (ROW_NUMBER()OVER(PARTITION BY TET7.ID_BURO_PERSONA ORDER BY CAST(VAEC.Cod_Act_Econo_CIIU_Fte AS INTEGER) DESC, VAEC.VERSION_CODIFICACION_CIIU DESC))=1*/	/*#5*/ /*#6*/
							
							/* Inicia #6 */
							LEFT JOIN (SELECT 
										TET7.ID_BURO_PERSONA
										,TET7.COD_PIN_PERSONA
										,VAEC.COD_ACT_ECONO_CIIU_FTE
										,VAEC.DESC_ACT_ECONO_CIIU 
										,VPAE.COD_DW_ACT_ECONO_CIIU
										FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7 TET7 
										INNER JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE ON TET7.COD_PIN_PERSONA =  VPAE.COD_PIN_PERSONA 
										AND VPAE.Ind_Act_Principal =''S''
										INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC     ON VAEC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU 
										QUALIFY (ROW_NUMBER()OVER(PARTITION BY TET7.ID_BURO_PERSONA ORDER BY CAST(VAEC.Cod_Act_Econo_CIIU_Fte AS INTEGER) DESC, VAEC.VERSION_CODIFICACION_CIIU DESC))=1
										) VAEC
							ON TET7.ID_BURO_PERSONA=VAEC.ID_BURO_PERSONA
							
							LEFT JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    
							ON VPJC.COD_PIN_PERSONA = VAEC.COD_PIN_PERSONA 
							AND VPJC.COD_DW_ACT_ECONO_CIIU = VAEC.COD_DW_ACT_ECONO_CIIU
							
							LEFT JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  
							ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA	  
							
							LEFT JOIN ( SELECT 
										TET7.ID_BURO_PERSONA
										,VAEC.COD_ACT_ECONO_CIIU_FTE
										,VAEC.DESC_ACT_ECONO_CIIU 
										,VMCC.PAGINA_WEB
										FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7 TET7 
										INNER JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    
										ON VPJC.COD_PIN_PERSONA = TET7.COD_PIN_PERSONA 
										INNER JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  
										ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA	
										INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC ON VPJC.COD_DW_ACT_ECONO_CIIU=VAEC.COD_DW_ACT_ECONO_CIIU
										WHERE  VPJC.IND_ACTIVO=''1''
										AND VPJC.IND_ACTIVIDAD_PRINCIPAL=''1''
										QUALIFY (ROW_NUMBER()OVER (PARTITION BY TET7.ID_BURO_PERSONA ORDER BY VPJC.Fecha_Ult_Renovacion DESC , VPJC.COD_DW_FTE_DATO ASC, CAST(VAEC.COD_ACT_ECONO_CIIU_FTE AS INTEGER) DESC ,NULLIF(VMCC.PAGINA_WEB,'''') DESC))=1
									  ) VAEC2
							ON TET7.ID_BURO_PERSONA=VAEC2.ID_BURO_PERSONA
							
							/* Fin #6 */
					 )
					 WITH DATA
					 PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (24):. Se crea la tabla TMP_INBAS_ETAPA_8' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	
   ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza la tabla LOG_TD
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona), COLUMN(ID_BuroP_MJF) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (25):. Estadisticas para tabla TMP_INBAS_ETAPA_8' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza la tabla LOG_TD
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9 
					AS (SELECT TET8.COD_PIN_PERSONA /*#2*/
							,TET8.ID_BURO_PERSONA
							,TET8.NOMBRE_1
							,TET8.NOMBRE_2
							,TET8.APELLIDO_1
							,TET8.APELLIDO_2
							,TET8.Nombre_Completo
							,TET8.COD_TIPO_IDENT_FTE
							,TET8.NUM_IDENT
							,TET8.COD_EST_DOC_IDENT_FTE --Estado Documento
							,TET8.COD_DW_RANGO_EDAD
							,TET8.COD_DW_GENERO
							,TET8.Cod_DW_Est_Civil
							,TET8.COD_CIUDAD_EXPEDICION
							,TET8.FECHA_EXPEDICION
							,TET8.NOMBRE_RAZON_SOCIAL
							,TET8.COD_DW_TIPO_GRUPO_MOSAIC
							,TET8.Id_Buro_Persona ID_BuroP_MJF
							,TET8.RANGO_EDAD
							,TET8.LUGAR_EXPEDICION
							,TET8.GENERO-- #2
							,TET8.DEPARTAMENTO_EXPEDICION -- #1

							,TET8.NOMBRE_1_2 
							,TET8.NOMBRE_2_2
							,TET8.APELLIDO_1_2
							,TET8.APELLIDO_2_2
							,TET8.Nombre_Completo_2
							,TET8.COD_TIPO_IDENT_FTE_2
							,TET8.NUM_IDENT_2
							,TET8.COD_EST_DOC_IDENT_FTE_2  --Estado Documento
							,TET8.COD_DW_RANGO_EDAD_2
							,TET8.COD_DW_GENERO_2
							,TET8.Cod_DW_Est_Civil_2
							,TET8.COD_CIUDAD_EXPEDICION_2
							,TET8.FECHA_EXPEDICION_2
							,TET8.NOMBRE_RAZON_SOCIAL_2

							,TET8.RANGO_EDAD_2
							,TET8.LUGAR_EXPEDICION_2
							,TET8.GENERO_2-- #2
							,TET8.DEPARTAMENTO_EXPEDICION_2 -- #1

							,TET8.CIIU
							,TET8.ACTIVIDAD_ECONOMICA
							,TET8.PAGINA_WEB
							
							/* Inicia #6 */
							
							/*
							,VAEC.COD_ACT_ECONO_CIIU_FTE AS CIIU_2
							,VAEC.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA_2
							,VMCC.PAGINA_WEB AS PAGINA_WEB_2
							*/ 							
							
							,VAEC.COD_ACT_ECONO_CIIU_FTE AS CIIU1
							,VAEC.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA1
							,VMCC.PAGINA_WEB AS PAGINA_WEB1
								
							,VAEC2.COD_ACT_ECONO_CIIU_FTE AS CIIU2
							,VAEC2.DESC_ACT_ECONO_CIIU AS ACTIVIDAD_ECONOMICA2
							,VAEC2.PAGINA_WEB AS PAGINA_WEB2

							,COALESCE(CIIU1,CIIU2) AS CIIU_2
							,COALESCE(ACTIVIDAD_ECONOMICA1,ACTIVIDAD_ECONOMICA2) AS ACTIVIDAD_ECONOMICA_2
							,COALESCE(PAGINA_WEB1,PAGINA_WEB2) AS PAGINA_WEB_2
							
							/* Fin #6 */
					 
						FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8 TET8 
						/*
						LEFT JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE ON TET8.ID_BuroP_MJF =  VPAE.ID_BURO_PERSONA AND VPAE.Ind_Act_Principal =''S''
						LEFT JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC     ON VAEC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU
						LEFT JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    ON VPJC.ID_BURO_PERSONA = VPAE.ID_BURO_PERSONA AND VPJC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU
						LEFT JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA
						QUALIFY (ROW_NUMBER()OVER(PARTITION BY TET8.ID_BURO_PERSONA ORDER BY CAST(VAEC.Cod_Act_Econo_CIIU_Fte AS INTEGER) DESC, VAEC.VERSION_CODIFICACION_CIIU DESC))=1	*/  /*#5*/ /*#6*/
						
						/* Inicia #6 */
						LEFT JOIN (SELECT TET8 .ID_BURO_PERSONA
									,VAEC.COD_ACT_ECONO_CIIU_FTE
									,VAEC.DESC_ACT_ECONO_CIIU 
									,VPAE.COD_DW_ACT_ECONO_CIIU
									FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8 TET8 
									INNER JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE ON TET8.ID_BuroP_MJF =  VPAE.ID_BURO_PERSONA AND VPAE.Ind_Act_Principal =''S''
									INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC     ON VAEC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU 
									QUALIFY (ROW_NUMBER()OVER(PARTITION BY TET8.ID_BURO_PERSONA ORDER BY CAST(VAEC.Cod_Act_Econo_CIIU_Fte AS INTEGER) DESC, VAEC.VERSION_CODIFICACION_CIIU DESC))=1
									) VAEC
						ON TET8.ID_BURO_PERSONA=VAEC.ID_BURO_PERSONA
							
						LEFT JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    ON VPJC.ID_BURO_PERSONA = VAEC.ID_BURO_PERSONA AND VPJC.COD_DW_ACT_ECONO_CIIU = VAEC.COD_DW_ACT_ECONO_CIIU
						LEFT JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA	  
							
						LEFT JOIN (	SELECT TET8 .ID_BURO_PERSONA
														,VAEC.COD_ACT_ECONO_CIIU_FTE
														,VAEC.DESC_ACT_ECONO_CIIU 
														,VMCC.PAGINA_WEB
														FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8 TET8 
														INNER JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    ON VPJC.ID_BURO_PERSONA = TET8.ID_BuroP_MJF 
														INNER JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA	
														INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC ON VPJC.COD_DW_ACT_ECONO_CIIU=VAEC.COD_DW_ACT_ECONO_CIIU
														WHERE  VPJC.IND_ACTIVO=''1''
														AND VPJC.IND_ACTIVIDAD_PRINCIPAL=''1''
														QUALIFY (ROW_NUMBER()OVER (PARTITION BY TET8.ID_BURO_PERSONA ORDER BY VPJC.Fecha_Ult_Renovacion DESC , VPJC.COD_DW_FTE_DATO ASC, CAST(VAEC.COD_ACT_ECONO_CIIU_FTE AS INTEGER) DESC ,NULLIF(VMCC.PAGINA_WEB,'''') DESC))=1
													  ) VAEC2
							ON TET8.ID_BURO_PERSONA=VAEC2.ID_BURO_PERSONA
						
						/* Fin #6 */
						
					)WITH DATA
					PRIMARY INDEX(ID_Buro_Persona);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (26):. Se crea la tabla TMP_INBAS_ETAPA_9' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza la tabla LOG_TD
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (27):. Estadisticas para TMP_INBAS_ETAPA_9' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_9_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_1';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Creacion table TMP_INBAS_ETAPA_9_1 con informacion de personas con datos de ubicacion 
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_1 
					AS (SELECT  TET9.COD_PIN_PERSONA /*#2*/
								,ID_BURO_PERSONA AS ID
								,COALESCE(NOMBRE_1_2, NOMBRE_1) AS PRIMER_NOMBRE
								,COALESCE(NOMBRE_2_2, NOMBRE_2) AS SEGUNDO_NOMBRE
								,COALESCE(APELLIDO_1_2, APELLIDO_1) AS PRIMER_APELLIDO
								,COALESCE(APELLIDO_2_2, APELLIDO_2) AS SEGUNDO_APELLIDO
								,COALESCE(Nombre_Completo_2, Nombre_Completo) AS NOMBRE_COMPLETO
								,COALESCE(COD_TIPO_IDENT_FTE_2, COD_TIPO_IDENT_FTE) COD_TIPO_IDENT_FTE
								,h1.Descripcion_Hom_Tip_Ident_Linea AS TIPO_IDENTIFICACION
								,CAST(COALESCE(NUM_IDENT_2, NUM_IDENT) AS BIGINT)  AS NUMERO_IDENTIFICACION
								,COALESCE(COD_EST_DOC_IDENT_FTE_2, COD_EST_DOC_IDENT_FTE) ESTADO_DOCUMENTO
								,COALESCE(RANGO_EDAD_2,RANGO_EDAD) AS RANGO_EDAD
								,COALESCE(LUGAR_EXPEDICION_2, LUGAR_EXPEDICION) AS LUGAR_EXPEDICION
								,COALESCE(FECHA_EXPEDICION_2,FECHA_EXPEDICION) AS FECHA_EXPEDICION
								,COALESCE(GENERO_2, GENERO,'''') AS GENERO-- #2
								,COALESCE(CIIU_2,CIIU) AS CIIU
								,COALESCE(ACTIVIDAD_ECONOMICA_2, ACTIVIDAD_ECONOMICA) AS ACTIVIDAD_ECONOMICA
								,COALESCE(NOMBRE_RAZON_SOCIAL_2, NOMBRE_RAZON_SOCIAL) AS RAZON_SOCIAL
								,COALESCE(PAGINA_WEB_2,PAGINA_WEB) AS PAGINA_WEB
								,COD_DW_TIPO_GRUPO_MOSAIC AS MOSAIC_ID -- CORREGIDO ANDY GARCIA 23/05/2018
								,COALESCE(DEPARTAMENTO_EXPEDICION_2, DEPARTAMENTO_EXPEDICION ) AS DEPARTAMENTO_EXPEDICION -- #1								
								,CASE WHEN FOPI.ID_FLAG1 IS NOT NULL AND FOPI.ID_FLAG2 IS NOT NULL THEN ''I''
			                          WHEN FOPA.ID_FLAG1 IS NOT NULL AND FOPA.ID_FLAG2 IS NOT NULL THEN ''A''
	                             END AS FLAG_OP1
								,CASE WHEN B.COD_PIN_PERSONA  IS NOT NULL THEN ''S'' ELSE ''N'' END RUT
								,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP
								
						FROM 	'||P_BDSTAGE||'.TMP_INBAS_ETAPA_9 TET9
						LEFT JOIN '||P_BDVISTA||'.V_Hom_Tip_Ident_Linea h1
						ON COALESCE(COD_TIPO_IDENT_FTE_2, COD_TIPO_IDENT_FTE)=h1.Valor_Fuente
						
						LEFT JOIN (SEL COD_PIN_PERSONA 
						           FROM  '||P_BTTPRUVI||'.VU_PERSONA
						           WHERE COD_DW_FTE_DATO = 2
                                    GROUP BY  1) B
                        ON TET9.COD_PIN_PERSONA = B.COD_PIN_PERSONA 
						

						LEFT JOIN '||P_BDVISTA||'.V_Hom_Genero_Linea h2
						ON COALESCE(GENERO_2,GENERO)=h2.Valor_Fuente
						
						LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_I_INBAS FOPI 											
						ON TET9.ID_BURO_PERSONA = FOPI.ID_FLAG1
                        AND FOPI.ID_FLAG2 IS NULL
						
	                    LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_A_INBAS FOPA 
						ON TET9.ID_BURO_PERSONA = FOPA.ID_FLAG1
						AND FOPA.ID_FLAG2 IS NULL	
					)
					WITH DATA
					PRIMARY INDEX(ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (28):. Se crea la tabla TMP_INBAS_ETAPA_9_1' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	

	SET V_CADENA = '';
 	SET V_CADENA = 'COLLECT STATS INDEX(ID) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_1';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (29):. Estadisticas para TMP_INBAS_ETAPA_9_1' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;	
	
------------------------------------------------------------------------------------------------------------------------
-- Creacion tablas con informacion de personas sin datos de ubicacion #9
------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'Persona_Sin_Ubic'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.Persona_Sin_Ubic';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;




SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Persona_Sin_Ubic AS
			(
			SELECT 
			a.Id_Buro_Persona
			,a.Cod_PIN_Persona
			,a.Num_Ident
			,a.Cod_Tipo_Ident_Fte
			,b.id
			FROM '||P_BDSTAGE||'.Vstg_BUROPERS_TMP a 
			LEFT OUTER JOIN '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_1 b 
			ON Cast(a.Num_Ident AS BIGINT) = Cast(b.NUMERO_IDENTIFICACION AS BIGINT)
			AND a.Cod_Tipo_Ident_Fte = b.COD_TIPO_IDENT_FTE
			WHERE a.Cod_DW_Fte_Dato IN (1,2,3,5,7,22)
			AND b.id IS NULL
			)
			WITH DATA
			PRIMARY INDEX(Id_Buro_Persona);';
			
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (28):. Se crea la tabla Persona_Sin_Ubic' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	


			
	  ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza estadisticas 
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'COLLECT STATS INDEX(ID_Buro_Persona) ON '||P_BDSTAGE||'.Persona_Sin_Ubic';


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (28):. Estadisticas para Persona_Sin_Ubic' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_9_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;



	
------------------------------------------------------------------------------------------------------------------------
-- Creacion tablas con informacion de personas sin datos de ubicacion TMP_INBAS_ETAPA_9_2 #9
------------------------------------------------------------------------------------------------------------------------			


SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_2 
					AS (
					SELECT
						b.Cod_PIN_Persona
						,b.id_buro_persona AS ID
						,B.Nombre_1 AS PRIMER_NOMBRE
						,B.Nombre_2 AS SEGUNDO_NOMBRE
						,B.Apellido_1 AS PRIMER_APELLIDO
						,B.Apellido_2 AS SEGUNDO_APELLIDO
						,B.NOMBRE_COMPLETO
						,B.COD_TIPO_IDENT_FTE
						,h1.Descripcion_Hom_Tip_Ident_Linea AS TIPO_IDENTIFICACION
						,Cast(B.Num_Ident AS BIGINT)AS NUMERO_IDENTIFICACION
						,Cod_Est_Doc_Ident_Fte AS ESTADO_DOCUMENTO
						,Trim(Cast(VRE.Edad_Desde_Rango_Edad AS CHAR(3)))||CASE WHEN VRE.Edad_hasta_rango_edad > 100 THEN ''+'' ELSE ''-''||Cast(VRE.Edad_hasta_rango_edad  AS CHAR(5)) END RANGO_EDAD
						,VJG.NOMBRE_CIUDAD AS LUGAR_EXPEDICION
						,B.FECHA_EXPEDICION
						,Cod_Genero_Fte AS GENERO
						,Coalesce(VAEC.COD_ACT_ECONO_CIIU_FTE, VAEC2.COD_ACT_ECONO_CIIU_FTE) AS CIIU
						,Coalesce(VAEC.DESC_ACT_ECONO_CIIU, VAEC2.DESC_ACT_ECONO_CIIU) AS ACTIVIDAD_ECONOMICA
						,Nombre_Razon_Social AS RAZON_SOCIAL
						,Coalesce(VMCC.PAGINA_WEB, VAEC2.PAGINA_WEB )  AS PAGINA_WEB
						,NULL AS MOSAIC_ID
						,VJG.NOMBRE_DEPARTAMENTO AS DEPARTAMENTO_EXPEDICION
						,CASE WHEN a.id IS NOT NULL THEN ''A''
							WHEN a.id  IS NULL THEN ''I''
						END AS FLAG_OP1
						,CASE WHEN b.COD_DW_FTE_DATO = ''2''  THEN ''S'' ELSE ''N'' END RUT
						,FLAG_OP1 AS FLAG_OP

						FROM '||P_BDSTAGE||'.Persona_Sin_Ubic a

						INNER JOIN '||P_BTTPRUVI||'.VU_PERSONA b
						ON a.id_buro_persona = b.id_buro_persona

						LEFT JOIN '||P_BDVISTA||'.V_Hom_Tip_Ident_Linea h1
						ON b.COD_TIPO_IDENT_FTE=h1.Valor_Fuente

						LEFT JOIN '||P_BTTPRUVI||'.V_RANGO_EDAD VRE        
						ON b.COD_DW_RANGO_EDAD = VRE.COD_DW_RANGO_EDAD

						LEFT JOIN '||P_BTTPRUVI||'.V_JERARQUIA_GEOGRAFICA VJG   
						ON b.COD_CIUDAD_EXPEDICION= VJG.COD_DW_CIUDAD

						LEFT JOIN 
						(
								SELECT 
								  TET7.ID_BURO_PERSONA
								  ,TET7.COD_PIN_PERSONA 
								  ,VAEC.COD_ACT_ECONO_CIIU_FTE
								  ,VAEC.DESC_ACT_ECONO_CIIU 
								  ,VPAE.COD_DW_ACT_ECONO_CIIU
								  FROM '||P_BDSTAGE||'.Persona_Sin_Ubic TET7 
								  INNER JOIN '||P_BDVISTA||'.VU_PERSONA_ACTIVIDAD_ECONOMICA VPAE
								  ON TET7.COD_PIN_PERSONA =  VPAE.COD_PIN_PERSONA 
								  AND VPAE.Ind_Act_Principal =''S''
								  INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC 
								  ON VAEC.COD_DW_ACT_ECONO_CIIU = VPAE.COD_DW_ACT_ECONO_CIIU 
								  QUALIFY (Row_Number()Over(PARTITION BY TET7.ID_BURO_PERSONA ORDER BY Cast(VAEC.Cod_Act_Econo_CIIU_Fte AS INTEGER) DESC, VAEC.VERSION_CODIFICACION_CIIU DESC))=1
						) VAEC
						ON b.ID_BURO_PERSONA=VAEC.ID_BURO_PERSONA

						LEFT JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    
						ON VPJC.COD_PIN_PERSONA = b.COD_PIN_PERSONA 
						AND VPJC.COD_DW_ACT_ECONO_CIIU = VAEC.COD_DW_ACT_ECONO_CIIU

						LEFT JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  
						ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA   

						 LEFT JOIN 
						 ( 
									SELECT 
									TET7.ID_BURO_PERSONA
									,VAEC.COD_ACT_ECONO_CIIU_FTE
									,VAEC.DESC_ACT_ECONO_CIIU 
									,VMCC.PAGINA_WEB
									FROM '||P_BDSTAGE||'.Persona_Sin_Ubic TET7 
									INNER JOIN '||P_BDVISTA||'.V_PERSONA_JURIDICA_CAMARA VPJC    
									ON VPJC.COD_PIN_PERSONA = TET7.COD_PIN_PERSONA 
									INNER JOIN '||P_BDVISTA||'.V_MATRICULA_CAMARA_COMERCIO VMCC  
									ON VMCC.COD_DW_MATRICULA = VPJC.COD_DW_MATRICULA 
									INNER JOIN '||P_BDVISTA||'.V_ACTIVIDAD_ECONO_CIIU VAEC ON VPJC.COD_DW_ACT_ECONO_CIIU=VAEC.COD_DW_ACT_ECONO_CIIU
									WHERE  VPJC.IND_ACTIVO=''1''
									AND VPJC.IND_ACTIVIDAD_PRINCIPAL=''1''
									QUALIFY (Row_Number()Over (PARTITION BY TET7.ID_BURO_PERSONA ORDER BY VPJC.Fecha_Ult_Renovacion DESC , VPJC.COD_DW_FTE_DATO ASC, Cast(VAEC.COD_ACT_ECONO_CIIU_FTE AS INTEGER) DESC ,NullIf(VMCC.PAGINA_WEB,'''') DESC))=1
						) VAEC2
						ON b.ID_BURO_PERSONA=VAEC2.ID_BURO_PERSONA
						
						/*LEFT OUTER JOIN REC_DATOS.MAT_INFO_BASICA IB  #10 se elimina Join
						ON Cast(IB.NUMERO_IDENTIFICACION AS BIGINT) = Cast(A.Num_Ident AS BIGINT)
						AND IB.COD_TIPO_IDENT_FTE = A.Cod_Tipo_Ident_Fte */

					)
					WITH DATA
					PRIMARY INDEX(ID);';
		
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (28):. Se crea la tabla TMP_INBAS_ETAPA_9_2' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;						
							
   ------------------------------------------------------------------------------------------------------------------------
   -- Actualiza la tabla LOG_TD
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'COLLECT STATS INDEX(ID) ON '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_2';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (29):. Estadisticas para TMP_INBAS_ETAPA_9_2' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
 	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (30):. Se  borra tabla  TMP_INBAS_ETAPA_9' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	

   ------------------------------------------------------------------------------------------------------------------------
   -- Creacion tabla definitiva TMP_INBAS_ETAPA_10
   ------------------------------------------------------------------------------------------------------------------------
   
   	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_10'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
   SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_10
					AS (
							SELECT * FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_1 
							UNION
							SELECT * FROM '||P_BDSTAGE||'.TMP_INBAS_ETAPA_9_2 
						) WITH DATA
						PRIMARY INDEX(ID);';
					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (28):. Se crea la tabla TMP_INBAS_ETAPA_10' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;	
	
   ------------------------------------------------------------------------------------------------------------------------
   -- #2 Borrado de Temporales
   ------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_INBAS_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_INBAS_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_INBAS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_INBAS';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_INBAS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_INBAS';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (31):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Mosaic
 ( 
 	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20)
 	,IN P_BDVISTA VARCHAR(20)
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BDMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * 
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla Mosai_AAAAMMDD_HHMMSS_Lote
 * Fecha:			2017/12/07
 * Realizado por:	Oscar Angel
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Mosaic
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * ################################################################################
 */ 
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'Mosai';
	SET nameTable = TRIM(acronimo||'_'||V_DateTable||'_'||CAST(P_Lote AS CHAR(10)));

------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla Mosai_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.'||nameTable||' AS(
	SELECT
	VTGM.COD_DW_TIPO_GRUPO_MOSAIC AS ID
	,VTGM.COD_GRUPO_MOSAIC_FTE AS GRUPO
	,VGM.NOMBRE_GRUPO_MOSAIC AS NOMBRE_GRUPO
	,VGM.DESCRIPCION_GRUPO_MOSAIC AS DESCRIPCION_GRUPO
	,VTGM.CODIGO_MOSAIC_ORIG AS TIPO
	,VTGM.NOMBRE_TIPO_GRUPO_MOSAIC AS NOMBRE_TIPO
	,VTGM.DESCRIPCION_TIPO_GRUPO_MOSAIC AS DESCRIPCION_TIPO
	FROM '||P_BDVISTA||'.V_GRUPO_MOSAIC VGM
	INNER JOIN '||P_BDVISTA||'.V_TIPO_GRUPO_MOSAIC VTGM ON VTGM.COD_GRUPO_MOSAIC_FTE = VGM.COD_GRUPO_MOSAIC_FTE
	) WITH DATA PRIMARY INDEX (ID);
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Mosaic (1):. Creacion Tabla Linea_Mosaic' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a Mosai_AAAAMMDD_HHMMSS_Lote
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (ID), COLUMN (ID) ON '||P_BDSTAGE||'.'||nameTable||';';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Mosaic (2):. Actualizar estadisticas a la tabla '||P_BDSTAGE||'.'||nameTable||''
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza la tabla LOG_TD
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
	(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
	CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
	USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
	SELECT
	'||P_Lote||',
	CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
	'''||P_Nombre_Proceso_Padre||''',
	NULL,
	'''||nameTable||''',
	NULL,
	(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
	0,
	(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
	0,
	USER,
	NULL,
	''dbc'',
	NULL,
	NULL;
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Mosaic (3):. Actualiza Tabla LOG_TD' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_PICalculados_Ctls                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
( 
	IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
	,IN P_BTTMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) 
) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35. Creacion tabla PUNTO_INTERES_CALCULADOS
 *                  y CTLS para validacion.
 * Fecha:			2020-07-21
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Reconocer Master
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo					 Realizado por
 * 2020-07-21		#1.0 Version Inicial        	 Fernando Garrido  
 * 2023-03-03		Incluir conteo tabla MAT_RML_B2BTONE        	 Omar Delgado
 * 2023-10-20		Incluir conteo tabla MAT Delta InfoBas y Agg     Omar Delgado
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);	
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');	
	SET acronimo = 'Ubica';
	SET nameTable = 'PUNTO_INTERES_CALCULADOS';
	
   	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_DIRECCIONES_AGR'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_DIRECCIONES_AGR';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_AGRUP_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_DIRECCIONES_AGR AS       
					(SELECT TIPO_IDENTIFICACION,
							NUMERO_IDENTIFICACION,   
							UBI.UBICACION_DATO AS UBICACION_DATO,
							UBI.UBICACION_CLASE AS UBICACION_CLASE,
							UBI.UBICACION_TIPOCUENTA AS UBICACION_TIPOCUENTA,
							UBI.UBICACION_ORDEN AS UBICACION_ORDEN,
							UBI.UBICACCION_INDICATIVO AS UBICACCION_INDICATIVO,
							UBI.UBICACION_ESTRATO AS UBICACION_ESTRATO,
							UBI.UBICACION_ZONA AS UBICACION_ZONA,
							UBI.UBICACION_CIUDAD AS UBICACION_CIUDAD,
							UBI.UBICACION_DEPARTAMENTO AS UBICACION_DEPARTAMENTO,
							UBI.UBICACION_CODIGODANE AS UBICACION_CODIGODANE,
							UBI.UBICACION_BARRIO AS UBICACION_BARRIO,
							UBI.UBICACION_LOCALIDAD AS UBICACION_LOCALIDAD,
							UBI.UBICACION_CODIGOPOSTAL AS UBICACION_CODIGOPOSTAL,
							UBI.UBICACION_LONGITUD AS UBICACION_LONGITUD,
							UBI.UBICACION_LATITUD AS UBICACION_LATITUD,
							UBI.UBICACION_REPORTDESDE AS UBICACION_REPORTDESDE,
							UBI.UBICACION_ULTREPORTE AS UBICACION_ULTREPORTE,
							UBI.UBICACION_NUMENTIDADES AS UBICACION_NUMENTIDADES,
							UBI.UBICACION_NUMREPORTES AS UBICACION_NUMREPORTES,
							UBI.FUENTE AS UBICACION_FUENTE, 
							UBI.TIPO AS UBICACION_TIPO, 
							 CASE WHEN ID LIKE ''%,%'' THEN CAST(rec_vista.eListGetValByIdx(ID, '','', 1)  AS BIGINT)
								ELSE CAST(ID AS BIGINT) 
							  END AS UBICACION_IDS_AGRUPADOS, 
							UBI.COD_Pais AS COD_PAIS 
					FROM '||P_BDDATOS||'.MAT_UBICACION_AGREGADA UBI 
					WHERE UBI.UBICACION_CLASE = ''DIR'' 
					)WITH DATA
					PRIMARY INDEX ( TIPO_IDENTIFICACION ,NUMERO_IDENTIFICACION ,
					UBICACION_DATO ,UBICACION_CIUDAD ,UBICACION_DEPARTAMENTO ,UBICACION_CODIGODANE )
					INDEX ( TIPO_IDENTIFICACION ,NUMERO_IDENTIFICACION )';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'PRO_Novedad_Linea_PICalculados_Ctls(1):. Creacion Tabla TMP_DIRECCIONES_AGR' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;   
   
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX ( TIPO_IDENTIFICACION ,NUMERO_IDENTIFICACION ,UBICACION_DATO ,UBICACION_CIUDAD ,UBICACION_DEPARTAMENTO ,UBICACION_CODIGODANE )
                                ,INDEX ( TIPO_IDENTIFICACION ,NUMERO_IDENTIFICACION ) ,COLUMN(UBICACION_IDS_AGRUPADOS) ON '||P_BDSTAGE || '.TMP_DIRECCIONES_AGR;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'PRO_Novedad_Linea_PICalculados_Ctls(2):. Estadistica para  TMP_DIRECCIONES_AGR' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_Puntos_Suscriptor
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_Puntos_Suscriptor'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Puntos_Suscriptor';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_Puntos_Suscriptor
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_Puntos_Suscriptor AS 
					(
						SELECT pui.id AS punto_id,
							pui.distancia AS punto_distancia,
							pui.tipo AS punto_tipo,
							ubicacion_id,
							TIPO_IDENTIFICACION,
							NUMERO_IDENTIFICACION,
							COALESCE(nit_entidad, ''SV'') nit_entidad
						FROM   '||P_BDVISTA||'.vu_punto_inter pui
						INNER JOIN '||P_BDSTAGE|| '.TMP_DIRECCIONES_AGR UBIC ON pui.ubicacion_id = Ubic.UBICACION_IDS_AGRUPADOS
						WHERE  COALESCE(nit_entidad, ''SV'') = ''SV''
						qualify( row_number() OVER ( partition BY nit_entidad, ubicacion_id ORDER BY distancia ASC,id ASC ) = 1 ) 
					) WITH DATA 
					PRIMARY INDEX(TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'PRO_Novedad_Linea_PICalculados_Ctls(3):. Creacion Tabla TMP_Puntos_Suscriptor' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  '||P_BDSTAGE || '.TMP_Puntos_Suscriptor INDEX ( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id );';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'PRO_Novedad_Linea_PICalculados_Ctls(4):. Estadistica para TMP_Puntos_Suscriptor' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Busca la tabla TMP_Puntos_Suscriptor2
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_Puntos_Suscriptor2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Puntos_Suscriptor2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_Puntos_Suscriptor2
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE || '.TMP_Puntos_Suscriptor2 AS
					(
						SEL TIPO_IDENTIFICACION,
							 NUMERO_IDENTIFICACION, 
							 b.punto_id punto_id_suscriptor,
							 b.punto_distancia distancia_suscriptor,
							 pui.id AS punto_id,
							 pui.nombre AS punto_nombre,
							 pui.nombre_entidad AS punto_nomentidad,
							 pui.nit_entidad AS punto_nitentidad,
							 pui.distancia AS punto_distancia,
							 pui.tipo AS punto_tipo,
							 pui.latitud AS punto_latitud,
							 pui.longitud AS punto_longitud,
							 pui.ubicacion_id AS ubicacion_id,                  
							 cast( ''CONSULTA-1-2'' AS varchar( 12 )) tipo_consulta
						FROM    '||P_BDVISTA || '.vu_punto_inter pui 
						CROSS JOIN '||P_BDSTAGE || '.TMP_Puntos_Suscriptor b
						WHERE    pui.tipo = b.punto_tipo
						AND pui.ubicacion_id = b.ubicacion_id 
						AND COALESCE( pui.nit_entidad, ''SV'' ) <> b.Nit_entidad
						Qualify( row_number() OVER ( partition BY pui.nit_entidad, b.ubicacion_id ORDER BY   distancia ASC,id ASC ) = 1 )
					)WITH DATA 
					PRIMARY INDEX(TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id );';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'PRO_Novedad_Linea_PICalculados_Ctls(5):. Creacion Tabla TMP_Puntos_Suscriptor2' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  '||P_BDSTAGE || '.TMP_Puntos_Suscriptor2 INDEX ( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id );';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'PRO_Novedad_Linea_PICalculados_Ctls(6):. Estadistica para TMP_Puntos_Suscriptor2' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_Puntos
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_Puntos'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_Puntos';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_Puntos
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE || '.TMP_Puntos AS 
					(
						SELECT  TIPO_IDENTIFICACION,
							NUMERO_IDENTIFICACION,                  
							cast( NULL AS bigint ) punto_id_suscriptor ,
							 cast( NULL AS integer ) distancia_suscriptor ,
							 pui.id AS punto_id ,
							 pui.nombre AS punto_nombre ,
							 pui.nombre_entidad AS punto_nomentidad ,
							 pui.nit_entidad AS punto_nitentidad ,
							 min( pui.distancia ) AS punto_distancia ,
							 pui.tipo AS punto_tipo ,
							 pui.latitud AS punto_latitud ,
							 pui.longitud AS punto_longitud ,
							 pui.ubicacion_id AS ubicacion_id ,
							CAST( ''CONSULTA 3'' AS VARCHAR(12))  tipo_consulta
						FROM '||P_BDVISTA || '.vu_punto_inter pui
						INNER JOIN '||P_BDSTAGE || '.TMP_DIRECCIONES_AGR UBIC ON pui.ubicacion_id = Ubic.UBICACION_IDS_AGRUPADOS
						GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 10,11,12,13
					) WITH DATA 
					PRIMARY INDEX(TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id );';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'PRO_Novedad_Linea_PICalculados_Ctls(7):. Creacion Tabla TMP_Puntos' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_4
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX(TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id ) ON   '||P_BDSTAGE || '.TMP_Puntos;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_Novedad_Linea_PICalculados_Ctls(8):. Estadisticas para '||P_BDSTAGE||'.TMP_Puntos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla PUNTO_INTERES_CALCULADOS
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'PUNTO_INTERES_CALCULADOS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.PUNTO_INTERES_CALCULADOS';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla PUNTO_INTERES_CALCULADOS
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.PUNTO_INTERES_CALCULADOS AS 
					(
						SEL * 
						FROM 
						(
							SELECT  a.TIPO_IDENTIFICACION           
								,a.NUMERO_IDENTIFICACION         
								,a.punto_id_suscriptor           
								,a.distancia_suscriptor          
								,a.punto_id                      
								,a.punto_nombre                  
								,a.punto_nomentidad              
								,a.punto_nitentidad              
								,a.punto_distancia               
								,a.punto_tipo                    
								,a.punto_latitud                 
								,a.punto_longitud                
								,a.ubicacion_id                  
								,a.tipo_consulta                 
							FROM '||P_BDSTAGE||'.TMP_Puntos_Suscriptor2 a
							UNION ALL
							SELECT  b.TIPO_IDENTIFICACION           
								,b.NUMERO_IDENTIFICACION         
								,b.punto_id_suscriptor           
								,b.distancia_suscriptor          
								,b.punto_id                      
								,b.punto_nombre                  
								,b.punto_nomentidad              
								,b.punto_nitentidad              
								,b.punto_distancia               
								,b.punto_tipo                    
								,b.punto_latitud                 
								,b.punto_longitud                
								,b.ubicacion_id                  
								,b.tipo_consulta              
							FROM '||P_BDSTAGE||'.TMP_Puntos b) A 
					)WITH DATA 
					PRIMARY INDEX( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id )
					INDEX( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'PRO_Novedad_Linea_PICalculados_Ctls(9):. Creacion Tabla PUNTO_INTERES_CALCULADOS' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a PUNTO_INTERES_CALCULADOS
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, ubicacion_id ),INDEX( TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION) ON '||P_BDSTAGE||'.PUNTO_INTERES_CALCULADOS;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_Novedad_Linea_PICalculados_Ctls(10):. Estadisticas a la tabla '||P_BDSTAGE||'.PUNTO_INTERES_CALCULADOS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Consulta tabla Novedades_CTLS
	------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'Novedades_CTLS'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.Novedades_CTLS';		
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla Novedades_CTLS
	------------------------------------------------------------------------------------------------------------------------
	-- 2023-03-03 -- 2023-10-20
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.Novedades_CTLS AS 
					(
						SELECT CAST(''MOSAIC'' AS VARCHAR(300))||''=''||trim(Count(1) ) AS CTLS FROM '||P_BDVISTA || '.VU_MOSAIC
						UNION ALL 
						SELECT CAST(''MAT_INFO_ACTIVIDAD_ECONOMICA'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_INFO_ACTIVIDAD_ECONOMICA
						UNION ALL
						SELECT CAST(''MAT_INFO_BASICA'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_INFO_BASICA
						UNION ALL
						SELECT CAST(''MAT_INFO_CONTACTABILIDAD'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_INFO_CONTACTABILIDAD
						UNION ALL
						SELECT CAST(''MAT_INFO_MOVILIDAD'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_INFO_MOVILIDAD
						UNION ALL
						SELECT CAST(''MAT_INFO_UBICACION'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_INFO_UBICACION
						UNION ALL
						SELECT CAST(''MAT_UBICACION_AGREGADA_PJ'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_UBICACION_AGREGADA
						WHERE TIPO_IDENTIFICACION IN (''NIT'',''NIT_EXT'')
						UNION ALL
						SELECT CAST(''MAT_UBICACION_AGREGADA_PN'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDDATOS || '.MAT_UBICACION_AGREGADA
						WHERE TIPO_IDENTIFICACION NOT IN (''NIT'',''NIT_EXT'')
						UNION ALL
						SELECT CAST(''MAT_PUNTO_INTERES_CALCULADOS'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDSTAGE || '.PUNTO_INTERES_CALCULADOS
						UNION ALL
						SELECT CAST(''MAT_RML_B2BTONE'' AS VARCHAR(200))||''=''||TRIM(Count(1)) AS CTL FROM '||P_BDSTAGE || '.MAT_RML_B2BTONE 
						WHERE TIPO_IDENTIFICACION IN (''CC'',''TI'',''CE'') AND COALESCE(ESTADO_DOCUMENTO, '''') <> '''' AND COALESCE(LUGAR_EXPEDICION, '''') <> '''' AND FECHA_EXPEDICION IS NOT NULL  
						AND COALESCE(NOMBRE_COMPLETO, '''') <> '''' AND COALESCE(PRIMER_APELLIDO, '''') <> '''' AND COALESCE(PRIMER_NOMBRE, '''') <> ''''
					) WITH DATA 
					NO PRIMARY INDEX';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
 
									,:V_CADENA 
									,'PRO_Novedad_Linea_PICalculados_Ctls(11):. Creacion Tabla Novedades_CTLS' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  COLUMN(CTLS) ON '||P_BDSTAGE || '.Novedades_CTLS;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_Novedad_Linea_PICalculados_Ctls(12):. Estadisticas a la tabla '||P_BDSTAGE||'.Novedades_CTLS'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Punto_Interes
 (IN P_Lote INTEGER 
  ,IN P_StartTimeStampPadre VARCHAR(20) 
  ,IN P_Nombre_Proceso_Padre VARCHAR(30) 
  ,IN P_BDDATOS VARCHAR(20) 
  ,IN P_BDVISTA VARCHAR(20) 
  ,IN P_BDSTAGE VARCHAR(20)
  ,IN P_BDMTDAT VARCHAR(20)
  ,OUT P_ERROR VARCHAR(32000) ) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_PINTER_ETAPA_2
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 Realizado por
 * 19-10-2018		Version Inicial	                     Fernando Garrido 
 * 05-12-2018		#1 Incluye borrado de Temporales     Andy Garcia 
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'PInte';
	SET nameTable = 'TMP_PINTER_ETAPA_2';
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Valida Tipo EjecuciÃ³n , is null = Carga Full, is not null = Carga Delta
	------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TABLA_ORIGEN_STAGE = :nameTable;

	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_I_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_PINTE'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_PINTE';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_I_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_PINTE AS(
					SELECT COD_DW_UBIC_PUNTO_INTERES FROM '||P_BDDATOS||'.RELACION_UBICACION_PUNTO_INTER RUPI
					WHERE RUPI.LOTE IS NOT NULL AND RUPI.LOTE_ACTUALIZACION IS NULL
					AND CAST(RUPI.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RUPI.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
					PRIMARY INDEX(COD_DW_UBIC_PUNTO_INTERES)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (1):. Creacion Tabla TMP_FLAG_OP_I_PINTE' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Estadisticas a la tabla TMP_FLAG_OP_I_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (COD_DW_UBIC_PUNTO_INTERES) ON '||P_BDSTAGE||'.TMP_FLAG_OP_I_PINTE;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Punto_Interes (2):. Estadisticas Para TMP_FLAG_OP_I_PINTE' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_A_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_PINTE'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_PINTE';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_A_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_PINTE AS(
					SELECT COD_DW_UBIC_PUNTO_INTERES FROM '||P_BDDATOS||'.RELACION_UBICACION_PUNTO_INTER RUPI
					WHERE RUPI.LOTE_ACTUALIZACION IS NOT NULL
					AND CAST(RUPI.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RUPI.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
					PRIMARY INDEX(COD_DW_UBIC_PUNTO_INTERES)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (3):. Creacion Tabla TMP_FLAG_OP_A_PINTE' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Estadisticas a la tabla TMP_FLAG_OP_A_PINTE
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (COD_DW_UBIC_PUNTO_INTERES) ON '||P_BDSTAGE||'.TMP_FLAG_OP_A_PINTE;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (4):. Estadisticas Para TMP_FLAG_OP_A_PINTE' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
    -- Busca la tabla TMP_PINTER_ETAPA_1
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PINTER_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PINTER_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_PINTER_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PINTER_ETAPA_1 AS (
					SELECT
						RUPI.COD_DW_UBIC_PUNTO_INTERES AS ID
						,PDIG.NOMBRE AS NOMBRE
						,RUPI.DISTANCIA AS DISTANCIA
						,VTPI.DESCRIPCION_TIPO_PUNTO_INTERES 
						--,COALESCE(VTPI.DESCRIPCION_TIPO_PUNTO_INTERES,Descripcion_Corr_Tipo_Pto_Interes) AS TIPO
						--,h2.Descripcion_Hom_Tipo_Pto_Int_Linea AS TIPO
						--,UTP9.ID AS UBICACION_ID
						,UTP9.COD_DW_UBIC AS UBICACION_ID
						
						,RPIP.NOMBRE_SUSCRIPTOR AS NOMBRE_ENTIDAD
						,RPIP.NUM_IDENT AS NIT_ENTIDAD
						,PDIG.LATITUD AS LATITUD
						,PDIG.LONGITUD AS LONGITUD
						,VTPI.Cod_Tipo_Punto_Interes_Host

						FROM (SELECT COD_DW_UBIC,COUNT(1) Q FROM '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9  GROUP BY 1) UTP9
						INNER JOIN  '||P_BDVISTA||'.V_RELACION_UBICACION_PUNTO_INT RUPI ON UTP9.COD_DW_UBIC = RUPI.COD_DW_UBIC
						LEFT JOIN  '||P_BDVISTA||'.V_PUNTO_DE_INTERES_GEO PDIG 					ON PDIG.COD_DW_PUNTO_INTERES = RUPI.COD_DW_PUNTO_INTERES
						LEFT JOIN  '||P_BDVISTA||'.V_TIPO_PUNTO_INTERES VTPI 					ON VTPI.COD_DW_TIPO_PUNTO_INTERES = PDIG.COD_DW_TIPO_PUNTO_INTERES
						LEFT JOIN  '||P_BDSTAGE||'.RELACION_PUNTO_INTERES_X_PERS RPIP	ON RUPI.COD_DW_PUNTO_INTERES EQ RPIP.COD_DW_PUNTO_INTERES
						
					)WITH DATA
					PRIMARY INDEX (ID, UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (5):. Creacion Tabla TMP_PINTER_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Estadisticas a la tabla TMP_PINTER_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (ID, UBICACION_ID) ON '||P_BDSTAGE||'.TMP_PINTER_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (6):. Estadisticas Para TMP_PINTER_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_PINTER_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_PINTER_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PINTER_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_PINTER_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PINTER_ETAPA_2 AS (
					SELECT
						PIET1.ID
						,PIET1.NOMBRE
						,PIET1.DISTANCIA
						,PIET1.DESCRIPCION_TIPO_PUNTO_INTERES 
						,PIET1.UBICACION_ID
						,PIET1.NOMBRE_ENTIDAD
						,PIET1.NIT_ENTIDAD
						,PIET1.LATITUD
						,PIET1.LONGITUD	
						,h2.Descripcion_Hom_Tipo_Pto_Int_Linea AS TIPO	
						,CASE WHEN BLQ.FECHA_BLOQUEO = DATE - INTERVAL ''1'' DAY THEN ''E''
								WHEN FOPI.COD_DW_UBIC_PUNTO_INTERES IS NOT NULL THEN ''I''
								WHEN FOPA.COD_DW_UBIC_PUNTO_INTERES IS NOT NULL THEN ''A''
						END AS FLAG_OP1						
						,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP						
						FROM '||P_BDSTAGE||'.TMP_PINTER_ETAPA_1 PIET1
						LEFT JOIN '||P_BDVISTA||'.V_Corr_Tipo_Pto_Int_Linea h1
						ON PIET1.DESCRIPCION_TIPO_PUNTO_INTERES=H1.Valor_Fuente
						
						LEFT JOIN '||P_BDVISTA||'.V_Hom_Tipo_Pto_Int_Linea h2
						--ON COALESCE(VTPI.DESCRIPCION_TIPO_PUNTO_INTERES,H1.Valor_Fuente)=h2.Valor_Fuente
						ON PIET1.Cod_Tipo_Punto_Interes_Host=H2.Valor_Fuente
						
						LEFT JOIN '||P_BDDATOS||'.BLOQUEO BLQ 							
						ON PIET1.UBICACION_ID = BLQ.COD_DW_PERSONA_UBIC
							
						LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_I_PINTE FOPI 					
						ON PIET1.ID = FOPI.COD_DW_UBIC_PUNTO_INTERES	  
	  
						LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_A_PINTE FOPA 					
						ON PIET1.ID = FOPA.COD_DW_UBIC_PUNTO_INTERES
						
						
					)WITH DATA
					PRIMARY INDEX (ID, UBICACION_ID);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (7):. Creacion Tabla TMP_PINTER_ETAPA_2' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Estadisticas a la tabla TMP_PINTER_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (ID, UBICACION_ID) ON '||P_BDSTAGE||'.TMP_PINTER_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (8):. Estadisticas Para TMP_PINTER_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
 	
	------------------------------------------------------------------------------------------------------------------------
	-- Borra la tabla TMP_PINTER_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_PINTER_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Punto_Interes (9):. Borra Tabla TMP_PINTER_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;


	------------------------------------------------------------------------------------------------------------------------
	-- #1 Borra Temporales
	------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_A_PINTE'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_PINTE';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_FLAG_OP_I_PINTE'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_PINTE';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;

	
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Punto_Interes (10):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
 	
	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Ubi_Agregada                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
 ( IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
	,IN P_BTTMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) 
) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_AGR_ETAPA_FINAL
 * Fecha:			2018/10/22
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Reconocer Master
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						 Realizado por
 * 22-10-2018		#1 adicionar a la tabla el campo	 Fernando Garrido 
 * 03-12-2018		#2 Anadir desempate de Ubicaciones 	 Andy Garcia
					y borrado de temporales
 * 18-12-2018		#3 Se aplica criterio para			 Andy Garcia	
					re-numerar orden
 * 02/05/2019       #Se ajusta el calculo tabla          Fernando Garrido
 *                   TMP_AGRUP_ETAPA_9
 * 12/12/2019       #Se adiciona campo COD_PAIS          Fernando Garrido
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (FORMAT 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (FORMAT 'hhmiss') (CHAR(6)));
	SET acronimo = 'Ubica';
	SET nameTable = 'TMP_AGR_ETAPA_FINAL';
	
   -- Valida Tipo Ejecucion , is null = Carga Full, is not null = Carga Delta
	------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT CAST(MAX(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE TRIM(ESTADO_EJECUCION) ='Finalizado OK'
	AND TRIM(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND TRIM(TABLA_ORIGEN_STAGE) =:nameTable;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_AGRUP_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_AGRUP_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_1 
	               AS (SELECT ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,MIN(ETP9.REPORTADO_DESDE) AS UBICACION_REPORTDESDE

						FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_2 ETP9

						GROUP BY 
						ETP9.TIPO_IDENTIFICACION
						,ETP9.NUMERO_IDENTIFICACION
						,ETP9.INFO_BASICA
						,ETP9.DATO
						,ETP9.CODIGO_DANE
						,ETP9.CIUDAD
						,ETP9.DEPARTAMENTO
						)
						WITH DATA
						PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,
						INFO_BASICA,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (1):. Creacion Tabla TMP_AGRUP_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;   
   
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_1 INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,
						INFO_BASICA,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (2):. Estadistica para  TMP_AGRUP_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_AGRUP_ETAPA_2
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_AGRUP_ETAPA_2
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_2 AS (
					SELECT ETP9.TIPO_IDENTIFICACION
						,ETP9.NUMERO_IDENTIFICACION
						,ETP9.INFO_BASICA
						,ETP9.DATO
						,ETP9.CODIGO_DANE
						,ETP9.CIUDAD
						,ETP9.DEPARTAMENTO
						,MAX(ETP9.ULTIMO_REPORTE) AS UBICACION_ULTREPORTE
					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_2 ETP9
					GROUP BY ETP9.TIPO_IDENTIFICACION
						,ETP9.NUMERO_IDENTIFICACION
						,ETP9.INFO_BASICA
						,ETP9.CODIGO_DANE
						,ETP9.DATO
						,ETP9.CIUDAD
						,ETP9.DEPARTAMENTO
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubi_Agregada (3):. Creacion Tabla TMP_AGRUP_ETAPA_2' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO)
  	                ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubi_Agregada (4):. Estadistica para TMP_AGRUP_ETAPA_2' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Busca la tabla TMP_AGRUP_ETAPA_3
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_AGRUP_ETAPA_3
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_3 AS (
					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,MAX(ETP9.NUMERO_ENTIDADES) AS UBICACION_NUMENTIDADES

					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_2 ETP9
					GROUP BY 
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								  ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (5):. Creacion Tabla TMP_AGRUP_ETAPA_3' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								  ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO)
  	                ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_3;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubi_Agregada (6):. Estadistica para TMP_AGRUP_ETAPA_3' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_4
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_AGRUP_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_4 AS (
					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,SUM(ETP9.NUMERO_REPORTES) AS UBICACION_NUMREPORTES

					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_2 ETP9

					GROUP BY 
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (7):. Creacion Tabla TMP_AGRUP_ETAPA_4' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_AGRUP_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_4;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (8):. Estadisticas para '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_5
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_AGRUP_ETAPA_5
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_5 AS (
					SELECT
					ATP1.TIPO_IDENTIFICACION
					,ATP1.NUMERO_IDENTIFICACION
					,ATP1.INFO_BASICA
					,ATP1.DATO
					,ATP1.CODIGO_DANE
					,ATP1.CIUDAD
					,ATP1.DEPARTAMENTO
					,ATP1.UBICACION_REPORTDESDE
					,ATP2.UBICACION_ULTREPORTE
					FROM '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_1 ATP1
					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_2 ATP2
					ON ATP1.TIPO_IDENTIFICACION=ATP2.TIPO_IDENTIFICACION
					AND ATP1.NUMERO_IDENTIFICACION=ATP2.NUMERO_IDENTIFICACION
					AND ATP1.DATO=ATP2.DATO
					AND ATP1.CODIGO_DANE=ATP2.CODIGO_DANE
					AND ATP1.CIUDAD=ATP2.CIUDAD
					AND ATP1.DEPARTAMENTO=ATP2.DEPARTAMENTO
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (9):. Creacion Tabla TMP_AGRUP_ETAPA_5' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA
								   ,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO)
                   ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_5;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (10):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_5'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_6
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_6 AS (
					SELECT ATP5.TIPO_IDENTIFICACION
						,ATP5.NUMERO_IDENTIFICACION
						,ATP5.INFO_BASICA
						,ATP5.DATO
						,ATP5.CODIGO_DANE
						,ATP5.CIUDAD
						,ATP5.DEPARTAMENTO
						,ATP5.UBICACION_REPORTDESDE
						,ATP5.UBICACION_ULTREPORTE
						,ATP3.UBICACION_NUMENTIDADES
					FROM '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_5 ATP5
					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_3 ATP3
					ON ATP5.TIPO_IDENTIFICACION=ATP3.TIPO_IDENTIFICACION
					AND ATP5.NUMERO_IDENTIFICACION=ATP3.NUMERO_IDENTIFICACION
					AND ATP5.DATO=ATP3.DATO
					AND ATP5.CODIGO_DANE=ATP3.CODIGO_DANE
					AND ATP5.CIUDAD=ATP3.CIUDAD
					AND ATP5.DEPARTAMENTO=ATP3.DEPARTAMENTO
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (11):. Creacion Tabla TMP_AGRUP_ETAPA_6' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								         DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO)  ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (12):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_7
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_7 AS (
					SELECT ATP6.TIPO_IDENTIFICACION
						,ATP6.NUMERO_IDENTIFICACION
						,ATP6.INFO_BASICA
						,ATP6.CODIGO_DANE
						,ATP6.CIUDAD
						,ATP6.DEPARTAMENTO
						,ATP6.DATO AS UBICACION_DATO
						,ATP6.UBICACION_REPORTDESDE
						,ATP6.UBICACION_ULTREPORTE
						,ATP6.UBICACION_NUMENTIDADES
						,ATP4.UBICACION_NUMREPORTES
					FROM '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_6 ATP6
					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_4 ATP4
					ON ATP6.TIPO_IDENTIFICACION=ATP4.TIPO_IDENTIFICACION
					AND ATP6.NUMERO_IDENTIFICACION=ATP4.NUMERO_IDENTIFICACION
					AND ATP6.DATO=ATP4.DATO
					AND ATP6.CODIGO_DANE=ATP4.CODIGO_DANE
					AND ATP6.CIUDAD=ATP4.CIUDAD
					AND ATP6.DEPARTAMENTO=ATP4.DEPARTAMENTO
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (13):. Creacion Tabla TMP_AGRUP_ETAPA_7' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_7;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (14):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_7'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_8
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_8 
					AS (SELECT ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO AS UBICACION_DATO
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.CLASE AS UBICACION_CLASE
							,ETP9.TIPO_CUENTA AS UBICACION_TIPOCUENTA

						FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
						GROUP BY ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO 
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.CLASE
							,ETP9.TIPO_CUENTA 
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (15):. Creacion Tabla TMP_AGRUP_ETAPA_8' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									      UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_8;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (16):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_8'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_AGRUP_ETAPA_9
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_9
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_9
					 AS (SELECT ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.DATO AS UBICACION_DATO
								,ETP9.CODIGO_DANE
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO
								,MIN(ETP9.ORDEN) AS UBICACION_ORDEN
								,MAX(COALESCE(ETP9.INDICATIVO, -1)) AS UBICACCION_INDICATIVO
								,ETP9.ESTRATO AS UBICACION_ESTRATO
								,ETP9.ZONA AS UBICACION_ZONA
						FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
						GROUP BY ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.DATO 
								,ETP9.CODIGO_DANE
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO								
								,ETP9.ESTRATO
								,ETP9.ZONA
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (17):. Creacion Tabla TMP_AGRUP_ETAPA_9' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_9
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									     UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_9;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubi_Agregada (18):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_9'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_AGRUP_ETAPA_10
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_10'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_10';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_10
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_10 
					AS (SELECT ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO AS UBICACION_DATO
							,ETP9.CIUDAD 
							,ETP9.DEPARTAMENTO 
							,ETP9.CODIGO_DANE --AS UBICACION_CODIGODANE
							,ETP9.BARRIO AS UBICACION_BARRIO
					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
					GROUP BY ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO
							,ETP9.CIUDAD 
							,ETP9.DEPARTAMENTO 
							,ETP9.CODIGO_DANE 
							,ETP9.BARRIO 
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (19):. Creacion Tabla TMP_AGRUP_ETAPA_10' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_10
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_10;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (20):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_10'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_AGRUP_ETAPA_11
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_11'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_11';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_11
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_11
					 AS (SELECT ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.DATO AS UBICACION_DATO
								,ETP9.CODIGO_DANE
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO
								,ETP9.LOCALIDAD AS UBICACION_LOCALIDAD
								,ETP9.CODIGO_POSTAL AS UBICACION_CODIGOPOSTAL
								,ETP9.LONGITUD AS UBICACION_LONGITUD
								,ETP9.LATITUD AS UBICACION_LATITUD
					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
					GROUP BY ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.DATO
							,ETP9.LOCALIDAD 
							,ETP9.CODIGO_POSTAL 
							,ETP9.LONGITUD
							,ETP9.LATITUD 
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (21):. Creacion Tabla TMP_AGRUP_ETAPA_11' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGRUP_ETAPA_11
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_11;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (22):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_11'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_1
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_1 
						AS (SELECT ETP9.TIPO_IDENTIFICACION
									,ETP9.NUMERO_IDENTIFICACION
									,ETP9.INFO_BASICA
									,ETP9.DATO AS UBICACION_DATO
									--,ETP9.UBICACION_DEPARTAMENTO
									,ETP9.CODIGO_DANE
									,ETP9.CIUDAD
									,ETP9.DEPARTAMENTO
									,ETP9.TIPO
									,CASE WHEN ETP9.TIPO=''R'' THEN 1 
													WHEN ETP9.TIPO=''L'' THEN 2
													WHEN ETP9.TIPO=''C'' THEN 3
													ELSE 4
									END TOKEN_TIPO
									,ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY Token_Tipo ASC) Token
						FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
						--WHERE NUMERO_IDENTIFICACION=208258
						GROUP BY ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO
								,ETP9.DATO
								,ETP9.CODIGO_DANE
								,ETP9.TIPO
						)WITH DATA
						PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									  UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TIPO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (23):. Creacion Tabla TMP_RECAGR_ETAPA_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									  UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TIPO) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (24):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_1'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_2
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_2 AS (
					WITH RECURSIVE RECAGR (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN,TIPO)
					AS
					(SELECT ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.UBICACION_DATO
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.TOKEN
							,ETP9.TIPO
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_1 ETP9

					UNION ALL

					SELECT ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.UBICACION_DATO
							,ETP9.CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.TOKEN
							,REC.TIPO||'' - ''||ETP9.TIPO
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_1 ETP9
					INNER JOIN RECAGR REC
					ON ETP9.TIPO_IDENTIFICACION=REC.TIPO_IDENTIFICACION
					AND ETP9.NUMERO_IDENTIFICACION=REC.NUMERO_IDENTIFICACION
					AND ETP9.INFO_BASICA=REC.INFO_BASICA
					AND ETP9.UBICACION_DATO=REC.UBICACION_DATO
					AND ETP9.CODIGO_DANE=REC.CODIGO_DANE
					AND ETP9.CIUDAD=REC.CIUDAD
					AND ETP9.DEPARTAMENTO=REC.DEPARTAMENTO
					AND ETP9.TOKEN=REC.TOKEN+1
					)
					SELECT *
					FROM RECAGR
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (25):. Creacion Tabla TMP_RECAGR_ETAPA_2' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,
 INFO_BASICA,
								         UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN) 
					ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (26):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_2'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_3
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_3
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_3
                	AS (SELECT *
						FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_2
						--WHERE NUMERO_IDENTIFICACION=208258
						QUALIFY (ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY CHAR(TIPO) DESC))=1
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (27):. Creacion Tabla TMP_RECAGR_ETAPA_3' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_3
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_3;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (28):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_3'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_4
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_4
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_4 
						AS (SELECT ETP9.TIPO_IDENTIFICACION
									,ETP9.NUMERO_IDENTIFICACION
									,ETP9.INFO_BASICA
									,ETP9.DATO AS UBICACION_DATO
									,ETP9.CODIGO_DANE
									,ETP9.CIUDAD
									,ETP9.DEPARTAMENTO
									,ETP9.FUENTE
									,CASE WHEN ETP9.FUENTE=''SUS'' THEN 1 
													WHEN ETP9.FUENTE=''CAM'' THEN 2
													WHEN ETP9.FUENTE=''CONT'' THEN 3
													ELSE 4
									END TOKEN_TIPO
								   ,ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY Token_Tipo ASC) Token
						FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_2 ETP9
						--WHERE NUMERO_IDENTIFICACION=208258
						GROUP BY ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.DATO
								,ETP9.CODIGO_DANE
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO
								,ETP9.FUENTE
						)WITH DATA
						PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,FUENTE);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (29):. Creacion Tabla TMP_RECAGR_ETAPA_4' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_4
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,FUENTE) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_4;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (30):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_4'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_5
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_5 AS (
					WITH RECURSIVE RECAGR (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN,FUENTE)
					AS
					(
					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.UBICACION_DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,ETP9.TOKEN
					,ETP9.FUENTE
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_4 ETP9

					UNION ALL

					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.UBICACION_DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,ETP9.TOKEN
					,REC.FUENTE||'' - ''||ETP9.FUENTE
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_4 ETP9
					INNER JOIN RECAGR REC
					ON  ETP9.TIPO_IDENTIFICACION=REC.TIPO_IDENTIFICACION
					AND ETP9.NUMERO_IDENTIFICACION=REC.NUMERO_IDENTIFICACION
					AND ETP9.INFO_BASICA=REC.INFO_BASICA
					AND ETP9.UBICACION_DATO=REC.UBICACION_DATO
					AND ETP9.CODIGO_DANE=REC.CODIGO_DANE
					AND ETP9.CIUDAD=REC.CIUDAD
					AND ETP9.DEPARTAMENTO=REC.DEPARTAMENTO
					AND ETP9.TOKEN=REC.TOKEN+1
					)
					SELECT *
					FROM RECAGR
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (31):. Creacion Tabla TMP_RECAGR_ETAPA_5' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_5;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (32):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_5'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_6
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_6 
					AS (SELECT *
						FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_5
						--WHERE NUMERO_IDENTIFICACION=208258
						QUALIFY (ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY CHAR(FUENTE) DESC))=1
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (33):. Creacion Tabla TMP_RECAGR_ETAPA_6' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (34):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_6'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_7
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_7
					 AS (SELECT ETP9.TIPO_IDENTIFICACION
								,ETP9.NUMERO_IDENTIFICACION
								,ETP9.INFO_BASICA
								,ETP9.DATO AS UBICACION_DATO
								,ETP9.CODIGO_DANE
								,ETP9.CIUDAD
								,ETP9.DEPARTAMENTO
								,ETP9.COD_DW_UBIC AS ID
								,ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY COD_DW_UBIC ASC) Token
								,MAX(ETP9.Tipo_Via_Principal) AS Tipo_Via_Principal
								,MAX(ETP9.Via_Principal) AS Via_Principal
								,MAX(ETP9.Via_Generadora) AS Via_Generadora
								,MAX(ETP9.Numero_Puerta) AS Numero_Puerta
								,MAX(ETP9.Descripcion_Tipo_Via) AS Descripcion_Tipo_Via
					FROM '||P_BDSTAGE || '.TMP_UBICA_ETAPA_9 ETP9
					--WHERE NUMERO_IDENTIFICACION=208258
					GROUP BY ETP9.TIPO_IDENTIFICACION
							,ETP9.NUMERO_IDENTIFICACION
							,ETP9.INFO_BASICA
							,ETP9.DATO
							,CODIGO_DANE
							,ETP9.CIUDAD
							,ETP9.DEPARTAMENTO
							,ETP9.COD_DW_UBIC
					)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (35):. Creacion Tabla TMP_RECAGR_ETAPA_7' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_7;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (36):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_7'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_8
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_RECAGR_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_8 AS (
					WITH RECURSIVE RECAGR (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN,ID,Tipo_Via_Principal,Via_Principal,Via_Generadora,Numero_Puerta,Descripcion_Tipo_Via)
					AS
					(
					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.UBICACION_DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,ETP9.TOKEN
					,CAST(ETP9.ID AS VARCHAR(1000)) ID
					,ETP9.Tipo_Via_Principal 
					,ETP9.Via_Principal
					,ETP9.Via_Generadora
					,ETP9.Numero_Puerta
					,ETP9.Descripcion_Tipo_Via
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_7 ETP9

					UNION ALL

					SELECT
					ETP9.TIPO_IDENTIFICACION
					,ETP9.NUMERO_IDENTIFICACION
					,ETP9.INFO_BASICA
					,ETP9.UBICACION_DATO
					,ETP9.CODIGO_DANE
					,ETP9.CIUDAD
					,ETP9.DEPARTAMENTO
					,ETP9.TOKEN
					,CAST(CAST(REC.ID AS VARCHAR(100)) ||'',''|| CAST(ETP9.ID AS VARCHAR(100)) AS VARCHAR(1000)) ID
					,ETP9.Tipo_Via_Principal 
					,ETP9.Via_Principal
					,ETP9.Via_Generadora
					,ETP9.Numero_Puerta
					,ETP9.Descripcion_Tipo_Via
					FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_7 ETP9
					INNER JOIN RECAGR REC
					ON  ETP9.TIPO_IDENTIFICACION=REC.TIPO_IDENTIFICACION
					AND ETP9.NUMERO_IDENTIFICACION=REC.NUMERO_IDENTIFICACION
					AND ETP9.INFO_BASICA=REC.INFO_BASICA
					AND ETP9.UBICACION_DATO=REC.UBICACION_DATO
					AND ETP9.CODIGO_DANE=REC.CODIGO_DANE
					AND ETP9.CIUDAD=REC.CIUDAD
					AND ETP9.DEPARTAMENTO=REC.DEPARTAMENTO

					AND ETP9.TOKEN=REC.TOKEN+1
					)
					SELECT *
					FROM RECAGR
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (37):. Creacion Tabla TMP_RECAGR_ETAPA_8' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
									UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO,TOKEN) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_8;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (38):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_8'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
    
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_RECAGR_ETAPA_9
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGRUP_ETAPA_11
	----------------------------------------------------------------------------------------
 --------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_9 
					AS (SELECT A.*
						--,ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO ORDER BY ID ASC, TOKEN ASC) ROWN
						FROM '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_8 A
						--WHERE NUMERO_IDENTIFICACION=208258
						QUALIFY (ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO ORDER BY CHAR(ID) DESC))=1
						--QUALIFY (ROW_NUMBER()OVER(PARTITION BY TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO ORDER BY ID ASC, TOKEN ASC))=1
						)WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (39):. Creacion Tabla TMP_RECAGR_ETAPA_9' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_RECAGR_ETAPA_9
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,
								   UBICACION_DATO,CODIGO_DANE,CIUDAD,DEPARTAMENTO) ON '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_9;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (40):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_9'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_AGR_ETAPA_FINAL_1
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGR_ETAPA_FINAL_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL_1';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGR_ETAPA_FINAL_1
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGR_ETAPA_FINAL_1 
					AS ( SELECT C.* 
							--,D.UBICACION_DATO
							,D.UBICACION_CLASE
							,D.UBICACION_TIPOCUENTA

							,E.UBICACION_ORDEN
							,E.UBICACCION_INDICATIVO
							,E.UBICACION_ESTRATO
							,E.UBICACION_ZONA

							,F.CIUDAD AS UBICACION_CIUDAD
							,F.DEPARTAMENTO AS UBICACION_DEPARTAMENTO
							,F.CODIGO_DANE AS UBICACION_CODIGODANE
							,F.UBICACION_BARRIO

							,G.UBICACION_LOCALIDAD
							,G.UBICACION_CODIGOPOSTAL
							,G.UBICACION_LONGITUD
							,G.UBICACION_LATITUD

							,H.TIPO
							,I.FUENTE
							,J.ID
							,J.Tipo_Via_Principal 
							,J.Via_Principal
							,J.Via_Generadora
							,J.Numero_Puerta
							,J.Descripcion_Tipo_Via

					FROM '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_7 C
					/*ON A.TIPO_IDENTIFICACION=C.TIPO_IDENTIFICACION
					AND A.NUMERO_IDENTIFICACION=C.NUMERO_IDENTIFICACION
					AND A.INFO_BASICA=C.INFO_BASICA
					AND A.COD_DW_UBIC=C.COD_DW_UBIC
					AND A.COD_DW_DIRECCION_FISICA=C.COD_DW_DIRECCION_FISICA
					AND A.COD_DW_TELEFONO=C.COD_DW_TELEFONO
					AND A.COD_DW_DIRECCION_ELECTRONICA=C.COD_DW_DIRECCION_ELECTRONICA
					*/
					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_8 D
					ON C.TIPO_IDENTIFICACION=D.TIPO_IDENTIFICACION
					AND C.NUMERO_IDENTIFICACION=D.NUMERO_IDENTIFICACION
					AND C.INFO_BASICA=D.INFO_BASICA
					AND C.UBICACION_DATO=D.UBICACION_DATO
					AND C.CODIGO_DANE=D.CODIGO_DANE
					AND C.CIUDAD=D.CIUDAD
					AND C.DEPARTAMENTO=D.DEPARTAMENTO

					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_9 E
					ON C.TIPO_IDENTIFICACION=E.TIPO_IDENTIFICACION
					AND C.NUMERO_IDENTIFICACION=E.NUMERO_IDENTIFICACION
					AND C.INFO_BASICA=E.INFO_BASICA
					AND C.UBICACION_DATO=E.UBICACION_DATO
					AND C.CODIGO_DANE=E.CODIGO_DANE
					AND C.CIUDAD=E.CIUDAD
					AND C.DEPARTAMENTO=E.DEPARTAMENTO


					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_10 F
					ON C.TIPO_IDENTIFICACION=F.TIPO_IDENTIFICACION
					AND C.NUMERO_IDENTIFICACION=F.NUMERO_IDENTIFICACION
					AND C.INFO_BASICA=F.INFO_BASICA
					AND C.UBICACION_DATO=F.UBICACION_DATO
					AND C.CODIGO_DANE=F.CODIGO_DANE
					AND C.CIUDAD=F.CIUDAD
					AND C.DEPARTAMENTO=F.DEPARTAMENTO


					INNER JOIN '||P_BDSTAGE || '.TMP_AGRUP_ETAPA_11 G
					ON C.TIPO_IDENTIFICACION=G.TIPO_IDENTIFICACION
					AND C.NUMERO_IDENTIFICACION=G.NUMERO_IDENTIFICACION
					AND C.INFO_BASICA=G.INFO_BASICA
					AND C.UBICACION_DATO=G.UBICACION_DATO
					AND C.CODIGO_DANE=G.CODIGO_DANE
					AND C.CIUDAD=G.CIUDAD
					AND C.DEPARTAMENTO=G.DEPARTAMENTO


					INNER JOIN '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_3 H
					ON F.TIPO_IDENTIFICACION=H.TIPO_IDENTIFICACION
					AND F.NUMERO_IDENTIFICACION=H.NUMERO_IDENTIFICACION
					AND F.INFO_BASICA=H.INFO_BASICA
					AND F.UBICACION_DATO=H.UBICACION_DATO
					AND F.CODIGO_DANE=H.CODIGO_DANE
					AND F.CIUDAD=H.CIUDAD
					AND F.DEPARTAMENTO=H.DEPARTAMENTO


					INNER JOIN '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_6 I
					ON F.TIPO_IDENTIFICACION=I.TIPO_IDENTIFICACION
					AND F.NUMERO_IDENTIFICACION=I.NUMERO_IDENTIFICACION
					AND F.INFO_BASICA=I.INFO_BASICA
					AND F.UBICACION_DATO=I.UBICACION_DATO
					AND F.CODIGO_DANE=I.CODIGO_DANE
					AND F.CIUDAD=I.CIUDAD
					AND F.DEPARTAMENTO=I.DEPARTAMENTO

					INNER JOIN '||P_BDSTAGE || '.TMP_RECAGR_ETAPA_9 J
					ON F.TIPO_IDENTIFICACION=J.TIPO_IDENTIFICACION
					AND F.NUMERO_IDENTIFICACION=J.NUMERO_IDENTIFICACION
					AND F.INFO_BASICA=J.INFO_BASICA
					AND F.UBICACION_DATO=J.UBICACION_DATO
					AND F.CODIGO_DANE=J.CODIGO_DANE
					AND F.CIUDAD=J.CIUDAD
					AND F.DEPARTAMENTO=J.DEPARTAMENTO

					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,UBICACION_CODIGODANE,UBICACION_CIUDAD,UBICACION_DEPARTAMENTO)
					INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (41):. Creacion Tabla TMP_AGR_ETAPA_FINAL_1' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGR_ETAPA_FINAL_1
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO,UBICACION_CODIGODANE,
	                                     UBICACION_CIUDAD,UBICACION_DEPARTAMENTO) 
					               ,INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION)
					ON '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (43):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL_1'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_AGR_ETAPA_FINAL
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGR_ETAPA_FINAL'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
        SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
		
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_AGR_ETAPA_FINAL
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_AGR_ETAPA_FINAL AS (
					SELECT TIPO_IDENTIFICACION	
							,NUMERO_IDENTIFICACION
							,INFO_BASICA
							,CODIGO_DANE
							,CIUDAD
							,DEPARTAMENTO
							,UBICACION_DATO
							,UBICACION_REPORTDESDE
							,UBICACION_ULTREPORTE
							,UBICACION_NUMENTIDADES
							,UBICACION_NUMREPORTES
							,UBICACION_CLASE
							,UBICACION_TIPOCUENTA
							,ROW_NUMBER()OVER(PARTITION BY INFO_BASICA,UBICACION_CLASE ORDER BY NVL(UBICACION_ORDEN,999) ASC,UBICACION_REPORTDESDE DESC, UBICACION_ULTREPORTE DESC,UBICACION_NUMREPORTES DESC, CHAR(TIPO) DESC, TIPO ASC, CHAR(UBICACION_DATO) DESC,CODIGO_DANE DESC, UBICACION_CIUDAD DESC,UBICACION_DEPARTAMENTO DESC, ID ASC, REC_VISTA.hash_md5(UBICACION_DATO) ASC ) UBICACION_ORDEN /*#3*/
							,UBICACCION_INDICATIVO
							,UBICACION_ESTRATO
							,UBICACION_ZONA
							,UBICACION_CIUDAD
							,UBICACION_DEPARTAMENTO
							,UBICACION_CODIGODANE
							,UBICACION_BARRIO
							,UBICACION_LOCALIDAD
							,UBICACION_CODIGOPOSTAL
							,UBICACION_LONGITUD
							,UBICACION_LATITUD
							,TIPO
							,FUENTE
							,ID
							,B.Cod_Pais
							,CAST(COALESCE(NULL, ''I'') AS CHAR(1)) FLAG_OP
							,Tipo_Via_Principal 
							,Via_Principal
							,Via_Generadora
							,Numero_Puerta
							,Descripcion_Tipo_Via
 					FROM '||P_BDSTAGE || '.TMP_AGR_ETAPA_FINAL_1 A
					CROSS JOIN (Select CAST(Cod_pais_Geo_Fte AS VARCHAR(3))  Cod_Pais
								from '||P_BTTPRUVI||'.V_PAIS 
								WHERE Desc_pais = ''Colombia'' ) B					
					)
					WITH DATA
					PRIMARY INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO)
					INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubi_Agregada (44):. Creacion Tabla TMP_AGR_ETAPA_FINAL' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_AGR_ETAPA_FINAL
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,UBICACION_DATO),
						INDEX (TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION) ON '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubi_Agregada (45):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_AGR_ETAPA_FINAL'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Borra Tablas Temporales
	------------------------------------------------------------------------------------------------------------------------
	/*
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
			
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_10'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_10';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;

	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_11'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_11';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;

	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;

	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;

	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
		*/
	/* Inicia #2 Borrado de Temporales */
	/*
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
		
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_AGRUP_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_AGRUP_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;


	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;

	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_4  '
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RECAGR_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RECAGR_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	*/
	/* Fin #2 Borrado de Temporales */
		
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;
					';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Info_Basica (46):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	END L1;
END;

REPLACE PROCEDURE REC_DATOS.PRO_Novedad_Linea_Ubicacion                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
 ( IN P_Lote INTEGER 
 	,IN P_StartTimeStampPadre VARCHAR(20) 
 	,IN P_Nombre_Proceso_Padre VARCHAR(30) 
 	,IN P_BDDATOS VARCHAR(20) 
 	,IN P_BDVISTA VARCHAR(20) 
 	,IN P_BDSTAGE VARCHAR(20) 
	,IN P_BTTPRUVI VARCHAR(20)
	,IN P_BDMTDAT VARCHAR(20)
	,IN P_BTTMTDAT VARCHAR(20)
 	,OUT P_ERROR VARCHAR(32000) 
) 
 /*
 * ################################################################################
 * Objetivo:		Caso de uso 35, 
 * 					Creacion de la Tabla TMP_UBICA_ETAPA_9
 * Fecha:			2018/10/19
 * Realizado por:	Fernando Garrido M.
 * Proyecto:		Nuevo reconocer 3
 * Script:			PRO_Novedad_Linea_Info_Basica
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha				Objetivo						          Realizado por
 * 19-10-2018		#1 adicionar a la tabla el campo	          Fernando Garrido 
 * 13-11-2018       #Se adiciona Valores Default a los 
 *                   campos CODIGO_DANE,CIUDAD, DEPARTAMENTO      Fernando Garrido 
 * 30-11-2018		#2 Se incluye filtro para excluir ubicaciones Andy Garcia 	
					sin orden.
 * 30-04-2019       #Se realiza ajuste para Calcular de la forma  Fernando Garrido. 
 *                  adecuada el numero de entidades que reporta 
 *                  una ubicacion. 
 * 10-10-2019       #Ajuste regla mosaic y numero de reportes     Jeimmy Chavez
 * 16-06-2021    # Ajuste codigo Dane a 8 digitos   Jeimmy Chavez 
 * --------------------------------------------------------------------------- 
 * ################################################################################*/
 	
BEGIN
------------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
------------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre TIMESTAMP(6);
	DECLARE V_DateTable VARCHAR(30);
	DECLARE V_ERROR VARCHAR(30);
	DECLARE V_CADENA VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE nameTable VARCHAR(30);
	DECLARE nameTable2 VARCHAR(30);
	DECLARE acronimo VARCHAR(5);
	DECLARE V_CARGA_FULL VARCHAR(20);
	
L1: BEGIN
	
	SET P_ERROR = ''; 
 
 	SET V_StartTimeStampPadre = Cast(P_StartTimeStampPadre AS TIMESTAMP(6) Format 'yyyy-mm-ddhh:mi:ss');
	SET V_DateTable = (V_StartTimeStampPadre (Format 'yyyyMMdd') (CHAR(8)))||'_'||(V_StartTimeStampPadre (Format 'hhmiss') (CHAR(6)));
	SET acronimo = 'Ubica';
	SET nameTable = 'TMP_UBICA_ETAPA_9';
	
    ------------------------------------------------------------------------------------------------------------------------
    -- Valida Tipo EjecuciÃ¸ÂŠÃ´Â³n , is null = Carga Full, is not null = Carga Delta
    ------------------------------------------------------------------------------------------------------------------------
	SET V_CARGA_FULL = '';
	SELECT Cast(Max(FECHA_HORA_FIN) AS VARCHAR(20))
	INTO V_CARGA_FULL
	FROM REC_MTDAT.LOG_TD LTD
	WHERE Trim(ESTADO_EJECUCION) ='Finalizado OK'
	AND Trim(NOMBRE_PROCESO)=:P_Nombre_Proceso_Padre
	AND Trim(TABLA_ORIGEN_STAGE) =:nameTable;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_I_UBICA
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_FLAG_OP_I_UBICA'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_UBICA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_I_UBICA
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_UBICA AS(
					SELECT COD_DW_PERSONA_UBIC FROM '||P_BDDATOS||'.RELACION_PERSONA_UBICACION RPU
					WHERE RPU.LOTE IS NOT NULL AND RPU.LOTE_ACTUALIZACION IS NULL
					AND CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (1):. Creacion Tabla TMP_FLAG_OP_I_UBICA' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT '||P_BDSTAGE||'.TMP_FLAG_OP_I_UBICA INDEX(COD_DW_PERSONA_UBIC)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (2):. Estadistica para  TMP_FLAG_OP_I_UBICA' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_FLAG_OP_A_UBICA
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_FLAG_OP_A_UBICA'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_UBICA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_FLAG_OP_A_UBICA
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_UBICA AS(
					SELECT COD_DW_PERSONA_UBIC FROM '||P_BDDATOS||'.RELACION_PERSONA_UBICACION RPU
					WHERE RPU.LOTE_ACTUALIZACION IS NOT NULL
					AND CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'') >= COALESCE((SELECT CAST(MAX(FECHA_HORA_FIN) AS DATE FORMAT ''YYYY-MM-DD'')
							FROM '||P_BDMTDAT||'.LOG_TD LTD
							WHERE TRIM(ESTADO_EJECUCION) =''Finalizado OK''
							AND TRIM(NOMBRE_PROCESO)='''||P_Nombre_Proceso_Padre||'''
							AND TABLA_ORIGEN_STAGE LIKE '''||nameTable||'''),CAST(RPU.FECHA_MODIFICACION AS DATE FORMAT ''YYYY-MM-DD'')-1)
					) WITH DATA
                    PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote 
	                                ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (3):. Creacion Tabla TMP_FLAG_OP_A_UBICA' 
									,V_ERROR);			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT '||P_BDSTAGE||'.TMP_FLAG_OP_A_UBICA INDEX(COD_DW_PERSONA_UBIC)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (4):. Estadistica para  TMP_FLAG_OP_A_UBICA' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
   
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_UBICA_ETAPA_0
   ------------------------------------------------------------------------------------------------------------------------
   
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_0'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_0';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_UBICA_ETAPA_0
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_0 
					AS (
					SELECT Lote
					,COUNT(1) Q
					FROM '||P_BDMTDAT||'.LOG_TD
					WHERE NOMBRE_PROCESO LIKE ''%P0002_RELACION_PERSONA_UBICACION%''
					AND Estado_Ejecucion IN (''Finalizado OK'',''Cargue OK'')
					AND Fecha_Hora_Inicio >= (SELECT MAX(Fecha_Hora_Inicio) Fecha_Hora
												FROM '||P_BDMTDAT||'.LOG_TD
												WHERE NOMBRE_PROCESO LIKE ''P0035%''
												AND Estado_Ejecucion IN (''Finalizado OK'',''Cargue OK''))
					GROUP BY 1
					)
					WITH DATA
					PRIMARY INDEX(Lote);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (5):. Creacion Tabla TMP_UBICA_ETAPA_0' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;   
   
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT '||P_BDSTAGE||'.TMP_UBICA_ETAPA_0 INDEX(Lote)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (6):. Estadistica para  TMP_UBICA_ETAPA_0' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Busca la tabla TMP_UBICA_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
   ------------------------------------------------------------------------------------------------------------------------
   -- Crea la tabla TMP_UBICA_ETAPA_1
   ------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1
					 AS (SELECT RPU.Cod_DW_Persona_Ubic
								,RPU.Orden_Prioridad
								,RPU.Cod_DW_Ubic
								,RPU.Cod_DW_Direccion_Fisica
								,RPU.Cod_DW_Telefono
								,RPU.Cod_DW_Direccion_Electronica
								,RPU.Ind_Unificacion
								,RPU.Cod_DW_Tipo_Ubicacion_Dir
								,RPU.ID_Buro_Persona
								,RPU.Cod_Pin_Persona
					FROM  '||P_BDVISTA||'.V_RELACION_PERSONA_UBICACION RPU
					LEFT JOIN '||P_BDVISTA||'.V_BLOQUEO BLQ
					ON RPU.COD_DW_PERSONA_UBIC=BLQ.COD_DW_PERSONA_UBIC

					WHERE (RPU.IND_UNIFICACION IS NULL OR RPU.IND_UNIFICACION=0 OR RPU.IND_UNIFICACION='''') -- Direcciones sin unificar o padres				  
					AND BLQ.COD_DW_PERSONA_UBIC IS NULL
					AND RPU.ORDEN_PRIORIDAD IS NOT NULL /*#2 AJUSTE 30-11-2018*/
					)WITH DATA
					PRIMARY INDEX(Cod_DW_Persona_Ubic);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (7):. Creacion Tabla TMP_UBICA_ETAPA_1' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
    
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic), COLUMN(Cod_DW_Ubic)
	                              , COLUMN(Cod_DW_Ubic,Cod_DW_Direccion_Fisica),COLUMN(Cod_DW_Telefono)
								  , COLUMN(Cod_DW_Direccion_Electronica)
								  , COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
								  ,COLUMN(ID_Buro_Persona)
  	                ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (8):. Estadistica para TMP_UBICA_ETAPA_1' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_3
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_UBICA_ETAPA_3
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3 
	            AS (SELECT
				UTP1.Cod_DW_Persona_Ubic
				,UTP1.Orden_Prioridad
				,UTP1.Cod_DW_Ubic
				,UTP1.Cod_DW_Direccion_Fisica
				,UTP1.Cod_DW_Telefono
				,UTP1.Cod_DW_Direccion_Electronica
				,UTP1.Ind_Unificacion
				,UTP1.Cod_DW_Tipo_Ubicacion_Dir
				,UTP1.ID_Buro_Persona
				,UTP1.Cod_Pin_Persona
				,TRIM(COALESCE(UEZ.TEXTO_UBICACION,'' '')) AS TEXTO_UBICACION--||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
				,UEZ.COD_DW_CIUDAD
				,VGEO.COD_DANE_CIUDAD AS CODIGO_DANE
				,UEZ.COD_DW_GESTION_REGISTRO
				,UEZ.COD_DW_TIPO_UBICACION
				,VTU.DESCRIPCION_TIPO_UBICACION
				,VTUD.DESCRIPCION_TIPO_UBICACION_DIR
				,UEZ.COD_DW_TIPO_VIA
				,UEZ.COD_DW_ZONA_UBICACION
				,VZU.DESCRIPCION_ZONA_UBICACION
				,VGEO.DESCRIPCION_CIUDAD AS CIUDAD
				,VGEO.DESCRIPCION_DEPARTAMENTO AS DEPARTAMENTO

				FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1 UTP1
				INNER JOIN '||P_BDDATOS||'.UBICACION_ESTANDARIZADA UEZ  ON UTP1.COD_DW_UBIC = UEZ.COD_DW_UBIC
				INNER JOIN '||P_BDVISTA||'.V_TIPO_UBICACION VTU  ON VTU.COD_DW_TIPO_UBICACION = UEZ.COD_DW_TIPO_UBICACION
				INNER JOIN '||P_BDVISTA||'.V_GESTION_REGISTRO GR 	 ON UEZ.COD_DW_GESTION_REGISTRO=GR.COD_DW_GESTION_REGISTRO
				AND GR.DESCRIPCION_GESTION_REGISTRO=''VALIDA'' -- Direcciones Validas

				LEFT JOIN '||P_BDVISTA||'.V_TIPO_UBICACION_DIRECCION VTUD                    ON UTP1.COD_DW_TIPO_UBICACION_DIR = VTUD.COD_DW_TIPO_UBICACION_DIR
				LEFT JOIN '||P_BDVISTA||'.V_ZONA_UBICACION VZU                                              ON UEZ.COD_DW_ZONA_UBICACION = VZU.COD_DW_ZONA_UBICACION
				LEFT JOIN '||P_BDVISTA||'.V_GEOGRAFIA VGEO                                                     ON UEZ.COD_DW_CIUDAD = VGEO.COD_DW_CIUDAD-- #1
				)
				WITH DATA
				PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (9):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Acte ualiza estadisticas a TMP_UBICA_ETAPA_3
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)
						,COLUMN(Cod_DW_Ubic)
						,COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						,COLUMN(Cod_DW_Telefono)
						,COLUMN(Cod_DW_Direccion_Electronica)
						,COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						,COLUMN(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (10):. Estadisticas para '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_41
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_41'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_UBICA_ETAPA_41
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41 
					AS (SELECT UTP3.Cod_DW_Persona_Ubic
							,UTP3.Orden_Prioridad
							,UTP3.Cod_DW_Ubic
							,UTP3.Cod_DW_Direccion_Fisica
							,UTP3.Cod_DW_Telefono
							,UTP3.Cod_DW_Direccion_Electronica
							,UTP3.Ind_Unificacion
							,UTP3.Cod_DW_Tipo_Ubicacion_Dir
							,UTP3.ID_Buro_Persona
							,UTP3.Cod_Pin_Persona
							,UTP3.TEXTO_UBICACION --||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
							,UTP3.COD_DW_CIUDAD
							,UTP3.CODIGO_DANE
							,UTP3.COD_DW_GESTION_REGISTRO
							,UTP3.COD_DW_TIPO_UBICACION
							,UTP3.DESCRIPCION_TIPO_UBICACION
							,UTP3.DESCRIPCION_TIPO_UBICACION_DIR
							,UTP3.COD_DW_TIPO_VIA
							,UTP3.COD_DW_ZONA_UBICACION
							,UTP3.DESCRIPCION_ZONA_UBICACION
							,UTP3.CIUDAD
							,UTP3.DEPARTAMENTO

							,TRIM(DRF.COMPLEMENTO) COMPLEMENTO
							,TRIM(UTP3.TEXTO_UBICACION ||'' ''|| COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
							,TRIM(DRF.Tipo_Via_Principal) Tipo_Via_Principal
							,TRIM(DRF.Via_Principal) Via_Principal
							,TRIM(DRF.Via_Generadora) Via_Generadora
							,TRIM(DRF.Numero_Puerta) Numero_Puerta
					FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3 UTP3
					LEFT JOIN '||P_BDDATOS||'.DIRECCION_FISICA DRF ON UTP3.COD_DW_DIRECCION_FISICA = DRF.COD_DW_DIRECCION_FISICA AND UTP3.COD_DW_UBIC=DRF.COD_DW_UBIC /* AJUSTADO 26/10/2018 */
					WHERE  UTP3.COD_DW_DIRECCION_FISICA > -1
					)
					WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (11):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_UBICA_ETAPA_41
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)  ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41;';
				   

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
	
 		,:V_CADENA
			,'SP_Linea_Ubicacion (12):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4';		
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
------------------------------------------------------------------------------------------------------------------------
-- Crea la tabla TMP_UBICA_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4 
					AS (SELECT UTP3.Cod_DW_Persona_Ubic
							,UTP3.Orden_Prioridad
							,UTP3.Cod_DW_Ubic
							,UTP3.Cod_DW_Direccion_Fisica
							,UTP3.Cod_DW_Telefono
							,UTP3.Cod_DW_Direccion_Electronica
							,UTP3.Ind_Unificacion
							,UTP3.Cod_DW_Tipo_Ubicacion_Dir
							,UTP3.ID_Buro_Persona
							,UTP3.Cod_Pin_Persona
							,UTP3.TEXTO_UBICACION 
							,UTP3.COD_DW_CIUDAD
							,UTP3.CODIGO_DANE
							,UTP3.COD_DW_GESTION_REGISTRO
							,UTP3.COD_DW_TIPO_UBICACION
							,UTP3.DESCRIPCION_TIPO_UBICACION
							,UTP3.DESCRIPCION_TIPO_UBICACION_DIR
							,UTP3.COD_DW_TIPO_VIA
							,UTP3.COD_DW_ZONA_UBICACION
							,UTP3.DESCRIPCION_ZONA_UBICACION
							,UTP3.CIUDAD
							,UTP3.DEPARTAMENTO

							,COMPLEMENTO
							,DATO
							,Tipo_Via_Principal
							,Via_Principal
							,Via_Generadora
							,Numero_Puerta
					FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3 UTP3
					LEFT JOIN '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41 UTP4
                    ON UTP3.COD_DW_PERSONA_UBIC = UTP4.COD_DW_PERSONA_UBIC
					)
					WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (11):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------
-- Actualiza estadisticas a TMP_UBICA_ETAPA_4
------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic), COLUMN(Cod_DW_Ubic)
						    , COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						    , COLUMN(Cod_DW_Telefono)
						    , COLUMN(Cod_DW_Direccion_Electronica)
						    , COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						    , COLUMN(ID_Buro_Persona) 
						    , COLUMN(COD_DW_CIUDAD) 
						    , COLUMN(COD_DW_GESTION_REGISTRO) 
						    , COLUMN(COD_DW_TIPO_UBICACION) 
						    , COLUMN(COD_DW_TIPO_VIA) 
						    , COLUMN(COD_DW_ZONA_UBICACION) 
                   ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (12):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_5
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_41';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5 AS (
					SELECT
					UTP4.Cod_DW_Persona_Ubic
					,UTP4.Orden_Prioridad
					,UTP4.Cod_DW_Ubic
					,UTP4.Cod_DW_Direccion_Fisica
					,UTP4.Cod_DW_Telefono
					,UTP4.Cod_DW_Direccion_Electronica
					,UTP4.Ind_Unificacion
					,UTP4.Cod_DW_Tipo_Ubicacion_Dir
					,UTP4.ID_Buro_Persona
					,UTP4.Cod_Pin_Persona
					,UTP4.TEXTO_UBICACION --||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
					,UTP4.COD_DW_CIUDAD
					,UTP4.CODIGO_DANE
					,UTP4.COD_DW_GESTION_REGISTRO
					,UTP4.COD_DW_TIPO_UBICACION
					,UTP4.DESCRIPCION_TIPO_UBICACION
					,UTP4.DESCRIPCION_TIPO_UBICACION_DIR
					,UTP4.COD_DW_TIPO_VIA
					,UTP4.COD_DW_ZONA_UBICACION
					,UTP4.DESCRIPCION_ZONA_UBICACION
					,UTP4.CIUDAD
					,UTP4.DEPARTAMENTO
					,UTP4.COMPLEMENTO
					,UTP4.DATO
					,UTP4.Tipo_Via_Principal
					,UTP4.Via_Principal
					,UTP4.Via_Generadora
					,UTP4.Numero_Puerta
					,VTF.COD_AREA AS INDICATIVO
					FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4 UTP4
					LEFT JOIN '||P_BDVISTA||'.V_TELEFONO_FIJO VTF  ON UTP4.COD_DW_TELEFONO = VTF.COD_DW_TELEFONO
					)
					WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (13):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_5
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)
						, COLUMN(Cod_DW_Ubic)
						, COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						, COLUMN(Cod_DW_Telefono)
						, COLUMN(Cod_DW_Direccion_Electronica)
						, COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						, COLUMN(ID_Buro_Persona)  ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (14):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_6
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6 
					AS (SELECT UTP5.Cod_DW_Persona_Ubic
								,UTP5.Orden_Prioridad
								,UTP5.Cod_DW_Ubic
								,UTP5.Cod_DW_Direccion_Fisica
								,UTP5.Cod_DW_Telefono
								,UTP5.Cod_DW_Direccion_Electronica
								,UTP5.Ind_Unificacion
								,UTP5.Cod_DW_Tipo_Ubicacion_Dir
								,UTP5.ID_Buro_Persona
								,UTP5.Cod_Pin_Persona
								,UTP5.TEXTO_UBICACION --||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
								,UTP5.COD_DW_CIUDAD
								,UTP5.CODIGO_DANE
								,UTP5.COD_DW_GESTION_REGISTRO
								,UTP5.COD_DW_TIPO_UBICACION
								,UTP5.DESCRIPCION_TIPO_UBICACION
								,UTP5.DESCRIPCION_TIPO_UBICACION_DIR
								,UTP5.COD_DW_TIPO_VIA
								,UTP5.COD_DW_ZONA_UBICACION
								,UTP5.DESCRIPCION_ZONA_UBICACION
								,UTP5.CIUDAD
								,UTP5.DEPARTAMENTO
								,UTP5.COMPLEMENTO
								,UTP5.DATO
								,UTP5.Tipo_Via_Principal
								,UTP5.Via_Principal
								,UTP5.Via_Generadora
								,UTP5.Numero_Puerta
								,UTP5.INDICATIVO
								,RUEG.LONGITUD AS LONGITUD
								,RUEG.LATITUD AS LATITUD
								,RUEG.URBANIZACION_BARRIO AS BARRIO
								,RUEG.LOCALIDAD_COMUNA AS LOCALIDAD
								,RUEG.COD_POSTAL AS CODIGO_POSTAL
								,VESD.DESCRIPCION_ESTRATO AS ESTRATO
					FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5 UTP5
					LEFT JOIN '||P_BDDATOS||'.RELACION_UBICAC_ESTANDAR_GEO RUEG ON UTP5.COD_DW_UBIC = RUEG.COD_DW_UBIC
					LEFT JOIN '||P_BDVISTA||'.V_ESTRATO_DIRECCION VESD  ON RUEG.COD_DW_ESTRATO = VESD.COD_DW_ESTRATO
					)WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (15):. Creacion Tabla TMP_UBICA_ETAPA_6' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_6
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)
							, COLUMN(Cod_DW_Ubic)
							, COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
							, COLUMN(Cod_DW_Telefono)
							, COLUMN(Cod_DW_Direccion_Electronica)
							, COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
							, COLUMN(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (16):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
   ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_7
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_7'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7 
					AS (SELECT UTP6.Cod_DW_Persona_Ubic
								,UTP6.Orden_Prioridad
								,UTP6.Cod_DW_Ubic
								,UTP6.Cod_DW_Direccion_Fisica
								,UTP6.Cod_DW_Telefono
								,UTP6.Cod_DW_Direccion_Electronica
								,UTP6.Ind_Unificacion
								,UTP6.Cod_DW_Tipo_Ubicacion_Dir
								,UTP6.ID_Buro_Persona
								,UTP6.Cod_Pin_Persona
								,UTP6.TEXTO_UBICACION --||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
								,UTP6.COD_DW_CIUDAD
								,UTP6.CODIGO_DANE
								,UTP6.COD_DW_GESTION_REGISTRO
								,UTP6.COD_DW_TIPO_UBICACION
								,UTP6.DESCRIPCION_TIPO_UBICACION
								,UTP6.DESCRIPCION_TIPO_UBICACION_DIR
								,UTP6.COD_DW_TIPO_VIA
								,UTP6.COD_DW_ZONA_UBICACION
								,UTP6.DESCRIPCION_ZONA_UBICACION
								,UTP6.CIUDAD
								,UTP6.DEPARTAMENTO

								,UTP6.COMPLEMENTO
								,UTP6.DATO
								,UTP6.Tipo_Via_Principal
								,UTP6.Via_Principal
								,UTP6.Via_Generadora
								,UTP6.Numero_Puerta
								,UTP6.INDICATIVO

								,UTP6.LONGITUD
								,UTP6.LATITUD
								,UTP6.BARRIO
								,UTP6.LOCALIDAD
								,UTP6.CODIGO_POSTAL
								,UTP6.ESTRATO

								,CAST(VTE.DESCRIPCION_TIPO_CORREO AS VARCHAR(1)) AS TIPO_CUENTA-- #1
					FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6 UTP6
					LEFT JOIN '||P_BDVISTA||'.V_DIRECCION_ELECTRONICA VDE  ON UTP6.COD_DW_UBIC = VDE.COD_DW_UBIC-- #1
					LEFT JOIN '||P_BDVISTA||'.V_TIPO_CORREO VTE    ON VTE.COD_DW_TIPO_CORREO = VDE.COD_DW_TIPO_CORREO-- #1
					)WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (17):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_7
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)
						, COLUMN(Cod_DW_Ubic)
						, COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						, COLUMN(Cod_DW_Telefono)
						, COLUMN(Cod_DW_Direccion_Electronica)
						, COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						, COLUMN(Cod_DW_Tipo_Via)
						, COLUMN(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (18):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  ------------------------------------------------------------------------------------------------------------------------
  -- Consulta tabla TMP_UBICA_ETAPA_8
  ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_8'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8 
					AS (SELECT UTP7.Cod_DW_Persona_Ubic
							,UTP7.Orden_Prioridad
							,UTP7.Cod_DW_Ubic
							,UTP7.Cod_DW_Direccion_Fisica
							,UTP7.Cod_DW_Telefono
							,UTP7.Cod_DW_Direccion_Electronica
							,UTP7.Ind_Unificacion
							,UTP7.Cod_DW_Tipo_Ubicacion_Dir
							,UTP7.ID_Buro_Persona
							,UTP7.Cod_Pin_Persona
							,UTP7.TEXTO_UBICACION --||'' ''||COALESCE(DRF.COMPLEMENTO,'' '')) AS DATO
							,UTP7.COD_DW_CIUDAD
							,UTP7.CODIGO_DANE
							,UTP7.COD_DW_GESTION_REGISTRO
							,UTP7.COD_DW_TIPO_UBICACION
							,UTP7.DESCRIPCION_TIPO_UBICACION
							,UTP7.DESCRIPCION_TIPO_UBICACION_DIR
							,UTP7.COD_DW_TIPO_VIA
							,UTP7.COD_DW_ZONA_UBICACION
							,UTP7.DESCRIPCION_ZONA_UBICACION
							,UTP7.CIUDAD
							,UTP7.DEPARTAMENTO
							,UTP7.COMPLEMENTO
							,UTP7.DATO
							,UTP7.Tipo_Via_Principal
							,UTP7.Via_Principal
							,UTP7.Via_Generadora
							,UTP7.Numero_Puerta
							,h4.Descripcion_Tipo_Via
							,UTP7.INDICATIVO
							,UTP7.LONGITUD
							,UTP7.LATITUD
							,UTP7.BARRIO
							,UTP7.LOCALIDAD
							,UTP7.CODIGO_POSTAL
							,UTP7.ESTRATO
							,UTP7.TIPO_CUENTA-- #1
							,CASE WHEN UTP7.DESCRIPCION_TIPO_UBICACION IN (''Celular'',''Mail'') THEN '''' ELSE  h3.Descripcion_Hom_TipoUbic_D_Linea END AS TIPO					
										/*,CASE WHEN VTU.DESCRIPCION_TIPO_UBICACION IN (''Celular'',''Mail'') THEN '''' ELSE  VZU.DESCRIPCION_ZONA_UBICACION END AS ZONA*/
							,CASE WHEN UTP7.DESCRIPCION_TIPO_UBICACION IN (''Celular'',''Mail'') THEN '''' ELSE  h1.Descripcion_Hom_Zona_Linea END AS ZONA
					 FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7 UTP7
					 LEFT JOIN '||P_BDVISTA||'.V_Hom_Zona_Linea h1   ON UTP7.Descripcion_Zona_Ubicacion=h1.Valor_Fuente
					 LEFT JOIN '||P_BDVISTA||'.V_Hom_TipoUbic_Dir_Linea h3 ON UTP7.Descripcion_Tipo_Ubicacion_Dir=h3.Valor_Fuente             
					 LEFT JOIN '||P_BDVISTA||'.V_Tipo_Via h4 ON UTP7.Cod_DW_Tipo_Via=h4.Cod_DW_Tipo_Via             
					)WITH DATA
					PRIMARY INDEX(COD_DW_PERSONA_UBIC);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (19):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(Cod_DW_Persona_Ubic)
						, COLUMN(Cod_DW_Ubic)
						, COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						, COLUMN(Cod_DW_Telefono)
						, COLUMN(Cod_DW_Direccion_Electronica)
						, COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						, COLUMN(ID_Buro_Persona) ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (20):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
    -- Consulta tabla TMP_UBICA_ETAPA_9
    ------------------------------------------------------------------------------------------------------------------------
    SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_9'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9';
		CALL DBC.SysExecSQL(:V_CADENA);
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_7';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_9
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
 	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9
					 AS (SELECT  VUP.COD_TIPO_IDENT_FTE 
								,h1.Descripcion_Hom_Tip_Ident_Linea AS TIPO_IDENTIFICACION
								,CAST(VUP.NUM_IDENT AS BIGINT) NUMERO_IDENTIFICACION
								,UTP8.Cod_DW_Persona_Ubic AS ID
								,ORDEN_PRIORIDAD AS ORDEN
								,INDICATIVO
								,CASE WHEN  DESCRIPCION_TIPO_UBICACION = ''Geografica'' THEN DATO ELSE TEXTO_UBICACION END DATO
								,ESTRATO
		
 						,TIPO
								,ZONA
								,COALESCE(CIUDAD,'''') CIUDAD
								,COALESCE(DEPARTAMENTO,'''') DEPARTAMENTO
								,LONGITUD
								,LATITUD
								,NULL AS REPORTADO_DESDE
								,NULL AS ULTIMO_REPORTE
								--,RRPU.FUENTE AS FUENTE
								,NULL AS FUENTE
								,0 AS NUMERO_REPORTES
								,0 AS NUMERO_ENTIDADES
								,BARRIO
								,LOCALIDAD
								,CODIGO_POSTAL
								,CASE WHEN DESCRIPCION_TIPO_UBICACION = ''Celular'' THEN ''CEL''
														WHEN DESCRIPCION_TIPO_UBICACION = ''Mail'' THEN ''EMAIL''
														WHEN DESCRIPCION_TIPO_UBICACION = ''Geografica'' THEN ''DIR''
														WHEN DESCRIPCION_TIPO_UBICACION = ''Telefono'' THEN ''TEL''
														ELSE NULL
								END AS CLASE
								,UTP8.Id_Buro_Persona AS INFO_BASICA
								,COALESCE(CODIGO_DANE,''-1'') CODIGO_DANE-- #1
								,CASE WHEN DESCRIPCION_TIPO_UBICACION_DIR EQ ''CRR'' THEN ''1'' ELSE ''0'' END ES_TIPO_CRR-- #1
								,CASE WHEN DESCRIPCION_TIPO_UBICACION_DIR EQ ''RES'' THEN ''1'' ELSE ''0'' END ES_TIPO_RES-- #1
								,CAST(NULL AS VARCHAR(1)) AS ES_TIPO_PPL-- #1
								,CAST(NULL AS VARCHAR(1)) AS ES_TIPO_AGN-- #1
								,CAST(NULL AS VARCHAR(1)) AS ES_TIPO_SUC-- #1
								,CAST(NULL AS VARCHAR(1)) AS ES_TIPO_EST-- #1
								,CAST(NULL AS VARCHAR(1)) AS ES_TIPO_CDI-- #1
								,CASE WHEN DESCRIPCION_TIPO_UBICACION_DIR EQ ''LAB'' THEN ''1'' ELSE ''0'' END ES_TIPO_LAB-- #1
								,TIPO_CUENTA-- #1															
								,UTP8.Cod_DW_Ubic
								,UTP8.Cod_DW_Direccion_Fisica
								,UTP8.Cod_DW_Telefono
								,UTP8.Cod_DW_Direccion_Electronica
								,UTP8.Ind_Unificacion
								,UTP8.Cod_DW_Tipo_Ubicacion_Dir
								,UTP8.ID_Buro_Persona								
								,UTP8.Cod_Pin_Persona			
								,'||CASE WHEN V_CARGA_FULL IS NULL THEN '''I''' ELSE 'FLAG_OP1' END||' AS FLAG_OP								
								,CASE WHEN BLQ.FECHA_BLOQUEO = DATE - INTERVAL ''1'' DAY THEN ''E''
										WHEN FOPI.COD_DW_PERSONA_UBIC IS NOT NULL THEN ''I''
										WHEN FOPA.COD_DW_PERSONA_UBIC IS NOT NULL THEN ''A''
								END AS FLAG_OP1
								,UTP8.Tipo_Via_Principal
								,UTP8.Via_Principal
								,UTP8.Via_Generadora
								,UTP8.Numero_Puerta
								,UTP8.Descripcion_Tipo_Via
						FROM  '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8 UTP8
						INNER JOIN '||P_BTTPRUVI||'.VU_PERSONA VUP
						ON UTP8.ID_BURO_PERSONA=VUP.ID_BURO_PERSONA

						LEFT JOIN '||P_BDVISTA||'.V_Hom_Tip_Ident_Linea h1
						ON VUP.COD_TIPO_IDENT_FTE=h1.Valor_Fuente 
						
						LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_I_UBICA FOPI 	
						ON UTP8.COD_DW_PERSONA_UBIC = FOPI.COD_DW_PERSONA_UBIC
						
						LEFT JOIN '||P_BDSTAGE||'.TMP_FLAG_OP_A_UBICA FOPA 	
						ON UTP8.COD_DW_PERSONA_UBIC = FOPA.COD_DW_PERSONA_UBIC
						
						LEFT JOIN '||P_BDVISTA||'.V_BLOQUEO BLQ
						ON UTP8.COD_DW_PERSONA_UBIC=BLQ.COD_DW_PERSONA_UBIC
						
						)WITH DATA
						PRIMARY INDEX(ID)
						INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
			,:P_Nombre_Proceso_Padre 
			,:V_CADENA 
			,'SP_Linea_Ubicacion (21):. Creacion Tabla Linea_Ubicacion' 
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_9
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(ID)
						, COLUMN(Cod_DW_Ubic)
						, COLUMN(Cod_DW_Direccion_Fisica,Cod_DW_Ubic) /* AJUSTADO 26/10/2018 */
						, COLUMN(Cod_DW_Telefono)
						, COLUMN(Cod_DW_Direccion_Electronica)
						, COLUMN(Cod_DW_Tipo_Ubicacion_Dir)
						, COLUMN(ID_Buro_Persona)ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'SP_Linea_Ubicacion (22):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ------------------------------------------------------------------------------------------------------------------------
	-- Borrar Tabla TMP_UBICA_ETAPA_8
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubicacion (23):. Borra Tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_8'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_UBICA_AGR_NRO_ENTIDADES
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_AGR_NRO_ENTIDADES'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_ENTIDADES';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_AGR_NRO_ENTIDADES
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_ENTIDADES
					AS 
					(SEL UTP1.Id_Buro_Persona
							,UTP1.Cod_Pin_Persona
							,UTP1.DATO
							,COALESCE(CIUDAD, ''SV'')  CIUDAD
							,COALESCE(DEPARTAMENTO, ''SV'') DEPARTAMENTO
							,COALESCE(CODIGO_DANE, ''SV'') CODIGO_DANE
							,Count(DISTINCT RRPU.ID_BURO_SUSCRIPTOR) AS NUMERO_ENTIDADES

					FROM '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 UTP1

					INNER JOIN '||P_BDVISTA||'.VM_REPORTE_RELACION_PERS_UBI RRPU
					ON UTP1.ID=RRPU.Cod_DW_Persona_Ubic

					/*LEFT JOIN '||P_BDVISTA||'.V_FUENTE VFT
					ON RRPU.COD_DW_FUENTE = VFT.COD_DW_FUENTE

					LEFT JOIN '||P_BTTPRUVI||'.V_FUENTE_DATO VFTD
					ON RRPU.COD_DW_FUENTE = VFTD.COD_DW_FTE_DATO

					LEFT JOIN '||P_BDVISTA||'.V_Hom_Fuente_Linea h2 
					ON VFT.DESCRIPCION_FUENTE=h2.valor_fuente*/ 

					GROUP BY 1,2,3,4,5,6
					)WITH DATA 
					PRIMARY INDEX(Id_Buro_Persona, Cod_Pin_Persona, DATO);';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (23):. Creacion Tabla TMP_UBICA_AGR_NRO_ENTIDADES' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
		
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT  INDEX(Id_Buro_Persona, Cod_Pin_Persona, DATO) ON '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_ENTIDADES;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubicacion (23.1):. Estadisticas a '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_ENTIDADES'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
---------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_AGR_NRO_REPORTES'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_REPORTES';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_REPORTES
					AS 
					(
					SEL UTP1.Id_Buro_Persona
							,UTP1.Cod_Pin_Persona
							,UTP1.DATO
							,Coalesce(CIUDAD, ''SV'')  CIUDAD
							,Coalesce(DEPARTAMENTO, ''SV'') DEPARTAMENTO
							,Coalesce(CODIGO_DANE, ''SV'') CODIGO_DANE
						,Count(*) AS NUMERO_REPORTES

					FROM '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 UTP1

					INNER JOIN '||P_BDVISTA||'.VM_REPORTE_RELACION_PERS_UBI RRPU
					ON UTP1.ID=RRPU.Cod_DW_Persona_Ubic
					GROUP BY 1,2,3,4,5,6
					)WITH DATA 
					PRIMARY INDEX(Id_Buro_Persona, Cod_Pin_Persona, DATO);';


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (24):. Creacion Tabla TMP_UBICA_AGR_NRO_REPORTES' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;					
	
	------------------------------------------------------------------------------------------------------------------------
	-- Busca la tabla TMP_UBICA_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_2'
	AND Tablekind IN ('T', 'O');
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	------------------------------------------------------------------------------------------------------------------------
	-- Crea la tabla TMP_UBICA_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_2
					AS (SELECT UTP1.TIPO_IDENTIFICACION
											,UTP1.NUMERO_IDENTIFICACION
											,UTP1.Id_Buro_Persona AS INFO_BASICA
											,UTP1.Cod_Pin_Persona
											,UTP1.DATO
											,RRPU.Cod_DW_Fuente
											,UTP1.ID
											,UTP1.CIUDAD
											,UTP1.DEPARTAMENTO
											,UTP1.CODIGO_DANE
											,COALESCE(COALESCE(VFT.DESCRIPCION_FUENTE,''CAM''),h2.Descripcion_Hom_Fuente_Linea) AS FUENTE
											,MIN(CASE WHEN RRPU.ID_FLAG_DESDE = 1 THEN RRPU.FECHA_REPORTE ELSE NULL END) AS REPORTADO_DESDE
											,MAX(CASE WHEN RRPU.ID_FLAG_DESDE = 0 THEN RRPU.FECHA_REPORTE ELSE NULL END) AS ULTIMO_REPORTE
											,MAX(AGR.NUMERO_ENTIDADES) NUMERO_ENTIDADES
											,max(AGRP.NUMERO_REPORTES) AS NUMERO_REPORTES
					FROM '||P_BDSTAGE||'.TMP_UBICA_ETAPA_9 UTP1

					INNER JOIN '||P_BDVISTA||'.VM_REPORTE_RELACION_PERS_UBI RRPU
					ON UTP1.ID=RRPU.Cod_DW_Persona_Ubic

					LEFT JOIN '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_ENTIDADES AGR 	
					ON   UTP1.Id_Buro_Persona  = AGR.Id_Buro_Persona
					AND  UTP1.Cod_Pin_Persona = AGR.Cod_Pin_Persona
					AND  UTP1.DATO =  AGR.DATO
					AND  UTP1.CIUDAD = AGR.CIUDAD
					AND  UTP1.DEPARTAMENTO = AGR.DEPARTAMENTO
					AND  UTP1.CODIGO_DANE = AGR.CODIGO_DANE
					
					LEFT JOIN '||P_BDSTAGE||'.TMP_UBICA_AGR_NRO_REPORTES AGRP 	
					ON   UTP1.Id_Buro_Persona  = AGRP.Id_Buro_Persona
					AND  UTP1.Cod_Pin_Persona = AGRP.Cod_Pin_Persona
					AND  UTP1.DATO =  AGRP.DATO
					AND  UTP1.CIUDAD = AGRP.CIUDAD
					AND  UTP1.DEPARTAMENTO = AGRP.DEPARTAMENTO
					AND  UTP1.CODIGO_DANE = AGRP.CODIGO_DANE

					LEFT JOIN '||P_BDVISTA||'.V_FUENTE VFT
					ON RRPU.COD_DW_FUENTE = VFT.COD_DW_FUENTE

					LEFT JOIN '||P_BTTPRUVI||'.V_FUENTE_DATO VFTD
					ON RRPU.COD_DW_FUENTE=VFTD.COD_DW_FTE_DATO

					LEFT JOIN '||P_BDVISTA||'.V_Hom_Fuente_Linea h2 
					ON VFT.DESCRIPCION_FUENTE=h2.valor_fuente

					GROUP BY 1,2,3,4,5,6,7,8,9,10,11
					)
					WITH DATA
					PRIMARY INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,DATO,ID, CODIGO_DANE,FUENTE);';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (24):. Creacion Tabla TMP_UBICA_ETAPA_2' 
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
	
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza estadisticas a TMP_UBICA_ETAPA_2
	------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATS INDEX(TIPO_IDENTIFICACION,NUMERO_IDENTIFICACION,INFO_BASICA,DATO,ID, CODIGO_DANE,FUENTE)
	                     ,COLUMN(ID)
				    ON '||P_BDSTAGE||'.TMP_UBICA_ETAPA_2;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'SP_Linea_Ubicacion (24.1):. Estadisticas a la tabla '||P_BDSTAGE||'.TMP_UBICA_ETAPA_2'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
  
	-----------------------------------------------------------------------------------------------------------------------
	-- Borra Tablas Temporales
	------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_0'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_0';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_1'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_1';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_3'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_3';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_4'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_4';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_5'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_5';
		CALL DBC.SysExecSQL(:V_CADENA);	
	END IF;
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_UBICA_ETAPA_6'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_UBICA_ETAPA_6';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	
	
	/*#2 INICIO AJUSTE BORRADO TEMP AJUSTE 30-11-2018*/
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_FLAG_OP_I_UBICA'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_I_UBICA';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
			
	
	
	SET V_CADENA = '';
	LOCKING ROW FOR ACCESS
	SELECT TableName 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TableName = 'TMP_FLAG_OP_A_UBICA'
	AND Tablekind IN ('T', 'O');
	
	
	IF Activity_Count > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_FLAG_OP_A_UBICA';
		CALL DBC.SysExecSQL(:V_CADENA);		
	END IF;
	
	
	/*#2 FIN AJUSTE BORRADO TEMP 30-11-2018*/
	
	
	------------------------------------------------------------------------------------------------------------------------
	-- Actualiza la tabla LOG_TD
	------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA = '';
 	SET V_CADENA = 'INSERT INTO '||P_BDMTDAT||'.LOG_TD
					(LOTE,FECHA_HORA_INICIO,NOMBRE_PROCESO,ARCHIVO_PLANO,TABLA_ORIGEN_STAGE,TABLA_DESTINO_PROD,
					CANT_REGISTROS_INSERTADOS,CANT_REGISTROS_ACTUALIZADOS,CANT_REGISTROS_STAGE,CANT_REGISTROS_RECHAZADOS,
					USUARIO_BD,FECHA_HORA_FIN,IP_MAQUINA,ESTADO_EJECUCION,COD_DW_FUENTE_ORIGEN)
					SELECT
					'||P_Lote||',
					CAST('''||P_StartTimeStampPadre||''' AS TIMESTAMP(6) FORMAT ''yyyy-mm-ddhh:mi:ss''),
					'''||P_Nombre_Proceso_Padre||''',
					NULL,
					'''||nameTable||''',
					NULL,
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''I''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''A''),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||'),
					(SELECT COUNT(*) FROM '||P_BDSTAGE||'.'||nameTable||' WHERE FLAG_OP = ''E''),
					USER,
					NULL,
					''dbc'',
					NULL,
					NULL;';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre 
									,:P_Nombre_Proceso_Padre 
									,:V_CADENA 
									,'SP_Linea_Ubicacion (28):. Actualiza Tabla LOG_TD' 
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
	
	IF Character_Length(V_ERROR) > 0 THEN 
		LEAVE L1;
	END IF;
 	
  END L1;

END;

