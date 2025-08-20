#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.1 – Asegurar que el tamaño de almacenamiento de los logs de auditoría esté configurado
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.2.1"
ITEM_DESC="Asegurar que el tamaño de almacenamiento de los logs de auditoría esté configurado"
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
REQUIRED_VALUE=32  # Valor mínimo recomendado en MB

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERROR] Este script debe ejecutarse como root."; exit 1; }
}

get_current_value() {
  grep -E '^[[:space:]]*max_log_file[[:space:]]*=' "$AUDIT_CONF" | head -n1 | awk -F= '{gsub(/[[:space:]]*/,"",$2); print $2}'
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ ! -f "$AUDIT_CONF" ]]; then
    log "[ERROR] Archivo $AUDIT_CONF no encontrado"
    exit 1
  fi

  current_value=$(get_current_value || echo "")

  if [[ -n "$current_value" && "$current_value" -ge "$REQUIRED_VALUE" ]]; then
    log "[OK] max_log_file=$current_value MB (>= $REQUIRED_VALUE) – no se requiere cambio"
  else
    timestamp=$(date +%Y%m%d%H%M%S)
    BACKUP="${AUDIT_CONF}.bak.${timestamp}"
    log "Backup creado: $BACKUP"
    [[ $DRY_RUN -eq 0 ]] && cp -p "$AUDIT_CONF" "$BACKUP"

    if [[ -z "$current_value" ]]; then
      log "Parámetro max_log_file no encontrado – se añadirá"
      run "echo 'max_log_file = $REQUIRED_VALUE' >> '$AUDIT_CONF'"
      log "[OK] max_log_file agregado con $REQUIRED_VALUE MB"
    else
      log "Parámetro max_log_file encontrado: $current_value – se actualizará"
      run "sed -i -E 's/^[[:space:]]*max_log_file[[:space:]]*=.*/max_log_file = $REQUIRED_VALUE/' '$AUDIT_CONF'"
      log "[OK] max_log_file actualizado a $REQUIRED_VALUE MB"
    fi

    run "systemctl restart auditd"
    log "[OK] Servicio auditd reiniciado"
  fi

  exit 0
}

main "$@"
