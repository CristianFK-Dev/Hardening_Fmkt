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
    #"1.1.1.6.sh"
    #"1.1.1.7.sh"
    #"1.1.1.8.sh"
  )

  # Lista negra de scripts a ignorar en modo auditoría
  local AUDIT_BLACKLIST=(
    "6.1.AuditClean.sh"
  )

  # Lista negra de scripts a ignorar en modo ejecución
  local EXEC_BLACKLIST=(
    "1.1.1.6.sh"
    "1.1.1.7.sh"
    "1.1.1.8.sh"
    "5.1.8.sh"
    "5.2.4.sh"
  )

  # Agrega entrada global de auditoría o ejecución al log general
  local timestamp; timestamp="$(date '+%F %T')"
  if [[ $mode == "audit" ]]; then
    log_line "===== [AUDIT MODE]  Inicio de auditoría: $timestamp  [AUDIT MODE] ====="
  else
    log_line "===== [EXEC MODE]  Inicio de ejecución: $timestamp  [EXEC MODE] ====="
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
      if ! output=$("$script" $script_args 2>&1); then
        local msg; msg=$(echo "$output" | head -n 1)
        log_line "${bname} | ${sname} | FAIL | ${msg}"
        echo -e "${R}${bname}/${sname} FAIL${NC}"
      else
          if [[ $mode == "audit" ]]; then
            if echo "$output" | grep -q "\[DRY-RUN\]"; then
              # Simplificar el mensaje de log para auditoría
              log_line "$(date '+%F %T') | ${bname} | ${sname} | REQUIERE REMEDIACIÓN"
              echo -e "${Y}${bname}/${sname} PENDIENTE${NC}"
            else
              log_line "$(date '+%F %T') | ${bname} | ${sname} | CUMPLE"
              echo -e "${G}${bname}/${sname} CUMPLE${NC}"
            fi
          else
            log_line "${bname} | ${sname} | OK |"
            echo -e "${G}${bname}/${sname} OK${NC}"
          fi
      fi
    done
  done

  # Cierre del bloque de auditoría o ejecución
  timestamp="$(date '+%F %T')"
  if [[ $mode == "audit" ]]; then
    log_line "===== [AUDIT MODE]  Fin de auditoría: $timestamp  [AUDIT MODE] ====="
  else
    log_line "===== [EXEC MODE]  Fin de ejecución: $timestamp  [EXEC MODE] ====="
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
    while true; do
        clear
        echo -e "\n${LIGHT_BLUE}=== Logs por Bloque ===${NC}"
        echo "1) Bloque 1"
        echo "2) Bloque 2"
        echo "3) Bloque 3"
        echo "4) Bloque 4"
        echo "5) Bloque 5"
        echo "6) Bloque 6"
        echo -e "${Y}v) Volver al menú principal${NC}"
        
        read -r -p "Seleccione un bloque (1-6) o 'v' para volver: " opcion
        
        case $opcion in
            1) ver_logs_bloque "Bloque1" ;;
            2) ver_logs_bloque "Bloque2" ;;
            3) ver_logs_bloque "Bloque3" ;;
            4) ver_logs_bloque "Bloque4" ;;
            5) ver_logs_bloque "Bloque5" ;;
            6) ver_logs_bloque "Bloque6" ;;
            v|V) return ;;
            *) echo -e "${R}Opción inválida${NC}" ;;
        esac
    done
}

ver_logs_bloque() {
    local bloque="$1"
    while true; do
        clear
        echo -e "\n${LIGHT_BLUE}=== Logs de ${bloque} ===${NC}"
        echo "1) Logs de ejecución (exec)"
        echo "2) Logs de auditoría (audit)"
        echo -e "${Y}v) Volver al menú de bloques${NC}"
        
        read -r -p "Seleccione tipo de logs (1-2) o 'v' para volver: " tipo
        
        case $tipo in
            v|V) return ;;
            1) ver_logs_tipo "$bloque" "exec" ;;
            2) ver_logs_tipo "$bloque" "audit" ;;
            *) echo -e "${R}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

ver_logs_tipo() {
    local bloque="$1"
    local tipo="$2"
    while true; do
        clear
        echo -e "\n${LIGHT_BLUE}=== Logs de ${bloque} (${tipo}) ===${NC}"
        local i=1
        local logs=()
        
        while IFS= read -r log; do
            logs+=("$log")
            echo "$i) $(basename "$log")"
            ((i++))
        done < <(find "${BASE_DIR}/${bloque}/Log/${tipo}" -type f -name "*.log" | sort)
        
        if [ ${#logs[@]} -eq 0 ]; then
            echo -e "${Y}No hay logs disponibles en esta categoría${NC}"
            sleep 2
            return
        fi
        
        echo -e "${Y}v) Volver al menú anterior${NC}"
        
        read -r -p "Seleccione un log (1-$((i-1))) o 'v' para volver: " opcion
        
        case $opcion in
            v|V) return ;;
            [1-9]|[1-9][0-9])
                if [ "$opcion" -lt "$i" ]; then
                    clear
                    echo -e "${LIGHT_BLUE}=== ${logs[$((opcion-1))]} ===${NC}"
                    cat "${logs[$((opcion-1))]}"
                    echo -e "\nPresione Enter para continuar o 'v' para volver..."
                    read -r respuesta
                    [ "$respuesta" = "v" ] || [ "$respuesta" = "V" ] && return
                else
                    echo -e "${R}Opción inválida${NC}"
                    sleep 1
                fi
                ;;
            *)
                echo -e "${R}Opción inválida${NC}"
                sleep 1
                ;;
        esac
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

***********************************************************************
*                    ¡Solo personal autorizado!                       *
* Atención: Este script modifica configuraciones críticas del sistema *
*        Asegúrese de entender los cambios que se aplicarán.          *
***********************************************************************
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
  echo ""

  case "$choice" in
    1)
        clear
        run_all "exec"
        echo -e "${R}\n### Reinicie el sistema de forma manual para impactar cambios ###${NC}"
        ;;
    2)
        clear
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