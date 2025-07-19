#!/usr/bin/env bash
# =============================================================================
# 3.2.2 – Asegurar que el módulo tipc no esté disponible
# =============================================================================

set -euo pipefail

ITEM_ID="3.2.2"
MOD_NAME="tipc"
CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"
DRY_RUN=0
LOG_SUBDIR="exec" 

# ---------- parámetros ----------
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1; LOG_SUBDIR="audit" ;;
    *) echo "Uso: $0 [--dry-run]" >&2; exit 1 ;;
  esac
done

# ---------- log ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/Log/${LOG_SUBDIR}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
log() {
    # Asegurarse de que el directorio de log existe justo antes de escribir
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo -e "[$(date +%F\ %T)] $*" | tee -a "${LOG_FILE}";
}
run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC] $*"
    eval "$@"
  fi
}

log "=== Remediación ${ITEM_ID}: Deshabilitar ${MOD_NAME} ==="

# ---------- descargar módulo cargado ----------
if lsmod | grep -q "^${MOD_NAME}\\b"; then
  log "Módulo ${MOD_NAME} cargado → descargando"
  run "modprobe -r ${MOD_NAME} || true"
  run "rmmod ${MOD_NAME}     || true"
else
  log "Módulo ${MOD_NAME} no está cargado"
fi

# ---------- /etc/modprobe.d ----------
need_update=0
if [[ -f "${CONF_FILE}" ]]; then
  grep -qE "^\\s*install\\s+${MOD_NAME}\\s+/bin/false" "${CONF_FILE}" || need_update=1
  grep -qE "^\\s*blacklist\\s+${MOD_NAME}\\s*$"       "${CONF_FILE}" || need_update=1
else
  need_update=1
fi

if [[ "${need_update}" -eq 1 ]]; then
  log "Actualizando ${CONF_FILE}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    {
      echo "install ${MOD_NAME} /bin/false"
      echo "blacklist ${MOD_NAME}"
    } > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
  else
    log "[DRY-RUN] Escribiría líneas install/blacklist en ${CONF_FILE}"
  fi
else
  log "${CONF_FILE} ya contiene las directivas necesarias"
fi

# ---------- módulo en disco ----------
MOD_PATHS=$(modinfo -n "${MOD_NAME}" 2>/dev/null || true)
if [[ -n "${MOD_PATHS}" ]]; then
  log "Módulo ${MOD_NAME}.ko presente en: ${MOD_PATHS}"
else
  log "Módulo ${MOD_NAME}.ko NO existe en disco (posible builtin)"
fi

log "== Remediación ${ITEM_ID} completada =="

exit 0
