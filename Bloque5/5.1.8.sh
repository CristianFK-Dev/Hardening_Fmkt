\
    #!/bin/bash
    # =============================================================================
    # 5.1.8 – Ensure sshd DisableForwarding is enabled
    # Establece DisableForwarding yes para desactivar X11, agent, TCP y StreamLocal forwarding.
    #
    # Uso      : sudo ./5.1.8.sh [--dry-run]
    #            --dry-run  → muestra acciones sin aplicar cambios
    #
    # Registro  : Bloque5/Log/<timestamp>_5.1.8.log
    # Retorno   : 0 éxito; !=0 error
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
    if [[ ${1:-} == "--dry-run" ]]; then
        DRY_RUN=1
        LOG_SUBDIR="audit"
    fi

    # ---------- logging ----------
    LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Log/${LOG_SUBDIR}"
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
    LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
    log() {
        printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}";
    }
    run() {
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log "[DRY-RUN] $*"
      else
        log "[EXEC]   $*"
        eval "$@"
      fi
    }

    log "=== Remediación ${ITEM_ID}: Establecer DisableForwarding yes ==="

    # ---------- comprobar configuración actual ----------
    CURRENT=$(grep -inE '^\s*DisableForwarding\s+' "${SSH_CFG}" || true | head -1)
    if [[ -n "${CURRENT}" ]]; then
      LINE=${CURRENT%%:*}
      VALUE=$(echo "${CURRENT}" | awk '{print tolower($2)}')
    else
      LINE=""
      VALUE=""
    fi

    if [[ "${VALUE}" == "yes" ]]; then
      log "DisableForwarding ya está en yes (línea ${LINE}). Nada que hacer."
      exit 0
    fi

    # ---------- backup ----------
    BACKUP_FILE="${BACKUP_DIR}/sshd_config.$(date +%Y%m%d-%H%M%S)"
    if [[ ${DRY_RUN} -eq 0 ]]; then
      cp --preserve=mode,ownership,timestamps "${SSH_CFG}" "${BACKUP_FILE}"
      log "Backup creado: ${BACKUP_FILE}"
    else
      log "[DRY-RUN] Crearía backup en ${BACKUP_FILE}"
    fi

    TMP=$(mktemp)

    if [[ -n "${LINE}" ]]; then
      # Reemplazar valor existente
      run "sed '${LINE}s/.*/DisableForwarding yes/' \"${SSH_CFG}\" > \"${TMP}\""
    else
      # Insertar antes del primer Include o al final
      INC_LINE=$(grep -nE '^\s*Include\b' "${SSH_CFG}" | head -1 | cut -d: -f1 || true)
      if [[ -n "${INC_LINE}" ]]; then
        run "awk 'NR==${INC_LINE}{print \"DisableForwarding yes\"} {print}' \"${SSH_CFG}\" > \"${TMP}\""
      else
        run "{ cat \"${SSH_CFG}\"; echo; echo \"DisableForwarding yes\"; } > \"${TMP}\""
      fi
    fi

    # ---------- validar ----------
    run "sshd -t -f \"${TMP}\""

    if [[ ${DRY_RUN} -eq 0 ]]; then
      mv "${TMP}" "${SSH_CFG}"
      log "Archivo ${SSH_CFG} actualizado."
      if command -v systemctl &>/dev/null; then
        run "systemctl reload sshd"
      else
        run "service ssh reload"
      fi
      log "sshd recargado."
    else
      log "[DRY-RUN] No se aplicaron cambios a ${SSH_CFG}"
      rm -f "${TMP}"
    fi

    log "== Remediación ${ITEM_ID} completada =="
    exit 0
