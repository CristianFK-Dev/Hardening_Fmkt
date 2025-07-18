#!/usr/bin/env bash

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
G="\e[32m"; R="\e[31m"; Y="\e[33m"; NC="\e[0m"; LIGHT_BLUE="\e[94m";

ensure_root() { [[ $EUID -eq 0 ]] || { echo -e "${R}Ejecutar como root${NC}"; exit 1; }; }

log_line() { echo "$*" | tee -a "$LOG_FILE"; }

chmod_all() {
  echo "→ Asignando permisos +x a todos los *.sh ..."
  find "$BASE_DIR" -type f -name '*.sh' -exec chmod +x {} +
}

run_all() {
  local mode="$1" # exec | audit | exec_force

  # Lista blanca de scripts que pueden recibir --force
  local FORCE_SCRIPTS=(
    "1.1.1.6.sh"
    "1.1.1.7.sh"
    "1.1.1.8.sh"
  )

  # Agrega entrada global de auditoría o ejecución al log general
  local timestamp; timestamp="$(date '+%F %T')"
  if [[ $mode == "audit" ]]; then
    log_line "===== [AUDIT MODE] Inicio de auditoría: $timestamp ====="
  else
    log_line "===== [EXEC MODE] Inicio de ejecución: $timestamp ====="
  fi

  for bloque in "$BASE_DIR"/Bloque*/; do
    [[ -d $bloque ]] || continue
    local bname; bname="$(basename "$bloque")"

    for script in "$bloque"/*.sh; do
      [[ -e $script ]] || continue
      local sname; sname="$(basename "$script")"

      # Determinar los argumentos para el script individual
      local script_args=""
      if [[ $mode == "audit" ]]; then
        script_args="--dry-run"
      elif [[ $mode == "exec_force" ]]; then
        # Comprobar si el script está en la lista blanca para forzar
        if [[ " ${FORCE_SCRIPTS[*]} " =~ " ${sname} " ]]; then
          script_args="--force"
        fi
      fi

      local output
      # Captura stdout y stderr, y comprueba el código de salida al mismo tiempo
      # Pasamos los argumentos en $script_args
      if ! output=$("$script" $script_args 2>&1); then
        # El script falló de verdad (código de salida != 0)
        local msg; msg=$(echo "$output" | head -n 1)
        log_line "${bname} | ${sname} | FAIL | ${msg}"
        echo -e "${R}${bname}/${sname} FAIL${NC}"
      else
        # El script se ejecutó correctamente (código de salida 0)
        if [[ $mode == "audit" ]] && [[ "$output" == *"[DRY-RUN]"* ]]; then
          # Modo auditoría y el script encontró algo que cambiar
          log_line "${bname} | ${sname} | AUDIT: PENDING |"
          echo -e "${Y}${bname}/${sname} AUDIT: PENDING${NC}"
        else
          # Modo ejecución, o modo auditoría sin cambios necesarios
          log_line "${bname} | ${sname} | OK |"
          echo -e "${G}${bname}/${sname} OK${NC}"
        fi
      fi
    done
  done

  # Cierre del bloque de auditoría o ejecución
  timestamp="$(date '+%F %T')"
  if [[ $mode == "audit" ]]; then
    log_line "===== [AUDIT MODE] Fin de auditoría: $timestamp ====="
  else
    log_line "===== [EXEC MODE] Fin de ejecución: $timestamp ====="
  fi
}

ver_log_general() {
  echo -e "${LIGHT_BLUE}\n=== Mostrando log general: Hardening.log ===${NC}"
  if [[ -f "$LOG_FILE" ]]; then
    less "$LOG_FILE"
  else
    echo -e "${R}No se encontró el archivo de log general: $LOG_FILE${NC}"
  fi
}

ver_logs_por_bloque() {
  echo -e "${LIGHT_BLUE}\n=== Ver logs por bloque ===${NC}"

  local bloques=()
  for logdir in "$BASE_DIR"/Bloque*/Log; do
    [[ -d "$logdir" ]] && bloques+=("$(basename "$(dirname "$logdir")")")
  done

  if [[ ${#bloques[@]} -eq 0 ]]; then
    echo -e "${R}No se encontraron bloques con carpeta Log.${NC}"
    return
  fi

  PS3=$'\nSeleccione un bloque para ver sus logs (o 0 para volver): '
  select bloque in "${bloques[@]}"; do
    if [[ -z "$bloque" ]]; then
      echo "Volviendo..."
      return
    fi

    local log_dir="$BASE_DIR/$bloque/Log"
    local log_files=("$log_dir"/*.log)

    if [[ ! -e "${log_files[0]}" ]]; then
      echo -e "${R}No hay logs en ${log_dir}.${NC}"
      return
    fi

    echo -e "${LIGHT_BLUE}\nLogs disponibles en ${bloque}/Log:${NC}"
    PS3=$'\nSeleccione un log para ver (o 0 para volver): '
    select log_file in "${log_files[@]}"; do
      if [[ -z "$log_file" ]]; then
        echo "Volviendo..."
        return
      fi

      echo -e "${LIGHT_BLUE}\nMostrando: $log_file${NC}"
      less "$log_file"
      break
    done

    break
  done
}

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

### MAIN LOOP ###
ensure_root
chmod_all

while true; do
  welcome_screen
  echo -e "Hardening wrapper listo.\n"

  PS3=$'\nSeleccione una opción (Ctrl+C para salir) : '
  select opt in "Ejecutar" "Auditar" "Ejecutar con --force (Peligroso)" "Ver log general" "Ver logs por bloque" "Salir"; do
    case $REPLY in
      1)
        run_all "exec"
        echo -e "${R}\n### Reinicie el sistema de forma manual para impactar cambios ###${NC}"
        break ;;
      2)
        run_all "audit"
        break ;;
      3)
        echo -e "${R}ADVERTENCIA: Esta opción aplicará --force a scripts específicos."
        echo -e "Esto puede deshabilitar servicios críticos (Docker, Snap, etc.).${NC}"
        read -rp "¿Está seguro de que desea continuar? (s/N): " confirm
        if [[ ${confirm,,} == "s" ]]; then
          run_all "exec_force"
          echo -e "${R}\n### Reinicie el sistema de forma manual para impactar cambios ###${NC}"
        else
          echo "Operación cancelada."
        fi
        break ;;
      4)
        ver_log_general
        break ;;
      5)
        ver_logs_por_bloque
        break ;;
      6)
        exit 0 ;;
      *)
        echo "Opción inválida" ;;
    esac
  done

  read -rp $'\nPresione Enter para volver al menú...'
done