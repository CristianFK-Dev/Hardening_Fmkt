#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.5 Ensure events that modify the system's network environment are collected
#
# Añade reglas de auditoría para:
#   - Syscalls sethostname y setdomainname (arch b64/b32)
#   - Cambios en /etc/issue, /etc/issue.net, /etc/hosts, /etc/networks,
#     /etc/network/, /etc/netplan/
# Etiqueta: -k system-locale
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.5"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-system_locale.rules"
RULES=(
"-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale"
"-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale"
"-w /etc/issue -p wa -k system-locale"
"-w /etc/issue.net -p wa -k system-locale"
"-w /etc/hosts -p wa -k system-locale"
"-w /etc/networks -p wa -k system-locale"
"-w /etc/network/ -p wa -k system-locale"
"-w /etc/netplan/ -p wa -k system-locale"
)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){
  # Busca la regla en todos los archivos .rules para evitar duplicados
  local r="$1"
  grep -hFxq -- "$r" /etc/audit/rules.d/*.rules 2>/dev/null
}

mkdir -p "$LOG_DIR"; : > "$LOG_FILE"; log "Running $SCRIPT_NAME – $ITEM_ID"
ensure_root
[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla ya presente en la configuración: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Añadida regla: $rule"
    fi
  fi
done

#if [[ $DRY_RUN -eq 0 ]]; then
#  log "Recargando reglas con augenrules..."
#  augenrules --load
#fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
