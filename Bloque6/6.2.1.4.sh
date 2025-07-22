#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.4 – Asegurar que el límite de retroceso de auditoría sea suficiente (>= 8192)
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.1.4"
ITEM_DESC="Asegurar que el límite de retroceso de auditoría sea suficiente (>= 8192)"
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
LIMIT="audit_backlog_limit=8192"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "ERROR: Este script debe ejecutarse como root."; exit 1; }
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ ! -f "$GRUB_FILE" ]]; then
    log "[ERR] Archivo $GRUB_FILE no encontrado"
    exit 1
  fi

  log "Backup creado: $BACKUP"
  [[ $DRY_RUN -eq 0 ]] && cp "$GRUB_FILE" "$BACKUP"

  if grep -Eq "\\baudit_backlog_limit=[0-9]+" "$GRUB_FILE"; then
    log "Parámetro audit_backlog_limit ya existe, será reemplazado por $LIMIT"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Reemplazaría audit_backlog_limit existente por $LIMIT"
    else
      sed -i "s/\\baudit_backlog_limit=[0-9]\\+/$LIMIT/" "$GRUB_FILE"
      log "[OK] audit_backlog_limit actualizado a 8192"
    fi
  else
    log "Parámetro audit_backlog_limit no encontrado, se agregará a GRUB_CMDLINE_LINUX"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Agregaría $LIMIT a GRUB_CMDLINE_LINUX"
    else
      sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $LIMIT\"/" "$GRUB_FILE"
      log "[OK] audit_backlog_limit=8192 agregado"
    fi
  fi

  run "update-grub"

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada (requiere reinicio para tomar efecto) =="
  exit 0
}

main "$@"
