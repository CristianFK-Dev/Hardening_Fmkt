#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.18 Asegurar que los intentos exitosos y fallidos de usar el comando usermod se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.18"
ITEM_DESC="Asegurar que los intentos exitosos y fallidos de usar el comando usermod se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-usermod.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
RULE="-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k usermod"
DRY_RUN=0

[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
ensure_root

if [[ -z "$UID_MIN" ]]; then log "[ERR] UID_MIN no encontrado"; exit 1; fi

[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

if grep -hFxq -- "$RULE" /etc/audit/rules.d/*.rules 2>/dev/null; then
  log "[OK] Regla ya presente"
else
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] Añadiría: $RULE"
  else
    echo "$RULE" >> "$RULE_FILE"
    log "Regla añadida"
  fi
fi

log "[SUCCESS] ${ITEM_ID} aplicado"
log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="

exit 0
