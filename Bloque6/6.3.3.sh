#!/usr/bin/env bash

# =============================================================================
# 6.3.3 – Asegurar que AIDE esté instalado (Integridad herramientas de auditoría)
# =============================================================================

set -euo pipefail

ITEM_ID="6.3.3"
ITEM_DESC="Asegurar que AIDE esté instalado (Integridad herramientas de auditoría)"
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
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"

  if command -v aide >/dev/null 2>&1; then
    log "[OK] AIDE ya está instalado en el sistema."
  else
    log "[WARN] AIDE no está instalado."

    run "apt-get update -y"
    run "apt-get install -y aide"

    if command -v aide >/dev/null 2>&1; then
      log "[OK] AIDE fue instalado correctamente."
    else
      log "[ERR] Error al instalar AIDE."
      exit 1
    fi
  fi

}

main "$@"
