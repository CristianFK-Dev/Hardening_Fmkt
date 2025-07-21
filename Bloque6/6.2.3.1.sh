#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.1 Asegurar que los cambios en el ámbito de administración del sistema (sudoers) se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.1"
ITEM_DESC="Asegurar que los cambios en el ámbito de administración del sistema (sudoers) se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-scope.rules"
RULE1="-w /etc/sudoers -p wa -k scope"
RULE2="-w /etc/sudoers.d -p wa -k scope"
DRY_RUN=0

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
fi

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Debe ejecutarse como root" >&2
    exit 1
  fi
}

rule_present() {
  local rule_to_find="$1"
  grep -hFxq -- "$rule_to_find" /etc/audit/rules.d/*.rules 2>/dev/null
}

add_rule() {
  local rule="$1"
  if rule_present "$rule"; then
    log "[OK] Regla ya presente: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría regla: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "Regla añadida: $rule"
    fi
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Ejecutando $SCRIPT_NAME – $ITEM_ID"
  ensure_root

  if [[ $DRY_RUN -eq 0 ]]; then
    touch "$RULE_FILE"
    chmod 640 "$RULE_FILE"
  fi

  add_rule "$RULE1"
  add_rule "$RULE2"

  log "Reglas guardadas en $RULE_FILE"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
}

main "$@"
