#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.1 Asegurar que los paquetes auditd estén instalados
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.1.1"
ITEM_DESC="Asegurar que los paquetes auditd estén instalados"
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

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "ERROR: Este script debe ejecutarse como root."; exit 1; }
}

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

ensure_package() {
  local pkg="$1"
  if pkg_installed "$pkg"; then
    log "[OK] Paquete $pkg ya instalado"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Instalaría paquete: $pkg"
    else
      run "apt-get update -qq"
      run "DEBIAN_FRONTEND=noninteractive apt-get install -y '$pkg'"
      log "[OK] Paquete $pkg instalado"
    fi
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  ensure_package auditd
  ensure_package audispd-plugins

  exit 0
}

main "$@"
