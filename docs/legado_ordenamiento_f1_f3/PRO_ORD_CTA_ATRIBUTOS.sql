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

