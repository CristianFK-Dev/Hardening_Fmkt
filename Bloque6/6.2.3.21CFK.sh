#!/usr/bin/env bash

# =============================================================================
# 6.2.3.21 – Ensure running and on-disk auditd configuration is the same
# -----------------------------------------------------------------------------
# • Verifica si `augenrules --check` detecta cambios pendientes.
# • Si hay desalineación: ejecuta `augenrules --load`.
# • Si auditd está en modo inmutable (`enabled = 2`), informa que se requiere reinicio.
# • Soporta modo --dry-run.
# =============================================================================

set -euo pipefail

ITEM_ID="6.2.3.21_AuditRulesSync"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Bloque6/Log"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

DRY_RUN=0
[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && DRY_RUN=1

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "→ Re-ejecutando con sudo para privilegios de root..." >&2
    exec sudo --preserve-env=PATH "$0" "$@"
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

# ========= Comienza ejecución =========

ensure_root
log "=== Remediación ${ITEM_ID}: Sincronizar reglas activas y persistidas de auditd ==="

CHECK_OUTPUT=$(augenrules --check 2>&1 || true)

if echo "$CHECK_OUTPUT" | grep -q "No change"; then
  log "✔ Las reglas activas y en disco ya están sincronizadas. No se requiere acción."
else
  log "✘ Se detectó desalineación entre reglas activas y en disco:"
  log "$CHECK_OUTPUT"

  run "augenrules --load"

  # Verificar si auditd está en modo inmutable (enabled = 2)
  ENABLED_MODE=$(auditctl -s | grep "^enabled" | awk '{print $2}')
  if [[ "$ENABLED_MODE" == "2" ]]; then
    log "⚠ Las reglas fueron cargadas, pero auditd está en modo inmutable (enabled = 2)."
    log "   → Es necesario reiniciar el sistema para que las nuevas reglas tengan efecto."
  else
    log "✔ Reglas cargadas correctamente con 'augenrules --load'."
  fi
fi

log "== Remediación ${ITEM_ID} completada =="

exit 0
