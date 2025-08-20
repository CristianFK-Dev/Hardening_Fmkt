#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.3 – Asegurar que el sistema se desactive cuando los logs de auditoría estén llenos
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.2.3"
ITEM_DESC="Asegurar que el sistema se desactive cuando los logs de auditoría estén llenos"
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

AUDIT_CONF="/etc/audit/auditd.conf"
REQ_DISK_FULL_ACTION="halt"
REQ_DISK_ERROR_ACTION="syslog"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}
run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}
ensure_root() {
  [[ $EUID -eq 0 ]] || { log "ERROR: Debe ejecutarse como root."; exit 1; }
}
get_value() {
  local key="$1"
  grep -iE "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF" | head -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print tolower($2)}'
}
set_param() {
  local key="$1" desired="$2"
  local current
  current=$(get_value "$key" || true)

  if [[ "$current" == "$desired" ]]; then
    log "[OK] ${key}=${current} – sin cambios"
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -z "$current" ]]; then
      log "[DRY-RUN] Añadiría ${key} = ${desired}"
    else
      log "[DRY-RUN] Cambiaría ${key} de ${current} a ${desired}"
    fi
    return 0
  fi

  if ! grep -iEq "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF"; then
    echo "${key} = ${desired}" >> "$AUDIT_CONF"
    log "Añadido ${key} = ${desired}"
  else
    sed -i -E "s/^[[:space:]]*${key}[[:space:]]*=.*/${key} = ${desired}/I" "$AUDIT_CONF"
    log "Actualizado ${key} a ${desired}"
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "=== Remediación ${ITEM_ID}: ${ITEM_DESC} ==="
  ensure_root

  if [[ ! -f "$AUDIT_CONF" ]]; then
    log "[ERR] Archivo ${AUDIT_CONF} no encontrado"
    log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
    exit 1
  fi

  local full_action error_action
  full_action=$(get_value "disk_full_action")
  error_action=$(get_value "disk_error_action")

  if [[ "$full_action" == "$REQ_DISK_FULL_ACTION" && "$error_action" == "$REQ_DISK_ERROR_ACTION" ]]; then
    log "[OK] Configuración ya conforme: disk_full_action=$full_action, disk_error_action=$error_action"
    log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
    exit 0
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    run "cp -p '$AUDIT_CONF' '${AUDIT_CONF}.bak.$(date +%Y%m%d%H%M%S)'"
    log "Backup creado de auditd.conf"
  fi

  set_param "disk_full_action" "$REQ_DISK_FULL_ACTION"
  set_param "disk_error_action" "$REQ_DISK_ERROR_ACTION"

  exit 0
}

main "$@"
