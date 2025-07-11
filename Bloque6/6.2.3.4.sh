#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.4 Ensure events that modify date and time information are collected
#
# Configura reglas de auditoría para registrar cambios en fecha/hora
# (adjtimex, settimeofday, clock_settime y modificaciones a /etc/localtime).
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.4"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-time-change.rules"
RULES=(
"-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change"
"-a always,exit -F arch=b32 -S adjtimex,settimeofday -k time-change"
"-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -k time-change"
"-a always,exit -F arch=b32 -S clock_settime -F a0=0x0 -k time-change"
"-w /etc/localtime -p wa -k time-change"
)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){ local r="$1"; grep -Fxq "$r" "$RULE_FILE" 2>/dev/null; }

mkdir -p "$LOG_DIR"; :>"$LOG_FILE"; log "Run $SCRIPT_NAME"
ensure_root
[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla ya presente"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Añadida regla: $rule"
    fi
  fi
done

if [[ $DRY_RUN -eq 0 ]]; then
  log "Recargando reglas..."
  augenrules --load
fi

log "[SUCCESS] $ITEM_ID aplicado"
exit 0
