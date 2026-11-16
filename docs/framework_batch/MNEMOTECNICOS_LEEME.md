# mnemotecnicos.csv: DOS FILAS QUE SE AGREGAN, NO UN ARCHIVO QUE SE REEMPLAZA

**LEER ESTO ANTES DE SUBIR NADA.** `mnemotecnicos_filas_reconocer.csv` NO es un
`mnemotecnicos.csv`: son las **dos lineas que hay que AGREGAR** al catalogo que
ya existe. Ese catalogo tiene **3.131 filas** y es de todos los clientes del
Framework (`src/dynamicProcessDefinitions/mnemotecnicos.csv` del repo
`tf_fw_dynbtch_chief`). **Subir un archivo de dos lineas con ese nombre deja sin
NIT a todos los demas procesos batch de la compania.**

## Por que hace falta tocarlo

`handler.py:70-72` del Builder hace:

```python
nit = mnemotecnicos.get(file_info.client_id)
if not nit:
    raise NITNotFoundError(file_info.client_id)
```

`client_id` es el mnemotecnico del nombre del `.val`. **Medido: ni
`reconocerfullval` ni `reconocerdeltaval` estan hoy en las 3.131 filas.** Sin
esas dos lineas el Builder muere antes de construir la Step Function.

## Formato: manda el codigo, no el documento

`docs/componentes/definiciones/mnemotecnicos-structure.md` dice en varios sitios
que el separador es punto y coma. **Es falso.** `s3_client.py:74` lee

```python
reader = csv.reader(StringIO(csv_string), delimiter=",")
data = {rows[0]: rows[1] for rows in reader}
```

y el archivo real usa **coma**. El mismo documento dice que el mnemotecnico sale
de la carpeta; tambien es falso, sale del **nombre del archivo**
(`parsers.py`, grupo 1 de `FILE_NAME_PATTERN`). Es la regla 4 del proyecto otra
vez: el documento funcional se equivoca y el codigo manda.

Lo que SI es cierto del formato, y hay que respetar:

| Cosa | Valor |
|---|---|
| Separador | coma `,` |
| Delimitador | comillas dobles `"` |
| Columnas | `ID`, `NIT`, `RAZON_SOCIAL` -- la tercera **el codigo la ignora** |
| Cabecera | el archivo real la trae; el parser no la salta, asi que entra como una fila basura inofensiva |
| Codificacion | UTF-8 **sin BOM** |
| Lineas en blanco | **ninguna**: `rows[0]` revienta con IndexError |
| Ubicacion | raiz del bucket de **definiciones**, el mismo de `PE1353.yml`, con el nombre exacto `mnemotecnicos.csv` |

## El NIT es el unico dato que no se puede inventar

Va en `<NIT_PENDIENTE>` a proposito. Tiene que ser **9 a 12 digitos** y **unico**
en el archivo, porque el validador del Framework rechaza NIT duplicados.

**Dato util para decidirlo:** ese NIT aterriza en el slot 2 del `CALL`, o sea en
`in_nit_suscriptor`, y **ninguno de nuestros tres orquestadores lo usa** -- es
uno de los tres parametros que la firma exige y nadie lee. Todas las llamadas
reales de hoy lo pasan como cadena vacia
(`run_reconocer_e2e_real_full.sql:60,63,69`). O sea: el valor no cambia el
resultado del proceso, pero **tiene que existir** o el Builder no arranca.

Las dos filas pueden llevar el MISMO NIT solo si el validador de duplicados no
se corre sobre ellas; si se corre, hacen falta dos valores distintos. Eso lo
decide quien mantiene el catalogo.
