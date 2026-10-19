REPLACE PROCEDURE REC_DATOS.PRO_ORD_MATERIALIZA_BTT
	(
		 IN	P_Lote						INTEGER
		,IN	P_StartTimeStampPadre		VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDDATOS				VARCHAR(20)
		,IN	P_BDVISTA					VARCHAR(20)
		,IN	P_BDSTAGE					VARCHAR(20)
		,IN	P_BTTDATOS				VARCHAR(20)
		,IN	P_BTTVISTA					VARCHAR(20)
		,IN	P_BDMTDAT				VARCHAR(20)
		,IN	P_BTTMTDAT					VARCHAR(20)
		,IN P_VARQUERY1	/*#2*/			VARCHAR (500)
		,OUT P_ERROR		VARCHAR(50)
	)

/*
 * ################################################################################
 * 
 * Objetivo:	Materialización tablas BTT Ordenamiento.
 * Fecha:		2017-02-17
 * Lider Tecnico:	
 * Realizado por:	Capgemini
 * Parametros:	
 * Proyecto:	
 * Script:		24.2 -- Materializacion BTT. 
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 25/09/2018   #1 Uso de la Vista VU_Cuenta     Andy Garcia
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
 *                                 METADATA TABLAS BDM_%  Modelo BTT
 * 
 * ################################################################################
 */
 
-- 1. Definir la fecha de Ultimo Ordenamiento. (YA CREADA, SOLO CONSUMIRLA)


BEGIN

------------------------
-- DeclaraciÃ³n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR				VARCHAR(30);
	DECLARE V_CADENA				VARCHAR(32000);
	DECLARE V_TABLE					VARCHAR(30);
	DECLARE Temp 					CHAR(30);
	DECLARE V_VARQUERY1			VARCHAR(500);
	DECLARE V_VARQUERY2			VARCHAR(500);
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	SET V_VARQUERY1 = NULLIF(TRIM(P_VARQUERY1),''); /*#2*/
L1:	
BEGIN

---------------------------
-- Busca la tabla Estructuras_MTDAT_BDM
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Estructuras_MTDAT_BDM' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla Estructuras_MTDAT_BDM si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.Estructuras_MTDAT_BDM';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	-----------------------------
	-- Convirtiendo fecha de varchar a date
	-----------------------------

    SET V_CADENA = '';
	SET V_CADENA = ' CREATE MULTISET TABLE  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS (SELECT  No_Lote
								,Tabla1 
								,Insert_1
								,Update_1
								,descripcion
								,CAST(CAST (fecha AS DATE )+36525 AS DATE) FechaProc
								,fecha
  						  FROM bdm_mtdat.MetadataCargaLog 
						) WITH DATA
					PRIMARY INDEX ( No_Lote );';


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(1):Convirtiendo fecha de varchar a date.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


  /*otro query*/
	
    SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM column(No_Lote);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(1.1):Recolectar estadisticas Estructuras_MTDAT_BDM .'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	---------------------------
	-- Busca la tabla CALCULA_LOTE_BTT
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'CALCULA_LOTE_BTT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla CALCULA_LOTE_BTT si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.CALCULA_LOTE_BTT';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	-----------------------------------------------------------------------------------------------------
	---------------- CALCULO QUERY DINAMICO /*#2*/ -----------------------------------------------
	-----------------------------------------------------------------------------------------------------


	SELECT CAMPO
	INTO :V_VARQUERY2
	FROM 
	(SELECT 	CASE WHEN V_VARQUERY1 IS NULL  THEN 
	' INNER JOIN '||P_BDMTDAT||'.Control_Ordenamiento b -- se debe crear en stage alli se almacena la fecha de la ultima vez que se actualiza el proceso
	ON a.FechaProc>=b.Fecha_Ult_Ord
	AND a.Tabla1 IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BTTVISTA||''') -- SUBSELECT PARA EXTRAER WHERE ESQUEMA = BDM
	AND (a.Insert_1>0 OR a.Update_1>0)
	AND TRIM(a.Descripcion)=''Ok'' '
	ELSE 'WHERE a.FechaProc '||V_VARQUERY1||'
	AND a.Tabla1 IN (Select Nombre_Tabla from '||P_BDMTDAT||'.METADATA_ORDENAMIENTO where Nombre_DB ='''||P_BTTVISTA||''') -- SUBSELECT PARA EXTRAER WHERE ESQUEMA = BDM
	AND (a.Insert_1>0 OR a.Update_1>0)
	AND TRIM(a.Descripcion)=''Ok''' END AS CAMPO
	) A
	;

		
	-- Calculando los Lotes para BTT, Fechas y Tablas a validar.
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.CALCULA_LOTE_BTT ,
						 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
				    AS(SELECT a.No_Lote, a.FechaProc, a.Tabla1  -- actualizar la volatil con los campos que se van a tra
					   FROM  '||P_BDSTAGE||'.Estructuras_MTDAT_BDM a
					   '||V_VARQUERY2||' /*#2*/
					)WITH DATA
					PRIMARY INDEX(No_Lote);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(2):Calculando los Lotes para BTT, Fechas y Tablas a validar.'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	/*otro query*/
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.CALCULA_LOTE_BTT INDEX(No_Lote);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(2.1):Recolectar estadisticas CALCULA_LOTE_BTT.'
									,V_ERROR);
									
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	
	
---------------------------
-- Busca la tabla PASO_V_CUENTA
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_CUENTA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
-----------------------------
-- Se borra la tabla PASO_V_CUENTA si existe
-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
-- Calculando los Id_buro_persona, Cod_Pin_Persona para las Cuentas modificadas.

	SET V_CADENA = '';
	SET V_CADENA = ' CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_CUENTA ,
						 NO BEFORE JOURNAL,
						 NO AFTER JOURNAL,
						 CHECKSUM = DEFAULT
						 AS  (
					SELECT c.Cod_Pin_Persona,
						a.Id_Buro_Cliente Id_Buro_Persona
					FROM '||P_BTTVISTA||'.V_CUENTA a
					INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
					ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
					AND (B.TABLA1 =''CUENTA'')

					INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
					ON a.Id_Buro_Cliente=c.Id_Buro_Persona
					
					Group by 1,2
					)
					WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(3):Calculando los Id_buro_persona, Cod_Pin_Persona para las Cuentas modificadas'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_CUENTA INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(3.1):Recolecion estadisticas PASO_V_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	---------------------------
	-- Busca la tabla PASO_V_BURO_PERSONA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_BURO_PERSONA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_BURO_PERSONA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_BURO_PERSONA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    --*************creacion tabla PASO_V_BURO_PERSONA *******************
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_BURO_PERSONA ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS (SELECT  a.Cod_Pin_Persona,
							a.Id_Buro_Persona
						FROM '||P_BTTVISTA||'.V_BURO_PERSONA a
							INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
							ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
								AND (B.TABLA1 =''BURO_PERSONA'')
								
						Group by 1,2
						)
				WITH DATA
				PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
					
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(4):creacion tabla PASO_V_BURO_PERSONA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_BURO_PERSONA INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(4.1):Recoleccion estadisticas PASO_V_BURO_PERSONA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla TMP_PASO_COMCTA_242
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_PASO_COMCTA_242
					AS 
					(SEL Cod_DW_Cta
					FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA a
					Where a.Lote IN (SEL No_Lote FROM  REC_STAGE.CALCULA_LOTE_BTT  WHERE TABLA1 =''COMPORTAMIENTO_CUENTA'' )
					OR a.Lote_Actualizacion IN (SEL No_Lote FROM  REC_STAGE.CALCULA_LOTE_BTT  WHERE TABLA1 =''COMPORTAMIENTO_CUENTA'' )
					Group by 1 
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Cta);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5):creacion tabla TMP_PASO_COMCTA_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_PASO_COMCTA_242 INDEX(Cod_DW_Cta); ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5.1):recoleccion estadisticas TMP_PASO_COMCTA_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_1_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_1_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_1_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_1_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla TMP_PASO_COMCTA_1_242
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242
					AS 
					(SEL Id_Buro_Cliente
					FROM '||P_BTTVISTA||'.VU_CUENTA
					WHERE Cod_DW_Cta IN (SELECT Cod_DW_Cta FROM '||P_BDSTAGE||'.TMP_PASO_COMCTA_242)
					Group by 1 )
					WITH DATA 
					PRIMARY INDEX( Id_Buro_Cliente );';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(6):creacion tabla TMP_PASO_COMCTA_1_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242 INDEX(Id_Buro_Cliente);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(6.1):recoleccion estadisticas TMP_PASO_COMCTA_1_242'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_PASO_COMCTA_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
	---------------------------
	-- Busca la tabla PASO_V_COMPORTAMIENTO_CUENTA
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORTAMIENTO_CUENTA' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORTAMIENTO_CUENTA si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORTAMIENTO_CUENTA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	
	
		
	--*creacion tabla PASO_V_COMPORTAMIENTO_CUENTA
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
					 AS  
					(SELECT  c.Cod_Pin_Persona,
							a.Id_Buro_Cliente Id_Buro_Persona
				      FROM  '||P_BDSTAGE||'.TMP_PASO_COMCTA_1_242 a

					  INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
					  ON a.Id_Buro_Cliente=c.Id_Buro_Persona
					  group by 1,2
					)
					WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5):creacion tabla PASO_V_COMPORTAMIENTO_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORTAMIENTO_CUENTA INDEX(Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(5.1):recoleccion estadisticas PASO_V_COMPORTAMIENTO_CUENTA'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	---------------------------
    -- Busca la tabla TMP_PASO_COMCTA_1_242
      ---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PASO_COMCTA_1_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_PASO_COMCTA_1_242 si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.TMP_PASO_COMCTA_1_242';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
	---------------------------
    -- Busca la tabla PASO_V_COMPORT_CTA_ACTIVO
      ---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORT_CTA_ACTIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_ACTIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORT_CTA_ACTIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
	
    -- creacion tabla PASO_V_COMPORT_CTA_ACTIVO
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO ,
					 NO BEFORE JOURNAL,
					 NO AFTER JOURNAL,
					 CHECKSUM = DEFAULT
			        AS (SELECT c.Cod_Pin_Persona,
         						x.Id_Buro_Cliente Id_Buro_Persona
						FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA_ACTIVO a


						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
						ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
						AND (B.TABLA1 =''COMPORTAMIENTO_CUENTA_ACTIVO'')

						inner join '||P_BTTVISTA||'.VU_CUENTA x /*#1*/
						on a.Cod_DW_Cta = x.Cod_DW_Cta


						INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
						ON x.Id_Buro_Cliente=c.Id_Buro_Persona
						
						Group by 1,2
						)
						WITH DATA
						PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(7):creacion tabla PASO_V_COMPORT_CTA_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_ACTIVO INDEX(Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(7.1):recolectar estadisticas PASO_V_COMPORT_CTA_ACTIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	---------------------------
	-- Busca la tabla PASO_V_COMPORT_CTA_PASIVO
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'PASO_V_COMPORT_CTA_PASIVO' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla PASO_V_COMPORT_CTA_PASIVO si existe
	-----------------------------
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE|| '.PASO_V_COMPORT_CTA_PASIVO';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;		
		
	
	
    --*creacion tabla PASO_V_COMPORT_CTA_PASIVO
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO ,
							 NO BEFORE JOURNAL,
							 NO AFTER JOURNAL,
							 CHECKSUM = DEFAULT
					AS  (SELECT c.Cod_Pin_Persona,
								x.Id_Buro_Cliente Id_Buro_Persona
						FROM  '||P_BTTVISTA||'.V_COMPORTAMIENTO_CUENTA_PASIVO a

						INNER JOIN  '||P_BDSTAGE||'.CALCULA_LOTE_BTT b
						ON  (a.Lote = b.No_Lote OR a.Lote_Actualizacion=b.No_Lote)
						AND (B.TABLA1 =''COMPORTAMIENTO_CUENTA_PASIVO'')
							
						inner join '||P_BTTVISTA||'.VU_CUENTA x /*#1*/
						on a.Cod_DW_Cta = x.Cod_DW_Cta
							

						INNER JOIN '||P_BTTVISTA||'.V_buro_persona c
                        ON x.Id_Buro_Cliente=c.Id_Buro_Persona
						Group by 1,2
					)WITH DATA
					PRIMARY INDEX (Cod_Pin_Persona, Id_Buro_Persona);   ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(8):creacion tabla PASO_V_COMPORT_CTA_PASIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STATISTICS  '||P_BDSTAGE||'.PASO_V_COMPORT_CTA_PASIVO INDEX(Cod_Pin_Persona, Id_Buro_Persona);  ';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_ORD_MATERIALIZA_BTT(8.1):Recoleccion estadisticas PASO_V_COMPORT_CTA_PASIVO'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
END L1;
END;

