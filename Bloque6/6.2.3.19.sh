#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.19 Asegurar que se recopilan los eventos de carga y descarga de módulos del kernel
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.19"
ITEM_DESC="Asegurar que se recopilan los eventos de carga y descarga de módulos del kernel"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-kernel_modules.rules"

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

RULES=(
  "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
  "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
  "-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules"
)

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERROR] Este script debe ejecutarse como root."; exit 1; }
}

rule_present() {
  local rule_to_find="$1"
  grep -hFxq -- "$rule_to_find" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ -z "$UID_MIN" ]]; then
    log "[ERROR] UID_MIN no encontrado en /etc/login.defs"
    exit 1
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    touch "$RULE_FILE"
    chmod 640 "$RULE_FILE"
  fi

  for rule in "${RULES[@]}"; do
    if rule_present "$rule"; then
      log "[OK] Regla ya presente: $rule"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Añadiría regla: $rule"
      else
        echo "$rule" >> "$RULE_FILE"
        log "[EXEC] Regla añadida: $rule"
      fi
    fi
  done

}

main "$@"
