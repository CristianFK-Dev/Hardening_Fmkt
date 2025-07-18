#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.17 Ensure successful and unsuccessful attempts to use the chacl command are collected
#
# Crea regla de auditoría para /usr/bin/chacl (-k perm_chng) registrando
# ejecuciones por usuarios no privilegiados.
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.17"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-perm_chng.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

RULE="-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k perm_chng"

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

#if [[ $DRY_RUN -eq 0 ]]; then
#  log "Recargando reglas con augenrules..."
#  augenrules --load
#fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
