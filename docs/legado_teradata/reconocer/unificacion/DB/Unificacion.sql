--<ScriptOptions statementTerminator=";"/>

REPLACE   PROCEDURE REC_DATOS.PRO_Unifi_MOTOR_TMP
	(
		IN	P_Lote			INTEGER
		,IN	P_StartTimeStampPadre	VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDDATOS		VARCHAR(20)
		,IN	P_BDVISTA		VARCHAR(20)
		,IN	P_BDSTAGE		VARCHAR(20)
		,IN	P_BTTPRUVI		VARCHAR(20)
		,OUT	P_ERROR			VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	MOTOR UNIFICACION 
 *				
 *				
 * Fecha:		2017/10/16
 * Realizado por:	Carlos Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		create_PRO_UnificacionR2.sql
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		  Objetivo										Realizado por
 * 
 * 
 * 
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */


BEGIN
	

------------------------------------------------
-- Declaracion de variables-------------
------------------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE Temp CHAR(30);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE V_COD_DW_UBIC_H				VARCHAR	(30);
	DECLARE Cur_Nomenclatura NO SCROLL CURSOR 	FOR the_statement;

L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------  Inicio creacion nuevas direcciones ------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D1 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_D1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*1. Descomposición de los complementos por nomenclatura  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1  AS 
					(SELECT TU.Cod_DW_Persona_Ubic
					,TU.Cod_dw_ubic
					,DC.nomen
					,NOM.Nivel_Complemento 
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  DESC  ROWS UNBOUNDED PRECEDING) AS ID_COM
					,SUM(TO_NUMBER(VALOR))	AS valor
					,COUNT(Cod_DW_Persona_Ubic ) AS cantidad
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  ROWS UNBOUNDED PRECEDING) AS ID_COM1
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D TU
					INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
					ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
					AND tu.cod_dw_ubic=dc.cod_dw_ubic
					LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
					ON NOM.NOMENCLATURA=DC.Nomen
					GROUP BY 1,2,3,4
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Persona_Ubic,nomen,Nivel_Complemento)
					;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D2 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*2. agrupación de nomenclaturas por cod_dw_persona_ubic  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D2
					(COD_DW_PERSONA_UBIC INTEGER NULL
					,NOM_AGRUP  VARCHAR (100) NULL
					,cantidad	 INTEGER NULL
					) ;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.Tmp_Unificacion_E051_D2
					SELECT COD_DW_PERSONA_UBIC
						,XMLAGG(NOMEN ORDER BY ID_COM) AS A_NOMEN
						,SUM(cantidad) AS cantidad
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1
					GROUP BY 1
					;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------CALCULO DE MDIR --> ID para identificar la direción de mayor jerarquía ---------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_Dx' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_Dx';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';

SELECT XMLAGG(CAMPO ORDER BY ORD)
INTO :V_CADENA
FROM 
(SELECT ORD
, ID_COM1 
,CAST(CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_Dx AS ( Select  cod_dw_persona_ubic,cod_dw_ubic
,COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||'
'
WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||'
'
END  AS VARCHAR(16000)) AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP,  SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
) A
UNION ALL 
SELECT ORD
, ID_COM1 
,CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN ' ,ROW_NUMBER() OVER (PARTITION BY cod_dw_ubic  ORDER BY  ID_COM1'||TRIM(ID_COM1)||'
'WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||') as MDIR
FROM rec_stage.Tmp_Unificacion_E051_D1
GROUP BY 1,2) WITH DATA
'
END AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP, 10000+ SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, 10000+idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
) A
) A;


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):MDIR'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	
	
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D3 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D3' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*3. agrupación Nomenclatura - valor cod_dw_persona_ubic e identificación de orden NOMENCLATURA - VALOR  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_D3 AS (
				SELECT TU.cod_dw_ubic
				,TU.Cod_DW_Persona_Ubic
				,TU.complemento
				,DC.Nomenclatura
				,DC.nomen
				,DC.VALOR
				,NOM.Nivel_Complemento
				,TU.Id_Buro_Persona
				,TU.Cod_DW_Tipo_Ubicacion_Dir
				,MAX(NOM.Nivel_Complemento) OVER() MAX_NIVEL
				,MIN(NOM.Nivel_Complemento) OVER() MIN_NIVEL
				,TUN.ID_COM
				,MAX(TUN.ID_COM) OVER() MAX_ID_COM
				,MIN(TUN.ID_COM) OVER() MIN_ID_COM
				,MDIR
				,SUM(1) OVER(PARTITION BY TU.Cod_DW_Persona_Ubic ORDER BY MDIR,ID_COM DESC,TO_NUMBER(DC.VALOR)ROWS UNBOUNDED PRECEDING) AS ORDEN
				,NAGR.NOM_AGRUP 
				,NAGR.CANTIDAD
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D TU
				INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
				ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
				AND tu.cod_dw_ubic=dc.cod_dw_ubic
				LEFT JOIN REC_DATOS.NOMENCLATURA NOM
				ON NOM.NOMENCLATURA=DC.Nomen
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1 TUN 
				ON TUN.Cod_DW_Persona_Ubic = TU.Cod_DW_Persona_Ubic
				AND TUN.nomen  = DC.nomen
				AND TUN.Nivel_Complemento  = NOM.Nivel_Complemento
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_Dx AS MD
				ON TU.Cod_DW_Persona_Ubic=MD.COD_DW_PERSONA_UBIC
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_D2 NAGR
				ON TU.COD_DW_PERSONA_UBIC=NAGR.COD_DW_PERSONA_UBIC
				
				)WITH DATA 
				PRIMARY INDEX(Id_Buro_Persona,Cod_DW_Persona_Ubic,cod_dw_ubic,Cod_DW_Tipo_Ubicacion_Dir)
				;
					';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
		
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D00 -------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D00' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D00';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	
	SET V_CADENA = '';
	
	SELECT CAST(SQL_STRING AS VARCHAR(32000)) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT   XMLAGG(campo ORDER BY numero ) AS SQL_STRING
	FROM (SELECT numero,
	CASE WHEN NUMERO=1 THEN  'CREATE SET TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D00
		( 
			Cod_DW_Persona_Ubic INTEGER
			,Cod_DW_Ubic INTEGER
			,Id_Buro_Persona INTEGER
			,Cod_DW_Tipo_Ubicacion_Dir INTEGER
			,Complemento VARCHAR(100) 
			,cantidad INTEGER
			,NOM_AGRUP VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',C'||TRIM(NUMERO)|| '	VARCHAR(30) '
	ELSE ',C'||TRIM(NUMERO)|| '	VARCHAR(30) ' 
	||'
	);' END AS campo
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3 
	) T4;	 

					
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


	SET V_CADENA='';
	
      SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
      INTO :V_CADENA
      FROM (
      
      SELECT NUMERO,
      CASE WHEN NUMERO=1 THEN  '
	INSERT INTO REC_STAGE.Tmp_Unificacion_E051_D00 
	SELECT COD_DW_PERSONA_UBIC
	,COD_DW_UBIC
	,ID_BURO_PERSONA
	,Cod_DW_Tipo_Ubicacion_Dir
	,COMPLEMENTO
	,CANTIDAD
	,NOM_AGRUP
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO)
	ELSE ',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO) 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_D3 
	GROUP BY 1,2,3,4,5,6,7
	;' END CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3
	;

	
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------------------------------------------------------------
----------------ESTRUCTURA TIPO N --> Convinación de posibles nomenclaturas-valor  -------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D01' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D01';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT NUMERO, CASE WHEN NUMERO=1 THEN  'CREATE SET  TABLE REC_STAGE.Tmp_Unificacion_E051_D01
    	 ( Cod_DW_Persona_Ubic INTEGER
	,Complemento VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',N'||TRIM(NUMERO)|| '	VARCHAR(100)'
	ELSE ',N'||TRIM(NUMERO)|| '	VARCHAR(100)
	);
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3
	
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	
	SELECT NUMERO,
	CASE WHEN NUMERO=1 THEN  'INSERT INTO REC_STAGE.Tmp_Unificacion_E051_D01 
	SELECT COD_DW_PERSONA_UBIC
	,COMPLEMENTO
	,MAX(CASE WHEN ORDEN=1 THEN COMPLEMENTO END) 					 AS N1 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',XMLAGG(CASE WHEN ORDEN>'||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS N'||TRIM(NUMERO+1)
	ELSE '
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	GROUP BY 1,2
	' END AS CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	)T3
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificación de registro de mayor gerarquía ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_P' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_P';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_P AS(
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T3.CANTIDAD
	,T3.NOM_AGRUP
	'||
	OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E051_D3 AS T2
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D00 AS T3
		ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_UBIC,T2.ID_BURO_PERSONA,T2.Cod_DW_Tipo_Ubicacion_Dir ORDER BY T2.MDIR ,T2.ORDEN ))=1
	) WITH DATA
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
	;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva P'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificación de registro de MENOR gerarquía ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_H' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_H';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA='';

SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_H 
	AS (
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T2.CANTIDAD
	,T2.NOM_AGRUP
	,T2.MDIR

	'||OREPLACE(XMLAGG( ',T5.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	 || (SELECT OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','') AS CPN
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D01'
	AND TRIM(COLUMNNAME) LIKE 'N%'
	AND ColumnFormat = 'X(100)')
	
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E051_D3 AS T2
	 LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D01 AS T3
	 	ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	 INNER JOIN REC_STAGE.Tmp_Unificacion_E051_D00 AS T5
	 	ON T2.COD_DW_PERSONA_UBIC=T5.COD_DW_PERSONA_UBIC
	 WHERE NOT EXISTS ( SELECT 1 FROM  REC_STAGE.Tmp_Unificacion_E051_P T4 WHERE T4.COD_DW_PERSONA_UBIC=T2.COD_DW_PERSONA_UBIC)
	 QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_PERSONA_UBIC ORDER BY T2.MDIR ,T2.ORDEN ))=1
	 ) WITH DATA
	 ;
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva H'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con los codigos generados para identificar los complementos que van a crear un nuevo complemento ---------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_codigo' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_codigo';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY ID_ORDEN) AS SQL_STRING
	INTO :V_CADENA
	FROM (
	SELECT SUM(1) OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	CAST(
	CASE WHEN NUMERO=1 THEN  'CREATE TABLE  REC_STAGE.Tmp_Unificacion_E051_codigo AS (
	SELECT T1.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_PADRE
	,T2.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_HIJO
	,T1.COMPLEMENTO AS COMPLEMENTO_PADRE
	,T1.COD_DW_UBIC 			
	,T1.ID_BURO_PERSONA 			
	,T1.Cod_DW_Tipo_Ubicacion_Dir	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',N'||TRIM(NUMERO)|| '	'
	ELSE ',N'||TRIM(NUMERO)|| '	' 
	||'
	
	' END
	
	AS VARCHAR(16000)) AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	--ORDER BY NUMERO
	
	UNION ALL 
	
	SELECT 1000 + SUM(1)  OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	
	CASE WHEN NUMERO=1 THEN  ',CASE WHEN T1.NOM_AGRUP= T2.NOM_AGRUP THEN ''1'' ELSE ''0'' END	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	'|| CASE WHEN T1.C'||TRIM(NUMERO)||' = T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END'
	
	ELSE '|| CASE WHEN T1.C'||TRIM(NUMERO)|| '= T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END AS CODIGO
	,''TRIM(N''||TRIM( CASE WHEN  (POSITION( ''0'' IN CODIGO) -1)<1 THEN 1 ELSE  (POSITION( ''0'' IN CODIGO) -1) END )||'')'' AS Campo_Complemento
	, CAST( NULL AS VARCHAR(300)) AS NUEVA_NOMENCLATURA
	,T2.MDIR  
	' 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_P T1
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_H T2
	ON 		T1.COD_DW_UBIC 			= 	T2.COD_DW_UBIC
	AND 	T1.ID_BURO_PERSONA 			= 	T2.ID_BURO_PERSONA 
	AND 	T1.Cod_DW_Tipo_Ubicacion_Dir	=	T2.Cod_DW_Tipo_Ubicacion_Dir
	) WITH DATA
	UNIQUE PRIMARY INDEX(COD_DW_PERSONA_UBIC_PADRE,COD_DW_PERSONA_UBIC_HIJO)
	;
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	--ORDER BY NUMERO
	)T3;

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva codigos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor Actulización NUEVA_NOMENCLATURA -----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  COD_DW_PERSONA_UBIC_HIJO,CAMPO_COMPLEMENTO
					 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_codigo
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Nomenclatura ;

	CUR2:LOOP
		FETCH Cur_Nomenclatura  INTO  V_COD_DW_UBIC_H, V_SQL ;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

-------------------------- UPDATE COMPLEMENTO -------------------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A 
						FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_codigo  A 
						  SET NUEVA_NOMENCLATURA= '||V_SQL||'
						WHERE COD_DW_PERSONA_UBIC_HIJO ='''||V_COD_DW_UBIC_H|| '''
						';
		SET P_ERROR=V_CADENA;			
	
		CALL DBC.SysExecSQL(:V_CADENA);

	END LOOP CUR2;

CLOSE Cur_Nomenclatura ;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------CREACION DE REGISTRO NUEVO PARA DIRECCION_FISICA Y RELACION PERSONA UBICACION -------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE 
		AND TABLENAME = 'Tmp_Unificacion_E051_E' ;
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_E';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;



		SET V_CADENA='';
		SET V_CADENA='CREATE TABLE rec_stage.Tmp_Unificacion_E051_E AS (
			SELECT COD_DW_PERSONA_UBIC_PADRE||COD_DW_PERSONA_UBIC_HIJO AS Cod_DW_Persona_Ubic 
			,NULL ID
			,T1.Texto_Ubicacion
			, CL.Id_Buro_Persona
			, CL.Cod_DW_Tipo_Ubicacion_Dir
			,COMPLEMENTO_PADRE|| CAST(NUEVA_NOMENCLATURA AS VARCHAR(300) )AS Complemento1
			,NULL Nomenclatura
			,CASE WHEN DF.COD_DW_DIRECCION_FISICA IS NULL 
					THEN ((SELECT ID FROM REC_MTDAT.MAX_ID AS M_ID1 WHERE M_ID1.NOMBRE_TABLA =''DIRECCION_FISICA'') +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
					ELSE DF.COD_DW_DIRECCION_FISICA   END AS COD_DW_DIRECCION_FISICA
			,CASE WHEN RPU.Cod_DW_Persona_Ubic IS NULL 
					THEN ((SELECT id FROM REC_MTDAT.MAX_ID AS M_ID WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' ) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
					ELSE RPU.Cod_DW_Persona_Ubic  END AS ID_PADRE
			,CL.COD_DW_UBIC
			FROM (
			SELECT COD_DW_PERSONA_UBIC_PADRE
			,COMPLEMENTO_PADRE
			,Cod_DW_Ubic
			,Id_Buro_Persona
			,Cod_DW_Tipo_Ubicacion_Dir
			,OREPLACE(XMLAGG( '' ''||TRIM(NUEVA_NOMENCLATURA) ORDER BY MDIR DESC) ,''@#X'','''')AS NUEVA_NOMENCLATURA
			,OREPLACE(XMLAGG( '' ,''||TRIM(COD_DW_PERSONA_UBIC_HIJO) ORDER BY MDIR DESC),''@'','''')  AS COD_DW_PERSONA_UBIC_HIJO
			FROM REC_STAGE.Tmp_Unificacion_E051_codigo 
			GROUP BY 1,2,3,4,5
			)CL
				LEFT JOIN REC_DATOS.DIRECCION_FISICA  DF
						ON 	 DF.Cod_DW_Ubic= CL.Cod_DW_Ubic
						AND  DF.Complemento = Complemento1
			
				LEFT JOIN REC_DATOS.RELACION_PERSONA_UBICACION RPU
				  ON     CL.Id_Buro_Persona  				= RPU.Id_Buro_Persona
				    AND DF.Cod_DW_Ubic  				= RPU.Cod_DW_Ubic
				    AND DF.Cod_DW_Direccion_Fisica  		= RPU.Cod_DW_Direccion_Fisica
				    AND CL.Cod_DW_Tipo_Ubicacion_Dir	= RPU.Cod_DW_Tipo_Ubicacion_Dir		
				 
				 LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D T1
				 ON T1.Cod_DW_Persona_Ubic=CL.COD_DW_PERSONA_UBIC_PADRE
				 
			)WITH DATA;
			';

			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva codigos'
			,V_ERROR);
			
			SET P_ERROR = V_ERROR;
        		
        		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;	
	
	END L1;
    
END;

REPLACE   PROCEDURE REC_DATOS.PRO_Unifi_MOTOR_TMP_V2
	(
		IN	P_Lote			INTEGER
		,IN	P_StartTimeStampPadre	VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDDATOS		VARCHAR(20)
		,IN	P_BDVISTA		VARCHAR(20)
		,IN	P_BDSTAGE		VARCHAR(20)
		,IN	P_BTTPRUVI		VARCHAR(20)
		,OUT	P_ERROR			VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	MOTOR UNIFICACION 
 *				
 *				
 * Fecha:		2017/10/16
 * Realizado por:	Carlos Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		create_PRO_UnificacionR2.sql
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		  Objetivo										Realizado por
 * 
 * 
 * 
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */


BEGIN
	

------------------------------------------------
-- Declaracion de variables-------------
------------------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE Temp CHAR(30);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE V_COD_DW_UBIC_H				VARCHAR	(30);
	DECLARE Cur_Nomenclatura NO SCROLL CURSOR 	FOR the_statement;

L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------  Inicio creacion nuevas direcciones ------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B1 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03_B1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*1. Descomposición de los complementos por nomenclatura  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1  AS 
					(SELECT TU.Cod_DW_Persona_Ubic
					,TU.Cod_dw_ubic
					,DC.nomen
					,NOM.Nivel_Complemento 
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  DESC  ROWS UNBOUNDED PRECEDING) AS ID_COM
					,SUM(TO_NUMBER(VALOR))	AS valor
					,COUNT(Cod_DW_Persona_Ubic ) AS cantidad
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  ROWS UNBOUNDED PRECEDING) AS ID_COM1
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B TU
					INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
					ON TU.complemento1 LIKE ''%''||DC.nomenclatura||''%''
					AND tu.cod_dw_ubic=dc.cod_dw_ubic
					LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
					ON NOM.NOMENCLATURA=DC.Nomen
					GROUP BY 1,2,3,4
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Persona_Ubic,nomen,Nivel_Complemento)
					;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B2 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*2. agrupación de nomenclaturas por cod_dw_persona_ubic  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B2
					(COD_DW_PERSONA_UBIC INTEGER NULL
					,NOM_AGRUP  VARCHAR (100) NULL
					,cantidad	 INTEGER NULL
					) ;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.Tmp_Unificacion_E03_B2
					SELECT COD_DW_PERSONA_UBIC
						,XMLAGG(NOMEN ORDER BY ID_COM) AS A_NOMEN
						,SUM(cantidad) AS cantidad
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1
					GROUP BY 1
					;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------CALCULO DE MDIR --> ID para identificar la direción de mayor jerarquía ---------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_Bx' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_Bx';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';

SELECT XMLAGG(CAMPO ORDER BY ORD)
INTO :V_CADENA
FROM 
(SELECT ORD
, ID_COM1 
,CAST(CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E03_Bx AS ( Select  cod_dw_persona_ubic,cod_dw_ubic
,COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||'
'
WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||'
'
END  AS VARCHAR(16000)) AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP,  SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
) A
UNION ALL 
SELECT ORD
, ID_COM1 
,CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN ' ,ROW_NUMBER() OVER (PARTITION BY cod_dw_ubic  ORDER BY  ID_COM1'||TRIM(ID_COM1)||'
'WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||') as MDIR
FROM rec_stage.Tmp_Unificacion_E03_B1
GROUP BY 1,2) WITH DATA
'
END AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP, 10000+ SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, 10000+idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
) A
) A;


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):MDIR'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	
	
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B3 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B3' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*3. agrupación Nomenclatura - valor cod_dw_persona_ubic e identificación de orden NOMENCLATURA - VALOR  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_B3 AS (
				SELECT TU.cod_dw_ubic
				,TU.Cod_DW_Persona_Ubic
				,TU.complemento1 complemento
				,DC.Nomenclatura
				,DC.nomen
				,DC.VALOR
				,NOM.Nivel_Complemento
				,TU.Id_Buro_Persona
				,TU.Cod_DW_Tipo_Ubicacion_Dir
				,MAX(NOM.Nivel_Complemento) OVER() MAX_NIVEL
				,MIN(NOM.Nivel_Complemento) OVER() MIN_NIVEL
				,TUN.ID_COM
				,MAX(TUN.ID_COM) OVER() MAX_ID_COM
				,MIN(TUN.ID_COM) OVER() MIN_ID_COM
				,MDIR
				,SUM(1) OVER(PARTITION BY TU.Cod_DW_Persona_Ubic ORDER BY MDIR,ID_COM DESC,TO_NUMBER(DC.VALOR)ROWS UNBOUNDED PRECEDING) AS ORDEN
				,NAGR.NOM_AGRUP 
				,NAGR.CANTIDAD
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B TU
				INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
				ON TU.complemento1 LIKE ''%''||DC.nomenclatura||''%''
				AND tu.cod_dw_ubic=dc.cod_dw_ubic
				LEFT JOIN REC_DATOS.NOMENCLATURA NOM
				ON NOM.NOMENCLATURA=DC.Nomen
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1 TUN 
				ON TUN.Cod_DW_Persona_Ubic = TU.Cod_DW_Persona_Ubic
				AND TUN.nomen  = DC.nomen
				AND TUN.Nivel_Complemento  = NOM.Nivel_Complemento
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_Bx AS MD
				ON TU.Cod_DW_Persona_Ubic=MD.COD_DW_PERSONA_UBIC
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_B2 NAGR
				ON TU.COD_DW_PERSONA_UBIC=NAGR.COD_DW_PERSONA_UBIC
				
				)WITH DATA 
				PRIMARY INDEX(Id_Buro_Persona,Cod_DW_Persona_Ubic,cod_dw_ubic,Cod_DW_Tipo_Ubicacion_Dir)
				;
					';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
		
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B00 -------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B00' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B00';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	
	SET V_CADENA = '';
	
	SELECT CAST(SQL_STRING AS VARCHAR(32000)) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT   XMLAGG(campo ORDER BY numero ) AS SQL_STRING
	FROM (SELECT numero,
	CASE WHEN NUMERO=1 THEN  'CREATE SET TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B00
		( 
			Cod_DW_Persona_Ubic INTEGER
			,Cod_DW_Ubic INTEGER
			,Id_Buro_Persona INTEGER
			,Cod_DW_Tipo_Ubicacion_Dir INTEGER
			,Complemento VARCHAR(100) 
			,cantidad INTEGER
			,NOM_AGRUP VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',C'||TRIM(NUMERO)|| '	VARCHAR(30) '
	ELSE ',C'||TRIM(NUMERO)|| '	VARCHAR(30) ' 
	||'
	);' END AS campo
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3 
	) T4;	 

					
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


	SET V_CADENA='';
	
      SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
      INTO :V_CADENA
      FROM (
      
      SELECT NUMERO,
      CASE WHEN NUMERO=1 THEN  '
	INSERT INTO REC_STAGE.Tmp_Unificacion_E03_B00 
	SELECT COD_DW_PERSONA_UBIC
	,COD_DW_UBIC
	,ID_BURO_PERSONA
	,Cod_DW_Tipo_Ubicacion_Dir
	,COMPLEMENTO
	,CANTIDAD
	,NOM_AGRUP
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO)
	ELSE ',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO) 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E03_B3 
	GROUP BY 1,2,3,4,5,6,7
	;' END CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3
	;

	
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------------------------------------------------------------
----------------ESTRUCTURA TIPO N --> Convinación de posibles nomenclaturas-valor  -------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B01' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B01';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT NUMERO, CASE WHEN NUMERO=1 THEN  'CREATE SET  TABLE REC_STAGE.Tmp_Unificacion_E03_B01
    	 ( Cod_DW_Persona_Ubic INTEGER
	,Complemento VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',N'||TRIM(NUMERO)|| '	VARCHAR(100)'
	ELSE ',N'||TRIM(NUMERO)|| '	VARCHAR(100)
	);
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3
	
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	
	SELECT NUMERO,
	CASE WHEN NUMERO=1 THEN  'INSERT INTO REC_STAGE.Tmp_Unificacion_E03_B01 
	SELECT COD_DW_PERSONA_UBIC
	,COMPLEMENTO
	,MAX(CASE WHEN ORDEN=1 THEN COMPLEMENTO END) 					 AS N1 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',XMLAGG(CASE WHEN ORDEN>'||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS N'||TRIM(NUMERO+1)
	ELSE '
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	GROUP BY 1,2
	' END AS CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	)T3
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificación de registro de mayor gerarquía ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_P' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_P';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_P AS(
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T3.CANTIDAD
	,T3.NOM_AGRUP
	'||
	OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E03_B3 AS T2
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B00 AS T3
		ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_UBIC,T2.ID_BURO_PERSONA,T2.Cod_DW_Tipo_Ubicacion_Dir ORDER BY T2.MDIR ,T2.ORDEN ))=1
	) WITH DATA
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
	;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva P'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificación de registro de MENOR gerarquía ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_H' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_H';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA='';

SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_H 
	AS (
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T2.CANTIDAD
	,T2.NOM_AGRUP
	,T2.MDIR

	'||OREPLACE(XMLAGG( ',T5.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	 || (SELECT OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','') AS CPN
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B01'
	AND TRIM(COLUMNNAME) LIKE 'N%'
	AND ColumnFormat = 'X(100)')
	
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E03_B3 AS T2
	 LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B01 AS T3
	 	ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	 INNER JOIN REC_STAGE.Tmp_Unificacion_E03_B00 AS T5
	 	ON T2.COD_DW_PERSONA_UBIC=T5.COD_DW_PERSONA_UBIC
	 WHERE NOT EXISTS ( SELECT 1 FROM  REC_STAGE.Tmp_Unificacion_E051_P T4 WHERE T4.COD_DW_PERSONA_UBIC=T2.COD_DW_PERSONA_UBIC)
	 QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_PERSONA_UBIC ORDER BY T2.MDIR ,T2.ORDEN ))=1
	 ) WITH DATA
	 ;
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva H'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con los codigos generados para identificar los complementos que van a crear un nuevo complemento ---------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E031_codigo' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E031_codigo';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY ID_ORDEN) AS SQL_STRING
	INTO :V_CADENA
	FROM (
	SELECT SUM(1) OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	CAST(
	CASE WHEN NUMERO=1 THEN  'CREATE TABLE  REC_STAGE.Tmp_Unificacion_E031_codigo AS (
	SELECT T1.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_PADRE
	,T2.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_HIJO
	,T1.COMPLEMENTO AS COMPLEMENTO_PADRE
	,T1.COD_DW_UBIC 			
	,T1.ID_BURO_PERSONA 			
	,T1.Cod_DW_Tipo_Ubicacion_Dir	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',N'||TRIM(NUMERO)|| '	'
	ELSE ',N'||TRIM(NUMERO)|| '	' 
	||'
	
	' END
	
	AS VARCHAR(16000)) AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	--ORDER BY NUMERO
	
	UNION ALL 
	
	SELECT 1000 + SUM(1)  OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	
	CASE WHEN NUMERO=1 THEN  ',CASE WHEN T1.NOM_AGRUP= T2.NOM_AGRUP THEN ''1'' ELSE ''0'' END	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	'|| CASE WHEN T1.C'||TRIM(NUMERO)||' = T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END'
	
	ELSE '|| CASE WHEN T1.C'||TRIM(NUMERO)|| '= T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END AS CODIGO
	,''TRIM(N''||TRIM( CASE WHEN  (POSITION( ''0'' IN CODIGO) -1)<1 THEN 1 ELSE  (POSITION( ''0'' IN CODIGO) -1) END )||'')'' AS Campo_Complemento
	, CAST( NULL AS VARCHAR(300)) AS NUEVA_NOMENCLATURA
	,T2.MDIR  
	' 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_P T1
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_H T2
	ON 		T1.COD_DW_UBIC 			= 	T2.COD_DW_UBIC
	AND 	T1.ID_BURO_PERSONA 			= 	T2.ID_BURO_PERSONA 
	AND 	T1.Cod_DW_Tipo_Ubicacion_Dir	=	T2.Cod_DW_Tipo_Ubicacion_Dir
	) WITH DATA
	UNIQUE PRIMARY INDEX(COD_DW_PERSONA_UBIC_PADRE,COD_DW_PERSONA_UBIC_HIJO)
	;
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	--ORDER BY NUMERO
	)T3;

	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva codigos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor Actulización NUEVA_NOMENCLATURA -----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  COD_DW_PERSONA_UBIC_HIJO,CAMPO_COMPLEMENTO
					 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031_codigo
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Nomenclatura ;

	CUR2:LOOP
		FETCH Cur_Nomenclatura  INTO  V_COD_DW_UBIC_H, V_SQL ;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

-------------------------- UPDATE COMPLEMENTO -------------------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A 
						FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031_codigo  A 
						  SET NUEVA_NOMENCLATURA= '||V_SQL||'
						WHERE COD_DW_PERSONA_UBIC_HIJO ='''||V_COD_DW_UBIC_H|| '''
						';
		SET P_ERROR=V_CADENA;			
	
		CALL DBC.SysExecSQL(:V_CADENA);

	END LOOP CUR2;

CLOSE Cur_Nomenclatura ;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------CREACION DE REGISTRO NUEVO PARA DIRECCION_FISICA Y RELACION PERSONA UBICACION -------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE 
		AND TABLENAME = 'Tmp_Unificacion_E051_E' ;
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_E';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;



		SET V_CADENA='';
		SET V_CADENA='CREATE TABLE rec_stage.Tmp_Unificacion_E051_E AS (
			SELECT COD_DW_PERSONA_UBIC_PADRE||COD_DW_PERSONA_UBIC_HIJO AS Cod_DW_Persona_Ubic 
			,NULL ID
			,T1.Texto_Ubicacion
			, CL.Id_Buro_Persona
			, CL.Cod_DW_Tipo_Ubicacion_Dir
			,COMPLEMENTO_PADRE|| CAST(NUEVA_NOMENCLATURA AS VARCHAR(300) )AS Complemento1
			,NULL Nomenclatura
			,CASE WHEN DF.COD_DW_DIRECCION_FISICA IS NULL 
					THEN ((SELECT ID FROM REC_MTDAT.MAX_ID AS M_ID1 WHERE M_ID1.NOMBRE_TABLA =''DIRECCION_FISICA'') +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
					ELSE DF.COD_DW_DIRECCION_FISICA   END AS COD_DW_DIRECCION_FISICA
			,CASE WHEN RPU.Cod_DW_Persona_Ubic IS NULL 
					THEN ((SELECT id FROM REC_MTDAT.MAX_ID AS M_ID WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' ) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
					ELSE RPU.Cod_DW_Persona_Ubic  END AS ID_PADRE
			,CL.COD_DW_UBIC
			FROM (
			SELECT COD_DW_PERSONA_UBIC_PADRE
			,COMPLEMENTO_PADRE
			,Cod_DW_Ubic
			,Id_Buro_Persona
			,Cod_DW_Tipo_Ubicacion_Dir
			,OREPLACE(XMLAGG( '' ''||TRIM(NUEVA_NOMENCLATURA) ORDER BY MDIR DESC) ,''@#X'','''')AS NUEVA_NOMENCLATURA
			,OREPLACE(XMLAGG( '' ,''||TRIM(COD_DW_PERSONA_UBIC_HIJO) ORDER BY MDIR DESC),''@'','''')  AS COD_DW_PERSONA_UBIC_HIJO
			FROM REC_STAGE.Tmp_Unificacion_E031_codigo 
			GROUP BY 1,2,3,4,5
			)CL

				 LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B T1
				 ON T1.Cod_DW_Persona_Ubic=CL.COD_DW_PERSONA_UBIC_PADRE
				
				LEFT JOIN REC_DATOS.DIRECCION_FISICA  DF
						ON 	 DF.Cod_DW_Ubic= CL.Cod_DW_Ubic
						AND  DF.Complemento = Complemento1
			
				LEFT JOIN REC_DATOS.RELACION_PERSONA_UBICACION RPU
				  ON     CL.Id_Buro_Persona  				= RPU.Id_Buro_Persona
				    AND DF.Cod_DW_Ubic  				= RPU.Cod_DW_Ubic
				    AND DF.Cod_DW_Direccion_Fisica  		= RPU.Cod_DW_Direccion_Fisica
				    AND CL.Cod_DW_Tipo_Ubicacion_Dir	= RPU.Cod_DW_Tipo_Ubicacion_Dir		
				 
			)WITH DATA;
			';

			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):Dirección_nueva codigos'
			,V_ERROR);
			
			SET P_ERROR = V_ERROR;
        		
        		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;	
	
	END L1;
    
END;

REPLACE PROCEDURE REC_DATOS.PRO_UnificacionR2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
 
	(IN	P_Lote			INTEGER
	,IN	P_StartTimeStampPadre	VARCHAR(20)
	,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN	P_BDDATOS		VARCHAR(20)
	,IN	P_BDVISTA		VARCHAR(20)
	,IN	P_BDSTAGE		VARCHAR(20)
	,IN	P_BTTPRUVI		VARCHAR(20)
	,OUT	P_ERROR			VARCHAR(32000))
/*################################################################################
 * 
 * Objetivo:		Crea la tabla Tmp_Unificacion en stage partiendo de la vista
 *			V_Insumo_Unificacion_Regla2, aplicando los 6 escenarios para la
 *			regla 2 de unificacion de complementos
 * Fecha:		2017/10/16
 * Realizado por:	Carlos Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		create_PRO_UnificacionR2.sql
 * 
 * 
 * 
 * BITACORA
 * ------------------------------------------------------------------------------------------------------------------------------------------------
 * Fecha		  	Objetivo								  Realizado por
 * 2018-02-05		#1 Ajuste creaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n direcciones nuevas 	  Carlos Castillo
 * 2018-06-19       #Ajuste al campo complemento mediante     Fernando Garrido
 *                   la funcion SetComplement.
 * 2018-08-13		#2 Ajuste tipo dato BIGINT				  CARLOS CASTILLO
 * 2018-09-07		#3 Ajuste Duplicados tablas C 			  CARLOS CASTILLO
 * 2018-09-10 		#4 Ajuste Diccionario ID_BURO_PERSONA	  CARLOS CASTILLO
 * 2018-09-10 		#5 Ajuste escenario 6 subcaso 2			  CARLOS CASTILLO
 * 2018-10-23 		#6 Ajuste DIRECCION_FISICA Duplicados	  CARLOS CASTILLO
 * 2022-11-11 		#7 Se quitÃ¸Â¡n saltos de lÃ¸Â­nea que generaban error	  Omar Delgado
 * 2025-07-30 		#8 Se hace la Restriccion a 15 Columnas para JOHN BUENO
 						la tabla Tmp_Unificacion_E03_B00 y 
						evitar el Error
 * -------------------------------------------------------------------------------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */


BEGIN
	

------------------------------------------------
-- Declaracion de variables-------------
------------------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE Temp CHAR(30);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE V_COD_DW_UBIC_H				VARCHAR(30);
	DECLARE Cur_Nomenclatura NO SCROLL CURSOR 	FOR the_statement;


L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------  Inicio unificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n Escenario 1 ---------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla R2_Vstg_Unificacion-------
----------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'R2_Vstg_Unificacion' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.R2_Vstg_Unificacion';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_0E1---------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_0E1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_0E1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

    /*Registros Padres e Hijos para escenario 1 */
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_0E1 AS(  
						SELECT COD_DW_PERSONA_UBIC,ID_PADRE FROM
						(
						SELECT B.COD_DW_PERSONA_UBIC
						 , A.COD_DW_PERSONA_UBIC AS ID_PADRE
						 ,  A.TEXTO_UBICACION
						 , A.COMPLEMENTO AS COMPLEMENTO1
						 , B.COMPLEMENTO AS COMPLEMENTO2
						 ,CASE WHEN A.COMPLEMENTO IS NULL THEN 1 ELSE 0 END  AS A_NULL
						 ,CASE WHEN B.COMPLEMENTO IS NULL THEN 1 ELSE 0 END  AS B_NULL
						FROM '||P_BDSTAGE||'.V_Insumo_Unificacion_Regla2 A
							 JOIN '||P_BDSTAGE||'.V_Insumo_Unificacion_Regla2 B
								ON  A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
								   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
								   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
								   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
								   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
						WHERE A.COMPLEMENTO IS NOT NULL
								AND B.COMPLEMENTO IS NULL 
						UNION ALL
						SELECT A.COD_DW_PERSONA_UBIC
						  , B.COD_DW_PERSONA_UBIC AS ID_PADRE
						  ,  A.TEXTO_UBICACION
						  , A.COMPLEMENTO AS COMPLEMENTO1
						  , B.COMPLEMENTO AS COMPLEMENTO2
						  ,CASE WHEN A.COMPLEMENTO IS NULL THEN 1 ELSE 0 END  AS A_NULL
						  ,CASE WHEN B.COMPLEMENTO IS NULL THEN 1 ELSE 0 END  AS B_NULL
						FROM '||P_BDSTAGE||'.V_Insumo_Unificacion_Regla2 A
							 JOIN '||P_BDSTAGE||'.V_Insumo_Unificacion_Regla2 B
								ON  A.Id_Buro_Persona		      	      		=    B.Id_Buro_Persona
								   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
								   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
								   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
								   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
						WHERE B.COMPLEMENTO IS NOT NULL
								AND A.COMPLEMENTO IS NULL 
						) AS A
						QUALIFY (ROW_NUMBER() OVER(PARTITION BY COD_DW_PERSONA_UBIC ORDER BY  ID_PADRE DESC)) =1

						) WITH DATA 
						UNIQUE PRIMARY INDEX (COD_DW_PERSONA_UBIC);';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 (0):.Crear y carga la tabla Tmp_Unificacion_0E1'
									,V_ERROR);			
	SET P_ERROR = V_ERROR;        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca y borra si existe la tabla Tmp_Unificacion_E1
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													
-----------------------------
-- Se crea y carga la tabla Tmp_Unificacion_E1
-- aplicando algoritmo del escenario 1
-----------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE ' || P_BDSTAGE ||'.Tmp_Unificacion_E1
					 AS (select a.Cod_DW_Persona_Ubic
								,b.ID_PADRE
								,Id_Buro_Persona
								,Cod_DW_Tipo_Ubicacion_Dir
								,Cod_DW_Ubic
								,Texto_Ubicacion
								,Cod_DW_Direccion_Fisica
								,Complemento
								,COD_DW_Doc_Ident
								,Cod_Tipo_Ident_Fte
								,Cod_DW_Municipio
								,Numero_entidades_que_Reportan
								,Fecha_Relacion_Persona_Ubicaci
								/*Escenario 1*/
								,CASE WHEN b.Cod_DW_Persona_Ubic IS NOT NULL
										THEN ''S''
									  ELSE ''N''
								 END Ind_Unificacion      
								 ,ROW_NUMBER() OVER(PARTITION BY Id_Buro_Persona, Cod_DW_Ubic, Ind_Unificacion,a.Cod_DW_Tipo_Ubicacion_Dir
														ORDER BY Complemento) ROW_U
								 ,CASE WHEN b.Cod_DW_Persona_Ubic IS NOT NULL THEN CAST(''H1'' AS VARCHAR(100)) END AS N_ID						 
					FROM '||P_BDSTAGE||'.V_Insumo_Unificacion_Regla2 a
						LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_0E1 B
						 ON a.Cod_DW_Persona_Ubic=b.Cod_DW_Persona_Ubic

					) WITH DATA
					PRIMARY INDEX (Id_Buro_Persona, Cod_DW_Ubic, ROW_U, Ind_Unificacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Texto_Ubicacion)';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (1):. Crear y carga la tabla Tmp_Unificacion_E1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
--------------------
-- Actualiza estadisticas a Tmp_Unificacion_E1
--------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT INDEX (Id_Buro_Persona, Cod_DW_Ubic, ROW_U, Ind_Unificacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Texto_Ubicacion)
				ON ' || P_BDSTAGE ||'.Tmp_Unificacion_E1';
	
	--------------------
	-- Ejecuta cadena
	--------------------
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (2):. Actualizar estadisticas a la tabla Tmp_Unificacion_E1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------  Fin unificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n Escenario 1 ---------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------  INICIO unificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n Escenario 2 ---------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
	
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_0E2
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_0E2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_0E2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

/*Registros Padres e Hijos para escenario 2 */
	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_0E2 AS 
(
SELECT COD_DW_PERSONA_UBIC, ID_PADRE FROM (
SELECT B.COD_DW_PERSONA_UBIC
, A.COD_DW_PERSONA_UBIC  AS ID_PADRE
,A.TEXTO_UBICACION
, A.COMPLEMENTO AS COMPLEMENTO1
, B.COMPLEMENTO AS COMPLEMENTO2
,CASE WHEN A.COMPLEMENTO LIKE  ''%''||B.COMPLEMENTO||''%'' THEN 1 ELSE 0 END  AS B_CONTENIDO_A,
CASE WHEN B.COMPLEMENTO LIKE  ''%''||A.COMPLEMENTO||''%'' THEN 1 ELSE 0 END  AS A_CONTENIDO_B
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E1 A
	 JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E1 B
		ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=   B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=   B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=   B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=   B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<> B.Cod_DW_Persona_Ubic 
		 
WHERE  B_CONTENIDO_A = 1 
AND A.Ind_Unificacion=''N''
 GROUP BY 1,2,3,4,5


UNION ALL


SELECT A.COD_DW_PERSONA_UBIC
, B.COD_DW_PERSONA_UBIC  AS ID_PADRE
,  A.TEXTO_UBICACION
, A.COMPLEMENTO AS COMPLEMENTO1
, B.COMPLEMENTO AS COMPLEMENTO2,
			CASE WHEN A.COMPLEMENTO LIKE  ''%''||B.COMPLEMENTO||''%'' THEN 1 ELSE 0 END  AS B_CONTENIDO_A,
			CASE WHEN B.COMPLEMENTO LIKE  ''%''||A.COMPLEMENTO||''%'' THEN 1 ELSE 0 END  AS A_CONTENIDO_B
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E1 A
	 JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E1 B
		ON A.COMPLEMENTO <> B.COMPLEMENTO
		AND A.Id_Buro_Persona		      	      	=   B.Id_Buro_Persona
		AND A.Texto_Ubicacion		      		=   B.Texto_Ubicacion
		 AND A.Cod_DW_Tipo_Ubicacion_Dir   =   B.Cod_DW_Tipo_Ubicacion_Dir
		 AND A.Cod_DW_Municipio		      	=   B.Cod_DW_Municipio
		 AND A.Cod_DW_Persona_Ubic 		<> B.Cod_DW_Persona_Ubic 
WHERE  A_CONTENIDO_B = 1 
 AND A.Ind_Unificacion=''N''
 GROUP BY 1,2,3,4,5
 ) A  QUALIFY (ROW_NUMBER() OVER(PARTITION BY COD_DW_PERSONA_UBIC ORDER BY  COD_DW_PERSONA_UBIC DESC)) =1
) WITH DATA 
UNIQUE PRIMARY INDEX (COD_DW_PERSONA_UBIC);
'

;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (02):.Crear y carga la tabla Tmp_Unificacion_0E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													
-----------------------------
-- Se crea y carga la tabla Tmp_Unificacion_E2
-- aplicando algoritmo del escenario 2
-----------------------------

	SET V_CADENA = '';
	SET V_CADENA = '
CREATE MULTISET TABLE ' || P_BDSTAGE ||'.Tmp_Unificacion_E2
 AS (
 
 select a.Cod_DW_Persona_Ubic
	,CASE WHEN A.ID_PADRE IS NOT NULL THEN A.ID_PADRE ELSE b.ID_PADRE END AS ID_PADRE
	,Id_Buro_Persona
	,Cod_DW_Tipo_Ubicacion_Dir
	,Cod_DW_Ubic
	,Texto_Ubicacion
	,Cod_DW_Direccion_Fisica
	,Complemento
	,COD_DW_Doc_Ident
	,Cod_Tipo_Ident_Fte

	,Cod_DW_Municipio
	
	,Numero_entidades_que_Reportan
	,Fecha_Relacion_Persona_Ubicaci
	/*Escenario 1*/
	,CASE WHEN a.Ind_Unificacion = ''S'' THEN a.Ind_Unificacion
	          WHEN b.Cod_DW_Persona_Ubic IS NOT NULL
			THEN ''S''
	      ELSE ''N''
	 END Ind_Unificacion      
	 ,ROW_NUMBER() OVER(PARTITION BY Id_Buro_Persona, Cod_DW_Ubic, Ind_Unificacion,a.Cod_DW_Tipo_Ubicacion_Dir
			 				ORDER BY Complemento) ROW_U
							
	 ,CASE WHEN A.N_ID IS NOT NULL THEN A.N_ID 
		   WHEN b.Cod_DW_Persona_Ubic IS NOT NULL THEN CAST(''K2'' AS VARCHAR(100)) 
		   END AS N_ID


	
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E1 a
	LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_0E2 B
	 ON a.Cod_DW_Persona_Ubic=b.Cod_DW_Persona_Ubic

) WITH DATA
PRIMARY INDEX(Cod_DW_Persona_Ubic)
INDEX (Id_Buro_Persona, Cod_DW_Ubic, ROW_U, Ind_Unificacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Texto_Ubicacion)';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (1):. Crear y carga la tabla Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
--------------------
-- Actualiza estadisticas a Tmp_Unificacion_E2
--------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT COLUMN (Id_Buro_Persona, Cod_DW_Ubic, ROW_U, Ind_Unificacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Texto_Ubicacion)
				ON ' || P_BDSTAGE ||'.Tmp_Unificacion_E2';
	
	--------------------
	-- Ejecuta cadena
	--------------------
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (2):. Actualizar estadisticas a la tabla Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-------------------------------------------------------------------------------------------------------------------------------------------
-- FIN ESCENARIO 2 ----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------------------------
-- INICIO ESCENARIO 3 ----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

-- Escenario 3 caso 1. sin nit ---
-- Se extraen los datos que cumplen las condiciones para ser unificados


SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03 AS
(SELECT A.* FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2  A
LEFT JOIN '||P_BTTPRUVI||'.V_Tipo_Identificacion TI
	ON TI.Cod_Tipo_Ident_Fte = a.Cod_Tipo_Ident_Fte
WHERE COALESCE(Nombre_Tipo_Ident,'''')  NOT LIKE ''%Nit%''
AND A.Ind_Unificacion=''N''
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona
,Texto_Ubicacion
,Cod_DW_Tipo_Ubicacion_Dir
,Cod_DW_Municipio
,Cod_DW_Persona_Ubic)
INDEX(COMPLEMENTO)
;'

;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E03'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	





---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


---- se aplican las reglas de negocio para identificar los registros que van a ser unificados
----asignando a cada registro un peso para identificar los registros padre campo ID

SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_A AS
(   SELECT U1.*
				  ,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Nomenclatura,ID) AS COUNT_EMPATE /*#2*/
				  ,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic,Nomenclatura) AS IDMAX
				  ,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 
				  	     WHEN  COUNT_EMPATE=1 THEN 1
				  ELSE 0 END AS EMPATE
				FROM
(
SELECT  A.COD_DW_PERSONA_UBIC
,(CAST((COALESCE(A.Fecha_Relacion_Persona_Ubicaci,CAST(''1900/01/01'' AS DATE))) AS INTEGER)) + (COALESCE(a.Numero_entidades_que_Reportan,0)+10000000)  AS ID
,A.TEXTO_UBICACION
,A.Fecha_Relacion_Persona_Ubicaci
,NMC1.Nomenclatura
,A.COMPLEMENTO AS COMPLEMENTO1
,B.COMPLEMENTO AS COMPLEMENTO2
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio,NMC1.Nomenclatura  ORDER BY ID ) AS ORDEN
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03 A
	JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03 B ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona = B.Id_Buro_Persona
		   AND A.Texto_Ubicacion = B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir = B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio = B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic <> B.Cod_DW_Persona_Ubic 
	INNER JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1 ON A.COMPLEMENTO LIKE  ''''||NMC1.Nomenclatura||''%''
	INNER JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2 ON B.COMPLEMENTO LIKE  ''''||NMC2.Nomenclatura||''%''
	WHERE NMC1.Nomenclatura=NMC2.nomenclatura
QUALIFY (ROW_NUMBER() OVER(PARTITION BY A.COD_DW_PERSONA_UBIC ORDER BY A.ROW_U ))=1

)AS U1
			 --	QUALIFY EMPATE=1


)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic )
;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E03_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	


------ Registros unificados regla 3 escenario 1 sin Nit ------------
--------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_E1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_E1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03_E1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;



SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_E1
AS(
	SELECT B.COD_DW_PERSONA_UBIC,A.COD_DW_PERSONA_UBIC AS ID_PADRE
	FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_A A
	   INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_A B ON A.Id_Buro_Persona = B.Id_Buro_Persona				 
				AND A.Texto_Ubicacion =  B.Texto_Ubicacion			         
				AND A.Cod_DW_Tipo_Ubicacion_Dir =  B.Cod_DW_Tipo_Ubicacion_Dir	     
				AND A.Cod_DW_Municipio =  B.Cod_DW_Municipio			    
				AND A.Nomenclatura = B.Nomenclatura
				AND A.Cod_DW_Persona_Ubic <> B.Cod_DW_Persona_Ubic			 
        		AND  A.ID > B.ID
	QUALIFY (MAX(A.ORDEN ) OVER(PARTITION BY A.Id_Buro_Persona,A.Texto_Ubicacion,A.Cod_DW_Tipo_Ubicacion_Dir,A.Cod_DW_Municipio,A.Nomenclatura) )=A.ORDEN 
)WITH DATA;
'

;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E03_E1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



-------------------------------------------------------------------------
-- Calulo Escenario 3 caso 2. NIT
--------------------------------------------------------------------------
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E031
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E031' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E031';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';
	SET V_CADENA ='CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E031 AS
(SELECT A.* FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2  A
LEFT JOIN '||P_BTTPRUVI||'.V_Tipo_Identificacion TI
	ON TI.Cod_Tipo_Ident_Fte = a.Cod_Tipo_Ident_Fte
WHERE COALESCE(Nombre_Tipo_Ident,'''')  LIKE ''%Nit%''
AND A.Ind_Unificacion=''N''
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona
,Texto_Ubicacion
,Cod_DW_Tipo_Ubicacion_Dir
,Cod_DW_Municipio
,Cod_DW_Persona_Ubic )
INDEX(COMPLEMENTO)
;'
 
;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E031'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03_B';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_B AS
(
	SELECT U1.*
	,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Nomenclatura,ID) AS COUNT_EMPATE /*#2*/
	,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic,Nomenclatura) AS IDMAX
	,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 WHEN  COUNT_EMPATE=1 THEN 1 ELSE 0 END AS EMPATE
	FROM
	(
	SELECT  A.COD_DW_PERSONA_UBIC
	,(CAST((COALESCE(A.Fecha_Relacion_Persona_Ubicaci,CAST(''1900/01/01'' AS DATE))) AS INTEGER)) + (COALESCE(a.Numero_entidades_que_Reportan,0)+10000000)  AS ID
	,  A.TEXTO_UBICACION
	, A.Fecha_Relacion_Persona_Ubicaci
	, NMC1.Nomenclatura
	, A.COMPLEMENTO AS COMPLEMENTO
	, B.COMPLEMENTO AS COMPLEMENTO2
	,A.Numero_entidades_que_Reportan 		
	,A.Id_Buro_Persona
	,A.Cod_DW_Tipo_Ubicacion_Dir
	,A.Cod_DW_Municipio
	,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio,NMC1.Nomenclatura  ORDER BY ID ) AS ORDEN
	,a.Cod_DW_Ubic						
	FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031 A
		JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E031 B
			ON A.COMPLEMENTO <> B.COMPLEMENTO
			AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
			AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
			AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
			AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
			AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		INNER JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1 ON A.COMPLEMENTO LIKE  ''''||NMC1.Nomenclatura||''%''
		INNER JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2 ON B.COMPLEMENTO LIKE  ''''||NMC2.Nomenclatura||''%''
	WHERE NMC1.Nomenclatura=NMC2.nomenclatura
	QUALIFY (ROW_NUMBER() OVER(PARTITION BY A.COD_DW_PERSONA_UBIC ORDER BY A.ROW_U ))=1
	)AS U1
	--	QUALIFY EMPATE=1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic ,Cod_DW_Ubic)
;'
;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E03_B'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




---SE DEBE CREAR UN NUEVO COMPLEMENTO EN LA TABLA DIRECCION_FISICA
--direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n GEO y creando su correspondiente relaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n con la persona en la tabla RELACION_PERSONA_UBICACION
--, estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â© nuevo registro corresponderÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡ a la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada y las dos direcciones evaluadas deben ser unidas a esta Ã¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Âºltima.

------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------- #1 Inicio creacion nuevas direcciones ------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B1 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E03_B1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*1. DescomposiciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de los complementos por nomenclatura  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1  AS 
					(SELECT TU.Cod_DW_Persona_Ubic
					,TU.Cod_dw_ubic
					,DC.nomen
					,NOM.Nivel_Complemento 
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  DESC  ROWS UNBOUNDED PRECEDING) AS ID_COM
					,SUM(TO_NUMBER(VALOR))	AS valor
					,COUNT(Cod_DW_Persona_Ubic ) AS cantidad
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  ROWS UNBOUNDED PRECEDING) AS ID_COM1
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B TU
					INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
					ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
					AND tu.cod_dw_ubic=dc.cod_dw_ubic
					AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
					LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
					ON NOM.NOMENCLATURA=DC.Nomen
					GROUP BY 1,2,3,4
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Persona_Ubic,nomen,Nivel_Complemento)
					;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B2 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*2. agrupaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de nomenclaturas por cod_dw_persona_ubic  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B2
					(COD_DW_PERSONA_UBIC BIGINT /*#2*/ NULL
					,NOM_AGRUP  VARCHAR (100) NULL
					,cantidad	 INTEGER NULL
					) ;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.Tmp_Unificacion_E03_B2
					SELECT COD_DW_PERSONA_UBIC
						,XMLAGG(NOMEN ORDER BY ID_COM) AS A_NOMEN
						,SUM(cantidad) AS cantidad
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1
					GROUP BY 1
					;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------CALCULO DE MDIR --> ID para identificar la direciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de mayor jerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_Bx' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_Bx';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';

SELECT XMLAGG(CAMPO ORDER BY ORD)
INTO :V_CADENA
FROM 
(SELECT ORD
, ID_COM1 
,CAST(CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E03_Bx AS ( Select  cod_dw_persona_ubic,cod_dw_ubic
,COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||'
'
WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||'
'
END  AS VARCHAR(16000)) AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP,  SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
) A
UNION ALL 
SELECT ORD
, ID_COM1 
,CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN ' ,ROW_NUMBER() OVER (PARTITION BY cod_dw_ubic  ORDER BY  ID_COM1'||TRIM(ID_COM1)||'
'WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||') as MDIR
FROM rec_stage.Tmp_Unificacion_E03_B1
GROUP BY 1,2) WITH DATA
'
END AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP, 10000+ SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, 10000+idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E03_B1 GROUP BY 1
) A
) A;




        IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E03_Bx  
     (
      Cod_DW_Persona_Ubic BIGINT /*#2*/,
      Cod_DW_Ubic BIGINT /*#2*/,
      ID_COM11 INTEGER,
      ID_COM12 INTEGER,
      ID_COM13 INTEGER,
      val1 NUMBER,
      val2 NUMBER,
      val3 NUMBER,
      MDIR INTEGER)
      PRIMARY INDEX ( Cod_DW_Persona_Ubic );';
		
	END IF;		


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):MDIR'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B3 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B3' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*3. agrupaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n Nomenclatura - valor cod_dw_persona_ubic e identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de orden NOMENCLATURA - VALOR  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_B3 AS (
				SELECT TU.cod_dw_ubic
				,TU.Cod_DW_Persona_Ubic
				,TU.complemento complemento
				,DC.Nomenclatura
				,DC.nomen
				,DC.VALOR
				,NOM.Nivel_Complemento
				,TU.Id_Buro_Persona
				,TU.Cod_DW_Tipo_Ubicacion_Dir
				,MAX(NOM.Nivel_Complemento) OVER() MAX_NIVEL
				,MIN(NOM.Nivel_Complemento) OVER() MIN_NIVEL
				,TUN.ID_COM
				,MAX(TUN.ID_COM) OVER() MAX_ID_COM
				,MIN(TUN.ID_COM) OVER() MIN_ID_COM
				,MDIR
				,SUM(1) OVER(PARTITION BY TU.Cod_DW_Persona_Ubic ORDER BY MDIR,ID_COM DESC,TO_NUMBER(DC.VALOR)ROWS UNBOUNDED PRECEDING) AS ORDEN
				,NAGR.NOM_AGRUP 
				,NAGR.CANTIDAD
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_B TU
				INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
				ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
				AND tu.cod_dw_ubic=dc.cod_dw_ubic
				AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
				LEFT JOIN REC_DATOS.NOMENCLATURA NOM
				ON NOM.NOMENCLATURA=DC.Nomen
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_B1 TUN 
				ON TUN.Cod_DW_Persona_Ubic = TU.Cod_DW_Persona_Ubic
				AND TUN.nomen  = DC.nomen
				AND TUN.Nivel_Complemento  = NOM.Nivel_Complemento
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_Bx AS MD
				ON TU.Cod_DW_Persona_Ubic=MD.COD_DW_PERSONA_UBIC
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_B2 NAGR
				ON TU.COD_DW_PERSONA_UBIC=NAGR.COD_DW_PERSONA_UBIC
				
				)WITH DATA 
				PRIMARY INDEX(Id_Buro_Persona,Cod_DW_Persona_Ubic,cod_dw_ubic,Cod_DW_Tipo_Ubicacion_Dir)
				;
					';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
		
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03_B00 -------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B00' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B00';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	
	SET V_CADENA = '';
	
	SELECT CAST(SQL_STRING AS VARCHAR(32000)) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT   XMLAGG(campo ORDER BY numero ) AS SQL_STRING
	FROM (SELECT numero,
	CASE WHEN NUMERO=1 THEN  'CREATE SET TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B00
		( 
			Cod_DW_Persona_Ubic BIGINT /*#2*/
			,Cod_DW_Ubic BIGINT /*#2*/
			,Id_Buro_Persona INTEGER
			,Cod_DW_Tipo_Ubicacion_Dir INTEGER
			,Complemento VARCHAR(100) 
			,cantidad INTEGER
			,NOM_AGRUP VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',C'||TRIM(NUMERO)|| '	VARCHAR(30) '
	ELSE ',C'||TRIM(NUMERO)|| '	VARCHAR(30) ' 
	||'
	);' END AS campo
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3 
	) T4;	 



        IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E03_B00  
     (
      Cod_DW_Persona_Ubic BIGINT /*#2*/,
      Cod_DW_Ubic BIGINT /*#2*/,
      Id_Buro_Persona INTEGER,
      Cod_DW_Tipo_Ubicacion_Dir INTEGER,
      Complemento VARCHAR(100)  ,
      cantidad INTEGER,
      NOM_AGRUP VARCHAR(100)  ,
      C1 VARCHAR(30)  ,
      C2 VARCHAR(30)  ,
      C3 VARCHAR(30)  ,
      C4 VARCHAR(30)  )
PRIMARY INDEX ( Cod_DW_Persona_Ubic );';
		
	END IF;		
					
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


	SET V_CADENA='';
	
      SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
 
      INTO :V_CADENA
      FROM (
      
      SELECT NUMERO,
      CASE WHEN NUMERO=1 THEN  '
	INSERT INTO REC_STAGE.Tmp_Unificacion_E03_B00 
	SELECT COD_DW_PERSONA_UBIC
	,COD_DW_UBIC
	,ID_BURO_PERSONA
	,Cod_DW_Tipo_Ubicacion_Dir
	,COMPLEMENTO
	,CANTIDAD
	,NOM_AGRUP
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO)
	ELSE ',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO)||'
	FROM REC_STAGE.Tmp_Unificacion_E03_B3 
	GROUP BY 1,2,3,4,5,6,7
	;' END CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3;

	
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------------------------------------------------------------
----------------ESTRUCTURA TIPO N --> ConvinaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de posibles nomenclaturas-valor  -------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E03_B01' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_B01';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT NUMERO, CASE WHEN NUMERO=1 THEN  'CREATE SET  TABLE REC_STAGE.Tmp_Unificacion_E03_B01
    	 ( Cod_DW_Persona_Ubic BIGINT /*#2*/
	,Complemento VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',N'||TRIM(NUMERO)|| '	VARCHAR(100)'
	ELSE ',N'||TRIM(NUMERO)|| '	VARCHAR(100)
	);
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	) T3
	
	;
	
	
	 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E03_B01  
     (
      Cod_DW_Persona_Ubic BIGINT /*#2*/,
      Complemento VARCHAR(100)  ,
      N1 VARCHAR(100)  ,
      N2 VARCHAR(100)  ,
      N3 VARCHAR(100)  ,
      N4 VARCHAR(100)  )
      PRIMARY INDEX ( Cod_DW_Persona_Ubic );';
		
	END IF;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	
	SELECT NUMERO,
	CASE WHEN NUMERO=1 THEN  'INSERT INTO REC_STAGE.Tmp_Unificacion_E03_B01 
	SELECT COD_DW_PERSONA_UBIC
	,COMPLEMENTO
	,MAX(CASE WHEN ORDEN=1 THEN COMPLEMENTO END) 					 AS N1 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',XMLAGG(CASE WHEN ORDEN>'||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS N'||TRIM(NUMERO+1)
	ELSE '
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	GROUP BY 1,2
	' END AS CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	)T3
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registro de mayor gerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON REC_STAGE.Tmp_Unificacion_E051_D3;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D3',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_UBIC ,COD_DW_PERSONA_UBIC,ID_BURO_PERSONA ,COD_DW_TIPO_UBICACION_DIR) ON REC_STAGE.Tmp_Unificacion_E051_D3;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D3',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON REC_STAGE.Tmp_Unificacion_E051_D00;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D00',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_P' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_P';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_P AS(
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T3.CANTIDAD
	,T3.NOM_AGRUP
	'||
	OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	||'
	FROM REC_STAGE.Tmp_Unificacion_E03_B3 AS T2
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B00 AS T3
		ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_UBIC,T2.ID_BURO_PERSONA,T2.Cod_DW_Tipo_Ubicacion_Dir ORDER BY T2.MDIR ,T2.ORDEN ))=1
	) WITH DATA
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
	;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva P'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registro de MENOR gerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_H' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_H';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA='';

SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_H 
	AS (
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T2.CANTIDAD
	,T2.NOM_AGRUP
	,T2.MDIR

	'||OREPLACE(XMLAGG( ',T5.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	 || (SELECT OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','') AS CPN
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B01'
	AND TRIM(COLUMNNAME) LIKE 'N%'
	AND ColumnFormat = 'X(100)')
	
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E03_B3 AS T2
	 LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B01 AS T3
	 	ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	 INNER JOIN REC_STAGE.Tmp_Unificacion_E03_B00 AS T5
	 	ON T2.COD_DW_PERSONA_UBIC=T5.COD_DW_PERSONA_UBIC
	 WHERE NOT EXISTS ( SELECT 1 FROM  REC_STAGE.Tmp_Unificacion_E051_P T4 WHERE T4.COD_DW_PERSONA_UBIC=T2.COD_DW_PERSONA_UBIC)
	 QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_PERSONA_UBIC ORDER BY T2.MDIR ,T2.ORDEN ))=1
	 ) WITH DATA
	 ;
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E03_B00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva H'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con los codigos generados para identificar los complementos que van a crear un nuevo complemento ---------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E031_codigo' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E031_codigo';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY ID_ORDEN) AS SQL_STRING
	INTO :V_CADENA
	FROM (
	SELECT SUM(1) OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	CAST(
	CASE WHEN NUMERO=1 THEN  'CREATE TABLE  REC_STAGE.Tmp_Unificacion_E031_codigo AS (
	SELECT T1.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_PADRE
	,T2.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_HIJO
	,T1.COMPLEMENTO AS COMPLEMENTO_PADRE
	,T1.COD_DW_UBIC 			
	,T1.ID_BURO_PERSONA 			
	,T1.Cod_DW_Tipo_Ubicacion_Dir	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	',N'||TRIM(NUMERO)|| '	'
	ELSE ',N'||TRIM(NUMERO)|| '	' 
	||'
	
	' END
	
	AS VARCHAR(16000)) AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	--ORDER BY NUMERO
	
	UNION ALL 
	
	SELECT 1000 + SUM(1)  OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	
	CASE WHEN NUMERO=1 THEN  ',CASE WHEN T1.NOM_AGRUP= T2.NOM_AGRUP THEN ''1'' ELSE ''0'' END	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3) THEN 
	'|| CASE WHEN T1.C'||TRIM(NUMERO)||' = T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END'
	
	ELSE '|| CASE WHEN T1.C'||TRIM(NUMERO)|| '= T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END AS CODIGO
	,''TRIM(N''||TRIM( CASE WHEN  (POSITION( ''0'' IN CODIGO) -1)<1 THEN 1 ELSE  (POSITION( ''0'' IN CODIGO) -1) END )||'')'' AS Campo_Complemento
	, CAST( NULL AS VARCHAR(300)) AS NUEVA_NOMENCLATURA
	,T2.MDIR  
	' 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_P T1
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_H T2
	ON 		T1.COD_DW_UBIC 			= 	T2.COD_DW_UBIC
	AND 	T1.ID_BURO_PERSONA 			= 	T2.ID_BURO_PERSONA 
	AND 	T1.Cod_DW_Tipo_Ubicacion_Dir	=	T2.Cod_DW_Tipo_Ubicacion_Dir
	) WITH DATA
	UNIQUE PRIMARY INDEX(COD_DW_PERSONA_UBIC_PADRE,COD_DW_PERSONA_UBIC_HIJO)
	;
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E03_B3
	QUALIFY (NUMERO) <= (SELECT CASE WHEN MAX(CANTIDAD)>15 THEN 15 ELSE MAX(CANTIDAD) END FROM REC_STAGE.Tmp_Unificacion_E03_B3)
	) T2
	--ORDER BY NUMERO
	)T3;

	
	 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E031_codigo  
     (
      COD_DW_PERSONA_UBIC_PADRE BIGINT /*#2*/,
      COD_DW_PERSONA_UBIC_HIJO BIGINT /*#2*/,
      COMPLEMENTO_PADRE VARCHAR(100)  ,
      Cod_DW_Ubic BIGINT, /*#2*/
      Id_Buro_Persona INTEGER,
      Cod_DW_Tipo_Ubicacion_Dir INTEGER,
      N1 VARCHAR(100)  ,
      N2 VARCHAR(100)  ,
      N3 VARCHAR(100)  ,
      N4 VARCHAR(100)  ,
      CODIGO VARCHAR(5) CHARACTER SET UNICODE NOT CASESPECIFIC,
      Campo_Complemento VARCHAR(18)  ,
      NUEVA_NOMENCLATURA VARCHAR(300)  ,
      MDIR INTEGER)
UNIQUE PRIMARY INDEX ( COD_DW_PERSONA_UBIC_PADRE ,COD_DW_PERSONA_UBIC_HIJO );';
		
	END IF;
	
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva codigos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n NUEVA_NOMENCLATURA -----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  COD_DW_PERSONA_UBIC_HIJO,CAMPO_COMPLEMENTO
					 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031_codigo
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Nomenclatura ;

	CUR2:LOOP
		FETCH Cur_Nomenclatura  INTO  V_COD_DW_UBIC_H, V_SQL ;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

-------------------------- UPDATE COMPLEMENTO -------------------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A 
						FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031_codigo  A 
						  SET NUEVA_NOMENCLATURA= '||V_SQL||'
						WHERE COD_DW_PERSONA_UBIC_HIJO ='||V_COD_DW_UBIC_H|| '
						';
		SET P_ERROR=V_CADENA;			
	
		CALL DBC.SysExecSQL(:V_CADENA);

	END LOOP CUR2;

CLOSE Cur_Nomenclatura ;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------CREACION DE REGISTRO NUEVO PARA DIRECCION_FISICA Y RELACION PERSONA UBICACION -------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE 
		AND TABLENAME = 'Tmp_Unificacion_E03_C' ;
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_C';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;



		SET V_CADENA='';
		SET V_CADENA='CREATE TABLE rec_stage.Tmp_Unificacion_E03_C AS (
			SELECT COD_DW_PERSONA_UBIC_PADRE||COD_DW_PERSONA_UBIC_HIJO AS Cod_DW_Persona_Ubic 
			,NULL ID
			,T1.Texto_Ubicacion
			, CL.Id_Buro_Persona
			, CL.Cod_DW_Tipo_Ubicacion_Dir
			,COMPLEMENTO_PADRE|| CAST(NUEVA_NOMENCLATURA AS VARCHAR(300) )AS Complemento1
			,NULL Nomenclatura
			,((SELECT ID FROM REC_MTDAT.MAX_ID AS M_ID1 WHERE M_ID1.NOMBRE_TABLA =''DIRECCION_FISICA'') +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) AS COD_DW_DIRECCION_FISICA /*#6*/
			,((SELECT id FROM REC_MTDAT.MAX_ID AS M_ID WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' ) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) AS ID_PADRE /*#6*/
			,CL.COD_DW_UBIC
			FROM (
			SELECT COD_DW_PERSONA_UBIC_PADRE
			,COMPLEMENTO_PADRE
			,Cod_DW_Ubic
			,Id_Buro_Persona
			,Cod_DW_Tipo_Ubicacion_Dir
			,OREPLACE(XMLAGG( '' ''||TRIM(NUEVA_NOMENCLATURA) ORDER BY MDIR DESC) ,''@#X'','''')AS NUEVA_NOMENCLATURA
			,OREPLACE(XMLAGG( '' ,''||TRIM(COD_DW_PERSONA_UBIC_HIJO) ORDER BY MDIR DESC),''@'','''')  AS COD_DW_PERSONA_UBIC_HIJO
			FROM REC_STAGE.Tmp_Unificacion_E031_codigo 
			GROUP BY 1,2,3,4,5
			)CL

				 LEFT JOIN REC_STAGE.Tmp_Unificacion_E03_B T1
				 ON T1.Cod_DW_Persona_Ubic=CL.COD_DW_PERSONA_UBIC_PADRE
				/*#6*/
				 
			)WITH DATA;
			';

			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva codigos'
			,V_ERROR);
			
			SET P_ERROR = V_ERROR;
        		
        		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;	


--------------------#1 Fin creacion nuevas direcciones ------------------------------------------------------
--------------------------------------------------------------------------------------------------------


		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE 
		AND TABLENAME = 'Tmp_Unificacion_E03_D' ;
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E03_D';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;



--- Se genera la tabla con los registros unificados y los registros que se deben crear en 
--- direccion_fisica y en Relacion_persona_ubicacion
SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E03_D AS 
(--- Registros nuevos creados
SELECT ID_PADRE AS Cod_DW_Persona_Ubic
 ,CAST(NULL AS BIGINT) AS ID_PADRE	/*#2*/
 ,Id_Buro_Persona
 ,Cod_DW_Tipo_Ubicacion_Dir	
 ,Cod_DW_Ubic
 ,Texto_Ubicacion
 ,COD_DW_DIRECCION_FISICA	
 ,Complemento1 AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''N'' Ind_Unificacion
 ,-99 AS ROW_U
 ,Cast(null as varchar(100)) as  N_ID
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_C AS T1
 
 
UNION ALL 

-- registros unificados escenario 2 registros con nit
SELECT T1.COD_DW_PERSONA_UBIC
 ,T2.ID_PADRE
 ,CAST(NULL AS INTEGER) Id_Buro_Persona
 ,CAST(NULL AS INTEGER) Cod_DW_Tipo_Ubicacion_Dir
 ,NULL Cod_DW_Ubic
 ,CAST(NULL AS VARCHAR(100))Texto_Ubicacion
 ,CAST(NULL AS BIGINT) COD_DW_DIRECCION_FISICA	
 ,CAST(NULL AS VARCHAR(1000))  AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''S'' Ind_Unificacion
 ,0 AS ROW_U
 ,Cast(''X4'' as varchar(100)) as  N_ID
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E031 AS T1
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E03_C AS T2
 ON T2.COD_DW_PERSONA_UBIC LIKE ''%'' ||cast(T1.COD_DW_PERSONA_UBIC as varchar(20))|| ''%'' 
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.COD_DW_PERSONA_UBIC ORDER BY T2.ID_PADRE))=1
 
 UNION ALL
 
-- registros unificados escenario 1 registros sin nit 
 SELECT  COD_DW_PERSONA_UBIC
 ,ID_PADRE
 ,CAST(NULL AS INTEGER) Id_Buro_Persona
 ,CAST(NULL AS INTEGER) Cod_DW_Tipo_Ubicacion_Dir
 ,NULL Cod_DW_Ubic
 ,CAST(NULL AS VARCHAR(100))Texto_Ubicacion
 ,CAST(NULL AS BIGINT) COD_DW_DIRECCION_FISICA	 /*#2*/
 ,CAST(NULL AS VARCHAR(1000))  AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''S'' Ind_Unificacion
 ,0 AS ROW_U
 ,Cast(''L3'' as varchar(100)) as  N_ID
 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_E1
 )WITH DATA 
 PRIMARY INDEX (COD_DW_PERSONA_UBIC);
 '
;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Crear y carga la tabla Tmp_Unificacion_E03_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Se realiza el merge para actualizar ID_PADRE  de las direcciones que fueron unificadas por escenario 1 y 2 -------------------------
----- y se insertan los registros con las direcciones nuevas creadas que se pueden identificar por el campo ,-99 AS ROW_U------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SET V_CADENA = '';
	SET V_CADENA = 
'MERGE INTO  '||P_BDSTAGE||'.Tmp_Unificacion_E2 U3
USING 
(SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E03_D
) STG
					ON 	U3.Cod_DW_Persona_Ubic = STG.COD_DW_PERSONA_UBIC

					WHEN MATCHED THEN UPDATE	
					SET 
						ID_PADRE                 =STG.ID_PADRE		
						,Ind_Unificacion		 =STG.Ind_Unificacion
						,ROW_U				 	 =STG.ROW_U
						,N_ID			 		 =STG.N_ID			

					WHEN NOT MATCHED THEN INSERT
					VALUES  ( STG.Cod_DW_Persona_Ubic				
							 ,STG.ID_PADRE 							
							 ,STG.Id_Buro_Persona 					
							 ,STG.Cod_DW_Tipo_Ubicacion_Dir 		
							 ,STG.Cod_DW_Ubic 						
							 ,STG.Texto_Ubicacion 					
							 ,STG.Cod_DW_Direccion_Fisica 			
							 ,STG.Complemento 						
							 ,STG.Cod_DW_Doc_Ident 					
							 ,STG.Cod_Tipo_Ident_Fte 				
							 ,STG.Cod_DW_Municipio 					
							 ,STG.Numero_entidades_que_Reportan 	
							 ,STG.Fecha_Relacion_Persona_Ubicaci 	
							 ,STG.Ind_Unificacion 					
							 ,STG.ROW_U 
							 ,STG.N_ID);
'
;
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):.Merge tabla Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-- Para el escenario 4 se debe tomar apartir de la tabla stage '||P_BDSTAGE||'.Tmp_Unificacion_E2 



--------------------
-- Actualiza estadisticas a Tmp_Unificacion_E3_2
--------------------
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT COLUMN (Id_Buro_Persona, Cod_DW_Ubic, ROW_U, Ind_Unificacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Texto_Ubicacion)
				ON ' || P_BDSTAGE ||'.Tmp_Unificacion_E2';
	
	--------------------
	-- Ejecuta cadena
	--------------------
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (9):. Actualizar estadisticas a la tabla Tmp_Unificacion'
			,:V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
--------------------------------------------------------------------------------------------------------------------------------------------
----------------------------FIN ESCENARIO 3 -----------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------


-- Escenario 4 ------------
-- Se extraen los datos que cumplen las condiciones para ser unificados

/*Si las nomenclaturas que difieren se encuentran al mismo Nivel, se debe consultar el Directorio de la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n GEO, (Ver Anexo Directorio Complemento) y verificar cuÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡l de los valores de las nomenclaturas tienen un mayor valor de frecuencia, esta serÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada.
Cuando las frecuencias sean iguales se tomarÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡ la que tenga la fecha de actualizaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n mÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡s reciente.*/

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E04
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


--- se toma la muestra de datos que no han sido unificados.

SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04
					AS (
					SELECT A.*
					FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
						JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
							ON A.COMPLEMENTO <> B.COMPLEMENTO
							AND A.Id_Buro_Persona		      	=    B.Id_Buro_Persona
							AND A.Texto_Ubicacion		      	=    B.Texto_Ubicacion
							AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
							AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
							AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
					QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
					) WITH DATA
					PRIMARY INDEX (Cod_DW_Persona_Ubic);'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




---------------------------
-- Busca y borra si existe la tabla '||P_BDSTAGE||'.Tmp_Unificacion_E04_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = --- Se identifican las nomenclaturas de cada complemento
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC1.NIVEL_COMPLEMENTO 
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
 ,NMC2.NIVEL_COMPLEMENTO AS NIVEL_COMPLEMENTO1
 ,TRIM( (OREPLACE ((OREPLACE (A.COMPLEMENTO,NMC1.NOMENCLATURA,'''')),NMC2.NOMENCLATURA,'''')) )
	AS COMPLEMENTO2
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1
  ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2
  ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	



-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- Se extraen los datos que cumplen con el escenario que existan varias nomenclaturas en el complemento y estos estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n contenidos en el otro-------------------------------------
---------, pero una de las nomenclaturas es diferente, se valida si las nomenclaturas se encuentran al mismo nivel, para ello se deben tener en  Cuenta ---------------------------------
---------los Niveles definidos para las nomenclaturas en la tabla NOMENCLATURA.--------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04_C AS(
SELECT * FROM (
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E04_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA = B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') <> NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )
		 AND NVL(A.NIVEL_COMPLEMENTO1,0)=NVL(B.NIVEL_COMPLEMENTO1,0) /*#8*/
UNION ALL
		   
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E04_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      	=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>   B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA <> B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') = NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )		   
		 AND A.NIVEL_COMPLEMENTO=B.NIVEL_COMPLEMENTO
)A /*#3*/
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



------------------------------------------------------------------------------------------
----- Se realiza la suma de los diccionarios para cada complemento.--- 
------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E04_C1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04_C1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04_C1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

--- Se agregan los conteos por diccionario. 
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04_C1
AS
( 

SELECT t1.COD_DW_PERSONA_UBIC,t2.CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_C  t1
LEFT JOIN 
(SELECT COD_DW_PERSONA_UBIC,SUM(CONTEO) AS CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_C T1
	LEFT JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS T2
		ON 	T1.COD_DW_UBIC=T2.COD_DW_UBIC
		AND T1.COMPLEMENTO LIKE ''%''||T2.Nomenclatura ||''%''
		AND T1.ID_BURO_PERSONA = T2.ID_BURO_PERSONA /*#4*/
GROUP BY 1
) t2 
ON t1.COD_DW_PERSONA_UBIC=t2.COD_DW_PERSONA_UBIC

)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04_C1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E04_D
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	
	SET V_CADENA = '';
	SET V_CADENA = 	
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04_D AS
(
SELECT U1.*
				  ,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
				  ,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
				  ,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 
				  	     WHEN  COUNT_EMPATE=1 THEN 1
				  ELSE 0 END AS EMPATE
				  
				FROM
(



SELECT  A.COD_DW_PERSONA_UBIC
/* Se suman las fechas con las entidades que reportan para sacar el de mayor peso para la unificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n*/
,(COALESCE(Conteo,0)+10000000) + COALESCE(CAST(fecha_relacion_persona_ubicaci AS INTEGER),0) AS ID
,  A.TEXTO_UBICACION
, A.Fecha_Relacion_Persona_Ubicaci
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir
						,a.Cod_DW_Municipio
						 ORDER BY ID ) AS ORDEN
,a.Cod_DW_Ubic		
,COMPLEMENTO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_C  A
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E04_C1 B
 ON A.Cod_DW_Persona_Ubic=B.Cod_DW_Persona_Ubic
)AS U1
			 --	QUALIFY EMPATE=1


)WITH DATA
PRIMARY INDEX(Id_Buro_Persona
,Texto_Ubicacion
,Cod_DW_Tipo_Ubicacion_Dir
,Cod_DW_Municipio
,Cod_DW_Persona_Ubic 
,Cod_DW_Ubic)
;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E04_E' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E04_E';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	
	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E04_E  
AS(
SELECT B.COD_DW_PERSONA_UBIC
,A.COD_DW_PERSONA_UBIC AS ID_PADRE
			  FROM '||P_BDSTAGE||'.Tmp_Unificacion_E04_D A
			   INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E04_D B
			   	  ON A.Id_Buro_Persona			  =  B.Id_Buro_Persona				 
				AND A.Texto_Ubicacion			          =  B.Texto_Ubicacion			         
				AND A.Cod_DW_Tipo_Ubicacion_Dir	  =  B.Cod_DW_Tipo_Ubicacion_Dir	     
				AND A.Cod_DW_Municipio			  =  B.Cod_DW_Municipio			    
				AND A.Cod_DW_Persona_Ubic	          <>B.Cod_DW_Persona_Ubic			 
        			AND  A.ID > B.ID
			  QUALIFY (MAX(A.ORDEN ) OVER(PARTITION BY A.Id_Buro_Persona			
,A.Texto_Ubicacion			        
,A.Cod_DW_Tipo_Ubicacion_Dir	
,A.Cod_DW_Municipio			
) )=A.ORDEN 

)WITH DATA;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):.Crear y carga la tabla Tmp_Unificacion_E04_E'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = --ActualizaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de IDs padre para el escenario 4

'UPDATE '||P_BDSTAGE||'.Tmp_Unificacion_E2
SET ID_PADRE   	   = Tmp_Unificacion_E04_E.ID_PADRE
  ,Ind_Unificacion 	   = ''S''
  ,N_ID		   =''B5''
WHERE '||P_BDSTAGE||'.Tmp_Unificacion_E2.COD_DW_PERSONA_UBIC = '||P_BDSTAGE||'.Tmp_Unificacion_E04_E.COD_DW_PERSONA_UBIC
AND '||P_BDSTAGE||'.Tmp_Unificacion_E2.ID_PADRE IS NULL
;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (4):Update Padres Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------   FIN ESCENARIO 4 ------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------
------------------- Inicio Escenario 5 subcaso 1 --------------------------------------------------------
---------------------------------------------------------------------------------------------------------

/*Subcaso uno: Si los valores que acompaÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â±an las nomenclaturas que difieren en el complemento 
son diferentes, se realiza la unificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n buscando armar un solo registro mÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡s completo que contenga 
ambas nomenclaturas y sus valores, creando para esto una nuevo complemento en la tabla DIRECCION_FISICA  
asociado a la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n GEO y creando su correspondiente relaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n con la persona en la tabla 
RELACION_PERSONA_UBICACION, estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â© nuevo registro corresponderÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡ a la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada y las dos direcciones 
evaluadas deben ser unidas a esta Ã¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Âºltima.*/



---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


--- se toma la muestra de datos que no han sido unificados.

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051
AS (
SELECT A.*
  FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
	 JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
		   ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
 
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic);'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

--- Se identifican las nomenclaturas de cada complemento
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC1.NIVEL_COMPLEMENTO 
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
 ,NMC2.NIVEL_COMPLEMENTO AS NIVEL_COMPLEMENTO1
 ,TRIM( (OREPLACE ((OREPLACE (A.COMPLEMENTO,NMC1.NOMENCLATURA,'''')),NMC2.NOMENCLATURA,'''')) )
	AS COMPLEMENTO2
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1
  ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2
  ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- Se extraen los datos que cumplen con el escenario que existan varias nomenclaturas en el complemento y estos estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n contenidos en el otro-------------------------------------
---------, pero una de las nomenclaturas es diferente, se valida si las nomenclaturas se encuentran al mismo nivel, para ello se deben tener en  Cuenta ---------------------------------
---------los Niveles definidos para las nomenclaturas en la tabla NOMENCLATURA.--------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

		SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_C AS(
SELECT * FROM
(SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2  NOT LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2  NOT LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA = B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') <> NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )
		 AND NVL(A.NIVEL_COMPLEMENTO1,0)<>NVL(B.NIVEL_COMPLEMENTO1,0)/*#8*/
UNION ALL
		   
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   NOT LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   NOT LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA <> B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') = NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )		   
		 AND A.NIVEL_COMPLEMENTO<>B.NIVEL_COMPLEMENTO
		 
) AS A		 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



------------------------------------------------------------------------------------------
----- Se realiza la suma de los diccionarios para cada complemento.--- 
------------------------------------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_C1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_C1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_C1
AS
( 

SELECT t1.COD_DW_PERSONA_UBIC,t2.CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_C  t1
LEFT JOIN 
(SELECT COD_DW_PERSONA_UBIC,SUM(CONTEO) AS CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_C T1
	LEFT JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS T2
		ON 	T1.COD_DW_UBIC=T2.COD_DW_UBIC
		AND T1.COMPLEMENTO LIKE ''%''||T2.Nomenclatura ||''%''
		AND T1.ID_BURO_PERSONA = T2.ID_BURO_PERSONA /*#4*/
GROUP BY 1
) t2 
ON t1.COD_DW_PERSONA_UBIC=t2.COD_DW_PERSONA_UBIC

)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051_C1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	



------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	
	SET V_CADENA = '';
	SET V_CADENA = 	
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_D AS
(
SELECT U1.COD_DW_PERSONA_UBIC,U1.ID+U1.ORDEN AS ID,U1.TEXTO_UBICACION,U1.Fecha_Relacion_Persona_Ubicaci,U1.Numero_entidades_que_Reportan
,U1.Id_Buro_Persona,U1.Cod_DW_Tipo_Ubicacion_Dir,U1.Cod_DW_Municipio,U1.ORDEN,U1.Cod_DW_Ubic,U1.COMPLEMENTO
,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 WHEN  COUNT_EMPATE=1 THEN 1 ELSE 0 END AS EMPATE
				  
FROM
(

	SELECT  A.COD_DW_PERSONA_UBIC
	,(COALESCE(Conteo,0)+10000000) + COALESCE(CAST(fecha_relacion_persona_ubicaci AS INTEGER),0) AS ID 
	,  A.TEXTO_UBICACION
	, A.Fecha_Relacion_Persona_Ubicaci
	,A.Numero_entidades_que_Reportan 		
	,A.Id_Buro_Persona
	,A.Cod_DW_Tipo_Ubicacion_Dir
	,A.Cod_DW_Municipio
	,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio ORDER BY ID ) AS ORDEN
	,a.Cod_DW_Ubic		
	,COMPLEMENTO
	FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_C  A
	LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_C1 B ON A.Cod_DW_Persona_Ubic=B.Cod_DW_Persona_Ubic
)AS U1
			 --	QUALIFY EMPATE=1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic ,Cod_DW_Ubic)
;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------#1 Inicio creacion nuevas direcciones -------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D1 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_D1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*1. DescomposiciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de los complementos por nomenclatura  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1  AS 
					(SELECT TU.Cod_DW_Persona_Ubic
					,TU.Cod_dw_ubic
					,DC.nomen
					,NOM.Nivel_Complemento 
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  DESC  ROWS UNBOUNDED PRECEDING) AS ID_COM
					,SUM(TO_NUMBER(VALOR))	AS valor
					,COUNT(Cod_DW_Persona_Ubic ) AS cantidad
					,SUM(1) OVER(PARTITION BY Cod_DW_Persona_Ubic ORDER BY NOM.Nivel_Complemento  ROWS UNBOUNDED PRECEDING) AS ID_COM1
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D TU
					INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
					ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
					AND tu.cod_dw_ubic=dc.cod_dw_ubic
					AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
					LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
					ON NOM.NOMENCLATURA=DC.Nomen
					GROUP BY 1,2,3,4
					)WITH DATA 
					PRIMARY INDEX(Cod_DW_Persona_Ubic,nomen,Nivel_Complemento)
					;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D2 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D2' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D2';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*2. agrupaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de nomenclaturas por cod_dw_persona_ubic  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D2
					(COD_DW_PERSONA_UBIC BIGINT NULL	/*#2*/
					,NOM_AGRUP  VARCHAR (100) NULL
					,cantidad	 INTEGER NULL
					) ;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.Tmp_Unificacion_E051_D2
					SELECT COD_DW_PERSONA_UBIC
						,XMLAGG(NOMEN ORDER BY ID_COM) AS A_NOMEN
						,SUM(cantidad) AS cantidad
					FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1
					GROUP BY 1
					;
					';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------CALCULO DE MDIR --> ID para identificar la direciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de mayor jerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------

	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_Dx' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_Dx';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';

SELECT XMLAGG(CAMPO ORDER BY ORD)
INTO :V_CADENA
FROM 
(SELECT ORD
, ID_COM1 
,CAST(CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_Dx AS ( Select  cod_dw_persona_ubic,cod_dw_ubic
,COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||'
'
WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN nivel_complemento end) ,99) AS ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',COALESCE(MAX(CASE WHEN ID_COM1 =  '||TRIM(ID_COM1)||' THEN valor end),99999) AS val'||TRIM(ID_COM1)||'
'
END  AS VARCHAR(16000)) AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP,  SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
) A
UNION ALL 
SELECT ORD
, ID_COM1 
,CASE WHEN ID_COM1 = idmin AND TP='ID_COM1'  THEN ' ,ROW_NUMBER() OVER (PARTITION BY cod_dw_ubic  ORDER BY  ID_COM1'||TRIM(ID_COM1)||'
'WHEN ID_COM1 <> idmin AND TP='ID_COM1'  THEN ',ID_COM1'||TRIM(ID_COM1)||' '
WHEN ID_COM1 <> idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||''
WHEN ID_COM1 = idMAX AND TP='val' THEN ',val'||TRIM(ID_COM1)||') as MDIR
FROM rec_stage.Tmp_Unificacion_E051_D1
GROUP BY 1,2) WITH DATA
'
END AS campo  
FROM 
(SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'ID_COM1' AS TP, 10000+ SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD 
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
UNION ALL 
SELECT ID_COM1,MAX(ID_COM1) OVER() idmax, MIN(ID_COM1) OVER() idmin , 'val' AS TP, 10000+idMAX + SUM(1) OVER (ORDER BY ID_COM1 ROWS UNBOUNDED PRECEDING ) AS ORD
FROM rec_stage.Tmp_Unificacion_E051_D1 GROUP BY 1
) A
) A;

 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E051_Dx  
     (
      Cod_DW_Persona_Ubic BIGINT, /*#2*/
      Cod_DW_Ubic BIGINT, /*#2*/
      ID_COM11 INTEGER,
      ID_COM12 INTEGER,
      ID_COM13 INTEGER,
      ID_COM14 INTEGER,
      ID_COM15 INTEGER,
      val1 NUMBER,
      val2 NUMBER,
      val3 NUMBER,
      val4 NUMBER,
      val5 NUMBER,
      MDIR INTEGER)
PRIMARY INDEX ( Cod_DW_Persona_Ubic );';
		
	END IF;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):MDIR'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;		
	
	
	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D3 --------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D3' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D3';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	
	/*3. agrupaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n Nomenclatura - valor cod_dw_persona_ubic e identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de orden NOMENCLATURA - VALOR  */
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_D3 AS (
				SELECT TU.cod_dw_ubic
				,TU.Cod_DW_Persona_Ubic
				,TU.complemento
				,DC.Nomenclatura
				,DC.nomen
				,DC.VALOR
				,NOM.Nivel_Complemento
				,TU.Id_Buro_Persona
				,TU.Cod_DW_Tipo_Ubicacion_Dir
				,MAX(NOM.Nivel_Complemento) OVER() MAX_NIVEL
				,MIN(NOM.Nivel_Complemento) OVER() MIN_NIVEL
				,TUN.ID_COM
				,MAX(TUN.ID_COM) OVER() MAX_ID_COM
				,MIN(TUN.ID_COM) OVER() MIN_ID_COM
				,MDIR
				,SUM(1) OVER(PARTITION BY TU.Cod_DW_Persona_Ubic ORDER BY MDIR,ID_COM DESC,TO_NUMBER(DC.VALOR)ROWS UNBOUNDED PRECEDING) AS ORDEN
				,NAGR.NOM_AGRUP 
				,NAGR.CANTIDAD
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D TU
				INNER  JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
				ON TU.complemento LIKE ''%''||DC.nomenclatura||''%''
				AND tu.cod_dw_ubic=dc.cod_dw_ubic
				AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
				LEFT JOIN REC_DATOS.NOMENCLATURA NOM
				ON NOM.NOMENCLATURA=DC.Nomen
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_D1 TUN 
				ON TUN.Cod_DW_Persona_Ubic = TU.Cod_DW_Persona_Ubic
				AND TUN.nomen  = DC.nomen
				AND TUN.Nivel_Complemento  = NOM.Nivel_Complemento
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_Dx AS MD
				ON TU.Cod_DW_Persona_Ubic=MD.COD_DW_PERSONA_UBIC
				LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_D2 NAGR
				ON TU.COD_DW_PERSONA_UBIC=NAGR.COD_DW_PERSONA_UBIC
				
				)WITH DATA 
				PRIMARY INDEX(Id_Buro_Persona,Cod_DW_Persona_Ubic,cod_dw_ubic,Cod_DW_Tipo_Ubicacion_Dir)
				INDEX (Cod_DW_Persona_Ubic) /*#7*/
				;
					';
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
		
---------------------------------
 ---------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E051_D00 -------------------
--------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D00' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D00';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	
	SET V_CADENA = '';
	
	SELECT CAST(SQL_STRING AS VARCHAR(32000)) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT   XMLAGG(campo ORDER BY numero ) AS SQL_STRING
	FROM (SELECT numero,
	CASE WHEN NUMERO=1 THEN  'CREATE SET TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D00
		( 
			Cod_DW_Persona_Ubic BIGINT /*#2*/
			,Cod_DW_Ubic BIGINT /*#2*/
			,Id_Buro_Persona INTEGER
			,Cod_DW_Tipo_Ubicacion_Dir INTEGER
			,Complemento VARCHAR(100) 
			,cantidad INTEGER
			,NOM_AGRUP VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',C'||TRIM(NUMERO)|| '	VARCHAR(30) '
	ELSE ',C'||TRIM(NUMERO)|| '	VARCHAR(30) ' 
	||'
	);' END AS campo
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3 
	) T4;	 

	 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E051_D00  
     (
      Cod_DW_Persona_Ubic BIGINT, /*#2*/
      Cod_DW_Ubic BIGINT, /*#2*/
      Id_Buro_Persona INTEGER,
      Cod_DW_Tipo_Ubicacion_Dir INTEGER,
      Complemento VARCHAR(100)  ,
      cantidad INTEGER,
      NOM_AGRUP VARCHAR(100)  ,
      C1 VARCHAR(30)  ,
      C2 VARCHAR(30)  ,
      C3 VARCHAR(30)  ,
      C4 VARCHAR(30)  ,
      C5 VARCHAR(30)  ,
      C6 VARCHAR(30)  ,
      C7 VARCHAR(30)  )
PRIMARY INDEX ( Cod_DW_Persona_Ubic );';
		
	END IF;				
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


	SET V_CADENA='';
	
      SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
      INTO :V_CADENA
      FROM (
      
      SELECT NUMERO,
      CASE WHEN NUMERO=1 THEN  '
	INSERT INTO REC_STAGE.Tmp_Unificacion_E051_D00 
	SELECT COD_DW_PERSONA_UBIC
	,COD_DW_UBIC
	,ID_BURO_PERSONA
	,Cod_DW_Tipo_Ubicacion_Dir
	,COMPLEMENTO
	,CANTIDAD
	,NOM_AGRUP
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO)
	ELSE ',XMLAGG(CASE WHEN ORDEN='||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS C'||TRIM(NUMERO) 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_D3 
	GROUP BY 1,2,3,4,5,6,7
	;' END CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3
	;

	
			
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva c'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------------------------------------------------------------
----------------ESTRUCTURA TIPO N --> ConvinaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de posibles nomenclaturas-valor  -------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_D01' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_D01';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
		
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	SELECT NUMERO, CASE WHEN NUMERO=1 THEN  'CREATE SET  TABLE REC_STAGE.Tmp_Unificacion_E051_D01
    	 ( Cod_DW_Persona_Ubic BIGINT /*#2*/
	,Complemento VARCHAR(100) 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',N'||TRIM(NUMERO)|| '	VARCHAR(100)'
	ELSE ',N'||TRIM(NUMERO)|| '	VARCHAR(100)
	);
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	) T3
	
	;
	
	 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E051_D01  
     (
      Cod_DW_Persona_Ubic BIGINT, /*#2*/
      Complemento VARCHAR(100)  ,
      N1 VARCHAR(100)  ,
      N2 VARCHAR(100)  ,
      N3 VARCHAR(100)  ,
      N4 VARCHAR(100)  ,
      N5 VARCHAR(100)  ,
      N6 VARCHAR(100)  ,
      N7 VARCHAR(100)  )
PRIMARY INDEX ( Cod_DW_Persona_Ubic );
';
		
	END IF;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY NUMERO) AS CONSULTA
	INTO :V_CADENA
	FROM (
	
	SELECT NUMERO,
	CASE WHEN NUMERO=1 THEN  'INSERT INTO REC_STAGE.Tmp_Unificacion_E051_D01 
	SELECT COD_DW_PERSONA_UBIC
	,COMPLEMENTO
	,MAX(CASE WHEN ORDEN=1 THEN COMPLEMENTO END) 					 AS N1 
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',XMLAGG(CASE WHEN ORDEN>'||TRIM(NUMERO)|| 'THEN NOMENCLATURA END ORDER BY ORDEN )  AS N'||TRIM(NUMERO+1)
	ELSE '
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	GROUP BY 1,2
	' END AS CAMPO
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	)T3
	;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva N'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registro de mayor gerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_P' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_P';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_P AS(
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T3.CANTIDAD
	,T3.NOM_AGRUP
	'||
	OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E051_D3 AS T2
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D00 AS T3
		ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_UBIC,T2.ID_BURO_PERSONA,T2.Cod_DW_Tipo_Ubicacion_Dir ORDER BY T2.MDIR ,T2.ORDEN ))=1
	) WITH DATA PRIMARY INDEX (COD_DW_PERSONA_UBIC)
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
	;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva P'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registro de MENOR gerarquÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON   REC_STAGE.Tmp_Unificacion_E051_D00;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D00',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON   REC_STAGE.Tmp_Unificacion_E051_D3;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D3',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON   REC_STAGE.Tmp_Unificacion_E051_D01;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D01',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON   REC_STAGE.Tmp_Unificacion_E051_P;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_P',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA='COLLECT STATISTICS COLUMN (COD_DW_UBIC ,COD_DW_PERSONA_UBIC,ID_BURO_PERSONA ,COD_DW_TIPO_UBICACION_DIR) ON    REC_STAGE.Tmp_Unificacion_E051_D3;'; /*#7*/
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (5):STATS Tmp_Unificacion_E051_D3',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 




	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_H' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_H';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA='';

SELECT 'CREATE TABLE REC_STAGE.Tmp_Unificacion_E051_H 
	AS (
	SELECT T2.COD_DW_PERSONA_UBIC
	,T2.COD_DW_UBIC
	,T2.ID_BURO_PERSONA 
	,T2.Cod_DW_Tipo_Ubicacion_Dir
	,T2.COMPLEMENTO
	,T2.CANTIDAD
	,T2.NOM_AGRUP
	,T2.MDIR

	'||OREPLACE(XMLAGG( ',T5.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','')
	 || (SELECT OREPLACE(XMLAGG( ',T3.'||TRIM(COLUMNNAME) ORDER BY ColumnId) ,'@','') AS CPN
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D01'
	AND TRIM(COLUMNNAME) LIKE 'N%'
	AND ColumnFormat = 'X(100)')
	
	||'
	 FROM REC_STAGE.Tmp_Unificacion_E051_D3 AS T2
	 LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D01 AS T3
	 	ON T2.COD_DW_PERSONA_UBIC=T3.COD_DW_PERSONA_UBIC
	 INNER JOIN REC_STAGE.Tmp_Unificacion_E051_D00 AS T5
	 	ON T2.COD_DW_PERSONA_UBIC=T5.COD_DW_PERSONA_UBIC
	 WHERE NOT EXISTS ( SELECT 1 FROM  REC_STAGE.Tmp_Unificacion_E051_P T4 WHERE T4.COD_DW_PERSONA_UBIC=T2.COD_DW_PERSONA_UBIC)
	 QUALIFY (ROW_NUMBER()OVER(PARTITION BY T2.COD_DW_PERSONA_UBIC ORDER BY T2.MDIR ,T2.ORDEN ))=1
	 ) WITH DATA PRIMARY INDEX(COD_DW_PERSONA_UBIC) /*#7*/
	 ;
	'
	INTO :V_CADENA
	FROM DBC.COLUMNS
	WHERE TRIM(DATABASENAME)= 'REC_STAGE'
	AND TRIM(TABLENAME)= 'Tmp_Unificacion_E051_D00'
	AND TRIM(COLUMNNAME) LIKE 'C%'
	AND ColumnFormat = 'X(30)'
;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva H'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------ Se crea la tabla con los codigos generados para identificar los complementos que van a crear un nuevo complemento ---------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_codigo' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_codigo';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	SET V_CADENA='';
	
	SELECT XMLAGG(CAMPO ORDER BY ID_ORDEN) AS SQL_STRING
	INTO :V_CADENA
	FROM (
	SELECT SUM(1) OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	CAST(
	CASE WHEN NUMERO=1 THEN  'CREATE TABLE  REC_STAGE.Tmp_Unificacion_E051_codigo AS (
	SELECT T1.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_PADRE
	,T2.COD_DW_PERSONA_UBIC AS COD_DW_PERSONA_UBIC_HIJO
	,T1.COMPLEMENTO AS COMPLEMENTO_PADRE
	,T1.COD_DW_UBIC 			
	,T1.ID_BURO_PERSONA 			
	,T1.Cod_DW_Tipo_Ubicacion_Dir	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	',N'||TRIM(NUMERO)|| '	'
	ELSE ',N'||TRIM(NUMERO)|| '	' 
	||'
	
	' END
	
	AS VARCHAR(16000)) AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	--ORDER BY NUMERO
	
	UNION ALL 
	
	SELECT 1000 + SUM(1)  OVER(ORDER BY NUMERO ROWS UNBOUNDED PRECEDING) AS ID_ORDEN,
	
	CASE WHEN NUMERO=1 THEN  ',CASE WHEN T1.NOM_AGRUP= T2.NOM_AGRUP THEN ''1'' ELSE ''0'' END	
	' ELSE '' END
	|| CASE WHEN NUMERO <> (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3) THEN 
	'|| CASE WHEN T1.C'||TRIM(NUMERO)||' = T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END'
	
	ELSE '|| CASE WHEN T1.C'||TRIM(NUMERO)|| '= T2.C'||TRIM(NUMERO)||' THEN ''1'' ELSE ''0'' END AS CODIGO
	,''TRIM(N''||TRIM( CASE WHEN  (POSITION( ''0'' IN CODIGO) -1)<1 THEN 1 ELSE  (POSITION( ''0'' IN CODIGO) -1) END )||'')'' AS Campo_Complemento
	, CAST( NULL AS VARCHAR(300)) AS NUEVA_NOMENCLATURA
	,T2.MDIR  
	' 
	||'
	FROM REC_STAGE.Tmp_Unificacion_E051_P T1
	LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_H T2
	ON 		T1.COD_DW_UBIC 			= 	T2.COD_DW_UBIC
	AND 	T1.ID_BURO_PERSONA 			= 	T2.ID_BURO_PERSONA 
	AND 	T1.Cod_DW_Tipo_Ubicacion_Dir	=	T2.Cod_DW_Tipo_Ubicacion_Dir
	) WITH DATA
	UNIQUE PRIMARY INDEX(COD_DW_PERSONA_UBIC_PADRE,COD_DW_PERSONA_UBIC_HIJO)
	;
	' END AS CAMPO
	
	FROM 
	(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS NUMERO
	FROM REC_STAGE.Tmp_Unificacion_E051_D3
	QUALIFY (NUMERO) <= (SELECT MAX(CANTIDAD) FROM REC_STAGE.Tmp_Unificacion_E051_D3)
	) T2
	--ORDER BY NUMERO
	)T3;


 IF V_CADENA IS NULL THEN
	
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE SET TABLE REC_STAGE.Tmp_Unificacion_E051_codigo  
     (
      COD_DW_PERSONA_UBIC_PADRE BIGINT, /*#2*/
      COD_DW_PERSONA_UBIC_HIJO BIGINT, /*#2*/
      COMPLEMENTO_PADRE VARCHAR(100)  ,
      Cod_DW_Ubic BIGINT, /*#2*/
      Id_Buro_Persona INTEGER,
      Cod_DW_Tipo_Ubicacion_Dir INTEGER,
      N1 VARCHAR(100)  ,
      N2 VARCHAR(100)  ,
      N3 VARCHAR(100)  ,
      N4 VARCHAR(100)  ,
      N5 VARCHAR(100)  ,
      N6 VARCHAR(100)  ,
      N7 VARCHAR(100)  ,
      CODIGO VARCHAR(8) CHARACTER SET UNICODE NOT CASESPECIFIC,
      Campo_Complemento VARCHAR(18)  ,
      NUEVA_NOMENCLATURA VARCHAR(300)  ,
      MDIR INTEGER)
UNIQUE PRIMARY INDEX ( COD_DW_PERSONA_UBIC_PADRE ,COD_DW_PERSONA_UBIC_HIJO );
';
		
	END IF;
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva codigos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n NUEVA_NOMENCLATURA -----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  COD_DW_PERSONA_UBIC_HIJO,CAMPO_COMPLEMENTO
					 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_codigo
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Nomenclatura ;

	CUR2:LOOP
		FETCH Cur_Nomenclatura  INTO  V_COD_DW_UBIC_H, V_SQL ;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

-------------------------- UPDATE COMPLEMENTO -------------------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A 
						FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_codigo  A 
						  SET NUEVA_NOMENCLATURA= '||V_SQL||'
						WHERE COD_DW_PERSONA_UBIC_HIJO ='||V_COD_DW_UBIC_H|| '
						';
		SET P_ERROR=V_CADENA;			
	
		CALL DBC.SysExecSQL(:V_CADENA);

	END LOOP CUR2;

CLOSE Cur_Nomenclatura ;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------CREACION DE REGISTRO NUEVO PARA DIRECCION_FISICA Y RELACION PERSONA UBICACION -------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		SELECT TABLENAME 
		INTO :Temp
		FROM dbc.tables
		WHERE databasename =:P_BDSTAGE 
		AND TABLENAME = 'Tmp_Unificacion_E051_E' ;
		
		IF ACTIVITY_COUNT > 0 THEN
			SET V_CADENA = 'DROP TABLE '||P_BDSTAGE ||'.Tmp_Unificacion_E051_E';
			CALL DBC.SysExecSQL(:V_CADENA);
		END IF;



		SET V_CADENA='';
		SET V_CADENA='CREATE TABLE rec_stage.Tmp_Unificacion_E051_E AS (
			SELECT COD_DW_PERSONA_UBIC_PADRE||COD_DW_PERSONA_UBIC_HIJO AS Cod_DW_Persona_Ubic 
			,NULL ID
			,T1.Texto_Ubicacion
			, CL.Id_Buro_Persona
			, CL.Cod_DW_Tipo_Ubicacion_Dir
			,COMPLEMENTO_PADRE|| CAST(NUEVA_NOMENCLATURA AS VARCHAR(300) )AS Complemento1
			,NULL Nomenclatura
			,((SELECT ID FROM REC_MTDAT.MAX_ID AS M_ID1 WHERE M_ID1.NOMBRE_TABLA =''DIRECCION_FISICA'') +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) AS COD_DW_DIRECCION_FISICA /*#6*/
			,
 ((SELECT id FROM REC_MTDAT.MAX_ID AS M_ID WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' ) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) AS ID_PADRE /*#6*/
			,CL.COD_DW_UBIC
			FROM (
			SELECT COD_DW_PERSONA_UBIC_PADRE
			,COMPLEMENTO_PADRE
			,Cod_DW_Ubic
			,Id_Buro_Persona
			,Cod_DW_Tipo_Ubicacion_Dir
			,OREPLACE(XMLAGG( '' ''||TRIM(NUEVA_NOMENCLATURA) ORDER BY MDIR DESC) ,''@#X'','''')AS NUEVA_NOMENCLATURA
			,OREPLACE(XMLAGG( '' ,''||TRIM(COD_DW_PERSONA_UBIC_HIJO) ORDER BY MDIR DESC),''@'','''')  AS COD_DW_PERSONA_UBIC_HIJO
			FROM REC_STAGE.Tmp_Unificacion_E051_codigo 
			GROUP BY 1,2,3,4,5
			)CL
								 
				 LEFT JOIN REC_STAGE.Tmp_Unificacion_E051_D T1
				 ON T1.Cod_DW_Persona_Ubic=CL.COD_DW_PERSONA_UBIC_PADRE

				/*#6*/
				
			)WITH DATA;
			';

			CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5):DirecciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n_nueva codigos'
			,V_ERROR);
			
			SET P_ERROR = V_ERROR;
        		
        		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;	

	
	
-----------------------------------#1 Fin creacion nuevas direcciones --------------------------
------------------------------------------------------------------------------------------------------------------
	
	
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E051_F' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E051_F';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;	

	

--- Se genera la tabla con los registros unificados y los registros que se deben crear en 
--- direccion_fisica y en Relacion_persona_ubicacion	

	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E051_F AS 
(--- Registros nuevos creados
SELECT ID_PADRE AS Cod_DW_Persona_Ubic
 ,CAST(NULL AS BIGINT) AS ID_PADRE	 /*#2*/
 ,Id_Buro_Persona
 ,Cod_DW_Tipo_Ubicacion_Dir	
 ,Cod_DW_Ubic
 ,Texto_Ubicacion
 ,COD_DW_DIRECCION_FISICA	
 ,complemento1 AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''N'' Ind_Unificacion
 ,-99 AS ROW_U
 ,Cast(NULL as varchar(100)) as  N_ID
 
 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_E T1

QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.ID_PADRE ORDER BY T1.ID_PADRE ))=1

 UNION ALL 
 SELECT T1.COD_DW_PERSONA_UBIC
 ,T2.ID_PADRE
 ,CAST(NULL AS INTEGER) Id_Buro_Persona
 ,CAST(NULL AS INTEGER) Cod_DW_Tipo_Ubicacion_Dir
 ,NULL Cod_DW_Ubic
 ,CAST(NULL AS VARCHAR(100))Texto_Ubicacion
 ,CAST(NULL AS BIGINT) COD_DW_DIRECCION_FISICA	/*#2*/
 ,CAST(NULL AS VARCHAR(1000))  AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''S'' Ind_Unificacion
 ,0 AS ROW_U
 ,Cast(''A6'' as varchar(100)) as  N_ID
 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_D  AS T1
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E051_E AS T2
 ON T2.COD_DW_PERSONA_UBIC LIKE ''%'' ||CAST(T1.COD_DW_PERSONA_UBIC AS VARCHAR(20))|| ''%'' 
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.COD_DW_PERSONA_UBIC ORDER BY T2.ID_PADRE))=1
 
 )WITH DATA 
 PRIMARY INDEX (COD_DW_PERSONA_UBIC);
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):.Crear y carga la tabla Tmp_Unificacion_E051_F'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Se realiza el merge para actualizar ID_PADRE  de las direcciones que fueron unificadas por escenario 1 y 2 -------------------------
----- y se insertan los registros con las direcciones nuevas creadas que se pueden identificar por el campo ,-99 AS ROW_U------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'MERGE INTO  '||P_BDSTAGE||'.Tmp_Unificacion_E2 U3
					USING 
					(SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E051_F) STG ON 	U3.Cod_DW_Persona_Ubic = STG.COD_DW_PERSONA_UBIC
					
					WHEN MATCHED THEN UPDATE	
					SET 
						ID_PADRE                        =STG.ID_PADRE		
						,Ind_Unificacion		 =STG.Ind_Unificacion
						,ROW_U				 =STG.ROW_U
						,N_ID				 =''A6''
					WHEN NOT MATCHED THEN INSERT
					VALUES  ( STG.Cod_DW_Persona_Ubic				
							 ,STG.ID_PADRE 							
							 ,STG.Id_Buro_Persona 					
							 ,STG.Cod_DW_Tipo_Ubicacion_Dir 		
							 ,STG.Cod_DW_Ubic 						
							 ,STG.Texto_Ubicacion 					
							 ,STG.Cod_DW_Direccion_Fisica 			
							 ,STG.Complemento 						
							 ,STG.Cod_DW_Doc_Ident 					
							 ,STG.Cod_Tipo_Ident_Fte 				
							 ,STG.Cod_DW_Municipio 					
							 ,STG.Numero_entidades_que_Reportan 	
							 ,STG.Fecha_Relacion_Persona_Ubicaci 	
							 ,STG.Ind_Unificacion 					
							 ,STG.ROW_U 
							 ,NULL		);'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.1):Merge Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

---------------------------------------------------------------------------------------------------------
------------------- Fin Escenario 5 subcaso 1 --------------------------------------------------------
---------------------------------------------------------------------------------------------------------	


/*----------------------------------------------------------------------------------------------------------
-------------------- Inicio unificacion Escenario 5 subcaso 2 -----------------------------------------------
---------------------------------------------------------------------------------------------------------*/



/*Si los valores que acompaÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â±an las nomenclaturas que difieren en el complemento son iguales
, se debe consultar el Directorio de la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n GEO, (Ver Anexo Directorio Complemento) y verificar cuÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡l 
de los valores de las nomenclaturas tienen un mayor valor de frecuencia, esta serÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â­a la direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada.
Cuando las frecuencias sean iguales se tomarÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡ la que tenga la fecha de actualizaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n mÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡s reciente.
*/


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


--- se toma la muestra de datos que no han sido unificados.
SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05
AS (
SELECT A.*
  FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
	 JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
		   ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic);'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_5'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


--- Se identifican las nomenclaturas de cada complemento
SET V_CADENA = '';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC1.NIVEL_COMPLEMENTO 
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
 ,NMC2.NIVEL_COMPLEMENTO AS NIVEL_COMPLEMENTO1
 ,TRIM( (OREPLACE ((OREPLACE (A.COMPLEMENTO,NMC1.NOMENCLATURA,'''')),NMC2.NOMENCLATURA,'''')) ) AS COMPLEMENTO2
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1 ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2 ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''
) WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic);
';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_E05_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- Se extraen los datos que cumplen con el escenario que existan varias nomenclaturas en el complemento y estos estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n contenidos en el otro-------------------------------------
---------, pero una de las nomenclaturas es diferente, se valida si las nomenclaturas se encuentran al mismo nivel, para ello se deben tener en  Cuenta ---------------------------------
---------los Niveles definidos para las nomenclaturas en la tabla NOMENCLATURA.--------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05_C AS(
SELECT * 
FROM(
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E05_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA = B.NOMENCLATURA			
		   	      AND NVL(A.NOMENCLATURA1,''A'') <> NVL(B.NOMENCLATURA1,''A'') 	/*#8*/
			     )
		 AND A.NIVEL_COMPLEMENTO<>B.NIVEL_COMPLEMENTO
UNION ALL
		   
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E05_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA <> B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') = NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )		   
		 AND A.NIVEL_COMPLEMENTO<>B.NIVEL_COMPLEMENTO
) AS A /*#3*/
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_E05C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


------------------------------------------------------------------------------------------
----- Se realiza la suma de los diccionarios para cada complemento.--- 
------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05_C1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05_C1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05_C1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


--Se agrega el conteo de diccionarios para el desempate

SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05_C1
AS
( 

SELECT t1.COD_DW_PERSONA_UBIC,t2.CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_C  t1
LEFT JOIN 
(SELECT COD_DW_PERSONA_UBIC,SUM(CONTEO) AS CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_C T1
	LEFT JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS T2
		ON 	T1.COD_DW_UBIC=T2.COD_DW_UBIC
		AND T1.COMPLEMENTO LIKE ''%''||T2.Nomenclatura ||''%''
		AND T1.ID_BURO_PERSONA = T2.ID_BURO_PERSONA /*#4*/
GROUP BY 1
) t2 
ON t1.COD_DW_PERSONA_UBIC=t2.COD_DW_PERSONA_UBIC

)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_E05_C1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	



------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05_D
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

-- se asignan los valores correspondientes para identificar los registros unificadores	

SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05_D AS
(
SELECT U1.*
				  ,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
				  ,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
				  ,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 
				  	     WHEN  COUNT_EMPATE=1 THEN 1
				  ELSE 0 END AS EMPATE
				  
				FROM
(



SELECT  A.COD_DW_PERSONA_UBIC
,(COALESCE(Conteo,0)+10000000) + COALESCE(CAST(fecha_relacion_persona_ubicaci AS INTEGER),0) AS ID
,  A.TEXTO_UBICACION
, A.Fecha_Relacion_Persona_Ubicaci
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio ORDER BY ID ) AS ORDEN
,a.Cod_DW_Ubic		
,COMPLEMENTO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_C  A
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E05_C1 B
 ON A.Cod_DW_Persona_Ubic=B.Cod_DW_Persona_Ubic
)AS U1
			 --	QUALIFY EMPATE=1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic,Cod_DW_Ubic)
;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_E05_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	
	


---- Se marcan los rregistros hijos con sus respectivos padres.

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E05_E
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E05_E' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E05_E';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E05_E  
AS(
SELECT B.COD_DW_PERSONA_UBIC
,A.COD_DW_PERSONA_UBIC AS ID_PADRE
			  FROM '||P_BDSTAGE||'.Tmp_Unificacion_E05_D A
			   INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E05_D B
			   	  ON A.Id_Buro_Persona			  =  B.Id_Buro_Persona				 
				AND A.Texto_Ubicacion			          =  B.Texto_Ubicacion			         
				AND A.Cod_DW_Tipo_Ubicacion_Dir	  =  B.Cod_DW_Tipo_Ubicacion_Dir	     
				AND A.Cod_DW_Municipio			  =  B.Cod_DW_Municipio			    
				AND A.Cod_DW_Persona_Ubic	          <>B.Cod_DW_Persona_Ubic			 
        			AND  A.ID > B.ID
			  QUALIFY (MAX(A.ORDEN ) OVER(PARTITION BY A.Id_Buro_Persona,A.Texto_Ubicacion,A.Cod_DW_Tipo_Ubicacion_Dir,A.Cod_DW_Municipio) )=A.ORDEN 
)WITH DATA;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):.Crear y carga la tabla Tmp_Unificacion_E05_E'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	
	

 --Se actualizÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n los registros unificados en la muestra total de datos. 
SET V_CADENA = '';
	SET V_CADENA =  'UPDATE '||P_BDSTAGE||'.Tmp_Unificacion_E2
SET ID_PADRE   	   = Tmp_Unificacion_E05_E.ID_PADRE
  ,Ind_Unificacion 	   = ''S''
  ,N_ID		=''C7''
WHERE '||P_BDSTAGE||'.Tmp_Unificacion_E2.COD_DW_PERSONA_UBIC = '||P_BDSTAGE||'.Tmp_Unificacion_E05_E.COD_DW_PERSONA_UBIC
AND '||P_BDSTAGE||'.Tmp_Unificacion_E2.ID_PADRE IS NULL
;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (5.2):Update id_padre en Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
 
/*----------------------------------------------------------------------------------------------------------
-------------------- fin unificacion Escenario 5 subcaso 2 -----------------------------------------------
---------------------------------------------------------------------------------------------------------*/


----------------------------------------------------------------------------------------------------------------
--------------------- Inicio escenario 6 subcaso 1 --------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
	

--------------------------------------------------------------------
----- IdentificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registros pendientes por unificar ----------
--------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061
AS (
SELECT A.*
  FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
	 JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
		   ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic);
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



---------------------------------------------------------------------------------
-------- identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de nomenclaturas en el complemento ----------------------
---------------------------------------------------------------------------------

	
----------------------------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061_A -----------
----------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = '
CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1
  ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2
  ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''

)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- IdentificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registros con Nomenclaturas IGUALES --------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_C AS(
SELECT * FROM (
SELECT A.* 
	,SUBSTR (A.COMPLEMENTO,POSITION(A.NOMENCLATURA IN A.COMPLEMENTO),100) AS NOM_A
	,SUBSTR (A.COMPLEMENTO,1,POSITION(A.NOMENCLATURA IN A.COMPLEMENTO)-1) AS NOM_B
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND  ( COALESCE(A.NOMENCLATURA,''A'')   = COALESCE(B.NOMENCLATURA1,''B'' ))	
UNION ALL 
SELECT A.* 
	,SUBSTR (A.COMPLEMENTO,POSITION(A.NOMENCLATURA1 IN A.COMPLEMENTO),100) AS NOM_A
	,SUBSTR (A.COMPLEMENTO,1,POSITION(A.NOMENCLATURA1 IN A.COMPLEMENTO)-1) AS NOM_B
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 

		   AND  ( COALESCE(A.NOMENCLATURA1,''A'')   = COALESCE(B.NOMENCLATURA,''B'' )
			     )		   

) A
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;
 '
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------- Identificacion de registros con nomenclaturas iguales y valores que estan incluidos-----------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E0611_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E0611_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E0611_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E0611_C AS(
SELECT * FROM (
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_C A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_C B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND  ( A.NOM_A LIKE ''%'' ||B.NOM_A||''%'')	
		   AND  ( A.NOM_A <> B.NOM_A)	
UNION ALL 
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_C A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_C B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND  ( B.NOM_A LIKE ''%'' ||A.NOM_A||''%'')	 
		   AND  ( B.NOM_A <> A.NOM_A)
) A
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E0611_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

 
  
---------------------------------------------------------------------------------------------------------------------------------------------------
----------------------- identificaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de registros a ser unificados en una nueva direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n -------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061_D
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_D AS
(

SELECT U1.COD_DW_PERSONA_UBIC
,U1.TEXTO_UBICACION
,U1.Fecha_Relacion_Persona_Ubicaci
,U1.Numero_entidades_que_Reportan 		
,U1.Id_Buro_Persona
,U1.Cod_DW_Tipo_Ubicacion_Dir
,U1.Cod_DW_Municipio
,U1.ORDEN
,U1.Cod_DW_Ubic		
,TRIM(U1.COMPLEMENTO1) AS COMPLEMENTO
,U1.ID
,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 WHEN  COUNT_EMPATE=1 THEN 1 ELSE 0 END AS EMPATE				  
FROM
(

SELECT  A.COD_DW_PERSONA_UBIC
,  A.TEXTO_UBICACION
, A.Fecha_Relacion_Persona_Ubicaci
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio ORDER BY ID ) AS ORDEN
,a.Cod_DW_Ubic		
,CASE WHEN NULLIF(NOM_B ,'''') IS NULL THEN NOM_A ELSE NOM_B END AS COMPLEMENTO1
,CHAR_LENGTH (COMPLEMENTO) AS ID
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E0611_C  A
)AS U1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic,Cod_DW_Ubic)
;
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





-------------------------------------------------------------------------------------------------------------------------------------------------
--------------------- creaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de la nueva direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n  aplicando las reglas escenario 6 subcaso 1 ---------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061_E
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_E' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_E';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_E  AS (
WITH RECURSIVE CONCAT_LIST
(Cod_DW_Persona_Ubic,Cod_DW_Ubic,ID,Cod_DW_Municipio,Texto_Ubicacion, Id_Buro_Persona, Cod_DW_Tipo_Ubicacion_Dir, Complemento, LVL) AS
(
  SELECT Cod_DW_Persona_Ubic (VARCHAR(1000)),Cod_DW_Ubic,ID,Cod_DW_Municipio,Texto_Ubicacion, Id_Buro_Persona, Cod_DW_Tipo_Ubicacion_Dir, Complemento (VARCHAR(1000)), 1
  FROM  '||P_BDSTAGE||'.Tmp_Unificacion_E061_D

  UNION ALL
  SELECT T1.Cod_DW_Persona_Ubic||'',''||T2.Cod_DW_Persona_Ubic   
    ,T1.Cod_DW_Ubic
    ,T1.ID,T1.Cod_DW_Municipio
    --,T1.Nomenclatura
    ,T1.Texto_Ubicacion
    , T1.Id_Buro_Persona
    , T1.Cod_DW_Tipo_Ubicacion_Dir
    , T1.Complemento || '' '' || T2.Complemento
    , LVL+1
  FROM   '||P_BDSTAGE||'.Tmp_Unificacion_E061_D T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.Texto_Ubicacion 				= T2.Texto_Ubicacion
   AND T1.Id_Buro_Persona            		= T2.Id_Buro_Persona
   AND T1.Cod_DW_Tipo_Ubicacion_Dir  	= T2.Cod_DW_Tipo_Ubicacion_Dir
   AND T1.Cod_DW_Municipio           		= T2.Cod_DW_Municipio
   AND T1.COD_DW_UBIC 		    		= T2.Cod_dw_ubic
  WHERE T1.ID > T2.ID
)


SELECT CL.Cod_DW_Persona_Ubic,CL.ID,CL.Texto_Ubicacion, CL.Id_Buro_Persona, CL.Cod_DW_Tipo_Ubicacion_Dir,CL.Complemento
,((SELECT CASE WHEN M_ID.ID > MAX(COD_DW_DIRECCION_FISICA) THEN M_ID.ID ELSE MAX(COD_DW_DIRECCION_FISICA) END AS ID
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 
					CROSS JOIN REC_MTDAT.MAX_ID AS M_ID 
				WHERE M_ID.NOMBRE_TABLA =''DIRECCION_FISICA'' 
				GROUP BY M_ID.ID		
				) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
		 AS COD_DW_DIRECCION_FISICA /*#6*/
,((	SELECT CASE WHEN M_ID.ID > MAX(COD_DW_PERSONA_UBIC) 
					THEN M_ID.ID ELSE MAX(COD_DW_PERSONA_UBIC) END AS ID
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 
					CROSS JOIN REC_MTDAT.MAX_ID AS M_ID 
				WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' 
					GROUP BY M_ID.ID

				) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
		AS ID_PADRE /*#6*/
,CL.COD_DW_UBIC
FROM   CONCAT_LIST CL
/*#6*/

 WHERE CL.Cod_DW_Persona_Ubic LIKE ''%,%''
QUALIFY RANK() OVER(PARTITION BY CL.Id_Buro_Persona,CL.Texto_Ubicacion,CL.Cod_DW_Tipo_Ubicacion_Dir,CL.Cod_DW_Municipio,CL.COD_DW_UBIC ORDER BY LVL DESC) = 1

) WITH DATA
;
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061_E'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-----------------------------------------------------------------------------------------------------------------------
------- AsignaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de valores para Ordenar el nuevo complemento creado ------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_EA' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_EA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													
-----------------------------
-- Se crea y carga la tabla Tmp_Unificacion_E061_EA
-----------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_EA 
AS (
SELECT TU.ID_PADRE AS cod_dw_persona_ubic
 ,complemento
 ,DC.NOMENCLATURA
 ,DC.Nomen
  ,NOM.Nivel_Complemento
  ,COALESCE(TO_NUMBER(VALOR) ,0) AS VALOR
  ,COALESCE( NOM.Nivel_Complemento*100000+(COALESCE(TO_NUMBER(VALOR) ,0)),0) *-1 ID_ORD_COMP 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_E TU
 INNER JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
  ON DC.COD_DW_UBIC=TU.COD_DW_UBIC
  AND TU.COMPLEMENTO LIKE ''%''||DC.NOMENCLATURA||''%''
  AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
  LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
   ON (COALESCE(NULLIF(DC.Nomen,''''),DC.Nomenclatura))=NOM.Nomenclatura

) WITH DATA
PRIMARY INDEX (cod_dw_persona_ubic, NOMENCLATURA)
;
';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):. Crear y carga la tabla Tmp_Unificacion_E061_EA'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





------------------------------------------------------------------------------------------------------------------------------
------------------------------ ORDENAMIENTO DE LAS PARTICULAS DE EL COMPLEMENTO PARA LAS DIRECCIONES NUEVAS CREADAS ---------- 
------------------------------------------------------------------------------------------------------------------------------
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E061_EB
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_EB' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_EB';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_EB 
AS (
WITH RECURSIVE CONCAT_LIST
(
   Cod_DW_Persona_Ubic
  ,COMPLEMENTO
  ,NOMENCLATURA
  ,ID_ORD_COMP 
  , LVL
) AS

(
  SELECT 
  	 Cod_DW_Persona_Ubic
	,COMPLEMENTO
	,NOMENCLATURA
	,ID_ORD_COMP 
	, 1
  FROM  '||P_BDSTAGE||'.Tmp_Unificacion_E061_EA 

  UNION ALL
  
  SELECT T1.Cod_DW_Persona_Ubic
    ,T1.COMPLEMENTO
    , T1.NOMENCLATURA|| '' '' || T2.NOMENCLATURA
    ,T1.ID_ORD_COMP 
    ,LVL+1
  FROM   '||P_BDSTAGE||'.Tmp_Unificacion_E061_EA  T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.Cod_DW_Persona_Ubic 	= T2.Cod_DW_Persona_Ubic 
  WHERE T1.ID_ORD_COMP > T2.ID_ORD_COMP
)

SELECT Cod_DW_Persona_Ubic,NOMENCLATURA AS NUEVO_COMPLEMENTO
FROM   CONCAT_LIST CL
QUALIFY (ROW_NUMBER() OVER(PARTITION BY Cod_Dw_Persona_Ubic ORDER BY LVL DESC ))=1
) WITH DATA
PRIMARY INDEX (cod_dw_persona_ubic)
;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):. Crear y carga la tabla Tmp_Unificacion_E061_EB'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


	
	
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E061_F' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E061_F';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

--- Se genera la tabla con los registros unificados y los registros que se deben crear en 
--- direccion_fisica y en Relacion_persona_ubicacion

	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E061_F AS 
(--- Registros nuevos creados
SELECT ID_PADRE AS Cod_DW_Persona_Ubic
 ,cast(NULL as BIGINT)/*#2*/ AS ID_PADRE	
 ,Id_Buro_Persona
 ,Cod_DW_Tipo_Ubicacion_Dir	
 ,Cod_DW_Ubic
 ,Texto_Ubicacion
 ,COD_DW_DIRECCION_FISICA	
 ,COALESCE(T2.NUEVO_COMPLEMENTO,Complemento) AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''N'' Ind_Unificacion
 ,-99 AS ROW_U
 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_E T1
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_EB AS T2 ON T1.ID_PADRE		=	T2.cod_dw_persona_ubic
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.ID_PADRE ORDER BY T1.ID_PADRE))=1

 UNION ALL 
 SELECT T1.COD_DW_PERSONA_UBIC
 ,T2.ID_PADRE
 ,CAST(NULL AS INTEGER) Id_Buro_Persona
 ,CAST(NULL AS INTEGER) Cod_DW_Tipo_Ubicacion_Dir
 ,NULL Cod_DW_Ubic
 ,CAST(NULL AS VARCHAR(100))Texto_Ubicacion
 ,CAST(NULL AS BIGINT) COD_DW_DIRECCION_FISICA	/*#2*/
 ,CAST(NULL AS VARCHAR(1000))  AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''S'' Ind_Unificacion
 ,0 AS ROW_U
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_D  AS T1
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E061_E AS T2 ON T2.COD_DW_PERSONA_UBIC LIKE ''%'' ||T1.COD_DW_PERSONA_UBIC|| ''%'' 
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.COD_DW_PERSONA_UBIC ORDER BY T2.ID_PADRE))=1
 
 )WITH DATA 
 PRIMARY INDEX (COD_DW_PERSONA_UBIC);
'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.1):.Crear y carga la tabla Tmp_Unificacion_E061_F'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Se realiza el merge para actualizar ID_PADRE  de las direcciones que fueron unificadas por escenario 1 y 2 -------------------------
----- y se insertan los registros con las direcciones nuevas creadas que se pueden identificar por el campo ,-99 AS ROW_U------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'MERGE INTO  '||P_BDSTAGE||'.Tmp_Unificacion_E2 U3
USING 
(SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E061_F
) STG
					ON 	U3.Cod_DW_Persona_Ubic = STG.COD_DW_PERSONA_UBIC

					WHEN MATCHED THEN UPDATE	
					SET 
						ID_PADRE                = STG.ID_PADRE		
						,Ind_Unificacion		= STG.Ind_Unificacion
						,ROW_U				 	= STG.ROW_U
						,N_ID        			= ''A8''
						
					WHEN NOT MATCHED THEN INSERT
					VALUES  ( STG.Cod_DW_Persona_Ubic				
							 ,STG.ID_PADRE 							
							 ,STG.Id_Buro_Persona 					
							 ,STG.Cod_DW_Tipo_Ubicacion_Dir 		
							 ,STG.Cod_DW_Ubic 						
							 ,STG.Texto_Ubicacion 					
							 ,STG.Cod_DW_Direccion_Fisica 			
							 ,STG.Complemento 						
							 ,STG.Cod_DW_Doc_Ident 					
							 ,STG.Cod_Tipo_Ident_Fte 				
							 ,STG.Cod_DW_Municipio 					
							 ,STG.Numero_entidades_que_Reportan 	
							 ,STG.Fecha_Relacion_Persona_Ubicaci 	
							 ,STG.Ind_Unificacion 					
							 ,STG.ROW_U 
							 ,NULL
							 );'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):Merge Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

----------------------------------------------------------------------------------------------------------------
--------------------- Fin escenario 6 subcaso 1 --------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
	



----------------------------------------------------------------------------------------------------------------
--------------------- Incio escenario 6 subcaso 2 --------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


/*S62 Cuando un complemento no estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â© incluido en el otro y las nomenclaturas no coinciden en ninguno de los casos, se debe evaluar si las nomenclaturas
estÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n en niveles diferentes, en este caso se debe armar un nuevo complemento uniendo las nomenclaturas*/

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
 

 --- se toma la muestra de datos que no han sido unificados.

 	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062
AS (
SELECT A.*
  FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
	 JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
		   ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic);'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
 
 

 ---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

--- Se identifican las nomenclaturas de cada complemento

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC1.NIVEL_COMPLEMENTO 
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
 ,NMC2.NIVEL_COMPLEMENTO AS NIVEL_COMPLEMENTO1
 ,TRIM( (OREPLACE ((OREPLACE (A.COMPLEMENTO,NMC1.NOMENCLATURA,'''')),NMC2.NOMENCLATURA,'''')) )
	AS COMPLEMENTO2
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1 ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2 ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





--SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_A 
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- Nomenclaturas distintas y nivel de complemento diferentes.--------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_C AS(
SELECT * FROM (
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E062_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2  NOT LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2  NOT LIKE ''%''||A.Complemento2||''%'' )
		   AND  (  COALESCE(A.NOMENCLATURA,''A'') 	  <> COALESCE(B.NOMENCLATURA,''B'')
		   	      AND COALESCE(A.NOMENCLATURA1,''A'') <> COALESCE(B.NOMENCLATURA1,''B'')
			      AND COALESCE(A.NOMENCLATURA,''A'')   <> COALESCE(B.NOMENCLATURA1,''B'' )
			     )		   
		AND A.NIVEL_COMPLEMENTO<>B.NIVEL_COMPLEMENTO
		AND COALESCE(A.NIVEL_COMPLEMENTO,''A'')<>COALESCE(B.NIVEL_COMPLEMENTO1,''B'')

) A
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



------------------------------------------------------------------------------------------
----- Se realiza la suma de los diccionarios para cada complemento.--- 
------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_C1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_C1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_C1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_C1
AS
( 

SELECT t1.COD_DW_PERSONA_UBIC,t2.CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_C  t1
LEFT JOIN 
(SELECT COD_DW_PERSONA_UBIC,SUM(CONTEO) AS CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_C T1
	LEFT JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS T2
		ON 	T1.COD_DW_UBIC=T2.COD_DW_UBIC
		AND T1.COMPLEMENTO LIKE ''%''||T2.Nomenclatura ||''%''
		AND T1.ID_BURO_PERSONA = T2.ID_BURO_PERSONA /*#4*/
GROUP BY 1
) t2 ON t1.COD_DW_PERSONA_UBIC=t2.COD_DW_PERSONA_UBIC
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_C1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_D
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_D AS
(
SELECT U1.*
	,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
	,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
	,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 WHEN  COUNT_EMPATE=1 THEN 1 ELSE 0 END AS EMPATE
FROM
(
SELECT  A.COD_DW_PERSONA_UBIC
,(COALESCE(Conteo,0)+10000000) + COALESCE(CAST(fecha_relacion_persona_ubicaci AS INTEGER),0) AS ID
,  A.TEXTO_UBICACION
, A.Fecha_Relacion_Persona_Ubicaci
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio ORDER BY ID ) AS ORDEN
,a.Cod_DW_Ubic		
,COMPLEMENTO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_C  A
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E062_C1 B ON A.Cod_DW_Persona_Ubic=B.Cod_DW_Persona_Ubic
)AS U1
			 	--QUALIFY EMPATE=1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic ,Cod_DW_Ubic)
;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_E
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_E' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_E';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------Creacion de registro nuevo con su respectiva relacion en Direccion_fisica y Relacion_persona_ubicacion--------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_E  AS (
WITH RECURSIVE CONCAT_LIST
(Cod_DW_Persona_Ubic,Cod_DW_Ubic,ID,Cod_DW_Municipio,Texto_Ubicacion, Id_Buro_Persona, Cod_DW_Tipo_Ubicacion_Dir, Complemento, LVL) AS
(
  SELECT Cod_DW_Persona_Ubic (VARCHAR(1000)),Cod_DW_Ubic,ID,Cod_DW_Municipio,Texto_Ubicacion, Id_Buro_Persona, Cod_DW_Tipo_Ubicacion_Dir, Complemento (VARCHAR(1000)), 1
  FROM  '||P_BDSTAGE||'.Tmp_Unificacion_E062_D

  UNION ALL
  SELECT T1.Cod_DW_Persona_Ubic||'',''||T2.Cod_DW_Persona_Ubic   
    ,T1.Cod_DW_Ubic
    ,T1.ID,T1.Cod_DW_Municipio
    --,T1.Nomenclatura
    ,T1.Texto_Ubicacion
    , T1.Id_Buro_Persona
    , T1.Cod_DW_Tipo_Ubicacion_Dir
    , T1.Complemento || ''  '' || T2.Complemento
    , LVL+1
  FROM   '||P_BDSTAGE||'.Tmp_Unificacion_E062_D T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.Texto_Ubicacion 				= T2.Texto_Ubicacion
   AND T1.Id_Buro_Persona            		= T2.Id_Buro_Persona
   AND T1.Cod_DW_Tipo_Ubicacion_Dir  	= T2.Cod_DW_Tipo_Ubicacion_Dir
   AND T1.Cod_DW_Municipio           		= T2.Cod_DW_Municipio
   AND T1.COD_DW_UBIC 		    		= T2.Cod_dw_ubic
  WHERE T1.ID > T2.ID
)


SELECT CL.Cod_DW_Persona_Ubic,CL.ID,CL.Texto_Ubicacion, CL.Id_Buro_Persona, CL.Cod_DW_Tipo_Ubicacion_Dir,CL.Complemento
, ((
				SELECT CASE WHEN M_ID.ID > MAX(COD_DW_DIRECCION_FISICA) 
					THEN M_ID.ID ELSE MAX(COD_DW_DIRECCION_FISICA) END AS ID
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 
					CROSS JOIN REC_MTDAT.MAX_ID AS M_ID 
				WHERE M_ID.NOMBRE_TABLA =''DIRECCION_FISICA'' 
				GROUP BY M_ID.ID		
				) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
 AS COD_DW_DIRECCION_FISICA /*#6*/
, ((	SELECT CASE WHEN M_ID.ID > MAX(COD_DW_PERSONA_UBIC) 
					THEN M_ID.ID ELSE MAX(COD_DW_PERSONA_UBIC) END AS ID
				FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 
					CROSS JOIN REC_MTDAT.MAX_ID AS M_ID 
				WHERE M_ID.NOMBRE_TABLA =''RELACION_PERSONA_UBICACION'' 
					GROUP BY M_ID.ID

				) +  SUM(1)    OVER (ROWS UNBOUNDED PRECEDING)) 
		AS ID_PADRE /*#6*/
,CL.COD_DW_UBIC
FROM   CONCAT_LIST CL
/*#6*/	 
 WHERE CL.Cod_DW_Persona_Ubic LIKE ''%,%''
QUALIFY RANK() OVER(PARTITION BY CL.Id_Buro_Persona,CL.Texto_Ubicacion,CL.Cod_DW_Tipo_Ubicacion_Dir,CL.Cod_DW_Municipio,CL.COD_DW_UBIC ORDER BY LVL DESC) = 1

) WITH DATA
;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_E'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-----------------------------------------------------------------------------------------------------------------------
------- AsignaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n de valores para Ordenar el nuevo complemento creado -------------------------------
 -----------------
-----------------------------------------------------------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_EA' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_EA';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													
-----------------------------
-- Se crea y carga la tabla Tmp_Unificacion_E062_EA
-----------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_EA 
AS (
SELECT TU.ID_PADRE AS cod_dw_persona_ubic
 ,complemento
 ,DC.NOMENCLATURA
 ,DC.Nomen
  ,NOM.Nivel_Complemento
  ,COALESCE(TO_NUMBER(VALOR) ,0) AS VALOR
  ,COALESCE( NOM.Nivel_Complemento*100000+(COALESCE(TO_NUMBER(VALOR) ,0)),0) *-1 ID_ORD_COMP 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_E TU
 INNER JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS DC
  ON DC.COD_DW_UBIC=TU.COD_DW_UBIC
  AND TU.COMPLEMENTO LIKE ''%''||DC.NOMENCLATURA||''%''
  AND TU.ID_BURO_PERSONA = DC.ID_BURO_PERSONA /*#4*/
  LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NOM
   ON (COALESCE(NULLIF(DC.Nomen,''''),DC.Nomenclatura))=NOM.Nomenclatura

) WITH DATA
PRIMARY INDEX (cod_dw_persona_ubic, NOMENCLATURA)
;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):. Crear y carga la tabla Tmp_Unificacion_E062_EA'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;





------------------------------------------------------------------------------------------------------------------------------
------------------------------ ORDENAMIENTO DE LAS PARTICULAS DE EL COMPLEMENTO PARA LAS DIRECCIONES NUEVAS CREADAS ---------- 
------------------------------------------------------------------------------------------------------------------------------
---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_EB
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_EB' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_EB';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
													


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_EB 
AS (
WITH RECURSIVE CONCAT_LIST
(
   Cod_DW_Persona_Ubic
  ,COMPLEMENTO
  ,NOMENCLATURA
  ,ID_ORD_COMP 
  , LVL
) AS

(
  SELECT 
  	 Cod_DW_Persona_Ubic
	,COMPLEMENTO
	,NOMENCLATURA
	,ID_ORD_COMP 
	, 1
  FROM  '||P_BDSTAGE||'.Tmp_Unificacion_E062_EA 

  UNION ALL
  
  SELECT T1.Cod_DW_Persona_Ubic
    ,T1.COMPLEMENTO
    , T1.NOMENCLATURA|| '' '' || T2.NOMENCLATURA
    ,T1.ID_ORD_COMP 
    ,LVL+1
  FROM   '||P_BDSTAGE||'.Tmp_Unificacion_E062_EA  T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.Cod_DW_Persona_Ubic 	= T2.Cod_DW_Persona_Ubic 
  WHERE T1.ID_ORD_COMP > T2.ID_ORD_COMP
)

SELECT Cod_DW_Persona_Ubic
	,NOMENCLATURA AS NUEVO_COMPLEMENTO
FROM   CONCAT_LIST CL

QUALIFY (ROW_NUMBER() OVER(PARTITION BY Cod_Dw_Persona_Ubic ORDER BY LVL DESC ))=1

) WITH DATA
PRIMARY INDEX (cod_dw_persona_ubic)
;';
			
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (3):. Crear y carga la tabla Tmp_Unificacion_E062_EB'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


--------------------------- #5 ----------------------------------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E062_F1 -----------------------
-----------------------------------------------------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_F1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_F1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

--- Crea la tabla hijos con sus padres

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_F1 AS ( 
SELECT T1.*,COUNT(*) OVER(PARTITION BY ID_PADRE) AS CANT
FROM (
SELECT T1.COD_DW_PERSONA_UBIC
 ,T2.ID_PADRE
 ,CAST(NULL AS INTEGER) Id_Buro_Persona
 ,CAST(NULL AS INTEGER) Cod_DW_Tipo_Ubicacion_Dir
 ,NULL Cod_DW_Ubic
 ,CAST(NULL AS VARCHAR(100))Texto_Ubicacion
 ,CAST(NULL AS BIGINT) COD_DW_DIRECCION_FISICA	/*#2*/
 ,CAST(NULL AS VARCHAR(1000))  AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''S'' Ind_Unificacion
 ,0 AS ROW_U
FROM REC_STAGE.Tmp_Unificacion_E062_D  AS T1
INNER JOIN REC_STAGE.Tmp_Unificacion_E062_E AS T2
 ON T2.COD_DW_PERSONA_UBIC LIKE ''%'' ||CAST(T1.COD_DW_PERSONA_UBIC AS VARCHAR(20))|| ''%'' 
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.COD_DW_PERSONA_UBIC ORDER BY T1.COD_DW_PERSONA_UBIC,T2.ID_PADRE))=1
 GROUP BY 1,2
 ) T1  
 )WITH DATA;'
;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2.1):.Crear tabla Tmp_Unificacion_E062_F1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	
	


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E03
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E062_F' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E062_F';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	

--- Se genera la tabla con los registros unificados y los registros que se deben crear en 
--- direccion_fisica y en Relacion_persona_ubicacion

	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E062_F AS 
(--- Registros nuevos creados
SELECT T1.ID_PADRE AS Cod_DW_Persona_Ubic
 ,CAST(NULL AS BIGINT)/*#2*/ AS ID_PADRE	
 ,T1.Id_Buro_Persona
 ,T1.Cod_DW_Tipo_Ubicacion_Dir	
 ,T1.Cod_DW_Ubic
 ,T1.Texto_Ubicacion
 ,T1.COD_DW_DIRECCION_FISICA	
 ,COALESCE(T2.NUEVO_COMPLEMENTO,T1.Complemento) AS Complemento
 ,CAST(NULL AS INTEGER) Cod_DW_Doc_Ident
 ,CAST(NULL AS VARCHAR(20)) Cod_Tipo_Ident_Fte
 ,CAST(NULL AS INTEGER) Cod_DW_Municipio
 ,CAST(NULL AS INTEGER) Numero_entidades_que_Reportan 						
 ,CAST(NULL AS DATE)Fecha_Relacion_Persona_Ubicaci 						
 ,''N'' Ind_Unificacion
 ,-99 AS ROW_U
 FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_E T1
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E062_EB AS T2
  ON T1.ID_PADRE		=	T2.cod_dw_persona_ubic
 INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E062_F1 T3
 ON T3.ID_PADRE=T1.ID_PADRE
 AND T3.CANT > 1
 QUALIFY (ROW_NUMBER() OVER (PARTITION BY T1.ID_PADRE ORDER BY T1.ID_PADRE))=1

 UNION ALL 

 SELECT Cod_DW_Persona_Ubic           
,ID_PADRE                      
,Id_Buro_Persona               
,Cod_DW_Tipo_Ubicacion_Dir     
,Cod_DW_Ubic                   
,Texto_Ubicacion               
,COD_DW_DIRECCION_FISICA       
,Complemento                   
,Cod_DW_Doc_Ident              
,Cod_Tipo_Ident_Fte            
,Cod_DW_Municipio              
,Numero_entidades_que_Reportan 
,Fecha_Relacion_Persona_Ubicaci
,Ind_Unificacion               
,ROW_U                         
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_F1 
WHERE CANT > 1
 )WITH DATA 
 PRIMARY INDEX (COD_DW_PERSONA_UBIC);
 ';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):.Crear y carga la tabla Tmp_Unificacion_E062_F'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

--- fin #5------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Se realiza el merge para actualizar ID_PADRE  de las direcciones que fueron unificadas por escenario 1 y 2 -------------------------
----- y se insertan los registros con las direcciones nuevas creadas que se pueden identificar por el campo ,-99 AS ROW_U------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA = '';
	SET V_CADENA = 'MERGE INTO  '||P_BDSTAGE||'.Tmp_Unificacion_E2 U3
USING 
(SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E062_F
) STG
					ON 	U3.Cod_DW_Persona_Ubic = STG.COD_DW_PERSONA_UBIC

					WHEN MATCHED THEN UPDATE	
					SET 
						ID_PADRE                = STG.ID_PADRE		
						,Ind_Unificacion		= STG.Ind_Unificacion
						,ROW_U				 	= STG.ROW_U
						,N_ID        			= ''D9''
						
					WHEN NOT MATCHED THEN INSERT
					VALUES  ( STG.Cod_DW_Persona_Ubic				
							 ,STG.ID_PADRE 							
							 ,STG.Id_Buro_Persona 					
							 ,STG.Cod_DW_Tipo_Ubicacion_Dir 		
							 ,STG.Cod_DW_Ubic 						
							 ,STG.Texto_Ubicacion 					
							 ,STG.Cod_DW_Direccion_Fisica 			
							 ,STG.Complemento 						
							 ,STG.Cod_DW_Doc_Ident 					
							 ,STG.Cod_Tipo_Ident_Fte 				
							 ,STG.Cod_DW_Municipio 					
							 ,STG.Numero_entidades_que_Reportan 	
							 ,STG.Fecha_Relacion_Persona_Ubicaci 	
							 ,STG.Ind_Unificacion 					
							 ,STG.ROW_U 
							 ,NULL
							 );'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.2):Merge Tmp_Unificacion_E2'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

----------------------------------------------------------------------------------------------------------------
--------------------- Fin escenario 6 subcaso 2 --------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
	
	
----------------------------------------------------------------------------------------------------------
---------------- Inicio escenario 6 subcaso 3 ------------------------------------------------------------
----------------------------------------------------------------------------------------------------------


/*
En caso que las nomenclaturas sean de igual nivel se debe revisar el DICCIONARIO y escoger como direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada la que mÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡s frecuencia tenga. 
*/

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
--- se toma la muestra de datos que no han sido unificados.

	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063
AS (
SELECT A.*
  FROM (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) A
	 JOIN (SELECT * FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE Ind_Unificacion=''N'' ) B
		   ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic);'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063_A
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063_A' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063_A';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = --- Se identifican las nomenclaturas de cada complemento
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063_A AS 
(SELECT A.*
 ,NMC1.NOMENCLATURA
 ,NMC1.NIVEL_COMPLEMENTO 
 ,NMC2.NOMENCLATURA AS NOMENCLATURA1 
 ,NMC2.NIVEL_COMPLEMENTO AS NIVEL_COMPLEMENTO1
 ,TRIM( (OREPLACE ((OREPLACE (A.COMPLEMENTO,NMC1.NOMENCLATURA,'''')),NMC2.NOMENCLATURA,'''')) ) AS COMPLEMENTO2
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063 A
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC1 ON A.COMPLEMENTO LIKE  ''''||(TRIM(NMC1.Nomenclatura)||'' '')||''%''
 LEFT JOIN '||P_BDDATOS||'.NOMENCLATURA NMC2 ON A.COMPLEMENTO LIKE  ''%''||('' ''||TRIM(NMC2.Nomenclatura)||'' '')||''%''
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063_A'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
-------------------------------------------------------------------------------------------
----En caso que las nomenclaturas sean de igual nivel se debe revisar el DICCIONARIO ------
----y escoger como direcciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n unificada la que mÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡s frecuencia tenga ------------------------
-------------------------------------------------------------------------------------------


---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063_C
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063_C' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063_C';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 
'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063_C AS(
SELECT * FROM (
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E063_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2  NOT LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2  NOT LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA <> B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') <> NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )
		 AND A.NIVEL_COMPLEMENTO=B.NIVEL_COMPLEMENTO

UNION ALL
		   
SELECT A.* 
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_A A
INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E063_A B
ON A.COMPLEMENTO <> B.COMPLEMENTO
		   AND A.Id_Buro_Persona		      	      	=    B.Id_Buro_Persona
		   AND A.Texto_Ubicacion		      		=    B.Texto_Ubicacion
		   AND A.Cod_DW_Tipo_Ubicacion_Dir   	=    B.Cod_DW_Tipo_Ubicacion_Dir
		   AND A.Cod_DW_Municipio		      	=    B.Cod_DW_Municipio
		   AND A.Cod_DW_Persona_Ubic 			<>  B.Cod_DW_Persona_Ubic 
		   AND ( A.Complemento2   NOT LIKE ''%''||B.Complemento2||''%''
			      OR B.Complemento2   NOT LIKE ''%''||A.Complemento2||''%'' )
		   AND (  A.NOMENCLATURA <> B.NOMENCLATURA
		   	      AND NVL(A.NOMENCLATURA1,''A'') <> NVL(B.NOMENCLATURA1,''A'') /*#8*/
			     )		   
		 AND A.NIVEL_COMPLEMENTO=B.NIVEL_COMPLEMENTO
) A
QUALIFY(ROW_NUMBER() OVER(PARTITION BY A.Cod_DW_Persona_Ubic  ORDER BY A.Cod_DW_Persona_Ubic DESC))=1			
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063_C'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


------------------------------------------------------------------------------------------
----- Se realiza la suma de los diccionarios para cada complemento.----------------------- 
------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063_C1
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063_C1' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063_C1';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063_C1
AS
( 

SELECT t1.COD_DW_PERSONA_UBIC,t2.CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_C  t1
LEFT JOIN 
(SELECT COD_DW_PERSONA_UBIC,SUM(CONTEO) AS CONTEO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_C T1
	LEFT JOIN '||P_BDSTAGE||'.DICCIONARIO_COMPLEMENTOS T2
		ON 	T1.COD_DW_UBIC=T2.COD_DW_UBIC
		AND T1.COMPLEMENTO LIKE ''%''||T2.Nomenclatura ||''%''
		AND T1.ID_BURO_PERSONA = T2.ID_BURO_PERSONA /*#4*/
GROUP BY 1
) t2 
ON t1.COD_DW_PERSONA_UBIC=t2.COD_DW_PERSONA_UBIC

)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic) ;'

	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063_C1'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
---- Del universo de datos a procesar se aplican las reglas para identificar los registros
---- que van a ser unificados 
-----  se calcula cuales presentan empate y se descartan de la muestra 
---- se toman los registros que presentan la misma nomenclatura pero con diferente valor
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063_D
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063_D' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063_D';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063_D AS
(
SELECT U1.*
	,COUNT(*) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,ID) AS COUNT_EMPATE /*#2*/
	,MAX(ID) OVER(PARTITION BY Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio) AS IDMAX
	,CASE WHEN  COUNT_EMPATE>1 AND IDMAX>ID THEN 1 WHEN  COUNT_EMPATE=1 THEN 1 ELSE 0 END AS EMPATE
FROM
(

SELECT  A.COD_DW_PERSONA_UBIC
,(COALESCE(Conteo,0)+10000000) + COALESCE(CAST(fecha_relacion_persona_ubicaci AS INTEGER),0) AS ID
,  A.TEXTO_UBICACION
, A.Fecha_Relacion_Persona_Ubicaci
,A.Numero_entidades_que_Reportan 		
,A.Id_Buro_Persona
,A.Cod_DW_Tipo_Ubicacion_Dir
,A.Cod_DW_Municipio
,ROW_NUMBER ()OVER (PARTITION BY a.Id_Buro_Persona,a.Texto_Ubicacion,a.Cod_DW_Tipo_Ubicacion_Dir,a.Cod_DW_Municipio 
 ORDER BY ID ) AS ORDEN
,a.Cod_DW_Ubic		
,COMPLEMENTO
FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_C  A
 LEFT JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E063_C1 B ON A.Cod_DW_Persona_Ubic=B.Cod_DW_Persona_Ubic
)AS U1
			 	--QUALIFY EMPATE=1
)WITH DATA
PRIMARY INDEX(Id_Buro_Persona,Texto_Ubicacion,Cod_DW_Tipo_Ubicacion_Dir,Cod_DW_Municipio,Cod_DW_Persona_Ubic ,Cod_DW_Ubic)
;'
;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063_D'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



---------------------------
-- Busca y borra si existe la tabla Tmp_Unificacion_E063_E
---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'Tmp_Unificacion_E063_E' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.Tmp_Unificacion_E063_E';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	


	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E063_E
AS(
SELECT B.COD_DW_PERSONA_UBIC
,A.COD_DW_PERSONA_UBIC AS ID_PADRE
			  FROM '||P_BDSTAGE||'.Tmp_Unificacion_E063_D A
			   INNER JOIN '||P_BDSTAGE||'.Tmp_Unificacion_E063_D B
			   	  ON A.Id_Buro_Persona			  =  B.Id_Buro_Persona				 
				AND A.Texto_Ubicacion			          =  B.Texto_Ubicacion			         
				AND A.Cod_DW_Tipo_Ubicacion_Dir	  =  B.Cod_DW_Tipo_Ubicacion_Dir	     
				AND A.Cod_DW_Municipio			  =  B.Cod_DW_Municipio			    
				AND A.COD_DW_UBIC				  =  B.COD_DW_UBIC				  
				AND A.Cod_DW_Persona_Ubic	          <>B.Cod_DW_Persona_Ubic			 
        			AND  A.ID > B.ID
			  QUALIFY (MAX(A.ORDEN ) OVER(PARTITION BY A.Id_Buro_Persona			
,A.Texto_Ubicacion			        
,A.Cod_DW_Tipo_Ubicacion_Dir	
,A.Cod_DW_Municipio			
,A.COD_DW_UBIC) )=A.ORDEN 
)WITH DATA;'
	;
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_E063_E'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	SET V_CADENA = '';
	--Se actualizÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â¡n los registros unificados en la muestra total de datos. 
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.Tmp_Unificacion_E2
					SET ID_PADRE   	    = Tmp_Unificacion_E063_E.ID_PADRE
					  ,Ind_Unificacion 	= ''S''
					  ,N_ID        = ''F1''
					  
					WHERE '||P_BDSTAGE||'.Tmp_Unificacion_E2.COD_DW_PERSONA_UBIC = '||P_BDSTAGE||'.Tmp_Unificacion_E063_E.COD_DW_PERSONA_UBIC
					AND '||P_BDSTAGE||'.Tmp_Unificacion_E2.ID_PADRE IS NULL
					;';
					
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.3):.Crear y carga la tabla Tmp_Unificacion_4'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 


----------------------------------------------------------------------------------------------------------
---------------- Fin escenario 6 subcaso 3 --------------------------------------------------------
----------------------------------------------------------------------------------------------------------	


	
	----------------#5 ------------------------------------------------------
	------ ValidaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n padres huerfanos --------------------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_PADRES_H' ;

	IF ACTIVITY_COUNT > 0 THEN
	SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.TMP_PADRES_H';
	CALL DBC.SysExecSQL(:V_CADENA);
	END IF;


	------ ValidaciÃ¸ÂŠÃ´ÅšÃ¸ÂÝÃ´Â³n padres huerfanos
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.TMP_PADRES_H AS (
	SELECT UNI.Cod_DW_Persona_Ubic
	FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 VU
	RIGHT JOIN (
	SELECT VU.COD_DW_PERSONA_UBIC 
	FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 VU
	LEFT JOIN '||P_BDSTAGE||'.tmpINSUMO_UNI_REG2 UNI
	ON VU.COD_dW_PERSONA_UBIC=UNI.Cod_DW_Persona_Ubic
	WHERE UNI.Cod_DW_Persona_Ubic IS NULL
	) UNI ON UNI.COD_DW_PERSONA_UBIC = VU.ID_PADRE
	WHERE VU.ID_PADRE IS NULL
	)WITH DATA;';	

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 PH: Crea la tabla TMP_PADRES_H'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;        
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 


	SET V_CADENA = '';
	SET V_CADENA = 'DELETE FROM '||P_BDSTAGE||'.Tmp_Unificacion_E2 WHERE COD_DW_PERSONA_UBIC IN (SELECT Cod_DW_Persona_Ubic FROM '||P_BDSTAGE||'.TMP_PADRES_H);';	

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 PH: Limpia padres Huerfanos'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;        
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 
		
	
    ---------------------------
    -- Se crea la tabla R2_Vstg_Unificacion
    ---------------------------
    --Se Crea la tabla para consimir en TPT. 
    SET V_CADENA = '';
	SET V_CADENA = 'RENAME TABLE '||P_BDSTAGE||'.Tmp_Unificacion_E2 TO '||P_BDSTAGE||'.R2_Vstg_Unificacion;';	

   CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 (6.4): crea la tabla R2_Vstg_Unificacion'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 
	
	---------------------------
	--2018-06-19
    -- Busca y borra si existe la tabla TMP_Unificacion_Complementos
    ---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_Unificacion_Complementos' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.TMP_Unificacion_Complementos';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_Unificacion_Complementos
					AS 
					(SEL sum(1) over(rows unbounded preceding) idx,a.*
					 FROM (SEL oreplace(Complemento, ''  '', '' '') SEtComplemento, 
								oreplace(REC_VISTA.SetComplement(SEtComplemento),''  '', '' '')  Comple_Adju
						  FROM '||P_BDSTAGE || '.R2_Vstg_Unificacion
						  WHERE trim(SEtComplemento) <> trim(Comple_Adju) 
						  AND complemento is not null
						  Group by 1, 2) A    
					)WITH DATA 
					PRIMARY INDEX(idx);';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.5):.Crear y carga la tabla TMP_Unificacion_Complementos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE 
	AND TABLENAME = 'TMP_Unificacion_Complementos' ;

	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.TMP_Unificacion_Complementos';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
    
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE || '.TMP_Unificacion_Complementos
					AS 
					(SEL sum(1) over(rows unbounded preceding) idx,a.*
					 FROM (SEL oreplace(Complemento, ''  '', '' '') SEtComplemento, 
								oreplace(REC_VISTA.SetComplement(SEtComplemento),''  '', '' '')  Comple_Adju
						  FROM '||P_BDSTAGE || '.R2_Vstg_Unificacion
						  WHERE trim(SEtComplemento) <> trim(Comple_Adju) 
						  AND complemento is not null
						  Group by 1, 2) A    
					)WITH DATA 
					PRIMARY INDEX(idx);';
				
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'PRO_UnificacionR2 (6.51):.Crear y carga la tabla TMP_Unificacion_Complementos'
			,V_ERROR);
			
	SET P_ERROR = V_ERROR;
        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	
	SET V_CADENA = '';
	SET V_CADENA = 'COLLECT STAT '||P_BDSTAGE||'.TMP_Unificacion_Complementos INDEX(Idx);';	

   CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 (6.6): Ejecutando estadisticas en TMP_Unificacion_Complementos'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 
   
    SET V_CADENA = '';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.R2_Vstg_Unificacion
					FROM '||P_BDSTAGE||'.TMP_Unificacion_Complementos
					 SET complemento = Comple_Adju
					WHERE oreplace(complemento, ''  '', '' '') = SetComplemento;';	

   CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_UnificacionR2 (F): Actualizando campo COMPLEMENTO en R2_Vstg_Unificacion'
									,V_ERROR);
			
	SET P_ERROR = V_ERROR;        
        IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	 
	
------------------------------------------------------------------------------------------------------------
-------- IDENTIFICACION REGISTRO EXISTENTE DIRECCION_FISICA Y RELACION_PERSONA_UBICACION -------------------
--SI un complemento que fue creado como nuevo, ya existe en direcciÃ¸Â³n fisica se herada el COD_DW_DIRECCION_FISICA de la tabla direcciÃ¸Â³n fisica para no duplicar registros en direccion_fisica. 
--Si un  complemento que fue creado como nuevo ya esta relacionado a una persona se hereda el COD_dW_RELACION_PERSONA_UBICACION y se elmina la nueva relaciÃ¸Â³n que fue creada ya que no se necesita. 
-- ejemplo 
--dire 1 ="BR BOSA S CONJ NUEVO RECREO ET 2 TO 5 AP 201"
--dire 2 ="BL 5 AP 201"
--new_dir ="BR BOSA S CONJ NUEVO RECREO ET 2 TO 5 AP 201 BL 5 AP 201"
--NEW dir despues de limpieza  "BR BOSA S CONJ NUEVO RECREO ET 2 TO 5 AP 201"
--por lo tanto se elimina new_dir y se deja como papÃ¸Â¡ dir 1
------------------------------------------------------------------------------------------------------------

-----------------COLLECT STATS R2_Vstg_Unificacion -------------------------------------------------------------------------------
SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_BURO_PERSONA,COD_DW_TIPO_UBICACION_DIR) ON REC_STAGE.R2_Vstg_Unificacion;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS R2_Vstg_Unificacion ID_BURO_PERSONA,COD_DW_TIPO_UBICACION_DIR',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA=' COLLECT  STATISTICS COLUMN (COD_DW_UBIC ,COMPLEMENTO) ON REC_STAGE.R2_Vstg_Unificacion;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS R2_Vstg_Unificacion COD_DW_UBIC ,COMPLEMENTO',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA=' COLLECT  STATISTICS COLUMN (ROW_U) ON     REC_STAGE.R2_Vstg_Unificacion;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS R2_Vstg_Unificacion (ROW_U) ',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_PADRE) ON   REC_STAGE.R2_Vstg_Unificacion;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS R2_Vstg_Unificacion (ID_PADRE)',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA=' COLLECT  STATISTICS COLUMN (COD_DW_PERSONA_UBIC) ON REC_STAGE.R2_Vstg_Unificacion;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS R2_Vstg_Unificacion (COD_DW_PERSONA_UBIC)',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
------------------FIN STATS R2_Vstg_Unificacion ----------------------------------------------------------------------------------------------


SELECT TABLENAME  INTO :Temp FROM dbc.tables WHERE databasename =:P_BDSTAGE  AND TABLENAME = 'TMP_Unificacion_Nuevos_comple1' ;  IF ACTIVITY_COUNT > 0 THEN
 SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.TMP_Unificacion_Nuevos_comple1'; CALL DBC.SysExecSQL(:V_CADENA); END IF;


SET V_CADENA= 'CREATE  MULTISET TABLE REC_STAGE.TMP_Unificacion_Nuevos_comple1 AS (
SELECT
CL.Cod_DW_Persona_Ubic AS Cod_DW_Persona_Ubic1
,ID_PADRE 			
,CASE WHEN ROW_U=-99  AND RPU.Cod_DW_Persona_Ubic IS NOT NULL THEN RPU.Cod_DW_Persona_Ubic ELSE NULL END AS ID_ACT_COD_DW_PERSONA_UBIC
,CASE WHEN ID_ACT_COD_DW_PERSONA_UBIC <> CL.Cod_DW_Persona_Ubic THEN 1 ELSE 0 END AS ID_ELIMINACION
,CL.Id_Buro_Persona               
,CL.Cod_DW_Tipo_Ubicacion_Dir     
,CL.Cod_DW_Ubic                   
,CL.Texto_Ubicacion               
,NVL(DF.Cod_DW_Direccion_Fisica,CL.Cod_DW_Direccion_Fisica) AS Cod_DW_Direccion_Fisica
,CL.Complemento                   
,CL.Cod_DW_Doc_Ident              
,CL.Cod_Tipo_Ident_Fte            
,CL.Cod_DW_Municipio              
,CL.Numero_entidades_que_Reportan 
,CL.Fecha_Relacion_Persona_Ubicaci
,CL.Ind_Unificacion               
,CL.ROW_U                         
,CL.N_ID                          
FROM REC_STAGE.R2_Vstg_Unificacion CL
LEFT JOIN REC_DATOS.DIRECCION_FISICA  DF
	ON 	 DF.Cod_DW_Ubic= CL.Cod_DW_Ubic
	AND  DF.Complemento = CL.Complemento
	AND CL.ROW_U=-99
LEFT JOIN REC_DATOS.RELACION_PERSONA_UBICACION RPU
	ON   CL.Id_Buro_Persona  				= RPU.Id_Buro_Persona
	AND DF.Cod_DW_Ubic  				= RPU.Cod_DW_Ubic
	AND DF.Cod_DW_Direccion_Fisica  		= RPU.Cod_DW_Direccion_Fisica
	AND CL.Cod_DW_Tipo_Ubicacion_Dir		= RPU.Cod_DW_Tipo_Ubicacion_Dir		
WHERE (ROW_U=-99 OR NOT (CL.Cod_DW_Persona_Ubic IS NULL OR CL.ID_PADRE IS NULL))
)WITH DATA 
PRIMARY INDEX (Cod_DW_Persona_Ubic1)

;';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): CREATE TMP_Unificacion_Nuevos_comple1',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SET V_CADENA= 'COLLECT STATISTICS COLUMN (COD_DW_UBIC) ON  REC_STAGE.TMP_Unificacion_Nuevos_comple1;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 ID_PADRE',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

SELECT TABLENAME  INTO :Temp FROM dbc.tables WHERE databasename =:P_BDSTAGE  AND TABLENAME = 'TMP_Unificacion_VIA_DIR' ;  IF ACTIVITY_COUNT > 0 THEN
 SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.TMP_Unificacion_VIA_DIR'; CALL DBC.SysExecSQL(:V_CADENA); END IF;


SET V_CADENA= 'CREATE MULTISET TABLE REC_STAGE.TMP_Unificacion_VIA_DIR AS (
SELECT 
Cod_DW_Ubic                   
,Tipo_Via_Principal            
,Via_Principal                 
,Via_Generadora                
,Numero_Puerta                 
FROM REC_DATOS.direccion_fisica DF
WHERE EXISTS (SELECT 1 FROM REC_STAGE.TMP_Unificacion_Nuevos_comple1 STG WHERE STG.COD_dW_UBIC=DF.COD_DW_UBIC AND STG.ROW_U=-99)
QUALIFY (ROW_NUMBER() OVER(PARTITION BY Cod_DW_Ubic ORDER BY Cod_DW_Direccion_Fisica))=1
)WITH DATA
UNIQUE PRIMARY INDEX(COD_DW_UBIC)
;';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): CREATE TMP_Unificacion_VIA_DIR',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 




-----------------COLLECT STATS TMP_Unificacion_Nuevos_comple1 -------------------------------------------------------------------------------
SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_PADRE) ON REC_STAGE.TMP_Unificacion_Nuevos_comple1;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 ID_PADRE',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
                                                                                                                                
SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_ELIMINACION ,COD_DW_PERSONA_UBIC1)    ON REC_STAGE.TMP_Unificacion_Nuevos_comple1;'; 
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 ID_ELIMINACION ,COD_DW_PERSONA_UBIC',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
                                                                                                                                
SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_ELIMINACION ,ID_PADRE) ON REC_STAGE.TMP_Unificacion_Nuevos_comple1;';               
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 ID_ELIMINACION ,ID_PADRE',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
                                                                                                                                
SET V_CADENA=' COLLECT  STATISTICS COLUMN (ID_ELIMINACION) ON  REC_STAGE.TMP_Unificacion_Nuevos_comple1;';                        
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 ID_ELIMINACION',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
                                                                                                                                
SET V_CADENA=' COLLECT  STATISTICS COLUMN (COD_DW_PERSONA_UBIC1) ON REC_STAGE.TMP_Unificacion_Nuevos_comple1;';                    
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): STATS TMP_Unificacion_Nuevos_comple1 COD_DW_PERSONA_UBIC',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
---------------FIN COLLECT STATS TMP_Unificacion_Nuevos_comple1 ------------------------------------------------------------------------------


-- SE RENOMBRA LA TABLA REC_STAGE.R2_Vstg_Unificacion ------------------------------------------------------------------------

SELECT TABLENAME  INTO :Temp FROM dbc.tables WHERE databasename =:P_BDSTAGE  AND TABLENAME = 'R2_Vstg_Unificacion_ANT' ;  IF ACTIVITY_COUNT > 0 THEN
 SET V_CADENA = 'DROP TABLE '||P_BDSTAGE || '.R2_Vstg_Unificacion_ANT'; CALL DBC.SysExecSQL(:V_CADENA); END IF;

SET V_CADENA=' RENAME TABLE REC_STAGE.R2_Vstg_Unificacion TO REC_STAGE.R2_Vstg_Unificacion_ANT ;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1): RENAME R2_Vstg_Unificacion TO R2_Vstg_Unificacion_ANT ',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 
------------------------------------------------------------------------------------------------------------------------------------


SET V_CADENA= 'CREATE  MULTISET TABLE REC_STAGE.R2_Vstg_Unificacion AS (
SELECT NVL(T1.ID_ACT_Cod_DW_Persona_Ubic,STG.Cod_DW_Persona_Ubic1) AS Cod_DW_Persona_Ubic
,CASE WHEN Cod_DW_Persona_Ubic=NEW_PADRE THEN NULL ELSE NEW_PADRE END AS ID_PADRE
,STG.Id_Buro_Persona               
,STG.Cod_DW_Tipo_Ubicacion_Dir     
,STG.Cod_DW_Ubic                   
,STG.Texto_Ubicacion               
,MIN(STG.Cod_DW_Direccion_Fisica) OVER (PARTITION BY STG.COD_DW_UBIC,STG.COMPLEMENTO) AS Cod_DW_Direccion_Fisica       
,STG.Complemento                   
,STG.Cod_DW_Doc_Ident              
,STG.Cod_Tipo_Ident_Fte            
,STG.Cod_DW_Municipio              
,STG.Numero_entidades_que_Reportan 
,STG.Fecha_Relacion_Persona_Ubicaci
,STG.Ind_Unificacion               
,STG.ROW_U                         
,STG.N_ID                          
,CASE WHEN STG.ROW_U=-99 THEN (ROW_NUMBER()OVER(PARTITION BY STG.COD_DW_UBIC,STG.COMPLEMENTO  ORDER BY STG.Cod_DW_Persona_Ubic1 )) ELSE 0 END SEVERIDAD_DIR_FISICA
,VDIR.Tipo_Via_Principal            
,VDIR.Via_Principal                 
,VDIR.Via_Generadora                
,VDIR.Numero_Puerta                 
,NVL(T2.ID_ACT_Cod_DW_Persona_Ubic,STG.ID_PADRE) AS NEW_PADRE
FROM REC_STAGE.TMP_Unificacion_Nuevos_comple1 STG
 LEFT JOIN  (SELECT Cod_DW_Persona_Ubic1, ID_ACT_Cod_DW_Persona_Ubic 
 FROM REC_STAGE.TMP_Unificacion_Nuevos_comple1  WHERE ID_ELIMINACION=1
 ) T1 -- ACTUALIZAR EL REGISTRO HIJO CON LOS Cod_DW_Persona_Ubic1 Existentes
 ON STG.Cod_DW_Persona_Ubic1=T1.Cod_DW_Persona_Ubic1
 
 LEFT JOIN  (SELECT Cod_DW_Persona_Ubic1, ID_ACT_Cod_DW_Persona_Ubic
 FROM REC_STAGE.TMP_Unificacion_Nuevos_comple1  WHERE ID_ELIMINACION=1
 ) T2 -- ACTUALIZAR EL REGISTRO PADRE con los Cod_DW_Persona_Ubic1
 ON STG.ID_PADRE=T2.Cod_DW_Persona_Ubic1
 
 LEFT JOIN REC_STAGE.TMP_Unificacion_VIA_DIR AS VDIR
 ON VDIR.COD_DW_UBIC=STG.COD_DW_UBIC
 AND STG.ROW_U=-99 
 
WHERE ID_ELIMINACION=0 --- se eliminan los nuevos registros que ya no se requieren por que la relaciÃ¸Â³n persona ubicacion ya existe
) WITH DATA
PRIMARY INDEX (Cod_DW_Persona_Ubic)
;';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'PRO_UnificacionR2 (F1):CREATE R2_Vstg_Unificacion',V_ERROR);SET P_ERROR = V_ERROR; IF CHARACTER_LENGTH(V_ERROR) > 0 THEN LEAVE L1; END IF;	 

-------------------------- FIN IDENTIFICACION REGISTRO EXISTENTE DIRECCION_FISICA Y RELACION_PERSONA_UBICACION ----------------------------------------------------
	
	
END L1;
    
END;

