
"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_A"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDVISTA				VARCHAR(20)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,IN	 P_BDMTDAT				VARCHAR(20)
		,IN   P_PLANTILLA         INTEGER
		,IN   P_SOLICITUD         INTEGER
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo:		Extraer la informacion del cubo de direcciones y actualizar el filtro
 *			para marcar la tabla BATCH_CUBO_DIRECCION el campo Filtra_A
 *			, Telefono, Direccion_Electronica, Direccion_Fisica
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_A
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo									Realizado por
 * 23/11/2017	# Historicos Reporte_Ubicacion_Original		Fernando Tafur
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
-- Declaraci??n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);

	
	
L1:	BEGIN

	SET P_ERROR = NULL;
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
		

  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'PRO_BATCH2_FILTRO_A1';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.PRO_BATCH2_FILTRO_A1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE PRO_BATCH2_FILTRO_A1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

---------------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_A1 AS
(
	SEL 
        ID_AUTO
		FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
		WHERE DIRECCION LIKE ANY (SEL ''%''||TRIM(CODIGO_CAMPO)||''%'' 
		                                                                 FROM '||P_BDSTAGE||'.BATCH_DIRECCION_FILTROS
																		 WHERE CODIGO_CAMPO IS NOT NULL
																		 AND ID_SOLICITUD = ' || P_SOLICITUD ||'
																		 AND ID_PLANTILLA = ' || P_PLANTILLA ||'
																		 )
    UNION 
	
	SEL 
		ID_AUTO
		FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
		WHERE TRIM(DIRECCION) LIKE ANY (SEL ''%''||UPPER(TRIM(CODIGO_TIPO))||''_%''||UPPER(TRIM(VALOR_PARTICULA))||''_%'' 
						                                                             FROM '||P_BDSTAGE||'.BATCH_DIRECCION_FILTROS 
																					 WHERE CODIGO_TIPO IS  NOT NULL 
																					 AND VALOR_PARTICULA IS NOT NULL
																					 AND ID_SOLICITUD = ' || P_SOLICITUD ||'
																		              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
																					 )
  UNION
	SEL 
       ID_AUTO
		FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
		WHERE TRIM(DIRECCION) LIKE ANY (SEL ''%''||UPPER(TRIM(CODIGO_TIPO))||''%'' 
						                                                              FROM '||P_BDSTAGE||'.BATCH_DIRECCION_FILTROS 
																					  WHERE VALOR_PARTICULA IS  NULL 
																					  AND ID_SOLICITUD = ' || P_SOLICITUD ||'
																		              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
																					  )

)
WITH DATA 
PRIMARY INDEX(ID_AUTO)';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla PRO_BATCH2_FILTRO_A1'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	
		

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION   SET FILTRO_A = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_H = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			
		
		
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_A1
				GROUP BY 1
				) B
SET FILTRO_A = 1
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_DIRECCION Campo FILTRO_A'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	




END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_B"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDVISTA				VARCHAR(20)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,IN	 P_BDMTDAT				VARCHAR(20)
		,IN   P_PLANTILLA         INTEGER
		,IN   P_SOLICITUD         INTEGER
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo:		Extraer la informacion del cubo de direcciones y actualizar el filtro
 *			para marcar la tabla BATCH_CUBO_DIRECCION el campo Filtra_B
 *			, Telefono, Direccion_Electronica, Direccion_Fisica
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_B
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo									Realizado por
 * 23/11/2017	# Historicos Reporte_Ubicacion_Original		Fernando Tafur
 * 06/03/2018 	#1 Ajuste para el tamaño.
 * 26/06/2019	#2 Se incluye filtro AND NO_ENTREGADO_X_MESES > 0 para que no aplique filtro B a registros con numero de meses entregado en 0
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
-- Declaraci??n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);

	
	
L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
		

  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'PRO_BATCH2_FILTRO_B';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE PRO_BATCH2_FILTRO_B'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

---------------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B AS
(
SEL ID_AUTO,CAST(''CUBO_TELEFONO'' AS VARCHAR(30)) TIPO  /*#1*/
FROM  '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
WHERE Meses_desde_el_ultimo_Reporte > (SELECT  CAST(TRIM(NO_ENTREGADO_X_MESES) AS INTEGER)
                 FROM   '||P_BDSTAGE||'.BATCH_DATOS_GENERALES
				  WHERE  ID_SOLICITUD = ' || P_SOLICITUD ||'
	              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
		      AND NO_ENTREGADO_X_MESES IS NOT NULL
			  AND NO_ENTREGADO_X_MESES > 0 /*#2*/
				 )
AND Meses_desde_el_ultimo_Reporte IS NOT NULL

UNION 
SEL ID_AUTO,''CUBO_CELULAR'' TIPO
FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
WHERE Meses_desde_el_ultimo_Reporte > (SELECT  CAST(TRIM(NO_ENTREGADO_X_MESES) AS INTEGER)
                 FROM   '||P_BDSTAGE||'.BATCH_DATOS_GENERALES
				  WHERE  ID_SOLICITUD = ' || P_SOLICITUD ||'
	              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
		      AND NO_ENTREGADO_X_MESES IS NOT NULL
			  AND NO_ENTREGADO_X_MESES > 0 /*#2*/
				 )
AND Meses_desde_el_ultimo_Reporte IS NOT NULL

UNION 
SEL ID_AUTO,''CUBO_DIRECCION'' TIPO
FROM  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
WHERE Meses_desde_el_ultimo_Reporte > (SELECT  CAST(TRIM(NO_ENTREGADO_X_MESES) AS INTEGER)
                 FROM   '||P_BDSTAGE||'.BATCH_DATOS_GENERALES
				  WHERE  ID_SOLICITUD = ' || P_SOLICITUD ||'
	              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
		      AND NO_ENTREGADO_X_MESES IS NOT NULL
			  AND NO_ENTREGADO_X_MESES > 0 /*#2*/
				 )
AND Meses_desde_el_ultimo_Reporte IS NOT NULL

UNION
SEL ID_AUTO,''CUBO_CORREO'' TIPO
FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
WHERE Meses_desde_el_ultimo_Reporte > (SELECT  CAST(TRIM(NO_ENTREGADO_X_MESES) AS INTEGER)
                 FROM   '||P_BDSTAGE||'.BATCH_DATOS_GENERALES
				  WHERE  ID_SOLICITUD = ' || P_SOLICITUD ||'
	              AND ID_PLANTILLA = ' || P_PLANTILLA ||'
		      AND NO_ENTREGADO_X_MESES IS NOT NULL
			  AND NO_ENTREGADO_X_MESES > 0 /*#2*/
				 )
AND Meses_desde_el_ultimo_Reporte IS NOT NULL
) WITH DATA
PRIMARY INDEX(ID_AUTO)
INDEX (TIPO)';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla PRO_BATCH2_FILTRO_B'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	






------------------------CUBO TELEFONO		

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO   SET FILTRO_B = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_TELEFONO FILTRO_B = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			
		
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B
				WHERE TIPO = ''CUBO_TELEFONO''
				GROUP BY 1
				) B
SET FILTRO_B = 1
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_TELEFONO Campo FILTRO_B'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



---------------------------CUBO_CELULAR	

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CELULAR   SET FILTRO_B = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CELULAR FILTRO_B = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;				
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B
				WHERE TIPO = ''CUBO_CELULAR''
				GROUP BY 1
				) B
SET FILTRO_B = 1
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CELULAR Campo FILTRO_B'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_DIRECCION

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION   SET FILTRO_B = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_B = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;				
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B
				WHERE TIPO = ''CUBO_DIRECCION''
				GROUP BY 1
				) B
SET FILTRO_B = 1
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_DIRECCION Campo FILTRO_B'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_CORREO

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CORREO   SET FILTRO_B = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CORREO FILTRO_B = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;				
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B
				WHERE TIPO = ''CUBO_CORREO''
				GROUP BY 1
				) B
SET FILTRO_B = 1
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CORREO Campo FILTRO_B'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

-----------------------------------BORRAR TABLA TEMPORAL

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.PRO_BATCH2_FILTRO_B';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE PRO_BATCH2_FILTRO_B'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;




END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_C"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDVISTA				VARCHAR(20)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,IN	 P_BDMTDAT				VARCHAR(20)
		,IN   P_PLANTILLA         INTEGER
		,IN   P_SOLICITUD         INTEGER
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo:		Extraer la informacion del cubo de direcciones y actualizar el filtro
 *			para marcar las tablas BATCH_CUBO_DIRECCION, BATCH_CUBO_TELEFONO, BATCH_CUBO_CORREO, BATCH_CUBO_CELULAR  el campo Filtra_C.
 *			
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur P.
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_C
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo									Realizado por
 * 24/11/2017	# Historicos Reporte_Ubicacion_Original		Alvaro Ariza
 * 17/01/2023   #Update sentencia Replace                   Fernando Garrido
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2017 Equipo Teradata - Capgemini
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE	V_QSQL						VARCHAR	(32000);
	DECLARE	V_DATO						VARCHAR (100);
	DECLARE Temp 						CHAR	(30);
	DECLARE Cur_ARCHIVO_LOG 			NO SCROLL CURSOR 	FOR the_statement;
	
	
	
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸Â³n de ARCHIVO_LOG la tabla BATCH_MOTOR_LOG se carga con un script inicial ---------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT DATO,SQL_STRING
					 FROM '||P_BDSTAGE||'.BATCH_MOTOR_LOG
					  WHERE SQL_STRING IS NOT NULL
					  AND TIPO =''FILTRO-C''
					 ORDER BY ID ;
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_ARCHIVO_LOG ;

	CUR2:LOOP
		FETCH Cur_ARCHIVO_LOG  INTO  V_DATO,V_QSQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

		
-------------------------- CreaciÃ¸Â³n de tablas registros % a insertar ----------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA= 
		
		REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(V_QSQL						
						,'P_BDSTAGE',P_BDSTAGE)
						,'P_ID_SOLICITUD',CAST(P_SOLICITUD AS VARCHAR(20)))
						,'P_ID_PLANTILLA',CAST(P_PLANTILLA AS VARCHAR(20)))					;
						
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Se realiza update al campo'||V_DATO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	END LOOP CUR2;

CLOSE Cur_ARCHIVO_LOG ;
	
END L1;
    
END;"

==============================================================



"REPLACE   PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_D"
"
	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre		VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDDATOS				VARCHAR(20)
		,IN		P_BDVISTA 				VARCHAR(20)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN   	P_PLANTILLA         			INTEGER
		,IN   	P_SOLICITUD         			INTEGER
		,OUT	P_ERROR				VARCHAR(32000)
		
	)
/*
 * ################################################################################
 * 
 * Objetivo:	Actualizar el campo filtro_d de cada uno de los cubos.
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_D
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE V_Desc   					VARCHAR	(100);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE Temp 						CHAR		(30);
	DECLARE V_NOMBRE_CUBO				VARCHAR	(30);
	DECLARE Cur_Filtro_d NO SCROLL CURSOR 	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Limpieza de Ambiente Borrado de tablas temporales  ----------------------
-------------------------------------------------------------------------------------------------------------------------------
/* 
FILTRO D
D-Datos mÃ­nimos de InclusiÃ³n Registro en la salida: En estÃ© filtro se busca excluir todos los registros que NO tengan informaciÃ³n (Nulos)  
en los campos configurados. El filtro se encuentra configurado en la tabla BATCH_SALIDAS_CAMPOS, el campo sobre el que se aplica el 
filtro se encuentra configurado en CODIGO_CAMPO (Columna sobre la que se aplica el filtro)  y el indicador que define si estÃ© campo debe
tener valor diferente a nulo se encuentra en el campo REQUERIDO_CAMPO (Si se encuentra activo 1).
*/
------ CreaciÃ³n de insumos para aplicaciÃ³n de filtros ---------------
----------------------------------------------------------------------------------
/* Borrado de tabla temporal BACTH_FD_1 */


	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FD_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FD_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FD_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------------------------------------------------------------------------
----FiltroD: Se crea la tabla con los filtros por campo y cubo ----------------------------
-------------------------------------------------------------------------------------------


SET V_CADENA = ' ';
SET V_CADENA = 
'CREATE TABLE  ' ||P_BDSTAGE||'.BACTH_FD_1 AS (
SELECT 
ID_SEQUENCIA AS ID
, CAST(MAX(ID_SEQUENCIA) OVER (PARTITION BY CUBO)  AS INTEGER) MAX_ID
  ,CAST(CASE WHEN ID_SEQUENCIA = MAX_ID THEN  HOMOLOGADO || '' IS NULL '' 
    ELSE  HOMOLOGADO || '' IS NULL  OR'' END  
  AS VARCHAR(1000))
  AS FILTRO_SQL
  ,CASE WHEN CUBO=''Celular'' 	THEN  ''BATCH_CUBO_CELULAR''            
   	WHEN CUBO=''Ciiu'' 		THEN  ''BATCH_CUBO_CIIU''               
   	WHEN CUBO=''Correo'' 		THEN  ''BATCH_CUBO_CORREO''             
   	WHEN CUBO=''Direccion'' 	THEN  ''BATCH_CUBO_DIRECCION''          
   	WHEN CUBO=''Persona'' 	THEN  ''BATCH_CUBO_PERSONA''            
   	WHEN CUBO=''Telefono'' 	THEN  ''BATCH_CUBO_TELEFONO''           
END AS NOMBRE_CUBO
,CUBO
FROM  ' ||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS BSC
 INNER JOIN  ' ||P_BDSTAGE||'.BATCH2_HOMOLOGACION B2H
  ON BSC.CODIGO_CAMPO=B2H.CODIGO_CAMPO 
  AND ID_SOLICITUD ='||P_SOLICITUD||'
  AND ID_PLANTILLA ='||P_PLANTILLA||'
WHERE BSC.REQUERIDO_CAMPO=''SI''
) WITH DATA 
;';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_FD_1'
			,V_ERROR);
SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	





---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_FD_2 

	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FD_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FD_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FD_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se crea una consulta recursiva para anidar cada uno de los filtros por cubo -----
-------------------------------------------------------------------------------------
 


SET V_CADENA = ' ';
SET V_CADENA = '
CREATE TABLE  ' ||P_BDSTAGE||'.BACTH_FD_2 AS(

WITH RECURSIVE CONCAT_LIST
( ID
,MAX_ID
,FILTRO_SQL
,NOMBRE_CUBO
,CUBO
,AUTO_ID
) AS

(
  SELECT 
  	 ID
	,MAX_ID
	,FILTRO_SQL
	,NOMBRE_CUBO
	,CUBO
	,1 AS AUTO_ID
  FROM   ' ||P_BDSTAGE||'.BACTH_FD_1

  UNION ALL
  
  SELECT  T1.ID
	,T1.MAX_ID
	,T1.FILTRO_SQL||''0A''XC|| T2.FILTRO_SQL
	,T1.NOMBRE_CUBO
	,T1.CUBO
    ,AUTO_ID+1
  FROM    ' ||P_BDSTAGE||'.BACTH_FD_1 T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.CUBO = T2.CUBO
   WHERE T1.ID< T2.ID
)

SELECT 
''CREATE TABLE  ' ||P_BDSTAGE||'.''||CUBO||''FD AS (
SELECT ID_AUTO 
FROM  ' ||P_BDSTAGE||'.''||NOMBRE_CUBO||''0A''XC||'' WHERE ('' ||CL.FILTRO_SQL||'')) WITH DATA;'' AS Q_SQL
,CL.NOMBRE_CUBO
,CL.CUBO
,CUBO||''FD'' AS TABLA_FILTRO
FROM   CONCAT_LIST CL
QUALIFY (SUM(1)    OVER (PARTITION BY NOMBRE_CUBO ORDER BY CL.AUTO_ID DESC ROWS UNBOUNDED PRECEDING))= 1
) WITH DATA;';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_FD_2'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ³n de filtroD---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  TABLA_FILTRO,Q_SQL,NOMBRE_CUBO
					FROM '||P_BDSTAGE||'.BACTH_FD_2
					ORDER BY 1,2 ;
					';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Filtro_d ;

	CUR2:LOOP
		FETCH Cur_Filtro_d  INTO  V_Desc, V_SQL ,V_NOMBRE_CUBO;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

----------------------------------------------------------------------------------------------------------------
-------------------Borrado de tablas filtroD si existen ------------------------------------------------
----------------------------------------------------------------------------------------------------------------

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = V_Desc;
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.'||V_Desc;
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE '||V_Desc||''
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------- CreaciÃ³n de tablas con los filtros calculados -------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=OREPLACE(OREPLACE(OREPLACE(V_SQL,'REC_STAGE', P_BDSTAGE),'REC_VISTA', P_BDVISTA), 'P_LOTE', CAST(P_Lote AS VARCHAR(12)));
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea tabla '||P_BDSTAGE||'.'||V_Desc||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
---------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------


-------------------------- UPDATE FILTROD=0 --------------------------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA='UPDATE '||P_BDSTAGE||'.'|| V_NOMBRE_CUBO ||' SET FILTRO_D=0;';
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE 0 tabla '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 



-------------------------- UPDATE FILTROD=1 --------------------------------------------------------
-------------------------------------------------------------------------------------------------------------		



		SET V_CADENA='UPDATE A 
						FROM '||P_BDSTAGE||'.'|| V_NOMBRE_CUBO ||'  A 
						 ,'||P_BDSTAGE||'.'||V_Desc||' B 
						 SET FILTRO_D = CASE WHEN B.ID_AUTO IS NOT NULL THEN 1 ELSE 0 END 
						WHERE A.ID_AUTO =B.ID_AUTO 
						';
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE 1 tabla '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 






	END LOOP CUR2;

CLOSE Cur_Filtro_d ;
	


END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_E"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDVISTA				VARCHAR(20)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,IN	 P_BDMTDAT				VARCHAR(20)
		,IN    P_PLANTILLA         INTEGER
		,IN    P_SOLICITUD         INTEGER
		,IN    P_TIPOPERSONA  VARCHAR(1)
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo:		Extraer la informacion del cubo de direcciones y actualizar el filtro
 *			para marcar la tabla BATCH_CUBO_DIRECCION el campo Filtra_B
 *			, Telefono, Direccion_Electronica, Direccion_Fisica
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_E
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo									Realizado por
 * 23/11/2017	# Historicos Reporte_Ubicacion_Original		Fernando Tafur
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
-- Declaraci??n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(63000);
	DECLARE Temp					CHAR(30);
	DECLARE V_TP                  INTEGER;
	DECLARE V_CUANTOS    INTEGER;

	
	
L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');



-------------------------------------------------------------------------
-- VALIDA QUE EXISTAN PARAMETROS CONFIGURADOS
/*
SEL COUNT(*) registros
INTO :V_CUANTOS
FROM
(
SEL 
  TRIM(COALESCE(PRC_TEL_PN,'0'))|| 
  TRIM(COALESCE(PRC_CEL_PN,'0'))|| 
  TRIM(COALESCE(PRC_DIR_PN,'0')) ||
  TRIM(COALESCE(PRC_MAIL_PN,'0')) ||
  TRIM(COALESCE(PRC_TEL_PJ,'0'))|| 
  TRIM(COALESCE(PRC_CEL_PJ,'0'))|| 
  TRIM(COALESCE(PRC_DIR_PJ,'0'))|| 
  TRIM(COALESCE(PRC_MAIL_PJ,'0'))|| 
  TRIM(COALESCE(PMD_TEL,'0'))|| 
  TRIM(COALESCE(PMD_CEL,'0'))|| 
  TRIM(COALESCE(PMD_DIR,'0'))|| 
  TRIM(COALESCE(PMD_MAIL,'0'))  EXPRESION
FROM REC_STAGE.BATCH_PORCENTAJES_FILTROS
WHERE ID_SOLICITUD = P_SOLICITUD
AND ID_PLANTILLA = P_PLANTILLA
AND REGEXP_SIMILAR(TRIM(EXPRESION),'[0-9]+')=1
) X;

IF V_CUANTOS = 0 THEN
        SET  V_CADENA='FALLO;';
   		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'VALIDAR Parametrizacion'
		,V_ERROR);
		 SET P_ERROR = V_ERROR;
		--LEAVE L1;
END IF;*/




  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH_CUBO_PERSONA_FILTRO_TP';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH_CUBO_PERSONA_FILTRO_TP'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP AS
(
SEL TIPO_ID,COD_PIN_PERSONA
FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
GROUP BY 1,2
) WITH DATA
PRIMARY INDEX( TIPO_ID,COD_PIN_PERSONA)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla PRO_BATCH2_FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

		
----------------------------------------------		

  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'PRO_BATCH2_FILTRO_E';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE PRO_BATCH2_FILTRO_E'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

----------------------------------------------------------------------

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2_TIPO_PERSONA';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_TIPO_PERSONA';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2_TIPO_PERSONA'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = '';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA AS
(
Select 
      ROW_NUMBER() OVER(PARTITION BY TIPO_PERSONA ORDER BY TIPO_PERSONA ) CONS
	, SUBSTR(UPPER(b.Nombre_Tipo_Persona),1,1)  TIPO_PERSONA
	 ,CAST(a.Cod_Tipo_Ident_Fte AS VARCHAR(1))  TIPO_ID
	 ,TIPO_ID TIPO_ID_X
From '||P_BDVISTA||'.vu_persona a
    Left Join bdm_vista.v_tipo_persona b on a.Cod_DW_Tipo_Persona=b.Cod_DW_Tipo_Persona
Group By 2,3,4
) WITH DATA
PRIMARY INDEX(CONS)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2_TIPO_PERSONA'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

--

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2_TIPO_PERSONA_F';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_F';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2_TIPO_PERSONA_F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

SET V_CADENA = '';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_F 
AS
(
WITH RECURSIVE TIPO_PERSONAS(
                             TIPO_PERSONA,
							 TIPO_ID,
							 CONS
                             ) AS
(
SEL  
TIPO_PERSONA
,CAST(TIPO_ID  AS VARCHAR(200))
,CONS 
FROM   '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA
WHERE CONS IN ( SEL ORDEN
                              FROM(
                             SEL TIPO_PERSONA,MIN(CONS) ORDEN
                             FROM REC_STAGE.BATCH2_TIPO_PERSONA
							 GROUP BY 1) X
							 )
UNION ALL
SEL 	
A.TIPO_PERSONA
,B.TIPO_ID ||'',''||TRIM(A.TIPO_ID)   TIPO_ID
,A.CONS        
FROM  '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA A,
            TIPO_PERSONAS B
WHERE A.TIPO_PERSONA = B.TIPO_PERSONA
AND A.CONS = B.CONS + 1
)
SEL
TIPO_PERSONA
,MAX(TIPO_ID)  TIPO_ID
FROM TIPO_PERSONAS
GROUP BY 1
) WITH DATA
PRIMARY INDEX(TIPO_PERSONA)';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2_TIPO_PERSONA'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2_TIPO_PERSONA_PORC';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2_TIPO_PERSONA_PORC'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC AS
(
SEL 
TIPO_PERSONA
,TIPO_ID
,TO_NUMBER(PRC_TEL_P'||P_TIPOPERSONA||')  TEL
,TO_NUMBER(PRC_DIR_P'||P_TIPOPERSONA||')  DIR
,TO_NUMBER(PRC_CEL_P'||P_TIPOPERSONA||')  CEL
,TO_NUMBER(PRC_MAIL_P'||P_TIPOPERSONA||') MAIL
FROM  
   '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_F TP,
   '||P_BDSTAGE||'.BATCH_PORCENTAJES_FILTROS PORC
WHERE PORC.ID_SOLICITUD = '||P_SOLICITUD||'
AND PORC.ID_PLANTILLA = '||P_PLANTILLA||'
AND TIPO_PERSONA = '''||P_TIPOPERSONA||'''
) WITH DATA
PRIMARY INDEX(TIPO_ID)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2_TIPO_PERSONA_PORC'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

---------------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E AS
(
SELECT 
A.*
,CASE WHEN NUM > 1 THEN 2 ELSE NULL END AS ID
,COUNT(ID) OVER (PARTITION BY NUMERO,TIPO_ID) AS CANT
,MAX(NUM) OVER (PARTITION BY NUMERO,TIPO_ID) AS MAX_NUM
, CANT*1.0/MAX_NUM*1.0 * 100.0 AS PORCENTAJE				
,TEL  PORC_PARAM  									
,cast(PORC_PARAM*MAX_NUM*1.0 / 100.0 AS INTEGER) AS PORCENTAJE_CALCULADO
,CASE WHEN NUM  <=  PORCENTAJE_CALCULADO THEN 1 ELSE 0 END FILTRO
,CASE WHEN PORCENTAJE_CALCULADO = 0 AND FILTRO = 0 THEN 0 
             WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO > 0 THEN 0
			 WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO = 0 THEN 1 END FLAG
,CAST(''CUBO_TELEFONO'' AS CHAR(20)) TIPO			 
FROM (
SEL 
 id_auto
 ,NUMERO
,TE.COD_PIN_PERSONA
,CAST(TP.TIPO_ID AS CHAR(1)) TIPO_IDS
,ROW_NUMBER() OVER(PARTITION BY  NUMERO,TIPO_ID ORDER BY NUMERO ) NUM
FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO TE
LEFT JOIN  '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP TP
ON TE.COD_PIN_PERSONA = TP.COD_PIN_PERSONA
WHERE NUMERO IS NOT NULL
AND TP.TIPO_ID IN (SEL TIPO_ID_X FROM  '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA WHERE TIPO_PERSONA = '''||P_TIPOPERSONA||''')
) A ,
'||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC PORCE

UNION ALL

SELECT 
A.*
,CASE WHEN NUM > 1 THEN 2 ELSE NULL END AS ID
,COUNT(ID) OVER (PARTITION BY NUMERO,TIPO_ID) AS CANT
,MAX(NUM) OVER (PARTITION BY NUMERO,TIPO_ID) AS MAX_NUM
, CANT*1.0/MAX_NUM*1.0 * 100.0 AS PORCENTAJE
,DIR  PORC_PARAM
,CAST(PORC_PARAM*MAX_NUM*1.0 / 100.0 AS INTEGER) AS PORCENTAJE_CALCULADO
,CASE WHEN NUM  <=  PORCENTAJE_CALCULADO THEN 1 ELSE 0 END FILTRO
,CASE WHEN PORCENTAJE_CALCULADO = 0 AND FILTRO = 0 THEN 0 
             WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO > 0 THEN 0
			 WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO = 0 THEN 1 END FLAG
,CAST(''CUBO_DIRECCIONES'' AS CHAR(20)) TIPO				 
FROM (
SEL 
 id_auto
 ,DIRECCION NUMERO
,TE.COD_PIN_PERSONA
,CAST(TP.TIPO_ID AS CHAR(1)) TIPO_IDS
,ROW_NUMBER() OVER(PARTITION BY  NUMERO,TIPO_ID ORDER BY NUMERO ) NUM
FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION TE
LEFT JOIN  '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP TP
ON TE.COD_PIN_PERSONA = TP.COD_PIN_PERSONA
WHERE DIRECCION IS NOT NULL
AND TP.TIPO_ID IN (SEL TIPO_ID_X FROM  '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA WHERE TIPO_PERSONA = '''||P_TIPOPERSONA||''')
) A , 
'||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC PORCE

UNION ALL

SELECT 
A.*
,CASE WHEN NUM > 1 THEN 2 ELSE NULL END AS ID
,COUNT(ID) OVER (PARTITION BY NUMERO,TIPO_ID) AS CANT
,MAX(NUM) OVER (PARTITION BY NUMERO,TIPO_ID) AS MAX_NUM
, CANT*1.0/MAX_NUM*1.0 * 100.0 AS PORCENTAJE
,MAIL  PORC_PARAM
,CAST(PORC_PARAM*MAX_NUM*1.0 / 100.0 AS INTEGER) AS PORCENTAJE_CALCULADO
,CASE WHEN NUM  <=  PORCENTAJE_CALCULADO THEN 1 ELSE 0 END FILTRO
,CASE WHEN PORCENTAJE_CALCULADO = 0 AND FILTRO = 0 THEN 0 
             WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO > 0 THEN 0
			 WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO = 0 THEN 1 END FLAG
,CAST(''CUBO_CORREO'' AS CHAR(20)) TIPO					 
FROM (
 SEL 
 id_auto
 ,CORREO NUMERO
,TE.COD_PIN_PERSONA
,CAST(TP.TIPO_ID AS CHAR(1)) TIPO_IDS
,ROW_NUMBER() OVER(PARTITION BY  NUMERO,TIPO_ID ORDER BY NUMERO ) NUM
FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO TE
LEFT JOIN  '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP TP
ON TE.COD_PIN_PERSONA = TP.COD_PIN_PERSONA
WHERE CORREO IS NOT NULL
AND TP.TIPO_ID IN (SEL TIPO_ID_X FROM  '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA WHERE TIPO_PERSONA = '''||P_TIPOPERSONA||''')
) A , 
'||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC PORCE

UNION ALL

SELECT 
A.*
,CASE WHEN NUM > 1 THEN 2 ELSE NULL END AS ID
,COUNT(ID) OVER (PARTITION BY NUMERO,TIPO_ID) AS CANT
,MAX(NUM) OVER (PARTITION BY NUMERO,TIPO_ID) AS MAX_NUM
, CANT*1.0/MAX_NUM*1.0 * 100.0 AS PORCENTAJE
,CEL  PORC_PARAM
,CAST(PORC_PARAM*MAX_NUM*1.0 / 100.0 AS INTEGER) AS PORCENTAJE_CALCULADO
,CASE WHEN NUM  <=  PORCENTAJE_CALCULADO THEN 1 ELSE 0 END FILTRO
,CASE WHEN PORCENTAJE_CALCULADO = 0 AND FILTRO = 0 THEN 0 
             WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO > 0 THEN 0
			 WHEN PORCENTAJE_CALCULADO > 0 AND FILTRO = 0 THEN 1 END FLAG
,CAST(''CUBO_CELULARES'' AS CHAR(20)) TIPO				 
FROM (
SEL 
 id_auto
 ,NUMERO
,TE.COD_PIN_PERSONA
,CAST(TP.TIPO_ID AS CHAR(1)) TIPO_IDS
,ROW_NUMBER() OVER(PARTITION BY  NUMERO,TIPO_ID ORDER BY NUMERO ) NUM
FROM '||P_BDSTAGE||'.BATCH_CUBO_CELULAR TE
LEFT JOIN  '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP TP
ON TE.COD_PIN_PERSONA = TP.COD_PIN_PERSONA
WHERE NUMERO IS NOT NULL
AND TP.TIPO_ID IN (SEL TIPO_ID_X FROM  '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA WHERE TIPO_PERSONA = '''||P_TIPOPERSONA||''')
) A , '||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC PORCE ) WITH DATA PRIMARY INDEX(ID_AUTO,FLAG,TIPO) INDEX(ID_AUTO,TIPO)';
  

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla PRO_BATCH2_FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------CUBO TELEFONO		

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO   SET FILTRO_E = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_TELEFONO FILTRO_E = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	
		
		
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,FLAG
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E
				WHERE TIPO = ''CUBO_TELEFONO''
				GROUP BY 1,2
				) B
SET FILTRO_E = B.FLAG
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,:P_TIPOPERSONA||' Act.  CUBO_TELEFONO Campo FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



---------------------------CUBO_CELULAR	

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CELULAR   SET FILTRO_E = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CELULAR FILTRO_E = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,FLAG
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E
				WHERE TIPO = ''CUBO_CELULAR''
				GROUP BY 1,2
				) B
SET FILTRO_E = B.FLAG
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,:P_TIPOPERSONA||' Act.  CUBO_CELULAR Campo FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_DIRECCION

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION   SET FILTRO_E = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_DIRECCION FILTRO_E = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	
	
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,FLAG
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E
				WHERE TIPO = ''CUBO_DIRECCION''
				GROUP BY 1,2
				) B
SET FILTRO_E = B.FLAG
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,:P_TIPOPERSONA||' Act.  CUBO_DIRECCION Campo FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_CORREO

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CORREO   SET FILTRO_E = 0';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Actualizando  Tabla BATCH_CUBO_CORREO FILTRO_E = 0'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,FLAG
				FROM  '||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E
				WHERE TIPO = ''CUBO_CORREO''
				GROUP BY 1,2
				) B
SET FILTRO_E = B.FLAG
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,:P_TIPOPERSONA||' Act.  CUBO_CORREO Campo FILTRO_E'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

-----------------------------------BORRAR TABLAS TEMPORALES

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.PRO_BATCH2_FILTRO_E';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE PRO_BATCH2_FILTRO_E'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

----------------


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_CUBO_PERSONA_FILTRO_TP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE BATCH_CUBO_PERSONA_FILTRO_TP'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_TIPO_PERSONA_PORC';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE BATCH2_TIPO_PERSONA_PORC'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;



END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_F"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDVISTA				VARCHAR(20)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,IN	 P_BDMTDAT				VARCHAR(20)
		,IN  P_PLANTILLA         INTEGER
		,IN  P_SOLICITUD         INTEGER
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo:		Extraer la informacion del cubo de direcciones y actualizar el filtro
 *			para marcar la tabla BATCH_CUBO_DIRECCION el campo Filtra_B
 *			, Telefono, Direccion_Electronica, Direccion_Fisica
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_F
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo									Realizado por
 * 23/11/2017	# Historicos Reporte_Ubicacion_Original		Fernando Tafur
 * 23/11/2017	#1 Ajuste nombre campos					
 * 11/04/2019   #3 Ajustes en filtros para salida de        Jeimmy Chavez
 *                 informacion de batch validacion                        
 * 12/04/2019   #4 Se ajusta calculo porcentaje similitud   Fernando Garrido.
 *                 Direccions  
 * 23/04/2019   #5 Se ajusta el calculo del de Porcentaje   Fernando Garrido.
 *               similitud Emails 
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
-- Declaraci??n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(33000);
	DECLARE Temp					CHAR(30);
	DECLARE Cuantos           INTEGER;

	
	
L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = Cast(P_StartTimeStampPadre AS TIMESTAMP(6) Format 'yyyy-mm-ddhh:mi:ss');


-------------------------------------------------------------------------------------------------------------------------------------------
/* VALIDACION: SI LA TABLA STG_INSUMO_BATCH_VALIDACION SE ENCUENTRA VACIA NO PROCESA NADA*/
-------------------------------------------------------------------------------------------------------------------------------------------

SEL Registros
INTO : Cuantos
FROM
(SEL  Count(*) Registros
FROM REC_STAGE.STG_INSUMO_BATCH_VALIDACION) X;


IF CUANTOS = 0 THEN
        SET  V_CADENA='DELETE '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION;';
   		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'NO HAY DATOS FILTRO #F'
		,V_ERROR);
		 SET P_ERROR = V_ERROR;
		-- LEAVE L1;
END IF;


  SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_CLIENTE_1';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_CLIENTE_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_CLIENTE_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_CLIENTE_1 AS
(
SEL TIPO_ID
,Cast(NUMERO_ID AS BIGINT) AS NUMERO_ID /*#3 casteo a bigint*/
,COD_PIN_PERSONA
FROM  '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
GROUP BY 1,2,3
) WITH DATA
PRIMARY INDEX( TIPO_ID,NUMERO_ID,COD_PIN_PERSONA)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_CLIENTE_1 F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------ CUBO DIRECCION ----------------
--1
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_DIR_2';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_DIR_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_DIR_2 F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

--2 #1 actualizaciÃ¸ÆÃ´Â³n nombre de campo DIR_INSUMO_STD_000
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_DIR_2 AS
(
SEL  
BO.COD_PIN_PERSONA
,CL.DIR_INSUMO_STD_000 DIR_INSUMO_STD
,CL.NUMERO_ID
FROM  '||P_BDSTAGE||'.FILTRO_CLIENTE_1 BO
LEFT JOIN  '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION CL
ON CL.TIPO_ID = BO.TIPO_ID
AND Cast(CL.NUMERO_ID AS BIGINT)  = BO.NUMERO_ID /*#3 casteo a bigint*/
WHERE CL.DIR_INSUMO_STD_000 IS NOT NULL
GROUP BY 1,2,3
) WITH DATA
PRIMARY INDEX (COD_PIN_PERSONA,DIR_INSUMO_STD)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_DIR_2 F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			
		

--3
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_3_CALC';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALC';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_3_CALC F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

		
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE  ' ||P_BDSTAGE||'.FILTRO_3_CALC 
				 AS
				(SEL DIR.ID_AUTO                       
						  ,DIR.Cod_Pin_Persona               
						  ,DIR.Direccion                     
						  ,DIR.DIR_INSUMO_STD                
						  ,DIR.DirInsumoIn                   
						  ,DIR.DirBodegaIn                   
						  ,DIR.PorHitMz0In                   
						  ,DIR.PorDisMz0In                   
						  ,DIR.PorHitMz1In                   
						  ,DIR.PorDisMz1In                   
						  ,DIR.PorHitMz2In                   
						  ,DIR.PorDisMz2In                   
						  ,DIR.PorHitMz3In                   
						  ,DIR.PorDisMz3In                   
						  ,DIR.SIMILITUD                     
						  ,DIR.ID                            
				FROM  (SEL   DIR.ID_AUTO
							,DIR.COD_PIN_PERSONA
							,DIR.DIRECCION
							,CJ.DIR_INSUMO_STD
							,TRIM(CJ.DIR_INSUMO_STD) DirInsumoIn
							, TRIM(DIR.DIRECCION) DirBodegaIn
							,CASE WHEN CHAR(DirInsumoIn) <=  CHAR(DirBodegaIn) THEN 1 ELSE 2 END VALTAM
							,0  PorHitMz0In
							,100  PorDisMz0In
							,20  PorHitMz1In
							,80  PorDisMz1In
							,50  PorHitMz2In
							,50  PorDisMz2In
							,70  PorHitMz3In
							,30  PorDisMz3In
							,'||P_BDVISTA||'.Bach_Similitud_Dir_MZ( DirInsumoIn	
															,DirBodegaIn
															,PorHitMz0In
															,PorDisMz0In
															,PorHitMz1In
															,PorDisMz1In
															,PorHitMz2In
															,PorDisMz2In
															,PorHitMz3In
															,PorDisMz3In
															) SIMIL
							,CAST( '||P_BDVISTA||'.PorcSimilitud(CASE WHEN VALTAM = 1  THEN  DirBodegaIn ELSE   DirInsumoIn END, CASE WHEN VALTAM = 1 THEN  DirInsumoIn ELSE DirBodegaIn END)  AS INTEGER) PORCSIMIL
							,CASE WHEN DirInsumoIn = DirBodegaIn THEN 100               
										  WHEN SIMIL BETWEEN 55 AND 100 THEN  SIMIL
										  WHEN SIMIL BETWEEN 101 AND 160  AND DirInsumoIn <> DirBodegaIn AND PORCSIMIL>50 THEN  PORCSIMIL
										  WHEN SIMIL BETWEEN 101 AND 160  AND DirInsumoIn <> DirBodegaIn AND PORCSIMIL<=50 THEN  SIMIL-62
										  WHEN SIMIL > 160  THEN PORCSIMIL               
										  WHEN PORCSIMIL > SIMIL AND  PORCSIMIL > 75  AND SIMIL BETWEEN 0 AND 54 THEN PORCSIMIL
										  WHEN SIMIL <0 THEN 0
										  ELSE SIMIL
							  END SIMILITUD
							,Row_Number() Over(PARTITION BY dir.ID_AUTO ORDER BY SIMILITUD DESC ) ID
					FROM  ' ||P_BDSTAGE||'.BATCH_CUBO_DIRECCION DIR
					CROSS JOIN  ' ||P_BDSTAGE||'.FILTRO_DIR_2 CJ
					WHERE DIR.COD_PIN_PERSONA = CJ.COD_PIN_PERSONA
					AND DIR.DIRECCION IS NOT NULL
					/*AND DIR.TIPO= ''LAB'' #3 Se elimina filtro por solicitud de Mauricio Marin*/) DIR
				) WITH DATA 
				PRIMARY INDEX(ID_AUTO,COD_PIN_PERSONA,ID)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'Crea FILTRO_3_CALC F'
								,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;					
		

------ CREACION TABLA DE TRABAJO ------
--4
SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_4_RES';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_4_RES';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_4_RES F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
		
		
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_4_RES AS
(
SEL 
ID_AUTO
,COD_PIN_PERSONA
,DIRECCION   TEXTO_CUBO
,DIR_INSUMO_STD  TEXTO_CLIENTE
,CASE WHEN SIMILITUD >= 0 THEN SIMILITUD ELSE 0 END SIMILITUD
,CASE WHEN SIMILITUD >= FIL.PMD_DIR THEN 0 ELSE 1 END FLAG
,CAST(''CUBO_DIRECCION'' AS CHAR(30)) CUBO
FROM '||P_BDSTAGE||'.FILTRO_3_CALC,
(SEL  TO_NUMBER(PMD_DIR) PMD_DIR  
 FROM '||P_BDSTAGE||'.BATCH_PORCENTAJES_FILTROS
 WHERE ID_SOLICITUD = '||P_SOLICITUD||'
 AND ID_PLANTILLA = '||P_PLANTILLA||'
) FIL
WHERE ID = 1
) WITH DATA
PRIMARY INDEX(ID_AUTO,COD_PIN_PERSONA)
INDEX(COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_4_RES F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;					
		
---------------TELEFONO--------------------------------
--1
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_TEL_2';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_TEL_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_TEL_2 F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

--2 #1 ajuste nombre campo TEL_INSUMO_STD_000
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_TEL_2 AS
(
SEL  
BO.COD_PIN_PERSONA
,CL.TEL_INSUMO_STD_000 TELEFONO
,CL.NUMERO_ID
FROM  '||P_BDSTAGE||'.FILTRO_CLIENTE_1 BO
LEFT JOIN  '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION CL
ON CL.TIPO_ID = BO.TIPO_ID
AND Cast(CL.NUMERO_ID AS BIGINT) = BO.NUMERO_ID /*#3 casteo a bigint*/
WHERE CL.TEL_INSUMO_STD_000 IS NOT NULL
GROUP BY 1,2,3
) WITH DATA
PRIMARY INDEX (COD_PIN_PERSONA,TELEFONO)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_TEL_2 F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			

--3
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_3_CALT';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALT';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_3_CALT F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

		
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_3_CALT AS
(
SEL 
DIR.ID_AUTO
,DIR.COD_PIN_PERSONA
,DIR.NUMERO
,CJ.TELEFONO
,'||P_BDVISTA||'.Bach_Similitud_Tel(DIR.NUMERO, CJ.TELEFONO) SIMILITUD
,ROW_NUMBER() OVER(PARTITION BY DIR.ID_AUTO ORDER BY SIMILITUD DESC ) ID
FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO DIR
CROSS JOIN '||P_BDSTAGE||'.FILTRO_TEL_2 CJ
WHERE DIR.COD_PIN_PERSONA = CJ.COD_PIN_PERSONA
AND DIR.NUMERO IS NOT NULL
/*AND DIR.TIPO =''TELEFONO'' #3 se elimina filtro por solicitud de Mauricio Marin*/
) WITH DATA 
PRIMARY INDEX(ID_AUTO,COD_PIN_PERSONA,ID)
INDEX(ID_AUTO)
INDEX(ID)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_3_CALT F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		

--4
SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO  '||P_BDSTAGE||'.FILTRO_4_RES
SEL 
ID_AUTO
,COD_PIN_PERSONA
,NUMERO   TEXTO_CUBO
,TELEFONO  TEXTO_CLIENTE
,CASE WHEN SIMILITUD >= 0 THEN SIMILITUD ELSE 0 END SIMILITUD
,CASE WHEN SIMILITUD >= FIL.PMD_TEL THEN 0 ELSE 1 END FLAG
,CAST(''CUBO_TELEFONO'' AS CHAR(30)) CUBO
FROM  '||P_BDSTAGE||'.FILTRO_3_CALT,
(SEL  TO_NUMBER(PMD_TEL) PMD_TEL
 FROM  '||P_BDSTAGE||'.BATCH_PORCENTAJES_FILTROS
 WHERE ID_SOLICITUD = '||P_SOLICITUD||'
 AND ID_PLANTILLA = '||P_PLANTILLA||'
) FIL
WHERE ID = 1';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Inserta  FILTRO_4_RES F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		

---------------------- CELULAR -------------------------------
--1
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_CEL_2';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_CEL_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_CEL_2 F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

--2 #1 ajuste nombre de campo CEL_INSUMO_STD_000
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_CEL_2 AS
(
SEL  
BO.COD_PIN_PERSONA
,CL.CEL_INSUMO_STD_000   CELULAR
,CL.NUMERO_ID
FROM  '||P_BDSTAGE||'.FILTRO_CLIENTE_1 BO
LEFT JOIN  '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION CL
ON CL.TIPO_ID = BO.TIPO_ID
AND Cast(CL.NUMERO_ID AS BIGINT) = BO.NUMERO_ID /*#3 casteo a bigint*/
WHERE CL.CEL_INSUMO_STD_000  IS NOT NULL
GROUP BY 1,2,3
) WITH DATA
PRIMARY INDEX (COD_PIN_PERSONA,CELULAR)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_CEL_2 F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			


--3
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_3_CALCEL';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALCEL';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_3_CALCEL F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

		
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_3_CALCEL AS
(
SEL 
DIR.ID_AUTO
,DIR.COD_PIN_PERSONA
,DIR.NUMERO
,CJ.CELULAR
, '||P_BDVISTA||'.Bach_Similitud_Tel(DIR.NUMERO, CJ.CELULAR) SIMILITUD
,ROW_NUMBER() OVER(PARTITION BY DIR.ID_AUTO ORDER BY SIMILITUD DESC ) ID
FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR DIR
CROSS JOIN  '||P_BDSTAGE||'.FILTRO_CEL_2 CJ
WHERE DIR.COD_PIN_PERSONA = CJ.COD_PIN_PERSONA
AND DIR.NUMERO IS NOT NULL
) WITH DATA 
PRIMARY INDEX(ID_AUTO,COD_PIN_PERSONA,ID)
INDEX(ID_AUTO)
INDEX(ID)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_3_CALCEL F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		

--4
SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.FILTRO_4_RES
SEL 
ID_AUTO
,COD_PIN_PERSONA
,NUMERO   TEXTO_CUBO
,CELULAR  TEXTO_CLIENTE
,CASE WHEN SIMILITUD >= 0 THEN SIMILITUD ELSE 0 END SIMILITUD
,CASE WHEN SIMILITUD >= FIL.PMD_CEL THEN 0 ELSE 1 END FLAG
,CAST(''CUBO_CELULAR'' AS CHAR(30)) CUBO
FROM '||P_BDSTAGE||'.FILTRO_3_CALCEL,
(SEL  TO_NUMBER(PMD_CEL) PMD_CEL
 FROM '||P_BDSTAGE||'.BATCH_PORCENTAJES_FILTROS
 WHERE ID_SOLICITUD = '||P_SOLICITUD||'
 AND ID_PLANTILLA = '||P_PLANTILLA||'
) FIL
WHERE ID = 1';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Inserta  FILTRO_4_RES F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		

------------------------CORREO --------------------------
--1

 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_MAIL_2';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_MAIL_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_MAIL_2 F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

--2 #1 ajuste nombre de campo EMAIL_INSUMO_STD_000
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_MAIL_2 AS
(
SEL  
BO.COD_PIN_PERSONA
,CL.EMAIL_INSUMO_STD_000               MAIL
,CL.NUMERO_ID
FROM   '||P_BDSTAGE||'.FILTRO_CLIENTE_1 BO
LEFT JOIN   '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION CL
ON CL.TIPO_ID = BO.TIPO_ID
AND Cast(CL.NUMERO_ID AS BIGINT) = BO.NUMERO_ID /*#3 casteo a bigint*/
WHERE CL.EMAIL_INSUMO_STD_000   IS NOT NULL
AND CL.EMAIL_INSUMO_STD_000               LIKE ''%@%''
GROUP BY 1,2,3
) WITH DATA
PRIMARY INDEX (COD_PIN_PERSONA,MAIL)
INDEX (COD_PIN_PERSONA)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_MAIL_2 F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;			

--3
 SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'FILTRO_3_CAL_MAIL';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CAL_MAIL';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE FILTRO_3_CAL_MAIL F'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

		
SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.FILTRO_3_CAL_MAIL AS
(
SEL 
DIR.ID_AUTO
,DIR.COD_PIN_PERSONA
,DIR.CORREO
,CJ.MAIL
,UPPER(TRIM(DIR.CORREO)) CADENA_BOD
,CHARS(CADENA_BOD) ancho_bod
,POSITION(''@'' IN CADENA_BOD) arroba_bod
,POSITION(''.'' IN  SUBSTR(CADENA_BOD,arroba_bod+1,ancho_bod  )) pospunto_bod
,SUBSTR(CADENA_BOD,1,arroba_bod-1) BuzonBod 
,'||P_BDVISTA||'.eListGetValByIdx(CADENA_BOD,''@'', 2) DomiNioBod
,UPPER(TRIM(CJ.MAIL)) CADENA_INS
,CHARS(CADENA_INS) ancho_INS
,POSITION(''@'' IN CADENA_INS) arroba_INS
,POSITION(''.'' IN  SUBSTR(CADENA_INS,arroba_INS+1,ancho_INS  )) pospunto_INS
,SUBSTR(CADENA_INS,1,arroba_INS-1) BuzonINS 
,'||P_BDVISTA||'.eListGetValByIdx(CADENA_INS, ''@'', 2) DomiNioINS
, B"
"uzonINS  BuzonInsumoIn
, DomiNioINS DominioInsumoIn
,SOUNDEX(TRANSLATE(REGEXP_REPLACE(BuzonInsumoIn,''[^a-zA-Z]'','''') USING   UNICODE_TO_LATIN)) SounBuzInsIn 
,SOUNDEX(TRANSLATE(REGEXP_REPLACE(DominioInsumoIn,''[^a-zA-Z]'','''') USING   UNICODE_TO_LATIN))  SounDomInsIn
,BuzonBod BuzonBodegaIn
,DomiNioBod DominioBodegaIn
,SOUNDEX(TRANSLATE(REGEXP_REPLACE(BuzonBodegaIn,''[^a-zA-Z]'','''') USING   UNICODE_TO_LATIN)) SounBuzBodIn
,SOUNDEX(TRANSLATE(REGEXP_REPLACE(DominioBodegaIn,''[^a-zA-Z]'','''') USING   UNICODE_TO_LATIN)) SounDomBodIn 
,70 PorBzIn
,50 PorBzSounIn
,50 PorBzDistIn
,30 PorDomIn
,50 PorDomSounIn
,50 PorDomDistIn
, '||P_BDVISTA||'.Bach_Similitud_email(
BuzonInsumoIn
,DominioInsumoIn
,SounBuzInsIn
,SounDomInsIn
,BuzonBodegaIn
,DominioBodegaIn
,SounBuzBodIn
,SounDomBodIn
,PorBzIn
,PorBzSounIn
,PorBzDistIn
,PorDomIn
,PorDomSounIn
,PorDomDistIn
 ) SIMILITUD
 ,CASE WHEN SIMILITUD > 100 THEN 100 ELSE SIMILITUD END SIMILITUDX
/*,ROW_NUMBER() OVER(PARTITION BY DIR.ID_AUTO ORDER BY SIMILITUDX DESC ) ID*/
,Row_Number() Over(PARTITION BY DIR.ID_AUTO ORDER BY SIMILITUDX DESC ) ID
FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO DIR
CROSS JOIN '||P_BDSTAGE||'.FILTRO_MAIL_2 CJ
WHERE DIR.COD_PIN_PERSONA = CJ.COD_PIN_PERSONA
AND DIR.CORREO IS NOT NULL
) WITH DATA 
PRIMARY INDEX(ID_AUTO,COD_PIN_PERSONA,ID)
INDEX(ID_AUTO)
INDEX(ID)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea FILTRO_3_CAL_MAIL F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		

--4
SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.FILTRO_4_RES
SEL 
ID_AUTO
,COD_PIN_PERSONA
,CORREO   TEXTO_CUBO
,MAIL  TEXTO_CLIENTE
,CASE WHEN SIMILITUDX >= 0 THEN SIMILITUDX ELSE 0 END SIMILITUDX
,CASE WHEN SIMILITUDX >= FIL.PMD_MAIL THEN 0 ELSE 1 END FLAG
,CAST(''CUBO_CORREO'' AS CHAR(30)) CUBO
FROM '||P_BDSTAGE||'.FILTRO_3_CAL_MAIL,
(SEL  TO_NUMBER(PMD_MAIL) PMD_MAIL
 FROM '||P_BDSTAGE||'.BATCH_PORCENTAJES_FILTROS
 WHERE ID_SOLICITUD = '||P_SOLICITUD||'
 AND ID_PLANTILLA = '||P_PLANTILLA||'
) FIL
WHERE ID = 1';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Inserta  FILTRO_4_RES F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;		




----------------------UPDATE CUBO TELEFONO		
		
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,SIMILITUD
				,FLAG
				FROM  '||P_BDSTAGE||'.FILTRO_4_RES
				WHERE CUBO = ''CUBO_TELEFONO''
				GROUP BY 1,2,3
				) B
SET FILTRO_F = B.FLAG,
       POR_SIM_TEL = B.SIMILITUD
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,' Act.  CUBO_TELEFONO Campo FILTRO_F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



---------------------------CUBO_CELULAR	


SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,SIMILITUD
				,FLAG
				FROM  '||P_BDSTAGE||'.FILTRO_4_RES
				WHERE CUBO = ''CUBO_CELULAR''
				GROUP BY 1,2,3
				) B
SET FILTRO_F = B.FLAG,
       POR_SIM_CEL = B.SIMILITUD
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,' Act.  CUBO_CELULAR Campo FILTRO_F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_DIRECCION
		
SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,SIMILITUD
				,FLAG
				FROM  '||P_BDSTAGE||'.FILTRO_4_RES
				WHERE CUBO = ''CUBO_DIRECCION''
				GROUP BY 1,2,3
				) B
SET FILTRO_F = B.FLAG,
       POR_SIM_DIR = B.SIMILITUD 
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,' Act.  CUBO_DIRECCION Campo FILTRO_F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


--------------------------CUBO_CORREO

SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
FROM (SEL
             	ID_AUTO ID_AUTO_UP
				,SIMILITUD
				,FLAG
				FROM  '||P_BDSTAGE||'.FILTRO_4_RES
				WHERE CUBO = ''CUBO_CORREO''
				GROUP BY 1,2,3
				) B
SET FILTRO_F = B.FLAG,
       POR_SIM_MAIL = B.SIMILITUD
WHERE ID_AUTO = B.ID_AUTO_UP';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,' Act.  CUBO_CORREO Campo FILTRO_F'
			,V_ERROR);
SET P_ERROR = V_ERROR;
		
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

-------------------BORRAR TABLAS TEMPORALES

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_CLIENTE_1';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_CLIENTE_1'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

----------------


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_DIR_2';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_DIR_2'
		,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALC';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_3_CALC'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_4_RES';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_4_RES'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

---------------------------------------------------------------

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_TEL_2';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_TEL_2'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALT';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_3_CALT'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


-------------------------------------------------------------------------------

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_CEL_2';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_CEL_2'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CALCEL';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_3_CALCEL'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

------------------------------------------------------------

SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_MAIL_2';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_MAIL_2'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;


SET V_CADENA='';
SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.FILTRO_3_CAL_MAIL';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'DROP TABLE FILTRO_3_CAL_MAIL'
		,V_ERROR);
 SET P_ERROR = V_ERROR;
	
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;




END L1;
    
END;"

==============================================================



"REPLACE   PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_G"
"


	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre		VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDDATOS				VARCHAR(20)
		,IN		P_BDVISTA 				VARCHAR(20)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN   	P_PLANTILLA         			INTEGER
		,IN   	P_SOLICITUD         			INTEGER
		,OUT	P_ERROR				VARCHAR(32000)
		
	)
/*
 * ################################################################################
 * 
 * Objetivo:	Actualizar el campo filtro_G de cada uno de los cubos.
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_G
 * 
 * 
 * 
 * BITACORA
 * ------------------------------------------------------------------------------------------------------
 * Fecha			Objetivo								Realizado por
 *2018-07-11		#1 Ajuste para aplicar filtro G, en direcciÃ¸ÂŠÃ´Â³n			Carlos Castillo
 				validando que los otros filtros esten 0
 *2018-11-08     #2 Ajuste punto de interes 								Carlos Castillo 				
 *2018-11-15     #3 Ajuste desempate direccion y telefono fijo 				Carlos Castillo 				
 *2018-12-18     #4 Ajuste filtro ubicacion persona direccion telefono 		Carlos Castillo 		
 *2019-05-21	 #5 Ajuste filtro ordenamiento ciuu por campo FECHA_REPORTE	 Jeimmy chavez 
 *2023-01-17     #6 Ajuste Update G                                         Fernando Garrido
 *2023-02-08	 #7 ajuste para los Puntos de interes						John Bueno
 * -------------------------------------------------------------------------------------------------------
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE Temp 						CHAR		(30);
	DECLARE V_NOMBRE_CUBO				VARCHAR	(30);
	DECLARE Cur_Filtro_G NO SCROLL CURSOR 	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Limpieza de Ambiente Borrado de tablas temporales  ----------------------
-------------------------------------------------------------------------------------------------------------------------------
/* 
G-Datos Activos a exportar: Es usado para limitar la cantidad de registros por canal que se incluirÃ¸ÂŠÃ´Â¡ para cada persona en el resultado de acuerdo 
a parÃ¸ÂŠÃ´Â¡metros de cantidad mÃ¸ÂŠÃ´Â­nima y/o Cantidad MÃ¸ÂŠÃ´Â¡xima. El filtro se encuentra configurado en la tabla BATCH_SALIDAS_CAMPOS, 
el campo MINIMO_REQUERIDO_CAMPO tiene almacenado el mÃ¸ÂŠÃ´Â­nimo de datos que deben tener la salida para cada persona 
(aplica para direcciones, telÃ¸ÂŠÃ´Â©fonos, mails, celulares y ciiu), ej.  Si el dato tiene un valor de 3 para el campo telefonos fijos, sÃ¸ÂŠÃ´Â³lo se debe incluir 
registros de personas que tienen al menos tres registros y excluir aquellos que tengan menos, si el dato NO estÃ¸ÂŠÃ´Â¡ configurado (nulo o vacÃ¸ÂŠÃ´Â­o) 
NO se tendrÃ¸ÂŠÃ´Â¡ lÃ¸ÂŠÃ´Â­mite mÃ¸ÂŠÃ´Â­nimo.
En el campo CANTIDAD_MAX_CAMPO  se almacena el nÃ¸ÂŠÃ´Âºmero mÃ¸ÂŠÃ´Â¡ximo de registros que se deben traer para el tipo de datos en el que estÃ¸ÂŠÃ´Â¡ 
configurado (aplica para direcciones, telÃ¸ÂŠÃ´Â©fonos, mails, celulares y CIIU), si estÃ¸ÂŠÃ´Â¡ vacÃ¸ÂŠÃ´Â­o o nÃ¸ÂŠÃ´Âºlo, NO se tiene restricciÃ¸ÂŠÃ´Â³n de registros que pueden 
traerse.

*/
------ CreaciÃ¸ÂŠÃ´Â³n de insumos para aplicaciÃ¸ÂŠÃ´Â³n de filtros ---------------
----------------------------------------------------------------------------------
/* Borrado de tabla temporal BACTH_FG_1 */


	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FG_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FG_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FG_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------------------------------------------------------------------------
----FiltroD: Se crea la tabla con los filtros por campo y cubo ----------------------------
-------------------------------------------------------------------------------------------
	SET V_CADENA = ' ';
	SET V_CADENA = 
		'CREATE TABLE '||P_BDSTAGE||'.BACTH_FG_1 AS (
	SELECT 
	ID_SEQUENCIA AS ID
	,CASE WHEN CUBO=''Celular'' 	THEN  ''BATCH_CUBO_CELULAR''            
		WHEN CUBO=''Ciiu'' 		THEN  ''BATCH_CUBO_CIIU''               
	   	WHEN CUBO=''Correo'' 		THEN  ''BATCH_CUBO_CORREO''             
	   	WHEN CUBO=''Direccion'' 	THEN  ''BATCH_CUBO_DIRECCION''          
	   	WHEN CUBO=''Persona'' 	THEN  ''BATCH_CUBO_PERSONA''            
	   	WHEN CUBO=''Telefono'' 	THEN  ''BATCH_CUBO_TELEFONO''   
		WHEN CUBO=''PuntoInteres'' 	THEN  ''BATCH_CUBO_PUNTO_INTERES_DIR''   
	END AS NOMBRE_CUBO
	,CUBO
	,''CREATE TABLE REC_STAGE.BACTH_FG_2  AS(''||
	CASE WHEN CUBO=''Ciiu'' THEN ''
	SELECT
	 ID_AUTO
	,ID_BURO_PERSONA
	,''|| CASE WHEN NOMBRE_CUBO=''BATCH_CUBO_CIIU''  THEN ''Sum(1) Over (PARTITION BY ID_BURO_PERSONA ROWS Unbounded Preceding ) CANT_CAMPO'' 
	WHEN NOMBRE_CUBO=''BATCH_CUBO_PUNTO_INTERES_DIR'' THEN ''Sum(1) Over (PARTITION BY B.ID_BURO_PERSONA,COD_DW_UBIC  ORDER BY Nvl(DISTANCIA,999)  ROWS Unbounded Preceding ) AS CANT_CAMPO'' /*#2*/
	ELSE ''Sum(1) Over (PARTITION BY ID_BURO_PERSONA ORDER BY Nvl(Orden_Prioridad,9999),Fecha_ultima_actualizacion DESC    ROWS Unbounded Preceding ) CANT_CAMPO'' END ||''
	
	,Decode(Y.NOMBRE_CUBO,NULL,1,CASE WHEN CANT_CAMPO BETWEEN ''||Trim(ZeroIfNull(To_Number(MINIMO_REQUERIDO_CAMPO)))||'' AND ''||CASE WHEN Coalesce(CANTIDAD_MAX_CAMPO,0)=0 THEN Trim(1000000) ELSE Trim(CANTIDAD_MAX_CAMPO) END ||'' THEN 0 ELSE 1 END) AS C_UPDATE
	FROM (SELECT
			 ID_AUTO
			,''||HOMOLOGADO||''
			,ID_BURO_PERSONA 
			,''''''||NOMBRE_CUBO||'''''' AS NOMBRE_CUBO
		     FROM REC_STAGE.''||NOMBRE_CUBO||''
		     
			''|| CASE WHEN NOMBRE_CUBO=''BATCH_CUBO_CIIU''  THEN ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,''||HOMOLOGADO||'' ORDER BY FECHA_REPORTE ) )=1'' /*#5*/
			WHEN NOMBRE_CUBO=''BATCH_CUBO_PUNTO_INTERES_DIR''  THEN ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,COD_DW_UBIC,Cod_DW_Ubic_Punto_Interes ORDER BY Nvl(DISTANCIA,999) ) )=1''  /*#2*/
			
			ELSE ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,''||HOMOLOGADO||'' ORDER BY Nvl(ORDEN_PRIORIDAD,999),Fecha_ultima_actualizacion DESC    ) )=1'' END ||''		
		) A''
	ELSE ''
	
	SELECT
	 B.ID_AUTO
	,B.ID_BURO_PERSONA
	,''||CASE WHEN NOMBRE_CUBO=''BATCH_CUBO_PUNTO_INTERES_DIR'' THEN ''Sum(1) Over (PARTITION BY B.ID_BURO_PERSONA,COD_DW_UBIC  ORDER BY Nvl(DISTANCIA,999)  ROWS Unbounded Preceding ) AS CANT_CAMPO'' 
/*#3*/			  WHEN (NOMBRE_CUBO=''BATCH_CUBO_DIRECCION'' OR NOMBRE_CUBO=''BATCH_CUBO_TELEFONO'') THEN  ''SUM(1) OVER (PARTITION BY B.ID_BURO_PERSONA ORDER BY NVL(B.ORDEN_PRIORIDAD,999),Fecha_ultima_actualizacion desc,CIUDAD,DEPARTAMENTO     ROWS UNBOUNDED PRECEDING ) AS CANT_CAMPO''
	ELSE ''SUM(1) OVER (PARTITION BY B.ID_BURO_PERSONA ORDER BY NVL(B.ORDEN_PRIORIDAD,999),Fecha_ultima_actualizacion  desc  ROWS UNBOUNDED PRECEDING ) AS CANT_CAMPO'' END ||''	/*#2*/
	,Decode(Y.NOMBRE_CUBO,NULL,1,CASE WHEN CANT_CAMPO BETWEEN ''||Trim(ZeroIfNull(To_Number(MINIMO_REQUERIDO_CAMPO)))||'' AND ''||CASE WHEN Coalesce(CANTIDAD_MAX_CAMPO,0)=0 THEN Trim(1000000) ELSE Trim(CANTIDAD_MAX_CAMPO) END ||'' THEN 0 ELSE 1 END) AS C_UPDATE
	FROM (SELECT
		 ID_AUTO
		,''||HOMOLOGADO||''
		,ID_BURO_PERSONA 
		,''''''||NOMBRE_CUBO||'''''' AS NOMBRE_CUBO
		FROM REC_STAGE.''||NOMBRE_CUBO||''
/*#1*/	''|| CASE WHEN NOMBRE_CUBO=''BATCH_CUBO_DIRECCION''    THEN '' WHERE ( coalesce(filtro_a,0)+coalesce(filtro_b,0)+coalesce(filtro_c,0)+coalesce(filtro_d,0)+coalesce(filtro_e,0)+coalesce(filtro_f,0) ) = 0 '' ELSE '''' END ||''
			''|| CASE WHEN NOMBRE_CUBO=''BATCH_CUBO_CIIU''  THEN ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,''||HOMOLOGADO||'' ORDER BY FECHA_REPORTE ) )=1'' /*#5*/
					  WHEN NOMBRE_CUBO=''BATCH_CUBO_PUNTO_INTERES_DIR''  THEN ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,COD_DW_UBIC,Cod_DW_Ubic_Punto_Interes ORDER BY Nvl(DISTANCIA,999) ) )=1'' /*#2*/
					  WHEN (NOMBRE_CUBO=''BATCH_CUBO_DIRECCION'' OR NOMBRE_CUBO=''BATCH_CUBO_TELEFONO'')  THEN ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,''||HOMOLOGADO||'',CIUDAD ORDER BY Nvl(ORDEN_PRIORIDAD,999),Fecha_ultima_actualizacion DESC ,CIUDAD,DEPARTAMENTO    ) )=1'' /*#3 #4*/
			ELSE ''QUALIFY (Row_Number() Over (PARTITION BY ID_BURO_PERSONA,''||HOMOLOGADO||'' ORDER BY Nvl(ORDEN_PRIORIDAD,999),Fecha_ultima_actualizacion DESC    ) )=1'' END ||''		
		) A
	INNER JOIN REC_STAGE.''||NOMBRE_CUBO||'' B ON A.ID_AUTO = B.ID_AUTO''
	END||''
	LEFT JOIN (SELECT
	CASE WHEN GRUPO_CAMPO=''''CUBO_CEL'''' THEN ''''BATCH_CUBO_CELULAR''''
		WHEN GRUPO_CAMPO=''''CUBO_CIIU'''' THEN ''''BATCH_CUBO_CIIU''''
	   	WHEN GRUPO_CAMPO=''''CUBO_EMAIL'''' THEN ''''BATCH_CUBO_CORREO''''
	   	WHEN GRUPO_CAMPO=''''CUBO_DIR'''' THEN ''''BATCH_CUBO_DIRECCION''''
	   	WHEN GRUPO_CAMPO=''''CUBO_TEL'''' THEN ''''BATCH_CUBO_TELEFONO''''
		WHEN GRUPO_CAMPO=''''CUBO_PT_INT'''' THEN ''''BATCH_CUBO_PUNTO_INTERES_DIR'''' /*#2*/
	END AS NOMBRE_CUBO
	FROM REC_STAGE.BATCH_SALIDAS_CAMPOS
	WHERE   GRUPO_CAMPO NE ''''CUBO_PERS''''
	AND NOMBRE_SECCION LIKE ''''%CON DATOS%''''
	AND ID_SOLICITUD EQ '||TRIM(P_SOLICITUD)||'
	AND ID_PLANTILLA EQ '||TRIM(P_PLANTILLA)||'
	GROUP BY GRUPO_CAMPO) Y
	ON A.NOMBRE_CUBO EQ Y.NOMBRE_CUBO
	
	
	) WITH DATA'' AS SQL_STRING
	FROM REC_STAGE.BATCH_SALIDAS_CAMPOS BSC
	INNER JOIN REC_STAGE.BATCH2_HOMOLOGACION B2H ON BSC.CODIGO_CAMPO=B2H.CODIGO_CAMPO
	AND BSC.CODIGO_CAMPO IN (''DT_NUM'',''CE_CORREO'',''DD_DIR'',''DC_NUMERO'',''DB_CIIU'',''DECB_NOM'') /*#2*/ 
	AND ID_SOLICITUD ='||TRIM(P_SOLICITUD)||'
	AND ID_PLANTILLA ='||TRIM(P_PLANTILLA)||'
	AND NOMBRE_CUBO <> (''BATCH_CUBO_PERSONA'')
	) WITH DATA;
	';


	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea Tabla BACTH_FG_1'
				,V_ERROR);
	SET P_ERROR = V_ERROR;

	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	

----------------------ActualizaciÃ¸ÂŠÃ´Â³n de cubos filtro G a 1----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------

 SET V_CADENA='';
 
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_CELULAR';


IF  CHARACTER_LENGTH (V_CADENA )>0 THEN 

SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_CELULAR SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=1 BATCH_CUBO_CELULAR'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
END IF;


SET V_CADENA='';
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_CIIU';

IF    CHARACTER_LENGTH (V_CADENA )>0 THEN 

SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_CIIU SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=1 BATCH_CUBO_CIIU'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;

END IF;


SET V_CADENA='';
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_CORREO';

IF    CHARACTER_LENGTH (V_CADENA )>0 THEN 


SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_CORREO SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=1 BATCH_CUBO_CORREO'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;

END IF;


SET V_CADENA='';
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_DIRECCION';

IF    CHARACTER_LENGTH (V_CADENA )>0 THEN 


SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_DIRECCION SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=0 BATCH_CUBO_DIRECCION'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
END IF;



SET V_CADENA='';
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_TELEFONO';

IF    CHARACTER_LENGTH (V_CADENA )>0 THEN 



SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_TELEFONO SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=1 BATCH_CUBO_TELEFONO'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
END IF;		


/*#2*/
SET V_CADENA='';
 SELECT 
   NOMBRE_CUBO
   INTO :V_CADENA
  FROM  REC_STAGE.BACTH_FG_1 
WHERE NOMBRE_CUBO='BATCH_CUBO_PUNTO_INTERES_DIR';

IF    CHARACTER_LENGTH (V_CADENA )>0 THEN 


/*#2*/
SET V_CADENA='';
		SET V_CADENA = 'UPDATE ' ||P_BDSTAGE||'.BATCH_CUBO_PUNTO_INTERES_DIR SET Filtro_G=1; ';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G=1 BATCH_CUBO_PUNTO_INTERES_DIR'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
END IF;	

		
----------------------FIN ActualizaciÃ¸ÂŠÃ´Â³n de cubos filtro G a 0----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸ÂŠÃ´Â³n de filtroD---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  NOMBRE_CUBO,SQL_STRING
					 FROM '||P_BDSTAGE||'.BACTH_FG_1
					 ORDER BY ID
					';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_Filtro_G ;

	CUR2:LOOP
		FETCH Cur_Filtro_G  INTO  V_NOMBRE_CUBO, V_SQL ;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

----------------------------------------------------------------------------------------------------------------
-------------------Borrado de tablas filtroD si existen ------------------------------------------------
----------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_FG_2 

	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FG_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FG_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FG_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------- CreaciÃ¸ÂŠÃ´Â³n de tablas con los filtros calculados -------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(V_SQL
						,'REC_STAGE', P_BDSTAGE)
						,'REC_VISTA', P_BDVISTA)
						, 'P_LOTE', CAST(P_Lote AS VARCHAR(12)))
						;
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea tabla '||P_BDSTAGE||'.'||V_SQL ||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

-------------------------- UPDATE FILTROG --------------------------------------------------------
-------------------------------------------------------------------------------------------------------------		

       SET V_CADENA='';
		SET V_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_CELULAR  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		
		
		SET V_CADENA='';
		SET V_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		

        SET V_CADENA='';
		SET V_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_CIIU  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 		
	---######pruebas JB	
		SET V_CADENA='';
		SET V"
"_CADENA='UPDATE A FROM '||P_BDSTAGE||'.BATCH_CUBO_PUNTO_INTERES_DIR  A 
						 ,'||P_BDSTAGE||'.BACTH_FG_2 B 
						 SET FILTRO_G = B.C_UPDATE
						WHERE A.ID_AUTO =B.ID_AUTO 
						';		
		
			
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE FILTRO G TABLA '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||' CAMPO BACTH_FG_2;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 
		---######pruebas JB

	END LOOP CUR2;

CLOSE Cur_Filtro_G ;
	


END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_H"
"
(
	 IN P_Lote								INTEGER
	,IN P_StartTimeStampPadre		VARCHAR(20)
	,IN P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN P_BDSTAGE						VARCHAR(20)
	,IN P_PLANTILLA         			INTEGER
	,IN P_SOLICITUD         			INTEGER
	,OUT P_ERROR						VARCHAR(32000)
)

/*
 * ################################################################################
 * 
 * Objetivo:		Eliminar los registros marcados en 1 con el Filtro_H
 * Fecha:		2017/11/26
 * Realizado por:	Capgemini
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_H
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha			Objetivo											   Realizado por
 * 22/02/2018		Eliminar los registros del Filtro H marcados en (1) 	Luis C.
 * 01/03/2018 	#1 requerido = si
 * 13/11/2018 	#2 requerido = si para todos los cubos						Carlos Castillo
 * 17/01/2023   #3 Ajuste caracter untraslable.                             Fernando Garrido. 
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


---------------------------------------------------------------------------------------------------------------------
-- DeclaraciÃ¸ÂŠÃ´Â³n de variables
---------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR						VARCHAR(30);
	DECLARE V_CADENA					VARCHAR(32000);
	DECLARE V_CADENA2					VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);
	DECLARE V_CUBO						VARCHAR(30);
	DECLARE C 								NO SCROLL CURSOR FOR the_statement;
	

L1:BEGIN
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸ÂŠÃ´Â³n de filtroH---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FH_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FH_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FG_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA =
'CREATE TABLE REC_STAGE.BACTH_FH_1 AS (SELECT * FROM 
(
SELECT * FROM 	        	(SELECT CAST(''BATCH_CUBO_PERSONA'' AS VARCHAR(30))		AS NOMBRE_CUBO,  CAST( ''UPDATE   REC_STAGE.BATCH_CUBO_PERSONA 	SET Filtro_H= CASE WHEN COALESCE(Filtro_D,0)  >0 THEN 1 ELSE 0 END;'' AS VARCHAR(1000)) AS SQL_STRING) A
UNION ALL SELECT * FROM  (SELECT 	 ''BATCH_CUBO_DIRECCION''	 	AS NOMBRE_CUBO, ''UPDATE REC_STAGE.BATCH_CUBO_DIRECCION	 SET Filtro_H= CASE WHEN ( COALESCE(Filtro_A,0) + COALESCE(Filtro_B,0) + COALESCE(Filtro_C,0) + COALESCE(Filtro_D,0) + COALESCE(Filtro_E,0) + COALESCE(Filtro_F,0) + COALESCE(Filtro_G,0) + COALESCE(Filtro_I,0)) > 0    THEN 1 ELSE 0 END ;''AS SQL_STRING)A
UNION ALL SELECT * FROM  (SELECT 	 ''BATCH_CUBO_TELEFONO'' 	 	AS NOMBRE_CUBO, ''UPDATE REC_STAGE.BATCH_CUBO_TELEFONO 	SET Filtro_H= CASE WHEN (COALESCE(Filtro_B,0) + COALESCE(Filtro_C,0) + COALESCE(Filtro_D,0) + COALESCE(Filtro_E,0) + COALESCE(Filtro_F,0) + COALESCE(Filtro_G,0) + COALESCE(Filtro_I,0)) > 0  THEN 1 ELSE 0 END;''AS SQL_STRING)A
UNION ALL SELECT * FROM  (SELECT 	 ''BATCH_CUBO_CELULAR'' 	 	AS NOMBRE_CUBO, ''UPDATE REC_STAGE.BATCH_CUBO_CELULAR 	SET Filtro_H= CASE WHEN  (COALESCE(Filtro_B,0) + COALESCE(Filtro_C,0) + COALESCE(Filtro_D,0) + COALESCE(Filtro_E,0) + COALESCE(Filtro_F,0) + COALESCE(Filtro_G,0) + COALESCE(Filtro_I,0)) > 0    THEN 1 ELSE 0 END;''AS SQL_STRING)A
UNION ALL SELECT * FROM  (SELECT 	 ''BATCH_CUBO_CORREO'' 	 	AS NOMBRE_CUBO, ''UPDATE REC_STAGE.BATCH_CUBO_CORREO 	SET Filtro_H= CASE WHEN (COALESCE(Filtro_B,0) + COALESCE(Filtro_C,0) + COALESCE(Filtro_D,0) + COALESCE(Filtro_E,0) + COALESCE(Filtro_F,0) + COALESCE(Filtro_G,0) + COALESCE(Filtro_I,0)) > 0    THEN 1 ELSE 0 END;''AS SQL_STRING)A
UNION ALL SELECT * FROM  (SELECT 	 ''Batch_Cubo_Ciiu''   		 	AS NOMBRE_CUBO, ''UPDATE REC_STAGE.Batch_Cubo_Ciiu   		SET Filtro_H= CASE WHEN (COALESCE(Filtro_D,0) + COALESCE(Filtro_G,0)) > 0     THEN 1 ELSE 0 END; ''AS SQL_STRING)A
)A) WITH DATA;'
;

		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'CREA TMP_FILTRO_H'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 


------------- INCIO CURSO FILTRO H ---------------------------------------------------------
SET V_CADENA= 'SELECT  NOMBRE_CUBO,SQL_STRING
					 FROM '||P_BDSTAGE||'.BACTH_FH_1
					 ';
  
PREPARE the_statement FROM V_CADENA;

OPEN C ;

	CUR2:LOOP
		FETCH C  INTO  V_CUBO, V_CADENA2;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;


-------------------------------------------------------------------------------------------------------------		
		
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA2
				,'UPDT FH '||V_CUBO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 


	END LOOP CUR2;

CLOSE C;


---------------------------------------------------------------------------------------------------------------------
-- Busca y borra si existe la tabla BACTH_FH_1
---------------------------------------------------------------------------------------------------------------------
SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FH_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FH_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FG_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
---------------------------------------------------------------------------------------------------------------------
-- Crea tabla BACTH_FH_1
---------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_FH_1 AS(
	SELECT * FROM (SELECT ''BATCH_CUBO_PERSONA'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_DIRECCION'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_TELEFONO'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_CELULAR'' (VARCHAR(30))AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_CORREO'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_CIIU'' (VARCHAR(30)) AS CUBO) X
	) WITH DATA;
	';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(
		:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'Crea BACTH_FH_1'
		,V_ERROR);
	
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

---------------------------------------------------------------------------------------------------------------------
-- Ejecuta Delete - Filtro_H para los cubos
	-- BATCH_CUBO_PERSONA
	-- BATCH_CUBO_DIRECCION
	-- BATCH_CUBO_TELEFONO
	-- BATCH_CUBO_CELULAR
	-- BATCH_CUBO_CORREO
	-- BATCH_CUBO_CIIU
---------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'SELECT CUBO FROM '||P_BDSTAGE||'.BACTH_FH_1;';

	PREPARE THE_STATEMENT FROM V_CADENA;
	OPEN C;

		I:LOOP
			FETCH C  INTO  V_CUBO;
			IF SQLCODE <> 0 THEN LEAVE I; END IF;
			/*Se eliminan las personas que estan marcadas con filtro 1 , que se encuentran ya clasificadas como con datos  */
			SET V_CADENA2 = '';
			SET V_CADENA2 = 'DELETE FROM '||P_BDSTAGE||'.'||V_CUBO||'
			WHERE FILTRO_H EQ 1
			AND ID_BURO_PERSONA = ANY (SELECT
				ID_BURO_PERSONA
				FROM (SELECT
					ID_BURO_PERSONA,COUNT(FILTRO_H) AS CANTIDAD
					FROM (SELECT
						ID_BURO_PERSONA,FILTRO_H
						FROM '||P_BDSTAGE||'.'||V_CUBO||'
						GROUP BY ID_BURO_PERSONA,FILTRO_H) X 
					GROUP BY ID_BURO_PERSONA
					HAVING CANTIDAD GT 1) Y)
			';
			
			CALL REC_DATOS.SP_EXECSTRING_DES(
				:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA2
				,'Filtro_H '||V_CUBO
				,V_ERROR);
			
			SET P_ERROR = V_ERROR;
			
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;
		END LOOP I;
	CLOSE C;
	
---------------------------------------------------------------------------------------------------------------------
-- Busca y borra si existe la tabla TMP_NEW_FILTRO_H
---------------------------------------------------------------------------------------------------------------------
	LOCKING ROW FOR ACCESS
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_NEW_FILTRO_H'
	AND Tablekind IN ('T', 'O');
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_NEW_FILTRO_H';
		CALL DBC.SysExecSQL(:V_CADENA);
	END IF;
	
---------------------------------------------------------------------------------------------------------------------
-- Crea tabla TMP_FILTRO_H_CUBO_PER
---------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_NEW_FILTRO_H AS(
	SELECT
	ID_AUTO
	FROM (SELECT
		BCP.ID_AUTO,
		CASE WHEN COALESCE(BCD.ID_AUTO,BCT.ID_AUTO,BCC.ID_AUTO,BCO.ID_AUTO,BCI.ID_AUTO) IS NULL THEN 1 ELSE 0  END AS NEW_FILTRO_H
		FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA BCP
		LEFT JOIN '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION BCD 	ON BCP.ID_BURO_PERSONA EQ BCD.ID_BURO_PERSONA AND BCD.FILTRO_H EQ 0
		LEFT JOIN '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO BCT	ON BCP.ID_BURO_PERSONA EQ BCT.ID_BURO_PERSONA AND BCT.FILTRO_H EQ 0
		LEFT JOIN '||P_BDSTAGE||'.BATCH_CUBO_CELULAR BCC		ON BCP.ID_BURO_PERSONA EQ BCC.ID_BURO_PERSONA AND BCC.FILTRO_H EQ 0
		LEFT JOIN '||P_BDSTAGE||'.BATCH_CUBO_CORREO BCO		ON BCP.ID_BURO_PERSONA EQ BCO.ID_BURO_PERSONA AND BCO.FILTRO_H EQ 0
		LEFT JOIN '||P_BDSTAGE||'.BATCH_CUBO_CIIU BCI				ON BCP.ID_BURO_PERSONA EQ BCI.ID_BURO_PERSONA AND BCI.FILTRO_H EQ 0) X
	WHERE NEW_FILTRO_H EQ 1
	) WITH DATA PRIMARY INDEX (ID_AUTO);
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(
		:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'Crea TMP_NEW_FILTRO_H'
		,V_ERROR);
	
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
---------------------------------------------------------------------------------------------------------------------
-- Actualiza Filtro_H para el cubo BATCH_CUBO_PERSONA
---------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
	SET FILTRO_H = 1
	WHERE ID_AUTO = ANY(SELECT ID_AUTO FROM '||P_BDSTAGE||'.TMP_NEW_FILTRO_H)
	AND FILTRO_H = 0;
	';

	CALL REC_DATOS.SP_EXECSTRING_DES(
		:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'new Filtro_H BATCH_CUBO_PERSONA'
		,V_ERROR);
	
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

------------------------------------------------------------------------------------------------------------------------------------------------------------
---------#1 Ajuste filtro requerido=si cuando los cubos de ubicacion estan nulos se aplica al cubo persona -------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FH_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_FH_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_FG_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



---------------- #2 Ajuste requerido =si -------------------------------------------------------------

SET V_CADENA=
	' CREATE TABLE '||P_BDSTAGE||'.BACTH_FH_2 AS (		
	SELECT ''UPDATE '||P_BDSTAGE||'.BATCH_CUBO_PERSONA 
	SET FILTRO_H=1
	WHERE ID_AUTO NOT IN (SELECT BCP.ID_AUTO
					    FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA BCP
					     INNER JOIN '||P_BDSTAGE||'.''||NOMBRE_CUBO||'' BCD 
						 ON BCP.ID_BURO_PERSONA=BCD.ID_BURO_PERSONA
						WHERE BCD.FILTRO_H EQ 0
						GROUP BY 1)
	AND NVL(Filtro_H,0) = 0;'' AS CAMPO
	FROM 
	(SELECT CASE WHEN CUBO=''Celular'' 	THEN  ''BATCH_CUBO_CELULAR''            
		WHEN CUBO=''Ciiu'' 		THEN  ''BATCH_CUBO_CIIU''               
	   	WHEN CUBO=''Correo'' 		THEN  ''BATCH_CUBO_CORREO''             
	   	WHEN CUBO=''Direccion'' 	THEN  ''BATCH_CUBO_DIRECCION''          
	   	WHEN CUBO=''Persona'' 	THEN  ''BATCH_CUBO_PERSONA''            
	   	WHEN CUBO=''Telefono'' 	THEN  ''BATCH_CUBO_TELEFONO''   
		WHEN CUBO=''PuntoInteres'' 	THEN  ''BATCH_CUBO_PUNTO_INTERES_DIR''   
	END AS NOMBRE_CUBO
	FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS BSC
	INNER JOIN '||P_BDSTAGE||'.BATCH2_HOMOLOGACION B2H ON BSC.CODIGO_CAMPO=B2H.CODIGO_CAMPO
	AND B2H.GRUPO_CAMPO=BSC.GRUPO_CAMPO
	AND ID_SOLICITUD ='||TRIM(P_SOLICITUD)||'		
	AND ID_PLANTILLA ='||TRIM(P_PLANTILLA)||'		
	WHERE REQUERIDO_CAMPO=''SI''
	AND BSC.GRUPO_CAMPO NE ''CUBO_PERS''
	GROUP BY 1
	) A
	) WITH DATA
	';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'CREATE TABLE BACTH_FG_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;


------------- INCIO CURSO FILTRO H  REQUERIDO CAMPO = SI ---------------------------------------------------------
SET V_CADENA= 'SELECT  CAMPO
					 FROM '||P_BDSTAGE||'.BACTH_FH_2
					 ';
  
PREPARE the_statement FROM V_CADENA;

OPEN C ;

	CUR2:LOOP
		FETCH C  INTO   V_CADENA2;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;


-------------------------------------------------------------------------------------------------------------		

		SET V_CADENA=REGEXP_REPLACE(REGEXP_REPLACE(V_CADENA2
						,'REC_STAGE', P_BDSTAGE)
						, 'P_LOTE', CAST(P_Lote AS VARCHAR(12)))
						;	
		
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDT FH CUBO_PERSONA;'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 


	END LOOP CUR2;

CLOSE C;



END;

END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_I"
"
(
	 IN P_Lote								INTEGER
	,IN P_StartTimeStampPadre		VARCHAR(20)
	,IN P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN P_BDSTAGE						VARCHAR(20)
	,OUT P_ERROR						VARCHAR(32000)
)

/*
 * ################################################################################
 * 
 * Objetivo:		Marcan en 1 el Filtro_I cuando el camo orden_prioridad se encuentre en (null) y 0 para otro valor.
 * Fecha:		2018/03/05
 * Realizado por:	Capgemini
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_I
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha			Objetivo															Realizado por
 * 05/03/2018		Marcan en 1 el Filtro_I cuando el camo 				Luis Carlos R.
 *						orden_prioridad se encuentre en (null) y 0 para 
 *						otro valor. 	
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

---------------------------------------------------------------------------------------------------------------------
-- DeclaraciÃ³n de variables
---------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR						VARCHAR(30);
	DECLARE V_CADENA					VARCHAR(32000);
	DECLARE V_CADENA2					VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);
	DECLARE V_CUBO						VARCHAR(30);
	DECLARE C 								NO SCROLL CURSOR FOR the_statement;
	

L1:BEGIN
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

---------------------------------------------------------------------------------------------------------------------
-- Busca y borra si existe la tabla BACTH_FI_1
---------------------------------------------------------------------------------------------------------------------
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_FI_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.BACTH_FI_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(
			:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'DROP TABLE BACTH_FI_1'
			,V_ERROR);
		SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 	END IF;

---------------------------------------------------------------------------------------------------------------------
-- Crea tabla BACTH_FI_1
---------------------------------------------------------------------------------------------------------------------
 	SET V_CADENA = '';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BACTH_FI_1 AS(
	SELECT * FROM (SELECT ''BATCH_CUBO_DIRECCION'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_TELEFONO'' (VARCHAR(30)) AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_CELULAR'' (VARCHAR(30))AS CUBO) X UNION ALL
	SELECT * FROM (SELECT ''BATCH_CUBO_CORREO'' (VARCHAR(30)) AS CUBO) X
	) WITH DATA;
	';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(
		:P_Lote
		,V_StartTimeStampPadre
		,:P_Nombre_Proceso_Padre
		,:V_CADENA
		,'Crea BACTH_FI_1'
		,V_ERROR);
	
	SET P_ERROR = V_ERROR;
	
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

---------------------------------------------------------------------------------------------------------------------
-- Ejecuta MERGE - Filtro_I para los cubos
	-- BATCH_CUBO_DIRECCION
	-- BATCH_CUBO_TELEFONO
	-- BATCH_CUBO_CELULAR
	-- BATCH_CUBO_CORREO
---------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'SELECT CUBO FROM '||P_BDSTAGE||'.BACTH_FI_1;';

	PREPARE THE_STATEMENT FROM V_CADENA;
	OPEN C;
		I:LOOP
			FETCH C  INTO  V_CUBO;
			IF SQLCODE <> 0 THEN LEAVE I; END IF;
			-- Marcan en 1 el Filtro_I cuando el camo orden_prioridad se encuentre en (null) y 0 para otro valor.
			SET V_CADENA2 = '';
			SET V_CADENA2 = 'MERGE INTO '||P_BDSTAGE||'.'||V_CUBO||' X
			USING(SELECT ID_AUTO,DECODE(ORDEN_PRIORIDAD,NULL,1,0) NEW_FILTRO_I
				FROM '||P_BDSTAGE||'.'||V_CUBO||')
			AS Y (ID_AUTO,NEW_FILTRO_I)
			ON X.ID_AUTO EQ Y.ID_AUTO
			WHEN MATCHED THEN UPDATE SET
			FILTRO_I = Y.NEW_FILTRO_I;
			';
			
			CALL REC_DATOS.SP_EXECSTRING_DES(
				:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA2
				,'Filtro_I '||V_CUBO
				,V_ERROR);
			SET P_ERROR = V_ERROR;
			
			IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
			END IF;
		END LOOP I;
	CLOSE C;

END;
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_FILTRO_J"
"
	(
		 IN	 P_Lote					INTEGER
		,IN	 P_StartTimeStampPadre	VARCHAR(20)
		,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	 P_BDSTAGE				VARCHAR(20)
		,OUT P_ERROR				VARCHAR(50)
	)
	
	
/*
 * ################################################################################
 * 
 * Objetivo: Control sobre información salida en procesos batch donde se limite la información de correo electrónico y/o celular 	
 *                por cantidad de duplicados.
 * Fecha: 2021/01/27
 * Realizado por: Jeimmy Chavez
 * Proyecto: Reconocer Master
 * Script: PRO_BATCH2_FILTRO_J
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		           Objetivo									                        												Realizado por
 * 2021/01/27		   Eliminar correos y/o celulares duplicados con base a las condiciones de              Jeimmy Chavez Cortes
 * 						   cantidad de registros de salida entregadas por producto
 * ---------------------------------------------------------------------------
 * 
 * 
 * ################################################################################
 */

BEGIN

--------------------------------------
-- Declaracionde variables
--------------------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);

	
	
L1:	BEGIN

	SET P_ERROR = NULL;
	SET V_StartTimeStampPadre = Cast(P_StartTimeStampPadre AS TIMESTAMP(6) Format 'yyyy-mm-ddhh:mi:ss');
		


-----------------------------------------------------------------------------------------------------------
-- Se crea tabla temporal para identificar los duplicados existentes en el cubo correo
-----------------------------------------------------------------------------------------------------------


  SELECT TableName
	INTO :Temp
	FROM dbc.TablesV
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'dup_correo';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.dup_correo';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE dup_correo'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.dup_correo AS
(
		SELECT  
		correo
		, Count(*)  AS duplicados
		FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
		GROUP BY 1
		HAVING Count(*) >1

)
WITH DATA 
PRIMARY INDEX(correo)';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla dup_correo'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

 
-----------------------------------------------------------------------------------------------------------
-- Se crea tabla temporal para identificar los duplicados existentes en el cubo celular
-----------------------------------------------------------------------------------------------------------


SELECT TableName
	INTO :Temp
	FROM dbc.TablesV
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'dup_celular';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.dup_celular';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE dup_celular'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.dup_celular AS
(
		SELECT  
		numero
		, Count(*)  AS duplicados
		FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
		GROUP BY 1
		HAVING Count(*) >1

)
WITH DATA 
PRIMARY INDEX(numero)';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla dup_celular'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	
		

-----------------------------------------------------------------------------------------------------------
-- Se crea tabla temporal con el conteo final de registros de salida de cada cubo y el numero maximo 
-- de duplicados por dato de contacto (CORREO- CELULAR)
-----------------------------------------------------------------------------------------------------------

SELECT TableName
	INTO :Temp
	FROM dbc.TablesV
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'detalleValores';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.detalleValores';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE detalleValores'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.detalleValores AS
(
		SELECT  
			Cast(''correo'' AS VARCHAR(30)) AS detalle
			, Count(*) conteo 
			,(SELECT Coalesce(Max (duplicados),0)  FROM '||P_BDSTAGE||'.dup_correo) AS duplicado
			FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
			
			UNION ALL
			
			SELECT  ''celular'' AS detalle
			, Count(*) conteo 
			,(SELECT Coalesce(Max (duplicados),0)  FROM '||P_BDSTAGE||'.dup_celular) AS duplicado 
			FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR

)
WITH DATA 
PRIMARY INDEX(detalle)';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla detalleValores'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------------------------------------------------------------------
-- Condiciones de eliminacion de registros por cantidas de duplicados vs cantidad de registros de salida CORREO
-------------------------------------------------------------------------------------------------------------------------------------


SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Correo'
AND duplicado >3
AND conteo >0 AND conteo <=1000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
										WHERE CORREO IN 
										(
													SELECT CORREO
													FROM  '||P_BDSTAGE||'.dup_correo
													WHERE duplicados > 3
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar correos duplicados condicion: Mas de 3 duplicados en base de salida de 1 a 1.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
-------------------------------------------------------------

SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Correo'
AND duplicado >5
AND conteo >1000 AND conteo <=10000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
										WHERE CORREO IN 
										(
													SELECT CORREO
													FROM  '||P_BDSTAGE||'.dup_correo
													WHERE duplicados > 5
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar correos duplicados condicion: Mas de 5 duplicados en base de salida de 1.000 a 10.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
 ----------------------------------------------
 
 SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Correo'
AND duplicado >10
AND conteo >10000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO
										WHERE CORREO IN 
										(
													SELECT CORREO
													FROM  '||P_BDSTAGE||'.dup_correo
													WHERE duplicados > 10
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar correos duplicados condicion: Mas de 10 duplicados en base de salida de mas de 10.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
 
 ------------------------------------------------------------------------------------------------------------------------------------
-- Condiciones de eliminacion de registros por cantidas de duplicados vs cantidad de registros de salida CELULAR
-------------------------------------------------------------------------------------------------------------------------------------


SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Celular'
AND duplicado >3
AND conteo >0 AND conteo <=1000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
										WHERE NUMERO IN 
										(
													SELECT NUMERO
													FROM  '||P_BDSTAGE||'.dup_celular
													WHERE duplicados > 3
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar celulares duplicados condicion: Mas de 3 duplicados en base de salida de 1 a 1.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 

-------------------------------------------------------------

SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Celular'
AND duplicado >5
AND conteo >1000 AND conteo <=10000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
										WHERE NUMERO IN 
										(
													SELECT NUMERO
													FROM  '||P_BDSTAGE||'.dup_celular
													WHERE duplicados > 5
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar celulares duplicados condicion: Mas de 5 duplicados en base de salida de 1.000 a 10.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
 ----------------------------------------------
 
 SELECT detalle
INTO :Temp
FROM  REC_STAGE.detalleValores
WHERE detalle = 'Celular'
AND duplicado >10
AND conteo >10000;


	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DELETE FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
										WHERE NUMERO IN 
										(
													SELECT NUMERO
													FROM  '||P_BDSTAGE||'.dup_celular
													WHERE duplicados > 10
										);';
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Eliminar celulares duplicados condicion: Mas de 10 duplicados en base de salida de mas de 10.000 registros'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

END L1;
    
END;"

==============================================================



" REPLACE   PROCEDURE REC_DATOS."
"PRO_BATCH2_HOMOLOGACIONES"
"
 
(
	IN		P_Lote			INTEGER
	,IN		P_StartTimeStampPadre	VARCHAR(20)
	,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN		P_BDDATOS		VARCHAR(20)
	,IN		P_BDVISTA 		VARCHAR(20)
	,IN		P_BDSTAGE		VARCHAR(20)
	,IN   	P_PLANTILLA         INTEGER
	,IN   	P_SOLICITUD         INTEGER
	,OUT	P_ERROR			VARCHAR(32000)
	
)
/*
 * ################################################################################
 * 
 * Objetivo:	Actualizar el campo HOMOLOGACIONES de cada uno de los cubos.
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_HOMOLOGACIONES
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			          Realizado por
 * 27-11-2017   Version Inicial               Calos Alberto Castillo  
 * 16-05-2018   Ajustar porceso para          Fernando Garrido Molina.(Stefanini)
 *              enmascarar los datos         
 *				cuando se ejecuta una 
 *				solictud de prueba.
 * 30-10-2018   #1 Holomolacion documento como bigint   Calos Alberto Castillo  
 * 14-12-2018   #2 Holomolacion documento como bigint   Calos Alberto Castillo  
 * 15-05-2023   #3 manejo Error cuando Castean a bigint John Bueno  
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE V_QSQL   					VARCHAR	(10000);
	DECLARE V_QSQL2    					VARCHAR	(10000);
	DECLARE V_SQLUP    					VARCHAR	(10000);
	DECLARE V_TABLAFILTRO				VARCHAR	(10000);
	DECLARE Temp 						CHAR	(30);
	DECLARE CNT 						INTEGER;
	DECLARE V_NOMBRE_CUBO				VARCHAR	(30);
	DECLARE Cur_HOMOLOGACIONES NO SCROLL CURSOR 	FOR the_statement;
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------
---------------------------------- HOMOLOGACIONES  ----------------------
-------------------------------------------------------------------------------------------------------------------------------
/* 

Realizar Homologaciones de valores

Una vez se tienen los datos filtrados se debe realizar un proceso de homologaciÃ¸ÂŠÃ´Â³n de los resultados para formateados de acuerdo a las necesidades de 
quÃ¸ÂŠÃ´Â­en solicita el proceso Batch,  estÃ¸ÂŠÃ´Â¡s homologaciones se encuentran definidas para los direferentes campos en la tabla BATCH_HOMOLOGACIONES, En el 
campo CODIGO_CAMPO  se define el campo sobre el cual va a ser aplicada la homologaciÃ¸ÂŠÃ´Â³n, actualmente se tiene definidos los siguientes, pero esto puede 
ser dinÃ¸ÂŠÃ´Â¡mico de acuerdo al campo configurado, ej:
Tipo de IdentificaciÃ¸ÂŠÃ´Â³n (BATCH_CUBO_PERSONA.DB_TIP_ID ) 
Nomenclatura (Direcciones) ( BACTH_CUBO_DIRECCION. DD_DIR )
Los valores a homologar se encuentran definidos en la tabla BATCH_HOMOLOGACIONES, campo VALOR_DEFECTO (Valor que se buscarÃ¸ÂŠÃ´Â­a en el texto del campo y VALOR_HOMOLOGADO, que serÃ¸ÂŠÃ´Â­a el valor por el que serÃ¸ÂŠÃ´Â­a cambiado el texto.


*/

/*#1*/
SET V_CADENA = 'UPDATE rec_stage.BATCH_CUBO_PERSONA SET Numero_Id = TRIM(CAST(Numero_Id AS BIGINT));';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'Homologacion Numero_Id as Bigint',V_ERROR); SET P_ERROR = V_ERROR;

/*#3*/
SET V_CADENA = 'UPDATE REC_STAGE.BATCH_IDENTIFICACIONES_INCONS SET Numero_Id = TRIM(CAST(Numero_Id AS BIGINT)) WHERE ID_SOLICITUD =' ||P_SOLICITUD||' and COALESCE(TO_NUMBER(Numero_Id),0) >0 ;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'Homologacion Numero_Id as Bigint Incons',V_ERROR); SET P_ERROR = V_ERROR;
/*#3*/

---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_HOMG_1 

	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_HOMG_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_HOMG_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_HOMG_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se crea tabla con los campos a homologar ----------------------------------------
-------------------------------------------------------------------------------------
 


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE REC_STAGE.BACTH_HOMG_1 AS (
SELECT 
 SUM(1) OVER(ORDER BY ID_SEQUENCIA  ROWS UNBOUNDED PRECEDING) AS ID
,BSC.CODIGO_CAMPO
 ,B2H.HOMOLOGADO
 ,BSC.VALOR_DEFECTO	
 ,BSC.VALOR_HOMOLOGADO
  ,CASE WHEN CUBO=''Celular'' 	THEN  ''BATCH_CUBO_CELULAR''            
   	WHEN CUBO=''Ciiu'' 		THEN  ''BATCH_CUBO_CIIU''               
   	WHEN CUBO=''Correo'' 		THEN  ''BATCH_CUBO_CORREO''             
   	WHEN CUBO=''Direccion'' 	THEN  ''BATCH_CUBO_DIRECCION''          
   	WHEN CUBO=''Persona'' 	THEN  ''BATCH_CUBO_PERSONA''            
   	WHEN CUBO=''Telefono'' 	THEN  ''BATCH_CUBO_TELEFONO''           
END AS NOMBRE_CUBO
,CUBO
FROM REC_STAGE.BATCH_HOMOLOGACIONES BSC
 INNER JOIN REC_STAGE.BATCH2_HOMOLOGACION B2H
  ON BSC.CODIGO_CAMPO=B2H.CODIGO_CAMPO
  WHERE ID_SOLICITUD ='||P_SOLICITUD||'
  AND ID_PLANTILLA ='||P_PLANTILLA||'
  
  )WITH DATA;
';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_HOMG_1'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	




-----------------------------------------------------------------------------------------------------------------------------------------
-----------Se realizÃ¸ÂŠÃ´Â¡ el formateo de las consultas para crear los DDL--------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_HOMG_2 

	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_HOMG_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_HOMG_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_HOMG_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE REC_STAGE.BACTH_HOMG_2 AS (
SELECT A.*,CAST(MIN(ID) OVER (PARTITION BY CUBO)  AS INTEGER) MIN_ID
,'' CASE WHEN HOMOLOGADO=''''''||HOMOLOGADO||'''''' THEN VALOR_HOMOLOGADO END AS ''||HOMOLOGADO AS FILTRO_SQL1
,CAST(CASE WHEN ID = MIN_ID THEN FILTRO_SQL1 ELSE   '',''||FILTRO_SQL1 END AS VARCHAR(1000))  AS FILTRO_SQLX
,CAST('' LEFT JOIN REC_STAGE.''||CUBO||''HO AS H''||TRIM(ID)||'' ON  H''||TRIM(ID)||''.''||HOMOLOGADO||''1= T1.''||HOMOLOGADO  AS VARCHAR(5000) )AS FILTRO_SQLA
,''CASE WHEN H''||TRIM(ID)||''.''||HOMOLOGADO||'' IS NULL THEN T1.''||HOMOLOGADO||'' ELSE H''||TRIM(ID)||''.''||HOMOLOGADO||'' END AS ''||HOMOLOGADO AS FILTRO_SQLB
,CAST(CASE WHEN ID = MIN_ID THEN FILTRO_SQLB ELSE   '',''||FILTRO_SQLB END AS VARCHAR(5000))  AS FILTRO_SQLC
,CAST(CASE WHEN ID = MIN_ID THEN HOMOLOGADO ||''=HO.'' ||HOMOLOGADO  ELSE   '',''||HOMOLOGADO ||''=HO.'' ||HOMOLOGADO END AS VARCHAR(1000))  SQL_UP
,'' CASE WHEN HOMOLOGADO=''''''||HOMOLOGADO||'''''' THEN VALOR_DEFECTO END AS ''||HOMOLOGADO||''1''  AS FILTRO_SQL0
, CAST(  '',''||FILTRO_SQL0 AS VARCHAR(1000))  AS FILTRO_SQLD
,FILTRO_SQLX||FILTRO_SQLD AS FILTRO_SQL
FROM REC_STAGE.BACTH_HOMG_1 A
QUALIFY (ROW_NUMBER () OVER (PARTITION BY NOMBRE_CUBO,CODIGO_CAMPO ORDER BY ID DESC))=1

)WITH DATA;
';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_HOMG_2'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

  

-----------------------------------------------------------------------------------
------Se crea tabla con los DDL FINALIZADOS ---------------------------------------
-----------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_HOMG_3 

	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_HOMG_3';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_HOMG_3';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_HOMG_3'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se crea una consulta recursiva para anidar cada uno de los filtros por cubo -----
-------------------------------------------------------------------------------------
 


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE REC_STAGE.BACTH_HOMG_3 AS (
WITH RECURSIVE CONCAT_LIST
( ID
,FILTRO_SQL
,FILTRO_SQLA
,FILTRO_SQLC
,SQL_UP
,NOMBRE_CUBO
,CUBO
,AUTO_ID
) AS

(
  SELECT 
  	 ID
	,FILTRO_SQL
	,FILTRO_SQLA
	,FILTRO_SQLC
	,SQL_UP
	,NOMBRE_CUBO
	,CUBO
	,1 AS AUTO_ID
  FROM  REC_STAGE.BACTH_HOMG_2 

  UNION ALL
  
  SELECT  T1.ID
	,T1.FILTRO_SQL||''0A''XC|| T2.FILTRO_SQL
	,T1.FILTRO_SQLA||''0A''XC|| T2.FILTRO_SQLA
	,T1.FILTRO_SQLC||''0A''XC|| T2.FILTRO_SQLC
	,T1.SQL_UP||''0A''XC||T2.SQL_UP
	,T1.NOMBRE_CUBO
	,T1.CUBO
        ,AUTO_ID+1
  FROM   REC_STAGE.BACTH_HOMG_2  T1
  INNER JOIN CONCAT_LIST T2 
   ON T1.CUBO = T2.CUBO
   WHERE T1.ID< T2.ID
)

SELECT 
''CREATE TABLE REC_STAGE.''||CUBO||''HO AS (
  SELECT ''||CL.FILTRO_SQL||
  ''
  FROM REC_STAGE.BACTH_HOMG_1
  ) WITH DATA;'' 
   AS Q_SQL
,''CREATE TABLE REC_STAGE.''||CUBO||''HO1 AS (
  SELECT ID_AUTO,''||CL.FILTRO_SQLC||''
  FROM REC_STAGE.''||CL.NOMBRE_CUBO||'' AS T1
  ''||CL.FILTRO_SQLA||
  ''
  ) WITH DATA;'' 
   AS Q_SQL2   
,''UPDATE T1
FROM REC_STAGE.''||NOMBRE_CUBO||'' T1 ,REC_STAGE.''||CUBO||''HO1  HO
SET ''|| CL.SQL_UP ||''
WHERE T1.ID_AUTO=HO.ID_AUTO;'' AS SQL_UP  
,CL.NOMBRE_CUBO
,CL.CUBO
,CUBO||''HO'' AS TABLA_FILTRO
FROM   CONCAT_LIST CL
QUALIFY (SUM(1)    OVER (PARTITION BY NOMBRE_CUBO ORDER BY CL.AUTO_ID DESC ROWS UNBOUNDED PRECEDING))= 1
) WITH DATA;
';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_HOMG_3'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	








---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸ÂŠÃ´Â³n de HOMOLOGACIONES---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  Q_SQL 
							,Q_SQL2 
							,SQL_UP 
							,NOMBRE_CUBO
							,TABLA_FILTRO 
					FROM '||P_BDSTAGE||'.BACTH_HOMG_3
					ORDER BY 1,2 ;
					';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_HOMOLOGACIONES ;

	CUR2:LOOP
		FETCH Cur_HOMOLOGACIONES  INTO  V_QSQL, V_QSQL2, V_SQLUP, V_NOMBRE_CUBO, V_TABLAFILTRO;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

----------------------------------------------------------------------------------------------------------------
-------------------Borrado de tablas HOMOLOGACIONES si existen ------------------------------------------------
----------------------------------------------------------------------------------------------------------------

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = V_TABLAFILTRO;
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.'||V_TABLAFILTRO;
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE '||V_TABLAFILTRO||''
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------- CreaciÃ¸ÂŠÃ´Â³n de tablas con los filtros calculados -------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=V_QSQL;
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea tabla '||P_BDSTAGE||'.'||V_QSQL||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 




----------------------------------------------------------------------------------------------------------------
-------------------Borrado de tablas HOMOLOGACIONES si existen ------------------------------------------------
----------------------------------------------------------------------------------------------------------------

SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = V_TABLAFILTRO||'1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.'||V_TABLAFILTRO||'1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE '||V_TABLAFILTRO||'1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------- CreaciÃ¸ÂŠÃ´Â³n de tablas con los filtros calculados -------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=V_QSQL2;
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea tabla '||P_BDSTAGE||'.'||V_QSQL2||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 




		
---------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------- UPDATE HOMOLOGACIONES ------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=V_SQLUP;
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'UPDATE HOMOLOGACIONES tabla '||P_BDSTAGE||'.'||V_NOMBRE_CUBO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 


	END LOOP CUR2;

CLOSE Cur_HOMOLOGACIONES ;
	


END L1;

L2:BEGIN 

    SET CNT=0;
	--Validando solicitud de prueba:
	SELECT COUNT(1) CNT
	INTO :CNT
	FROM rec_stage.BATCH_SOLICITUD_BATCH
	WHERE COALESCE(Prueba, 'SV') <> 'SV'
	AND Id_Solicitud = :P_SOLICITUD;
	
	IF CNT > 0 THEN	

	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE ' || P_BDSTAGE ||'.BATCH_CUBO_CELULAR
                    SET Numero = ' || P_BDVISTA||'.DataMasking(Numero);';

		
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(01):Enmascarando celulares'
									,V_ERROR);	

	
	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE ' || P_BDSTAGE ||'.BATCH_CUBO_TELEFONO 
                    SET Numero = ' || P_BDVISTA||'.DataMasking(Numero); ';

		
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(02):Enmascarando telefonos'
									,V_ERROR);	

	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE ' || P_BDSTAGE ||'.BATCH_CUBO_DIRECCION
                    SET Direccion =  ' || P_BDVISTA||'.DirDataMasking(Direccion);';

		
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(02):Enmascarando Direcciones'
									,V_ERROR);	
									
      
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH_CUBO_CORREO_MASK';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_CUBO_CORREO_MASK';	
		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH2_HOMOLOGACIONES(021):Borrando BATCH_CUBO_CORREO_MASK'
										,V_ERROR);	
    END IF;
	
	SET V_CADENA ='';
	SET V_CADENA = 'CREATE MULTISET TABLE ' || P_BDSTAGE ||'.BATCH_CUBO_CORREO_MASK
					AS 
					(SELECT Id_Auto,  
						   rec_vista.DataMasking(rec_vista.eListGetValByIdx(TRIM(correo), ''@'', 1)) buzonMask,
						   rec_vista.eListGetValByIdx(TRIM(correo), ''@'', 2) Ext,
						   Substr(ext, Position(''.'' in  ext)+1, character_length(ext)-1 ) extNew
						   ,correo
						   ,buzonMask||''@XXXX.''||extNew mailMask
					FROM ' || P_BDSTAGE ||'.BATCH_CUBO_CORREO
					)WITH DATA 
					PRIMARY INDEX(ID_Auto);';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(03):Enmascarando Emails, Creando BATCH_CUBO_CORREO_MASK'
									,V_ERROR);	
									
    SET V_CADENA ='';	
	SET V_CADENA = 'COLLECT STAT ' || P_BDSTAGE ||'.BATCH_CUBO_CORREO_MASK INDEX (ID_AUTO);';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(04):Enmascarando Emails, Ejecutando Estadisticas BATCH_CUBO_CORREO_MASK'
									,V_ERROR);
									
    SET V_CADENA = 'UPDATE ' || P_BDSTAGE ||'.BATCH_CUBO_CORREO
					  FROM ' || P_BDSTAGE ||'.BATCH_CUBO_CORREO_MASK
					SET Correo = mailMask
					Where BATCH_CUBO_CORREO.Id_Auto = BATCH_CUBO_CORREO_MASK.Id_Auto';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(05):Enmascarando Emails'
									,V_ERROR);
									
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH_CUBO_PERSONA_MASK';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_CUBO_PERSONA_MASK;';	
		
		CALL REC_DATOS.SP_EX"
"ECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH2_HOMOLOGACIONES(051):Borrando BATCH_C
 UBO_PERSONA_MASK'
										,V_ERROR);	
    END IF;
									
    SET V_CADENA = 'CREATE MULTISET TABLE ' || P_BDSTAGE ||'.BATCH_CUBO_PERSONA_MASK
					AS 
					(SEL ID_AUTO                       	
						,Numero_Id     
						,Nombre_Completo                
						,CASE WHEN Tipo_ID = 2 THEN
							  ' || P_BDVISTA||'.RazonDataMasking(Coalesce(a.Nombre_completo,''''))                   
						   ELSE 
						   Primer_Apellido1||'' ''||Segundo_Apellido1||'' ''||Primer_Nombre1||'' ''||Segundo_Nombre1                		        
						 END Nombre_Completo1     
						,CASE WHEN Tipo_Id <> 2 THEN COALESCE(a.Segundo_Apellido, ''XXXX'') ELSE NULL END  Primer_Apellido1               
						,a.Primer_Apellido Segundo_Apellido1              
						,CASE WHEN Tipo_Id <> 2 THEN COALESCE(a.Segundo_Nombre, ''XXXX'') ELSE NULL END  Primer_Nombre1                 
						,Primer_Nombre Segundo_Nombre1                	     
					FROM  ' || P_BDSTAGE ||'.BATCH_CUBO_PERSONA a
					)WITH DATA 
					PRIMARY INDEX(ID_Auto);';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(06):Enmascarando nombres, Creando BATCH_CUBO_PERSONA_MASK'
									,V_ERROR);
									
    SET V_CADENA = 'COLLECT STAT ' || P_BDSTAGE ||'.BATCH_CUBO_PERSONA_MASK INDEX (ID_AUTO);';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(07):Enmascarando Emails, Ejec Estadisticas en BATCH_CUBO_PERSONA_MASK'
									,V_ERROR);
									
    SET V_CADENA = 'UPDATE ' || P_BDSTAGE ||'.BATCH_CUBO_PERSONA
					FROM ' || P_BDSTAGE ||'.BATCH_CUBO_PERSONA_MASK
					  SET Nombre_Completo = BATCH_CUBO_PERSONA_MASK.Nombre_Completo1
						  ,Primer_Nombre = Primer_Nombre1
						  ,Segundo_Nombre = Segundo_Nombre1
						  ,Primer_Apellido = Primer_Apellido1
						  ,Segundo_Apellido = Segundo_Apellido1   
					WHERE BATCH_CUBO_PERSONA.Id_Auto = BATCH_CUBO_PERSONA_MASK.Id_Auto';
					
	
    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH2_HOMOLOGACIONES(07):Enmascarando Emails, Ejec Estadisticas en BATCH_CUBO_PERSONA_MASK'
									,V_ERROR);
									
   END IF; 
   
END L2;

END;"
""

==============================================================



"REPLACE PROCEDURE REC_DATOS."
"PRO_BATCH_ADD_PORC_INSUMO"
"
( 
	 IN P_Lote 							INTEGER 
	,IN P_StartTimeStampPadre 		VARCHAR(20)
 	,IN P_Nombre_Proceso_Padre 	VARCHAR(30)
 	,IN P_BDSTAGE 						VARCHAR(20)
	,IN P_ID_SOLICITUD				INTEGER
	,IN P_ID_PLANTILLA					INTEGER
 	,OUT P_ERROR 						VARCHAR(32000)
)
 /*
 * ############################################################################################################
 * 
 * Objetivo:		Agregar los campos de porcentaje similitud a la tabla STG_INSUMO_BATCH_VALIDACION
 * Fecha:			2018/02/24
 * Realizado por:	Carlos Castillo
 * Proyecto:		Nuevo reconocer
 * Script:			PRO_BATCH_ADD_PORC_INSUMO
 * 
 * 
 * BITACORA
 * ------------------------------------------------------------------------------------------------
 * Fecha				Objetivo												   Realizado por
 * 2018/02/24   		Agregar los campos de porcentaje similitud		          Luis Carlos R.
 *							a la tabla STG_INSUMO_BATCH_VALIDACION
 * 2019/02/13   		#1 ajuste nombre campos
 * 2019/04/26           #Ajustar Merge para que no actualice el ORDEN_PRIORIDAD   Fernando Garrido.
 *                      cuendo el canal enviado en la validacion es nulo. 
 * 2019/05/15           #Ajuste Posicion Canal Contacto.                          Fernando Garrido. 
 * 2021/01/19           #Eliminar campos de mosaic                                Jeimmy Chavez
 * ------------------------------------------------------------------------------------------------
 * 
 * Copyright 2016 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ############################################################################################################
 */ 

BEGIN
---------------------------------------------------------------------------------------------------------------------
-- Declaracion de variables
---------------------------------------------------------------------------------------------------------------------
	DECLARE V_StartTimeStampPadre 	TIMESTAMP(6);
	DECLARE V_ERROR 							VARCHAR(30);
	DECLARE V_CADENA 						VARCHAR(32000);
	DECLARE Temp 								CHAR(30);
	DECLARE V_VALIDACION VARCHAR(30);

V1:BEGIN
	SET V_VALIDACION = NULL;
	SELECT NOMBRE_SUBSECCION
	INTO :V_VALIDACION
	FROM REC_STAGE.BATCH_SALIDAS_CAMPOS
	WHERE NOMBRE_SUBSECCION LIKE '%Validacion%'
	AND ID_SOLICITUD EQ :P_ID_SOLICITUD
	AND ID_PLANTILLA EQ :P_ID_PLANTILLA
	GROUP BY NOMBRE_SUBSECCION
	QUALIFY ROW_NUMBER() OVER (ORDER BY NOMBRE_SUBSECCION) EQ 1;
	
	SET P_ERROR = CASE WHEN SQLCODE NOT IN (0,7632) THEN SQLCODE ELSE '' END ;	
	
	
IF V_VALIDACION IS NULL THEN
	LEAVE V1;
ELSE
	
L1:BEGIN
	SET P_ERROR 					= '';
 	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');		
	-----------------------------------------------------------------------------------------------------------------
	-- Ajuste Ordenamiento DIRECCION
	-----------------------------------------------------------------------------------------------------------------
	SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'TMP_BATCH_PORPOS_DIR';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.TMP_BATCH_PORPOS_DIR';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH_ADD_PORC_INSUMO(1): DROP TABLE TMP_BATCH_PORPOS_DIR'
										,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
     END IF;

		
	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_BATCH_PORPOS_DIR 
					AS 
					(SEL a.ID_AUTO                       
							,a.Cod_Pin_Persona               
							,a.Cod_DW_Agenda_Batch           
							,a.Cod_DW_Persona_Ubic           
							,a.Direccion                     
							,a.Ciudad                        
							,a.Departamento                  
							,a.Cod_Dane_Ciudad               
							,a.Cod_Dane_Departamento         
							,a.Tipo                          
							,a.Localidad                     
							,a.Barrio                        
							,a.Zona                          
							,a.Estrato                       
							,a.Fecha_ultima_actualizacion    
							,a.Numero_de_entidades_reporta   
							,a.Fuente                        
							/*,a.Grupo_Mosaic                  
							,a.Tipo_Mosaic                   
							,a.Descripcion_Mosaic*/            
							,a.Contactabilidad               
							,a.Medio_Acceso                  
							,a.Mejor_dia_para_gestion        
							,a.Mejor_hora_para_gestion       
							,a.Mejor_Resultado_3Meses        
							,a.Mejor_Resultado_6Meses        
							,a.Reportado_por                 
							,a.Reportado_por_el_Suscriptor   
							,a.Meses_desde_el_ultimo_Reporte 
							,CASE WHEN Orden <= B.CANTIDAD_MAX_CAMPO THEN a.POR_SIM_DIR ELSE NULL END POR_SIM_DIR
							,a.Filtro_A                      
							,a.Filtro_B                      
							,a.Filtro_C                      
							,a.Filtro_D                      
							,a.Filtro_E                      
							,a.Filtro_F                      
							,a.Filtro_G                      
							,a.Filtro_H                      
							,a.Filtro_I                      
							,a.Id_Buro_Persona 
							,ROW_NUMBER()OVER(PARTITION BY ID_BURO_PERSONA ORDER BY ORDEN_PRIORIDAD ASC,Fecha_ultima_actualizacion DESC  , CHAR(TIPO) DESC
											  ,CHAR(DIRECCION) DESC ,Cod_Dane_Ciudad DESC, CIUDAD DESC,DEPARTAMENTO DESC, REC_VISTA.hash_md5(DIRECCION) ASC ) Orden               
					FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION a
					CROSS JOIN  (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
												 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
												AND CODIGO_CAMPO = ''DD_DIR'') B
					WHERE FILTRO_H EQ 0
					)WITH DATA 
					PRIMARY INDEX( ID_AUTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(2):TMP_BATCH_PORPOS_DIR'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;					
    
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STAT INDEX( ID_AUTO) ON '||P_BDSTAGE||'.TMP_BATCH_PORPOS_DIR;';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(3):Etadisticas en TMP_BATCH_PORPOS_DIR'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
				    FROM  '||P_BDSTAGE||'.TMP_BATCH_PORPOS_DIR 
				    SET    POR_SIM_DIR = TMP_BATCH_PORPOS_DIR.POR_SIM_DIR,
							  Orden_Prioridad = Orden
				    WHERE BATCH_CUBO_DIRECCION.ID_Auto = TMP_BATCH_PORPOS_DIR.Id_Auto';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(4):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_DIRECCION'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ---------------------------------------------------------------------------------------------------------------------
	-- Ajuste Ordenamiento Telefono
	-----------------------------------------------------------------------------------------------------------------
	
	
	SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'TMP_BATCH_PORPOS_TEL';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.TMP_BATCH_PORPOS_TEL';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH_ADD_PORC_INSUMO(5): DROP TABLE TMP_BATCH_PORPOS_TEL'
										,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
     END IF;

		
	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_BATCH_PORPOS_TEL
					AS 
					(SEL ID_AUTO                       
						,a.Cod_Pin_Persona               
						,a.Cod_DW_Agenda_Batch           
						,a.Cod_DW_Persona_Ubic           
						,a.Numero                        
						,a.Ciudad                        
						,a.Departamento                  
						,a.Cod_Dane_Ciudad               
						,a.Cod_Dane_Departamento         
						,a.Indicativo                    
						,a.Tipo                          
						,a.Fecha_ultima_actualizacion    
						,a.Numero_de_entidades_reporta   
						,a.Fuente                        
						,a.Reportado_por_el_Suscriptor   
						,a.Meses_desde_el_ultimo_Reporte 
						,a.Contactabilidad               
						,a.Medio_Acceso                  
						,a.Mejor_dia_para_gestion        
						,a.Mejor_hora_para_gestion       
						,a.Mejor_Resultado_3Meses        
						,a.Mejor_Resultado_6Meses        
						,a.Reportado_por                 
						,CASE WHEN Orden <= B.CANTIDAD_MAX_CAMPO THEN a.POR_SIM_TEL  ELSE NULL END POR_SIM_TEL                   		
						,a.Filtro_B                      
						,a.Filtro_C                      
						,a.Filtro_D                      
						,a.Filtro_E                      
						,a.Filtro_F                      
						,a.Filtro_G                      
						,a.Filtro_H                      
						,a.Filtro_I                      
						,a.Id_Buro_Persona 
						,ROW_NUMBER()OVER(PARTITION BY ID_BURO_PERSONA ORDER BY ORDEN_PRIORIDAD ASC,Fecha_ultima_actualizacion DESC,CHAR(TIPO)
										  , CHAR(Numero) DESC ,Cod_Dane_Ciudad DESC, CIUDAD DESC,DEPARTAMENTO DESC, REC_VISTA.hash_md5(Numero) ASC ) Orden               
					FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO a
					CROSS JOIN  (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
								 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
								 AND CODIGO_CAMPO = ''DT_NUM'') B
					WHERE FILTRO_H EQ 0
					)WITH DATA 
					PRIMARY INDEX( ID_AUTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(6):TMP_BATCH_PORPOS_TEL'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;					
    
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STAT INDEX( ID_AUTO) ON '||P_BDSTAGE||'.TMP_BATCH_PORPOS_TEL;';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(6):Etadisticas en TMP_BATCH_PORPOS_TEL'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
				    FROM  '||P_BDSTAGE||'.TMP_BATCH_PORPOS_TEL 
				    SET    POR_SIM_TEL = TMP_BATCH_PORPOS_TEL.POR_SIM_TEL,
							  Orden_Prioridad = Orden
				    WHERE BATCH_CUBO_TELEFONO.ID_Auto = TMP_BATCH_PORPOS_TEL.Id_Auto';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(7):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_TELEFONO'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ---------------------------------------------------------------------------------------------------------------------
	-- Ajuste Ordenamiento Celular
	-----------------------------------------------------------------------------------------------------------------
	
	
	SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'TMP_BATCH_PORPOS_CEL';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.TMP_BATCH_PORPOS_CEL';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH_ADD_PORC_INSUMO(8): DROP TABLE TMP_BATCH_PORPOS_CEL'
										,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
     END IF;

		
	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_BATCH_PORPOS_CEL
					AS 
					(SEL ID_AUTO                       
							,a.Cod_Pin_Persona               
							,a.Cod_DW_Agenda_Batch           
							,a.Cod_DW_Persona_Ubic           
							,a.Numero                        
							,a.Fecha_ultima_actualizacion    
							,a.Numero_de_entidades_reporta   
							,a.Fuente                        
							,a.Reportado_por_el_Suscriptor   
							,a.Meses_desde_el_ultimo_Reporte 
							,a.Contactabilidad               
							,a.Medio_Acceso                  
							,a.Mejor_dia_para_gestion        
							,a.Mejor_hora_para_gestion       
							,a.Mejor_Resultado_3Meses        
							,a.Mejor_Resultado_6Meses        
							,a.Reportado_por                            
							,CASE WHEN Orden <= B.CANTIDAD_MAX_CAMPO THEN a.POR_SIM_CEL  ELSE NULL END POR_SIM_CEL                 		
							,a.Filtro_B                      
							,a.Filtro_C                      
							,a.Filtro_D                      
							,a.Filtro_E                      
							,a.Filtro_F                      
							,a.Filtro_G                      
							,a.Filtro_H                      
							,a.Filtro_I                      
							,a.Id_Buro_Persona 
							,ROW_NUMBER()OVER(PARTITION BY ID_BURO_PERSONA ORDER BY ORDEN_PRIORIDAD ASC,Fecha_ultima_actualizacion DESC  
											  ,CHAR(Numero) DESC,REC_VISTA.hash_md5(Numero) ASC ) Orden               
					FROM '||P_BDSTAGE||'.BATCH_CUBO_CELULAR a
					CROSS JOIN  (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
								 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
								 AND CODIGO_CAMPO = ''DC_NUMERO'') B
					WHERE FILTRO_H EQ 0
					)WITH DATA 
					PRIMARY INDEX( ID_AUTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(9):TMP_BATCH_PORPOS_CEL'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;					
    
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STAT INDEX( ID_AUTO) ON '||P_BDSTAGE||'.TMP_BATCH_PORPOS_CEL;';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(10):Etadisticas en TMP_BATCH_PORPOS_CEL'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
				    FROM  '||P_BDSTAGE||'.TMP_BATCH_PORPOS_CEL 
				    SET    POR_SIM_CEL = TMP_BATCH_PORPOS_CEL.POR_SIM_CEL,
							  Orden_Prioridad = Orden
				    WHERE BATCH_CUBO_CELULAR.ID_Auto = TMP_BATCH_PORPOS_CEL.Id_Auto';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(11):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_CELULAR'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
    ---------------------------------------------------------------------------------------------------------------------
	-- Ajuste Ordenamiento Correo
	-----------------------------------------------------------------------------------------------------------------
	
	
	SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'TMP_BATCH_PORPOS_COR';
		
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.TMP_BATCH_PORPOS_COR';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
										,V_StartTimeStampPadre
										,:P_Nombre_Proceso_Padre
										,:V_CADENA
										,'PRO_BATCH_ADD_PORC_INSUMO(12): DROP TABLE TMP_BATCH_PORPOS_COR'
										,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
     END IF;

		
	SET V_CADENA = ' ';
	SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_BATCH_PORPOS_COR
					AS 
					(SEL ID_AUTO                       
						,a.Cod_Pin_Persona               
						,a.Cod_DW_Agenda_Batch           
						,a.Cod_DW_Persona_Ubic           
						,a.Correo                        
						,a.Fecha_ultima_actualizacion    
						,a.Numero_de_entidades_reporta   
						,a.Fuente                        
						,a.Reportado_por_el_Suscriptor   
						,a.Meses_desde_el_ultimo_Reporte 
						,a.Contactabilidad               
						,a.Medio_Acceso                  
						,a.Mejor_dia_para_gestion        
						,a.Mejor_hora_para_gestion       
						,a.Mejor_Resultado_3Meses        
						,a.Mejor_Resultado_6Meses        
						,a.Reportado_por               
						,CASE WHEN Orden <= B.CANTIDAD_MAX_CAMPO THEN a.POR_SIM_MAIL  ELSE NULL END POR_SIM_MAIL                                   		
						,a.Filtro_B                      
						,a.Filtro_C                      
						,a.Filtro_D                      
						,a.Filtro_E                      
						,a.Filtro_F                      
						,a.Filtro_G                      
						,a.Filtro_H                      
						,a.Filtro_I                      
						,a.Id_Buro_Persona 
						,ROW_NUMBER()OVER(PARTITION BY ID_BURO_PERSONA ORDER BY ORDEN_PRIORIDAD ASC,Fecha_ultima_actualizacion DESC  
										  ,CHAR(Correo) DESC,REC_VISTA.hash_md5(Correo) ASC ) Orden               
					FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO a
					CROSS JOIN  (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
								 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
								 AND CODIGO_CAMPO = ''CE_CORREO'') B
					WHERE FILTRO_H EQ 0
					)WITH DATA 
					PRIMARY INDEX( ID_AUTO);';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(13):TMP_BATCH_PORPOS_COR'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;					
    
	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STAT INDEX( ID_AUTO) ON '||P_BDSTAGE||'.TMP_BATCH_PORPOS_COR;';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(14):Etadisticas en TMP_BATCH_PORPOS_COR'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;
	
	SET V_CADENA = ' ';
	SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_CUBO_CORREO
				    FROM  '||P_BDSTAGE||'.TMP_BATCH_PORPOS_COR 
				    SET    POR_SIM_MAIL = TMP_BATCH_PORPOS_COR.POR_SIM_MAIL,
							  Orden_Prioridad = Orden
				    WHERE BATCH_CUBO_CORREO.ID_Auto = TMP_BATCH_PORPOS_COR.Id_Auto';					

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(15):UPDATE POR_SIM_DIR y Orden_Prioridad En BATCH_CUBO_CORREO'
									,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;

	---------------------------------------------------------------------------------------------------------------------
	-- Agregar porcentajes de similitud a la tabla STG_INSUMO_BATCH_VALIDACION
	-----------------------------------------------------------------"
"------------------------------------------------
	SET V_CADENA = '';
	SET V_CADENA = 'MERGE INTO '||P_BDSTAGE||'.STG_INSUMO_BATCH_VALIDACION X
					USING (SELECT
						VUE.Cod_DW_Reporte_Ubic_Original
						,VUE.Texto_Ubicacion_Original
						,VUE.Cod_DW_Tipo_Ubicacion
						,VUE.Cod_DW_Fuente
						,VUE.Lote
						,VUE.Id_Buro_Suscriptor
						,VUE.Id_Buro_Persona
						,VUE.Cod_DW_Cta
						,VUE.Cod_DW_Hash
						,VUE.Cod_DW_Ubic
						,VUE.Valor
						,VUE.Texto_Ciudad
						,VUE.Codigo_Ciudad_Dane
						,VUE.Fecha_Reporte
						,VUE.Cod_DW_Ubicacion_Original
						,VUE.Cod_DW_Tipo_Ubicacion_Dir
						,VUE.Usuario_BD
						,VUE.Fecha_Desde
						,VUE.Fecha_Hasta
						,VUE.Id_Flag_Nuevo
						,VUE.Id_Flag_Desde
						,VUE.Cod_PIN_Persona
						,VUE.Cod_DW_Pais
						,VUE.TIPO_ID
						,VUE.NUMERO_ID
						,VUE.DIRECCION
						,VUE.TELEFONO
						,VUE.CELULAR
						,VUE.EMAIL
						,VUE.TIPO_DIR_STD
						,VUE.CIUDAD_DIR_INSUMO_STD
						,VUE.DIR_INSUMO_STD
						,VUE.CIUDAD_TEL_INSUMO_STD
						,VUE.TEL_INSUMO_STD
						,VUE.CEL_INSUMO_STD
						,VUE.EMAIL_INSUMO_STD
						,VUE.CIUDAD_DIRECCION
						,VUE.CIUDAD_TELEFONO
						,VUE.DEPARTAMENTO_DIRECCION
						,VUE.DEPARTAMENTO_TELEFONO
						,BCD.POR_SIM_DIR
						,BCD.ORDEN_PRIORIDAD AS ORDEN_PRIORIDAD_DIR
						,BCT.POR_SIM_TEL
						,BCT.ORDEN_PRIORIDAD AS ORDEN_PRIORIDAD_TEL
						,BCC.POR_SIM_CEL
						,BCC.ORDEN_PRIORIDAD AS ORDEN_PRIORIDAD_CEL
						,BCO.POR_SIM_MAIL
						,BCO.ORDEN_PRIORIDAD AS ORDEN_PRIORIDAD_MAIL
						FROM '||P_BDSTAGE||'.VstgBATCHCargaUbicEstandarizada VUE
						LEFT JOIN (SELECT ID_BURO_PERSONA,POR_SIM_DIR,CASE WHEN FILTRO_F IS NULL THEN NULL ELSE  ORDEN_PRIORIDAD END  ORDEN_PRIORIDAD
									FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
									WHERE FILTRO_H EQ 0
									AND ORDEN_PRIORIDAD <= (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
															WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
															AND CODIGO_CAMPO = ''DD_DIR'') 
									QUALIFY ROW_NUMBER() OVER (PARTITION BY ID_BURO_PERSONA ORDER BY POR_SIM_DIR DESC, ORDEN_PRIORIDAD ASC) EQ 1
									) BCD
						ON VUE.ID_BURO_PERSONA EQ BCD.ID_BURO_PERSONA
						LEFT JOIN (SELECT ID_BURO_PERSONA,POR_SIM_TEL,CASE WHEN FILTRO_F IS NULL THEN NULL ELSE  ORDEN_PRIORIDAD END  ORDEN_PRIORIDAD
									FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
									WHERE FILTRO_H EQ 0
									AND ORDEN_PRIORIDAD <= (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
															 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
															 AND CODIGO_CAMPO = ''DT_NUM'')
									QUALIFY ROW_NUMBER() OVER (PARTITION BY ID_BURO_PERSONA ORDER BY POR_SIM_TEL DESC, ORDEN_PRIORIDAD ASC) EQ 1) BCT
						ON VUE.ID_BURO_PERSONA EQ BCT.ID_BURO_PERSONA
						LEFT JOIN (SELECT ID_BURO_PERSONA,POR_SIM_CEL,CASE WHEN FILTRO_F IS NULL THEN NULL ELSE  ORDEN_PRIORIDAD END  ORDEN_PRIORIDAD
									FROM '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
									WHERE FILTRO_H EQ 0
									AND ORDEN_PRIORIDAD <= (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
															 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
															 AND CODIGO_CAMPO = ''DC_NUMERO'')
									QUALIFY ROW_NUMBER() OVER (PARTITION BY ID_BURO_PERSONA ORDER BY POR_SIM_CEL DESC, ORDEN_PRIORIDAD ASC) EQ 1) BCC
						ON VUE.ID_BURO_PERSONA EQ BCC.ID_BURO_PERSONA
						LEFT JOIN (SELECT ID_BURO_PERSONA,POR_SIM_MAIL,CASE WHEN FILTRO_F IS NULL THEN NULL ELSE  ORDEN_PRIORIDAD END  ORDEN_PRIORIDAD
									FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO
									WHERE FILTRO_H EQ 0
									AND ORDEN_PRIORIDAD <= (SEL CANTIDAD_MAX_CAMPO FROM '||P_BDSTAGE||'.BATCH_SALIDAS_CAMPOS
															 WHERE ID_Solicitud = '||P_ID_SOLICITUD||'
															 AND CODIGO_CAMPO = ''CE_CORREO'')
									QUALIFY ROW_NUMBER() OVER (PARTITION BY ID_BURO_PERSONA ORDER BY POR_SIM_MAIL DESC, ORDEN_PRIORIDAD ASC) EQ 1) BCO
						ON VUE.ID_BURO_PERSONA EQ BCO.ID_BURO_PERSONA)
					AS Y (Cod_DW_Reporte_Ubic_Original,Texto_Ubicacion_Original,Cod_DW_Tipo_Ubicacion,Cod_DW_Fuente,Lote,Id_Buro_Suscriptor,Id_Buro_Persona,Cod_DW_Cta,
					Cod_DW_Hash,Cod_DW_Ubic,Valor,Texto_Ciudad,Codigo_Ciudad_Dane,Fecha_Reporte,Cod_DW_Ubicacion_Original,Cod_DW_Tipo_Ubicacion_Dir,Usuario_BD,
					Fecha_Desde,Fecha_Hasta,Id_Flag_Nuevo,Id_Flag_Desde,Cod_PIN_Persona,Cod_DW_Pais,TIPO_ID,NUMERO_ID,DIRECCION,TELEFONO,CELULAR,EMAIL,
					TIPO_DIR_STD,CIUDAD_DIR_INSUMO_STD,DIR_INSUMO_STD,CIUDAD_TEL_INSUMO_STD,TEL_INSUMO_STD,CEL_INSUMO_STD,EMAIL_INSUMO_STD,
					CIUDAD_DIRECCION,CIUDAD_TELEFONO,DEPARTAMENTO_DIRECCION,DEPARTAMENTO_TELEFONO,POR_SIM_DIR,ORDEN_PRIORIDAD_DIR,POR_SIM_TEL,
					ORDEN_PRIORIDAD_TEL,POR_SIM_CEL,ORDEN_PRIORIDAD_CEL,POR_SIM_MAIL,ORDEN_PRIORIDAD_MAIL)
					ON X.ID_BURO_PERSONA = Y.ID_BURO_PERSONA
					WHEN MATCHED THEN UPDATE SET
					POR_SIM_DIR_000 = Y.POR_SIM_DIR,
					ORDEN_PRIORIDAD_DIR_000 = Y.ORDEN_PRIORIDAD_DIR,
					POR_SIM_TEL_000 = Y.POR_SIM_TEL,
					ORDEN_PRIORIDAD_TEL_000 = Y.ORDEN_PRIORIDAD_TEL,
					POR_SIM_CEL_000 = Y.POR_SIM_CEL,
					ORDEN_PRIORIDAD_CEL_000 = Y.ORDEN_PRIORIDAD_CEL,
					POR_SIM_MAIL_000 = Y.POR_SIM_MAIL,
					ORDEN_PRIORIDAD_MAIL_000 = Y.ORDEN_PRIORIDAD_MAIL
					;';
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
									,V_StartTimeStampPadre
									,:P_Nombre_Proceso_Padre
									,:V_CADENA
									,'PRO_BATCH_ADD_PORC_INSUMO(16): Add PORC_SIMILITUD'
									,V_ERROR);
 	SET P_ERROR = V_ERROR;
 	
 	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
 		LEAVE L1;
 	END IF;
	
	END L1;
END IF;
END V1;    

END;"

==============================================================



" REPLACE PROCEDURE REC_DATOS."
"PRO_BATCH2_ADICIONAR_INCON"
"
 
	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre		VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN   	P_PLANTILLA         			INTEGER
		,IN   	P_SOLICITUD         			INTEGER
		,OUT	P_ERROR				VARCHAR(32000)
		
	)
/*
 * ################################################################################
 * 
 * Objetivo:	Actualizar la tabla inconsistencia debido a la comparacion entre batch_solicitud y el cubo persona
 * Fecha:		2018/03/05
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_ADICIONAR_INCON
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 *2018-12-28  	#1 ajuste BIGINT documento   Carlos Castillo
 *2019-01-16 	#2 ajuste a bigint numero_id tabla batch_identificaciones_validas Jeimmy chavez
 *2019-02-05	#3 eliminar de identificaciones validas los registros enviados a inconsistencias con estado 06 y causal 04
 *15-05-2023   #4 manejo Error cuando Castean a bigint 	John Bueno  
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_SQL     					VARCHAR	(32000);
	DECLARE TEMP                           VARCHAR	(150);   
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = Cast(P_StartTimeStampPadre AS TIMESTAMP(6) Format 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------


	SELECT TableName
	INTO :Temp
	FROM dbc.tables
	WHERE Trim(databasename) = :P_BDSTAGE
	AND Trim(TableName) = 'BATCH2_TABLA_INCONSIS_AD_TMP';
	
	IF Activity_Count > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_TABLA_INCONSIS_AD_TMP';

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2_TABLA_INCONSIS_AD_TMP'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF Character_Length(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------------------------------------------------------------------------
----FiltroD: Se crea la tabla con los filtros por campo y cubo ----------------------------
-------------------------------------------------------------------------------------------
SET V_CADENA = ' ';
SET V_CADENA = 
'CREATE TABLE '||P_BDSTAGE||'.BATCH2_TABLA_INCONSIS_AD_TMP AS
(
SEL  
ID_SOLICITUD, 
ID_PLANTILLA,
TIPO_ID,
NUMERO_ID,
''06''  AS ESTADO,
''04'' CAUSAL
FROM  '||P_BDSTAGE||'.batch_identificaciones_validas BS
WHERE
ID_SOLICITUD = '||P_SOLICITUD ||'	
AND ID_PLANTILLA = '||P_PLANTILLA ||'		
AND NOT EXISTS (
               SEL ''X''
			  FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA CP
			  WHERE TRIM(cast(BS.NUMERO_ID as bigint)) = TRIM(CP.NUMERO_ID)
			  AND BS.TIPO_ID = CP.TIPO_ID
			  )
AND NOT EXISTS (SEL ''X''
              FROM REC_STAGE.BATCH_IDENTIFICACIONES_INCONS VER
			  WHERE TRIM(cast(BS.NUMERO_ID as bigint)) = TRIM(VER.NUMERO_ID)
			  AND BS.TIPO_ID = VER.TIPO_ID
			  AND VER.ID_SOLICITUD = BS.ID_SOLICITUD
			  )	
GROUP BY 1,2,3,4,5,6								  
) WITH DATA
PRIMARY INDEX(NUMERO_ID,TIPO_ID)';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea Tabla TMP Inconsist'
				,V_ERROR);
	SET P_ERROR = V_ERROR;

	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	

----------------------Actualizacion Inconsistencias----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO '||P_BDSTAGE||'.BATCH_IDENTIFICACIONES_INCONS
(ID_SOLICITUD,ID_PLANTILLA,TIPO_ID,NUMERO_ID,ESTADO,CAUSAL)
SELECT
ID_SOLICITUD
,ID_PLANTILLA
,TIPO_ID
,NUMERO_ID
,ESTADO
,CAUSAL
FROM  '||P_BDSTAGE||'.BATCH2_TABLA_INCONSIS_AD_TMP';

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insertando En Inconsist'
				,V_ERROR);
	SET P_ERROR = V_ERROR;

	IF Character_Length(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;	


----------------------------------------------------------------------------------------
-- Borrar tabla temporal
----------------------------------------------------------------------------------------


SET V_CADENA = 'DELETE FROM REC_STAGE.BATCH_IDENTIFICACIONES_VALIDAS WHERE (TIPO_ID, CAST(NUMERO_ID AS BIGINT) ) IN (SELECT TIPO_ID, CAST(NUMERO_ID AS BIGINT) FROM REC_STAGE.batch_identificaciones_incons WHERE ESTADO=''06'' AND CAUSAL=''04'' AND ID_SOLICITUD = '||P_SOLICITUD||') AND ID_SOLICITUD = '||P_SOLICITUD||' and COALESCE(TO_NUMBER(Numero_Id),0) >0;'; 
/*#4 maejo Error cuando se castea a BIGINT*/

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote ,V_StartTimeStampPadre ,:P_Nombre_Proceso_Padre ,:V_CADENA ,'BATCH_CUBO_PERSONA: DELETE ESTADO VALIDAS=''estado 06 y causal 04'' ' ,V_ERROR);
SET P_ERROR = V_ERROR;
IF Character_Length(V_ERROR) > 0 THEN LEAVE L1; END IF;
	

/*#1*/
SET V_CADENA = 'UPDATE REC_STAGE.BATCH_IDENTIFICACIONES_INCONS SET Numero_Id = TRIM(CAST(Numero_Id AS BIGINT)) WHERE ID_SOLICITUD =' ||P_SOLICITUD||' and COALESCE(TO_NUMBER(Numero_Id),0) >0;';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote,V_StartTimeStampPadre,:P_Nombre_Proceso_Padre,:V_CADENA,'Homologacion Numero_Id as Bigint Incons',V_ERROR); SET P_ERROR = V_ERROR;


END L1;
    
END;"

==============================================================



"REPLACE  PROCEDURE REC_DATOS."
"PRO_BATCH2_ESTADISTICAS"
"
(
	 IN	 P_Lote					INTEGER
	,IN	 P_StartTimeStampPadre	VARCHAR(20)
	,IN	 P_Nombre_Proceso_Padre	VARCHAR(30)
	,IN	 P_BDVISTA				VARCHAR(20)
	,IN	 P_BDSTAGE				VARCHAR(20)
	,IN	 P_BDDATOS				VARCHAR(20)
	,IN    P_PLANTILLA         INTEGER
	,IN    P_SOLICITUD         INTEGER
	,OUT P_ERROR				VARCHAR(50)
)	
/*
 * ################################################################################
 * 
 * Objetivo:		Calificar los cubos   Telefono, Direccion_Electronica, Direccion , celular y correo por cod_pin
 *                       para las estadisticas
 *			
 * Fecha:		2017/11/26
 * Realizado por:	Fernando Tafur
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_FILTRO_B
 * 
 * 
 * 
 * BITACORA
 * -------------------------------------------------------------------------------------
 * Fecha		Objetivo											Realizado por
 * 23/11/2017	# Historicos Reporte_Ubicacion_Original				Fernando Tafur
 * 22/08/2018	#1 Ajuste ID vista VSTG_BATCH_ESTADISTICAS_EXP		Carlos Castillo
 * 28/09/2018	#2 Ajuste conteo PROC								Carlos Castillo
 * 04/10/2018	#3 Ajuste Conteo repetidos 							Carlos Castillo 
 * 01/03/2019   #CQ81348 Ajustas Estadisticas Inconsistentes        Fernando Garrido.
 * 23/07/2019   #5 Ajuste tipos de identificacion, se elimina 
                validacion por descripcion, se realiza por codigo   Jeimmy chavez
 * 27/01/2022   #20220127 Ajuste incidente estadisticas             Fernando Garrido.
 * 02/12/2022	# Ajuste del TOTAL BASEENTRADA y manejo Duplicados
 *				adicion a ID_NO_VALIDOS con Estado <> 21 en INCONSISTENCIAS	 	John Wilmer Bueno
 * 15/05/2023	#Ajuste para Errores con Referente al Numero de identificacion	John Wilmer Bueno
 * 30/05/2023	#Adicion de nuevos Tipos de Identificacion 						John Wilmer Bueno
 * --------------------------------------------------------------------------------------
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
-- Declaraci??n de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE Temp					 		CHAR(30);

	
	
L1:	BEGIN

	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
		

  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2_ESTADISTICAS_TMP';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2_ESTADISTICAS_TMP';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2_ESTADISTICAS_TMP'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- GENERA  CONTADORES  -------------
---------------------------------------------------------------------------------------------------------------------------------------------
 
 
 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'SQL-PARAM',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;
 

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- GENERICA INCONSIS TABLA ------------- Taba de trabajo
---------------------------------------------------------------------------------------------------------------------------------------------
 
  SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'vstg_INCONSIS_PNPJ_TABLA';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE vstg_INCONSIS_PNPJ_TABLA'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
 SET V_CADENA = ' ';
 SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA  AS
(
SEL *
FROM  '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ   
) WITH DATA ';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2_ESTADISTICAS_TMP'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- GENERALES  PROC ---------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------


 SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH_CUBO_PERSONA_UNICO';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_CUBO_PERSONA_UNICO';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH_CUBO_PERSONA_UNICO'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;
 
 SET V_CADENA = ' ';
 SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BATCH_CUBO_PERSONA_UNICO 
AS
(
SEL COD_PIN_PERSONA
FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
GROUP BY 1
) WITH DATA
PRIMARY INDEX (COD_PIN_PERSONA) ';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2_ESTADISTICAS_TMP'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

 ------------------------ ESSTADISTICAS --------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'ESTADISTICAS',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


---------------- CUBOS TEMPORALES

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'TMP_ESTADISTICAS',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;

 
 
------------------------------------------------------------------------
---------PROC GENERALES
--------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
SET CONTEO = 0
WHERE ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE Tabla CONTEO'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------
---------PROC GENERALES:20220127  Creando tablas de trabajo 
------------------------------------------------------------------------

 SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH_TMP_CALCULO_CON_DATOS';
		
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH_TMP_CALCULO_CON_DATOS'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS
				AS 
				(
				SELECT  ''DIRECCION'' ORIGEN,  ID_BURO_PERSONA 
				 FROM  '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
				 WHERE  COALESCE(FILTRO_H,0) = 0
				 Group by ID_BURO_PERSONA
				 )WITH DATA 
				 PRIMARY INDEX(ORIGEN);';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Creado tabla BATCH_TMP_CALCULO_CON_DATOS'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS
				 SELECT ''CELULAR'' ,id_buro_persona FROM  '||P_BDSTAGE||'.BATCH_CUBO_CELULAR 
				 Where  Id_buro_persona NOT IN (Select Id_Buro_persona  From  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS)
				 and COALESCE(FILTRO_H,0) = 0
				 group by id_buro_persona ;';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Insertando celulares en BATCH_TMP_CALCULO_CON_DATOS'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS
				 SELECT ''CORREO'' ,id_buro_persona FROM  '||P_BDSTAGE||'.BATCH_CUBO_CORREO 
				 Where  Id_buro_persona NOT IN (Select Id_Buro_persona  From  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS)
				 and COALESCE(FILTRO_H,0) = 0
				 group by id_buro_persona ;';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Insertando CORREO en BATCH_TMP_CALCULO_CON_DATOS'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA ='INSERT INTO  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS
				 SELECT ''TELEFONO'' ,id_buro_persona FROM  '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
				 Where  Id_buro_persona NOT IN (Select Id_Buro_persona  From  '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS)
				 and COALESCE(FILTRO_H,0)=0
				 group by id_buro_persona ;';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Insertando TELEFONO en BATCH_TMP_CALCULO_CON_DATOS'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

/*SET V_CADENA = ' ';
SET V_CADENA = '

UPDATE '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
FROM --#2
(SELECT ''PROC'' TIPO
		,sum(totales) CONTEOX  
From (Select  CASE WHEN B.tipo_id=''1'' THEN ''ID_CC_CON_DATOS''
		       WHEN B.tipo_id=''2'' THEN ''ID_NIT_CON_DATOS'' 
		       WHEN B.tipo_id=''3'' THEN ''ID_NITE_CON_DATOS''  
		       WHEN B.tipo_id=''4'' THEN ''ID_CE_CON_DATOS'' END TIPO
		       ,Count(*) Totales 		     
		From '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS A 
		INNER JOIN (SELECT ID_BURO_PERSONA , TIPO_ID
								 FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
								 group by 1,2) B
		ON A.Id_Buro_Persona = B.Id_Buro_persona 
		Group by 1) a
) TMP_FINAL
SET CONTEO = TMP_FINAL.CONTEOX
WHERE TRIM(IDENTIFICADOR) = ''GENERALES''
AND TRIM(VALOR1) = TMP_FINAL.TIPO
AND ID_SOLICITUD =  '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE Tabla PRO-Registro Procesados'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	*/


---Se devuelve el cambio.
SET V_CADENA = ' ';
SET V_CADENA = '

UPDATE '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
FROM --#2
(
		SEL
		''PROC'' TIPO
		,SUM(TOTAL) CONTEOX
		FROM 
		(
		SELECT 
		 CASE WHEN I.NOMBRE_TIPO_IDENT=''Cedula de Ciudadania'' THEN ''ID_CC_CON_DATOS''
		 WHEN I.NOMBRE_TIPO_IDENT=''Nit Juridicos'' THEN ''ID_NIT_CON_DATOS'' 
		 WHEN I.NOMBRE_TIPO_IDENT=''Nit de Extranjeria'' THEN ''ID_NITE_CON_DATOS''  
		 WHEN I.NOMBRE_TIPO_IDENT=''Cedula de Extranjeria'' THEN ''ID_CE_CON_DATOS'' END TIPO
		 , COUNT(*) TOTAL
		 FROM 
		 (SELECT tipo_id 
		 FROM '||P_BDSTAGE||'.BATCH_IDENTIFICACIONES_VALIDAS
		 WHERE id_solicitud='||P_SOLICITUD||'
		 UNION ALL
		 SELECT tipo_id 
		 FROM '||P_BDSTAGE||'.BATCH_IDENTIFICACIONES_INCONS
		 WHERE ID_SOLICITUD='||P_SOLICITUD||'
		 ) CP
		 LEFT JOIN BDM_VISTA.V_TIPO_IDENTIFICACION I
		 ON CP.TIPO_ID = I.Cod_Tipo_Ident_Fte   
		 GROUP BY 1		
		) TEMP
				GROUP BY 1
) TMP_FINAL
SET CONTEO = TMP_FINAL.CONTEOX
WHERE TRIM(IDENTIFICADOR) = ''GENERALES''
AND TRIM(VALOR1) = TMP_FINAL.TIPO
AND ID_SOLICITUD =  '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE Tabla PRO-Registro Procesados'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	
------------------------------------------------------------------------
---------FIN PROC GENERALES:20220127  Creando tablas de trabajo 
------------------------------------------------------------------------

------------------------------------------------------------------------
---------INICIO PROC GENERALES:20221102  Creando tablas de trabajo Adicionales-- John Bueno
------------------------------------------------------------------------
/*CALCULO PARA EL TOTAL DE LA BASE DE ENTRADA*/
SET V_CADENA = ' ';
SET V_CADENA = '

UPDATE '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
FROM --#2
(		SEL
		''BASE_EN'' TIPO
		,TOTAl CONTEOX
		FROM 
		(SELECT COUNT(1) TOTAL
			FROM '||P_BDSTAGE||'.batch_valform_st2	
		) TEMP
) TMP_FINAL
SET CONTEO = TMP_FINAL.CONTEOX
WHERE TRIM(IDENTIFICADOR) = ''GENERALES''
AND TRIM(VALOR1) = TMP_FINAL.TIPO
AND ID_SOLICITUD =  '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE Tabla PRO-BASE_EN'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

/*CALCULO PARA EL TOTAL DE LOS DUPLICADOS*/
SET V_CADENA = ' ';
SET V_CADENA = '

UPDATE '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
FROM --#2
(		SEL
		''BASE_DUP'' TIPO
		,TOTAl CONTEOX
		FROM 
		(SELECT COUNT(1) TOTAL
			FROM '||P_BDSTAGE||'.batch_valform_st4
			WHERE Val_Dupe=0 
			AND ID_SOLICITUD =  '||P_SOLICITUD||'
			AND ID_PLANTILLA = '||P_PLANTILLA||'
		) TEMP
) TMP_FINAL
SET CONTEO = TMP_FINAL.CONTEOX
WHERE TRIM(IDENTIFICADOR) = ''GENERALES''
AND TRIM(VALOR1) = TMP_FINAL.TIPO
AND ID_SOLICITUD =  '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';

	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE Tabla PRO-BASE_DUP'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;
------------------------------------------------------------------------
---------FIN PROC GENERALES:20221102  Creando tablas de trabajo Adicionales-- John Bueno
------------------------------------------------------------------------
------------------------------------------------------------------------
---------FIN PROC GENERALES:20220127  Creando tablas de trabajo 
------------------------------------------------------------------------

------------------------------------------------------------------------
---------INCONSISTENCIAS
--------------------------------------------------------------------


SET V_CADENA = ' ';
SET V_CADENA = '
UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
SET CONTEO = 
(
		SEL
		COUNT(*) TOTAL
		FROM '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA
		WHERE ID_SOLICITUD =  '||P_SOLICITUD||'
		AND ID_PLANTILLA = '||P_PLANTILLA||'
		
)
WHERE IDENTIFICADOR = ''GENERALES''
AND VALOR1 =  ''INCO''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDTE. Inconsistencias'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------
---------CAUSAL Y ESTADO
--------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA ='COLLECT STATISTICS COLUMN (CAUSAL) ON '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA';
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Estadisticas Causal'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
				SEL 
				CR.IDENTIFICADOR IDENTIFICADORX
				,CR.VALOR1 VALOR1X
				,COUNT(*) CUANTOS
				FROM  '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA tw
				INNER JOIN REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS CR
				ON TRIM(TW.CAUSAL) = TRIM(CR.CRITERIO)				
				WHERE CR.CAMPO = ''CAUSAL''
				AND CR.IDENTIFICADOR = ''GENERALES''
				AND CR.VALOR1 <> ''ID_NV''
				GROUP BY 1,2
				) TMP
				SET CONTEO = TMP.CUANTOS
				WHERE IDENTIFICADOR = TMP.IDENTIFICADORX
				AND VALOR1 = TMP.VALOR1X
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'UPDATE Causal <> ID_NV'
								,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

------------------------------------------------------------------------
---------INICIO PROC GENERALES:20221102  MODIFICACION EN IDS NO VALIDOS-- John Bueno
------------------------------------------------------------------------
SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
				SEL
				IDENTIFICADOR IDENTIFICADORX
				,VALOR1 VALOR1X
				,COUNT(*) CUANTOS
				FROM(
				SEL TW.*,CR.IDENTIFICADOR
				,CR.VALOR1 FROM  '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA tw
				INNER JOIN REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS CR
				ON TRIM(TW.CAUSAL)  = TRIM(CR.CRITERIO)				
				AND TRIM(TW.ESTADO) = ''''
				WHERE CR.CAMPO = ''CAUSAL''				
				AND CR.IDENTIFICADOR = ''GENERALES''
				AND CR.VALOR1 = ''ID_NV''
				UNION ALL 
				SEL TW.*
				,CAST(''GENERALES'' AS VARCHAR(100)) IDENTIFICADORX
				,CAST(''ID_NV'' AS VARCHAR(100)) VALOR1X 
				FROM  REC_STAGE.VSTG_INCONSIS_PNPJ_TABLA TW
				WHERE  TRIM(TW.ESTADO) NOT IN ('''',''21'')
				AND (TRIM(TW.CAUSAL)  is null or TRIM(TW.CAUSAL) <>''06'')
				) T1
				GROUP BY 1,2)TMP
				SET CONTEO = TMP.CUANTOS
				WHERE IDENTIFICADOR = TMP.IDENTIFICADORX
				AND VALOR1 = TMP.VALOR1X
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';
------------------------------------------------------------------------
---------FIN PROC GENERALES:20221102  MODIFICACION EN IDS NO VALIDOS-- John Bueno
------------------------------------------------------------------------				


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'UPDATE Causal = ID_NV'
								,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
				SEL 
				CR.IDENTIFICADOR IDENTIFICADORX
				,CR.VALOR1 VALOR1X
				,COUNT(*) CUANTOS
				FROM  '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA tw
				INNER JOIN REC_DATOS.PRO_BATCH2_F"
"ILTROS_ESTADISTICAS CR
				ON TRIM(TW.CAUSAL)  = ''05''								
	
 			WHERE CR.CAMPO = ''CAUSAL''				
				AND CR.IDENTIFICADOR = ''GENERALES''
				AND CR.VALOR1 = ''ID_NE''

 				GROUP BY 1,2
				) TMP
				SET CONTEO = COALESCE(CONTEO,0) + TMP.CUANTOS
				WHERE IDENTIFICADOR = TMP.IDENTIFICADORX
				AND VALOR1 = TMP.VALOR1X
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'UPDATE Causal = ID_NE'
								,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
				SEL 
				CR.IDENTIFICADOR IDENTIFICADORX
				,CR.VALOR1 VALOR1X
				,COUNT(*) CUANTOS
				FROM  '||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA tw
				INNER JOIN REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS CR
				ON TRIM(TW.ESTADO)  = TRIM(CR.CRITERIO)				
				WHERE CR.CAMPO = ''ESTADO''				
				AND CR.IDENTIFICADOR = ''GENERALES''				
				GROUP BY 1,2
				) TMP
				SET CONTEO = TMP.CUANTOS
				WHERE IDENTIFICADOR = TMP.IDENTIFICADORX
				AND VALOR1 = TMP.VALOR1X
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'UPDATE Estado'
								,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



------------------------------------------------------------------------
--------UBICACIONES - 20220127 Ajuste conteo
------------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
					SELECT sum(totales) TOTAL,  ''CON_UBI'' TIPO
					From   
					(Select         
								  CASE WHEN B.tipo_id=''1'' THEN ''ID_CC_CON_DATOS''
								   WHEN B.tipo_id=''2'' THEN ''ID_NIT_CON_DATOS'' 
								   WHEN B.tipo_id=''3'' THEN ''ID_NITE_CON_DATOS''  
								   WHEN B.tipo_id=''4'' THEN ''ID_CE_CON_DATOS'' END TIPO
								   ,		     Count(*) Totales 		     
					From '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS A 
					INNER JOIN (SELECT ID_BURO_PERSONA , TIPO_ID
											 FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
											 group by 1,2) B
					ON A.Id_Buro_Persona = B.Id_Buro_persona 
					Group by 1) a

					UNION ALL 

					SELECT Count(Distinct Id_Buro_Persona), ''SIN_UBI'' TIPO
					From '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
					Where Id_Buro_Persona not in (Select Id_Buro_persona From '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS)

				) TMP_FINAL
				SET CONTEO = TMP_FINAL.TOTAL
				WHERE TRIM(IDENTIFICADOR) = ''GENERALES''
				AND TRIM(VALOR1) = TRIM(TMP_FINAL.TIPO)
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';



CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE. Ubicaciones CON_UBI SIN_UBI ajs 20220127'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

------------------------------------------------------------------------
--------FIN UBICACIONES - 2
--0220127 Ajuste conteo
------------------------------------------------------------------------


SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM
				(
				SEL
				CR.IDENTIFICADOR IDENTIFICADORX
				,CR.VALOR1 VALOR1X
				,CONTEO.TOTAL CONTEOX
				FROM
				(
				SEL  
				CAST(''CON_DIR'' AS VARCHAR(50))  TIPO
				,COUNT(DISTINCT ID_BURO_PERSONA) TOTAL
				FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA CE
				WHERE  EXISTS       (SEL ''X''
												  FROM '||P_BDSTAGE||'.BATCH_CUBO_TEMP_DIR_TOTAL BP 
												  WHERE CE.ID_BURO_PERSONA = BP.ID_BURO_PERSONA
												  AND TOTAL_DIR = 0	
												  )				  
				and  COALESCE(CE.FILTRO_H,0) = 0

				UNION

				SEL  
				CAST(''CON_TEL'' AS VARCHAR(50))  TIPO
				,COUNT(DISTINCT ID_BURO_PERSONA) TOTAL
				FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA CE
				WHERE  EXISTS       (SEL ''X''
												  FROM '||P_BDSTAGE||'.BATCH_CUBO_TEMP_TELEFONO_TOTAL BP 
												  WHERE CE.ID_BURO_PERSONA = BP.ID_BURO_PERSONA
												  AND TOTAL_TEL = 0	
												  )				  
				and  COALESCE(CE.FILTRO_H,0) = 0

				UNION

				SEL  
				CAST(''CON_CEL'' AS VARCHAR(50))  TIPO
				,COUNT(DISTINCT ID_BURO_PERSONA) TOTAL
				FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA CE
				WHERE  EXISTS       (SEL ''X''
												  FROM '||P_BDSTAGE||'.BATCH_CUBO_TEMP_CELULAR_TOTAL BP 
												  WHERE CE.ID_BURO_PERSONA = BP.ID_BURO_PERSONA
												  AND TOTAL_CEL = 0	
												  )				  
				and  COALESCE(CE.FILTRO_H,0) = 0

				UNION

				SEL  
				CAST(''CON_EMAIL'' AS VARCHAR(50))  TIPO
				,COUNT(DISTINCT ID_BURO_PERSONA) TOTAL
				FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA CE
				WHERE  EXISTS       (SEL ''X''
												  FROM '||P_BDSTAGE||'.BATCH_CUBO_TEMP_CORREO_TOTAL BP 
												  WHERE CE.ID_BURO_PERSONA = BP.ID_BURO_PERSONA
												  AND TOTAL_CORREO = 0	
												  )				  
				and  COALESCE(CE.FILTRO_H,0) = 0

				) CONTEO
				INNER JOIN REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS CR
				ON CR.VALOR1 = CONTEO.TIPO
				WHERE  CR.IDENTIFICADOR = ''GENERALES''
				) TMP
				SET CONTEO = TMP.CONTEOX
				WHERE IDENTIFICADOR = TMP.IDENTIFICADORX
				AND TRIM(VALOR1) = TRIM(TMP.VALOR1X)
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE. Ubicaciones'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------
--------GENERALES CC, CE, NIT ,NITE - 20220127 Ajuste conteo
------------------------------------------------------------------------

 

------------------------------------------------------------------------
--------GENERALES CÃ©dula de ciudadanÃ­a y NUIP	1 ,NIT	2,NIT de ExtranjerÃ­a	3,CÃ©dula de ExtranjerÃ­a	4,Pasaporte	5,Carnet DiplomÃ¡tico/PPT	6,Tarjeta de Identidad	7,Documento Nacional de Identidad	8,Permiso Especial de Permanencia	9
---20230530 Ajuste conteo
------------------------------------------------------------------------

--- 20220127: Se comente instruccion

   /*CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'CONTEO_TIPO_DOC',P_ERROR);
	 SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;*/
--

---20230530
SET V_CADENA = ' ';
SET V_CADENA = 'UPDATE  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
				FROM (Select         
							  CASE WHEN B.tipo_id=''1'' THEN ''ID_CC_CON_DATOS''
							   WHEN B.tipo_id=''2'' THEN ''ID_NIT_CON_DATOS'' 
							   WHEN B.tipo_id=''3'' THEN ''ID_NITE_CON_DATOS''  
							   WHEN B.tipo_id=''4'' THEN ''ID_CE_CON_DATOS'' 
							   WHEN B.tipo_id=''5'' THEN ''ID_PAS_CON_DATOS'' 
							   WHEN B.tipo_id=''6'' THEN ''ID_PPT_CON_DATOS'' 
							   WHEN B.tipo_id=''7'' THEN ''ID_TI_CON_DATOS'' 
							   WHEN B.tipo_id=''8'' THEN ''ID_DNI_CON_DATOS'' 
							   WHEN B.tipo_id=''9'' THEN ''ID_PEP_CON_DATOS'' 
							   END TIPO
							   ,		     Count(*) TOTAL 		     
				From '||P_BDSTAGE||'.BATCH_TMP_CALCULO_CON_DATOS A 
				INNER JOIN (SELECT ID_BURO_PERSONA , TIPO_ID
										 FROM '||P_BDSTAGE||'.BATCH_CUBO_PERSONA
										 group by 1,2) B
				ON A.Id_Buro_Persona = B.Id_Buro_persona 
				Group by 1 
					  ) TEMP
				SET  CONTEO = TEMP.TOTAL
				WHERE IDENTIFICADOR = ''GENERALES''
				AND TRIM(VALOR1) = TRIM(TEMP.TIPO)
				AND ID_SOLICITUD = '||P_SOLICITUD||'
				AND ID_PLANTILLA = '||P_PLANTILLA||'';
				
---20230530

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'UPDATE. CONTEO_TIPO_DOC'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------
--------FIN GENERALES CC, CE, NIT ,NITE - 20220127 Ajuste conteo
------------------------------------------------------------------------



------------------------------------------------------------------------
--------RANGO  EDAD
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'ESTADIS_EDAD',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
--------CIUDAD DIR_TOTAL Y CIUDAD_DIR1
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'CIUDAD_DIR',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
--------CIUDAD TEL_TOTAL Y TELEFONO_DIR1
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'TELEFONO_DIR',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;

------------------------------------------------------------------------
--------GENERO
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'GENERO',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
--------DIR_POR_IDENT
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'DIR_POR_IDENT',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
--------TEL_POR_IDENT
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'TEL_POR_IDENT',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;



------------------------------------------------------------------------
-------- TIPO DIR
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'ESTADIS_DIR',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;

------------------------------------------------------------------------
-------- TIPO TEL
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'ESTADIS_TEL',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
-------- ESTRATO
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'ESTAD_ESTRATO',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;


------------------------------------------------------------------------
-------- ESTRATO
-----------------------------------------------------------------------

 CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'CIIU',P_ERROR);
 SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
END IF;



--#start new
------------------------------------------------------------------------
-- DISTRIB_INGRESOS
-----------------------------------------------------------------------
CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'DISTRIB_INGRESOS',P_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

------------------------------------------------------------------------
-- DISTRIB_EGRESOS
-----------------------------------------------------------------------
CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'DISTRIB_EGRESOS',P_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

------------------------------------------------------------------------
-- CANT_INGRESOS
-----------------------------------------------------------------------
CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'CANT_INGRESOS',P_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;

------------------------------------------------------------------------
-- CANT_EGRESOS
-----------------------------------------------------------------------
CALL REC_DATOS.PRO_BATCH2_ESTADISTICAS_CFG(P_LOTE,P_StartTimeStampPadre,P_Nombre_Proceso_Padre,P_BDVISTA,P_BDSTAGE,P_BDDATOS,P_PLANTILLA,P_SOLICITUD ,'CANT_EGRESOS',P_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;
-- #end new

------------------------------------------------------------------------
-------- REP_DIR_100
-----------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = '
DELETE FROM '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR IN(''REP_DIR_100'',''REP_TEL_100'',''REP_CEL_100'',''REP_MAIL_100'')
AND ID_PLANTILLA =  '||P_PLANTILLA||'
AND ID_SOLICITUD =  '||P_SOLICITUD||'';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Borrando. REP_DIR_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------

SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO('||P_SOLICITUD||','||P_PLANTILLA||',''REP_DIR_100'',''IDENTIFICADOR'','' '',0)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. TIT REP_DIR_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
(ID_SOLICITUD,ID_PLANTILLA,IDENTIFICADOR,VALOR1,VALOR2,CONTEO)
SEL
 '||P_SOLICITUD||'
, '||P_PLANTILLA||'
,CAST(''REP_DIR_100'' AS CHAR(20)) IDENTIFICADOR
,CIUDAD VALOR1
,DIRECCION VALOR2
,COUNT(*)  CONTADOR 
FROM '||P_BDSTAGE||'.BATCH_CUBO_DIRECCION
WHERE Direccion IS NOT NULL
AND FILTRO_H = 0
GROUP BY 1,2,3,4,5
HAVING CONTADOR > 1
QUALIFY ROW_NUMBER() OVER (ORDER BY CONTADOR DESC) <= 100';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. DAT REP_DIR_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

---

SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO('||P_SOLICITUD||','||P_PLANTILLA||',''REP_TEL_100'',''IDENTIFICADOR'','' '',0)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. TIT REP_TEL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
(ID_SOLICITUD,ID_PLANTILLA,IDENTIFICADOR,VALOR1,VALOR2,CONTEO)
SEL
 '||P_SOLICITUD||'
, '||P_PLANTILLA||'
,CAST(''REP_TEL_100'' AS CHAR(20)) IDENTIFICADOR
,CIUDAD VALOR1
,NUMERO VALOR2
,COUNT(*)  CONTADOR 
FROM '||P_BDSTAGE||'.BATCH_CUBO_TELEFONO
WHERE NUMERO IS NOT NULL
AND FILTRO_H = 0
GROUP BY 1,2,3,4,5
HAVING CONTADOR > 1
QUALIFY ROW_NUMBER() OVER (ORDER BY CONTADOR DESC) <= 100';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. DAT REP_TEL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

---

SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO('||P_SOLICITUD||','||P_PLANTILLA||',''REP_CEL_100'',''IDENTIFICADOR'','' '',0)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. TIT REP_CEL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
(ID_SOLICITUD,ID_PLANTILLA,IDENTIFICADOR,VALOR1,CONTEO)
SEL
 '||P_SOLICITUD||'
, '||P_PLANTILLA||'
,CAST(''REP_CEL_100'' AS CHAR(20)) IDENTIFICADOR
,NUMERO VALOR1
,COUNT(*)  CONTADOR 
FROM '||P_BDSTAGE||'.BATCH_CUBO_CELULAR
WHERE NUMERO IS NOT NULL
AND FILTRO_H = 0
GROUP BY 1,2,3,4
HAVING CONTADOR > 1
QUALIFY ROW_NUMBER() OVER (ORDER BY CONTADOR DESC) <= 100';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. DAT REP_CEL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

------

SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO  '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO('||P_SOLICITUD||','||P_PLANTILLA||',''REP_MAIL_100'',''IDENTIFICADOR'','' '',0)';

CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. TIT REP_CEL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



SET V_CADENA = ' ';
SET V_CADENA = '
INSERT INTO '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
(ID_SOLICITUD,ID_PLANTILLA,IDENTIFICADOR,VALOR1,CONTEO)
SEL
 '||P_SOLICITUD||'
, '||P_PLANTILLA||'
,CAST(''REP_MAIL_100'' AS CHAR(20)) IDENTIFICADOR
,CORREO VALOR1
,COUNT(*)  CONTADOR 
FROM '||P_BDSTAGE||'.BATCH_CUBO_CORREO
WHERE CORREO IS NOT NULL
AND FILTRO_H = 0
GROUP BY 1,2,3,4
HAVING CONTADOR > 1
QUALIFY ROW_NUMBER() OVER (ORDER BY CONTADOR DESC) <= 100';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Poblando. DAT REP_MAIL_100'
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


------------------------------------------------------------------------
-------- VISTAS REPORTE CONTROL
-----------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = '
REPLACE VIEW '||P_BDSTAGE||'.V_STG_DIRTOP10 AS 
LOCK ROW FOR ACCESS   
SELECT TOP 10 6 AS ID, TRIM(VALOR2)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CIUDAD_DIR1''
AND ID_SOLICITUD = '"
"||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'	
AND CONTEO > 0
ORDER BY CONTEO desc';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Creando Vista V_STG_DIRTOP10 '
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

-----------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = '
REPLACE VIEW '||P_BDSTAGE||'.V_STG_TELTOP10 AS 
LOCK ROW FOR ACCESS   
SELECT TOP 10 8 AS ID, TRIM(VALOR2)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM '||P_BDDATOS||'.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CIUDAD_TEL1''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'		
AND CONTEO > 0
ORDER BY CONTEO desc';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,
:V_CADENA
			,
 'Creando Vista V_STG_TELTOP10 '
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	







-----------------------------------------------------------------------


SET V_CADENA = ' ';
--#1 se agrega id2 al campo id final de la vista
SET V_CADENA = 'REPLACE VIEW '||P_BDSTAGE||'.VSTG_BATCH_ESTADISTICAS_EXP
AS 
LOCK ROW FOR ACCESS   
(
SELECT SUM(1) OVER(ORDER BY ID,ID2,CAMPO ROWS UNBOUNDED PRECEDING) AS ID,CAMPO  
FROM(
SELECT * FROM (SELECT CAST(1 AS INTEGER) AS ID,CAST(1 AS INTEGER) AS ID2, CAST(''PARTE_1''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 2 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''GENERALES''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'  
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
--#start new ADD MAYRA

UNION ALL
SELECT 2 AS ID,110+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''GENERO''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'  
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL

SELECT 2 AS ID,220+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, ''REG_ING;''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CANT_INGRESOS''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL

SELECT 2 AS ID,330+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,  ''REG_EGR;''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CANT_EGRESOS''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
UNION ALL

SELECT 2 AS ID,440+ROW_NUMBER() OVER (ORDER BY CAST(VALOR    AS INTEGER) DESC) ID2,CAST(''REGISTROS_LEIDOS'' AS VARCHAR(250)) ||'';''||TRIM(CAST(VALOR    AS INTEGER)) AS CAMPO 
FROM  REC_STAGE.BATCH_ARCHIVO_LOG
WHERE ID IN (7)
UNION ALL


--#3

SELECT 2 AS ID,550+ROW_NUMBER() OVER (ORDER BY CAST(COUNT(TIPO_ID||NUMERO_ID) - COUNT(DISTINCT TIPO_ID||NUMERO_ID) AS INTEGER) DESC) ID2,CAST(''DIR'' AS VARCHAR(4)) ||'';''||TRIM(CAST(COUNT(TIPO_ID||NUMERO_ID) - COUNT(DISTINCT TIPO_ID||NUMERO_ID) AS INTEGER))  AS CAMPO
FROM (
SELECT TIPO_ID,NUMERO_ID  FROM REC_STAGE.BATCH_IDENTIFICACIONES_VALIDAS WHERE ID_SOLICITUD = '||P_SOLICITUD||' AND ID_PLANTILLA = '||P_PLANTILLA||' 
UNION ALL
SELECT TIPO_ID,NUMERO_ID FROM REC_STAGE.BATCH_IDENTIFICACIONES_incons WHERE ID_SOLICITUD = '||P_SOLICITUD||' AND ID_PLANTILLA = '||P_PLANTILLA||' 
) A



UNION ALL 
SELECT 2 AS ID,660+ROW_NUMBER() OVER (ORDER BY CAST(VALOR    AS INTEGER)DESC) ID2,CAST(''REGISTROS_GRABADOS'' AS VARCHAR(250)) ||'';''||TRIM(CAST(VALOR    AS INTEGER)) AS CAMPO 
FROM  REC_STAGE.BATCH_ARCHIVO_LOG
WHERE ID IN (8)



--#end new ADD MAYRA
UNION ALL 
SELECT * FROM (SELECT 3 AS ID,2 AS ID2,CAST(''PARTE_2''||
'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 4 AS ID,20+ROW_NUMBER() OVER (ORDER BY CAST(CONTEO AS INTEGER) DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''RANGO_EDAD''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 

SELECT * FROM (SELECT 5 AS ID,3 ID2, CAST(''PARTE_3''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT ID, 20+ROW_NUMBER() OVER (ORDER BY CAST(REGEXP_REPLACE( (REGEXP_REPLACE(CAMPO, ''[^;0-9]+'', '' '', 1, 0, ''i'' )  ),'';'','' '') AS INTEGER) DESC) ID2, CAMPO
FROM REC_STAGE.V_STG_DIRTOP10
UNION ALL 
SELECT * FROM (SELECT 7 AS ID,4 AS ID2, CAST(''PARTE_4''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT ID, 20+ROW_NUMBER() OVER (ORDER BY CAST(REGEXP_REPLACE( (REGEXP_REPLACE(CAMPO, ''[^;0-9]+'', '' '', 1, 0, ''i'' )  ),'';'','' '') AS INTEGER) DESC) ID2, CAMPO 
FROM REC_STAGE.V_STG_TELTOP10 

UNION ALL 
SELECT * FROM (SELECT 9 AS ID,5 AS ID2, CAST(''PARTE_5''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 10 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''GENERO''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 
SELECT * FROM (SELECT 11 AS ID,6 AS ID2,CAST(''PARTE_6''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 12 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''DIR_POR_IDENT''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 
SELECT * FROM (SELECT 13 AS ID,7 AS ID2,CAST(''PARTE_7''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 14 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''TEL_POR_IDENT''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 

SELECT * FROM (SELECT 15 AS ID,8 AS ID2,CAST(''PARTE_8''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 16 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''TIPO_DIR''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 

SELECT * FROM (SELECT 17 AS ID,9 AS ID2,CAST(''PARTE_9''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 18 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''TIPO_TEL''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 
SELECT * FROM (SELECT 19 AS ID,10 AS ID2,CAST(''PARTE_10''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 20 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''ESTRATO''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 

SELECT * FROM (SELECT 21 AS ID,11 AS ID2,CAST(''PARTE_11''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 22 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(VALOR2)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CIUDAD_DIR_TOTAL''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
AND CONTEO>0
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
UNION ALL 

SELECT * FROM (SELECT 23 AS ID,12 AS ID2, CAST(''PARTE_12''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 24 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(VALOR1)||'';''||TRIM(VALOR2)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CIUDAD_DIR_TOTAL''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
AND CONTEO>0
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 
SELECT * FROM (SELECT 25 AS ID, 13 AS ID2,CAST(''PARTE_13''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT * FROM (SELECT 26 AS ID, 13 AS ID2,CAST(''1''||'';''||''A''||'';''||''REPETIDOS TELEFONO''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT * FROM (SELECT 27 AS ID, 13 AS ID2,CAST(''1''||'';''||''E''||'';''||''CIUDAD''||'';''||'' TELEFONO''||'';''||'' REPETIDOS'' AS VARCHAR(250)) AS CAMPO) A UNION ALL

SELECT 28 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,TRIM(1)||'';''||TRIM(''D'')||'';''|| TRIM(COALESCE(VALOR1,''''))||'';''||TRIM(COALESCE(VALOR2,''''))||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''REP_TEL_100''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0

UNION ALL 
SELECT * FROM (SELECT 29 AS ID, 13 AS ID2,CAST(''2''||'';''||''A''||'';''||''REPETIDOS DIRECCION''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT * FROM (SELECT 30 AS ID, 13 AS ID2,CAST(''2''||'';''||''E''||'';''||''CIUDAD''||'';''||'' DIRECCION''||'';''||'' REPETIDOS'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 31 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,TRIM(2)||'';''||TRIM(''D'')||'';''|| TRIM(COALESCE(VALOR1,''''))||'';''||TRIM(COALESCE(VALOR2,''''))||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''REP_DIR_100''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
UNION ALL 
SELECT * FROM (SELECT 32 AS ID, 13 AS ID2,CAST(''3''||'';''||''A''||'';''||''REPETIDOS CELULAR''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT * FROM (SELECT 33 AS ID, 13 AS ID2,CAST(''3''||'';''||''E''||'';''||'' CELULAR''||'';''||'' REPETIDOS'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 34 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,TRIM(3)||'';''||TRIM(''D'')||'';''|| TRIM(COALESCE(VALOR1,''''))||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''REP_CEL_100''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
UNION ALL 
SELECT * FROM (SELECT 35 AS ID, 13 AS ID2,CAST(''7''||'';''||''A''||'';''||''REPETIDOS MAIL''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT * FROM (SELECT 36 AS ID, 13 AS ID2,CAST(''7''||'';''||''E''||'';''||'' MAIL''||'';''||'' REPETIDOS'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 37 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,TRIM(7)||'';''||TRIM(''D'')||'';''|| TRIM(COALESCE(VALOR1,''''))||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''REP_MAIL_100''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
UNION ALL
SELECT 38 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2,CASE WHEN CONTEO = 0 THEN CAST(''FIN_PARTE_13''||'';'' AS VARCHAR(250))  ELSE  TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) END AS CAMPO 
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''CIIU''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||' 
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
--#start new ADD MAYRA
UNION ALL
SELECT * FROM (SELECT 39 AS ID, 14 AS ID2,CAST(''PARTE_14''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 40 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(IDENTIFICADOR)||'';''||TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''DISTRIB_INGRESOS''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
UNION ALL
SELECT * FROM (SELECT 41 AS ID,15 AS ID2,CAST(''PARTE_15''||'';'' AS VARCHAR(250)) AS CAMPO) A UNION ALL
SELECT 42 AS ID,20+ROW_NUMBER() OVER (ORDER BY CONTEO DESC) ID2, TRIM(IDENTIFICADOR)||'';''||TRIM(VALOR1)||'';''||TRIM(CAST(CONTEO AS INTEGER)) AS CAMPO
FROM REC_DATOS.BATCH_ESTADISTICAS_PRO
WHERE IDENTIFICADOR=''DISTRIB_EGRESOS''
AND ID_SOLICITUD = '||P_SOLICITUD||'
AND ID_PLANTILLA = '||P_PLANTILLA||'
QUALIFY ROW_NUMBER() OVER ( ORDER BY CONTEO DESC ) > 0
UNION ALL
SELECT * FROM (SELECT 43 AS ID,200 AS ID2,CAST(''FIN_PARTE_15''||'';'' AS VARCHAR(250)) AS CAMPO) T
--#end new ADD MAYRA
) X
)
';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Creando Vista VSTG_BATCH_ESTADISTICAS_EXP '
			,V_ERROR);
SET P_ERROR = V_ERROR;
IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



END L1;
    
END;"
""

==============================================================



"REPLACE   PROCEDURE REC_DATOS."
"PRO_BATCH2_TRANSPUESTA"
"


	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre	VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDDATOS				VARCHAR(20)
		,IN		P_BDVISTA 				VARCHAR(20)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN		P_Batch2_PNPJ 			VARCHAR(20)
		,OUT	P_ERROR					VARCHAR(32000)
		
	)
/*
 * ################################################################################
 * 
 * Objetivo:	TRANSPUESTA de campos para el archivo de salida. 		
 *			Entradas     Vstg_Batch2_PNPJ 
 *			     		   Vstg_Batch2_PN    
 *			     		   Vstg_Batch2_PJ
 *			Salidas 	TB_Vstg_Batch2_PNPJ
 *				    	TB_Vstg_Batch2_PN   
 *				    	TB_Vstg_Batch2_PJ
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_TRANSPUESTA
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE V_ID 	  					VARCHAR	(10);
	DECLARE	V_QSQL						VARCHAR	(63900);
	DECLARE Temp 						CHAR	(30);
	DECLARE Cur_TRANSPUESTA NO SCROLL CURSOR 	FOR the_statement;
	
	
	
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------------------------------------------------------
---------------------------------- TRANSPUESTA  ----------------------
-------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--1.se realizÃ¡ la identificaciÃ³n de las columnas que se deben transponer ------
-------------------------------------------------------------------------------
        LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_CAMPOS';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS AS (
SELECT  ordenamiento COLUMNID
 ,CASE WHEN xalias=''CBPER'' THEN Valor_Ini ELSE CampoNuevo END CAMPOS
FROM rec_stage.v_ba2_Campos_Salida 
) WITH DATA ;

';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_CAMPOS'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



-------------------------------------------------------------------------------
--2.se crea la tabla para la inserciÃ³n de registros              ------
-------------------------------------------------------------------------------
        LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'TB_'||P_Batch2_PNPJ||'';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TB_'||P_Batch2_PNPJ;
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE '||P_BDSTAGE||'.TB_'||P_Batch2_PNPJ||''
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.TB_'||P_Batch2_PNPJ||'  (
    COLUMNID INTEGER NULL
    ,COLUMNA VARCHAR(30) NULL
    ,VALORES VARCHAR(1000) NULL
    ,TIPO_ID VARCHAR (10) NULL
    ,NUMERO_ID VARCHAR(20) NULL
    )PRIMARY INDEX(NUMERO_ID,COLUMNID);
';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla .TB_'||P_Batch2_PNPJ||''
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



-----------------------------------------------------------------------------------------------------------------------------------------
-----------Se realizÃ¡ el formateo de las consultas para crear los DDL--------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------
-- Borrado de tabla temporal BACTH_CAMPOS_1 
	LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS_1';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_1';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS_1'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;



SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_1 AS (SELECT AUTO_ID,ID,COLUMNID,MAX (ID_C) OVER 
(PARTITION BY ID ) AS MAX_ID,MIN (ID_C) OVER (PARTITION BY ID ) AS MIN_ID,MAX(AUTO_ID) OVER () AS MAX_TABLE,
CASE WHEN ID_C=MIN_ID THEN ''CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_TEMP 
AS (SELECT COLUMNID,CAMPOS ,MAX(CASE ''||SQL_1 WHEN ID_C=MAX_ID THEN SQL_1||'' END )AS
C''||TRIM(ID)||'' FROM '||P_BDSTAGE||'.BACTH_CAMPOS AS BC 
CROSS JOIN '||P_BDSTAGE||'.'||P_Batch2_PNPJ||' AS T GROUP BY 1,2 ) 
WITH DATA PRIMARY INDEX(COLUMNID);'' ELSE SQL_1 END AS SQL_2 FROM 
(SELECT SUM(1) OVER(ROWS UNBOUNDED PRECEDING) AS AUTO_ID,ID	,COLUMNID
,ROW_NUMBER() OVER (PARTITION BY ID ORDER BY ID,COLUMNID ) AS ID_C,''WHEN T.ID=''||TRIM(T.ID)||''
AND TRIM(CAMPOS) =''''''||TRIM(CAMPOS)||'''''' THEN T.''||CAMPOS AS SQL_1 
FROM '||P_BDSTAGE||'.BACTH_CAMPOS AS BC CROSS JOIN '||P_BDSTAGE||'.'||P_Batch2_PNPJ||' T) A )WITH DATA PRIMARY INDEX(ID,COLUMNID);';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_CAMPOS_1'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

  

-----------------------------------------------------------------------------------
------Se crea tabla con los DDL FINALIZADOS ---------------------------------------
-----------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Borrado de tabla temporal  
	LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_CAMPOS_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se unifica cada uno de los ddls por registro ------------------------------------
-------------------------------------------------------------------------------------
 


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_2 
AS (
SELECT ID, XMLAGG((SQL_2) ORDER BY AUTO_ID) AS SQL_TRANS
   FROM '||P_BDSTAGE||'.BACTH_CAMPOS_1 
   GROUP BY ID
 )WITH DATA ;';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_CAMPOS_2'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	



-- Borrado de tabla temporal BACTH_HOMG_3 
	LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS_2';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_CAMPOS_2';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS_2'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se unifica cada uno de los ddls por registro ------------------------------------
-------------------------------------------------------------------------------------
 


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_2 
AS (
SELECT ID, XMLAGG((SQL_2) ORDER BY AUTO_ID) AS SQL_TRANS
   FROM '||P_BDSTAGE||'.BACTH_CAMPOS_1 
   GROUP BY ID
 )WITH DATA ;';


	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_CAMPOS_2'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

-----
-----
-- Borrado de tabla temporal BACTH_HOMG_3 
	LOCKING ROW FOR ACCESS  
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS_3';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BACTH_CAMPOS_3';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS_3'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;

-------------------------------------------------------------------------------------
----Se unifica cada uno de los ddls por registro -------------------------
-------------------------------------------------------------------------------------

SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BACTH_CAMPOS_3 (ID INTEGER NULL ,SQL_TRANS VARCHAR(64000) NULL);';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BACTH_CAMPOS_3'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	

SET V_CADENA = ' ';
SET V_CADENA = 'INSERT INTO '||P_BDSTAGE||'.BACTH_CAMPOS_3 SELECT ID ,SQL_TRANS FROM '||P_BDSTAGE||'.BACTH_CAMPOS_2 ;';
	
CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'INSERT Tabla BACTH_CAMPOS_3'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ³n de TRANSPUESTA---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  TRIM(ID),SQL_TRANS
					FROM '||P_BDSTAGE||'.BACTH_CAMPOS_3
					ORDER BY ID ;
					';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_TRANSPUESTA ;

	CUR2:LOOP
		FETCH Cur_TRANSPUESTA  INTO  V_ID, V_QSQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

----------------------------------------------------------------------------------------------------------------
-------------------Borrado de tablas TRANSPUESTA si existen ------------------------------------------------
----------------------------------------------------------------------------------------------------------------
LOCKING ROW FOR ACCESS  
SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BACTH_CAMPOS_TEMP';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.'||'BACTH_CAMPOS_TEMP';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BACTH_CAMPOS_TEMP'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


-------------------------- CreaciÃ³n de tablas con los registros transpuestos --------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA=V_QSQL;
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Crea tabla '||P_BDSTAGE||'.'||V_QSQL||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	

		SET V_CADENA=	'INSERT INTO  '||P_BDSTAGE||'.TB_'||P_Batch2_PNPJ||'
						          SELECT T1.ColumnId
						         	      ,T1.CAMPOS 
						         	      ,T2.C'||V_ID||' 
						         	      ,MAX(CASE WHEN T1.CAMPOS=''Tipo_Id'' THEN T2.C'||V_ID||'  END) OVER ()
								      ,MAX(CASE WHEN T1.CAMPOS=''Numero_Id'' THEN T2.C'||V_ID||'  END) OVER ()
						          FROM '||P_BDSTAGE||'.BACTH_CAMPOS T1
						           LEFT JOIN '||P_BDSTAGE||'.BACTH_CAMPOS_TEMP  T2
						           ON T1.COLUMNID=T2.COLUMNID
						';
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'INSERT TABLA '||P_Batch2_PNPJ||''
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	END LOOP CUR2;

CLOSE Cur_TRANSPUESTA ;

END L1;
    
END;"

==============================================================



"REPLACE PROCEDURE REC_DATOS."
"PRO_Batch2_Completitud_Canal"
"
	(
		 IN	P_Lote			INTEGER
		,IN	P_StartTimeStampPadre	VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN	P_BDVISTA		VARCHAR(20)
		,IN	P_BDSTAGE		VARCHAR(20)
		,IN	P_BDDATOS		VARCHAR(20)
		,IN	P_PLANTILLA		INTEGER
		,IN	P_SOLICITUD		INTEGER
		,OUT P_ERROR		VARCHAR(50)
	)

/*
 * ################################################################################
 * 
 * Objetivo:		Batch2 - Determinar Inconsistentes Completitud x Canal
 * Fecha:		2017-12-28
 * Lider Tecnico:	
 * Realizado por:	Holmer Alfonso H
 * Parametros:	
 * Proyecto:	
 * Script:		
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 2019-07-26 Agregar LOCK ROW FOR ACCESS  sentecia para las vistas Jeimmy chavez
 * ---------------------------------------------------------------------------
 * 
 * Copyright 2017 Equipo Teradata - Capgemini
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Capgemini S.A.S y
 * 		se encuentra protegido por las leyes de derechos de autor
 * 
 * 
 * ################################################################################
 */


BEGIN
	
	

------------------------
-- Declaración de variables
------------------------
	DECLARE V_StartTimeStampPadre	TIMESTAMP(6);
	DECLARE V_ERROR			VARCHAR(300);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE Temp CHAR(30);
	DECLARE V_INDICE	INTEGER;
	DECLARE V_ITERA	INTEGER;
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');


L1:	BEGIN

/* ===================================================
	**********  INICIO Creación tablas y vistas STAGE  **********
 ====================================================
*/

--	Vista de Datos
	SET V_CADENA = '';
	SET V_CADENA = ('REPLACE VIEW '||P_BDSTAGE||'.v_Datos_tmp1 AS LOCK ROW FOR ACCESS  (
	select * from rec_stage.Vstg_Batch2_PNPJ
	union
	select * from rec_stage.Vstg_Batch2_PJ
	union
	select * from rec_stage.Vstg_Batch2_PN ) ; ') ; 
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea vista en STAGE v_Datos_tmp1'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



-- Vista Telefono Fijo
	SET V_CADENA = '';
	SET V_CADENA = ('REPLACE VIEW '||P_BDSTAGE||'.v_Telefono_tmp1 as LOCK ROW FOR ACCESS 
(
	select Y.*, row_number() over(order by serie, orden, codigo_campo) as q from  
	 (
		 select X.* from 
		 ( select xalias, codigo_campo, camponuevo, right(camponuevo,3) as serie, 0 as orden from '||P_BDSTAGE||'.v_ba2_Campos_Salida ) as X
		 where codigo_campo in (''DT_NUM'')
		 UNION
		select X.* from 
		 ( select xalias, codigo_campo, camponuevo, right(camponuevo,3) as serie, 1 as orden from '||P_BDSTAGE||'.v_ba2_Campos_Salida ) as X
		 where codigo_campo in (''DT_CIUDAD'',''DT_DEPARTA'',''DT_DAN_CIU'',''DT_DAN_DEP'',''DT_INDICAT'',''DT_TIPO'')
	) as Y
	where to_number(serie) <= (select count(*) as cont from '||P_BDSTAGE||'.v_ba2_Campos_Salida where codigo_campo in (''DT_NUM''))
)   ; ') ; 

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea vista en STAGE v_Telefono_tmp1'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



--  Vista  Direccion
	SET V_CADENA = '';
	SET V_CADENA = ('REPLACE VIEW '||P_BDSTAGE||'.v_Direccion_tmp1 as LOCK ROW FOR ACCESS 
(
	select Y.*, row_number() over(order by serie, orden, codigo_campo) as q from  
	 (
		 select X.* from 
		 ( select xalias, codigo_campo, camponuevo, right(camponuevo,3) as serie, 0 as orden from '||P_BDSTAGE||'.v_ba2_Campos_Salida ) as X
		 where codigo_campo in (''DD_DIR'') 
		 UNION
		select X.* from 
		 ( select xalias, codigo_campo, camponuevo, right(camponuevo,3) as serie, 1 as orden from '||P_BDSTAGE||'.v_ba2_Campos_Salida group by 1,2,3 ) as X
		 where codigo_campo in (''DD_CIUDAD'',''DD_DEPARTA'',''DD_DAN_CIU'',''DD_DAN_DEP'',''DD_TIPO'')
	) as Y
	where to_number(serie) <= (select count(*) as cont from '||P_BDSTAGE||'.v_ba2_Campos_Salida where codigo_campo in (''DD_DIR''))
)   ; ') ; 

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea vista en STAGE v_Direccion_tmp1'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;



----   Inicio del ciclo TELEFONO   
--  Crear Sentencia Creacion Tabla Temporal dinamica Telefono
	SET V_CADENA = '';
	SET V_CADENA = ('Insert Into '||P_BDSTAGE||'.w_borrar_002
	select 1, '' CREATE TABLE '||P_BDSTAGE||'.tabla_w1 ( Secuencia INTEGER,  ID INTEGER '' from '||P_BDSTAGE||'.secuencia A where secuencia=1
	union 
	Select CAST((1+alfa) as integer) , '','' || A.codigo_campo || ''  varchar(100)    ''
	From (Select codigo_campo, camponuevo, orden, q as alfa From '||P_BDSTAGE||'.v_Telefono_tmp1 B where serie = 1) A
	union 
	select 99, '' )  PRIMARY INDEX (Secuencia)  '' from '||P_BDSTAGE||'.secuencia C where secuencia=1  ; ') ; 
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Sentencia en STAGE w_borrar_002'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


--  Pre Ejecutar Sentencia Creacion Tabla Temporal dinamica Telefono
	SET V_CADENA = '';
	SET V_CADENA = ('Insert Into '||P_BDSTAGE||'.w_Ejecutor select 1, (xmlagg(Detalle order by Secuencia) )  from '||P_BDSTAGE||'.w_borrar_002 ; ') ; 

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea vista en STAGE Dinamico 2'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-- Ejecutar Sentencia de Creacion 
	SET V_CADENA = '';
	Select campo into :V_CADENA from REC_STAGE.w_Ejecutor ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla en STAGE tabla_w1'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;




--	Definir Iteraciones para Loop de TELEFONO
	SET V_ITERA = 1;
	Select count(*) into :V_INDICE From REC_STAGE.v_Telefono_tmp1 where codigo_campo = 'DT_NUM' ;


	--WHILE ( V_ITERA<=V_INDICE ) DO
	WHILE ( V_ITERA=1 ) DO
	Begin

		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_borrar_002 ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_Ejecutor ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002  Select 1,'' Insert Into rec_stage.tabla_w1  Select  TOP 100 SUM(1) OVER (ROWS UNBOUNDED PRECEDING)+B.Secuencia AS auto_id, A.ID '' From rec_stage.secuencia A where secuencia=1 ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-1 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002 
			Select (1+alfa) cont , '', A.'' || camponuevo From (Select codigo_campo, camponuevo, orden, q as alfa From REC_STAGE.v_Telefono_tmp1 where serie = 1) A  ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-3 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002 
Select	SUM(1) OVER (ROWS UNBOUNDED PRECEDING) +B.Secuencia AS auto_id  , ''FROM REC_STAGE.v_Datos_tmp1 A , (select COALESCE(MAX(Secuencia),0) Secuencia from rec_stage.tabla_w1) B
	where A.ID in ( select ID from rec_stage.v_Datos_tmp1 where ( '' from (Select coalesce(max(Secuencia),0) Secuencia from REC_STAGE.w_borrar_002) B ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-4 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		/*
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002 
Select	SUM(1) OVER (ROWS UNBOUNDED PRECEDING) +B.Secuencia AS auto_id,''Select ''''CASE when TRIM(COALESCE('''' || camponuevo || '''', '''''''''''' ''''''''''''))='''' || '''''''''''''''''''''''' || '''' then 1 else 0 end  + ''''
		From (Select codigo_campo, camponuevo, orden, q as alfa From REC_STAGE.v_Telefono_tmp1 where serie = 1) A''
  from (Select coalesce(max(Secuencia),0) Secuencia from REC_STAGE.w_borrar_002) B ' ; 
		*/
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002
Select	SUM(1) OVER (ROWS UNBOUNDED PRECEDING) +B.Secuencia AS auto_id , 
 ''CASE when TRIM(COALESCE('' || camponuevo || '', '''''' ''''''))='' || '''''''''''' || '' then 1 else 0 end  + ''
		From (Select codigo_campo, camponuevo, orden, q as alfa From REC_STAGE.v_Telefono_tmp1 where serie = 1) A  ,
 (Select coalesce(max(Secuencia),0) Secuencia from REC_STAGE.w_borrar_002) B ' ; 

		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-5 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = ' INSERT INTO '||P_BDSTAGE||'.w_borrar_002 Select 99, '' 0 ) > 0 ) '' ' ; 

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-6 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = ' INSERT INTO '||P_BDSTAGE||'.w_Ejecutor  Select 2, xmlagg(Detalle order by Secuencia) from REC_STAGE.w_borrar_002 ; ' ; 

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_Ejecutor-1 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		Select Campo into :V_CADENA From REC_STAGE.w_Ejecutor where Secuencia = 2 ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_Ejecutor-2 TT'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_ITERA=V_ITERA+1;
	end;
	END WHILE;



--==================================================

		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_borrar_002 ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_Ejecutor ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;

--==================================================
----   Inicio del ciclo  DIRECCION 
--==================================================
--  Crear Sentencia Creacion Tabla Temporal dinamica Direccion
	SET V_CADENA = '';
	SET V_CADENA = ('Insert Into '||P_BDSTAGE||'.w_borrar_002
	select 1, '' CREATE TABLE '||P_BDSTAGE||'.tabla_w2 ( Secuencia INTEGER,  ID INTEGER '' from '||P_BDSTAGE||'.secuencia A where secuencia=1
	union 
	Select CAST((1+alfa) as integer) , '','' || A.codigo_campo || ''  varchar(100)    ''
	From (Select codigo_campo, camponuevo, orden, q as alfa From '||P_BDSTAGE||'.v_Direccion_tmp1 B where serie = 1) A
	union 
	select 99, '' )  PRIMARY INDEX (Secuencia)  '' from '||P_BDSTAGE||'.secuencia C where secuencia=1  ; ') ; 
	
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Sentencia en STAGE w_borrar_002 DD'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


--  Pre Ejecutar Sentencia Creacion Tabla Temporal dinamica Direccion
	SET V_CADENA = '';
	SET V_CADENA = ('Insert Into '||P_BDSTAGE||'.w_Ejecutor select 1, (xmlagg(Detalle order by Secuencia) )  from '||P_BDSTAGE||'.w_borrar_002 ; ') ; 

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea vista en STAGE Dinamico 2 DD'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


-- Ejecutar Sentencia de Creacion 
	SET V_CADENA = '';
	Select campo into :V_CADENA from REC_STAGE.w_Ejecutor ;

	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla en STAGE tabla_w2 DD'
			,V_ERROR);
	SET P_ERROR = V_ERROR;
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
		LEAVE L1;
	END IF;


--	Definir Iteraciones para Loop de DIRECCION
	SET V_ITERA = 1;
	Select count(*) into :V_INDICE From REC_STAGE.v_Direccion_tmp1 where codigo_campo = 'DD_DIR' ;


	--WHILE ( V_ITERA<=V_INDICE ) DO
	WHILE ( V_ITERA=2 ) DO
	Begin

		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_borrar_002 ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'Delete '||P_BDSTAGE||'.w_Ejecutor ;' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Delete REC_STAGE.w_borrar_002 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;



		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002  Select 1,'' Insert Into rec_stage.tabla_w2  Select  TOP 100 SUM(1) OVER (ROWS UNBOUNDED PRECEDING)+B.Secuencia AS auto_id, A.ID '' From rec_stage.secuencia A where secuencia=1 ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-1 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002 
			Select (1+alfa) cont , '', A.'' || camponuevo From (Select codigo_campo, camponuevo, orden, q as alfa From REC_STAGE.v_Direccion_tmp1 where serie = 1) A  ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-3 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002 
Select	SUM(1) OVER (ROWS UNBOUNDED PRECEDING) +B.Secuencia AS auto_id  , ''FROM REC_STAGE.v_Datos_tmp1 A , (select COALESCE(MAX(Secuencia),0) Secuencia from rec_stage.tabla_w2) B
	where A.ID in ( select ID from rec_stage.v_Datos_tmp1 where ( '' from (Select coalesce(max(Secuencia),0) Secuencia from REC_STAGE.w_borrar_002) B ' ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-4 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = 'INSERT INTO REC_STAGE.w_borrar_002
Select	SUM(1) OVER (ROWS UNBOUNDED PRECEDING) +B.Secuencia AS auto_id , 
 ''CASE when TRIM(COALESCE('' || camponuevo || '', '''''' ''''''))='' || '''''''''''' || '' then 1 else 0 end  + ''
		From (Select codigo_campo, camponuevo, orden, q as alfa From REC_STAGE.v_Direccion_tmp1 where serie = 1) A  ,
 (Select coalesce(max(Secuencia),0) Secuencia from REC_STAGE.w_borrar_002) B ' ; 

		
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-5 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = ' INSERT INTO '||P_BDSTAGE||'.w_borrar_002 Select 99, '' 0 ) > 0 ) '' ' ; 

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_borrar_002-6 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		SET V_CADENA = ' INSERT INTO '||P_BDSTAGE||'.w_Ejecutor  Select 2, xmlagg(Detalle order by Secuencia) from REC_STAGE.w_borrar_002 ; ' ; 

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_Ejecutor-1 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_CADENA = '';
		Select Campo into :V_CADENA From REC_STAGE.w_Ejecutor where Secuencia = 2 ;

		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Insert REC_STAGE.w_Ejecutor-2 DD'
				,V_ERROR);
		SET P_ERROR = V_ERROR;
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1; 
		END IF;


		SET V_ITERA=V_ITERA+1;
	end;
	END WHILE;




	END L1;
    
END;"

==============================================================



"REPLACE PROCEDURE REC_DATOS."
"PRO_BATCH2_CANTREPCANAL_CON"
"
	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre		VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDDATOS				VARCHAR(20)
		,IN		P_BTTVISTA 				VARCHAR(20)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN		P_ID_SOLICITUD			INTEGER
		,IN     	P_ID_PLANTILLA			INTEGER
		,IN		P_CDATOS_SDATOS		VARCHAR (2)
		,OUT	P_ERROR				VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	Insertar en la tabla BATCH_ESTADISTICAS_PRO el top 100 de registros
 * 				de registros repetidos por canal de contacto
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_CANTREPCANAL_CON
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 2023-01-17    Ajuste proceso            Fernando Garrido. 
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR						VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE	V_QSQL						VARCHAR	(32000);
	DECLARE	V_DATO						VARCHAR (100);
	DECLARE Temp 						CHAR	(30);
	DECLARE Cur_ARCHIVO_LOG 			NO SCROLL CURSOR 	FOR the_statement;
	
	
	
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
-------------------------------------------------------------------------------
--1. IdentificaciÃ¸Â³n del tipo de persona NATURALES, JURIDICAS ------------------
-------------------------------------------------------------------------------



---------------------------------------------------------------------------
-- Borrado y creaciÃ¸Â³n de la tabla temporal BATCH2TIPODOC ------------------ 
---------------------------------------------------------------------------
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2TIPODOC';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2TIPODOC';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2TIPODOC'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE TABLE '||P_BDSTAGE||'.BATCH2TIPODOC AS 
(SELECT a.Cod_Tipo_Ident_Fte, UPPER(TRIM(b.Nombre_Tipo_Persona)) AS Nombre_Tipo_Persona 
FROM '||P_BTTVISTA||'.vu_persona a 
 LEFT JOIN '||P_BTTVISTA||'.v_tipo_persona b 
 	ON a.Cod_DW_Tipo_Persona=b.Cod_DW_Tipo_Persona 
GROUP BY 1,2 
)WITH DATA;';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2TIPODOC'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


-------------------------------------------------------------------------------
--2 tipo de persona por pin persona 
-------------------------------------------------------------------------------








---------------------------------------------------------------------------
-- Borrado y creaciÃ¸Â³n de la tabla temporal BATCH2PERSONADOC ------------------ 
---------------------------------------------------------------------------
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = 'BATCH2PERSONADOC';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.BATCH2PERSONADOC';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE BATCH2PERSONADOC'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


SET V_CADENA = ' ';
SET V_CADENA = 'CREATE MULTISET TABLE '||P_BDSTAGE||'.BATCH2PERSONADOC AS
(SELECT Cod_Pin_Persona
 , NOMBRE_TIPO_PERSONA
FROM '||P_BDSTAGE||'.BATCH_Cubo_Persona11 BCP
INNER JOIN '||P_BDSTAGE||'.BATCH2TIPODOC BTD
ON BCP.tipo_id=BTD.COD_TIPO_IDENT_FTE
QUALIFY (ROW_NUMBER()OVER(PARTITION BY Cod_Pin_Persona ORDER BY id_auto))=1
)WITH DATA;';


CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
			,V_StartTimeStampPadre
			,:P_Nombre_Proceso_Padre
			,:V_CADENA
			,'Crea Tabla BATCH2PERSONADOC'
			,V_ERROR);

SET P_ERROR = V_ERROR;

IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
	LEAVE L1;
END IF;	


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor tabla BATCH_MOTOR_LOG Cantidad repetidos por canal de contacto ------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT DATO,SQL_STRING
					 FROM '||P_BDSTAGE||'.BATCH_MOTOR_LOG
					  WHERE SQL_STRING IS NOT NULL
					  AND TIPO =''CANT_REP_CANAL_CONTACTO''
					 ORDER BY ID ;
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_ARCHIVO_LOG ;

	CUR2:LOOP
		FETCH Cur_ARCHIVO_LOG  INTO  V_DATO,V_QSQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

		
-------------------------- CreaciÃ¸Â³n de tablas registros % a insertar ----------------------------------------
-------------------------------------------------------------------------------------------------------------		
	SELECT TABLENAME
	INTO :Temp
	FROM dbc.tables
	WHERE TRIM(databasename) = :P_BDSTAGE
	AND TRIM(TABLENAME) = ''||V_DATO||'';
	
	IF ACTIVITY_COUNT > 0 THEN
		SET V_CADENA='';
		SET V_CADENA = 'DROP TABLE ' ||P_BDSTAGE||'.'||V_DATO||'';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'DROP TABLE '||V_DATO||''
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 END IF;


		SET V_CADENA= 
		
		REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(V_QSQL
						,'P_StartTimeStampPadre',CAST(V_StartTimeStampPadre AS VARCHAR(20)))
						,'P_BDDATOS',P_BDDATOS)
						,'P_BTTVISTA',P_BTTVISTA)
						,'P_BDSTAGE',P_BDSTAGE)
						,'P_ID_SOLICITUD',CAST(P_ID_SOLICITUD AS VARCHAR(20)))
						,'P_ID_PLANTILLA',CAST(P_ID_PLANTILLA AS VARCHAR(20)))
						,'P_CDATOS_SDATOS',P_CDATOS_SDATOS)
						;
						
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Se realiza '||V_DATO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	END LOOP CUR2;

CLOSE Cur_ARCHIVO_LOG ;
	
END L1;
    
END;"

==============================================================



"REPLACE PROCEDURE REC_DATOS."
"PRO_BATCH2_ARCHIVO_LOG"
"
	(
		IN		P_Lote					INTEGER
		,IN		P_StartTimeStampPadre		VARCHAR(20)
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_BDDATOS				VARCHAR(20)
		,IN		P_BDVISTA 				VARCHAR(20)
		,IN		P_BDSTAGE				VARCHAR(20)
		,IN		P_ID_SOLICITUD			INTEGER
		,IN     	P_ID_PLANTILLA			INTEGER
		,IN		P_ARCHIVOPRN			VARCHAR (1000)
		,IN		P_MAQUINA				VARCHAR (200)
		,IN 		P_RUTA					VARCHAR (200)
		,IN		P_FEINICIO			        VARCHAR (32)
		,IN		P_NOMBRE_SECCION		VARCHAR (32)
		,OUT	P_ERROR				VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	ARCHIVO_LOG de campos para el archivo de salida.
 * Fecha:		2017/11/27
 * Realizado por:	Carlos Alberto Castillo
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_ARCHIVO_LOG
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			           Realizado por
 * 2023-01-17   Ajustar por error en udpdate   Fernando Garrido. 
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE	V_QSQL						VARCHAR	(32000);
	DECLARE	V_DATO						VARCHAR (100);
	DECLARE Temp 						CHAR	(30);
	DECLARE Cur_ARCHIVO_LOG 			NO SCROLL CURSOR 	FOR the_statement;
	
	
	
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');
	
	
------------------------------------------------------------------------------
--1.se realizÃ¸Â¡ la identificaciÃ¸Â³n de las columnas que se deben transponer ------
-------------------------------------------------------------------------------
 		SET V_CADENA='';
		SET V_CADENA = 'UPDATE '||P_BDSTAGE||'.BATCH_ARCHIVO_LOG SET VALOR=NULL;';
	
		CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Actualiza a NULL campo Valor'
				,V_ERROR);
		 SET P_ERROR = V_ERROR;
    		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF;
 

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ¸Â³n de ARCHIVO_LOG la tabla BATCH_MOTOR_LOG se carga con un script inicial ---------------
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA =  'SELECT  CAST(SQL_STRING AS VARCHAR(32000) ) SQL_STRING, DATO
					 FROM '||P_BDSTAGE||'.BATCH_MOTOR_LOG
					  WHERE SQL_STRING IS NOT NULL
					  AND TIPO =''LOG''
					 ORDER BY ID ;
					 ';

PREPARE the_statement FROM V_CADENA;

OPEN Cur_ARCHIVO_LOG ;

	CUR2:LOOP
		FETCH Cur_ARCHIVO_LOG  INTO  V_QSQL,V_DATO;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

		
-------------------------- CreaciÃ¸Â³n de tablas registros % a insertar ----------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA= 
		
		REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(V_QSQL
						,'P_StartTimeStampPadre',CAST(V_StartTimeStampPadre AS VARCHAR(20)))
						,'P_BDDATOS',P_BDDATOS)
						,'P_BDVISTA',P_BDVISTA)
						,'P_BDSTAGE',P_BDSTAGE)
						,'P_ID_SOLICITUD',CAST(P_ID_SOLICITUD AS VARCHAR(20)))
						,'P_ID_PLANTILLA',CAST(P_ID_PLANTILLA AS VARCHAR(20)))
						,'P_ARCHIVOPRN',P_ARCHIVOPRN)
						,'P_MAQUINA',P_MAQUINA)
						,'P_RUTA',P_RUTA)
						,'P_FEINICIO',P_FEINICIO)
						,'P_NOMBRE_SECCION',P_NOMBRE_SECCION)
						;
						
		SET P_ERROR=V_CADENA;			
	
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Se realiza update al campo'||V_DATO||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	END LOOP CUR2;

CLOSE Cur_ARCHIVO_LOG ;
	
END L1;
    
END;"

==============================================================



"REPLACE PROCEDURE REC_DATOS."
"PRO_BATCH2_PLAN_EJECUCION_SHELL"
"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
	(
		IN		P_Lote					INTEGER
		,IN		P_Nombre_Proceso_Padre	VARCHAR(30)
		,IN		P_ID_SOLICITUD			INTEGER
		,IN     P_PARTE                 VARCHAR(100)
		,OUT	P_ERROR			        VARCHAR(32000)
	)
/*
 * ################################################################################
 * 
 * Objetivo:	POBLAR  Iteracion Integral teniendo en cuenta la solicitud. Batch1, Batch 2 y Batch 4
 * Fecha:		2018/01/27
 * Realizado por:	Fernando Tafur .
 * Proyecto:		Nuevo reconocer
 * Script:		PRO_BATCH2_PLAN_EJECUCION_SHELL
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha		Objetivo			Realizado por
 * 2023-01-17   Ajuste Cursor       Fernando Garrido. 
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
	DECLARE V_StartTimeStampPadre			TIMESTAMP	(6);
	DECLARE	V_ERROR					VARCHAR	(30);
	DECLARE V_CADENA					VARCHAR	(32000);
	DECLARE V_CADENA1					VARCHAR	(10000);
	DECLARE	V_QSQL						VARCHAR	(32000);
	DECLARE	V_DATO						VARCHAR (200);
	DECLARE	V_PARTE						VARCHAR (100);
	DECLARE Temp 						CHAR	(30);
	DECLARE V_BD         VARCHAR (200);
	DECLARE V_CREATE         VARCHAR (200);
	DECLARE V_TABLA         VARCHAR (100);
	DECLARE CUR_PROCESO_MTR 			NO SCROLL CURSOR 	FOR the_statement;

	
	
	
	
L1:	BEGIN
	SET P_ERROR = '';
	SET V_StartTimeStampPadre = CURRENT_TIMESTAMP(6);
	
 

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------- Cursor ActulizaciÃ³n ESTADISTICAS MOTOR contadores
---------------------------------------------------------------------------------------------------------------------------------------------
	SET V_CADENA = ' ';
	SET V_CADENA =  '
				SEL CAMPO, SQL_VALOR
				FROM REC_STAGE.PRO_PLAN_EJECUCION
				WHERE PARTE = TRIM( '''||P_PARTE||''')
				ORDER BY ID ';

PREPARE the_statement FROM V_CADENA;

OPEN CUR_PROCESO_MTR ;

	CUR2:LOOP
		FETCH CUR_PROCESO_MTR  INTO  V_DATO, V_QSQL;
		
		IF SQLCODE <> 0 THEN LEAVE CUR2;
		END IF;

		
-------------------------- CreaciÃ³n de tablas registros % a insertar ----------------------------------------
-------------------------------------------------------------------------------------------------------------		
		SET V_CADENA= 
		
	      REGEXP_REPLACE(REGEXP_REPLACE(V_QSQL
						,'P_StartTimeStampPadre',CAST(V_StartTimeStampPadre AS VARCHAR(20)))
						,'P_ID_SOLICITUD',CAST(P_ID_SOLICITUD AS VARCHAR(20)));
              
						
		SET P_ERROR=V_CADENA;			
	    
		SET V_CREATE = '';
		SEL STRTOK(TRIM(UPPER(V_QSQL)),' ',1) --Esta sentencia no funciona.
		INTO :V_CREATE;
		

		
		IF TRIM(V_QSQL) LIKE '%CREATE%' THEN
		  
		 SET V_BD=' ';			   
		 SEL  T.DatabaseName
	   	 INTO 	:V_BD   
	     FROM DBC.Tables T
		 WHERE T.TABLENAME = TRIM(V_DATO);
			
		     SET Temp=' ';			
			SELECT TABLENAME
			INTO :Temp
			FROM dbc.tables
			WHERE TRIM(databasename) = TRIM(V_BD)
			AND TRIM(TABLENAME) = TRIM(V_DATO);
				
								
			IF ACTIVITY_COUNT > 0 THEN

			
				SET V_CADENA1='';
				SET V_CADENA1 = 'DROP TABLE ' ||V_BD||'.'||V_DATO;
			
				CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
						,V_StartTimeStampPadre
						,:P_Nombre_Proceso_Padre
						,:V_CADENA1
						,'DROP TABLE '||V_DATO
						,V_ERROR);
				 SET P_ERROR = V_ERROR;
		    		
				IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
					LEAVE L1;
				END IF;
		 END IF;		   
		END IF;
		
		
		CALL REC_DATOS.SP_EXECSTRING_DES
				(:P_Lote
				,V_StartTimeStampPadre
				,:P_Nombre_Proceso_Padre
				,:V_CADENA
				,'Ejecuta:'||P_PARTE||';'
				,V_ERROR
				);
		
		SET P_ERROR = V_ERROR;
		
		IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
			LEAVE L1;
		END IF; 

	END LOOP CUR2;

CLOSE CUR_PROCESO_MTR ;
	
END L1;
    
END;"
