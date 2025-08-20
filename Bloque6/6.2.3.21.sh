#!/usr/bin/env bash

# =============================================================================
# 6.2.3.21 – Asegurar que se sincronizan las reglas activas y persistidas de auditd
# =============================================================================

set -euo pipefail

ITEM_ID="6.2.3.21"
ITEM_DESC="Asegurar que se sincronizan las reglas activas y persistidas de auditd"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Este script debe ejecutarse como root."; exit 1; }
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]   $*"
    eval "$@"
  fi
}

main() {
  ensure_root
  : > "$LOG_FILE"
  log "[EXEC] Ejecutando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"

  CHECK_OUTPUT=$(augenrules --check 2>&1 || true)

  if echo "$CHECK_OUTPUT" | grep -q "No change"; then
    log "[OK] Reglas activas y persistidas ya están sincronizadas"
  else
    log "[WARN] Desalineación detectada entre reglas activas y persistidas"
    log "[INFO] Resultado de augenrules --check:"
    log "$CHECK_OUTPUT"

    run "augenrules --load"

    ENABLED_MODE=$(auditctl -s | awk '/^enabled/ {print $2}')
    if [[ "$ENABLED_MODE" == "2" ]]; then
      log "[NOTICE] Las reglas fueron cargadas, pero auditd está en modo inmutable (enabled=2)"
      log "[NOTICE] Se requiere reinicio para aplicar los cambios"
    else
      log "[OK] Reglas sincronizadas con éxito usando 'augenrules --load'"
    fi
  fi

}

main "$@"
