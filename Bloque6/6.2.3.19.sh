#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.19 Asegurar que se recopilan los eventos de carga y descarga de módulos del kernel
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.19"
ITEM_DESC="Asegurar que se recopilan los eventos de carga y descarga de módulos del kernel"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-kernel_modules.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

RULES=(
"-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
"-a always,exit -F arch=b32 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
"-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){
  local rule_to_find="$1"
  grep -hFxq -- "$rule_to_find" /etc/audit/rules.d/*.rules 2>/dev/null
}

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
ensure_root
if [[ -z "$UID_MIN" ]]; then log "[ERR] UID_MIN no encontrado"; exit 1; fi

[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla presente: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Regla añadida: $rule"
    fi
  fi
done

log "[SUCCESS] ${ITEM_ID} aplicado"
log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="

exit 0
