#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.11 Ensure session initiation information is collected
#
# Añade reglas de auditoría para monitorear /var/run/utmp, /var/log/wtmp y
# /var/log/btmp con etiqueta -k session.
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.11"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-session.rules"
RULES=(
"-w /var/run/utmp -p wa -k session"
"-w /var/log/wtmp -p wa -k session"
"-w /var/log/btmp -p wa -k session"
)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){ local r="$1"; grep -Fxq "$r" "$RULE_FILE" 2>/dev/null; }

mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
ensure_root
[[ $DRY_RUN -eq 0 ]] && { touch "$RULE_FILE"; chmod 640 "$RULE_FILE"; }

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla presente: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Regla añadida: $rule"
    fi
  fi
done

#if [[ $DRY_RUN -eq 0 ]]; then
#  log "Recargando reglas con augenrules..."
#  augenrules --load
#fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
