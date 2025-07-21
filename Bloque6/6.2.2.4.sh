#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.2.4 – Asegurar que el sistema advierte cuando los registros de auditoría
#           están bajos de espacio, y normaliza sintaxis clave=valor
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.2.4"
ITEM_DESC="Asegurar que el sistema advierte cuando los registros de auditoría están bajos de espacio"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"
AUDIT_CONF="/etc/audit/auditd.conf"
REQ_SPACE_LEFT_ACTION="email"
REQ_ADMIN_SPACE_LEFT_ACTION="single"
DRY_RUN=0

[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Debe ejecutarse como root." >&2
    exit 1
  fi
}

get_value() {
  local key="$1"
  grep -iE "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF" | head -n1 | awk -F= '{gsub(/[[:space:]]*/,"",$2); print tolower($2)}'
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
      log "[DRY-RUN] Añadiría ${key}=${desired}"
    else
      log "[DRY-RUN] Cambiaría ${key} de ${current} a ${desired}"
    fi
    return 0
  fi

  if ! grep -iEq "^[[:space:]]*${key}[[:space:]]*=" "$AUDIT_CONF"; then
    echo "${key}=${desired}" >> "$AUDIT_CONF"
    log "Añadido ${key}=${desired}"
  else
    sed -i -E "s/^[[:space:]]*${key}[[:space:]]*=.*/${key}=${desired}/I" "$AUDIT_CONF"
    log "Actualizado ${key} a ${desired}"
  fi
}

normalize_conf_syntax() {
  log "Normalizando formato clave=valor en ${AUDIT_CONF} ..."
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] No se modifica el archivo, solo se mostrarían cambios"
    grep -E '^[[:space:]]*[a-zA-Z0-9_.-]+[[:space:]]*=' "$AUDIT_CONF" | while read -r line; do
      norm=$(echo "$line" | sed -E 's/^([[:space:]]*[a-zA-Z0-9_.-]+)[[:space:]]*=[[:space:]]*/\1=/')
      [[ "$line" != "$norm" ]] && log "[DRY-RUN] → $line → $norm"
    done
  else
    sed -i -E 's/^([[:space:]]*[a-zA-Z0-9_.-]+)[[:space:]]*=[[:space:]]*/\1=/' "$AUDIT_CONF"
    log "Formato clave=valor normalizado"
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

  if [[ $DRY_RUN -eq 0 ]]; then
    cp -p "$AUDIT_CONF" "${AUDIT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backup creado de auditd.conf"
  fi

  normalize_conf_syntax
  set_param "space_left_action" "$REQ_SPACE_LEFT_ACTION"
  set_param "admin_space_left_action" "$REQ_ADMIN_SPACE_LEFT_ACTION"

  if [[ $DRY_RUN -eq 0 ]]; then
    log "Reiniciando auditd ..."
    systemctl restart auditd
    log "[OK] auditd reiniciado"
  fi

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
}

main "$@"