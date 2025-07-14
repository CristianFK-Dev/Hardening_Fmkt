#!/usr/bin/env bash

# =============================================================================
# 6.3.3 - Asegurar que AIDE esté instalado (Integridad herramientas de auditoría)
# Solo instala el paquete AIDE si no está presente
# =============================================================================

set -euo pipefail

ITEM_ID="6.3.3_AIDE_Install"
SCRIPT_NAME="$(basename "$0")"
LOG_DIR="./Log"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

mkdir -p "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "→ Re-ejecutando con sudo para privilegios de root..." >&2
    exec sudo --preserve-env=PATH "$0" "$@"
  fi
}

ensure_root

log "=== Remediación ${ITEM_ID}: Verificar si AIDE está instalado ==="

if command -v aide >/dev/null 2>&1; then
  log "AIDE ya está instalado en el sistema."
else
  log "→ AIDE no está instalado. Procediendo a instalar..."
  apt-get update -y && apt-get install -y aide
  log "AIDE fue instalado correctamente."
fi

log "== Remediación ${ITEM_ID} completada =="
