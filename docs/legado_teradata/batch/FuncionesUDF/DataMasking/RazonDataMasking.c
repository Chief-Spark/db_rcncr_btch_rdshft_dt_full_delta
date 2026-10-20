#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>
#define SQL_TEXT Latin_Text
#include "sqltypes_td.h"

void RazonDataMasking(VARCHAR_LATIN *razon,
					  VARCHAR_LATIN  *outSalida,
					  SQL_TEXT extname[129],
					  SQL_TEXT specific_name[129],
					  SQL_TEXT error_message[257],
					 char sqlstate[6])
{
 sprintf (outSalida, "");
 
  char *result[500];
  char str[500];
  char *aux;
  char aux1[500];
  char *resp;
  int j=0;  
  strcpy (aux1,"");
  strcpy (str,razon);
  
  char * pch;
  pch = strtok (str," ");   
  int i=0;
  
  while (pch != NULL)
  {
   result[i]=pch; 
   pch = strtok (NULL, " "); 
   i++;
  }
  
  for(j=0; j<i; j++){
    aux=result[j];
    int lenDato = strlen(result[j]);
    if(lenDato>3){
     int x=1;
     while(x<5){
        aux[lenDato-x]='X';
        x++;
      }
    }
     
    strcat (aux1,aux);
    if(j<i-1){
      strcat (aux1," ");
    }
    result[j]=aux;
   }
 sprintf(outSalida,aux1);	
}
