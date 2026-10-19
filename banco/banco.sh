#!/usr/bin/env bash
# banco.sh -- replica en local el job de Jenkins, sobre PostgreSQL 16.
#
# Ejecuta los tres deploy.par en orden (strct -> pgm -> dt), archivo a archivo,
# y desde SLCOPRBA-1355 tambien los rollback.par y el ciclo controlado
# completo. Lo que gana: Redshift NO compila
# el cuerpo de un procedimiento al crearlo -- los errores salen en la primera
# invocacion -- y Postgres SI. Un verde aqui NO es una certificacion; ver
# README.md.
#
#   ./banco.sh init                arranca el cluster, shims y stub
#   ./banco.sh fase strct|pgm|dt   una fase
#   ./banco.sh todo                las tres
#   ./banco.sh rollback <fase>     corre rollback.par (el reverso)
#   ./banco.sh ciclo <fase>        el ciclo de Jenkins entero:
#                                  PRECHECK -> DDL_1 -> DPLY -> RLLBCK_FINAL
#                                  -> DDL_3 -> compare -> DPLY. Es el unico
#                                  modo que caza un rollback asimetrico
#                                  ([REDSHIFT:335], job QA #122) o uno que
#                                  aborta (2BP01, job DEV #422)
#   ./banco.sh foto <tag>          guarda el estado como plantilla
#   ./banco.sh desde <tag>         restaura y sigue (re-correr rapido)
#   ./banco.sh psql                consola
#   ./banco.sh parar | estado | limpio
#
#   BANCO_N=100 ./banco.sh todo    baja la replica por arquetipo SOLO AQUI
#                                  (el repo y Redshift siguen en 1000; minimo
#                                  100, ver el comentario en corre_archivo)
set -uo pipefail

# Piso de 100: por debajo, la mutacion de la fase 3 de la bateria -- que
# siembra un 'n.i < 100' FIJO -- apuntaria a personas no sembradas.
if [ -n "${BANCO_N:-}" ] && [ "$BANCO_N" -lt 100 ] 2>/dev/null; then
  echo "BANCO_N=$BANCO_N es menor que el piso de 100; se usa 100" >&2
  BANCO_N=100
fi

BANCO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DT="$(dirname "$BANCO")"
RAIZ="$(dirname "$DT")"
STRCT="$RAIZ/db_rcncr_btch_rdshft_strct_full_delta"
PGM="$RAIZ/db_rcncr_btch_rdshft_pgm_full_delta"

PGBIN=/usr/lib/postgresql/16/bin
PGROOT=/var/lib/postgresql/banco
SOCK=/tmp
PUERTO=55432
# La base se llama como el datashare a proposito: Postgres acepta el nombre de
# tres partes `ds_dba_rncr_batch.edf_views.xpm` cuando la primera parte es la
# base actual, asi que las 14 referencias resuelven sin reescribir nada.
BD=ds_dba_rncr_batch
OUT="$BANCO/out"

V='\033[32m'; R='\033[31m'; A='\033[33m'; O='\033[0m'
# El search_path va en PGOPTIONS y no solo en ALTER DATABASE: CREATE DATABASE
# ... TEMPLATE no copia los ajustes por base, asi que al restaurar una foto los
# shims de `rs` se volvian invisibles y salia "function getdate() does not
# exist". Puesto aqui, vale para toda invocacion sin depender del estado.
export PGOPTIONS='-c search_path=public,rs'
PSQL=(psql -X -q -h "$SOCK" -p "$PUERTO" -U postgres)

falla=0

sql() { "${PSQL[@]}" -d "$1" -v ON_ERROR_STOP=1 -c "$2"; }

arranca() {
  if [ ! -s "$PGROOT/PG_VERSION" ]; then
    install -d -o postgres -g postgres "$PGROOT"
    runuser -u postgres -- "$PGBIN/initdb" -D "$PGROOT" -U postgres \
            -A trust -E UTF8 --locale=C >/dev/null || return 1
  fi
  if runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" status >/dev/null 2>&1; then
    return 0
  fi
  # EL -o VA EN UNA SOLA LINEA, Y NO ES ESTILO: pg_ctl DEJA DE PARSEAR LA
  # CADENA EN EL PRIMER SALTO DE LINEA, sin avisar. Partida en siete lineas
  # como estaba, lo unico que llegaba al servidor era
  #   -p 55432 -k /tmp -c listen_addresses=''
  # y los doce ajustes restantes se perdian. Comprobado con pg_settings: con
  # la version partida, fsync salia 'on' por DEFAULT y work_mem 4MB por
  # DEFAULT; en una linea, las dos salen con source 'command line'.
  #
  # Lo que costaba: el banco corria con los valores de fabrica -- work_mem de
  # 4MB sobre tablas de 85.000 filas, que desborda cada hash join y cada sort
  # a disco (medidos 855 archivos temporales y 2,7 GB), y ADEMAS con fsync y
  # synchronous_commit en 'on', de modo que cada commit esperaba al disco.
  # Nada de esto se veia: Postgres arrancaba y respondia igual.
  #
  # Los valores son seguros aqui y solo aqui: es un banco desechable de una
  # sola sesion. fsync=off se puede perder la base entera ante un corte, y da
  # igual -- se reconstruye con 'init nueva'. NUNCA en nada que no sea esto.
  local OPC="-p $PUERTO -k $SOCK -c listen_addresses=''"
  OPC="$OPC -c fsync=off -c full_page_writes=off -c synchronous_commit=off"
  OPC="$OPC -c shared_buffers=2GB -c work_mem=512MB"
  OPC="$OPC -c maintenance_work_mem=1GB -c max_connections=20"
  OPC="$OPC -c effective_cache_size=10GB -c random_page_cost=1.1"
  OPC="$OPC -c max_locks_per_transaction=4096"
  OPC="$OPC -c max_parallel_workers_per_gather=4 -c max_parallel_workers=4"
  OPC="$OPC -c plan_cache_mode=force_custom_plan"
  OPC="$OPC -c TimeZone=UTC -c DateStyle='ISO, YMD'"
  runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" -w -t 30 \
    -l "$PGROOT/pg.log" -o "$OPC" start >/dev/null
}

cmd_init() {
  arranca || { echo -e "${R}el cluster no arranca${O}"; exit 1; }
  mkdir -p "$OUT"
  # `init nueva` rehace la base desde cero. Hace falta mas de lo que parece:
  # en Redshift las vistas son WITH NO SCHEMA BINDING, de enlace tardio, asi
  # que no registran dependencia y un DROP TABLE IF EXISTS pasa siempre. Al
  # quitar esa clausula, Postgres SI registra la dependencia y el mismo DROP
  # falla con "other objects depend on it" en la segunda pasada. Es artefacto
  # del banco, no del codigo: la salida honesta es desplegar sobre base limpia,
  # que es el escenario del primer despliegue de Jenkins.
  if [ "${1:-}" = nueva ]; then
    sql postgres "DROP DATABASE IF EXISTS $BD;" >/dev/null
  fi
  "${PSQL[@]}" -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$BD'" | grep -q 1 \
    || sql postgres "CREATE DATABASE $BD TEMPLATE template0 ENCODING UTF8 LC_COLLATE 'C' LC_CTYPE 'C';"
  # El search_path lleva `rs` para que GETDATE/FNV_HASH/LEN/TRUNC resuelvan
  # por sobrecarga y el transpilador no tenga que tocar el texto.
  sql "$BD" "ALTER DATABASE $BD SET search_path = \"\$user\", public, rs;"
  sql "$BD" "ALTER DATABASE $BD SET plan_cache_mode = force_custom_plan;"
  "${PSQL[@]}" -d "$BD" -v ON_ERROR_STOP=1 -f "$BANCO/shims.sql" || exit 1
  python3 -I "$BANCO/stub_datashare.py" \
    "$(paq_de "$STRCT")/SQL/02_vistas_insumo_edf_views.sql" \
    "$(paq_de "$STRCT")/SQL/03_vistas_contacto_canal_edf_views.sql" \
    > "$OUT/stub_datashare.sql" || exit 1
  "${PSQL[@]}" -d "$BD" -v ON_ERROR_STOP=1 -f "$OUT/stub_datashare.sql" || exit 1
  # Los esquemas bdm_* NO se precrean: los crea el DDL del repo, y asi el banco
  # prueba tambien eso.
  echo -e "${V}init OK${O}  base $BD, puerto $PUERTO, shims y stub cargados"
  sql "$BD" "SELECT rs.datediff('month', DATE '2026-01-31', DATE '2026-02-01') AS debe_ser_1;" \
    | grep -qw 1 && echo -e "${V}  semantica de DATEDIFF verificada (cruce de frontera)${O}" \
    || { echo -e "${R}  DATEDIFF no cuenta fronteras${O}"; exit 1; }
}

# ANALYZE del lado del banco tras sembrar. Es compensacion del MOTOR, no un
# cambio al repo: Unificacion tiene 93 CTAS y cero ANALYZE, y Redshift sobrevive
# a eso por fuerza bruta columnar mientras Postgres single-node se queda minutos
# en el primer self-join sin estadisticas. El ANALYZE que falta en el repo esta
# anotado como hallazgo y queda fuera del alcance de esta tanda.
analiza_base() { "${PSQL[@]}" -d "$BD" -c "ANALYZE;" >/dev/null 2>&1; }

# Indices sobre las llaves de join de las tablas sembradas. Tambien es
# compensacion del motor: Redshift es columnar y resuelve estos joins por
# fuerza bruta con el DISTKEY; Postgres en un nodo necesita el indice. El primer
# CTAS de la Regla 1 es un join de seis vias con COUNT(DISTINCT) y GROUP BY, y
# sin indices se come minutos de CPU.
indexa_base() {
  "${PSQL[@]}" -d "$BD" >/dev/null 2>&1 <<'IDX'
CREATE INDEX IF NOT EXISTS ix_b_rpu_ubic   ON bdm_stage.relacion_persona_ubicacion (cod_dw_ubic);
CREATE INDEX IF NOT EXISTS ix_b_rpu_pers   ON bdm_stage.relacion_persona_ubicacion (id_buro_persona);
CREATE INDEX IF NOT EXISTS ix_b_rpu_pu     ON bdm_stage.relacion_persona_ubicacion (cod_dw_persona_ubic);
CREATE INDEX IF NOT EXISTS ix_b_rpu_df     ON bdm_stage.relacion_persona_ubicacion (cod_dw_direccion_fisica);
CREATE INDEX IF NOT EXISTS ix_b_ubi_ubic   ON bdm_stage.ubicacion_estandarizada (cod_dw_ubic);
CREATE INDEX IF NOT EXISTS ix_b_rep_pu     ON bdm_stage.reporte_relacion_persona_ubica (cod_dw_persona_ubic);
CREATE INDEX IF NOT EXISTS ix_b_can_pu     ON bdm_stage.contacto_canal (cod_dw_persona_ubic);
CREATE INDEX IF NOT EXISTS ix_b_can_pers   ON bdm_stage.contacto_canal (id_buro_persona);
IDX
}

repo_de() { case "$1" in strct) echo "$STRCT";; pgm) echo "$PGM";; dt) echo "$DT";; esac; }

# El paquete puede estar en deploy/redshift/ o, cuando se aplique migra418.sh,
# en deploy/redshift/<identificador>/. Se resuelve buscando el deploy.par para
# que el banco sobreviva a la migracion sin editarlo.
paq_de() {
  local r="$1"
  if [ -f "$r/deploy/redshift/deploy.par" ]; then echo "$r/deploy/redshift"; return; fi
  local d; d=$(dirname "$(ls -1 "$r"/deploy/redshift/*/deploy.par 2>/dev/null | head -1)")
  [ -n "$d" ] && echo "$d"
}

# Transpila y ejecuta un archivo. Devuelve 0 si corrio limpio.
corre_archivo() {
  local fase="$1" repo="$2" entrada="$3" parar="$4" anota="${5:-1}"
  # Sexto parametro: la carpeta de origen. SQL/ es el deploy; RevSQL/ es el
  # reverso, que hasta SLCOPRBA-1355 el banco NO CORRIA NUNCA. Ese fue el
  # agujero por el que pasaron el QA #122 y el DEV #422: los dos murieron en
  # un stage de rollback que aqui no existia.
  local carpeta="${6:-SQL}"
  local orig; orig="$(paq_de "$repo")/$carpeta/$entrada"
  local dest="$OUT/$fase/$entrada"
  [ "$carpeta" = SQL ] || dest="$OUT/$fase/rev/$entrada"
  mkdir -p "$(dirname "$dest")"
  if ! python3 -I "$BANCO/transpila.py" "$orig" "$dest" 2>>"$OUT/transpila.log"; then
    printf '%s\t%s\t-\tTRANSPILA\tHUECO_BANCO\tel transpilador rechazo el archivo\n' \
           "$fase" "$entrada" >> "$OUT/errores.tsv"
    return 1
  fi
  # ------------------------------------------------------------------
  # BANCO_N: la replica por arquetipo, SOLO EN EL BANCO.
  #
  # Las semillas acotan con 'WHERE n.i < 1000', que son ~85.000 personas y
  # unas dos horas de bateria en un nodo. Para una hipotesis barata no hace
  # falta ese volumen. Con BANCO_N=100 el mismo recorrido pasa a minutos.
  #
  # EL REPO NO SE TOCA Y REDSHIFT SIGUE EN 1000. La sustitucion ocurre sobre
  # la COPIA transpilada que vive en out/, nunca sobre el archivo del paquete.
  # Es deliberado que este aqui y no en transpila.py: aquel corrige SINTAXIS
  # de Redshift a Postgres y su cabecera dice que reescribir texto es la
  # ultima opcion. Esto cambia los DATOS, que es otra cosa, y tiene que verse.
  #
  # PISO DE 100, Y NO ES ARBITRARIO: la mutacion de la fase 3 siembra un
  # 'WHERE n.i < 100' FIJO sobre los ARQ 21 y 22
  # (run_reconocer_e2e_mock_full_delta.sql:169,181). Por debajo de 100
  # referenciaria personas que no existen y DELTA2 daria FAILED por un efecto
  # de siembra, no por un defecto.
  #
  # El gate por arquetipo MIDE N del dato desde SLCOPRBA-1355
  # (sp_unificacion_mock_gate_arq.sql, tabla stg_gate_n), de modo que sus
  # conteos acompanan. Antes clavaba 66000/8000/5000/1000 y cualquier N
  # distinto lo ponia entero en FAILED.
  # ------------------------------------------------------------------
  if [ -n "${BANCO_N:-}" ] && [ "$BANCO_N" != 1000 ]; then
    sed -i -E "s/\bn\.i < 1000\b/n.i < $BANCO_N/g" "$dest"
  fi
  # El log cuelga del destino, no de la fase: si no, el reverso releeria
  # el log del DPLY anterior y reportaria fallos que no son suyos.
  local log="$dest.log"
  "${PSQL[@]}" -d "$BD" -v ON_ERROR_STOP="$parar" --echo-errors \
       -f "$dest" > "$log" 2>&1
  local rc=$?
  # La invariante de saltos de linea del transpilador hace que la linea que
  # reporta psql SEA la del archivo original. Solo hay que reescribir la ruta.
  if grep -q '^psql:.*ERROR' "$log"; then
    [ "$anota" = 1 ] && grep '^psql:' "$log" | sed -n 's|^psql:[^:]*:\([0-9]*\): ERROR:  \(.*\)$|\1\t\2|p' \
      | while IFS=$'\t' read -r ln msg; do
          printf '%s\t%s\t%s\t-\t?\t%s\n' "$fase" "$entrada" "$ln" "$msg" \
            >> "$OUT/errores.tsv"
        done
    return 1
  fi
  return $rc
}

cmd_fase() {
  local fase="$1"; shift
  local solo="" parar=1 pasadas=1
  # strct necesita varias pasadas, y no por un defecto del DDL: en Redshift las
  # vistas son WITH NO SCHEMA BINDING -- enlace tardio -- de modo que
  # 02_vistas_insumo_edf_views.sql puede referenciar bdm_datos.geo_atributos
  # aunque la cree 03_ddl_geo.sql tres archivos despues. El propio codigo lo
  # dice en su cabecera. Al quitar la clausula, Postgres exige el orden de
  # dependencias. Se re-corren SOLO los que fallaron hasta que el conjunto deja
  # de encogerse; lo que sobreviva es un hallazgo de verdad. Es seguro porque
  # el DDL de strct es idempotente: IF NOT EXISTS, CREATE OR REPLACE VIEW,
  # TRUNCATE + INSERT.
  [ "$fase" = strct ] && pasadas=3
  while [ $# -gt 0 ]; do
    case "$1" in
      --solo) solo="$2"; shift 2;;
      --sigue) parar=0; shift;;
      --pasadas) pasadas="$2"; shift 2;;
      *) shift;;
    esac
  done
  local repo; repo="$(repo_de "$fase")"
  local paq; paq="$(paq_de "$repo")"
  local par="$paq/deploy.par"
  mkdir -p "$OUT/$fase"; : > "$OUT/transpila.log"

  local -a pendientes=()
  while read -r entrada; do
    [ -z "$entrada" ] && continue
    [ -n "$solo" ] && [ "$entrada" != "$solo" ] && continue
    pendientes+=("$entrada")
  done < "$par"
  local total=${#pendientes[@]}

  local pasada=1
  while :; do
    local -a fallaron=()
    local ultima=0
    [ "$pasada" -ge "$pasadas" ] && ultima=1
    [ "$pasada" -gt 1 ] && echo -e "  ${A}pasada $pasada${O} sobre ${#pendientes[@]} archivos que fallaron"
    for entrada in "${pendientes[@]}"; do
      case "$entrada" in seed_mock_*|reset_mock.sql) at=1;; *) at=0;; esac
      if corre_archivo "$fase" "$repo" "$entrada" "$([ "$ultima" = 1 ] && echo "$parar" || echo 0)" "$ultima"; then
        [ "$at" = 1 ] && { indexa_base; analiza_base; }
        [ "$pasada" = 1 ] && printf "  ${V}ok${O}   %s\n" "$entrada"
        [ "$pasada" -gt 1 ] && printf "  ${V}ok${O}   %s  ${A}(resuelto en la pasada %s)${O}\n" "$entrada" "$pasada"
      else
        fallaron+=("$entrada")
        if [ "$ultima" = 1 ]; then
          printf "  ${R}FALLA${O} %s\n" "$entrada"
          grep -m3 'ERROR:' "$OUT/$fase/$entrada.log" \
            | sed -n 's|^psql:[^:]*:\([0-9]*\): ERROR:  |    linea \1: |p'
          [ "$parar" = 1 ] && [ -z "$solo" ] && break
        fi
      fi
    done
    if [ "$ultima" = 1 ] || [ ${#fallaron[@]} -eq 0 ] \
       || [ ${#fallaron[@]} -eq ${#pendientes[@]} ]; then
      pendientes=("${fallaron[@]+"${fallaron[@]}"}")
      [ ${#fallaron[@]} -eq 0 ] && break
      [ "$ultima" = 1 ] && break
      # el conjunto dejo de encogerse: una pasada final que si reporta
      pasadas=$((pasada+1)); pasada=$((pasada+1)); continue
    fi
    pendientes=("${fallaron[@]}")
    pasada=$((pasada+1))
  done

  local mal=${#pendientes[@]}
  [ "$mal" -gt 0 ] && falla=1
  echo -e "fase ${A}$fase${O}: $total archivos, $mal con fallo"
  # El veredicto de verdad de una fase de DDL o de procedimientos no es "cada
  # archivo corrio limpio" sino "al terminar existen todos los objetos". Es lo
  # unico inmune a las divergencias de enlace tardio y de DROP de Postgres.
  if [ -z "$solo" ] && [ "$fase" != dt ]; then
    python3 -I "$BANCO/verifica.py" "$par" "$paq/SQL" > "$OUT/verifica_$fase.sql" 2>/dev/null
    local v; v=$("${PSQL[@]}" -d "$BD" -tAf "$OUT/verifica_$fase.sql" 2>/dev/null | tr -d '\n')
    case "$v" in
      TODOS*) echo -e "  ${V}$v${O}";;
      FALTAN*) echo -e "  ${R}$v${O}"; falla=1; mal=$((mal+1));;
      *) echo -e "  ${A}no se pudo verificar el estado final${O}";;
    esac
  fi
  return "$mal"
}

# La huella del transpilador y de los shims se guarda con la foto. Un cambio en
# transpila.py NO se refleja en los procedimientos ya creados: siguen con el
# cuerpo viejo dentro de la base. Costo 20 minutos aprenderlo con
# DATE_PART(year, x), asi que ahora el banco avisa.
huella() { md5sum "$BANCO/transpila.py" "$BANCO/shims.sql" 2>/dev/null | md5sum | cut -c1-12; }

cmd_foto() { sql postgres "DROP DATABASE IF EXISTS foto_$1;" >/dev/null 2>&1
             sql postgres "CREATE DATABASE foto_$1 TEMPLATE $BD;" || return 1
             mkdir -p "$OUT"; huella > "$OUT/foto_$1.huella"
             echo "foto_$1 guardada"; }
cmd_desde() { sql postgres "DROP DATABASE IF EXISTS $BD;" >/dev/null 2>&1
              sql postgres "CREATE DATABASE $BD TEMPLATE foto_$1;" || return 1
              sql "$BD" "ALTER DATABASE $BD SET search_path = \"\$user\", public, rs;"
              sql "$BD" "ALTER DATABASE $BD SET plan_cache_mode = force_custom_plan;"
              echo "restaurado desde foto_$1"
              if [ -f "$OUT/foto_$1.huella" ] && [ "$(cat "$OUT/foto_$1.huella")" != "$(huella)" ]; then
                echo -e "  ${R}AVISO${O}: el transpilador o los shims cambiaron despues de esta foto."
                echo -e "  ${R}     ${O} Los procedimientos de la foto llevan el cuerpo VIEJO."
                echo -e "  ${R}     ${O} Corre './banco.sh fase pgm' y vuelve a tomar la foto."
              fi; }

# ------------------------------------------------------------------
# EL REVERSO Y EL CICLO CONTROLADO: el QUINTO PUNTO CIEGO del banco.
#
# Hasta SLCOPRBA-1355 el banco corria deploy.par y nada mas. El pipeline de
# Jenkins corre OTRA COSA:
#   RLLBCK_PRECHECK -> DDL_1 -> DPLY -> DDL_2 -> RLLBCK_FINAL -> DDL_3
#   -> compare -> DPLY
# o sea que el rollback se ejecuta DOS VECES y el esquema se fotografia tres.
# Los dos ultimos builds rojos murieron ahi y el banco no vio ninguno:
#   QA/DATABASE #122  [REDSHIFT:335]  DDL_1 != DDL_3: objetos sin reverso.
#   DEV/DATABASE #422 [REDSHIFT:112]  2BP01 en RLLBCK_FINAL: DROP SCHEMA
#                                     bdm_stage con objetos de pgm dentro.
#
# EL #422 SE REPRODUCE AQUI, y es lo que justifica el modo: despues de
# 'fase pgm' el esquema bdm_stage tiene los tres wrappers GEO, de modo que
# Postgres aborta el DROP SCHEMA igual que Redshift. El #122 se reproduce por
# el diff de catalogo.
#
# LO QUE SIGUE SIN VERSE, y hay que decirlo: 'DROP TABLE IF EXISTS x.y' con el
# ESQUEMA ausente es 3F000 en Redshift y en Postgres solo un NOTICE. Ese caso
# -- el otro fallo del #122 -- es un punto ciego mas, y por eso las guardas
# CREATE SCHEMA IF NOT EXISTS de RevSQL/ se sostienen en la lectura del log de
# Jenkins, no en este banco.
# ------------------------------------------------------------------
rev_malos=0
cmd_rollback() {
  local fase="$1" parar="${2:-0}"
  local repo; repo="$(repo_de "$fase")"
  local paq; paq="$(paq_de "$repo")"
  mkdir -p "$OUT/$fase/rev"
  local n=0 malos=0
  while read -r entrada; do
    [ -z "$entrada" ] && continue
    n=$((n+1))
    # ON_ERROR_STOP=0 SIEMPRE, y no es laxitud: las sentencias del hueco
    # NO FALLAN en Redshift, asi que cortar el archivo ahi deja sin ejecutar
    # las de abajo y arrastra fallos en cascada que el pipeline no tiene. Es
    # justo lo que paso con RevSQL/01: su DROP TABLE insumo_direccion solo es
    # un no-op porque RevSQL/04 ya borro la vista homonima, y al cortarse 04
    # en su linea 5 la vista seguia en pie. Quien decide abortar la etapa es
    # el clasificador de abajo, no psql.
    if corre_archivo "$fase" "$repo" "$entrada" 0 0 RevSQL; then
      printf "  ${V}ok${O}   %s\n" "$entrada"
    else
      # CLASIFICACION, Y ES LO QUE HACE EL MODO UTIL EN VEZ DE RUIDOSO.
      # 'cannot drop table|view X because other objects depend on it' es un
      # falso positivo del banco: nuestras vistas van WITH NO SCHEMA BINDING y
      # en Redshift NO crean dependencia -- por eso existe la clausula. La
      # prueba es el log del job DEV/DATABASE #422: de los 37 archivos del
      # precheck fallo UNO, el 00, y los otros 36 -- estos seis incluidos --
      # corrieron limpios en Redshift.
      # EL CASO DEL ESQUEMA NO SE PERDONA: ahi los dos motores coinciden, y es
      # exactamente el 2BP01 que tumbo ese build.
      local err; err=$(grep -m1 'ERROR:' "$OUT/$fase/rev/$entrada.log" 2>/dev/null)
      if printf '%s' "$err" | grep -qiE 'cannot drop (table|view) .* because other objects depend'; then
        printf "  ${A}HUECO${O} %s  ${A}(dependencia que Redshift no tiene: NO SCHEMA BINDING)${O}\n" "$entrada"
      else
        malos=$((malos+1))
        printf "  ${R}FALLA${O} %s\n" "$entrada"
        grep -m2 'ERROR:' "$OUT/$fase/rev/$entrada.log" 2>/dev/null \
          | sed -n 's|^psql:[^:]*:\([0-9]*\): ERROR:  |    linea \1: |p'
        [ "$parar" = 1 ] && { falla=1; return 1; }
      fi
    fi
  done < "$paq/rollback.par"
  echo "  $n archivos, $malos con error"
  rev_malos="$malos"
  [ "$malos" -gt 0 ] && [ "$parar" = 1 ] && falla=1
  return 0
}

# La foto del esquema, con el mismo grano que el comparador del pipeline:
# esquema, tabla, columna y tipo, mas las rutinas. No mira datos.
foto_ddl() {
  "${PSQL[@]}" -d "$BD" -At -c "
    SELECT 'SCHEMA|'||nspname FROM pg_namespace
     WHERE nspname IN ('bdm_datos','bdm_tempo','bdm_stage')
    UNION ALL
    SELECT 'COLUMN|'||table_schema||'|'||table_name||'|'||column_name
           ||'|'||data_type
      FROM information_schema.columns
     WHERE table_schema IN ('bdm_datos','bdm_tempo','bdm_stage')
    UNION ALL
    SELECT 'ROUTINE|'||n.nspname||'|'||p.proname
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('bdm_datos','bdm_tempo','bdm_stage')
    ORDER BY 1" | sort
}

cmd_ciclo() {
  local fase="$1"; shift
  echo -e "${A}=== ciclo controlado sobre $fase (replica del job de Jenkins) ===${O}"
  echo -e "${A}[1/6] RLLBCK_PRECHECK${O}  (no para en error, como catchError)"
  cmd_rollback "$fase" 0
  echo -e "${A}[2/6] DDL_1${O}"
  foto_ddl > "$OUT/ddl_1.txt"; echo "  $(wc -l < "$OUT/ddl_1.txt") entradas"
  echo -e "${A}[3/6] DPLY${O}"
  # No se corta si el DPLY deja archivos en rojo: en el banco strct arrastra
  # dos fallos de la misma familia NO SCHEMA BINDING (01_ddl_unificacion_
  # direccion y 02_vistas_insumo_edf_views) y aun asi deja los 121 objetos en
  # pie. Cortar aqui dejaria el paso que de verdad importa -- el compare --
  # sin correr nunca.
  if ! cmd_fase "$fase" "$@"; then
    echo -e "  ${A}AVISO${O}: el DPLY dejo archivos en rojo; si son del hueco de"
    echo -e "  ${A}     ${O} Postgres el compare sigue valiendo, si no, leelo con pinzas"
  fi
  foto_ddl > "$OUT/ddl_2.txt"
  echo -e "${A}[4/6] RLLBCK_FINAL${O}  (PARA en error: aqui murio el #422)"
  cmd_rollback "$fase" 1 || return 1
  echo -e "${A}[5/6] DDL_3${O}"
  foto_ddl > "$OUT/ddl_3.txt"; echo "  $(wc -l < "$OUT/ddl_3.txt") entradas"
  echo -e "${A}[6/6] compare DDL_1 vs DDL_3${O}"
  local simetrico=1
  if diff -u "$OUT/ddl_1.txt" "$OUT/ddl_3.txt" > "$OUT/ddl_diff.txt"; then
    echo -e "  ${V}OK${O}   sin diferencias: el rollback es simetrico"
  else
    simetrico=0; falla=1
    echo -e "  ${R}FALLA${O} [REDSHIFT:335] el rollback no revierte todo:"
    grep -E '^[+-][^+-]' "$OUT/ddl_diff.txt" | head -20 | sed 's|^|        |'
    echo "        detalle en out/ddl_diff.txt"
  fi
  echo -e "${A}[+] DPLY de vuelta${O}  (el pipeline tambien redespliega)"
  cmd_fase "$fase" "$@"
  # El veredicto va al final y aparte, porque el codigo de salida lo tine el
  # redespliegue: en strct arrastra dos fallos del hueco de Postgres y daria
  # rc=1 sobre un ciclo verde.
  echo
  if [ "$simetrico" = 1 ] && [ "$rev_malos" = 0 ]; then
    echo -e "${V}CICLO VERDE${O} sobre $fase: RLLBCK_FINAL sin errores reales y DDL_1 == DDL_3"
  else
    echo -e "${R}CICLO ROJO${O} sobre $fase: rollback con $rev_malos error(es), simetrico=$simetrico"
  fi
}

case "${1:-}" in
  init)   shift; cmd_init "${1:-}";;
  fase)   shift; : > "$OUT/errores.tsv"; cmd_fase "$@";;
  todo)   shift; cmd_init nueva; : > "$OUT/errores.tsv"
          cmd_fase strct "$@"; cmd_fase pgm "$@"; cmd_fase dt "$@";;
  rollback) shift; : > "$OUT/errores.tsv"; cmd_rollback "$1" "${2:-0}";;
  ciclo)  shift; : > "$OUT/errores.tsv"; cmd_ciclo "$@";;
  foto)   cmd_foto "$2";;
  desde)  cmd_desde "$2";;
  psql)   shift; exec "${PSQL[@]}" -d "$BD" "$@";;
  parar)  runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" -w stop;;
  estado) runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" status;;
  limpio) runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" -w stop 2>/dev/null
          rm -rf "$PGROOT" "$OUT"; echo "cluster y salidas borrados";;
  *) sed -n '2,20p' "$0"; exit 1;;
esac
exit $falla
