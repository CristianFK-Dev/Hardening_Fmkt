#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.17 Asegurar que los intentos exitosos y fallidos de usar el comando chacl se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.17"
ITEM_DESC="Asegurar que los intentos exitosos y fallidos de usar el comando chacl se recopilan"
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

RULE_FILE="/etc/audit/rules.d/50-perm_chng.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
RULE="-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k perm_chng"

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Debe ser root para ejecutar este script."; exit 1; }
}

rule_present() {
  grep -hFxq -- "$RULE" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "[EXEC] Ejecutando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ -z "$UID_MIN" ]]; then
    log "[ERR] UID_MIN no encontrado en /etc/login.defs"
    exit 1
  fi

  if rule_present; then
    log "[OK] Regla ya presente: $RULE"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría regla: $RULE"
    else
      touch "$RULE_FILE" && chmod 640 "$RULE_FILE"
      echo "$RULE" >> "$RULE_FILE"
      log "[EXEC] Regla añadida: $RULE"
    fi
  fi

}

main "$@"
