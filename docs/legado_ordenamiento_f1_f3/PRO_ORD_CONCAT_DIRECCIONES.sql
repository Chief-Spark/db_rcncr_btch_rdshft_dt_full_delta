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

