#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.2 Ensure auditd service is enabled and active
#
# Descripción  : Habilita y activa el servicio auditd para registrar eventos
#                del sistema.
# Referencias   : CIS Debian 12 v1.1.0 - Sección 6.2.1.2
#                Nessus FAILED - auditd inactivo o deshabilitado
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.1.2"
ITEM_DESC="Ensure auditd service is enabled and active"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

# -----------------------------------------------------------------------------
# Parámetros
# -----------------------------------------------------------------------------
DRY_RUN=0
if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
fi

# -----------------------------------------------------------------------------
# Funciones
# -----------------------------------------------------------------------------
log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$msg" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root." >&2
    exit 1
  fi
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
      log "Instalando paquete auditd (dependencia)..."
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y auditd
    fi
  fi
}

service_exists() {
  systemctl list-unit-files | grep -q "^$1\.service"
}

ensure_service_enabled_active() {
  local svc="$1"

  # Unmask
  if systemctl is-enabled "$svc" &>/dev/null || systemctl is-active "$svc" &>/dev/null; then
    :  # already known
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Unmask, enable y start para servicio $svc"
      return
    fi
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    systemctl unmask "$svc" || true
    systemctl enable "$svc"
    systemctl start "$svc"
  fi

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

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
ensure_root

install_auditd_pkg
ensure_service_enabled_active "auditd"

log "[SUCCESS] $ITEM_ID Aplicado correctamente"
exit 0
