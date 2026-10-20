#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>
#define SQL_TEXT Latin_Text
#include "sqltypes_td.h"

void DirDataMasking(VARCHAR_LATIN *dir,
					VARCHAR_LATIN  *outSalida,
					SQL_TEXT extname[129],
					SQL_TEXT specific_name[129],
					SQL_TEXT error_message[257],
					char sqlstate[6])
{

 sprintf (outSalida, "");

 char  cadena[200];
 int lenDato = strlen(dir);

 strcpy((char *) cadena, (const char *) dir );

 int i=0;
 
 	while(i<lenDato){
	 
	 if( isdigit(cadena[i]) ) {
		cadena[i]='X';
	 }
	i++;
	}
 sprintf(outSalida,cadena);	
}



