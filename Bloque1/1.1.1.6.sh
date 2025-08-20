#!/usr/bin/env bash
# =============================================================================
# 1.1.1.6 – Asegurar que el módulo overlayfs no esté disponible
# =============================================================================

set -euo pipefail

ITEM_ID="1.1.1.6"
MOD_NAME="overlay"
ALIAS_NAME="overlayfs"
ITEM_DESC="Deshabilitar ${MOD_NAME}/${ALIAS_NAME}"
CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"
DRY_RUN=0
FORCE=0
LOG_SUBDIR="exec"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1; LOG_SUBDIR="audit" ;;
    --force)   FORCE=1   ;;
    *) echo "Uso: $0 [--dry-run] [--force]" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/Log/${LOG_SUBDIR}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
log() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo -e "[$(date +%F\ %T)] $*" | tee -a "${LOG_FILE}";
}

run() {
    local cmd="$*"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Pendiente: $cmd"
        return 0
    else
        log "[EXEC] $cmd"
        eval "$@"
        return $?
    fi
}

log "[INFO] === Remediación ${ITEM_ID}: ${ITEM_DESC} ==="

if command -v docker &>/dev/null        && docker info --format '{{.Driver}}' 2>/dev/null | grep -qi overlay        && [[ "${FORCE}" -ne 1 ]]; then
  log "[ERROR] Docker usa overlay2 → ejecuta con --force para continuar."
  exit 1
fi

if lsmod | grep -q "^${MOD_NAME}\b"; then
  log "[INFO] Módulo ${MOD_NAME} cargado → descargando"
  run "modprobe -r ${MOD_NAME} || true"
  run "rmmod ${MOD_NAME}     || true"
else
  log "[INFO] Módulo ${MOD_NAME} no está cargado"
fi

need_update=0
if [[ -f "${CONF_FILE}" ]]; then
  grep -qE "^\s*install\s+${MOD_NAME}\s+/bin/false" "${CONF_FILE}" || need_update=1
  grep -qE "^\s*blacklist\s+${MOD_NAME}\s*$"       "${CONF_FILE}" || need_update=1
else
  need_update=1
fi

if [[ "${need_update}" -eq 1 ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Pendiente: Actualizar ${CONF_FILE}"
        log "[DRY-RUN] - Añadir: install ${MOD_NAME} /bin/false"
        log "[DRY-RUN] - Añadir: blacklist ${MOD_NAME}"
    else
        log "[EXEC] Actualizando ${CONF_FILE}"
        {
            echo "install ${MOD_NAME} /bin/false"
            echo "blacklist ${MOD_NAME}"
        } > "${CONF_FILE}"
        chmod 644 "${CONF_FILE}"
        log "[SUCCESS] Archivo actualizado"
    fi
else
    log "[OK] ${CONF_FILE} ya contiene las directivas necesarias"
fi

MOD_PATHS=$(modinfo -n "${MOD_NAME}" 2>/dev/null || true)
if [[ -n "${MOD_PATHS}" ]]; then
  log "[INFO] Módulo ${MOD_NAME}.ko presente en: ${MOD_PATHS}"
else
  log "[INFO] Módulo ${MOD_NAME}.ko NO existe en disco (posible builtin)"
fi

exit 0
