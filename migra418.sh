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
# RAMAS DE BITBUCKET, NOMBRE COMPLETO. Antes esto era un sufijo pegado a mano
# ("feature/$j-full-delta") y cada tanda de subtareas lo rompia. Van enteras.
BITBUCKET=(feature/SLCOPRBA-1444-strct-full-delta-real
           feature/SLCOPRBA-1445-pgm-full-delta-real
           feature/SLCOPRBA-1446-dt-full-delta-real)
PIEZAS=(deploy.par rollback.par SQL RevSQL)
# La rama de GitHub de la que sale el paquete.
RAMA=codex/ajustes-sp-reales-batch-en-linea

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
Traslado a Bitbucket. Un comando por linea: PowerShell 5.1 rechaza '&&', de
modo que si uno falla los siguientes se ejecutan igual.

LA TRAMPA, y es la que hace volver el error: 'git checkout <rama> -- <ruta>'
COPIA pero NO BORRA. Sin el 'git rm -r --cached' de delante, los archivos de la
estructura vieja sobreviven en la rama de Bitbucket y [REDSHIFT:418] se vuelve a
disparar aunque en GitHub este todo bien.

Y LA OTRA CARA DE ESA MISMA TRAMPA: el 'git rm -r --cached' borra el paquete
del indice ANTES de que el 'git checkout' lo reponga. Si la copia falla, el
commit y el push suben EL BORRADO. Por eso hay un 'git ls-files' entre los dos
y un 'git ls-tree' despues del push: el primero mira el indice local, el
segundo mira lo que Jenkins va a construir, que es el remoto. NO son
intercambiables.

NUNCA reescribir la rama de Bitbucket entre despliegues: siempre un commit
normal hacia adelante que toque un archivo del paquete.

Cuentas de hoy, para comparar: strct 100 archivos, pgm 234, dt 74.

EL TRASLADO LLEVA TAMBIEN .jenkins.yml, Y ESO ES NUEVO (2026-10-22). La regla
escrita -- "el traslado lleva solo deploy/redshift/" -- valia cuando los repos
de Bitbucket ya traian su .jenkins.yml bueno. Los repos DB_DS_* son nuevos y
nacen de una PLANTILLA DE TERRAFORM: su .jenkins.yml declara tech: terraform,
de modo que Jenkins manda el build al pipeline TERRAFORM, que muere en
sonarQubeScan con SONARQUBE:101 sin mirar una linea de SQL y sin tocar DEV.
Comprobado en DEV/TERRAFORM #74615 sobre SLCOPRBA-1444.
  Lo que sigue en pie de aquella regla: NADA de CLAUDE.md, validar.sh, docs/
  ni banco/. El .jenkins.yml es la excepcion porque es lo que ELIGE el
  pipeline, y Jenkins lo lee de la rama de Bitbucket, no de GitHub.

Y LAS CINCO CARPETAS DE LA PLANTILLA SE BORRAN: demo, develop, qa, trunk y
production son entornos de Terraform y el UNICO que las nombra es ese mismo
.jenkins.yml. Sustituido el yml, quedan huerfanas; dejarlas solo sirve para
confundir a quien revise el diff. .gitignore y README.md se quedan.

EOT
  for i in 0 1 2; do
    local r="${REPOS[$i]}" b="${BITBUCKET[$i]}"
    cat <<EOT
--- $r   ->   $b
cd <ruta>\\$r
git fetch github $RAMA
git checkout $b
git pull origin $b
git rm -r --cached deploy/redshift
git checkout github/$RAMA -- deploy/redshift
git checkout github/$RAMA -- .jenkins.yml
git rm -r --quiet --ignore-unmatch demo develop qa trunk production
git ls-files deploy/redshift | Measure-Object -Line
git status
git commit -m "$ID: paquete Reconocer desde $RAMA"
git push origin $b
git ls-tree -r --name-only origin/$b -- deploy/redshift | Measure-Object -Line

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
