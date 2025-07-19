#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.2 Asegurar que el servicio auditd esté habilitado y activo
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.1.2"
ITEM_DESC="Asegurar que el servicio auditd esté habilitado y activo"
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
install_auditd_pkg() {
  if pkg_installed "auditd"; then
    log "[OK] Paquete auditd ya instalado"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Instalaría paquete auditd (dependencia)"
    else
      run "apt-get update -qq"
      run "DEBIAN_FRONTEND=noninteractive apt-get install -y auditd"
      log "[OK] Paquete auditd instalado"
    fi
  fi
}
service_exists() {
  systemctl list-unit-files | grep -q "^$1\.service"
}
ensure_service_enabled_active() {
  local svc="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] Unmask, enable y start para servicio $svc"
    return
  fi

  run "systemctl unmask '$svc' || true"
  run "systemctl enable '$svc'"
  run "systemctl start '$svc'"

  local state_enabled
  local state_active
  state_enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")
  state_active=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")

  if [[ $state_enabled == "enabled" && $state_active == "active" ]]; then
    log "[OK] Servicio $svc está habilitado ($state_enabled) y activo ($state_active)"
  else
    log "[ERR] No se pudo habilitar/activar el servicio $svc (enabled=$state_enabled active=$state_active)"
    exit 1
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  install_auditd_pkg
  ensure_service_enabled_active "auditd"

  log "[SUCCESS] $ITEM_ID Aplicado correctamente"
  exit 0
}

main "$@"
