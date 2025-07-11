#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.4 Ensure system warns when audit logs are low on space
#
# Descripción  : Configura los parámetros space_left_action y
#                admin_space_left_action en /etc/audit/auditd.conf para
#                garantizar que el sistema emita alertas (y, si lo requiere,
#                cambie a modo monousuario) cuando el espacio para logs de
#                auditoría sea bajo.
#
# Requisitos   :
#   - space_left_action  : email | exec | single | halt   (se usará 'email')
#   - admin_space_left_action : single | halt             (se usará 'single')
#
# Referencias   : CIS Debian 12 v1.1.0 - 6.2.2.4
# -----------------------------------------------------------------------------
set -euo pipefail

ITEM_ID="6.2.2.4"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

AUDIT_CONF="/etc/audit/auditd.conf"
REQ_SPACE_LEFT_ACTION="email"
REQ_ADMIN_SPACE_LEFT_ACTION="single"

DRY_RUN=0
if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
fi

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$msg" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Debe ejecutarse como root." >&2
    exit 1
  fi
}

get_value() {
  local key="$1"
  grep -iE "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF" |     head -n1 | awk -F= '{gsub(/[[:space:]]*/,"",$2); print tolower($2)}'
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
  log "Ejecutando ${SCRIPT_NAME} – ${ITEM_ID}"
  ensure_root

  if [[ ! -f "$AUDIT_CONF" ]]; then
    log "[ERR] Archivo ${AUDIT_CONF} no encontrado"
    exit 1
  fi

  # Backup antes de cambios reales
  if [[ $DRY_RUN -eq 0 ]]; then
    cp -p "$AUDIT_CONF" "${AUDIT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backup creado de auditd.conf"
  fi

  set_param "space_left_action" "$REQ_SPACE_LEFT_ACTION"
  set_param "admin_space_left_action" "$REQ_ADMIN_SPACE_LEFT_ACTION"

  if [[ $DRY_RUN -eq 0 ]]; then
    log "Reiniciando auditd ..."
    systemctl restart auditd
    log "[OK] auditd reiniciado"
  fi

  log "[SUCCESS] ${ITEM_ID} aplicado"
}

main "$@"
