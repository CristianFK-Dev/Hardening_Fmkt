#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.3 Asegurar que la auditoría esté habilitada antes de iniciar auditd (audit=1 en GRUB)
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.1.3"
ITEM_DESC="Asegurar que la auditoría esté habilitada antes de iniciar auditd (audit=1 en GRUB)"
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

GRUB_FILE="/etc/default/grub"
BACKUP="${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERROR] Este script debe ejecutarse como root."; exit 1; }
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ ! -f "$GRUB_FILE" ]]; then
    log "[ERROR] Archivo $GRUB_FILE no encontrado"
    exit 1
  fi

  log "[EXEC] Backup creado: $BACKUP"
  [[ $DRY_RUN -eq 0 ]] && cp "$GRUB_FILE" "$BACKUP"

  if grep -Eq '(^|\s)audit=1(\s|$)' "$GRUB_FILE"; then
    log "[OK] El parámetro audit=1 ya estaba presente"
  else
    log "[INFO] Parámetro audit=1 será añadido"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría audit=1 en GRUB_CMDLINE_LINUX"
    else
      sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 audit=1"/' "$GRUB_FILE"
      log "[SUCCESS] audit=1 añadido en GRUB_CMDLINE_LINUX"
    fi
  fi

  run "update-grub"
  exit 0
}

main "$@"