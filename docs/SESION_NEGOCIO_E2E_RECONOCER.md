# Sesión con Negocio — el e2e de Reconocer corre en Redshift

**Objetivo de la sesión: obtener el aval para avanzar a producción.**
Público: Negocio y gerencia de producto. No es técnico.

Artefacto visual: https://claude.ai/artifact/T8hhNCJYPyBTBh734Y9kGn
(privado; hay que compartirlo desde el menú Share antes de la sesión si lo van
a abrir otros).

El artefacto es el apoyo, no el contenido. Se recorre con scroll, una sección
por idea, y la narrativa la pone quien presenta con el guión de abajo.

---

## Estructura — 9 bloques

| # | Bloque | La única idea que deja |
|---|---|---|
| 1 | Titular | el cálculo corre de punta a punta, medido en tres frentes |
| 2 | Qué hace | tres pasos, y el orden es parte de la regla |
| 3 | El embudo | entraron tantas, pasó esto, salió esto |
| 4 | Las tres vertientes | mock prueba la regla, real prueba el volumen |
| 5 | Cómo clasificamos | el lugar 1 es el mejor dato de contacto |
| 6 | Transparencia | lo que encontramos al leer Teradata |
| 7 | Qué mejoró | la misma lógica, corregida |
| 8 | Producción | cómo operaría |
| 9 | La decisión | el aval, y qué falta |

---

## Guión

Dos o tres frases por bloque. Escrito para decirse en voz alta.

### 1 · Titular

> Lo que vamos a ver hoy es que el cálculo de Reconocer ya corre completo sobre
> Redshift: Unificación, Ordenamiento y Novedades, encadenados, sin intervención
> manual.
>
> Lo probamos de dos maneras: con datos construidos por nosotros para forzar cada
> regla, y con el dato real del buró. En desarrollo está medido; en QA lo estamos
> corriendo ahora mismo.

### 2 · Qué hace el proceso

> El proceso hace tres cosas. Primero reconoce cuándo dos direcciones distintas
> son en realidad la misma casa. Después puntúa todos los datos de contacto de
> cada persona y los pone en orden. Y al final entrega siete tablas con la foto
> de cada persona.
>
> El orden importa: Ordenamiento necesita lo que produce Unificación, y Novedades
> sólo toma lo que Ordenamiento ya priorizó.

### 3 · El embudo  ← **el corazón de la sesión**

> De cada cien relaciones persona-ubicación que trae el buró, entran al proceso
> veintiséis.
>
> **Y aquí está lo importante: las que no entran son empresas.** Ciento seis NIT
> concentran ciento treinta y cuatro mil relaciones: compañías con cientos de
> sedes. El proceso actual de Teradata las excluye exactamente igual. No es
> pérdida, es el universo correcto.
>
> Con lo que queda, Unificación resolvió diecinueve duplicados, Ordenamiento
> puntuó ciento ochenta y cinco mil datos de contacto, y Novedades entregó
> trescientas sesenta y tres mil filas para cincuenta y ocho mil personas. Todo
> eso en cuatro minutos y veintitrés segundos.

**Si preguntan por qué sólo diecinueve unificaciones** (y van a preguntar):

> El proceso une dos direcciones cuando son la misma casa escrita distinto:
> *Calle 10 # 5-20 apto 201* y *Calle 10 # 5-20 ap 201*. Para que haya algo que
> unir, tienen que existir dos escrituras de la misma dirección.
>
> De las setenta y ocho mil que entraron, **setenta y ocho mil ciento ochenta y
> ocho eran direcciones únicas**: no había con quién emparejarlas. Y de las que
> sí tenían un candidato, **no quedó ni una sin resolver. Cero.**
>
> La diferencia que importa es entre *no resolvió* y *no había qué resolver*.

Lo que hay detrás, por si alguien pregunta de dónde sale: el proceso guarda un
censo que clasifica cada dirección en tres cubos.

| Cubo | Qué significa | DEV |
|---|---|---|
| La resolvió una regla | se unificó | **19** |
| Sin pareja posible | su grupo traía una sola escritura de la dirección | **78.188** |
| Sin resolver | sí había otra escritura, y ninguna regla las unió | **0** |

**La tercera fila es la única que delataría un hueco en el port.** Por eso es la
que se mira, y por eso dio cero. La clasificación está en
`sp_unificacion_regla2.sql:148-165`; el censo es `bdm_datos.unif_escenario_censo`.

### 4 · Las tres vertientes

> Trabajamos con dos juegos de datos porque responden preguntas distintas.
>
> El de laboratorio está construido para que cada criterio tenga un caso que lo
> ejercite: noventa y tres situaciones distintas, con el resultado calculado de
> antemano. Prueba que la regla es correcta.
>
> El dato real prueba otra cosa: que la regla aguanta el volumen y la suciedad
> del origen. Ninguno reemplaza al otro.

**Sobre los cuatro ciclos del mock**, si hay interés:

> Corremos la cadena cuatro veces seguidas: carga completa, incremental sin
> cambios, le cambiamos datos a propósito, e incremental otra vez. Así separamos
> dos cosas que se confunden: que el proceso no duplique, y que sí detecte lo que
> cambió.

### 5 · Cómo clasificamos

> Cada dirección, teléfono, celular y correo recibe un puntaje con cuarenta y
> siete características calibradas por el modelo del buró, y queda en una
> posición. El lugar uno es el mejor dato para contactar a esa persona.
>
> En el dato real hay personas con cincuenta y siete correos ordenados. Eso es lo
> que demuestra que el ranking discrimina de verdad: con datos de laboratorio
> nunca pasa de dos.

### 6 · Transparencia — lo que encontramos en Teradata

> Portar nos obligó a leer el proceso actual línea por línea, y aparecieron cuatro
> cosas que conviene que ustedes sepan.
>
> **La primera:** el proceso de Teradata nunca hizo carga incremental. Borra, al
> arrancar, la bitácora de la que después lee la fecha de corte. Siempre queda
> vacía. Toda corrida reprocesa el universo completo.
>
> **La segunda:** no puede dar de baja un dato. La única ruta que marca una
> ubicación como eliminada depende de encontrarla en una tabla de la que ya fue
> excluida dos pasos antes.
>
> **La tercera:** treinta y dos de las cuarenta y siete características del
> puntaje medían algo distinto de lo que dice el modelo. Dos puntajes del mismo
> correo podían diferir en más de seiscientos puntos. Una penalizaba noventa y
> ocho puntos por tener una cuenta de Gmail, sin ninguna base.
>
> **La cuarta:** la exportación se aborta si no cuadra un conteo contra un insumo
> que hoy está fuera de alcance por decisión legal.

Tono: esto **no** es un reproche al equipo anterior. Es el valor de haber
portado: salió a la luz porque alguien tuvo que leerlo entero.

### 7 · Qué mejoró, en números

> No llevamos la misma lógica a otro motor. Llevamos la misma lógica, corregida.
>
> Hay ciento ochenta y nueve criterios de aceptación escritos, cada uno con la
> consulta que lo afirma. Treinta y nueve de las cuarenta y siete características
> quedaron fieles al modelo original. Mil ochenta y tres puntos del modelo que
> medían ruido están saneados.
>
> Y cada diferencia que decidimos no replicar está escrita, con responsable y
> fecha. Son veintinueve. Eso es lo que el proceso actual no tenía.

**Hueco pendiente:** el tiempo de la malla actual en Teradata. Cuando llegue, va
al lado de los 263 segundos.

### 8 · Producción

> En producción lo dispara el Framework Batch corporativo, el mismo que ya usan
> los demás procesos: se deja un archivo de control y la cadena arranca.
>
> La misma cadena sirve para carga completa y para incremental; cambia el nombre
> del archivo, nada más. El disparo está probado en desarrollo y en QA; el modo
> incremental, por ahora sólo con datos de laboratorio.
>
> La ventana operativa la definimos con el volumen real del buró, que todavía no
> hemos medido. Lo que sí está medido es que corre sin intervención manual.

**Y el alcance, por si preguntan (decisión del equipo, 2026-10-30):** con dato
real hemos corrido la **carga completa**, y es lo que se presenta. El modo
incremental está certificado con los datos de laboratorio, que es donde se puede
ejercitar de verdad: allí se le cambian datos a propósito y se comprueba que los
detecta.

> El proceso sabe hacer las dos cosas. Con el dato real hemos ejercitado la carga
> completa; el incremental está probado en laboratorio, donde podemos provocar
> los cambios que hacen falta para probarlo.

**Lo que no se dice es "el incremental es N veces más rápido".** No lo hemos
medido con dato real, y la cifra fácil —lanzarlo detrás de una carga completa
sobre datos que no se movieron— mide lo que cuesta *confirmar que no hay
cambios*, no la eficiencia. Si alguien la pide, ésa es la respuesta.

### 9 · La decisión

> Les pedimos el aval para avanzar a producción. El motor funciona y está medido.
>
> Lo que queda no es lógica de negocio: son tres dependencias externas. Nueve
> catálogos que el proceso consume y no se han entregado. Dos de las siete tablas
> que dependen de que el georreferenciador empiece a responder. Y el contrato de
> salida, que se cierra cuando llegue su documento de homologación.

---

## Las tres preguntas difíciles, y su respuesta

| Pregunta | Respuesta corta |
|---|---|
| *"¿Están botando el 74% del buró?"* | No. Son empresas con cientos de sedes; Teradata las excluye igual. 106 NIT concentran 134.357 relaciones. |
| *"Diecinueve unificaciones parece nada."* | 78.188 de las que entraron eran direcciones únicas: no había con quién emparejarlas. De las que sí tenían candidato, **ninguna quedó sin resolver**. No es que no resolviera; es que no había qué resolver. |
| *"¿Por qué dos tablas en cero?"* | Dependen del georreferenciador externo, que todavía no procesa. Está documentado y es dependencia de terceros, no código faltante. |
| *"¿El incremental sirve de algo?"* | El control incremental es diseño nuevo: el proceso de Teradata nunca lo tuvo. Funciona y **está certificado con datos de laboratorio**, que es donde se pueden provocar los cambios que lo prueban. Con dato real el alcance acordado es la carga completa. |

---

## Antes de la sesión

| Qué | Estado |
|---|---|
| Correr el e2e real en QA y capturar cifras | **pendiente** — consultas en `framework_batch/captura_qa_real.sql` |
| Tiempo de la malla actual en Teradata | **pendiente** — lo consigue el presentador |
| Compartir el artefacto con los asistentes | **pendiente** — menú Share de la página |

**Un aviso sobre una cifra:** el alcance de Unificación (50) es un literal escrito
a mano en el tablero, no un conteo. Los de Ordenamiento (45) y Novedades (26) sí
se cuentan solos. Si alguien audita el tablero, conviene saberlo.

## Las fuentes de cada número

| Bloque | Fuente |
|---|---|
| Embudo, canales, tiempos | `REPORTE_DRILLDOWN_VIA_REAL.md` — job DEV/DATABASE #491, lote 1356301 |
| Veredictos del mock | jobs DEV/DATABASE #491 (Unificación, Ordenamiento, Novedades) y #402 (GEO) |
| 189 criterios | los tres DDL de catálogo en `strct` |
| 32 de 47, los 600 puntos, el caso Gmail | `AUDITORIA_SEMANTICA_ORDENAMIENTO_F4.md` |
| 1.083 puntos saneados | 618 + 299,79 + 165,97 |
| 29 diferencias | `BITACORA_DIFERENCIAS.md` |
| Defectos del legado | `legado_teradata/` — citados línea por línea en la bitácora |
