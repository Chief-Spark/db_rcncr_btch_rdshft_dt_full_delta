/*
 * ################################################################################
 * 
 * Objetivo:	  Aplicar el algoritmo de comparacion de correos electronicos
 * Fecha:	  2017/04/24
 * Realizado por: Luis E Ramirez (Capgemini)
 * Parametros:	  
 * Proyecto:	  Experian - Reconocer
 * Script:	  BachSimilitudEmail.c
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
#include <math.h>
#include <ctype.h>
#include <stdlib.h>

// Funcion referenciada por Teradata
void BachSimilitudEmail (
		VARCHAR_LATIN *BuzonInsumoIn,
		VARCHAR_LATIN *DominioInsumoIn,
		VARCHAR_LATIN *SounBuzInsIn,
		VARCHAR_LATIN *SounDomInsIn,
		VARCHAR_LATIN *BuzonBodegaIn,
		VARCHAR_LATIN *DominioBodegaIn,
		VARCHAR_LATIN *SounBuzBodIn,
		VARCHAR_LATIN *SounDomBodIn,
		INTEGER	      *PorBzIn,
		INTEGER	      *PorBzSounIn,
		INTEGER	      *PorBzDistIn,
		INTEGER	      *PorDomIn,
		INTEGER	      *PorDomSounIn,
		INTEGER	      *PorDomDistIn,
					
		INTEGER 	  *outSimilitud,
		SQL_TEXT extname[129],
		SQL_TEXT specific_name[129],
		SQL_TEXT error_message[257],
		char sqlstate[6])	
{
	*outSimilitud = 0;
	
	//Define variables
	int porSounBz   		= 0
	   ,porSounDom  		= 0
	   ,outLargoBz  		= 0
	   ,outLargoDom 		= 0
	   ,outPorcDistanciaBz  = 0
	   ,outPorcDistanciaDom = 0
	   ,outPorBzIn  		= 0
	   ,outPorDomIn 		= 0;
		
	INTEGER cost = 1
		, *outDistBz  = NULL
		, *outDistDom = NULL;;
	
	outDistBz  = (INTEGER *) malloc(sizeof(INTEGER));
	outDistDom = (INTEGER *) malloc(sizeof(INTEGER));
	
	if (strcmp(SounBuzInsIn, SounBuzBodIn) == 0)
		porSounBz  = 100;
	if (strcmp(SounDomInsIn, SounDomBodIn) == 0)
		porSounDom = 100;
	
	// Aplica distancia de edicion para buzon
	editdistance_u(
		BuzonInsumoIn,
		BuzonBodegaIn,
		&cost,
		&cost,
		&cost,
		&cost,
		outDistBz,
		sqlstate
	);
	
	// Aplica distancia de edicion para dominio
	editdistance_u(
		DominioInsumoIn,
		DominioBodegaIn,
		&cost,
		&cost,
		&cost,
		&cost,
		outDistDom,
		sqlstate
	);
	
	// Calcula largo
	outLargoBz  			= strlen(BuzonInsumoIn);
	outLargoDom 			= strlen(DominioInsumoIn);
	// Calcula porcentaje distancia
	outPorcDistanciaBz 		= (((outLargoBz-(*outDistBz))*1.0/outLargoBz*1.0))*100.0;
	outPorcDistanciaDom 	= (((outLargoDom-(*outDistDom))*1.0/outLargoDom*1.0))*100.0;
	// Calcula porcentaje parcial
	outPorBzIn          	= (((porSounBz*(*PorBzSounIn))*1.0+(outPorcDistanciaBz*(*PorBzDistIn))*1.0)*(*PorBzIn))/10000.0;
	outPorDomIn         	= (((porSounDom*(*PorDomSounIn))*1.0+(outPorcDistanciaDom*(*PorDomDistIn))*1.0)*(*PorDomIn))/10000.0;
	// Salida porcentaje similitud
	*outSimilitud 			= round(outPorBzIn + outPorDomIn);
	free(outDistBz);
	free(outDistDom);
}
