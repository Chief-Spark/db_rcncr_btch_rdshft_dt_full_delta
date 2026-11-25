# CHG3122759 — las cuatro tareas de implementacion, en orden

Estado actual del CHG: **dos** tareas en `Implementation`, las dos en `Draft`.
Faltan **dos** en medio, y la que hoy va de segunda pasa a ser la ultima.

| Secuencia | Tarea | Estado |
|---|---|---|
| 1 | `IMPTASK1786645` — Datashare, esquemas, rol propietario y permisos | **ya existe** |
| 2 | *Infraestructura: buckets y roles IAM de GEO y UNLOAD* | **crear** |
| 3 | *Asociar los dos roles IAM al cluster de Redshift de PDN* | **crear** |
| 4 | `IMPTASK1786640` — Despliegue manual de los seis paquetes SQL | **existe, cambia de secuencia 2 a 4** |

**El orden no es preferencia, es dependencia:** sin el datashare el calculo no
tiene fuente; sin los buckets y roles el `UNLOAD` no tiene donde escribir; y un
rol que existe pero no esta asociado al cluster da
`UnauthorizedException: role ... is not associated to cluster`, que es
exactamente lo que paso en DEV y en DEMO.

---

## Tarea 2 (NUEVA) — Infraestructura de S3 e IAM para GEO y UNLOAD

**Short description**

```
Despliegue en PDN de la infraestructura de S3 e IAM del calculo Reconocer: buckets y roles de GEO y de UNLOAD
```

**Assignment group:** el que opere Terraform / DevSecOps (no DBA)
**Secuencia:** 2 — **depende de:** nada. Puede ir en paralelo a la tarea 1.

**Description**

```
Crear en la cuenta de PRODUCCION de Reconocer (696708350333) los recursos de
S3 e IAM que consume el calculo Reconocer, mediante los dos repositorios de
Terraform que ya los crearon en DEMO:

  - TF_RCNCR_WS5_INFRA        -> bucket y rol de GEO
  - tf_rcncr_linea_ws5_infra  -> rol de UNLOAD, rol de COPY cross-account y
                                 los buckets de triggers, staging y lotes

SON DOS REPOSITORIOS DISTINTOS SOBRE LA MISMA CUENTA. En DEMO se verifico uno
solo y se concluyo que el rol del UNLOAD no existia; existia, lo creaba el otro.

Recursos que esta tarea debe dejar creados:

  - bucket de GEO
  - rol IAM de Redshift para GEO
  - bucket de triggers del exportador
  - rol IAM de Redshift para el UNLOAD

EVIDENCIA QUE DEBE DEVOLVER ESTA TAREA, Y ES LA QUE HABILITA LA TAREA 4:
la salida del 'terraform apply' con los NOMBRES REALES de los cuatro recursos.
En DEMO la salida fue de esta forma:

  geo_bucket_name       = "stg-453645298399-rcncr-ws5-geo"
  geo_redshift_role_arn = "arn:aws:iam::453645298399:role/BURoleFor-stg-...-redshift-geo"
  "redshift_unload"     = "arn:aws:iam::453645298399:role/BURoleFor-stg-...-redshift-unload"
  s3_triggers_bucket    = "stg-453645298399-rcncr-ws5-triggers-reconocer-s3"

POR QUE SE PIDE ESA SALIDA Y NO BASTA CON "quedo creado": el token del ambiente
NO se deduce del nombre del ambiente. La cuenta de DEMO figura como DEMO en
Jenkins, como 'uat' en el alias de AWS y como 'stg' en todo lo que crea la
infraestructura. El paquete SQL pedia 'demo-...' y 'uat-...' y ninguno de esos
cuatro objetos existia. Si en PDN el token no resulta ser 'prod', hay que
corregir cuatro literales del paquete ANTES de la tarea 4.

La politica de acceso de los roles es por PREFIJO y por ACCION, medida en DEV:
el rol de GEO escribe en 'reconocer_input/' y lee de 'reconocer_output/', y no
al reves. Es minimo privilegio correcto y se replica igual.
```

---

## Tarea 3 (NUEVA) — Asociar los dos roles IAM al cluster de Redshift

**Short description**

```
Asociar al cluster de Redshift de PDN los dos roles IAM del calculo Reconocer (GEO y UNLOAD)
```

**Assignment group:** SP LATAM Infrastructure (DBA) junto con quien administre IAM
**Secuencia:** 3 — **depende de:** tarea 2.

**Description**

```
Asociar al cluster de Redshift de produccion de Reconocer los dos roles IAM
creados en la tarea 2:

  - el rol de GEO     (lo usa el UNLOAD de candidatos y el COPY de la respuesta)
  - el rol del UNLOAD (lo usa la exportacion de las siete tablas de dominio)

Crear el rol NO BASTA. Redshift solo puede asumir un rol que este asociado al
cluster: si no lo esta, la sentencia falla con

  UnauthorizedException: role ... is not associated to cluster

y ese fue el bloqueo real de GEO en DEV durante semanas, y del UNLOAD en DEMO.

Se hace desde la consola de Redshift (Actions -> Manage IAM roles) o con
'aws redshift modify-cluster-iam-roles --add-iam-roles'.

EVIDENCIA QUE DEBE DEVOLVER ESTA TAREA: la lista de roles IAM asociados al
cluster, mostrando los dos ARN y el estado 'in-sync'.

PRUEBA OPCIONAL, Y ES LA QUE DE VERDAD CIERRA LA TAREA: un
UNLOAD ('SELECT 1') al prefijo de entrada con el rol de GEO. En DEV tardo
0,698 segundos y dejo el objeto en S3 en el mismo segundo. Distingue "el rol
esta asociado" de "el rol sirve".

OJO AL PROBAR EL COPY: no se puede probar con un viaje de ida y vuelta desde
Redshift, porque el rol no puede escribir donde si puede leer. Hay que subir el
archivo al prefijo de salida con un usuario de AWS y entonces leerlo, y
borrarlo enseguida: el cargador hace COPY de TODOS los archivos del prefijo,
sin filtrar por nombre.
```

---

## Tarea 4 — la que ya existe, con dos cambios

`IMPTASK1786640` se queda, y hay que tocarle dos cosas:

1. **La secuencia pasa de 2 a 4.**
2. **La descripcion debe decir que el paquete es la version del 2026-11-25**,
   la que incorpora los cuatro ajustes que salieron del despliegue manual a
   DEMO. El paquete anterior falla en el archivo 023 y en el de validacion.

**Short description sugerida**

```
Despliegue manual en Redshift PDN de los seis paquetes SQL del calculo Reconocer (SLCOPRBA-1353 y SLCOPRBA-1820) - paquete v2026-11-25
```

**Lo que conviene anadir a la descripcion**

```
El paquete y su instructivo van adjuntos: RECONOCER_PDN.zip, 180 archivos de
estructura y programas mas la ejecucion y la validacion, en el orden de sus
carpetas. El documento 00_LEEME_PASO_A_PASO.md trae el procedimiento completo.

DEPENDE DE LAS TAREAS 1, 2 Y 3. Antes de ejecutar la carpeta 01 hay que
comparar los nombres reales que devolvio la tarea 2 con los cuatro literales
que el paquete siembra para PROD:

  geo_config  PROD  bucket           prod-696708350333-rcncr-ws5-geo
  geo_config  PROD  iam_role         ...:role/BURoleFor-prod-696708350333-rcncr-ws5-redshift-geo
  nov_config  PROD  triggers_bucket  prod-696708350333-rcncr-ws5-triggers-reconocer-s3
  nov_config  PROD  unload_iam_role  ...:role/BURoleFor-prod-696708350333-rcncr-ws5-redshift-unload

Si no coinciden, se corrigen esos cuatro literales antes de ejecutar. Son
cuatro cadenas y no hay cambio de logica. Atencion a que las dos tablas NO se
corrigen igual: nov_config se re-siembra sola porque su carga es DELETE+INSERT;
geo_config lleva WHERE NOT EXISTS y ademas hay que tocar sus dos UPDATE de
reconciliacion.

CERTIFICACION DEL AMBIENTE ANTERIOR: el mismo paquete se desplego manualmente
en DEMO el 2026-11-24. Resultado: los 279 objetos presentes y 0 faltantes, los
23 catalogos poblados, las siete tablas de dominio con 2.506.894 filas y el
exportador en estado 'completado' con 2.505.136 registros.

ROLLBACK: la carpeta 90_ROLLBACK, en el orden contrario de los paquetes. El
despliegue es aditivo y no altera objetos de otros equipos.
```

---

## Dos cosas de calendario que hay que resolver antes de fijar la fecha

**1 — Entre el 26 y el 30 de noviembre no hay ventana, por dos motivos a la
vez.** El Black Weekend (26-30 nov) es congelamiento total sin excepcion, y el
27 (viernes) y el 30 (lunes) son ademas los **dos ultimos dias habiles del
mes**, que tampoco se autorizan. El 25 es hoy; despues de hoy, la siguiente
ventana es a partir del **1 de diciembre**.

**2 — La clasificacion del CHG no cabe en el periodo de proteccion.** El BPP
arranco el **23 de noviembre**, y en su Fase 1 (hasta el 10 de diciembre) se
autorizan Normales de impacto y riesgo **BAJO o MEDIO con CAB**, pero **no los
de riesgo o impacto ALTO**. Este CHG esta clasificado `Risk: High` /
`Impact: 1-High`. Caminos: bajar la clasificacion con argumento (el cambio es
aditivo y se revierte borrando), o ir por Gestion de Excepciones, que **no es
una autorizacion**: la evalua Change Management y con riesgo alto escala al
CIO SPLatam.

**Y el corte de recepcion decide en que ciclo entra:** el Comite de Cambios
recibe **lunes y jueves**, hasta las **10:00** en Colombia. Lo que llega
despues pasa al ciclo siguiente, que es donde se pierde una semana sin darse
cuenta.
