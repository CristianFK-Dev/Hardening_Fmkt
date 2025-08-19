#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.12 Asegurar que los eventos de inicio y cierre de sesión se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.12"
ITEM_DESC="Asegurar que los eventos de inicio y cierre de sesión se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_SUBDIR="${LOG_SUBDIR:-$(date +'%Y%m%d_%H%M%S')}"
LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-login.rules"

RULES=(
"-w /var/log/lastlog -p wa -k logins"
"-w /var/run/faillock -p wa -k logins"
)

DRY_RUN="${DRY_RUN:-0}"
if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
    DRY_RUN=1
fi

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date +'%F %T')" "$msg" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "[ERR] Debe ser root" >&2
    exit 1
  fi
}

rule_present() {
  local rule_to_find="$1"
  grep -hFxq -- "$rule_to_find" /etc/audit/rules.d/*.rules 2>/dev/null
}

# Inicio
mkdir -p "$LOG_DIR"; :> "$LOG_FILE"
log "[EXEC] Ejecutando $SCRIPT_NAME – $ITEM_ID"
ensure_root

if [[ $DRY_RUN -eq 0 ]]; then
  touch "$RULE_FILE"
  chmod 640 "$RULE_FILE"
  log "[EXEC] Archivo de reglas creado: $RULE_FILE"
fi

for rule in "${RULES[@]}"; do
  if rule_present "$rule"; then
    log "[OK] Regla ya presente: $rule"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría regla: $rule"
    else
      echo "$rule" >> "$RULE_FILE"
      log "[EXEC] Regla añadida: $rule"
    fi
  fi
done

log "[SUCCESS] ${ITEM_ID} aplicado correctamente"
log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
exit 0
