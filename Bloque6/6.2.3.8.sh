#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.8 Ensure events that modify user/group information are collected
#
# Añade reglas de auditoría para monitorear archivos y directorios críticos de
# identidad (-k identity).
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.3.8"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-identity.rules"
RULES=(
"-w /etc/group -p wa -k identity"
"-w /etc/passwd -p wa -k identity"
"-w /etc/gshadow -p wa -k identity"
"-w /etc/shadow -p wa -k identity"
"-w /etc/security/opasswd -p wa -k identity"
"-w /etc/nsswitch.conf -p wa -k identity"
"-w /etc/pam.conf -p wa -k identity"
"-w /etc/pam.d -p wa -k identity"
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
      log "Añadida regla: $rule"
    fi
  fi
done

#if [[ $DRY_RUN -eq 0 ]]; then
#  log "Recargando reglas con augenrules..."
#  augenrules --load
#fi

log "[SUCCESS] ${ITEM_ID} aplicado"
exit 0
