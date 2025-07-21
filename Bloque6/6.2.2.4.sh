#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.4 – Asegurar que el sistema advierte cuando los registros de auditoría están bajos de espacio
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.2.4"
ITEM_DESC="Asegurar que el sistema advierte cuando los registros de auditoría están bajos de espacio"
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
REQ_SPACE_LEFT_ACTION="email"
REQ_ADMIN_SPACE_LEFT_ACTION="single"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Este script debe ejecutarse como root."; exit 1; }
}

get_value() {
  local key="$1"
  grep -iE "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF" | head -n1 | awk -F= '{gsub(/[[:space:]]*/,"",$2); print tolower($2)}'
}

set_param() {
  local key="$1" desired="$2"
  local current
  current=$(get_value "$key" || echo "")

  if [[ "$current" == "$desired" ]]; then
    log "[OK] ${key}=${current} – sin cambios"
    return 0
  fi

  if ! grep -iEq "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF"; then
    run "echo '${key} = ${desired}' >> '$AUDIT_CONF'"
    log "[OK] Añadido ${key} = ${desired}"
  else
    run "sed -i -E 's|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${desired}|I' '$AUDIT_CONF'"
    log "[OK] Actualizado ${key} a ${desired}"
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ ! -f "$AUDIT_CONF" ]]; then
    log "[ERR] Archivo $AUDIT_CONF no encontrado"
    exit 1
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    BACKUP="${AUDIT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$AUDIT_CONF" "$BACKUP"
    log "Backup creado: $BACKUP"
  fi

  set_param "space_left_action" "$REQ_SPACE_LEFT_ACTION"
  set_param "admin_space_left_action" "$REQ_ADMIN_SPACE_LEFT_ACTION"

  #if [[ $DRY_RUN -eq 0 ]]; then
  #  run "systemctl restart auditd"
  #  log "[OK] Servicio auditd reiniciado"
  #fi

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
  exit 0
}

main "$@"
