# CHG - Despliegue a PRODUCCION del calculo e2e Reconocer (incluye UNLOAD)

> Alcance de este documento: **solo logica de base de datos**. La
> infraestructura (bucket GEO, rol IAM, datashare, onboarding) va por sus
> propias solicitudes y se lista aqui unicamente como prerrequisito.

## 1. Objetivo

Desplegar en el Redshift de produccion la cadena completa de Reconocer migrada
de Teradata: **Unificacion de direcciones**, **Ordenamiento (scoring de
contactabilidad)**, **Novedades (P0035)** y la **exportacion de las siete tablas
dominio a S3 (UNLOAD)**, de modo que el Framework Batch pueda ejecutar el
proceso end-to-end sobre datos reales.

## 2. Que se despliega

Seis paquetes, en dos tandas. Cada repositorio despliega con su propio job del
pipeline de DATABASE y lleva su `rollback.par`.

| Tanda | Paquete | Repositorio (Bitbucket) | Tipo / orden | Scripts |
|---|---|---|---|---|
| 1 | `SLCOPRBA-1353` | `DB_RCNCR_BTCH_RDSHFT_STRCT` | struct / 1 | **51** |
| 1 | `SLCOPRBA-1353` | `DB_RCNCR_BTCH_RDSHFT_PGM` | program / 2 | **122** |
| 1 | `SLCOPRBA-1353` | `DB_RCNCR_BTCH_RDSHFT_DT` | data / 3 | **17** |
| 2 | `SLCOPRBA-1820` | `A_RCNCR_LN_RDSHFT_STRCT` | struct / 1 | **2** |
| 2 | `SLCOPRBA-1820` | `A_RCNCR_LN_RDSHFT_PGM` | program / 2 | **3** |
| 2 | `SLCOPRBA-1820` | `A_RCNCR_LN_RDSHFT_DT` | data / 3 | **1** |

**El orden es obligatorio y no es intercambiable:** dentro de cada tanda
`struct -> program -> data`, y la tanda 1 completa antes de la tanda 2. El
exportador de la tanda 2 lee las siete tablas dominio que crea y puebla la
tanda 1; desplegado al reves falla con `procedure/relation does not exist`.

### Contenido funcional

- **struct (1353):** esquemas, tablas, vistas de insumo sobre el datashare,
  catalogos de scoring, las 47 betas de la calibracion RITM5226589, tablas de
  control y observabilidad.
- **program (1353):** los procedimientos de negocio de los tres procesos, sus
  orquestadores con la firma de seis parametros del Framework Batch, el ciclo
  GEO y los wrappers de paralelismo de los cuatro canales de scoring.
- **data (1353):** migraciones de estructura sobre objetos ya existentes y los
  runners de ejecucion y validacion (ver la decision del punto 5).
- **struct (1820):** `nov_config` y `nov_export_control` (frontera propia del
  exportador, acotada por ambiente).
- **program (1820):** el exportador de las siete tablas a S3 en CSV HEADER GZIP
  y el archivo de control `7_tablas_finish.json`.
- **data (1820):** runner de la exportacion (ver la decision del punto 5).

## 3. Que hace el proceso una vez desplegado

El Framework Batch dispara la cadena con un archivo `.val` en S3; todos los
parametros viajan en el nombre del archivo. La cadena corre en seis niveles:

1. Unificacion de direcciones (reglas 1, 2 y 3, con el ciclo GEO intercalado).
2. Ordenamiento - preparacion de insumos.
3. Ordenamiento - scoring de los cuatro canales (en paralelo).
4. Ordenamiento - consolidacion y orden de prioridad.
5. Novedades - siete dominios.
6. Exportacion (UNLOAD) de las siete tablas a S3.

El modo FULL o DELTA lo decide el nombre del archivo disparador; ni el YAML ni
los procedimientos cambian entre una modalidad y otra.

## 4. Que NO incluye este cambio

- Infraestructura: bucket de GEO, rol IAM de Redshift, politicas de S3.
- Creacion y asociacion del datashare de produccion.
- Onboarding de los repositorios en DevSecOps.
- Definicion y despliegue del YAML del Framework Batch y su archivo disparador.
- Carga a DynamoDB del lado del consumidor.

## 5. Decision requerida antes de ejecutar

Los paquetes `data` de ambas tandas **ejecutan procesos**, no solo crean
objetos. Tal como estan hoy, al desplegarse en produccion:

- lanzarian una corrida FULL completa de la cadena sobre datos reales;
- sembrarian el juego de datos de prueba (aprox. 450.000 filas) y correrian la
  bateria de certificacion;
- ejecutarian una exportacion real a S3.

Y el ciclo controlado del pipeline ejecuta el paso de despliegue **dos veces**,
de modo que todo lo anterior ocurriria por duplicado.

**Recomendacion:** desplegar en produccion los paquetes `data` **reducidos a
las migraciones de estructura**, sin los runners de ejecucion, siembra ni
certificacion. En produccion la cadena debe dispararla el Framework Batch de
forma controlada y auditable, no el despliegue. La certificacion funcional ya
esta surtida en los ambientes inferiores.

Esta reduccion exige una version de los paquetes `data` especifica para
produccion y debe quedar registrada como parte del cambio.

## 6. Prerrequisitos

| # | Prerrequisito | Responsable |
|---|---|---|
| 1 | Datashare de produccion creado, con sus nueve relaciones y asociado a la cuenta consumidora | Solicitud ServiceNow (en curso) |
| 2 | Rol propietario de los tres esquemas, concedido al usuario de despliegue y al usuario de ejecucion | Misma solicitud |
| 3 | Onboarding de los seis repositorios en DevSecOps | DevSecOps |
| 4 | Infraestructura de GEO disponible | Solicitud de infraestructura |
| 5 | Definicion del Framework Batch publicada para produccion | Equipo de Framework Batch |

Los prerrequisitos 4 y 5 **no bloquean el despliegue**: GEO corre en su propio
bloque de excepcion y su indisponibilidad no detiene la cadena.

## 7. Plan de reversion

Cada paquete incluye su archivo de reversion, con paridad uno a uno con el de
despliegue, y el pipeline lo ejecuta y valida como parte del propio ciclo
controlado antes de dar el despliegue por bueno.

La reversion se ejecuta en **orden inverso**: tanda 2 (`data -> program ->
struct`) y despues tanda 1 (`data -> program -> struct`).

Los tres esquemas son compartidos con otros procesos: la reversion elimina
unicamente los objetos de estos paquetes y en ningun caso los esquemas.

## 8. Verificacion posterior a la implementacion

1. Los seis jobs terminan en estado correcto, con la comparacion de estructura
   sin diferencias y la prueba de reversion satisfactoria.
2. Existen en produccion los objetos de los seis paquetes, y los catalogos de
   configuracion y de pesos del scoring tienen filas (un catalogo vacio no
   produce error y solo se detecta contando).
3. Una ejecucion controlada de la cadena desde el Framework Batch cierra sus
   tablas de control en estado completado, con las etapas completas y **conteos
   mayores que cero**: el estado solo dice que no hubo excepcion, no que el
   proceso haya hecho trabajo.
4. Las siete tablas dominio quedan pobladas y la exportacion deja su registro
   de control y su archivo de control en S3.

## 9. Riesgos conocidos

| Riesgo | Mitigacion |
|---|---|
| Valores de datos reales mas largos o mayores que los vistos en ambientes inferiores | Las conversiones y anchos estan acotados y hay una validacion automatica que lo verifica en cada entrega |
| Un catalogo no entregado deja columnas sin poblar | Documentado; no genera error ni pierde registros |
| GEO sin respuesta del proveedor externo | No bloqueante por diseno; los lotes sin respuesta se reexportan solos |
| La exportacion incremental mas la actualizacion por clave del consumidor no refleja borrados | Riesgo abierto del contrato con el consumidor; se mitiga con una exportacion completa periodica |
