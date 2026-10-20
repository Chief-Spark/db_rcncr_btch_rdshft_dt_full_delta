/*
 * ################################################################################
 * 
 * Objetivo:	  Aplicar el algoritmo de comparacion de telefonos
 * Fecha:	  2017/04/24
 * Realizado por: Luis E Ramirez (Capgemini)
 * Parametros:	  
 * Proyecto:	  Experian - Reconocer
 * Script:	  BachSimilitudTel.c
 * 
 * 
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha	Objetivo				Realizado por
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

#include "loadParamsAcepAut.h"
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

// Funcion referenciada por Teradata
void BachSimilitudTel (
		VARCHAR_LATIN *inTelInsumo,
		VARCHAR_LATIN *inTelBodega,
		INTEGER *outSimilitud,
		SQL_TEXT extname[129],
		SQL_TEXT specific_name[129],
		SQL_TEXT error_message[257],
		char sqlstate[6])
{
	*outSimilitud = 0;
	
	//Define variables
	int lenTel = strlen(inTelInsumo);
	INTEGER cost = 1, *outDist1 = NULL;
	
	outDist1 = (INTEGER *) malloc(sizeof(INTEGER)); 
	
	// Aplica distancia de edicion
	editdistance_u(inTelInsumo, 
			inTelBodega, 
			&cost, 
			&cost, 
			&cost, 
			&cost, 
			outDist1, 
			sqlstate);
	
	*outSimilitud = (1.0-((*outDist1*1.0)/(lenTel*1.0))+0.00499)*100;
	//*outSimilitud = *outDist1;
	free(outDist1);	

}
