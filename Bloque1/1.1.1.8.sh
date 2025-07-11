\
    #!/usr/bin/env bash
    # =============================================================================
    # 1.1.1.8 – Ensure udf kernel module is not available
    # Deshabilita y deniega el módulo udf (Universal Disk Format) para reducir
    # superficie de ataque cuando no se requiera grabar DVD/ISO.
    #
    # ⚠️  Advertencia Azure:
    #     Microsoft Azure utiliza udf internamente en algunas instancias.
    #     Este script abortará si detecta Azure, salvo que pases --force.
    #
    # Uso      : sudo ./1.1.1.8.sh [--dry-run] [--force]
    #            --dry-run  → solo muestra acciones
    #            --force    → omite advertencia Azure
    #
    # Registro  : Bloque1/Log/<timestamp>_1.1.1.8.log
    # Retorno   : 0 éxito; !=0 error (set -euo pipefail)
    # =============================================================================

    set -euo pipefail

    ITEM_ID="1.1.1.8"
    MOD_NAME="udf"
    CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"

    # ---------- parámetros ----------
    DRY_RUN=0
    FORCE=0
    for arg in "$@"; do
      case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1   ;;
        *) echo "Uso: $0 [--dry-run] [--force]" >&2; exit 1 ;;
      esac
    done

    # ---------- log ----------
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOG_DIR="${SCRIPT_DIR}/Log"
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
    log() { echo -e "[$(date +%F\\ %T)] $*" | tee -a "${LOG_FILE}"; }
    run() {
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] $*"
      else
        log "[EXEC] $*"
        eval "$@"
      fi
    }

    log "=== Remediación ${ITEM_ID}: Deshabilitar ${MOD_NAME} ==="

    # ---------- detección Azure ----------
    if [[ "${FORCE}" -ne 1 ]]; then
      if [ -d /var/lib/waagent ] || grep -qi 'azure' /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        log "ERROR: Entorno Azure detectado; udf podría ser necesario. Aborta (usa --force para continuar)."
        exit 1
      fi
    fi

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
