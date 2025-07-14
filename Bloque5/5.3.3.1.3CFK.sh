#!/usr/bin/env bash

# =============================================================================
# 5.3.3.1.3 – Asegurar que /etc/security/faillock.conf incluya even_deny_root
#            o root_unlock_time=60 (o mayor)
# =============================================================================

set -euo pipefail

ITEM_ID="5.3.3.1.3_FaillockConf"
SCRIPT_NAME="$(basename "$0")"
LOG_DIR="./Log"
BACKUP_DIR="/etc/security/hardening_backups"
FAILLOCK_CONF="/etc/security/faillock.conf"
ROOT_UNLOCK_TIME="60"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "→ Re-ejecutando con sudo..." >&2
    exec sudo "$0" "$@"
  fi
}

ensure_root "$@"

DRY_RUN=0
[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && DRY_RUN=1

# Si no existe el archivo, lo crea
if [[ ! -f "$FAILLOCK_CONF" ]]; then
  log "Archivo $FAILLOCK_CONF no existe. Creando..."
  [[ $DRY_RUN -eq 0 ]] && touch "$FAILLOCK_CONF"
fi

# Verificamos si ya tiene configuración válida
if grep -Eq '^\s*(even_deny_root|root_unlock_time\s*=\s*[6-9][0-9]|[1-9][0-9]{2,})\b' "$FAILLOCK_CONF"; then
  log "✔ El archivo ya contiene configuración válida (even_deny_root o root_unlock_time >= 60)."
  exit 0
fi

# Backup previo
BACKUP_FILE="${BACKUP_DIR}/faillock.conf.$(date +%Y%m%d-%H%M%S)"
if [[ $DRY_RUN -eq 0 ]]; then
  cp --preserve=mode,ownership,timestamps "$FAILLOCK_CONF" "$BACKUP_FILE"
  log "Backup creado: $BACKUP_FILE"
else
  log "[DRY-RUN] Se crearía backup: $BACKUP_FILE"
fi

# Agregar las líneas requeridas
if [[ $DRY_RUN -eq 0 ]]; then
  {
    echo ""
    echo "# Añadido por $SCRIPT_NAME para cumplimiento 5.3.3.1.3"
    echo "even_deny_root"
    echo "root_unlock_time = $ROOT_UNLOCK_TIME"
  } >> "$FAILLOCK_CONF"
  log "✔ Se añadieron 'even_deny_root' y 'root_unlock_time = $ROOT_UNLOCK_TIME' a $FAILLOCK_CONF"
else
  log "[DRY-RUN] Se añadiría 'even_deny_root' y 'root_unlock_time = $ROOT_UNLOCK_TIME' a $FAILLOCK_CONF"
fi

log "Remediación ${ITEM_ID} completada."
exit 0
