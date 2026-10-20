/*
 * ################################################################################
 * 
 * Objetivo:	  Aplicar el algoritmo de comparacion de direcciones fisicas de tipo
 *		  manzana
 * Fecha:	  2017/05/04
 * Realizado por: Luis E Ramirez (Capgemini)
 * Parametros:	  
 * Proyecto:	  Experian - Reconocer
 * Script:	  BachSimilitudDirVIA.c
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
#define SQL_TEXT Latin_Text
#include "sqltypes_td.h"
#include "loadParamsAcepAut.h"
#include "operationsString.h"
#include "AddressNormalization.h"
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <regex.h>

// Funcion referenciada por Teradata
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
);

// Funcion referenciada por Teradata
void BachSimilitudDirVIA (
		VARCHAR_LATIN *inCiudadInsumo,
		VARCHAR_LATIN *inDirInsumo,
		VARCHAR_LATIN *inDaneInsumo,
		VARCHAR_LATIN *inCiudadBodega,
		VARCHAR_LATIN *inDirBodega,
		VARCHAR_LATIN *inDaneBodega,

		INTEGER	*PorCiudad,
		INTEGER	*PorDireccion,
		INTEGER	*PorComplemento,
		
		INTEGER	*PorTipoViaPpal,
		INTEGER *PorNumViaPpal,
		INTEGER	*PorModViaPpal,
		INTEGER *PorViaGen,
		
		INTEGER	*PorModViaGen,
		
		INTEGER *PorNumPlaca,
		
		INTEGER *PorCuadrante,
		
		INTEGER	*PorHitMz0,
		INTEGER	*PorDisMz0,
		INTEGER	*PorHitMz1,
		INTEGER	*PorDisMz1,
		INTEGER *PorHitMz2,
		INTEGER	*PorDisMz2,
		INTEGER *PorHitMz3,
		INTEGER	*PorDisMz3,

		INTEGER *outSimilitud,
		//VARCHAR_LATIN *outSimilitud,
		SQL_TEXT extname[129],
		SQL_TEXT specific_name[129],
		SQL_TEXT error_message[257],
		char sqlstate[6])
{
	*outSimilitud = 0;
	//sprintf (outSimilitud, "");
		
	int 	
	// Variables para almacenar la comparacion de los componentes de las direcciones
		 TipoViaPpal=0
		, NumViaPpal=0
		, ModViaPpal=0
		, ViaGen=0
		, ModViaGen=0
		, NumPlaca=0
		, Cuadrante=0
		, Ciudad = 0
	;
	
	int Complemento=0;
	
	// Variables para almacenar las partes de la direccion
	char *FormatDirIns
		,*FormatDirBod
		,TipoViaPpalIns[100]=""
		,TipoViaPpalBod[100]=""
		,NumViaPpalIns[100]=""
		,NumViaPpalBod[100]=""
		,ModViaPpalIns[100]=""
		,ModViaPpalBod[100]=""
		,ViaGenIns[100]=""
		,ViaGenBod[100]=""
		,ModViaGenIns[100]=""
		,ModViaGenBod[100]=""
		,NumPlacaIns[100]=""
		,NumPlacaBod[100]=""
		,CuadranteIns[100]=""
		,CuadranteBod[100]=""
		,*ComplementoIns
		,*ComplementoBod
		;
			
	// Formatea la direccion insumo
	FormatDirIns = (char*)malloc(500); 
	sprintf (FormatDirIns, "");
	ComplementoIns = (char*)malloc(500); 
	sprintf (ComplementoIns, "");
	// type = 3
	Address_Normalization (inDirInsumo, inCiudadInsumo, FormatDirIns,500, 3, inDaneInsumo);
	//Split a resultado
	ListGetValByIdx(FormatDirIns, "|", 1, TipoViaPpalIns);
	ListGetValByIdx(FormatDirIns, "|", 2, NumViaPpalIns);
	ListGetValByIdx(FormatDirIns, "|", 3, ModViaPpalIns);
	ListGetValByIdx(FormatDirIns, "|", 4, ViaGenIns);
	ListGetValByIdx(FormatDirIns, "|", 5, ModViaGenIns);
	ListGetValByIdx(FormatDirIns, "|", 6, NumPlacaIns);
	ListGetValByIdx(FormatDirIns, "|", 7, CuadranteIns);
	ListGetValByIdx(FormatDirIns, "|", 8, ComplementoIns);
		
	// Formatea la direccion bodega
	FormatDirBod = (char*)malloc(500);
	sprintf (FormatDirBod, ""); 
	ComplementoBod = (char*)malloc(500);
	sprintf (ComplementoBod, ""); 
	// type = 3
	Address_Normalization (inDirBodega, inCiudadBodega, FormatDirBod,500, 3, inDaneBodega);
	//Split a resultado
	ListGetValByIdx(FormatDirBod, "|", 1, TipoViaPpalBod);
	ListGetValByIdx(FormatDirBod, "|", 2, NumViaPpalBod);
	ListGetValByIdx(FormatDirBod, "|", 3, ModViaPpalBod);
	ListGetValByIdx(FormatDirBod, "|", 4, ViaGenBod);
	ListGetValByIdx(FormatDirBod, "|", 5, ModViaGenBod);
	ListGetValByIdx(FormatDirBod, "|", 6, NumPlacaBod);
	ListGetValByIdx(FormatDirBod, "|", 7, CuadranteBod);
	ListGetValByIdx(FormatDirBod, "|", 8, ComplementoBod);
	
	// Comparacion de componentes de las direcciones
	if (strcmp(TipoViaPpalIns, TipoViaPpalBod) == 0)
		TipoViaPpal=100;
	
	if (strcmp(NumViaPpalIns, NumViaPpalBod) == 0)
		NumViaPpal=100;
	
	if (strcmp(ModViaPpalIns, ModViaPpalBod) == 0)
		ModViaPpal=100;
	
	if (strcmp(ViaGenIns, ViaGenBod) == 0)
		ViaGen=100;
	
	if (strcmp(ModViaGenIns, ModViaGenBod) == 0)
		ModViaGen=100;
	
	if (strcmp(NumPlacaIns, NumPlacaBod) == 0)
		NumPlaca=100;
	
	if (strcmp(CuadranteIns, CuadranteBod) == 0)
		Cuadrante=100;
	
	// Comparacion de los complementos
	//Complemento=(INTEGER*)malloc(sizeof(INTEGER));
	//*Complemento = 0;
	Complemento = 0;
	Complemento = similitudDirMZ( ComplementoIns
				, ComplementoBod
				, *PorHitMz0
				, *PorDisMz0
				, *PorHitMz1
				, *PorDisMz1
				, *PorHitMz2
				, *PorDisMz2
				, *PorHitMz3
				, *PorDisMz3);

	// Comparacion de las ciudades
	if (strcmp(inCiudadInsumo, inCiudadBodega) == 0)
		Ciudad=100;
	
	// Calculo porcentaje de similitud

	*outSimilitud = ((((Ciudad*1.0)/100.0) * ((*PorCiudad*1.0)/100.0))			// Para ciudad
			+ (((((TipoViaPpal*1.0)/100.0) * ((*PorTipoViaPpal*1.0)/100.0))    // Tipo via principal
				+ (((NumViaPpal*1.0)/100.0) * ((*PorNumViaPpal*1.0)/100.0))// Numero via principal
				+ (((ModViaPpal*1.0)/100.0) * ((*PorModViaPpal*1.0)/100.0))// Modificador via principal
				+ (((ViaGen*1.0)/100.0) * ((*PorViaGen*1.0)/100.0))        // Via generadora
				+ (((ModViaGen*1.0)/100.0) * ((*PorModViaGen*1.0)/100.0))  // Modificador de via generadora
				+ (((NumPlaca*1.0)/100.0) * ((*PorNumPlaca*1.0)/100.0))    // Numero de placa
				+ (((Cuadrante*1.0)/100.0) * ((*PorCuadrante*1.0)/100.0))  // Cuadrante
				) * ((*PorDireccion*1.0)/100.0))				// Direccion
			+ (((Complemento*1.0)/100.0) * ((*PorComplemento*1.0)/100.0)) 		// Complemento
			+ 0.00499) * 100
	;
	
	//sprintf (outSimilitud, "ComplementoIns:.%s - ComplementoBod:.%s",ComplementoIns,ComplementoBod);
	//sprintf (outSimilitud, "%s",FormatDirIns);
	
	free(FormatDirIns);
	free(FormatDirBod);
	free(ComplementoIns);
	free(ComplementoBod);
	
	FormatDirIns=NULL;
	FormatDirBod=NULL;
	ComplementoIns=NULL;
	ComplementoBod=NULL;
	
	TipoViaPpal=0;
	NumViaPpal=0;
	ModViaPpal=0;
	ViaGen=0;
	ModViaGen=0;
	NumPlaca=0;
	Cuadrante=0;
	Ciudad = 0; 
	Complemento=0;
	                            
	sprintf(TipoViaPpalIns,"" );
	sprintf(TipoViaPpalBod,"" );
	sprintf(NumViaPpalIns,""  );
	sprintf(NumViaPpalBod,""  );
	sprintf(ModViaPpalIns,""  );
	sprintf(ModViaPpalBod,""  );
	sprintf(ViaGenIns,""      );
	sprintf(ViaGenBod,""      );
	sprintf(ModViaGenIns,""   );
	sprintf(ModViaGenBod,""   );
	sprintf(NumPlacaIns,""    );
	sprintf(NumPlacaBod,""    );
	sprintf(CuadranteIns,""   );
	sprintf(CuadranteBod,""   );
	//sprintf(ComplementoIns,"" );
	//sprintf(ComplementoBod,"" );
}                                                                                
