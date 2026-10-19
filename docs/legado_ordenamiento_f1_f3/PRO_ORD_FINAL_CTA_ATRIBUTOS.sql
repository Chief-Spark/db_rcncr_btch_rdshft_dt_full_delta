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

