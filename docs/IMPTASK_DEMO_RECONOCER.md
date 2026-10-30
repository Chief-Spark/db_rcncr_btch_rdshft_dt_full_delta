# IMPTASK1752413 - Paso a DEMO del Calculo Reconocer

Texto listo para pegar en la Implementation Task de ServiceNow.
Change: CHG3089126 | Jira: SLCOPRBA-1353 | Grupo: SP LATAM Development
Ventana planificada: 2026-10-29 17:00 -> 2026-10-30 18:00

ServiceNow no renderiza markdown: cada bloque de abajo va en texto plano,
tal cual, al campo que lo encabeza.

---

## Campo: Short description

Despliegue del Calculo Reconocer en DEMO - tres repositorios Redshift

---

## Campo: Description

Despliegue en DEMO del Calculo Reconocer migrado de Teradata a Amazon Redshift:
Unificacion de direcciones, Ordenamiento (scoring de contactabilidad) y
Novedades. Son tres repositorios de base de datos que se despliegan en orden
fijo y que ya salieron en verde en QA (job QA/Deploy #62992, Jenkins Job Status
QA: Success).

El paquete que se despliega es EXACTAMENTE el mismo que se certifico en QA. No
lleva cambios de codigo. El despliegue incluye la creacion de objetos, la carga
de catalogos, una corrida con datos reales y una bateria de pruebas automatica
que certifica 121 criterios de aceptacion y detiene el build si alguno falla.

Duracion estimada: 60 a 75 minutos. El pipeline ejecuta el despliegue dos veces
de forma deliberada (ciclo controlado de Jenkins), de modo que todas las
validaciones de abajo deben aparecer dos veces en el log.

---

## Campo: Implementation plan (o Work notes)

PRERREQUISITOS - verificar ANTES de lanzar

1. Onboarding Redshift en DevSecOps para los tres repositorios en DEMO:
   - DB_DS_RCNCR_BTCH_RDSHFT_STRCT
   - DB_DS_RCNCR_BTCH_RDSHFT_PGM
   - DB_DS_RCNCR_BTCH_RDSHFT_DT
   Es un alta que hace DevSecOps repositorio por repositorio. Sin ella el build
   valida el paquete entero y muere despues con:
   ERROR: [REDSHIFT:156] El repositorio ... no tiene onboarding Redshift en
   DevSecOps
   No se arregla desde el codigo.

2. Campo SNOW ID del Jira SLCOPRBA-1353 diligenciado con CHG3089126.
   Hoy el Deploy Info del Jira muestra:
   JIRA:110 The issue 'SLCOPRBA-1353' in the 'SNOW ID' field is empty or invalid
   En QA salio como advertencia y el despliegue siguio. Diligenciarlo antes de
   lanzar DEMO.

3. Datashare de EDF disponible en DEMO (relaciones xpm_*). El despliegue del
   repositorio de datos consulta el datashare en su cuarto archivo de diecisiete
   y no tiene manejo de excepcion: si el datashare no responde, el despliegue se
   detiene ahi.

4. Rama de Bitbucket con el paquete publicada y verificada. La verificacion
   correcta se hace DESPUES del push y contra el remoto:
   git ls-tree -r --name-only origin/<rama> -- deploy/redshift
   No sirve git ls-files: lee el indice local, no lo que Jenkins construye.


PASOS DE EJECUCION - el orden no se puede alterar

Paso 1. Desplegar DB_DS_RCNCR_BTCH_RDSHFT_STRCT (estructura).
        49 scripts de despliegue y 49 de rollback.
        Crea esquemas, tablas, vistas, catalogos y funciones.
        Esperar a que termine en verde antes de continuar.

Paso 2. Desplegar DB_DS_RCNCR_BTCH_RDSHFT_PGM (programas).
        116 scripts de despliegue y 116 de rollback.
        Crea los procedimientos almacenados de los tres procesos.
        Esperar a que termine en verde antes de continuar.

Paso 3. Desplegar DB_DS_RCNCR_BTCH_RDSHFT_DT (datos y validaciones).
        17 scripts de despliegue y 17 de rollback.
        Ejecuta la corrida con datos reales, la bateria de pruebas y el
        certificado de aceptacion. Es el paso largo: ~45 minutos.

Por que ese orden: los programas referencian objetos que crea la estructura, y
las validaciones referencian los procedimientos que crea el repositorio de
programas. Cada repositorio lo declara en su .jenkins.yml con order 1, 2 y 3.
Invertirlo hace fallar el despliegue.


VALIDACION - que debe imprimir el log para dar el paso por bueno

El pipeline ejecuta el despliegue DOS veces. Todo lo siguiente debe aparecer en
las DOS pasadas:

1. Los tres titulares de certificacion, con estas cifras exactas:
   Unificacion    50 | 50 | 0
   Ordenamiento   45 / 44 / 1
   Novedades      26 / 25 / 1
   La tercera cifra NO son fallos: es el conteo de criterios pendientes de una
   decision funcional o sin dato de laboratorio que los ejercite. Fallos hay
   cero, y un fallo detendria el build automaticamente.

2. Dos lineas CERTIFICACION OK. Son dos porque el certificado se ejecuta para
   Unificacion y para Novedades por separado.

3. Las ocho validaciones de convergencia CA-C01 a CA-C08 con checksums
   identicos entre ciclos.

4. Las siete tablas de entrega pobladas. Como referencia, en QA el resultado
   fue 396.738 filas en total y la cadena completa tardo 365 segundos.

5. Rollback de prueba exitoso y Finished: SUCCESS.

Si el log imprime CERTIFICACION OK dos veces y Finished: SUCCESS, el paso esta
completo.


LO QUE NO ES UN FALLO - no abortar el paso por esto

En DEMO aparecera en el log un error del componente de georreferenciacion (GEO)
con este texto:
   no se pudo resolver el Ambiente para la cuenta AWS ...

Es esperado y NO detiene el despliegue. La tabla de configuracion de GEO trae
los ambientes PROD, UAT, TEST y DEV, y no tiene fila para DEMO. GEO se ejecuta
dentro de su propio bloque de excepcion por decision de negocio (el sistema
externo ArcGIS todavia no procesa), de modo que la corrida continua con el resto
del proceso y solo deja la traza de GEO marcada como fallida.

Para eliminarlo hace falta la cuenta AWS de DEMO y anadir su fila de
configuracion. Es una accion posterior, no un bloqueo de este paso.


ROLLBACK

Cada repositorio trae su rollback completo y el pipeline lo valida antes de
desplegar (REDSHIFT:211 Rollback disponible: true). Si hay que revertir, se
ejecuta en ORDEN INVERSO:

   1. DB_DS_RCNCR_BTCH_RDSHFT_DT
   2. DB_DS_RCNCR_BTCH_RDSHFT_PGM
   3. DB_DS_RCNCR_BTCH_RDSHFT_STRCT

El rollback elimina los objetos creados por este despliegue. No toca objetos de
otros procesos que comparten el mismo esquema.


CONTACTO

Ante cualquier duda durante la ejecucion, detener el paso y escalar al grupo
SP LATAM Development antes de intentar una correccion manual sobre el ambiente.

---

## De donde sale cada cifra de este documento

Para quien tenga que revisarlo o actualizarlo. Esta seccion NO se pega en
ServiceNow.

| Afirmacion | Evidencia |
|---|---|
| Orden strct -> pgm -> dt | `.jenkins.yml` de cada repo, `global.order` 1 / 2 / 3; regla 6 del `CLAUDE.md` |
| 49 / 116 / 17 scripts | `wc -l` de los tres `deploy.par` bajo `deploy/redshift/SLCOPRBA-1353/`, medido 2026-10-30 |
| Titulares 50\|50\|0, 45/44/1, 26/25/1 | `validacion_certificacion_51.sql`, `_ord.sql`, `_nov.sql`; ultimo verde job DEV/DATABASE #491 y QA/Deploy #62992 |
| La tercera cifra no son FAILED | `validacion_certificacion_51.sql:76-85`: es `alcance \| certificados \| pendientes`, y `pendientes` es todo lo que no es PASSED ni NO_APLICA |
| Dos `CERTIFICACION OK` | `run_cert_asercion_final.sql:35-36`, dos `CALL` con 'UNIFICACION' y 'NOVEDADES' |
| El build se detiene ante un FAILED | `sp_cert_asercion_final.sql:92-133` levanta excepcion y Jenkins la trata como error |
| El DPLY corre dos veces | ciclo controlado de Jenkins, documentado en los `CLAUDE.md` (job DEV/DATABASE #412) |
| La via real no tiene guarda | `run_reconocer_e2e_real_full.sql` es el archivo 4 de 17 de `dt/deploy.par` y no abre bloque de excepcion |
| DEMO sin fila en `geo_config` | `03_ddl_geo.sql:135,148`: siembra PROD 696708350333, UAT 453645298399, TEST 667397050561, DEV 647096294147 |
| El error de GEO no bloquea | `sp_geo_exportar_insumo.sql:124-133` levanta la excepcion; el ciclo la captura en su propio bloque |
| 396.738 filas y 365 s en QA | `dt/docs/DESGLOSE_TRES_VERTIENTES.md`, tabla D y tiempos de la cadena |
| `[REDSHIFT:156]` onboarding | job DEV/DATABASE #451; peticion en `dt/docs/PETICION_ONBOARDING_REDSHIFT_DEVSECOPS.md` |
| `git ls-tree` y no `git ls-files` | leccion de metodo del `[REDSHIFT:419]`, en los `CLAUDE.md` |
