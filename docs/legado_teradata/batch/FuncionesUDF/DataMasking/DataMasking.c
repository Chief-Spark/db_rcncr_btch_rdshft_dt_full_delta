#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>
#define SQL_TEXT Latin_Text
#include "sqltypes_td.h"
// Funcion referenciada por Teradata
void DataMasking(VARCHAR_LATIN *dato,
                VARCHAR_LATIN *outSimilitud,
                SQL_TEXT extname[129],
                SQL_TEXT specific_name[129],
                SQL_TEXT error_message[257],
                char sqlstate[6])
{

   sprintf (outSimilitud, "");
		
    char  cadena[200];
    int lenDato = strlen(dato);

   if(lenDato>3){
    strcpy((char *) cadena, (const char *) dato );
     int i=1;
     while(i<5){
        cadena[lenDato-i]='X';
        i++;
     }
   }
   sprintf(outSimilitud,cadena);	
		
}


