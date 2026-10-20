--<ScriptOptions statementTerminator=";"/>

REPLACE   PROCEDURE REC_DATOS.PRO_Cursor_caract


	(
		IN	P_Lote			INTEGER
		,IN	P_StartTimeStampPadre	VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDDATOS		VARCHAR(20)
		,IN	P_BDVISTA 		VARCHAR(20)
		,IN	P_BDSTAGE		VARCHAR(20)
		,OUT	P_ERROR			VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	Realizar la ejecuci?n de los scripts de la tabla Caracteristicas de 
				acuerdo al orden establecido.
 * Fecha:		2016/11/09
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_Cursor_caract
 * 
 * 
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
 * 
 * ################################################################################
 */


BEGIN
------------------------
-- Declaracion de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE V_ID			INTEGER;
	DECLARE V_TABLA			VARCHAR(100);
	DECLARE V_Cod			VARCHAR(100);
	DECLARE V_Desc   		VARCHAR(100);
	DECLARE V_SQL     		VARCHAR(32000);
	DECLARE DROP_TMPS NO SCROLL CURSOR
	FOR the_statement1;
	
	DECLARE Cur_Caract NO SCROLL CURSOR
	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Limpieza de Ambiente Borrado de tablas temporales  ----------------------
-------------------------------------------------------------------------------------------------------------------------------

	SET V_CADENA =  'SELECT * FROM REC_STAGE.DROP_TMP_CARACTERISTICA
					';
	
	PREPARE the_statement1 FROM V_CADENA;

	OPEN DROP_TMPS;
	
	CUR1:LOOP
		FETCH DROP_TMPS INTO V_ID, V_TABLA;
		
		IF SQLCODE <> 0 THEN LEAVE CUR1;
		END IF;
				
	SELECT TABLENAME
	INTO :P_ERROR
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = V_TABLA ;



	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.'||V_TABLA||';';


	CALL DBC.SysExecSQL(:V_CADENA);

/*
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Drop tabla '||P_BDSTAGE||'.'||V_TABLA||';'
			,V_ERROR);
*/	
--	SET P_ERROR = V_ERROR;

	IF SQLCODE NOT IN (0, 7632) 
		THEN		
		SET V_CADENA1 = V_CADENA;
		SET P_ERROR = 'ERROR: '|| SQLCODE || '. Error en el borrado de las tablas temporales =  ' || V_CADENA1;
		LEAVE L1;
	END IF; 
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;

	END IF;
		
	END LOOP CUR1;

	CLOSE DROP_TMPS;


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor Creaci?n de caracteristicas --------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  Cod_Caracteristica_Fte,Descripcion_Caracteristica,SQL_String
					FROM '||P_BDDATOS||'.CARACTERISTICA 
					ORDER BY 1,2 ;
					';
	PREPARE the_statement FROM V_CADENA;
	OPEN Cur_Caract ;

	CUR2:LOOP
		FETCH Cur_Caract  INTO V_Cod, V_Desc,V_SQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

	
		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
			

		SET P_ERROR=V_CADENA;			


	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Drop tabla '||P_BDSTAGE||'.'||V_TABLA||';'
				,V_ERROR);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
	END LOOP CUR2;

	CLOSE Cur_Caract ;
	


/*
CALL DBC.SysExecSQL(:V_CADENA);
*/

END L1;
    
END;

REPLACE PROCEDURE REC_DATOS.PRO_Cursor_caracteristicaDirec
 (IN	P_Lote			INTEGER
	,IN	P_StartTimeStampPadre	VARCHAR(20)
	,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN	P_BDDATOS		VARCHAR(20)
	,IN	P_BDVISTA 		VARCHAR(20)
	,IN	P_BDSTAGE		VARCHAR(20)
	,OUT	P_ERROR			VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo: Realizar la ejecuci?n de los scripts de la tabla Caracteristicas de 
 *           Direccion fisica acuerdo al orden establecido.
 * Fecha:		2018/10/08
 * Realizado por: Fernando Garrido M.
 * Proyecto:	Reconocer Master.
 * Script:		PRO_Cursor_caracteristicaDirec
 *  
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		 Objetivo			Realizado por
 * 2018-10-08    Version Inicial    Fernando Garrido M.
 * 2023-01-31    Setear variables    Omar Delgado.
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2018 Equipo Teradata - Experian
 * 
 * ################################################################################
 */
BEGIN
------------------------
-- Declaracion de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE V_ID			INTEGER;
	DECLARE V_TABLA			VARCHAR(100);
	DECLARE V_Cod			VARCHAR(100);
	DECLARE V_Desc   		VARCHAR(100);
	DECLARE V_SQL     		VARCHAR(32000);
	DECLARE DROP_TMPS NO SCROLL CURSOR
	FOR the_statement1;
	
	DECLARE Cur_Caract NO SCROLL CURSOR
	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_Cod = '';
	SET V_Desc = '';
	SET V_SQL = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');	
	
	
	------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------- Cursor Creaci?n de caracteristicas  Dir--------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA =  'SELECT  Cod_Caracteristica_Fte,Descripcion_Caracteristica,SQL_String
					FROM '||P_BDDATOS||'.CARACTERISTICA 
					WHERE Cod_Caracteristica_Fte = ''1.3- Calc Caracteristica_Direc''
					ORDER BY 1,2;';
					
	PREPARE the_statement FROM V_CADENA;
	OPEN Cur_Caract ;

	CUR2:LOOP
		FETCH Cur_Caract  INTO V_Cod, V_Desc,V_SQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;
		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
			
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										, 'Paso: '||V_Desc
										,V_ERROR);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
	  END LOOP CUR2;
	CLOSE Cur_Caract;
	
END L1;
    
END;

REPLACE PROCEDURE REC_DATOS.PRO_Cursor_caracteristicaEmail
 (IN	P_Lote			INTEGER
	,IN	P_StartTimeStampPadre	VARCHAR(20)
	,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN	P_BDDATOS		VARCHAR(20)
	,IN	P_BDVISTA 		VARCHAR(20)
	,IN	P_BDSTAGE		VARCHAR(20)
	,OUT	P_ERROR			VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo: Realizar la ejecuci?n de los scripts de la tabla Caracteristicas de 
 *           Email acuerdo al orden establecido.
 * Fecha:		2018/10/08
 * Realizado por: Fernando Garrido M.
 * Proyecto:	Reconocer Master.
 * Script:		PRO_Cursor_caracteristicaEmail
 *  
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		 Objetivo			Realizado por
 * 2018-10-08    Version Inicial    Fernando Garrido M.
 * 2023-01-31    Setear variables    Omar Delgado.
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2018 Equipo Teradata - Experian
 * 
 * ################################################################################
 */
BEGIN
------------------------
-- Declaracion de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE V_ID			INTEGER;
	DECLARE V_TABLA			VARCHAR(100);
	DECLARE V_Cod			VARCHAR(100);
	DECLARE V_Desc   		VARCHAR(100);
	DECLARE V_SQL     		VARCHAR(32000);
	DECLARE DROP_TMPS NO SCROLL CURSOR
	FOR the_statement1;
	
	DECLARE Cur_Caract NO SCROLL CURSOR
	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_Cod = '';
	SET V_Desc = '';
	SET V_SQL = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');		
	
	------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------- Cursor Creaci?n de caracteristicas Email --------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA =  'SELECT  Cod_Caracteristica_Fte,Descripcion_Caracteristica,SQL_String
					FROM '||P_BDDATOS||'.CARACTERISTICA 
					WHERE Cod_Caracteristica_Fte = ''1.1- Calc Caracteristica_Mail''
					ORDER BY 1,2;';
					
	PREPARE the_statement FROM V_CADENA;
	OPEN Cur_Caract ;

	CUR2:LOOP
		FETCH Cur_Caract  INTO V_Cod, V_Desc,V_SQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;
		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
			
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										, 'Paso: '||V_Desc
										,V_ERROR);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
	  END LOOP CUR2;
	CLOSE Cur_Caract;
	
END L1;
    
END;

REPLACE   PROCEDURE REC_DATOS.PRO_Cursor_caracteristicaMovil
 (IN	P_Lote			INTEGER
															,IN	P_StartTimeStampPadre	VARCHAR(20)
															,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
															,IN	P_BDDATOS		VARCHAR(20)
															,IN	P_BDVISTA 		VARCHAR(20)
															,IN	P_BDSTAGE		VARCHAR(20)
															,OUT	P_ERROR			VARCHAR(32000)
															)
/*
 * ################################################################################
 * 
 * Objetivo: Realizar la ejecuci?n de los scripts de la tabla Caracteristicas de 
 *           Movil acuerdo al orden establecido.
 * Fecha:		2018/10/08
 * Realizado por: Fernando Garrido M.
 * Proyecto:	Reconocer Master.
 * Script:		PRO_Cursor_caracteristicaMovil
 *  
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		 Objetivo			Realizado por
 * 2018-10-08    Version Inicial    Fernando Garrido M.
 * 2023-01-31    Setear variables    Omar Delgado.
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2018 Equipo Teradata - Experian
 * 
 * ################################################################################
 */
BEGIN
------------------------
-- Declaracion de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE V_ID			INTEGER;
	DECLARE V_TABLA			VARCHAR(100);
	DECLARE V_Cod			VARCHAR(100);
	DECLARE V_Desc   		VARCHAR(100);
	DECLARE V_SQL     		VARCHAR(32000);
	DECLARE DROP_TMPS NO SCROLL CURSOR
	FOR the_statement1;
	
	DECLARE Cur_Caract NO SCROLL CURSOR
	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_Cod = '';
	SET V_Desc = '';
	SET V_SQL = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');	
	
	
	------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------- Cursor Creaci?n de caracteristicas  Dir--------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA =  'SELECT  Cod_Caracteristica_Fte,Descripcion_Caracteristica,SQL_String
					FROM '||P_BDDATOS||'.CARACTERISTICA 
					WHERE Cod_Caracteristica_Fte = ''1.2- Calc Caracteristica_Movil''
					ORDER BY 1,2;';
					
	PREPARE the_statement FROM V_CADENA;
	OPEN Cur_Caract ;

	CUR2:LOOP
		FETCH Cur_Caract  INTO V_Cod, V_Desc,V_SQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;
		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
			
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										, 'Paso: '||V_Desc
										,V_ERROR);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
	  END LOOP CUR2;
	CLOSE Cur_Caract;
	
END L1;
    
END;

REPLACE   PROCEDURE REC_DATOS.PRO_Cursor_caracteristicaTele
(IN	P_Lote			INTEGER
															,IN	P_StartTimeStampPadre	VARCHAR(20)
															,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
															,IN	P_BDDATOS		VARCHAR(20)
															,IN	P_BDVISTA 		VARCHAR(20)
															,IN	P_BDSTAGE		VARCHAR(20)
															,OUT	P_ERROR			VARCHAR(32000)
															)
/*
 * ################################################################################
 * 
 * Objetivo: Realizar la ejecuci?n de los scripts de la tabla Caracteristicas de 
 *           Telefono acuerdo al orden establecido.
 * Fecha:		2018/10/08
 * Realizado por: Fernando Garrido M.
 * Proyecto:	Reconocer Master.
 * Script:		PRO_Cursor_caracteristicaTele
 *  
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		 Objetivo			Realizado por
 * 2018-10-08    Version Inicial    Fernando Garrido M.
 * 2023-01-31    Setear variables    Omar Delgado.
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2018 Equipo Teradata - Experian
 * 
 * ################################################################################
 */
BEGIN
------------------------
-- Declaracion de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE	V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_CADENA1		VARCHAR(10000);
	DECLARE V_ID			INTEGER;
	DECLARE V_TABLA			VARCHAR(100);
	DECLARE V_Cod			VARCHAR(100);
	DECLARE V_Desc   		VARCHAR(100);
	DECLARE V_SQL     		VARCHAR(32000);
	DECLARE DROP_TMPS NO SCROLL CURSOR
	FOR the_statement1;
	
	DECLARE Cur_Caract NO SCROLL CURSOR
	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_Cod = '';
	SET V_Desc = '';
	SET V_SQL = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');	
	
	
	------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------- Cursor Creaci?n de caracteristicas  Dir--------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	
	SET V_CADENA =  'SELECT  Cod_Caracteristica_Fte,Descripcion_Caracteristica,SQL_String
					FROM '||P_BDDATOS||'.CARACTERISTICA 
					WHERE Cod_Caracteristica_Fte = ''1- Calcula Caracteristica_Tele''
					ORDER BY 1,2;';
					
	PREPARE the_statement FROM V_CADENA;
	OPEN Cur_Caract ;

	CUR2:LOOP
		FETCH Cur_Caract  INTO V_Cod, V_Desc,V_SQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;
		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
			
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										, 'Paso: '||V_Desc
										,V_ERROR);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
	  END LOOP CUR2;
	CLOSE Cur_Caract;
	
END L1;
    
END;

