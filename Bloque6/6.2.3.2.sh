#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.2 Ensure actions as another user are always logged
#
# Descripción : Añade reglas de auditoría para registrar la ejecución de
#               procesos con UID efectivo distinto al real (sudo, su, pkexec).
#               Se etiquetan con -k user_emulation y cubren arquitecturas
#               b32 y b64.
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.2"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-user_emulation.rules"
RULE_B64="-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation"
RULE_B32="-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation"

DRY_RUN=0
if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
fi

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { echo "Debe ejecutarse como root" >&2; exit 1; }
}

rule_exists() {
  local rule="$1"
  grep -Fxq "$rule" "$RULE_FILE" 2>/dev/null
}

add_rule() {
  local rule="$1"
  if rule_exists "$rule"; then
    log "[OK] Regla presente: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría regla: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Regla añadida: $rule"
    fi
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Ejecutando ${SCRIPT_NAME} – ${ITEM_ID}"
  ensure_root

  if [[ $DRY_RUN -eq 0 ]]; then
    touch "$RULE_FILE"
    chmod 640 "$RULE_FILE"
  fi

  add_rule "$RULE_B64"
  add_rule "$RULE_B32"

  #if [[ $DRY_RUN -eq 0 ]]; then
  #  log "Recargando reglas (augenrules --load)..."
  #  augenrules --load
  #  log "[OK] Reglas de auditoría cargadas"
  #fi

  log "[SUCCESS] ${ITEM_ID} aplicado"
}

main "$@"
