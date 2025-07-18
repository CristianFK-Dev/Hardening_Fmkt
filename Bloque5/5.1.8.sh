#!/usr/bin/env bash
# =============================================================================
# 5.1.8 – Ensure sshd DisableForwarding is enabled
#
# Descripción: Establece 'DisableForwarding yes' para desactivar el reenvío
#              de X11, agent, TCP y StreamLocal.
#
# Uso      : sudo ./5.1.8.sh [--dry-run]
#            --dry-run  → Muestra acciones sin aplicar cambios.
# Registro : Bloque5/Log/{audit|exec}/<timestamp>_5.1.8.log
# Retorno  : 0 en éxito, no-cero en error.
# =============================================================================

set -euo pipefail

ITEM_ID="5.1.8"
SSH_CFG="/etc/ssh/sshd_config"
BACKUP_DIR="/etc/ssh/hardening_backups"

# --- ensure_root ---
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Este script debe ser ejecutado como root." >&2
  exit 1
fi

# ---------- parámetros ----------
DRY_RUN=0
LOG_SUBDIR="exec"
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

# ---------- logging ----------
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Log/${LOG_SUBDIR}"
mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}
run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]   $*"
    eval "$@"
  fi
}

log "=== Remediación ${ITEM_ID}: Establecer DisableForwarding yes ==="

# Verificar si el archivo existe
if [[ ! -f "${SSH_CFG}" ]]; then
  # Escribimos al log individual Y a stderr para que el wrapper lo capture.
  log "ERROR: No se encontró el archivo de configuración: ${SSH_CFG}" >&2
  exit 1
fi

# ---------- comprobar configuración actual ----------
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
  exit 0
fi

# ---------- backup ----------
BACKUP_FILE="${BACKUP_DIR}/sshd_config.$(date +%Y%m%d-%H%M%S)"
run "cp --preserve=mode,ownership,timestamps '${SSH_CFG}' '${BACKUP_FILE}'"

TMP=$(mktemp)

if [[ -n "${LINE_NUM}" ]]; then
  # Reemplazar valor existente
  log "La directiva 'DisableForwarding' existe con un valor incorrecto. Se corregirá."
  run "sed '${LINE_NUM}s/.*/DisableForwarding yes/' '${SSH_CFG}' > '${TMP}'"
else
  # Añadir al final
  log "La directiva 'DisableForwarding' no existe. Se añadirá al final."
  run "{ cat '${SSH_CFG}'; echo; echo '# Added by hardening script ${ITEM_ID}'; echo 'DisableForwarding yes'; } > '${TMP}'"
fi

# ---------- validar ----------
run "sshd -t -f '${TMP}'"

# ---------- aplicar ----------
if [[ "${DRY_RUN}" -eq 0 ]]; then
  mv "${TMP}" "${SSH_CFG}"
  log "Archivo ${SSH_CFG} actualizado."

  if command -v systemctl &>/dev/null; then
    run "systemctl reload sshd"
  else
    run "service ssh reload"
  fi
  log "Servicio sshd recargado."
else
  log "[DRY-RUN] No se aplicaron cambios a ${SSH_CFG}"
  rm -f "${TMP}"
fi

log "== Remediación ${ITEM_ID} completada =="
exit 0
