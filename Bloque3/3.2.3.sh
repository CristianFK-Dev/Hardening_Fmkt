#!/usr/bin/env bash
# =============================================================================
# 3.2.3 – Asegurar que el módulo rds no esté disponible
# =============================================================================

set -euo pipefail

ITEM_ID="3.2.3"
ITEM_DESC="Asegurar que el módulo rds no esté disponible"
MOD_NAME="rds"
CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"
DRY_RUN=0
LOG_SUBDIR="exec" 

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1; LOG_SUBDIR="audit" ;;
    *) echo "Uso: $0 [--dry-run]" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/Log/${LOG_SUBDIR}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

log() {
    local msg="$1"
    printf '[%s] %s\n' "$(date +'%F %T')" "$msg" | tee -a "$LOG_FILE"
}

run() {
    local cmd="$*"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Pendiente: $cmd"
        return 0
    else
        log "[EXEC] Ejecutando: $cmd"
        eval "$@"
        local status=$?
        [[ $status -eq 0 ]] && log "[SUCCESS] Comando completado" || log "[ERROR] Falló el comando"
        return $status
    fi
}

log "[INFO] === Remediación ${ITEM_ID}: ${ITEM_DESC} ==="

if lsmod | grep -q "^${MOD_NAME}\\b"; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Estado actual: Módulo ${MOD_NAME} cargado"
        log "[DRY-RUN] Acción pendiente: Descargar módulo"
    else
        log "[EXEC] Descargando módulo ${MOD_NAME}"
        run "modprobe -r ${MOD_NAME} || true"
        run "rmmod ${MOD_NAME} || true"
        log "[EXEC] Módulo ${MOD_NAME} descargado"
    fi
else
    log "[OK] Módulo ${MOD_NAME} no está cargado"
fi

need_update=0
if [[ -f "${CONF_FILE}" ]]; then
    if ! grep -qE "^\\s*install\\s+${MOD_NAME}\\s+/bin/false" "${CONF_FILE}" || 
       ! grep -qE "^\\s*blacklist\\s+${MOD_NAME}\\s*$" "${CONF_FILE}"; then
        need_update=1
    fi
else
    need_update=1
fi

if [[ "${need_update}" -eq 1 ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Estado actual: Configuración incompleta o ausente"
        log "[DRY-RUN] Archivo: ${CONF_FILE}"
        log "[DRY-RUN] Cambios pendientes:"
        log "[DRY-RUN] - Añadir: install ${MOD_NAME} /bin/false"
        log "[DRY-RUN] - Añadir: blacklist ${MOD_NAME}"
    else
        log "[EXEC] Actualizando ${CONF_FILE}"
        {
            echo "install ${MOD_NAME} /bin/false"
            echo "blacklist ${MOD_NAME}"
        } > "${CONF_FILE}"
        chmod 644 "${CONF_FILE}"
        log "[SUCCESS] Archivo actualizado correctamente"
    fi
else
    log "[OK] ${CONF_FILE} ya contiene la configuración correcta"
fi

MOD_PATHS=$(modinfo -n "${MOD_NAME}" 2>/dev/null || true)
if [[ -n "${MOD_PATHS}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[INFO] Módulo ${MOD_NAME}.ko detectado en: ${MOD_PATHS}"
        log "[INFO] Nota: La presencia del módulo no afecta si está correctamente blacklisted"
    else
        log "[INFO] Módulo ${MOD_NAME}.ko presente en: ${MOD_PATHS}"
    fi
else
    log "[OK] Módulo ${MOD_NAME}.ko no existe en disco"
fi

# Finalización
if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] === Verificación ${ITEM_ID} completada ==="
else
    log "[SUCCESS] === Remediación ${ITEM_ID} completada ==="
fi

exit 0
