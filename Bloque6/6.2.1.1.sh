#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.1 Ensure auditd packages are installed
#
# Descripción  : Instala los paquetes auditd y audispd-plugins necesarios para
#                el subsistema de auditoría de Linux.
# Referencias   : CIS Debian 12 v1.1.0 - Sección 6.2.1.1
#                Nessus FAILED - dpkg check auditd / audispd-plugins
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.1.1"
ITEM_DESC="Ensure auditd packages are installed"
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
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
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

ensure_package() {
  local pkg="$1"
  if pkg_installed "$pkg"; then
    log "[OK] Paquete $pkg ya instalado"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Instalaría paquete: $pkg"
    else
      log "Instalando paquete $pkg ..."
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
      log "[OK] Paquete $pkg instalado"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
: > "$LOG_FILE"   # Truncar log al inicio

log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
ensure_root

ensure_package auditd
ensure_package audispd-plugins

log "[SUCCESS] $ITEM_ID Aplicado correctamente"
exit 0
