#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.1.4 – Ensure audit_backlog_limit is sufficient (>= 8192)
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.1.4"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

ensure_root() { [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"; }

GRUB_FILE="/etc/default/grub"
BACKUP="${GRUB_FILE}.bak.$(date +%s)"
LIMIT="audit_backlog_limit=8192"

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"
ensure_root

log "Backup creado: $BACKUP"
cp "$GRUB_FILE" "$BACKUP"

if grep -Eq "\\baudit_backlog_limit=[0-9]+" "$GRUB_FILE"; then
  sed -i "s/\\baudit_backlog_limit=[0-9]\\+/$LIMIT/" "$GRUB_FILE"
  log "Parámetro audit_backlog_limit actualizado a 8192"
else
  sed -i "s/^GRUB_CMDLINE_LINUX=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX=\"\\1 $LIMIT\"/" "$GRUB_FILE"
  log "Parámetro audit_backlog_limit=8192 agregado"
fi

log "Ejecutando update-grub ..."
update-grub      #  <-- sin -q

log "[SUCCESS] ${ITEM_ID} aplicado correctamente (requiere reinicio para tomar efecto)"
exit 0
