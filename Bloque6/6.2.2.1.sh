#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.1 Asegurar que el tamaño de almacenamiento de los logs de auditoría esté configurado
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.2.1"
ITEM_DESC="Asegurar que el tamaño de almacenamiento de los logs de auditoría esté configurado"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
AUDIT_CONF="/etc/audit/auditd.conf"
REQUIRED_VALUE=32     # Valor mínimo recomendado en MB
DRY_RUN=0

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
fi

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root." >&2
    exit 1
  fi
}

current_value() {
  grep -E '^[[:space:]]*max_log_file[[:space:]]*=' "$AUDIT_CONF" |     head -n1 | awk -F= '{gsub(/ /,"",$2); print $2}'
}

set_max_log_file() {
  local value
  value=$(current_value || true)

  if [[ -n "$value" && $value -ge $REQUIRED_VALUE ]]; then
    log "[OK] max_log_file=$value MB (>= $REQUIRED_VALUE) – no se requiere cambio"
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -z "$value" ]]; then
      log "[DRY-RUN] Añadiría max_log_file=$REQUIRED_VALUE al final de auditd.conf"
    else
      log "[DRY-RUN] Actualizaría max_log_file de $value a $REQUIRED_VALUE"
    fi
    return 0
  fi

  cp -p "$AUDIT_CONF" "${AUDIT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
  log "Backup creado: ${AUDIT_CONF}.bak.*"

  if grep -qE '^[[:space:]]*max_log_file[[:space:]]*=' "$AUDIT_CONF"; then
    sed -i -E 's/^[[:space:]]*max_log_file[[:space:]]*=.*/max_log_file = '"$REQUIRED_VALUE"'/' "$AUDIT_CONF"
    log "Parámetro max_log_file actualizado a $REQUIRED_VALUE MB"
  else
    echo "max_log_file = $REQUIRED_VALUE" >> "$AUDIT_CONF"
    log "Parámetro max_log_file añadido con $REQUIRED_VALUE MB"
  fi

  log "Reiniciando servicio auditd..."
  systemctl restart auditd
  log "[OK] auditd reiniciado"
}

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
ensure_root

if [[ ! -f "$AUDIT_CONF" ]]; then
  log "[ERR] Archivo $AUDIT_CONF no encontrado"
  exit 1
fi

set_max_log_file

log "[SUCCESS] ${ITEM_ID} aplicado"
log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="

exit 0
