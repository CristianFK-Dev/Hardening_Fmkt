#!/usr/bin/env bash

# =============================================================================
# 6.2.3.21 – Asegurar que se sincronizan las reglas activas y persistidas de auditd
# =============================================================================

set -euo pipefail

ITEM_ID="6.2.3.21_AuditRulesSync"
ITEM_DESC="Asegurar que se sincronizan las reglas activas y persistidas de auditd"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Bloque6/Log"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
DRY_RUN=0

[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && DRY_RUN=1

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ser ejecutado como root." >&2
    exit 1
  fi
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]   $*"
    eval "$@"
  fi
}

ensure_root
log "=== Remediación ${ITEM_ID}: Sincronizar reglas activas y persistidas de auditd ==="

CHECK_OUTPUT=$(augenrules --check 2>&1 || true)

if echo "$CHECK_OUTPUT" | grep -q "No change"; then
  log "✔ Las reglas activas y en disco ya están sincronizadas. No se requiere acción."
else
  log "✘ Se detectó desalineación entre reglas activas y en disco:"
  log "$CHECK_OUTPUT"

  run "augenrules --load"

  ENABLED_MODE=$(auditctl -s | grep "^enabled" | awk '{print $2}')
  if [[ "$ENABLED_MODE" == "2" ]]; then
    log "⚠ Las reglas fueron cargadas, pero auditd está en modo inmutable (enabled = 2)."
    log "   → Es necesario reiniciar el sistema para que las nuevas reglas tengan efecto."
  else
    log "✔ Reglas cargadas correctamente con 'augenrules --load'."
  fi
fi

log "[SUCCESS] ${ITEM_ID} aplicado"
log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="

exit 0
