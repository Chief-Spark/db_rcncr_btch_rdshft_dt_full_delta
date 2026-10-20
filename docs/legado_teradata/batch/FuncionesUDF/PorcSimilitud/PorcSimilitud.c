/*
 * ################################################################################
 * 
 * Objetivo:	  Aplicar el algoritmo de comparacion de palabras y entregar el procentaje de similitud
 * Fecha:	  2018/02/08
 * Realizado por: Fernando Garrido (Stefanini)
 * Parametros:	  
 * Proyecto:	  Experian - Reconocer
 * Script:	  PorcSimilitudTel.c
 * 
 * BITACORA
 * ---------------------------------------------------------------------------
 * Fecha	Objetivo				Realizado por
 * 2018-02-08    Version Inicial                        Fernando Garrido M.
 * ---------------------------------------------------------------------------
 * 
 * ################################################################################
 */

#include "loadParamsAcepAut.h"
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>
#define SQL_TEXT Latin_Text
#include "sqltypes_td.h"


// Funcion referenciada por Teradata
void PorcSimilitud (
		VARCHAR_LATIN *inTelInsumo,
		VARCHAR_LATIN *inTelBodega,
		FLOAT *outSimilitud,
		SQL_TEXT extname[129],
		SQL_TEXT specific_name[129],
		SQL_TEXT error_message[257],
		char sqlstate[6])
{
       *outSimilitud = 0.0;

	//Define variables
	int lenTel = strlen(inTelInsumo);
	INTEGER cost = 1, *outDist1 = NULL;
	
	outDist1 = (INTEGER *) malloc(sizeof(INTEGER)); 
	
	//Aplica algoritmo Levenshtein 
	editdistance_u(inTelInsumo, 
			inTelBodega, 
			&cost, 
			&cost, 
			&cost, 
			&cost, 
			outDist1, 
			sqlstate);
	
           *outSimilitud = ((lenTel - *outDist1)*1.0/lenTel*1.0 )*100 ;
           free(outDist1);	

}
