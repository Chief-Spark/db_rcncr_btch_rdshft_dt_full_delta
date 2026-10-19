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

