#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.7 – Asegurar que los intentos de acceso a archivos fallidos se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.7"
ITEM_DESC="Asegurar que los intentos de acceso a archivos fallidos se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
RULE_FILE="/etc/audit/rules.d/50-access.rules"

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

RULES=(
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=${UID_MIN} -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=${UID_MIN} -F auid!=unset -k access"
)

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Este script debe ejecutarse como root."; exit 1; }
}

rule_present() {
  local r="$1"
  grep -hFxq -- "$r" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ -z "$UID_MIN" ]]; then
    log "[ERR] No se pudo obtener UID_MIN de /etc/login.defs"
    exit 1
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    if [[ -f "$RULE_FILE" ]]; then
      BACKUP="${RULE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
      cp -p "$RULE_FILE" "$BACKUP"
      log "[OK] Backup creado: $BACKUP"
    fi
    touch "$RULE_FILE"
    chmod 640 "$RULE_FILE"
  fi

  for rule in "${RULES[@]}"; do
    if rule_present "$rule"; then
      log "[OK] Regla ya presente: $rule"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Añadiría: $rule"
      else
        echo "$rule" >> "$RULE_FILE"
        log "[OK] Regla añadida: $rule"
      fi
    fi
  done

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
  exit 0
}

main "$@"
