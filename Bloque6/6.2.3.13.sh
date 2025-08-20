#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.13 Asegurar que los eventos de eliminación de archivos por usuarios se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.13"
ITEM_DESC="Asegurar que los eventos de eliminación de archivos por usuarios se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
RULE_FILE="/etc/audit/rules.d/50-delete.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULES=(
"-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete"
"-a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete"
)

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
mkdir -p "$LOG_DIR"
: > "$LOG_FILE"
log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID"
ensure_root

if [[ -z "$UID_MIN" ]]; then
  log "[ERR] UID_MIN no encontrado en /etc/login.defs"
  exit 1
fi

if [[ $DRY_RUN -eq 0 ]]; then
  touch "$RULE_FILE"
  chmod 640 "$RULE_FILE"
  log "[EXEC] Archivo de reglas preparado: $RULE_FILE"
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

exit 0
