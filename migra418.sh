#!/usr/bin/env bash
# migra418.sh -- mueve el paquete a deploy/redshift/<identificador>/, y lo deshace.
#
# EL BLOQUEANTE. El job #353 murio en 'Before deploy', antes de ejecutar una
# sola sentencia:
#
#   ERROR: [REDSHIFT:418] Se detecto la estructura legacy en 'deploy/redshift'.
#   Mueva el paquete a deploy/redshift/<identificador>/{deploy.par,SQL,RevSQL}.
#
# No es nuestro codigo. La libreria compartida se carga desde una rama FEATURE,
# EITS_SLA_CO_DEVOPS_SHRD_LBS@feature/SPDE-15069-archivos-par-database-redshift,
# con el commit "Nueva forma de crear el paquete a desplegar v1".
#
# QUE VALOR LLEVA <identificador>. Ningun documento del proyecto lo dice, pero
# el repo si: los tres .jenkins.yml declaran
#
#   global:
#     application: dba_rncr_batch
#
# que es el mismo nombre del usuario del consumidor y del datashare
# (ds_dba_rncr_batch). Para un paquete database-redshift es el candidato
# natural. ES UNA HIPOTESIS, NO UN DATO: confirmar con DevOps antes de aplicar.
#
# Ningun .sql cambia. Es un movimiento de carpetas y dos lineas de texto.
#
#   ./migra418.sh plan     [id]   que haria, sin tocar nada  (por omision)
#   ./migra418.sh aplicar  [id]
#   ./migra418.sh revertir [id]
#   ./migra418.sh traslado [id]   imprime el traslado a Bitbucket con la trampa
set -uo pipefail

ACCION="${1:-plan}"
ID="${2:-dba_rncr_batch}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS=(db_rcncr_btch_rdshft_strct_full_delta
       db_rcncr_btch_rdshft_pgm_full_delta
       db_rcncr_btch_rdshft_dt_full_delta)
JIRA=(SLCOPRBA-1397-strct SLCOPRBA-1398-pgm SLCOPRBA-1399-dt)
PIEZAS=(deploy.par rollback.par SQL RevSQL)
RAMA=claude/elegant-carson-tqhcku

di() { printf '%s\n' "$*"; }
corre() { if [ "$ACCION" = plan ]; then di "    $*"; else eval "$@" || return 1; fi; }

aplicar() {
  for r in "${REPOS[@]}"; do
    di "  $r"
    local d="$RAIZ/$r/deploy/redshift"
    if [ -d "$d/$ID" ]; then di "    ya migrado, nada que hacer"; continue; fi
    corre "mkdir -p '$d/$ID'"
    for p in "${PIEZAS[@]}"; do
      [ -e "$d/$p" ] && corre "git -C '$RAIZ/$r' mv 'deploy/redshift/$p' 'deploy/redshift/$ID/$p'"
    done
    # validar.sh resuelve todo contra ROOT; es la unica linea que hay que mover.
    corre "sed -i 's|^ROOT=\"deploy/redshift\"\$|ROOT=\"deploy/redshift/$ID\"|' '$RAIZ/$r/validar.sh'"
  done
}

revertir() {
  for r in "${REPOS[@]}"; do
    di "  $r"
    local d="$RAIZ/$r/deploy/redshift"
    [ -d "$d/$ID" ] || { di "    no esta migrado"; continue; }
    for p in "${PIEZAS[@]}"; do
      [ -e "$d/$ID/$p" ] && corre "git -C '$RAIZ/$r' mv 'deploy/redshift/$ID/$p' 'deploy/redshift/$p'"
    done
    corre "rmdir '$d/$ID'"
    corre "sed -i 's|^ROOT=\"deploy/redshift/$ID\"\$|ROOT=\"deploy/redshift\"|' '$RAIZ/$r/validar.sh'"
  done
}

traslado() {
  cat <<EOT
Traslado a Bitbucket despues de migrar. Un comando por linea: PowerShell 5.1
rechaza '&&'.

LA TRAMPA, y es la que hace volver el error: 'git checkout <rama> -- <ruta>'
COPIA pero NO BORRA. Sin el 'git rm -r --cached' de delante, los archivos de la
estructura vieja sobreviven en la rama de Bitbucket y [REDSHIFT:418] se vuelve a
disparar aunque en GitHub este todo bien.

EOT
  for i in 0 1 2; do
    local r="${REPOS[$i]}" j="${JIRA[$i]}"
    cat <<EOT
--- $r
cd <ruta>\\$r
git fetch github $RAMA
git checkout feature/$j-full-delta
git rm -r --cached deploy/redshift
git checkout github/$RAMA -- deploy/redshift
git status
git commit -m "$j: paquete a deploy/redshift/$ID (REDSHIFT:418)"
git push origin feature/$j-full-delta

EOT
  done
}

di "accion: $ACCION   identificador: $ID"
[ "$ACCION" = plan ] && di "(solo muestra; 'aplicar' ejecuta)"
case "$ACCION" in
  plan|aplicar) aplicar;;
  revertir)     revertir;;
  traslado)     traslado;;
  *) sed -n '2,30p' "$0"; exit 1;;
esac
