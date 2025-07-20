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

  # Lista negra de scripts a ignorar en modo auditoría
  local AUDIT_BLACKLIST=(
    "6.1.AuditClean.sh"
  )

  # Lista negra de scripts a ignorar en modo ejecución
  local EXEC_BLACKLIST=(
    "5.2.4.sh"
    "5.1.8.sh"
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

    find "$bloque" -maxdepth 1 -type f -name '*.sh' | sort -V | while IFS= read -r script; do
      local sname; sname="$(basename "$script")"

      # Omitir scripts en la lista negra de auditoría
      if [[ $mode == "audit" ]] && [[ " ${AUDIT_BLACKLIST[*]} " =~ " ${sname} " ]]; then
        log_line "${bname} | ${sname} | AUDIT: SKIPPED |"
        echo -e "${LIGHT_BLUE}${bname}/${sname} AUDIT: SKIPPED${NC}"
        continue
      fi

      # Omitir scripts en la lista negra de ejecución
      if [[ ( $mode == "exec" || $mode == "exec_force" ) ]] && [[ " ${EXEC_BLACKLIST[*]} " =~ " ${sname} " ]]; then
        log_line "${bname} | ${sname} | EXEC: SKIPPED |"
        echo -e "${LIGHT_BLUE}${bname}/${sname} EXEC: SKIPPED${NC}"
        continue
      fi

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
  clear
  print_menu_header "LOG GENERAL"
  if [[ -f "$LOG_FILE" ]]; then
    less "$LOG_FILE"
  else
    echo -e "${R}No se encontró el archivo de log general: $LOG_FILE${NC}"
  fi
}

ver_logs_por_bloque() {
    clear
    print_menu_header "LOGS POR BLOQUE"

    local bloques=()
    for dir in "$BASE_DIR"/Bloque*/; do
        [[ -d "$dir" ]] && bloques+=("$(basename "$dir")")
    done

    if [[ ${#bloques[@]} -eq 0 ]]; then
        echo -e "${R}No se encontraron directorios de Bloque.${NC}"
        return
    fi

    PS3=$'\nSeleccione un bloque (o 0 para volver al menú principal): '
    select bloque in "${bloques[@]}"; do
        if [[ -z "$bloque" ]]; then echo "Volviendo..."; return; fi

        clear
        print_menu_header "TIPO DE LOG - $bloque"
        local log_base_dir="$BASE_DIR/$bloque/Log"
        PS3=$'\nSeleccione el tipo de log (o 0 para volver a la selección de bloque): '
        select log_type in "Auditoría" "Ejecución"; do
            if [[ -z "$log_type" ]]; then echo "Volviendo..."; break; fi

            local log_subdir
            [[ "$log_type" == "Auditoría" ]] && log_subdir="audit" || log_subdir="exec"
            local log_dir="${log_base_dir}/${log_subdir}"
            
            clear
            print_menu_header "LOGS DE ${log_type^^} - $bloque"
            
            if [[ ! -d "$log_dir" ]] || [[ -z "$(ls -A "$log_dir")" ]]; then
                echo -e "${R}No se encontraron logs de '$log_type' en $bloque.${NC}"
                break
            fi

            local log_files=("$log_dir"/*.log)
            PS3=$'\nSeleccione un log para ver (o 0 para volver a la selección de tipo): '
            select log_file in "${log_files[@]}"; do
                if [[ -z "$log_file" ]]; then echo "Volviendo..."; break; fi
                echo -e "${LIGHT_BLUE}\nMostrando: $(basename "$log_file")${NC}"
                less "$log_file"
                # Vuelve al menú de tipo de log después de ver uno
                break
            done
            # Vuelve al menú de bloques después de salir del submenú de logs
            break
        done
        # Vuelve al menú principal después de salir del menú de bloques
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

print_menu_header() {
    local title=" $1 "
    local width=42
    local padding=$(( (width - ${#title}) / 2 ))
    local remainder=$(( (width - ${#title}) % 2 ))
    
    echo -e "\n${LIGHT_BLUE}********************************************"
    printf "*%*s%s%*s*\n" "$padding" "" "$title" "$((padding + remainder))" ""
    echo -e "********************************************${NC}\n"
}

main_menu() {
    echo -e "Menú Principal:\n"
    echo -e "  1. Ejecutar - [EXEC MODE]"
    echo -e "  ${Y}2. Auditar - [AUDIT MODE]${NC}"
    echo -e "  ${R}3. Ejecutar con --force (Peligroso)${NC}"
    echo -e "  4. Ver log general"
    echo -e "  5. Ver logs por bloque"
    echo -e "  6. Salir"
}

### MAIN LOOP ###
ensure_root
chmod_all

while true; do
  welcome_screen
  main_menu

  read -rp $'\nSeleccione una opción (1-6): ' choice
  echo "" # Newline for clarity

  case "$choice" in
    1)
        run_all "exec"
        echo -e "${R}\n### Reinicie el sistema de forma manual para impactar cambios ###${NC}"
        ;;
    2)
        run_all "audit"
        ;;
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
        ;;
    4)
        ver_log_general
        ;;
    5)
        ver_logs_por_bloque
        ;;
    6)
        exit 0 ;;
    *)
        echo "Opción inválida" ;;
  esac

  read -rp $'\nPresione Enter para volver al menú...'
done