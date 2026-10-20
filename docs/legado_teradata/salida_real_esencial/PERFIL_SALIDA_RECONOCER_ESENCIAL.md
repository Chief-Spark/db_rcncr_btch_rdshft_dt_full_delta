# Perfil de una salida real de Batch: "Reconocer Esencial"

Archivo original: `Reconocer_Esencial_2950_20221216145538_1.xlsx` (solicitud 2950, 2022-12-16).
**El original NO se versiona: contiene datos personales reales** (documentos, nombres, telefonos, correos).
Aqui solo queda lo que sirve para homologar: encabezados, formas de los valores y dominios de catalogo.

Convencion de forma: `a` = letra, `9` = digito, `a{6}` = 6 letras seguidas.

## Hoja: Estadísticas (68 filas)

Agregados y ayudas, transcritos tal cual (no identifican personas):

```
Estadística de Resultados
Experian
colParse | Cantidad de Registros | %
Registros recibidos del cliente | 3
Documentos de identidad repetidos | 0 | 0.00%
Registros procesados | 3 | 100%
Registros con tipo CC (con datos) | 2 | 66,67%
Registros con identificación tipo CE (con datos) | 0 | 0,00%
Registros con identificación tipo NIT (con datos) | 0 | 0,00%
Registros con identificación tipo NIT de Extranjería (con datos) | 0 | 0,00%
Registros con validación correcta | 3 | 100%
Registros sin datos de ubicación | 1 | 33%
Registros con datos de ubicación | 2 | 67%
Registros con direcciones | 2 | 100,00%
Registros con teléfono fijo | 2 | 100,00%
Registros con correo electrónico | 2 | 100,00%
Registros con número teléfono celular | 2 | 100,00%
Registros con inconsistencias | 0 | 0%
Identificación no existe (Tipo 7) | 0 | 0.00%
Nombre no coincide con  Registraduría (Ciudadanos Colombianos) | 0 | 0.00%
NIT o Cedula de Extranjería no existe | 0 | 0.00%
Nombre no coincide con los registrados en la base de datos | 0 | 0.00%
Identificación NO vigente | 0 | 0.00%
Registros de personas fallecidas | 0 | 0.00%
Experian
Experian
Experian
Ayudas
Tipo documento
1-Cédulas de ciudadanía y NUIP
2-Nit empresarial
3-Nit de extranjería
4-Cedulas de  extranjería
Tipo teléfono
LAB- Laboral
RES- Residencial
CCL- Comercial
Tipo dirección
CRR- Correspondencia
LAB- Laboral
RES- Residencial
CCL- Comercial
PPL- Principal
AGN- Agencia
SUC- Sucursal
EST- Establecimiento
Zona dirección
URB- Urbana
RUR- Rural
Fecha de Ultima Actualización
Fecha en la que se reportó por última vez el dato de contacto en la
base de datos de DataCrédito Experian por parte de la fuente
Fecha de Primer Reporte
Fecha en la que se registró por primera vez el dato de contacto
en la base de DataCrédito Experian
Número de Entidades que Reportan
Indica la cantidad de entidades que han reportado el dato
de contacto para la identificación consultada
Fuente
Fuente que reportó la información: El Suscriptor (SUS), Ciudadano
(CIU), Cámara de comercio (CAM)
```

## Hoja: Con datos ubicación (4 filas)

Titulo de la hoja: `DATOS DE IDENTIFICACION TELEFONOS DIRECCIONES DATOS ADICIONALES`

Registros: 2. Columnas: 72.

| Col | Encabezado | Llenas | Forma de los valores | Dominio observado |
|---|---|---|---|---|
| A | Tipo id | 2/2 | `9` | `1` |
| B | Numero id | 2/2 | `9{7}` |  |
| C | Primer apellido | 2/2 | `a{9}`, `a{6}` |  |
| D | Segundo apellido | 2/2 | `a{5}`, `a{7}` |  |
| E | Primer nombre | 2/2 | `a{6}` |  |
| F | Segundo nombre | 2/2 | `a{6}`, `a{2} a{5}` |  |
| G | Nombre completo | 2/2 | `a{9} a{5} a{6} a{6}`, `a{6} a{7} a{6} a{2} a{5}` |  |
| H | Fecha expedicion | 2/2 | `9{2}/9{2}/9{2}` |  |
| I | Ciudad expedicion | 2/2 | `a{3} a{5}`, `a{5}` |  |
| J | Departamento expedicion | 2/2 | `a{9}` |  |
| K | Genero | 2/2 | `a` | `M` |
| L | Rango edad | 2/2 | `9{2}-9{2}   ` | `36-45`, `46-55` |
| M | CIIU | 2/2 | `9{4}` | `1020`, `8299` |
| N | Actividad economica | 2/2 | `a{13} a a{12} a{2} a{6}, a{9}, a{10} a a{10}`, `a{5} a{11} a{2} a{8} a{2} a{5} a a{3} a{8} a.a.a.` | `OTRAS ACTIVIDADES DE SERVICIO DE APOYO A LAS EMPRESAS N.C.P.`, `PROCESAMIENTO Y CONSERVACION DE FRUTAS, LEGUMBRES, HORTALIZAS Y TUBERCULOS` |
| O | Ciudad Telefono 1 | 2/2 | `a{8}`, `a{5}` |  |
| P | Departamento Telefono 1 | 2/2 | `a{9}` |  |
| Q | Codigo DANE ciudad Telefono 1 | 2/2 | `9{8}` |  |
| R | Codigo DANE departamento Telefono 1 | 2/2 | `9{2}` |  |
| S | Numero Telefono 1 | 2/2 | `9{7}` |  |
| T | Tipo Telefono 1 | 2/2 | `a{3}`, `a{3} - a{3}` | `RES`, `RES - LAB` |
| U | Fecha ultima actualizacion Telefono 1 | 2/2 | `9{2}/9{2}/9{4}` |  |
| V | Numero de entidades reporta Telefono 1 | 2/2 | `9` | `1`, `4` |
| W | Ciudad Telefono 2 | 2/2 | `a{8}` |  |
| X | Departamento Telefono 2 | 2/2 | `a{9}` |  |
| Y | Codigo DANE ciudad Telefono 2 | 2/2 | `9{8}` |  |
| Z | Codigo DANE departamento Telefono 2 | 2/2 | `9{2}` |  |
| AA | Numero Telefono 2 | 2/2 | `9{7}` |  |
| AB | Tipo Telefono 2 | 2/2 | `a{3}`, `a{3} - a{3}` | `RES`, `RES - LAB` |
| AC | Fecha ultima actualizacion Telefono 2 | 2/2 | `9{2}/9{2}/9{4}` |  |
| AD | Numero de entidades reporta Telefono 2 | 2/2 | `9` | `3`, `5` |
| AE | Ciudad Telefono 3 | 1/2 | `a{8}`, `vacio` |  |
| AF | Departamento Telefono 3 | 1/2 | `a{9}`, `vacio` |  |
| AG | Codigo DANE ciudad Telefono 3 | 1/2 | `9{8}`, `vacio` |  |
| AH | Codigo DANE departamento Telefono 3 | 1/2 | `9{2}`, `vacio` |  |
| AI | Numero Telefono 3 | 1/2 | `9{7}`, `vacio` |  |
| AJ | Tipo Telefono 3 | 1/2 | `a{3}`, `vacio` | `RES` |
| AK | Fecha ultima actualizacion Telefono 3 | 1/2 | `9{2}/9{2}/9{4}`, `vacio` |  |
| AL | Numero de entidades reporta Telefono 3 | 1/2 | `9`, `vacio` | `2` |
| AM | Ciudad Direccion 1 | 2/2 | `a{8}` |  |
| AN | Departamento Direccion 1 | 2/2 | `a{9}` |  |
| AO | Codigo DANE ciudad Direccion 1 | 2/2 | `9{8}` |  |
| AP | Codigo DANE departamento Direccion 1 | 2/2 | `9{2}` |  |
| AQ | Direccion 1 | 2/2 | `a{2} 9{2}a 9 9{2} a`, `a{2} 9{2} 9{2} 9` |  |
| AR | Tipo Direccion 1 | 2/2 | `a{3}`, `a{3} - a{3} - a{3}` | `LAB`, `RES - LAB - CRR` |
| AS | Zona 1 | 2/2 | `a{3}` | `URB` |
| AT | Estrato Direccion 1 | 2/2 | `9` | `2`, `3` |
| AU | Fecha ultima actualizacion Direccion 1 | 2/2 | `9{2}/9{2}/9{4}` |  |
| AV | Numero de entidades reporta Direccion 1 | 2/2 | `9` | `1`, `2` |
| AW | Ciudad Direccion 2 | 2/2 | `a{8}`, `a{5}` |  |
| AX | Departamento Direccion 2 | 2/2 | `a{9}` |  |
| AY | Codigo DANE ciudad Direccion 2 | 2/2 | `9{8}` |  |
| AZ | Codigo DANE departamento Direccion 2 | 2/2 | `9{2}` |  |
| BA | Direccion 2 | 2/2 | `a{2} 9{2} 9{2} 9{2}`, `a{2} 9{2} 9{2} 9` |  |
| BB | Tipo Direccion 2 | 2/2 | `a{3} - a{3}` | `RES - CRR` |
| BC | Zona 2 | 2/2 | `a{3}` | `URB` |
| BD | Estrato Direccion 2 | 1/2 | `9`, `vacio` | `3` |
| BE | Fecha ultima actualizacion Direccion 2 | 2/2 | `9{2}/9{2}/9{4}` |  |
| BF | Numero de entidades reporta Direccion 2 | 2/2 | `9` | `4`, `5` |
| BG | Ciudad Direccion 3 | 2/2 | `a{8}`, `a{5}` |  |
| BH | Departamento Direccion 3 | 2/2 | `a{9}` |  |
| BI | Codigo DANE ciudad Direccion 3 | 2/2 | `9{8}` |  |
| BJ | Codigo DANE departamento Direccion 3 | 2/2 | `9{2}` |  |
| BK | Direccion 3 | 2/2 | `a{2} 9{2} 9{2} 9{2}`, `a{2} 9{2} 9{2} 9` |  |
| BL | Tipo Direccion 3 | 2/2 | `a{3}` | `RES` |
| BM | Zona 3 | 2/2 | `a{3}` | `URB` |
| BN | Estrato Direccion 3 | 1/2 | `9`, `vacio` | `3` |
| BO | Fecha ultima actualizacion Direccion 3 | 2/2 | `9{2}/9{2}/9{4}` |  |
| BP | Numero de entidades reporta Direccion 3 | 2/2 | `9` | `1`, `5` |
| BQ | Correo  1 | 2/2 | `correo (a@a.a)` |  |
| BR | Numero  1 | 2/2 | `9{10}` |  |
| BS | Correo  2 | 2/2 | `correo (a@a.a)` |  |
| BT | Numero  2 | 2/2 | `9{10}` |  |

## Hoja: Sin datos de ubicación (3 filas)

Titulo de la hoja: `DATOS DE IDENTIFICACION`

Registros: 1. Columnas: 14.

| Col | Encabezado | Llenas | Forma de los valores | Dominio observado |
|---|---|---|---|---|
| A | Tipo id | 1/1 | `9` | `1` |
| B | Numero id | 1/1 | `9{10}` |  |
| C | Primer apellido | 1/1 | `a{9}` |  |
| D | Segundo apellido | 1/1 | `a{7}` |  |
| E | Primer nombre | 1/1 | `a{8}` |  |
| F | Segundo nombre | 0/1 | `vacio` |  |
| G | Nombre completo | 1/1 | `a{9} a{7} a{8}` |  |
| H | Fecha expedicion | 1/1 | `9{2}/9{2}/9{2}` |  |
| I | Ciudad expedicion | 1/1 | `a{11}` |  |
| J | Departamento expedicion | 1/1 | `a{9}` |  |
| K | Genero | 0/1 | `vacio` |  |
| L | Rango edad | 1/1 | `9{2}-9{2}   ` | `18-21` |
| M | CIIU | 0/1 | `vacio` |  |
| N | Actividad economica | 1/1 | ` ` | `` |

## Hoja: Inconsistencias (1 filas)

Registros: 0. Columnas: 11.

| Col | Encabezado | Llenas | Forma de los valores | Dominio observado |
|---|---|---|---|---|
| A | ID_SOLICITUD | 0/0 |  |  |
| B | ID_PLANTILLA | 0/0 |  |  |
| C | TIPO_ID | 0/0 |  |  |
| D | NUMERO_ID | 0/0 |  |  |
| E | NOMBRE_COMPLETO | 0/0 |  |  |
| F | NOMBRE_ENTIDAD | 0/0 |  |  |
| G | FECHA_EXPEDICION | 0/0 |  |  |
| H | CIUDAD_EXPEDICION | 0/0 |  |  |
| I | DEPARTAMENTO_EXPEDICION | 0/0 |  |  |
| J | ESTADO | 0/0 |  |  |
| K | CAUSAL | 0/0 |  |  |

