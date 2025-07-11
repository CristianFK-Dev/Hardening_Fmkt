#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.7 Ensure unsuccessful file access attempts are collected
#
# Añade reglas para registrar intentos fallidos (EACCES, EPERM) de crear/abrir/
# truncar archivos por usuarios no privilegiados.
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.7"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-access.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

RULES=(
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=${UID_MIN} -F auid!=unset -k access"
)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){ local r="$1"; grep -Fxq "$r" "$RULE_FILE" 2>/dev/null; }

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
ensure_root

if [[ -z "$UID_MIN" ]]; then
  log "[ERR] No se pudo obtener UID_MIN"; exit 1;
fi

[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla presente"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Regla añadida"
    fi
  fi
done

if [[ $DRY_RUN -eq 0 ]]; then
  log "Recargando reglas con augenrules..."
  augenrules --load
fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
