#!/usr/bin/env bash
# banco.sh -- replica en local el job de Jenkins, sobre PostgreSQL 16.
#
# Ejecuta los tres deploy.par en orden (strct -> pgm -> dt), archivo a archivo,
# que es exactamente lo que hace el pipeline. Lo que gana: Redshift NO compila
# el cuerpo de un procedimiento al crearlo -- los errores salen en la primera
# invocacion -- y Postgres SI. Un verde aqui NO es una certificacion; ver
# README.md.
#
#   ./banco.sh init                arranca el cluster, shims y stub
#   ./banco.sh fase strct|pgm|dt   una fase
#   ./banco.sh todo                las tres
#   ./banco.sh foto <tag>          guarda el estado como plantilla
#   ./banco.sh desde <tag>         restaura y sigue (re-correr rapido)
#   ./banco.sh psql                consola
#   ./banco.sh parar | estado | limpio
set -uo pipefail

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
  runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGROOT" -w -t 30 \
    -l "$PGROOT/pg.log" \
    -o "-p $PUERTO -k $SOCK -c listen_addresses=''
        -c fsync=off -c full_page_writes=off -c synchronous_commit=off
        -c shared_buffers=1GB -c work_mem=128MB
        -c maintenance_work_mem=256MB -c max_connections=20
        -c max_locks_per_transaction=4096
        -c plan_cache_mode=force_custom_plan
        -c TimeZone=UTC -c DateStyle='ISO, YMD'" start >/dev/null
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
  local orig; orig="$(paq_de "$repo")/SQL/$entrada"
  local dest="$OUT/$fase/$entrada"
  mkdir -p "$(dirname "$dest")"
  if ! python3 -I "$BANCO/transpila.py" "$orig" "$dest" 2>>"$OUT/transpila.log"; then
    printf '%s\t%s\t-\tTRANSPILA\tHUECO_BANCO\tel transpilador rechazo el archivo\n' \
           "$fase" "$entrada" >> "$OUT/errores.tsv"
    return 1
  fi
  local log="$OUT/$fase/$entrada.log"
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
        [ "$at" = 1 ] && analiza_base
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
  return "$mal"
}

cmd_foto() { sql postgres "DROP DATABASE IF EXISTS foto_$1;" >/dev/null 2>&1
             sql postgres "CREATE DATABASE foto_$1 TEMPLATE $BD;" && echo "foto_$1 guardada"; }
cmd_desde() { sql postgres "DROP DATABASE IF EXISTS $BD;" >/dev/null 2>&1
              sql postgres "CREATE DATABASE $BD TEMPLATE foto_$1;" || return 1
              sql "$BD" "ALTER DATABASE $BD SET search_path = \"\$user\", public, rs;"
              sql "$BD" "ALTER DATABASE $BD SET plan_cache_mode = force_custom_plan;"
              echo "restaurado desde foto_$1"; }

case "${1:-}" in
  init)   shift; cmd_init "${1:-}";;
  fase)   shift; : > "$OUT/errores.tsv"; cmd_fase "$@";;
  todo)   shift; cmd_init nueva; : > "$OUT/errores.tsv"
          cmd_fase strct "$@"; cmd_fase pgm "$@"; cmd_fase dt "$@";;
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
