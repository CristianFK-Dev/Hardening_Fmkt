#!/usr/bin/env bash
# =============================================================================
# 5.1.8 – Asegurar que sshd DisableForwarding esté habilitado
# =============================================================================

set -euo pipefail

ITEM_ID="5.1.8"
ITEM_DESC="Asegurar que sshd DisableForwarding esté habilitado"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CFG="/etc/ssh/sshd_config"
BACKUP_DIR="/etc/ssh/hardening_backups"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
: > "${LOG_FILE}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
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

main() {
  log "[INFO] === Remediación ${ITEM_ID}: Establecer DisableForwarding yes ==="

  if [[ ! -f "${SSH_CFG}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      log "[AUDIT] No se encontró el archivo de configuración: ${SSH_CFG}. No se realizaría ningún cambio."
      log "[INFO] == Auditoría ${ITEM_ID}: ${ITEM_DESC} finalizada =="
    else
      log "[FAIL] No se encontró el archivo de configuración: ${SSH_CFG}. No se realizaron cambios."
      log "[INFO] == Remediación ${ITEM_ID}: ${ITEM_DESC} finalizada =="
    fi
    exit 1
  fi

  CURRENT_LINE=$(grep -inE '^[[:space:]]*DisableForwarding[[:space:]]+' "${SSH_CFG}" || true | head -1)
  if [[ -n "${CURRENT_LINE}" ]]; then
    LINE_NUM=${CURRENT_LINE%%:*}
    CURRENT_VALUE=$(echo "${CURRENT_LINE}" | awk '{print tolower($2)}')
  else
    LINE_NUM=""
    CURRENT_VALUE=""
  fi

  if [[ "${CURRENT_VALUE}" == "yes" ]]; then
    log "[OK] DisableForwarding ya está en 'yes' (línea ${LINE_NUM}). Nada que hacer."
    log "[INFO] == Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
    exit 0
  fi

  BACKUP_FILE="${BACKUP_DIR}/sshd_config.$(date +%Y%m%d-%H%M%S)"
  run "cp --preserve=mode,ownership,timestamps '${SSH_CFG}' '${BACKUP_FILE}'"

  TMP=$(mktemp)

  if [[ -n "${LINE_NUM}" ]]; then
    log "[EXEC] La directiva 'DisableForwarding' existe con un valor incorrecto. Se corregirá."
    run "sed '${LINE_NUM}s/.*/DisableForwarding yes/' '${SSH_CFG}' > '${TMP}'"
    log "[SUCCESS] Archivo ${SSH_CFG} actualizado."
  else
    log "[EXEC] La directiva 'DisableForwarding' no existe. Se añadirá al final."
    run "{ cat '${SSH_CFG}'; echo; echo '# Added by hardening script ${ITEM_ID}'; echo 'DisableForwarding yes'; } > '${TMP}'"
    log "[SUCCESS] Directiva creada."
  fi

  run "sshd -t -f '${TMP}'"

  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mv "${TMP}" "${SSH_CFG}"
    log "[EXEC] Archivo ${SSH_CFG} actualizado."
    if command -v systemctl &>/dev/null; then
      run "systemctl reload sshd"
    else
      run "service ssh reload"
      log "[EXEC] Servicio sshd recargado."
    fi
    log "[SUCCESS] Servicio recargado."
  else
    log "[DRY-RUN] No se aplicaron cambios a ${SSH_CFG}"
    rm -f "${TMP}"
  fi
  
  exit 0
}

main "$@"
