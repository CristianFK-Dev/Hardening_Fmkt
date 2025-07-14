#!/usr/bin/env bash

# Comando SCP de ejemplo
# scp.exe -i "C:\Users\matias.vazquez\Desktop\FMKT\Infra\FMKT-HARDERING-TEST.pem" -r "C:\\\\Users\\\\matias.vazquez\\\\Desktop\\\\hardening_fmkt" admin@52.90.118.210:~/hardening_fmkt
# ------------------------------------------------------------------
#     Hardening – Wrapper sencillo
#   • Da permisos +x a todos los *.sh
#   • Ejecuta o audita todos los scripts de cada bloque
#   • Registra resultados en Hardening.log
# ------------------------------------------------------------------
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${BASE_DIR}/Hardening.log"

# Colores opcionales
G="\e[32m"; R="\e[31m"; NC="\e[0m" ; LIGHT_BLUE="\e[94m" ;

ensure_root() { [[ $EUID -eq 0 ]] || { echo -e "${R}Ejecutar como root${NC}"; exit 1; }; }

log_line() { echo "$*" | tee -a "$LOG_FILE"; }

chmod_all() {
  echo "→ Asignando permisos +x a todos los *.sh ..."
  find "$BASE_DIR" -type f -name '*.sh' -exec chmod +x {} +
}

run_all() {
  local mode="$1"            # exec  | audit
  local flag=""              # vacío o --dry-run
  [[ $mode == "audit" ]] && flag="--dry-run"

  for bloque in "$BASE_DIR"/Bloque*/; do
    [[ -d $bloque ]] || continue
    local bname; bname="$(basename "$bloque")"

    for script in "$bloque"/*.sh; do
      [[ -e $script ]] || continue
      local sname; sname="$(basename "$script")"

      # Ejecutar y capturar salida+error
      local out err
      out=$(mktemp); err=$(mktemp)
      if "$script" $flag >"$out" 2>"$err"; then
        log_line "${bname} | ${sname} | OK |"
        echo -e "${G}${bname}/${sname} OK${NC}"
      else
        local msg; msg=$(head -1 "$err")
        log_line "${bname} | ${sname} | FAIL | ${msg}"
        echo -e "${R}${bname}/${sname} FAIL${NC}"
      fi
      rm -f "$out" "$err"
    done
  done
}

### MAIN ###
ensure_root
chmod_all
echo -e "\nHardening wrapper listo."

# Función para mostrar la pantalla de bienvenida
welcome_screen() {
  clear
  echo -e "${LIGHT_BLUE}"
  cat << "EOF"
     ███████╗███╗   ███╗ ██╗ ██╗████████╗
     ██╔════╝████╗ ████║ ██║██╔╝╚══██╔══╝
     █████╗  ██╔████╔██║ █████╔╝   ██║
     ██╔══╝  ██║╚██╔╝██║ ██╔═██╗   ██║
     ██╗     ██║ ╚═╝ ██║ ██║  ██╗  ██║
     ╚═╝     ╚═╝     ╚═╝ ╚═╝  ╚═╝  ╚═╝

    F I D E L I T Y   M A R K E T I N G
                   2025

********************************************
* Authorized Access Only                   *
* All activity is monitored and logged.    *
* Disconnect immediately if unauthorized.  *
********************************************
EOF
  echo -e "${NC}"
}

while true; do
  welcome_screen
  echo -e "Hardening wrapper listo.\n"

  PS3=$'\nSeleccione una opción: '
  select opt in "Ejecutar" "Auditar" "Salir"; do
    case $REPLY in
      1) run_all "exec"; break ;;
      2) run_all "audit"; break ;;
      3) exit 0 ;;
      *) echo "Opción inválida" ;;
    esac
  done
  echo -e "${R}\n### Reinicie el sistema de forma manual para impactar cambios ###"
  read -rp $'\nPresione Enter para volver al menú...'
done
