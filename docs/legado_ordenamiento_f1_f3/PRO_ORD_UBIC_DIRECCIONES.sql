REPLACE   PROCEDURE REC_DATOS.PRO_ORD_UBIC_DIRECCIONES

     (
		 IN	P_Lote						INTEGER
		,IN	P_StartTimeStampPadre		VARCHAR(20)
		,IN	P_Nombre_Proceso_Padre		VARCHAR(30)
		,IN	P_BDDATOS					VARCHAR(20)
		,IN	P_BDVISTA					VARCHAR(20)
		,IN	P_BDSTAGE					VARCHAR(20)
		,IN	P_BTTDATOS					VARCHAR(20)
		,IN	P_BTTVISTA					VARCHAR(20)
		,IN	P_BDMTDAT					VARCHAR(20)
		,IN	P_BTTMTDAT					VARCHAR(20)
		,IN P_VARQUERY	/*#1*/			VARCHAR (500)
		,OUT P_ERROR					VARCHAR(50)
	)


/*
 * ################################################################################
 * 
 * Objetivo:	Ordenamiento PRO_ORD_CTA_ATRIBUTOS.
 * Fecha:		2019-01-09
 * Lider Tecnico:	
 * Realizado por:	Fernando Garrido M.
 * Parametros:	
 * Proyecto:	 Reconocer Master
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha:2019-01-09 VERSION INICIAL  Realizado por: Fernando Garrido
 * 
 * --------------------------------------------------------------------------- 
 
 * 
 *  Este componente fue realizado bajo la metodologia de desarrollo de Experian  y
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
	DECLARE V_ERROR			VARCHAR(30);
	DECLARE V_CADENA		VARCHAR(32000);
	DECLARE V_TABLE			VARCHAR(30);
	DECLARE Temp CHAR(30);
	
	SET V_StartTimeStampPadre = CAST(P_StartTimeStampPadre AS TIMESTAMP(6) FORMAT 'yyyy-mm-ddhh:mi:ss');

L1:	BEGIN
    
	
	----------------------------------------- INICIO CALCULO vmo_reporte_relacion_pers_ubi /*#5*/ /*#6*/---------------------------------------------------------
	-- Objetivo: Persistir a nivel de capa stage el calculo de la data con informacion historica para el algoritmo de ordenamiento.
	-- Objetos a Modificar : SP PRO_ORD_UBIC_DIRECCIONES.                                                   
	-------------------------------------------------------------------------------------------------------------------------------------------------------

	---------------------------
	-- Busca la tabla TMP_RelPerUbic_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RelPerUbic_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RelPerUbic_242 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242';
					CALL DBC.SysExecSQL(:V_CADENA);
    END IF;          


 	 SET V_CADENA= 'CREATE MULTISET  TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242
					 AS 
					(SELECT cod_dw_persona_ubic, Id_Buro_Persona 
					 FROM  '||P_BDDATOS||'.relacion_persona_ubicacion  
					 WHERE (cod_pin_persona, id_buro_persona)  IN (SELECT cod_pin_persona, id_buro_persona FROM '||P_BDSTAGE||'.UNIFICA_BTT_RECONOCER) 
					 )WITH DATA 
					 PRIMARY INDEX(cod_dw_persona_ubic);';



    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'PRO_ORD_UBIC_DIRECCIONES(1):CREACION DE TABLA TMP_RelPerUbic_242'
								,V_ERROR);
																	   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;

					
	-----------------------------------------
	-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL_MAT
	-----------------------------------------

	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_RelPerUbic_242 INDEX(cod_dw_persona_ubic);';
						   
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_UBIC_DIRECCIONES(2):RECOLECCION DE ESTADISTICAS TMP_RelPerUbic_242'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	---------------------------
	-- Busca la tabla TMP_ORD_CAL_MAT
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_ORD_CAL_MAT' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_ORD_CAL_MAT si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_ORD_CAL_MAT';
					CALL DBC.SysExecSQL(:V_CADENA);
		END IF;          


 	 SET V_CADENA= 'CREATE MULTISET TABLE '||P_BDSTAGE||'.TMP_ORD_CAL_MAT 
				   AS (SELECT CASE WHEN ID_FLAG_DESDE = 0 THEN MAX(a.Cod_DW_Reporte_Persona_Ubic) else MIN(a.Cod_DW_Reporte_Persona_Ubic) END Cod_DW_Reporte_Persona_Ubic
							,a.Cod_DW_Persona_Ubic
							,COALESCE(a.Id_Buro_Suscriptor,-1) Id_Buro_Suscriptor
							,COALESCE(a.Cod_DW_Cta,-1) Cod_DW_Cta
							,CASE WHEN ID_FLAG_DESDE =0 THEN MAX(Fecha_Reporte) ELSE  MIN(Fecha_Reporte)  END  Fecha_Reporte
							,a.Fecha_Apertura
							,a.Fecha_Nov
							,a.Desc_Est_Vigencia
							,a.Nombre_Natu_Cta
							,a.Nombre_Tipo_Rel_con_Cta
							,a.Cod_DW_Motivo_Bloqueo  
							,a.Id_Flag_Nuevo
							,a.Id_Flag_Desde
							,a.Flag_Bloqueo
							,a.Cod_DW_Fuente
							,COALESCE(a.Cod_DW_Matricula,-1) Cod_DW_Matricula
							,b.Id_Buro_Persona

					FROM '||P_BDDATOS||'.MAT_REPORTE_REL_PERS_UBI A

					INNER JOIN '||P_BDSTAGE||'.TMP_RelPerUbic_242 b
                    ON a.cod_dw_persona_ubic=b.cod_dw_persona_ubic 

					WHERE ID_FLAG_DESDE in (0,1)

					GROUP BY a.Cod_DW_Persona_Ubic
					,a.Id_Buro_Suscriptor
					,a.Cod_DW_Cta
					,a.Fecha_Apertura
					,a.Fecha_Nov
					,a.Desc_Est_Vigencia
					,a.Nombre_Natu_Cta
					,a.Nombre_Tipo_Rel_con_Cta
					,a.Cod_DW_Motivo_Bloqueo
					,a.Id_Flag_Nuevo
					,a.Id_Flag_Desde
					,a.Flag_Bloqueo
					,a.Cod_DW_Fuente
					,a.Cod_DW_Matricula
					,b.Id_Buro_Persona			
				)WITH DATA
				PRIMARY INDEX(Cod_DW_Reporte_Persona_Ubic);';



    CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								,V_StartTimeStampPadre
								,:P_Nombre_Proceso_Padre
								,:V_CADENA
								,'PRO_ORD_UBIC_DIRECCIONES(1):CREACION DE TABLA TMP_ORD_CAL_MAT'
								,V_ERROR);
																	   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;

					
	-----------------------------------------
	-- RECOLECCION DE ESTADISTICAS       TMP_ORD_CAL_MAT
	-----------------------------------------

	SET V_CADENA = ' ';
	SET V_CADENA = 'COLLECT STATISTICS '||P_BDSTAGE||'.TMP_ORD_CAL_MAT INDEX(Cod_DW_Reporte_Persona_Ubic);';
						   
	CALL REC_DATOS.SP_EXECSTRING_DES(:P_Lote
								   ,V_StartTimeStampPadre
								   ,:P_Nombre_Proceso_Padre
								   ,:V_CADENA
								   ,'PRO_ORD_UBIC_DIRECCIONES(2):RECOLECCION DE ESTADISTICAS TMP_ORD_CAL_MAT'
								   ,V_ERROR);
						   
	SET P_ERROR = V_ERROR;
				
	IF CHARACTER_LENGTH(V_ERROR) > 0 THEN
				LEAVE L1;
	END IF;
	
	---------------------------
	-- Busca la tabla TMP_RelPerUbic_242
	---------------------------
	SELECT TABLENAME 
	INTO :Temp
	FROM dbc.tables
	WHERE databasename =:P_BDSTAGE
	AND TABLENAME = 'TMP_RelPerUbic_242' ;
	
	IF ACTIVITY_COUNT > 0 THEN
	-----------------------------
	-- Se borra la tabla TMP_RelPerUbic_242 si existe
	-----------------------------
					SET V_CADENA = 'DROP TABLE '||P_BDSTAGE||'.TMP_RelPerUbic_242';
					CALL DBC.SysExecSQL(:V_CADENA);
    END IF;          
		
 END L1;
END;

