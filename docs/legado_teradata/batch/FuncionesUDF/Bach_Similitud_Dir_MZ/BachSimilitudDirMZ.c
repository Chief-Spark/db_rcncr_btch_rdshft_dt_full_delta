/*
 * ################################################################################
 * 
 * Objetivo:	  Aplicar el algoritmo de comparacion de direcciones fisicas de tipo
 *		  manzana
 * Fecha:	  2017/05/04
 * Realizado por: Luis E Ramirez (Capgemini)
 * Parametros:	  
 * Proyecto:	  Experian - Reconocer
 * Script:	  Bach_Similitud_Dir_MZ.c
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
#include "operationsString.h"
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

// Constantes
#define MAX_SIZE_STRING 500

 //Estructuras
	//Estructura para palabras
typedef struct wordString {
		char word[MAX_SIZE_WORK]; // Palabra
		struct wordString *next; //Enlaza a la siguiente palabra de izquierda a derecha
		
	} wordString;	
	
// funcion similitudDirMZ
int similitudDirMZ (
		char *DirInsumo,
		char *DirBodega,

		int porHitMz0,
		int porDisMz0,
		int porHitMz1,
		int porDisMz1,
		int porHitMz2,
		int porDisMz2,
		int porHitMz3,
		int porDisMz3
)
{
	
	//Define variables
	int cantNum = 0
		, loop
		, space = 0
		, lenDirInsumo = 0
		, countHits = 0
		, outSimilitud = 0;

	
	int PorHitMz = 0
		,PorDisMz = 0
		,cost = 1
		, *outDist = NULL
		;
	
	outDist = (int *) malloc(sizeof(int));

	char word[MAX_SIZE_STRING]
		,preWord[2] = ""
		,sqlstate[6];

	struct wordString *dirInsumo=NULL
		, *dirInsumoEnd=NULL
		, *dirInsumoStart=NULL
		, *dirBodega=NULL
		, *dirBodegaEnd=NULL
		, *dirBodegaStart=NULL;
	
	// Recorre direccion insumo 
	sprintf(word, "");
	for (loop = 0; loop<=strlen(DirInsumo); loop++)
	{
	
		if ((DirInsumo[loop] == ' ' || strlen(DirInsumo) == loop) && space == 1) 
		{
			// En una cola va agregan palabra por palabra
			dirInsumo =(wordString*)malloc(sizeof(wordString));
			sprintf(dirInsumo->word,"%s", word);
			dirInsumo->next = NULL;
			
			if ( !dirInsumoEnd)
				dirInsumoEnd=dirInsumoStart=dirInsumo;
			else {
				dirInsumoEnd->next = dirInsumo;
				dirInsumoEnd=dirInsumo;
			}
			space = 0;
			sprintf(word, "");
		} else {
			if (DirInsumo[loop] != ' ') {
				preWord[0] = DirInsumo[loop];
				preWord[1] = '\0';
				sprintf(word ,"%s%s", word, preWord);
				space = 1;
			}
		}
		
	}
	
	sprintf(word, "");
	sprintf(preWord, "");
	space = 0;
	
	// Recorre direccion bodega 
	for (loop = 0; loop<=strlen(DirBodega); loop++)
	{
	
		if ((DirBodega[loop] == ' ' || strlen(DirBodega) == loop) && space == 1) 
		{
			// En una cola va agregan palabra por palabra
			dirBodega =(wordString*)malloc(sizeof(wordString));
			sprintf(dirBodega->word,"%s", word);
			dirBodega->next = NULL;
			
			if ( !dirBodegaEnd)
				dirBodegaEnd=dirBodegaStart=dirBodega;
			else {
				dirBodegaEnd->next = dirBodega;
				dirBodegaEnd=dirBodega;
			}
			space = 0;
			sprintf(word, "");
		} else {
			if (DirBodega[loop] != ' ') {
				preWord[0] = DirBodega[loop];
				preWord[1] = '\0';
				sprintf(word ,"%s%s", word, preWord);
				space = 1;
			}
		}
		
	}
	
	// Recorre direccion insumo para verificar la cantidad de valores numericos
	dirInsumo = dirInsumoStart;
	
	while (dirInsumo) 
	{
		if (valExpRegStr(dirInsumo->word, "^[0-9]{1,9}$") == 1)
		{
			cantNum++;
			
			// Se valida los Hist
			dirBodega = dirBodegaStart;
			
			while (dirBodega)
			{
				if (valExpRegStr(dirBodega->word, "^[0-9]{1,9}$") == 1)
				{
					if (strcmp(dirInsumo->word, dirBodega->word) == 0)
						countHits++;
				}
				dirBodega = dirBodega->next;
			}
		}
			
		dirInsumo = dirInsumo->next;
	}
	
	// Libera memoria
	while (dirInsumoStart != NULL)
	{
		dirInsumo = dirInsumoStart;
		dirInsumoStart = dirInsumoStart->next;
				
		if (dirInsumo != NULL)
			free(dirInsumo);
	}
	
	
	while (dirBodegaStart != NULL)
	{
		dirBodega = dirBodegaStart;
		dirBodegaStart = dirBodegaStart->next;
				
		if (dirBodega != NULL)
			free(dirBodega);
	}
	
	// Determina que porcentajes usa de acuerdo a cantNum
	if (cantNum == 0)
	{
		PorHitMz = porHitMz0;
		PorDisMz = porDisMz0;
	}
	
	switch(cantNum)
	{
		case 0:
			PorHitMz = porHitMz0;
			PorDisMz = porDisMz0;
			break;
	
		case 1:
			PorHitMz = porHitMz1;
			PorDisMz = porDisMz1;
			break;

		case 2:
			PorHitMz = porHitMz2;
			PorDisMz = porDisMz2;
			break;

		default:
			PorHitMz = porHitMz3;
			PorDisMz = porDisMz3;
	}
		
	// Aplica distancia de edicion para buzon
	editdistance_u(DirInsumo, 
			DirBodega, 
			&cost, 
			&cost, 
			&cost, 
			&cost, 
			outDist, 
			sqlstate);
	
	
	
	// Se calcula el tamaño de la direccion insumo
	lenDirInsumo = strlen(DirInsumo);
	
	// Calculo de la similitud
	if (cantNum != 0 && lenDirInsumo != 0)
		outSimilitud = ((((countHits*1.0) / (cantNum*1.0)) /*% Hits*/ 
					* ((PorHitMz*1.0)/100.0)) /*Porcentaje de Hits in*/
				+
				((1-((*outDist*1.0) / (lenDirInsumo*1.0))) /*Distancia*/
					* ((PorDisMz*1.0)/100.0))
				+ 0.00499) * 100
		;
		
	if (cantNum == 0 && lenDirInsumo != 0)
		outSimilitud = 0 /*Porcentaje de Hits in*/
				+
				(((1-((*outDist*1.0) / (lenDirInsumo*1.0))) /*Distancia*/
					* ((PorDisMz*1.0)/100.0))
				+ 0.00499) * 100
		;
		
	if (cantNum != 0 && lenDirInsumo == 0)
		outSimilitud = ((((countHits*1.0) / (cantNum*1.0)) /*% Hits*/ 
					* ((PorHitMz*1.0)/100.0)) /*Porcentaje de Hits in*/
				+
				0 /*Distancia*/
				+ 0.00499) * 100
		;
		
	if (cantNum == 0 && lenDirInsumo == 0)
		outSimilitud = 0
		;
	
	//*outSimilitud = *outDist;
	
	free(outDist);
	
	return outSimilitud;
	

}

	

// Funcion referenciada por Teradata
void BachSimilitudDirMZ (
		VARCHAR_LATIN *inDirInsumo,
		VARCHAR_LATIN *inDirBodega,

		INTEGER	*PorHitMz0,
		INTEGER	*PorDisMz0,
		INTEGER	*PorHitMz1,
		INTEGER	*PorDisMz1,
		INTEGER *PorHitMz2,
		INTEGER	*PorDisMz2,
		INTEGER *PorHitMz3,
		INTEGER	*PorDisMz3,

		INTEGER *outSimilitud,
		SQL_TEXT extname[129],
		SQL_TEXT specific_name[129],
		SQL_TEXT error_message[257],
		char sqlstate[6])
{
	*outSimilitud = similitudDirMZ (
				inDirInsumo
				,inDirBodega,

				*PorHitMz0,
				*PorDisMz0,
				*PorHitMz1,
				*PorDisMz1,
				*PorHitMz2,
				*PorDisMz2,
				*PorHitMz3,
				*PorDisMz3
		);
	

}
