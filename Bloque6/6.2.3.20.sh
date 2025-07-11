#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.20 Ensure the audit configuration is immutable
#
# Añade '-e 2' a /etc/audit/rules.d/99-finalize.rules para poner auditd en modo
# inmutable. Requiere reinicio para activarse.
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.20"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

FINAL_RULE_FILE="/etc/audit/rules.d/99-finalize.rules"
RULE="-e 2"

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
ensure_root

add_rule() {
  if grep -Fxq "$RULE" "$FINAL_RULE_FILE" 2>/dev/null; then
    log "[OK] Regla -e 2 ya presente"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría '-e 2' a $FINAL_RULE_FILE"
    else
      echo "$RULE" >> "$FINAL_RULE_FILE"
      chmod 640 "$FINAL_RULE_FILE"
      log "Añadido '-e 2' a $FINAL_RULE_FILE"
    fi
  fi
}

add_rule

if [[ $DRY_RUN -eq 0 ]]; then
  log "Recargando reglas con augenrules..."
  augenrules --load || true
  if auditctl -s | grep -q "enabled 2"; then
    log "[INFO] Modo inmutable activo."
  else
    log "[NOTICE] Se requiere reinicio para activar el modo inmutable."
  fi
fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
