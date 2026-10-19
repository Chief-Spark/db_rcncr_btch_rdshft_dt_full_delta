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

