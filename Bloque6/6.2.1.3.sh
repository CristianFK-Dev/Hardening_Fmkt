#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.3 Ensure auditing for processes that start prior to auditd is enabled
# Agrega audit=1 a GRUB_CMDLINE_LINUX y actualiza grub.
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.1.3"
ITEM_DESC="Asegurar que la auditoría esté habilitada antes de iniciar auditd (audit=1 en GRUB)"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

ensure_root() { [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
log() { printf '[%s] %s\n' "$(date +'%F %T')" "$*" | tee -a "$LOG_FILE"; }

GRUB_FILE="/etc/default/grub"
BACKUP="${GRUB_FILE}.bak.$(date +%s)"

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"
ensure_root
log "=== Remediación ${ITEM_ID}: ${ITEM_DESC} ==="
log "Backup creado: $BACKUP"
cp "$GRUB_FILE" "$BACKUP"

if grep -Eq '(^|\s)audit=1(\s|$)' "$GRUB_FILE"; then
  log "[OK] El parámetro audit=1 ya estaba presente"
else
  log "Parámetro audit=1 añadido"
  sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 audit=1"/' "$GRUB_FILE"
fi

log "Ejecutando update-grub ..."
update-grub

log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
exit 0
