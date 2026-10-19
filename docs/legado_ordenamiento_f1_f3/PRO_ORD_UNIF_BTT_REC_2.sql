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

